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
        services.AddSingleton<UserMutationTargetAuthorizationFilter>();
        services.AddSingleton<StepUpAuthorizationFilter>();
        services.AddSingleton<OrderCancellationStepUpAuthorizationFilter>();
        services.AddSingleton<OrderShippingCostStepUpAuthorizationFilter>();
        services.AddSingleton<ProductPriceStepUpAuthorizationFilter>();
        services.AddSingleton<ProductCreatePriceStepUpAuthorizationFilter>();
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
            options.AddFixedWindowLimiter("admin-step-up", limiter =>
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
                if (tokens.IsMfaRequiredForRole(tokens.ConfiguredRole) && !users.IsConfigured)
                    return TotpReplayPersistenceUnavailable();
                var ownerUserId = await users.FindOwnerMembershipIdAsync(tokens.OwnerEmail, cancellationToken);
                if (users.IsConfigured && ownerUserId is null)
                    return Results.Problem(
                        title: "نشست مدیر اصلی آماده نیست.",
                        detail: "پیش از ورود، عضویت مدیر اصلی را با مرحلهٔ seed-admin ایجاد کنید.",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                var mfaFailure = await GetMfaFailureAsync(tokens, users, tokens.ConfiguredRole, request.MfaCode, cancellationToken);
                if (mfaFailure is not null) return mfaFailure;
                var mfaVerified = tokens.IsMfaRequiredForRole(tokens.ConfiguredRole);
                var owner = tokens.Issue(request.Email, ownerUserId, mfaVerified);
                if (ownerUserId is Guid userId)
                    await users.CreateSessionAsync(userId, "default", owner.SessionId, owner.ExpiresAt, cancellationToken);
                return Results.Ok(new
                {
                    accessToken = owner.Token,
                    tokenType = "Bearer",
                    expiresAt = owner.ExpiresAt,
                    role = owner.Role,
                    permissions = owner.Permissions,
                    email = tokens.OwnerEmail,
                    storeId = "default",
                    mfaVerified
                });
            }

            var member = await users.AuthenticateAsync(request.Email, request.Password, request.StoreId, cancellationToken);
            if (member is null) return Results.Unauthorized();
            var memberMfaFailure = await GetMfaFailureAsync(tokens, users, member.Role, request.MfaCode, cancellationToken);
            if (memberMfaFailure is not null) return memberMfaFailure;
            var memberMfaVerified = tokens.IsMfaRequiredForRole(member.Role);
            var issued = tokens.Issue(member, memberMfaVerified);
            await users.CreateSessionAsync(member.Id, member.StoreId, issued.SessionId, issued.ExpiresAt, cancellationToken);
            return Results.Ok(new
            {
                accessToken = issued.Token,
                tokenType = "Bearer",
                expiresAt = issued.ExpiresAt,
                role = issued.Role,
                permissions = issued.Permissions,
                email = member.Email,
                storeId = member.StoreId,
                mfaVerified = memberMfaVerified
            });
        })
        .RequireRateLimiting("admin-login")
        .WithTags("Admin Auth");

        endpoints.MapPost("/api/v1/admin/auth/accept-invite", async Task<IResult> (
            AdminInviteAcceptRequest request, AdminUsersDatabase users, AdminAuditLogDatabase audit, HttpContext context, CancellationToken cancellationToken) =>
        {
            var accepted = await users.AcceptInvitationAsync(request.Token, request.Password, context.TraceIdentifier, audit, cancellationToken);
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
            if (tokens.IsMfaRequiredForRole(principal.Role) && !principal.MfaVerified)
                return MfaRequiredResult();
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

        endpoints.MapPost("/api/v1/admin/auth/step-up", async Task<IResult> (
            AdminStepUpRequest request,
            AdminTokenService tokens,
            AdminUsersDatabase users,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var bearer = AdminTokenService.ReadBearerToken(context.Request);
            if (bearer is null || !tokens.TryValidate(bearer, out var principal))
                return Results.Unauthorized();

            if (principal.UserId is Guid userId)
            {
                if (!await users.IsSessionActiveAsync(userId, principal.StoreId, principal.SessionId, cancellationToken))
                    return Results.Unauthorized();
                if (principal.StoreId == "default" &&
                    string.Equals(principal.Email, tokens.OwnerEmail, StringComparison.OrdinalIgnoreCase))
                {
                    if (!tokens.ValidateCredentials(principal.Email, request.Password))
                        return Results.Json(new { message = "رمز عبور تأیید نشد." }, statusCode: StatusCodes.Status403Forbidden);
                }
                else
                {
                    var member = await users.AuthenticateAsync(principal.Email, request.Password, principal.StoreId, cancellationToken);
                    if (member is null || member.Id != userId || !string.Equals(member.StoreId, principal.StoreId, StringComparison.Ordinal))
                        return Results.Json(new { message = "رمز عبور تأیید نشد." }, statusCode: StatusCodes.Status403Forbidden);
                }
            }
            else if (!tokens.ValidateCredentials(principal.Email, request.Password))
            {
                return Results.Json(new { message = "رمز عبور تأیید نشد." }, statusCode: StatusCodes.Status403Forbidden);
            }

            var mfaFailure = await GetMfaFailureAsync(
                tokens, users, principal.Role, request.MfaCode, cancellationToken,
                requireSensitiveOwnerMfa: true);
            if (mfaFailure is not null) return mfaFailure;

            var issued = tokens.IssueStepUp(principal);
            return Results.Ok(new { stepUpToken = issued.Token, expiresAt = issued.ExpiresAt });
        })
        .RequireRateLimiting("admin-step-up")
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
            HttpContext context,
            CancellationToken cancellationToken) =>
            Results.Ok(await database.ListAsync(ResolveMembershipStore(context, storeId), cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>()
            .WithTags("Admin Users");

        endpoints.MapGet("/api/v1/admin/users/{id:guid}/sessions", async (
            Guid id, string? storeId, AdminUsersDatabase database, HttpContext context, CancellationToken cancellationToken) =>
            Results.Ok(await database.ListActiveSessionsAsync(id, ResolveMembershipStore(context, storeId), cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>()
            .AddEndpointFilter<UserMutationTargetAuthorizationFilter>()
            .WithTags("Admin Users");

        endpoints.MapPost("/api/v1/admin/users/{id:guid}/sessions/{sessionId:guid}/revoke", async (
            Guid id, Guid sessionId, string? storeId, AdminUsersDatabase database, HttpContext context, CancellationToken cancellationToken) =>
        {
            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var revoked = await database.RevokeManagedSessionAsync(
                id, sessionId, ResolveMembershipStore(context, storeId), actor, context.TraceIdentifier, cancellationToken);
            return revoked
                ? Results.NoContent()
                : Results.NotFound(new { message = "نشست فعال پیدا نشد؛ فهرست را دوباره بارگذاری کنید." });
        })
        .AddEndpointFilter<OwnerAuthorizationFilter>()
        .AddEndpointFilter<UserMutationTargetAuthorizationFilter>()
        .AddEndpointFilter<StepUpAuthorizationFilter>()
        .WithMetadata(new StepUpPermissionRequirement(AdminPermissionCatalog.UsersWrite))
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
                var created = await database.CreateAsync(request, actor, ResolveMembershipStore(context, storeId), context.TraceIdentifier, cancellationToken);
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
        .AddEndpointFilter<StepUpAuthorizationFilter>()
        .WithMetadata(new StepUpPermissionRequirement(AdminPermissionCatalog.UsersWrite))
        .WithTags("Admin Users");

        endpoints.MapPatch("/api/v1/admin/users/{id:guid}/permissions", async (
            Guid id, AdminUserPermissionsRequest request, string? storeId, AdminUsersDatabase database,
            HttpContext context, CancellationToken cancellationToken) =>
        {
            if (!AdminPermissionCatalog.AreValidPermissions(request.Permissions))
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(request.Permissions)] = ["فهرست دسترسی‌ها معتبر نیست."] });
            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var updated = await database.SetPermissionsAsync(id, request.Permissions, ResolveMembershipStore(context, storeId), actor, context.TraceIdentifier, cancellationToken);
            return updated is null
                ? Results.NotFound(new { message = "کاربر پیدا نشد یا امکان ویرایش دسترسی مدیر اصلی وجود ندارد." })
                : Results.Ok(updated);
        })
        .AddEndpointFilter<OwnerAuthorizationFilter>()
        .AddEndpointFilter<UserMutationTargetAuthorizationFilter>()
        .AddEndpointFilter<StepUpAuthorizationFilter>()
        .WithMetadata(new StepUpPermissionRequirement(AdminPermissionCatalog.UsersWrite))
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
            var updated = await database.SetStatusAsync(id, request.IsActive, ResolveMembershipStore(context, storeId), actor, context.TraceIdentifier, cancellationToken);
            return updated is null
                ? Results.NotFound(new { message = "کاربر پیدا نشد." })
                : Results.Ok(updated);
        })
        .AddEndpointFilter<OwnerAuthorizationFilter>()
        .AddEndpointFilter<UserMutationTargetAuthorizationFilter>()
        .AddEndpointFilter<StepUpAuthorizationFilter>()
        .WithMetadata(new StepUpPermissionRequirement(AdminPermissionCatalog.UsersWrite))
        .WithTags("Admin Users");

        return endpoints;
    }

    private static async Task<IResult?> GetMfaFailureAsync(
        AdminTokenService tokens,
        AdminUsersDatabase users,
        string role,
        string? code,
        CancellationToken cancellationToken,
        bool requireSensitiveOwnerMfa = false)
    {
        long? timeStep;
        var validation = requireSensitiveOwnerMfa
            ? tokens.ValidateSensitiveActionMfaCode(role, code, out timeStep)
            : tokens.ValidateMfaCode(role, code, out timeStep);
        switch (validation)
        {
            case AdminMfaValidationResult.NotRequired:
                return null;
            case AdminMfaValidationResult.NotConfigured:
                return Results.Problem(
                    title: "تأیید دومرحله‌ای پیکربندی نشده است.",
                    detail: "برای حساب مدیر اصلی، Admin__Mfa__TotpSecret را در secret manager ثبت کنید.",
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            case AdminMfaValidationResult.Missing:
                return MfaRequiredResult();
            case AdminMfaValidationResult.Invalid:
                return InvalidMfaResult();
            case AdminMfaValidationResult.Valid:
                if (!users.IsConfigured) return TotpReplayPersistenceUnavailable();
                if (timeStep is not long acceptedStep) return InvalidMfaResult();
                return await users.TryConsumeTotpTimeStepAsync("configured-owner", acceptedStep, cancellationToken)
                    ? null
                    : InvalidMfaResult();
            default:
                return InvalidMfaResult();
        }
    }

    internal static IResult MfaRequiredResult() => Results.Json(
        new { message = "کد تأیید دومرحله‌ای لازم است.", code = "mfa_required" },
        statusCode: StatusCodes.Status428PreconditionRequired);

    private static IResult InvalidMfaResult() => Results.Json(
        new { message = "کد تأیید دومرحله‌ای معتبر نیست.", code = "mfa_invalid" },
        statusCode: StatusCodes.Status403Forbidden);

    private static IResult TotpReplayPersistenceUnavailable() => Results.Problem(
        title: "ذخیره‌سازی امن کد تأیید آماده نیست.",
        detail: "برای جلوگیری از استفادهٔ دوبارهٔ کد، اتصال دیتابیس مدیران و migrationهای آن لازم است.",
        statusCode: StatusCodes.Status503ServiceUnavailable);

    private static string? ResolveMembershipStore(HttpContext context, string? requestedStoreId)
    {
        var principal = context.Items["AdminPrincipal"] as AdminPrincipal;
        return principal?.UserId is not null && context.Items["ConfiguredOwnerSession"] is not true
            ? principal.StoreId
            : requestedStoreId;
    }
}

public sealed record AdminLoginRequest(string Email, string Password, string? StoreId = null, string? MfaCode = null);
public sealed record AdminInviteAcceptRequest(string Token, string Password);
public sealed record AdminStepUpRequest(string Password, string? MfaCode = null);
public sealed record IssuedAdminToken(string Token, DateTimeOffset ExpiresAt, string Role, IReadOnlyList<string> Permissions, Guid SessionId);
public sealed record IssuedAdminStepUpToken(string Token, DateTimeOffset ExpiresAt);
public sealed record AdminPrincipal(string Email, DateTimeOffset ExpiresAt, string Role, IReadOnlyList<string> Permissions, Guid SessionId, Guid? UserId, string StoreId, bool MfaVerified = false);

public static class AdminPermissionCatalog
{
    public const string UnmappedAdminRoute = "admin.unmapped.owner-only";
    public const string DashboardRead = "dashboard.read";
    public const string OrdersRead = "orders.read";
    public const string OrdersExport = "orders.export";
    public const string OrdersDocumentsRead = "orders.documents.read";
    public const string OrdersWrite = "orders.write";
    public const string ProductsRead = "products.read";
    public const string ProductsWrite = "products.write";
    public const string InventoryRead = "inventory.read";
    public const string InventoryWrite = "inventory.write";
    public const string CustomersRead = "customers.read";
    public const string CustomersExport = "customers.export";
    public const string CustomersPiiRead = "customers.pii.read";
    public const string ReportsRead = "reports.read";
    public const string CategoriesRead = "categories.read";
    public const string CategoriesWrite = "categories.write";
    public const string PricingRead = "pricing.read";
    public const string PricingWrite = "pricing.write";
    public const string SettingsRead = "settings.read";
    public const string SettingsWrite = "settings.write";
    public const string CorporateRead = "corporate.read";
    public const string CorporateWrite = "corporate.write";
    public const string ContentRead = "content.read";
    public const string ContentWrite = "content.write";
    public const string AuditRead = "audit.read";
    public const string UsersRead = "users.read";
    public const string UsersWrite = "users.write";

    public static IReadOnlyList<string> Owner { get; } =
    [
        DashboardRead, OrdersRead, OrdersWrite, OrdersExport, OrdersDocumentsRead, ProductsRead, ProductsWrite,
        InventoryRead, InventoryWrite, CustomersRead, CustomersExport, CustomersPiiRead, ReportsRead,
        CategoriesRead, CategoriesWrite, PricingRead, PricingWrite, CorporateRead,
        CorporateWrite, ContentRead, ContentWrite, AuditRead, SettingsRead, SettingsWrite
    ];

    public static IReadOnlyList<string> AllPermissions { get; } =
    [
        DashboardRead, OrdersRead, OrdersWrite, OrdersExport, OrdersDocumentsRead,
        ProductsRead, ProductsWrite, InventoryRead, InventoryWrite, CustomersRead,
        CustomersPiiRead, CustomersExport, ReportsRead,
        CategoriesRead, CategoriesWrite, PricingRead, PricingWrite, CorporateRead,
        CorporateWrite, ContentRead, ContentWrite, AuditRead, SettingsRead, SettingsWrite
    ];

    public static bool AreValidPermissions(IEnumerable<string>? permissions) =>
        permissions is not null && permissions.All(permission => AllPermissions.Contains(permission, StringComparer.OrdinalIgnoreCase));

    public static IReadOnlyDictionary<string, IReadOnlyList<string>> DefaultRoles { get; } =
        new Dictionary<string, IReadOnlyList<string>>(StringComparer.OrdinalIgnoreCase)
        {
            ["Owner"] = Owner,
            ["StoreManager"] = [DashboardRead, OrdersRead, OrdersWrite, OrdersExport, OrdersDocumentsRead, ProductsRead, ProductsWrite, InventoryRead, InventoryWrite, CustomersRead, CustomersPiiRead, ReportsRead, CategoriesRead, CategoriesWrite, PricingRead, PricingWrite, CorporateRead, CorporateWrite, ContentRead, ContentWrite, SettingsRead, SettingsWrite],
            ["SalesOperator"] = [DashboardRead, OrdersRead, OrdersWrite, OrdersDocumentsRead, CustomersRead, CustomersPiiRead, CorporateRead],
            ["WarehouseOperator"] = [DashboardRead, ProductsRead, InventoryRead, InventoryWrite, OrdersRead, OrdersWrite, OrdersDocumentsRead, CustomersPiiRead],
            ["Accountant"] = [DashboardRead, OrdersRead, OrdersExport, ReportsRead, PricingRead],
            ["CustomerSupport"] = [DashboardRead, OrdersRead, OrdersWrite, OrdersDocumentsRead, CustomersRead, CustomersPiiRead],
            ["CorporateSales"] = [DashboardRead, CorporateRead, CorporateWrite, CustomersRead, CustomersPiiRead],
            ["ContentManager"] = [DashboardRead, ProductsRead, ProductsWrite, CategoriesRead, CategoriesWrite, ContentRead, ContentWrite],
            ["MarketingManager"] = [DashboardRead, ProductsRead, CustomersRead, CustomersPiiRead, ReportsRead, PricingRead, PricingWrite, ContentRead, ContentWrite, CorporateRead],
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
        var normalizedRole = role?.Trim() ?? string.Empty;
        if (!DefaultRoles.ContainsKey(normalizedRole))
            return Array.Empty<string>();

        if (overridePermissions is not null)
            return overridePermissions.Where(item => !string.IsNullOrWhiteSpace(item)).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        return DefaultRoles[normalizedRole];
    }

    public static bool Allows(AdminPrincipal principal, string permission)
    {
        if (string.Equals(permission, UnmappedAdminRoute, StringComparison.OrdinalIgnoreCase))
            return string.Equals(principal.Role, "Owner", StringComparison.OrdinalIgnoreCase);

        return string.Equals(principal.Role, "Owner", StringComparison.OrdinalIgnoreCase) ||
            principal.Permissions.Contains(permission, StringComparer.OrdinalIgnoreCase);
    }

    public static string? RequiredPermission(HttpContext context)
    {
        var path = (context.Request.Path.Value ?? string.Empty).TrimEnd('/');
        var method = context.Request.Method;
        if (IsUnderPath(context, "/api/v1/admin/users")) return HttpMethods.IsGet(method) ? UsersRead : UsersWrite;
        if (IsUnderPath(context, "/api/v1/admin/audit-log")) return AuditRead;
        if (HttpMethods.IsGet(method) && path.Equals("/api/v1/admin/orders/export.csv", StringComparison.OrdinalIgnoreCase)) return OrdersExport;
        if (IsOrderDocument(context)) return OrdersDocumentsRead;
        if (IsUnderPath(context, "/api/v1/admin/shipping/overdue")) return OrdersRead;
        if (IsUnderPath(context, "/api/v1/admin/orders")) return HttpMethods.IsGet(method) ? OrdersRead : OrdersWrite;
        if (IsUnderPath(context, "/api/v1/admin/dashboard") || IsUnderPath(context, "/api/v1/admin/notifications")) return DashboardRead;
        if (IsUnderPath(context, "/api/v1/admin/analytics")) return ReportsRead;
        if (IsUnderPath(context, "/api/v1/admin/inventory/pricing"))
            return path.EndsWith("/apply", StringComparison.OrdinalIgnoreCase) ? PricingWrite : PricingRead;
        if (IsUnderPath(context, "/api/v1/admin/inventory")) return HttpMethods.IsGet(method) ? InventoryRead : InventoryWrite;
        if (HttpMethods.IsGet(method) && path.Equals("/api/v1/admin/customers/export.csv", StringComparison.OrdinalIgnoreCase)) return CustomersExport;
        if (IsUnderPath(context, "/api/v1/admin/customers")) return CustomersRead;
        if (IsUnderPath(context, "/api/v1/admin/corporate-requests")) return HttpMethods.IsGet(method) ? CorporateRead : CorporateWrite;
        if (IsUnderPath(context, "/api/v1/admin/commerce/settings")) return HttpMethods.IsGet(method) ? SettingsRead : SettingsWrite;
        if (IsUnderPath(context, "/api/v1/admin/media/metadata")) return ContentRead;
        if (IsUnderPath(context, "/api/v1/admin/media")) return ContentWrite;
        if (IsUnderPath(context, "/api/v1/categories/admin")) return CategoriesRead;
        if (IsUnderPath(context, "/api/v1/categories")) return CategoriesWrite;
        if (IsUnderPath(context, "/api/v1/products/admin")) return ProductsRead;
        if (IsUnderPath(context, "/api/v1/products")) return ProductsWrite;
        return context.Request.Path.StartsWithSegments(
            new PathString("/api/v1/admin"),
            StringComparison.OrdinalIgnoreCase)
            ? UnmappedAdminRoute
            : null;
    }

    private static bool IsUnderPath(HttpContext context, string path)
    {
        var requestPath = context.Request.Path.Value ?? string.Empty;
        return requestPath.StartsWith(path, StringComparison.OrdinalIgnoreCase) &&
            (requestPath.Length == path.Length || requestPath[path.Length] == '/');
    }
    public static bool IsOrderDocument(HttpContext context)
    {
        var path = (context.Request.Path.Value ?? string.Empty).TrimEnd('/');
        return HttpMethods.IsGet(context.Request.Method) && path.StartsWith("/api/v1/admin/orders/", StringComparison.OrdinalIgnoreCase) &&
            (path.EndsWith("/invoice", StringComparison.OrdinalIgnoreCase) || path.EndsWith("/packing-slip", StringComparison.OrdinalIgnoreCase));
    }

    public static bool AllowsSensitiveAdminOutput(HttpContext context, AdminPrincipal principal)
    {
        var path = (context.Request.Path.Value ?? string.Empty).TrimEnd('/');
        if (IsOrderDocument(context))
            return Allows(principal, OrdersRead) && Allows(principal, CustomersPiiRead);
        if (path.Equals("/api/v1/admin/orders/export.csv", StringComparison.OrdinalIgnoreCase))
            return Allows(principal, OrdersRead);
        if (path.Equals("/api/v1/admin/audit-log", StringComparison.OrdinalIgnoreCase) &&
            RequiresOrderAuditPii(context))
            return Allows(principal, CustomersPiiRead);
        return true;
    }

    private static bool RequiresOrderAuditPii(HttpContext context)
    {
        var entityType = context.Request.Query["entityType"].ToString().Trim();
        // An unfiltered audit query can include order snapshots, so it needs the
        // same PII permission as an explicitly filtered order audit query.
        return string.IsNullOrEmpty(entityType) ||
            string.Equals(entityType, "Order", StringComparison.OrdinalIgnoreCase);
    }

}

public enum AdminMfaValidationResult { NotRequired, NotConfigured, Missing, Invalid, Valid }

public sealed class AdminTokenService
{
    private readonly byte[] _signingKey;
    private readonly byte[] _configuredPasswordHash;
    private readonly TimeSpan _lifetime;
    private readonly string _configuredRole;
    private readonly IReadOnlyList<string> _configuredPermissions;
    private readonly bool _mfaRequired;
    private readonly bool _sensitiveActionsMfaRequired;
    private readonly string? _mfaTotpSecret;
    private readonly bool _mfaSecretIsValid;
    private readonly ConcurrentDictionary<string, DateTimeOffset> _revokedTokens = new(StringComparer.Ordinal);

    public AdminTokenService(IConfiguration configuration)
    {
        OwnerEmail = configuration["Admin:Email"]?.Trim().ToLowerInvariant() ?? string.Empty;
        _signingKey = Encoding.UTF8.GetBytes(configuration["Admin:TokenSigningKey"] ?? string.Empty);
        _configuredPasswordHash = ParseHex(configuration["Admin:PasswordHash"]);
        _lifetime = TimeSpan.FromMinutes(Math.Clamp(configuration.GetValue("Admin:AccessTokenMinutes", 15), 5, 60));
        _configuredRole = AdminPermissionCatalog.NormalizeRole(configuration["Admin:Role"]);
        _configuredPermissions = ParsePermissions(configuration["Admin:Permissions"]);
        _mfaRequired = configuration.GetValue("Admin:Mfa:Required", false);
        _sensitiveActionsMfaRequired = configuration.GetValue("Admin:Mfa:SensitiveActionsRequired", true);
        _mfaTotpSecret = configuration["Admin:Mfa:TotpSecret"]?.Trim();
        _mfaSecretIsValid = AdminTotpAuthenticator.IsValidSecret(_mfaTotpSecret);
    }

    public string OwnerEmail { get; }
    public string ConfiguredRole => _configuredRole;
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

    public bool IsMfaRequiredForRole(string role) =>
        _mfaRequired && string.Equals(role, "Owner", StringComparison.OrdinalIgnoreCase);

    public AdminMfaValidationResult ValidateMfaCode(string role, string? code)
        => ValidateMfaCode(role, code, out _);

    public AdminMfaValidationResult ValidateMfaCode(string role, string? code, out long? timeStep)
    {
        return ValidateMfaCode(role, code, out timeStep, IsMfaRequiredForRole(role));
    }

    public AdminMfaValidationResult ValidateSensitiveActionMfaCode(string role, string? code, out long? timeStep)
    {
        var requiredForOwner = string.Equals(role, "Owner", StringComparison.OrdinalIgnoreCase) &&
            _sensitiveActionsMfaRequired;
        return ValidateMfaCode(role, code, out timeStep,
            IsMfaRequiredForRole(role) || requiredForOwner);
    }

    private AdminMfaValidationResult ValidateMfaCode(
        string role, string? code, out long? timeStep, bool required)
    {
        timeStep = null;
        if (!required) return AdminMfaValidationResult.NotRequired;
        if (!_mfaSecretIsValid) return AdminMfaValidationResult.NotConfigured;
        if (string.IsNullOrWhiteSpace(code)) return AdminMfaValidationResult.Missing;
        timeStep = AdminTotpAuthenticator.GetMatchingTimeStep(_mfaTotpSecret, code, DateTimeOffset.UtcNow);
        return timeStep is not null ? AdminMfaValidationResult.Valid : AdminMfaValidationResult.Invalid;
    }

    public IssuedAdminToken Issue(string email) =>
        Issue(email, _configuredRole, AdminPermissionCatalog.Resolve(_configuredRole, _configuredPermissions.Count == 0 ? null : _configuredPermissions), null, "default", false);

    public IssuedAdminToken Issue(string email, Guid? userId, bool mfaVerified = false) =>
        Issue(email, _configuredRole, AdminPermissionCatalog.Resolve(_configuredRole, _configuredPermissions.Count == 0 ? null : _configuredPermissions), userId, "default", mfaVerified);

    public IssuedAdminToken Issue(AdminUserSummary member, bool mfaVerified = false) =>
        Issue(member.Email, member.Role, member.Permissions, member.Id, member.StoreId, mfaVerified);

    public IssuedAdminStepUpToken IssueStepUp(AdminPrincipal principal)
    {
        if (!CanIssueTokens) throw new InvalidOperationException("کلید امضای نشست تنظیم نشده است.");
        var expiresAtUnix = Math.Min(DateTimeOffset.UtcNow.AddMinutes(5).ToUnixTimeSeconds(), principal.ExpiresAt.ToUnixTimeSeconds());
        var expiresAt = DateTimeOffset.FromUnixTimeSeconds(expiresAtUnix);
        var payload = $"{principal.SessionId:N}|{principal.UserId?.ToString("N") ?? string.Empty}|{expiresAt.ToUnixTimeSeconds()}|{Base64Url(Encoding.UTF8.GetBytes(principal.StoreId))}";
        var payloadBytes = Encoding.UTF8.GetBytes(payload);
        var signature = HMACSHA256.HashData(_signingKey, Encoding.UTF8.GetBytes($"step-up|{payload}"));
        return new IssuedAdminStepUpToken($"{Base64Url(payloadBytes)}.{Base64Url(signature)}", expiresAt);
    }

    public bool TryValidateStepUp(string token, AdminPrincipal principal)
    {
        var parts = token.Split('.', 2);
        if (parts.Length != 2 || !TryBase64Url(parts[0], out var payloadBytes) || !TryBase64Url(parts[1], out var signature)) return false;
        var payload = Encoding.UTF8.GetString(payloadBytes);
        var expected = HMACSHA256.HashData(_signingKey, Encoding.UTF8.GetBytes($"step-up|{payload}"));
        if (!CryptographicOperations.FixedTimeEquals(signature, expected)) return false;
        var fields = payload.Split('|');
        if (fields.Length != 4 ||
            !Guid.TryParseExact(fields[0], "N", out var sessionId) ||
            !long.TryParse(fields[2], out var unixExpiry) ||
            !TryBase64Url(fields[3], out var storeBytes)) return false;
        var userIdText = principal.UserId?.ToString("N") ?? string.Empty;
        var storeId = Encoding.UTF8.GetString(storeBytes);
        var expiresAt = DateTimeOffset.FromUnixTimeSeconds(unixExpiry);
        return sessionId == principal.SessionId &&
            string.Equals(fields[1], userIdText, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(storeId, principal.StoreId, StringComparison.Ordinal) &&
            expiresAt > DateTimeOffset.UtcNow &&
            expiresAt <= DateTimeOffset.UtcNow.AddMinutes(5) &&
            expiresAt <= principal.ExpiresAt;
    }

    private IssuedAdminToken Issue(string email, string role, IReadOnlyList<string> permissions, Guid? userId, string storeId, bool mfaVerified)
    {
        if (!CanIssueTokens) throw new InvalidOperationException("کلید امضای نشست تنظیم نشده است.");
        var expiresAt = DateTimeOffset.UtcNow.Add(_lifetime);
        var sessionId = Guid.NewGuid();
        var payload = $"{email.Trim().ToLowerInvariant()}|{expiresAt.ToUnixTimeSeconds()}|{sessionId:N}|{role}|{string.Join(',', permissions)}|{userId?.ToString("N") ?? string.Empty}|{Base64Url(Encoding.UTF8.GetBytes(storeId))}|{(mfaVerified ? '1' : '0')}";
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
        if (expiresAt <= DateTimeOffset.UtcNow || string.IsNullOrWhiteSpace(fields[0])) return false;
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
        var mfaVerified = fields.Length > 7 && fields[7] == "1";
        if (fields.Length > 7 && fields[7] is not ("0" or "1")) return false;
        principal = new AdminPrincipal(fields[0], expiresAt, role, permissions, sessionId, userId, storeId, mfaVerified);
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
        if (tokens.IsMfaRequiredForRole(principal.Role) && !principal.MfaVerified)
            return AdminSecurityExtensions.MfaRequiredResult();

        if (principal.UserId is Guid userId)
        {
            if (!await users.IsSessionActiveAsync(userId, principal.StoreId, principal.SessionId, context.HttpContext.RequestAborted))
                return Results.Unauthorized();
            var configuredOwnerSession = principal.StoreId == "default" &&
                string.Equals(principal.Email, tokens.OwnerEmail, StringComparison.OrdinalIgnoreCase);
            context.HttpContext.Items["ConfiguredOwnerSession"] = configuredOwnerSession;
            var requestedStore = context.HttpContext.Request.Query["storeId"].ToString();
            if (!configuredOwnerSession && !string.IsNullOrWhiteSpace(requestedStore) &&
                !string.Equals(requestedStore.Trim(), principal.StoreId, StringComparison.Ordinal))
                return Results.Json(new { message = "به این فروشگاه دسترسی ندارید." }, statusCode: StatusCodes.Status403Forbidden);
            if (!configuredOwnerSession && !string.Equals(principal.StoreId, "default", StringComparison.Ordinal) &&
                !context.HttpContext.Request.Path.StartsWithSegments("/api/v1/admin/users", StringComparison.OrdinalIgnoreCase))
                return Results.Json(
                    new { message = "دسترسی عملیاتی این فروشگاه تا فعال‌شدن داده‌های تفکیک‌شده محدود است." },
                    statusCode: StatusCodes.Status403Forbidden);
        }
        else
        {
            context.HttpContext.Items["ConfiguredOwnerSession"] =
                string.Equals(principal.Email, tokens.OwnerEmail, StringComparison.OrdinalIgnoreCase);
        }

        context.HttpContext.Items["AdminPrincipal"] = principal;
        var requiredPermission = AdminPermissionCatalog.RequiredPermission(context.HttpContext);
        if (requiredPermission is not null && !AdminPermissionCatalog.Allows(principal, requiredPermission))
            return Results.Json(new { message = "این عملیات برای نقش فعلی مجاز نیست." }, statusCode: StatusCodes.Status403Forbidden);
        if (!AdminPermissionCatalog.AllowsSensitiveAdminOutput(context.HttpContext, principal))
            return Results.Json(new { message = "برای این سند، دسترسی مجاز به اطلاعات مشتری لازم است." }, statusCode: StatusCodes.Status403Forbidden);
        return await next(context);
    }
}

public sealed class StepUpAuthorizationFilter(AdminTokenService tokens) : IEndpointFilter
{
    public ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var principal = context.HttpContext.Items["AdminPrincipal"] as AdminPrincipal;
        var requiredPermissions = context.HttpContext.GetEndpoint()?.Metadata
            .GetMetadata<StepUpPermissionRequirement>()?.Permissions ?? [];
        if (principal is null || requiredPermissions.Any(permission => !AdminPermissionCatalog.Allows(principal, permission)))
            return ValueTask.FromResult<object?>(Results.Json(
                new { message = "این عملیات برای نقش فعلی مجاز نیست." },
                statusCode: StatusCodes.Status403Forbidden));
        var token = context.HttpContext.Request.Headers["X-Admin-Step-Up"].ToString();
        if (string.IsNullOrWhiteSpace(token) || !tokens.TryValidateStepUp(token, principal))
            return ValueTask.FromResult<object?>(Results.Json(
                new { message = "برای این عملیات، تأیید دوبارهٔ هویت لازم است.", code = "step_up_required" },
                statusCode: StatusCodes.Status428PreconditionRequired));
        return next(context);
    }
}

public sealed class OrderCancellationStepUpAuthorizationFilter(AdminTokenService tokens) : IEndpointFilter
{
    public ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var isCancellation = context.Arguments.Any(argument => argument switch
        {
            SetOrderStateRequest request => string.Equals(request.State, "Cancelled", StringComparison.OrdinalIgnoreCase),
            BulkOrderStateRequest request => string.Equals(request.State, "Cancelled", StringComparison.OrdinalIgnoreCase),
            _ => false
        });
        if (!isCancellation)
            return next(context);

        var principal = context.HttpContext.Items["AdminPrincipal"] as AdminPrincipal;
        if (principal is null || !AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.OrdersWrite))
            return ValueTask.FromResult<object?>(Results.Json(
                new { message = "این عملیات برای نقش فعلی مجاز نیست." },
                statusCode: StatusCodes.Status403Forbidden));

        var token = context.HttpContext.Request.Headers["X-Admin-Step-Up"].ToString();
        if (string.IsNullOrWhiteSpace(token) || !tokens.TryValidateStepUp(token, principal))
            return ValueTask.FromResult<object?>(Results.Json(
                new { message = "برای لغو سفارش و آزادسازی موجودی، تأیید دوبارهٔ هویت لازم است.", code = "step_up_required" },
                statusCode: StatusCodes.Status428PreconditionRequired));

        return next(context);
    }
}

public sealed class OrderShippingCostStepUpAuthorizationFilter(AdminTokenService tokens) : IEndpointFilter
{
    public ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var updatesShippingCost = context.Arguments.OfType<AdminShipmentUpdateInput>()
            .Any(input => input.UpdateActualShippingCost);
        if (!updatesShippingCost)
            return next(context);

        var principal = context.HttpContext.Items["AdminPrincipal"] as AdminPrincipal;
        if (principal is null || !AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.OrdersWrite))
            return ValueTask.FromResult<object?>(Results.Json(
                new { message = "این عملیات برای نقش فعلی مجاز نیست." },
                statusCode: StatusCodes.Status403Forbidden));

        var token = context.HttpContext.Request.Headers["X-Admin-Step-Up"].ToString();
        if (string.IsNullOrWhiteSpace(token) || !tokens.TryValidateStepUp(token, principal))
            return ValueTask.FromResult<object?>(Results.Json(
                new { message = "برای تغییر هزینهٔ واقعی ارسال، تأیید دوبارهٔ هویت لازم است.", code = "step_up_required" },
                statusCode: StatusCodes.Status428PreconditionRequired));

        return next(context);
    }
}

public sealed class ProductCreatePriceStepUpAuthorizationFilter(ProductCatalog catalog, AdminTokenService tokens) : IEndpointFilter
{
    public ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var request = context.Arguments.OfType<CreateProductRequest>().FirstOrDefault();
        if (request is null || request.Validate().Count > 0)
            return next(context);

        if (request.IsPublished && catalog.ValidateForPublication(catalog.Build(request)).Count > 0)
            return next(context);

        var principal = context.HttpContext.Items["AdminPrincipal"] as AdminPrincipal;
        if (principal is null || !AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.PricingWrite))
            return ValueTask.FromResult<object?>(Results.Json(
                new { message = "برای ثبت محصول و قیمت اولیه، دسترسی قیمت‌گذاری لازم است." },
                statusCode: StatusCodes.Status403Forbidden));

        var token = context.HttpContext.Request.Headers["X-Admin-Step-Up"].ToString();
        if (string.IsNullOrWhiteSpace(token) || !tokens.TryValidateStepUp(token, principal))
            return ValueTask.FromResult<object?>(Results.Json(
                new { message = "برای ثبت محصول و قیمت اولیه، تأیید دوبارهٔ هویت لازم است.", code = "step_up_required" },
                statusCode: StatusCodes.Status428PreconditionRequired));

        return next(context);
    }
}

public sealed class ProductPriceStepUpAuthorizationFilter(ProductCatalog catalog, AdminTokenService tokens) : IEndpointFilter
{
    public ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var request = context.Arguments.OfType<UpdateProductRequest>().FirstOrDefault();
        if (request is null ||
            !context.HttpContext.Request.RouteValues.TryGetValue("slug", out var routeSlug) ||
            catalog.FindBySlug(routeSlug?.ToString() ?? string.Empty) is not { } existing)
            return next(context);

        var existingPrices = existing.Variants.ToDictionary(variant => variant.Sku, variant => variant.Price,
            StringComparer.OrdinalIgnoreCase);
        var changesSellingPrice = request.Variants.Any(variant =>
            !existingPrices.TryGetValue(variant.Sku, out var currentPrice) || currentPrice != variant.Price);
        if (!changesSellingPrice)
            return next(context);

        var principal = context.HttpContext.Items["AdminPrincipal"] as AdminPrincipal;
        if (principal is null || !AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.PricingWrite))
            return ValueTask.FromResult<object?>(Results.Json(
                new { message = "برای تغییر قیمت فروش، دسترسی قیمت‌گذاری لازم است." },
                statusCode: StatusCodes.Status403Forbidden));

        var token = context.HttpContext.Request.Headers["X-Admin-Step-Up"].ToString();
        if (string.IsNullOrWhiteSpace(token) || !tokens.TryValidateStepUp(token, principal))
            return ValueTask.FromResult<object?>(Results.Json(
                new { message = "برای تغییر قیمت فروش، تأیید دوبارهٔ هویت لازم است.", code = "step_up_required" },
                statusCode: StatusCodes.Status428PreconditionRequired));

        return next(context);
    }
}

public sealed class UserMutationTargetAuthorizationFilter(AdminUsersDatabase users) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        if (!context.HttpContext.Request.RouteValues.TryGetValue("id", out var routeId) ||
            !Guid.TryParse(routeId?.ToString(), out var userId))
            return Results.NotFound(new { message = "کاربر پیدا نشد." });

        var principal = context.HttpContext.Items["AdminPrincipal"] as AdminPrincipal;
        if (principal is null)
            return Results.Unauthorized();

        var requestedStore = context.HttpContext.Request.Query["storeId"].ToString();
        var storeId = principal.UserId is not null && context.HttpContext.Items["ConfiguredOwnerSession"] is not true
            ? principal.StoreId
            : string.IsNullOrWhiteSpace(requestedStore) ? null : requestedStore.Trim();
        if (!await users.CanManageAsync(userId, storeId, context.HttpContext.RequestAborted))
            return Results.NotFound(new { message = "کاربر پیدا نشد." });

        return await next(context);
    }
}

public sealed record StepUpPermissionRequirement(params string[] Permissions);
