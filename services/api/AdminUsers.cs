using System.Net.Mail;
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
            select id,email,display_name,role,is_active,created_at,deactivated_at
            from admin_users where store_id=@store_id order by created_at desc;
            """, connection);
        command.Parameters.AddWithValue("store_id", NormalizeStoreId(storeId));
        return await ReadManyAsync(command, cancellationToken);
    }

    public async Task<AdminUserSummary> CreateAsync(AdminUserCreateRequest request, string actor, string? storeId, string requestId, CancellationToken cancellationToken)
    {
        var validation = request.Validate();
        if (validation.Count > 0) throw new AdminUserValidationException(validation);
        await using var connection = await OpenAsync(cancellationToken);
        var id = Guid.NewGuid();
        await using var command = new NpgsqlCommand("""
            insert into admin_users(id,store_id,email,display_name,role,is_active,created_by,created_at)
            values(@id,@store_id,@email,@display_name,@role,true,@created_by,now());
            """, connection);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("store_id", NormalizeStoreId(storeId));
        command.Parameters.AddWithValue("email", request.Email.Trim().ToLowerInvariant());
        command.Parameters.AddWithValue("display_name", request.DisplayName.Trim());
        command.Parameters.AddWithValue("role", AdminPermissionCatalog.NormalizeRole(request.Role));
        command.Parameters.AddWithValue("created_by", actor.Trim());
        await command.ExecuteNonQueryAsync(cancellationToken);
        var created = await GetAsync(connection, id, cancellationToken);
        if (created is null) throw new InvalidOperationException("کاربر ایجادشده پیدا نشد.");
        await audit.RecordAsync(actor, "admin-user.created", "AdminUser", id.ToString(), null, created, "ایجاد عضویت مدیر فروشگاه", requestId, cancellationToken);
        return created;
    }

    public async Task<AdminUserSummary?> SetStatusAsync(Guid id, bool isActive, string? storeId, string actor, string requestId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        await using var connection = await OpenAsync(cancellationToken);
        var before = await GetAsync(connection, id, cancellationToken);
        if (before is null) return null;
        await using var command = new NpgsqlCommand("""
            update admin_users set is_active=@is_active, deactivated_at=case when @is_active then null else now() end
            where id=@id and store_id=@store_id;
            """, connection);
        command.Parameters.AddWithValue("is_active", isActive);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("store_id", NormalizeStoreId(storeId));
        if (await command.ExecuteNonQueryAsync(cancellationToken) == 0) return null;
        var updated = await GetAsync(connection, id, cancellationToken);
        if (updated is not null)
            await audit.RecordAsync(actor, "admin-user.status-changed", "AdminUser", id.ToString(), before, updated, isActive ? "فعال‌سازی عضویت مدیر" : "غیرفعال‌سازی عضویت مدیر", requestId, cancellationToken);
        return updated;
    }

    private async Task<NpgsqlConnection> OpenAsync(CancellationToken cancellationToken)
    {
        var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }

    private static async Task<AdminUserSummary?> GetAsync(NpgsqlConnection connection, Guid id, CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand("""
            select id,email,display_name,role,is_active,created_at,deactivated_at from admin_users where id=@id;
            """, connection);
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
        var role = reader.GetString(3);
        return new AdminUserSummary(
            reader.GetGuid(0), reader.GetString(1), reader.GetString(2), role, reader.GetBoolean(4),
            AdminPermissionCatalog.Resolve(role), reader.GetFieldValue<DateTimeOffset>(5), reader.IsDBNull(6) ? null : reader.GetFieldValue<DateTimeOffset>(6));
    }

    private static string NormalizeStoreId(string? storeId) => string.IsNullOrWhiteSpace(storeId) ? DefaultStoreId : storeId.Trim();
}

public sealed class AdminUserSchemaInitializer(AdminUsersDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken) => database.InitializeAsync(cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

public sealed record AdminUserSummary(Guid Id, string Email, string DisplayName, string Role, bool IsActive, IReadOnlyList<string> Permissions, DateTimeOffset CreatedAt, DateTimeOffset? DeactivatedAt);
public sealed record AdminUserCreateRequest(string Email, string DisplayName, string Role)
{
    public Dictionary<string, string[]> Validate()
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(Email) || Email.Length > 320 || !MailAddress.TryCreate(Email.Trim(), out _)) errors[nameof(Email)] = ["ایمیل معتبر و غیرخالی وارد کنید."];
        if (string.IsNullOrWhiteSpace(DisplayName) || DisplayName.Trim().Length > 200) errors[nameof(DisplayName)] = ["نام نمایشی الزامی و حداکثر ۲۰۰ نویسه است."];
        if (!AdminPermissionCatalog.DefaultRoles.ContainsKey(Role?.Trim() ?? string.Empty)) errors[nameof(Role)] = ["نقش انتخاب‌شده معتبر نیست."];
        return errors;
    }
}
public sealed record AdminUserStatusRequest(bool IsActive);
public sealed class AdminUserValidationException(Dictionary<string, string[]> errors) : Exception("اطلاعات کاربر معتبر نیست.")
{
    public Dictionary<string, string[]> Errors { get; } = errors;
}
