using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using Npgsql;

public static class AdminSecurityExtensions
{
    public static IServiceCollection AddAdminSecurity(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddSingleton<AdminTokenService>();
        services.AddSingleton<OwnerAuthorizationFilter>();
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.AddFixedWindowLimiter("admin-login", limiter =>
            {
                limiter.PermitLimit = 5;
                limiter.Window = TimeSpan.FromMinutes(1);
                limiter.QueueLimit = 0;
                limiter.AutoReplenishment = true;
            });
        });
        return services;
    }

    public static IEndpointRouteBuilder MapAdminSecurity(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost("/api/v1/admin/auth/login", async Task<IResult> (
            AdminLoginRequest request, AdminTokenService tokens, AdminUsersDatabase users, CancellationToken cancellationToken) =>
        {
            if (!tokens.CanIssueTokens || (!tokens.IsConfigured && !users.IsConfigured))
                return Results.Problem(
                    title: "ورود مدیر پیکربندی نشده است.",
                    detail: "تنظیم کلید امضای نشست و دیتابیس کاربران الزامی است.",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            if (tokens.ValidateCredentials(request.Email, request.Password) &&
                (string.IsNullOrWhiteSpace(request.StoreId) || string.Equals(request.StoreId.Trim(), "default", StringComparison.Ordinal)))
            {
                var owner = tokens.Issue(request.Email);
                return Results.Ok(new
                {
                    accessToken = owner.Token,
                    tokenType = "Bearer",
                    expiresAt = owner.ExpiresAt,
                    role = owner.Role,
                    permissions = owner.Permissions,
                    email = tokens.OwnerEmail,
                    storeId = "default"
                });
            }

            var member = await users.AuthenticateAsync(request.Email, request.Password, request.StoreId, cancellationToken);
            if (member is null) return Results.Unauthorized();
            var issued = tokens.Issue(member);
            await users.CreateSessionAsync(member.Id, member.StoreId, issued.SessionId, issued.ExpiresAt, cancellationToken);
            return Results.Ok(new
            {
                accessToken = issued.Token,
                tokenType = "Bearer",
                expiresAt = issued.ExpiresAt,
                role = issued.Role,
                permissions = issued.Permissions,
                email = member.Email,
                storeId = member.StoreId
            });
        })
        .RequireRateLimiting("admin-login")
        .WithTags("Admin Auth");

        endpoints.MapPost("/api/v1/admin/auth/accept-invite", async Task<IResult> (
            AdminInviteAcceptRequest request, AdminUsersDatabase users, CancellationToken cancellationToken) =>
        {
            var accepted = await users.AcceptInvitationAsync(request.Token, request.Password, cancellationToken);
            return accepted
                ? Results.NoContent()
                : Results.BadRequest(new { message = "دعوت معتبر نیست یا منقضی شده است. از مدیر فروشگاه دعوت تازه بگیرید." });
        })
        .RequireRateLimiting("admin-login")
        .WithTags("Admin Auth");

        endpoints.MapGet("/api/v1/admin/auth/session", async Task<IResult> (
            AdminTokenService tokens, AdminUsersDatabase users, HttpContext context, CancellationToken cancellationToken) =>
        {
            var token = AdminTokenService.ReadBearerToken(context.Request);
            if (token is null || !tokens.TryValidate(token, out var principal)) return Results.Unauthorized();
            if (principal.UserId is Guid userId &&
                !await users.IsSessionActiveAsync(userId, principal.StoreId, principal.SessionId, cancellationToken))
                return Results.Unauthorized();
            return Results.Ok(new { authenticated = true, email = principal.Email, role = principal.Role, permissions = principal.Permissions, storeId = principal.StoreId, expiresAt = principal.ExpiresAt });
        })
        .WithTags("Admin Auth");

        endpoints.MapPost("/api/v1/admin/auth/logout", async Task<IResult> (
            AdminTokenService tokens, AdminUsersDatabase users, HttpContext context, CancellationToken cancellationToken) =>
        {
            var token = AdminTokenService.ReadBearerToken(context.Request);
            if (token is null || !tokens.TryValidate(token, out var principal)) return Results.Unauthorized();
            tokens.Revoke(token);
            if (principal.UserId is Guid userId)
                await users.RevokeSessionAsync(userId, principal.StoreId, principal.SessionId, cancellationToken);
            return Results.NoContent();
        })
        .WithTags("Admin Auth");

        endpoints.MapGet("/api/v1/admin/audit-log", async (
            string? entityType,
            string? entityId,
            int? limit,
            AdminAuditLogDatabase database,
            CancellationToken cancellationToken) =>
            Results.Ok(await database.ListAsync(entityType, entityId, Math.Clamp(limit ?? 100, 1, 250), cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>()
            .WithTags("Admin Security");

        endpoints.MapGet("/api/v1/admin/users", async (
            string? storeId,
            AdminUsersDatabase database,
            CancellationToken cancellationToken) =>
            Results.Ok(await database.ListAsync(storeId, cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>()
            .WithTags("Admin Users");

        endpoints.MapGet("/api/v1/admin/users/roles", () =>
            Results.Ok(AdminPermissionCatalog.DefaultRoles.Select(item => new AdminRoleSummary(
                item.Key,
                item.Value,
                AdminPermissionCatalog.RoleLabel(item.Key)))))
            .AddEndpointFilter<OwnerAuthorizationFilter>()
            .WithTags("Admin Users");

        endpoints.MapPost("/api/v1/admin/users", async (
            AdminUserCreateRequest request,
            string? storeId,
            AdminUsersDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            try
            {
                var created = await database.CreateAsync(request, actor, storeId, context.TraceIdentifier, cancellationToken);
                return Results.Created($"/api/v1/admin/users/{created.User.Id}", new { user = created.User, invitationToken = created.InvitationToken, expiresAt = created.ExpiresAt });
            }
            catch (AdminUserValidationException exception)
            {
                return Results.ValidationProblem(exception.Errors);
            }
            catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
            {
                return Results.Conflict(new { message = "کاربری با این ایمیل در این فروشگاه وجود دارد." });
            }
        })
        .AddEndpointFilter<OwnerAuthorizationFilter>()
        .WithTags("Admin Users");

        endpoints.MapPatch("/api/v1/admin/users/{id:guid}/status", async (
            Guid id,
            AdminUserStatusRequest request,
            string? storeId,
            AdminUsersDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var updated = await database.SetStatusAsync(id, request.IsActive, storeId, actor, context.TraceIdentifier, cancellationToken);
            return updated is null
                ? Results.NotFound(new { message = "کاربر پیدا نشد." })
                : Results.Ok(updated);
        })
        .AddEndpointFilter<OwnerAuthorizationFilter>()
        .WithTags("Admin Users");

        return endpoints;
    }
}

public sealed record AdminLoginRequest(string Email, string Password, string? StoreId = null);
public sealed record AdminInviteAcceptRequest(string Token, string Password);
public sealed record IssuedAdminToken(string Token, DateTimeOffset ExpiresAt, string Role, IReadOnlyList<string> Permissions, Guid SessionId);
public sealed record AdminPrincipal(string Email, DateTimeOffset ExpiresAt, string Role, IReadOnlyList<string> Permissions, Guid SessionId, Guid? UserId, string StoreId);

public static class AdminPermissionCatalog
{
    public const string DashboardRead = "dashboard.read";
    public const string OrdersRead = "orders.read";
    public const string OrdersWrite = "orders.write";
    public const string ProductsRead = "products.read";
    public const string ProductsWrite = "products.write";
    public const string InventoryRead = "inventory.read";
    public const string InventoryWrite = "inventory.write";
    public const string CustomersRead = "customers.read";
    public const string CustomersExport = "customers.export";
    public const string ReportsRead = "reports.read";
    public const string CategoriesRead = "categories.read";
    public const string CategoriesWrite = "categories.write";
    public const string PricingRead = "pricing.read";
    public const string PricingWrite = "pricing.write";
    public const string CorporateRead = "corporate.read";
    public const string CorporateWrite = "corporate.write";
    public const string ContentRead = "content.read";
    public const string ContentWrite = "content.write";
    public const string AuditRead = "audit.read";
    public const string SettingsWrite = "settings.write";
    public const string UsersRead = "users.read";
    public const string UsersWrite = "users.write";

    public static IReadOnlyList<string> Owner { get; } =
    [
        DashboardRead, OrdersRead, OrdersWrite, ProductsRead, ProductsWrite,
        InventoryRead, InventoryWrite, CustomersRead, CustomersExport, ReportsRead,
        CategoriesRead, CategoriesWrite, PricingRead, PricingWrite, CorporateRead,
        CorporateWrite, ContentRead, ContentWrite, AuditRead, SettingsWrite
    ];

    public static IReadOnlyDictionary<string, IReadOnlyList<string>> DefaultRoles { get; } =
        new Dictionary<string, IReadOnlyList<string>>(StringComparer.OrdinalIgnoreCase)
        {
            ["Owner"] = Owner,
            ["StoreManager"] = [DashboardRead, OrdersRead, OrdersWrite, ProductsRead, ProductsWrite, InventoryRead, InventoryWrite, CustomersRead, ReportsRead, CategoriesRead, CategoriesWrite, PricingRead, PricingWrite, CorporateRead, CorporateWrite, ContentRead, ContentWrite, SettingsWrite],
            ["SalesOperator"] = [DashboardRead, OrdersRead, OrdersWrite, CustomersRead, CorporateRead],
            ["WarehouseOperator"] = [DashboardRead, ProductsRead, InventoryRead, InventoryWrite, OrdersRead, OrdersWrite],
            ["Accountant"] = [DashboardRead, OrdersRead, ReportsRead, PricingRead],
            ["CustomerSupport"] = [DashboardRead, OrdersRead, OrdersWrite, CustomersRead],
            ["CorporateSales"] = [DashboardRead, CorporateRead, CorporateWrite, CustomersRead],
            ["ContentManager"] = [DashboardRead, ProductsRead, ProductsWrite, CategoriesRead, CategoriesWrite, ContentRead, ContentWrite],
            ["MarketingManager"] = [DashboardRead, ProductsRead, CustomersRead, ReportsRead, PricingRead, PricingWrite, ContentRead, ContentWrite, CorporateRead],
            ["ReadOnlyAnalyst"] = [DashboardRead, OrdersRead, ProductsRead, InventoryRead, CustomersRead, ReportsRead, PricingRead, CorporateRead],
        };

    public static string RoleLabel(string role) => role switch
    {
        "Owner" => "مدیر اصلی",
        "StoreManager" => "مدیر فروشگاه",
        "SalesOperator" => "اپراتور فروش",
        "WarehouseOperator" => "اپراتور انبار",
        "Accountant" => "حسابدار",
        "CustomerSupport" => "پشتیبانی مشتری",
        "CorporateSales" => "فروش سازمانی",
        "ContentManager" => "مدیر محتوا",
        "MarketingManager" => "مدیر بازاریابی",
        "ReadOnlyAnalyst" => "تحلیلگر فقط‌خواندنی",
        _ => role
    };

    public static string NormalizeRole(string? role) =>
        role is not null && DefaultRoles.ContainsKey(role.Trim()) ? role.Trim() : "Owner";

    public static IReadOnlyList<string> Resolve(string? role, IReadOnlyList<string>? overridePermissions = null)
    {
        if (overridePermissions is { Count: > 0 })
            return overridePermissions.Where(item => !string.IsNullOrWhiteSpace(item)).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        return DefaultRoles.TryGetValue(NormalizeRole(role), out var permissions) ? permissions : Owner;
    }

    public static bool Allows(AdminPrincipal principal, string permission) =>
        string.Equals(principal.Role, "Owner", StringComparison.OrdinalIgnoreCase) ||
        principal.Permissions.Contains(permission, StringComparer.OrdinalIgnoreCase);

    public static string? RequiredPermission(HttpContext context)
    {
        var path = context.Request.Path.Value ?? string.Empty;
        var method = context.Request.Method;
        if (path.StartsWith("/api/v1/admin/users", StringComparison.OrdinalIgnoreCase)) return HttpMethods.IsGet(method) ? UsersRead : UsersWrite;
        if (path.StartsWith("/api/v1/admin/audit-log", StringComparison.OrdinalIgnoreCase)) return AuditRead;
        if (path.StartsWith("/api/v1/admin/orders", StringComparison.OrdinalIgnoreCase)) return HttpMethods.IsGet(method) ? OrdersRead : OrdersWrite;
        if (path.StartsWith("/api/v1/admin/dashboard", StringComparison.OrdinalIgnoreCase) ||
            path.StartsWith("/api/v1/admin/analytics", StringComparison.OrdinalIgnoreCase) ||
            path.StartsWith("/api/v1/admin/notifications", StringComparison.OrdinalIgnoreCase)) return DashboardRead;
        if (path.StartsWith("/api/v1/admin/inventory/pricing", StringComparison.OrdinalIgnoreCase))
            return HttpMethods.IsGet(method) || path.EndsWith("/preview", StringComparison.OrdinalIgnoreCase) ? InventoryRead : PricingWrite;
        if (path.StartsWith("/api/v1/admin/inventory", StringComparison.OrdinalIgnoreCase)) return HttpMethods.IsGet(method) ? InventoryRead : InventoryWrite;
        if (path.StartsWith("/api/v1/admin/customers/export", StringComparison.OrdinalIgnoreCase)) return CustomersExport;
        if (path.StartsWith("/api/v1/admin/customers", StringComparison.OrdinalIgnoreCase)) return CustomersRead;
        if (path.StartsWith("/api/v1/admin/corporate-requests", StringComparison.OrdinalIgnoreCase)) return HttpMethods.IsGet(method) ? CorporateRead : CorporateWrite;
        if (path.StartsWith("/api/v1/admin/commerce/settings", StringComparison.OrdinalIgnoreCase)) return HttpMethods.IsGet(method) ? PricingRead : PricingWrite;
        if (path.StartsWith("/api/v1/admin/media/metadata", StringComparison.OrdinalIgnoreCase)) return ContentRead;
        if (path.StartsWith("/api/v1/admin/media", StringComparison.OrdinalIgnoreCase)) return ContentWrite;
        if (path.StartsWith("/api/v1/categories/admin", StringComparison.OrdinalIgnoreCase)) return CategoriesRead;
        if (path.StartsWith("/api/v1/categories", StringComparison.OrdinalIgnoreCase)) return CategoriesWrite;
        if (path.StartsWith("/api/v1/products/admin", StringComparison.OrdinalIgnoreCase)) return ProductsRead;
        if (path.StartsWith("/api/v1/products", StringComparison.OrdinalIgnoreCase)) return ProductsWrite;
        return null;
    }
}

public sealed class AdminTokenService
{
    private readonly byte[] _signingKey;
    private readonly byte[] _configuredPasswordHash;
    private readonly TimeSpan _lifetime;
    private readonly string _configuredRole;
    private readonly IReadOnlyList<string> _configuredPermissions;
    private readonly ConcurrentDictionary<string, DateTimeOffset> _revokedTokens = new(StringComparer.Ordinal);

    public AdminTokenService(IConfiguration configuration)
    {
        OwnerEmail = configuration["Admin:Email"]?.Trim().ToLowerInvariant() ?? string.Empty;
        _signingKey = Encoding.UTF8.GetBytes(configuration["Admin:TokenSigningKey"] ?? string.Empty);
        _configuredPasswordHash = ParseHex(configuration["Admin:PasswordHash"]);
        _lifetime = TimeSpan.FromMinutes(Math.Clamp(configuration.GetValue("Admin:AccessTokenMinutes", 15), 5, 60));
        _configuredRole = AdminPermissionCatalog.NormalizeRole(configuration["Admin:Role"]);
        _configuredPermissions = ParsePermissions(configuration["Admin:Permissions"]);
    }

    public string OwnerEmail { get; }
    public bool CanIssueTokens => _signingKey.Length >= 32;
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(OwnerEmail) &&
        CanIssueTokens &&
        _configuredPasswordHash.Length == 32;

    public bool ValidateCredentials(string? email, string? password)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(email) || string.IsNullOrEmpty(password)) return false;
        if (!string.Equals(email.Trim(), OwnerEmail, StringComparison.OrdinalIgnoreCase)) return false;
        var suppliedHash = SHA256.HashData(Encoding.UTF8.GetBytes(password));
        return CryptographicOperations.FixedTimeEquals(suppliedHash, _configuredPasswordHash);
    }

    public IssuedAdminToken Issue(string email) =>
        Issue(email, _configuredRole, AdminPermissionCatalog.Resolve(_configuredRole, _configuredPermissions), null, "default");

    public IssuedAdminToken Issue(AdminUserSummary member) =>
        Issue(member.Email, member.Role, member.Permissions, member.Id, member.StoreId);

    private IssuedAdminToken Issue(string email, string role, IReadOnlyList<string> permissions, Guid? userId, string storeId)
    {
        if (!CanIssueTokens) throw new InvalidOperationException("کلید امضای نشست تنظیم نشده است.");
        var expiresAt = DateTimeOffset.UtcNow.Add(_lifetime);
        var sessionId = Guid.NewGuid();
        var payload = $"{email.Trim().ToLowerInvariant()}|{expiresAt.ToUnixTimeSeconds()}|{sessionId:N}|{role}|{string.Join(',', permissions)}|{userId?.ToString("N") ?? string.Empty}|{Base64Url(Encoding.UTF8.GetBytes(storeId))}";
        var payloadBytes = Encoding.UTF8.GetBytes(payload);
        var signature = HMACSHA256.HashData(_signingKey, payloadBytes);
        var token = $"{Base64Url(payloadBytes)}.{Base64Url(signature)}";
        return new IssuedAdminToken(token, expiresAt, role, permissions, sessionId);
    }

    public void Revoke(string token)
    {
        var now = DateTimeOffset.UtcNow;
        _revokedTokens[Fingerprint(token)] = now;
        foreach (var item in _revokedTokens)
            if (now - item.Value > _lifetime) _revokedTokens.TryRemove(item.Key, out _);
    }

    public bool TryValidate(string token, out AdminPrincipal principal)
    {
        principal = default!;
        if (!CanIssueTokens) return false;
        var parts = token.Split('.', 2);
        if (parts.Length != 2 || !TryBase64Url(parts[0], out var payloadBytes) || !TryBase64Url(parts[1], out var signature)) return false;
        var expectedSignature = HMACSHA256.HashData(_signingKey, payloadBytes);
        if (!CryptographicOperations.FixedTimeEquals(signature, expectedSignature)) return false;
        if (_revokedTokens.ContainsKey(Fingerprint(token))) return false;

        var fields = Encoding.UTF8.GetString(payloadBytes).Split('|');
        if (fields.Length < 3 || !long.TryParse(fields[1], out var unixExpiry)) return false;
        var expiresAt = DateTimeOffset.FromUnixTimeSeconds(unixExpiry);
        if (expiresAt <= DateTimeOffset.UtcNow || !string.Equals(fields[0], OwnerEmail, StringComparison.OrdinalIgnoreCase)) return false;
        var role = fields.Length > 3 && !string.IsNullOrWhiteSpace(fields[3]) ? fields[3] : "Owner";
        var permissions = fields.Length > 4
            ? fields[4].Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            : AdminPermissionCatalog.Owner;
        if (!Guid.TryParseExact(fields[2], "N", out var sessionId)) return false;
        Guid? userId = fields.Length > 5 && Guid.TryParse(fields[5], out var parsedUserId) ? parsedUserId : null;
        var storeId = "default";
        if (fields.Length > 6)
        {
            if (!TryBase64Url(fields[6], out var storeBytes)) return false;
            storeId = Encoding.UTF8.GetString(storeBytes);
            if (string.IsNullOrWhiteSpace(storeId) || storeId.Length > 120) return false;
        }
        principal = new AdminPrincipal(fields[0], expiresAt, role, permissions, sessionId, userId, storeId);
        return true;
    }

    public static string? ReadBearerToken(HttpRequest request)
    {
        var value = request.Headers.Authorization.ToString();
        return value.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) ? value[7..].Trim() : null;
    }

    private static string Base64Url(byte[] value) => Convert.ToBase64String(value).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static string Fingerprint(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    private static bool TryBase64Url(string value, out byte[] bytes)
    {
        try
        {
            var normalized = value.Replace('-', '+').Replace('_', '/');
            normalized = normalized.PadRight(normalized.Length + ((4 - normalized.Length % 4) % 4), '=');
            bytes = Convert.FromBase64String(normalized);
            return true;
        }
        catch (FormatException)
        {
            bytes = [];
            return false;
        }
    }

    private static byte[] ParseHex(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length != 64) return [];
        try { return Convert.FromHexString(value); }
        catch (FormatException) { return []; }
    }

    private static IReadOnlyList<string> ParsePermissions(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? []
            : value.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}

public sealed class OwnerAuthorizationFilter(AdminTokenService tokens, AdminUsersDatabase users) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var token = AdminTokenService.ReadBearerToken(context.HttpContext.Request);
        if (token is null || !tokens.TryValidate(token, out var principal))
            return Results.Unauthorized();

        if (principal.UserId is Guid userId)
        {
            if (!await users.IsSessionActiveAsync(userId, principal.StoreId, principal.SessionId, context.HttpContext.RequestAborted))
                return Results.Unauthorized();
            var requestedStore = context.HttpContext.Request.Query["storeId"].ToString();
            if (!string.IsNullOrWhiteSpace(requestedStore) && !string.Equals(requestedStore.Trim(), principal.StoreId, StringComparison.Ordinal))
                return Results.Json(new { message = "به این فروشگاه دسترسی ندارید." }, statusCode: StatusCodes.Status403Forbidden);
        }

        context.HttpContext.Items["AdminPrincipal"] = principal;
        var requiredPermission = AdminPermissionCatalog.RequiredPermission(context.HttpContext);
        if (requiredPermission is not null && !AdminPermissionCatalog.Allows(principal, requiredPermission))
            return Results.Json(new { message = "این عملیات برای نقش فعلی مجاز نیست." }, statusCode: StatusCodes.Status403Forbidden);
        return await next(context);
    }
}
