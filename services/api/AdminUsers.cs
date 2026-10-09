using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Npgsql;

public sealed class AdminUsersDatabase(IConfiguration configuration, ILogger<AdminUsersDatabase> logger, AdminTokenService tokens, AdminAuditLogDatabase audit)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    private const string DefaultStoreId = "default";

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        const string sql = """
            create table if not exists admin_users (
                id uuid primary key,
                store_id varchar(120) not null,
                email varchar(320) not null,
                display_name varchar(200) not null,
                role varchar(80) not null,
                is_active boolean not null default true,
                created_by varchar(320) not null,
                created_at timestamptz not null,
                deactivated_at timestamptz null,
                unique(store_id, email)
            );
            create index if not exists ix_admin_users_store_active on admin_users(store_id, is_active, created_at desc);
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "admin-users", "001-memberships", sql, cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "admin-users", "002-member-login", """
            alter table admin_users add column if not exists password_salt bytea null;
            alter table admin_users add column if not exists password_hash bytea null;
            alter table admin_users add column if not exists invitation_token_hash bytea null;
            alter table admin_users add column if not exists invitation_expires_at timestamptz null;
            create table if not exists admin_user_sessions (
                session_id uuid primary key,
                user_id uuid not null references admin_users(id) on delete cascade,
                store_id varchar(120) not null,
                created_at timestamptz not null,
                expires_at timestamptz not null,
                revoked_at timestamptz null
            );
            create index if not exists ix_admin_user_sessions_user_active
                on admin_user_sessions(user_id, store_id, expires_at desc) where revoked_at is null;
            """, cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "admin-users", "003-member-permissions", """
            alter table admin_users add column if not exists permissions_json jsonb null;
            """, cancellationToken);
        await using var seed = new NpgsqlCommand("""
            insert into admin_users(id,store_id,email,display_name,role,is_active,created_by,created_at)
            values(@id,@store_id,@email,@display_name,'Owner',true,'system',now())
            on conflict(store_id,email) do update set role='Owner', is_active=true, deactivated_at=null;
            """, connection);
        seed.Parameters.AddWithValue("id", Guid.NewGuid());
        seed.Parameters.AddWithValue("store_id", DefaultStoreId);
        seed.Parameters.AddWithValue("email", tokens.OwnerEmail);
        seed.Parameters.AddWithValue("display_name", "مدیر اصلی");
        await seed.ExecuteNonQueryAsync(cancellationToken);
        logger.LogInformation("Admin user membership schema is ready.");
    }

    public async Task<IReadOnlyCollection<AdminUserSummary>> ListAsync(string? storeId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<AdminUserSummary>();
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("""
            select id,store_id,email,display_name,role,is_active,created_at,deactivated_at,password_hash is not null,permissions_json::text
            from admin_users where store_id=@store_id order by created_at desc;
            """, connection);
        command.Parameters.AddWithValue("store_id", NormalizeStoreId(storeId));
        return await ReadManyAsync(command, cancellationToken);
    }

    public async Task<AdminUserInvitation> CreateAsync(AdminUserCreateRequest request, string actor, string? storeId, string requestId, CancellationToken cancellationToken)
    {
        var validation = request.Validate();
        if (validation.Count > 0) throw new AdminUserValidationException(validation);
        await using var connection = await OpenAsync(cancellationToken);
        var id = Guid.NewGuid();
        var normalizedStoreId = NormalizeStoreId(storeId);
        var invitationToken = CreateInvitationToken();
        var tokenHash = HashToken(invitationToken);
        var expiresAt = DateTimeOffset.UtcNow.AddHours(24);
        await using var command = new NpgsqlCommand("""
            insert into admin_users(id,store_id,email,display_name,role,is_active,created_by,created_at,invitation_token_hash,invitation_expires_at,permissions_json)
            values(@id,@store_id,@email,@display_name,@role,true,@created_by,now(),@token_hash,@expires_at,@permissions::jsonb);
            """, connection);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("store_id", normalizedStoreId);
        command.Parameters.AddWithValue("email", request.Email.Trim().ToLowerInvariant());
        command.Parameters.AddWithValue("display_name", request.DisplayName.Trim());
        command.Parameters.AddWithValue("role", AdminPermissionCatalog.NormalizeRole(request.Role));
        command.Parameters.AddWithValue("created_by", actor.Trim());
        command.Parameters.AddWithValue("token_hash", tokenHash);
        command.Parameters.AddWithValue("expires_at", expiresAt);
        command.Parameters.AddWithValue("permissions", request.Permissions is null ? DBNull.Value : JsonSerializer.Serialize(request.Permissions));
        await command.ExecuteNonQueryAsync(cancellationToken);
        var created = await GetAsync(connection, id, cancellationToken);
        if (created is null) throw new InvalidOperationException("کاربر ایجادشده پیدا نشد.");
        await audit.RecordAsync(actor, "admin-user.invited", "AdminUser", id.ToString(), null, created, "ایجاد عضویت و صدور دعوت یک‌بارمصرف", requestId, cancellationToken);
        return new AdminUserInvitation(created, invitationToken, expiresAt);
    }

    public async Task<AdminUserSummary?> AuthenticateAsync(string email, string password, string? storeId, CancellationToken cancellationToken)
    {
        if (!IsConfigured || !IsValidPassword(password)) return null;
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("""
            select id,store_id,email,display_name,role,is_active,created_at,deactivated_at,password_salt,password_hash,permissions_json::text
            from admin_users
            where store_id=@store_id and email=@email and is_active=true;
            """, connection);
        command.Parameters.AddWithValue("store_id", NormalizeStoreId(storeId));
        command.Parameters.AddWithValue("email", email.Trim().ToLowerInvariant());
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken) || reader.IsDBNull(8) || reader.IsDBNull(9)) return null;
        var salt = reader.GetFieldValue<byte[]>(8);
        var expected = reader.GetFieldValue<byte[]>(9);
        var supplied = Rfc2898DeriveBytes.Pbkdf2(password, salt, PasswordIterations, HashAlgorithmName.SHA256, PasswordHashBytes);
        if (!CryptographicOperations.FixedTimeEquals(expected, supplied)) return null;
        var role = reader.GetString(4);
        return new AdminUserSummary(
            reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), role, reader.GetBoolean(5),
            ReadPermissions(role, reader.IsDBNull(10) ? null : reader.GetString(10)), reader.GetFieldValue<DateTimeOffset>(6), reader.IsDBNull(7) ? null : reader.GetFieldValue<DateTimeOffset>(7), true);
    }

    public async Task<bool> AcceptInvitationAsync(string token, string password, string requestId, AdminAuditLogDatabase audit, CancellationToken cancellationToken)
    {
        if (!IsConfigured || !IsValidPassword(password) || string.IsNullOrWhiteSpace(token) || token.Length > 128) return false;
        var salt = RandomNumberGenerator.GetBytes(PasswordSaltBytes);
        var passwordHash = Rfc2898DeriveBytes.Pbkdf2(password, salt, PasswordIterations, HashAlgorithmName.SHA256, PasswordHashBytes);
        await using var connection = await OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        Guid userId = Guid.Empty;
        string email = string.Empty;
        string storeId = string.Empty;
        string role = string.Empty;
        var accepted = false;
        await using (var command = new NpgsqlCommand("""
            update admin_users
            set password_salt=@salt,password_hash=@password_hash,invitation_token_hash=null,invitation_expires_at=null
            where invitation_token_hash=@token_hash and invitation_expires_at>now() and is_active=true and password_hash is null
            returning id,store_id,email,role;
            """, connection, transaction))
        {
            command.Parameters.AddWithValue("salt", salt);
            command.Parameters.AddWithValue("password_hash", passwordHash);
            command.Parameters.AddWithValue("token_hash", HashToken(token));
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (await reader.ReadAsync(cancellationToken))
            {
                userId = reader.GetGuid(0);
                storeId = reader.GetString(1);
                email = reader.GetString(2);
                role = reader.GetString(3);
                accepted = true;
            }
        }
        if (!accepted)
        {
            await transaction.RollbackAsync(cancellationToken);
            return false;
        }
        await audit.RecordAsync(connection, transaction, email, "admin-user.invitation-accepted", "AdminUser", userId.ToString(),
            new { InvitationPending = true }, new { InvitationPending = false, StoreId = storeId, Role = role },
            "Invitation accepted", requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return true;
    }

    public async Task CreateSessionAsync(Guid userId, string storeId, Guid sessionId, DateTimeOffset expiresAt, CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("""
            insert into admin_user_sessions(session_id,user_id,store_id,created_at,expires_at)
            select @session_id,id,store_id,now(),@expires_at
            from admin_users where id=@user_id and store_id=@store_id and is_active=true and password_hash is not null;
            """, connection);
        command.Parameters.AddWithValue("session_id", sessionId);
        command.Parameters.AddWithValue("user_id", userId);
        command.Parameters.AddWithValue("store_id", storeId);
        command.Parameters.AddWithValue("expires_at", expiresAt);
        if (await command.ExecuteNonQueryAsync(cancellationToken) != 1)
            throw new InvalidOperationException("عضویت مدیر دیگر فعال نیست.");
    }

    public async Task<bool> IsSessionActiveAsync(Guid userId, string storeId, Guid sessionId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return false;
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("""
            select exists(
                select 1 from admin_user_sessions s
                join admin_users u on u.id=s.user_id and u.store_id=s.store_id
                where s.session_id=@session_id and s.user_id=@user_id and s.store_id=@store_id
                  and s.revoked_at is null and s.expires_at>now() and u.is_active=true
            );
            """, connection);
        command.Parameters.AddWithValue("session_id", sessionId);
        command.Parameters.AddWithValue("user_id", userId);
        command.Parameters.AddWithValue("store_id", storeId);
        return (bool)(await command.ExecuteScalarAsync(cancellationToken) ?? false);
    }

    public async Task RevokeSessionAsync(Guid userId, string storeId, Guid sessionId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        await using var connection = await OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("""
            update admin_user_sessions set revoked_at=coalesce(revoked_at,now())
            where session_id=@session_id and user_id=@user_id and store_id=@store_id;
            """, connection);
        command.Parameters.AddWithValue("session_id", sessionId);
        command.Parameters.AddWithValue("user_id", userId);
        command.Parameters.AddWithValue("store_id", storeId);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<AdminUserSummary?> SetStatusAsync(Guid id, bool isActive, string? storeId, string actor, string requestId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        await using var connection = await OpenAsync(cancellationToken);
        var before = await GetAsync(connection, id, cancellationToken);
        if (before is null || before.Role.Equals("Owner", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(before.StoreId, NormalizeStoreId(storeId), StringComparison.Ordinal)) return null;
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand("""
            update admin_users set is_active=@is_active, deactivated_at=case when @is_active then null else now() end
            where id=@id and store_id=@store_id;
            """, connection, transaction);
        command.Parameters.AddWithValue("is_active", isActive);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("store_id", NormalizeStoreId(storeId));
        if (await command.ExecuteNonQueryAsync(cancellationToken) == 0)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }
        if (!isActive)
        {
            await using var revoke = new NpgsqlCommand("""
                update admin_user_sessions set revoked_at=coalesce(revoked_at,now())
                where user_id=@id and store_id=@store_id and revoked_at is null;
                """, connection, transaction);
            revoke.Parameters.AddWithValue("id", id);
            revoke.Parameters.AddWithValue("store_id", NormalizeStoreId(storeId));
            await revoke.ExecuteNonQueryAsync(cancellationToken);
        }
        var updated = await GetAsync(connection, id, cancellationToken, transaction);
        if (updated is not null)
            await audit.RecordAsync(connection, transaction, actor, "admin-user.status-changed", "AdminUser", id.ToString(), before, updated, isActive ? "فعال‌سازی عضویت مدیر" : "غیرفعال‌سازی عضویت مدیر", requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return updated;
    }

    public async Task<AdminUserSummary?> SetPermissionsAsync(Guid id, IReadOnlyList<string> permissions, string? storeId, string actor, string requestId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        await using var connection = await OpenAsync(cancellationToken);
        var before = await GetAsync(connection, id, cancellationToken);
        if (before is null || before.Role.Equals("Owner", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(before.StoreId, NormalizeStoreId(storeId), StringComparison.Ordinal)) return null;
        var normalized = permissions.Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using (var command = new NpgsqlCommand("update admin_users set permissions_json=@permissions::jsonb where id=@id and store_id=@store_id;", connection, transaction))
        {
            command.Parameters.AddWithValue("permissions", JsonSerializer.Serialize(normalized));
            command.Parameters.AddWithValue("id", id);
            command.Parameters.AddWithValue("store_id", NormalizeStoreId(storeId));
            if (await command.ExecuteNonQueryAsync(cancellationToken) == 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return null;
            }
        }
        await using (var revoke = new NpgsqlCommand("update admin_user_sessions set revoked_at=coalesce(revoked_at,now()) where user_id=@id and store_id=@store_id and revoked_at is null;", connection, transaction))
        {
            revoke.Parameters.AddWithValue("id", id);
            revoke.Parameters.AddWithValue("store_id", NormalizeStoreId(storeId));
            await revoke.ExecuteNonQueryAsync(cancellationToken);
        }
        var updated = await GetAsync(connection, id, cancellationToken, transaction);
        if (updated is not null)
            await audit.RecordAsync(connection, transaction, actor, "admin-user.permissions-changed", "AdminUser", id.ToString(), before, updated, "به‌روزرسانی دسترسی‌های عضویت مدیر", requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return updated;
    }

    private const int PasswordIterations = 210_000;
    private const int PasswordSaltBytes = 16;
    private const int PasswordHashBytes = 32;

    public static bool IsValidPassword(string? password) => password is { Length: >= 12 and <= 128 };

    private static string CreateInvitationToken() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] HashToken(string token) => SHA256.HashData(Encoding.UTF8.GetBytes(token));

    private async Task<NpgsqlConnection> OpenAsync(CancellationToken cancellationToken)
    {
        var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }

    private static async Task<AdminUserSummary?> GetAsync(NpgsqlConnection connection, Guid id, CancellationToken cancellationToken, NpgsqlTransaction? transaction = null)
    {
        await using var command = new NpgsqlCommand("""
            select id,store_id,email,display_name,role,is_active,created_at,deactivated_at,password_hash is not null,permissions_json::text
            from admin_users where id=@id;
            """, connection, transaction);
        command.Parameters.AddWithValue("id", id);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken) ? Read(reader) : null;
    }

    private static async Task<IReadOnlyCollection<AdminUserSummary>> ReadManyAsync(NpgsqlCommand command, CancellationToken cancellationToken)
    {
        var result = new List<AdminUserSummary>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken)) result.Add(Read(reader));
        return result;
    }

    private static AdminUserSummary Read(NpgsqlDataReader reader)
    {
        var role = reader.GetString(4);
        return new AdminUserSummary(
            reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), role, reader.GetBoolean(5),
            ReadPermissions(role, reader.IsDBNull(9) ? null : reader.GetString(9)), reader.GetFieldValue<DateTimeOffset>(6), reader.IsDBNull(7) ? null : reader.GetFieldValue<DateTimeOffset>(7), reader.GetBoolean(8));
    }

    private static IReadOnlyList<string> ReadPermissions(string role, string? json) =>
        json is null ? AdminPermissionCatalog.Resolve(role) : JsonSerializer.Deserialize<string[]>(json) ?? [];

    private static string NormalizeStoreId(string? storeId) => string.IsNullOrWhiteSpace(storeId) ? DefaultStoreId : storeId.Trim();
}

public sealed class AdminUserSchemaInitializer(AdminUsersDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken) => database.InitializeAsync(cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

public sealed record AdminUserSummary(Guid Id, string StoreId, string Email, string DisplayName, string Role, bool IsActive, IReadOnlyList<string> Permissions, DateTimeOffset CreatedAt, DateTimeOffset? DeactivatedAt, bool HasPassword);
public sealed record AdminUserInvitation(AdminUserSummary User, string InvitationToken, DateTimeOffset ExpiresAt);
public sealed record AdminRoleSummary(string Role, IReadOnlyList<string> Permissions, string TitleFa);
public sealed record AdminUserCreateRequest(string Email, string DisplayName, string Role, IReadOnlyList<string>? Permissions = null)
{
    public Dictionary<string, string[]> Validate()
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(Email) || Email.Trim().Length > 320 || !MailAddress.TryCreate(Email.Trim(), out _)) errors[nameof(Email)] = ["ایمیل معتبر و غیرخالی وارد کنید."];
        if (string.IsNullOrWhiteSpace(DisplayName) || DisplayName.Trim().Length > 200) errors[nameof(DisplayName)] = ["نام نمایشی الزامی و حداکثر ۲۰۰ نویسه است."];
        if (!AdminPermissionCatalog.DefaultRoles.ContainsKey(Role?.Trim() ?? string.Empty) || string.Equals(Role?.Trim(), "Owner", StringComparison.OrdinalIgnoreCase)) errors[nameof(Role)] = ["نقش انتخاب‌شده معتبر نیست."];
        if (Permissions is not null && !AdminPermissionCatalog.AreValidPermissions(Permissions)) errors[nameof(Permissions)] = ["فهرست دسترسی‌ها معتبر نیست."];
        return errors;
    }
}
public sealed record AdminUserPermissionsRequest(IReadOnlyList<string> Permissions);
public sealed record AdminUserStatusRequest(bool IsActive);
public sealed class AdminUserValidationException(Dictionary<string, string[]> errors) : Exception("اطلاعات کاربر معتبر نیست.")
{
    public Dictionary<string, string[]> Errors { get; } = errors;
}
