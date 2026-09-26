using System.Security.Cryptography;
using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

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
        endpoints.MapPost("/api/v1/admin/auth/login", (AdminLoginRequest request, AdminTokenService tokens) =>
        {
            if (!tokens.IsConfigured)
                return Results.Problem(
                    title: "ورود مدیر پیکربندی نشده است.",
                    detail: "متغیرهای Admin__Email، Admin__PasswordHash و Admin__TokenSigningKey باید در محیط اجرا تنظیم شوند.",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            if (!tokens.ValidateCredentials(request.Email, request.Password))
                return Results.Unauthorized();

            var issued = tokens.Issue(request.Email);
            return Results.Ok(new
            {
                accessToken = issued.Token,
                tokenType = "Bearer",
                expiresAt = issued.ExpiresAt,
                role = "Owner",
                email = tokens.OwnerEmail
            });
        })
        .RequireRateLimiting("admin-login")
        .WithTags("Admin Auth");

        endpoints.MapGet("/api/v1/admin/auth/session", (AdminTokenService tokens, HttpContext context) =>
        {
            var token = AdminTokenService.ReadBearerToken(context.Request);
            return token is not null && tokens.TryValidate(token, out var principal)
                ? Results.Ok(new { authenticated = true, email = principal.Email, role = "Owner", expiresAt = principal.ExpiresAt })
                : Results.Unauthorized();
        })
        .WithTags("Admin Auth");

        return endpoints;
    }
}

public sealed record AdminLoginRequest(string Email, string Password);
public sealed record IssuedAdminToken(string Token, DateTimeOffset ExpiresAt);
public sealed record AdminPrincipal(string Email, DateTimeOffset ExpiresAt);

public sealed class AdminTokenService
{
    private readonly byte[] _signingKey;
    private readonly byte[] _configuredPasswordHash;
    private readonly TimeSpan _lifetime;

    public AdminTokenService(IConfiguration configuration)
    {
        OwnerEmail = configuration["Admin:Email"]?.Trim().ToLowerInvariant() ?? string.Empty;
        _signingKey = Encoding.UTF8.GetBytes(configuration["Admin:TokenSigningKey"] ?? string.Empty);
        _configuredPasswordHash = ParseHex(configuration["Admin:PasswordHash"]);
        _lifetime = TimeSpan.FromMinutes(Math.Clamp(configuration.GetValue("Admin:AccessTokenMinutes", 15), 5, 60));
    }

    public string OwnerEmail { get; }
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(OwnerEmail) &&
        _signingKey.Length >= 32 &&
        _configuredPasswordHash.Length == 32;

    public bool ValidateCredentials(string? email, string? password)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(email) || string.IsNullOrEmpty(password)) return false;
        if (!string.Equals(email.Trim(), OwnerEmail, StringComparison.OrdinalIgnoreCase)) return false;
        var suppliedHash = SHA256.HashData(Encoding.UTF8.GetBytes(password));
        return CryptographicOperations.FixedTimeEquals(suppliedHash, _configuredPasswordHash);
    }

    public IssuedAdminToken Issue(string email)
    {
        var expiresAt = DateTimeOffset.UtcNow.Add(_lifetime);
        var payload = $"{email.Trim().ToLowerInvariant()}|{expiresAt.ToUnixTimeSeconds()}|{Guid.NewGuid():N}";
        var payloadBytes = Encoding.UTF8.GetBytes(payload);
        var signature = HMACSHA256.HashData(_signingKey, payloadBytes);
        var token = $"{Base64Url(payloadBytes)}.{Base64Url(signature)}";
        return new IssuedAdminToken(token, expiresAt);
    }

    public bool TryValidate(string token, out AdminPrincipal principal)
    {
        principal = default!;
        if (!IsConfigured) return false;
        var parts = token.Split('.', 2);
        if (parts.Length != 2 || !TryBase64Url(parts[0], out var payloadBytes) || !TryBase64Url(parts[1], out var signature)) return false;
        var expectedSignature = HMACSHA256.HashData(_signingKey, payloadBytes);
        if (!CryptographicOperations.FixedTimeEquals(signature, expectedSignature)) return false;

        var fields = Encoding.UTF8.GetString(payloadBytes).Split('|', 3);
        if (fields.Length != 3 || !long.TryParse(fields[1], out var unixExpiry)) return false;
        var expiresAt = DateTimeOffset.FromUnixTimeSeconds(unixExpiry);
        if (expiresAt <= DateTimeOffset.UtcNow || !string.Equals(fields[0], OwnerEmail, StringComparison.OrdinalIgnoreCase)) return false;
        principal = new AdminPrincipal(fields[0], expiresAt);
        return true;
    }

    public static string? ReadBearerToken(HttpRequest request)
    {
        var value = request.Headers.Authorization.ToString();
        return value.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) ? value[7..].Trim() : null;
    }

    private static string Base64Url(byte[] value) => Convert.ToBase64String(value).TrimEnd('=').Replace('+', '-').Replace('/', '_');

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
}

public sealed class OwnerAuthorizationFilter(AdminTokenService tokens) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var token = AdminTokenService.ReadBearerToken(context.HttpContext.Request);
        if (token is null || !tokens.TryValidate(token, out var principal))
            return Results.Unauthorized();

        context.HttpContext.Items["AdminPrincipal"] = principal;
        return await next(context);
    }
}
