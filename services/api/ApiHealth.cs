using Npgsql;

public static class ApiHealthEndpoints
{
    public static IEndpointRouteBuilder MapApiHealth(this IEndpointRouteBuilder endpoints)
    {
        // Liveness must not depend on PostgreSQL: an outage should remove traffic,
        // rather than cause an otherwise live process to restart repeatedly.
        endpoints.MapGet("/health/live", () => Results.Ok(new { status = "alive" }));

        endpoints.MapGet("/health/ready", async (
            ApiHealthProbe probe, AdminTokenService adminTokens,
            HttpContext context, CancellationToken cancellationToken) =>
        {
            context.Response.Headers.CacheControl = "no-store";
            var database = await probe.CheckDatabaseAsync(cancellationToken);
            var ready = database.IsReady && adminTokens.IsConfigured;
            return Results.Json(new
            {
                status = ready ? "ready" : "not-ready",
                database = database.Database,
                migrations = database.MigrationStatus,
                adminAuthentication = adminTokens.IsConfigured ? "configured" : "not-configured"
            }, statusCode: ready ? StatusCodes.Status200OK : StatusCodes.Status503ServiceUnavailable);
        });

        // Keep the legacy diagnostic contract; orchestrators should use /health/ready.
        endpoints.MapGet("/health", async (
            ApiHealthProbe probe, AdminTokenService adminTokens,
            PaymentDatabase payments, ZibalGateway zibal, HttpContext context, CancellationToken cancellationToken) =>
        {
            context.Response.Headers.CacheControl = "no-store";
            var database = await probe.CheckDatabaseAsync(cancellationToken);
            var latest = database.Migrations.LastOrDefault();
            return Results.Ok(new
            {
                status = database.Database == "unhealthy" ? "degraded" : "healthy",
                service = "mazeduneh-api",
                database = database.Database,
                migrations = new
                {
                    status = database.MigrationStatus,
                    applied = database.Migrations.Count,
                    latest = latest is null ? null : new { component = latest.Component, version = latest.Version }
                },
                adminAuthentication = adminTokens.IsConfigured ? "configured" : "not-configured",
                paymentSandbox = payments.SandboxEnabled ? "enabled" : "disabled",
                payment = zibal.IsConfigured ? "zibal-configured" : payments.SandboxEnabled ? "sandbox-enabled" : "disabled",
                utc = DateTimeOffset.UtcNow
            });
        });
        return endpoints;
    }
}

public sealed class ApiHealthProbe(IConfiguration configuration, ILogger<ApiHealthProbe> logger)
{
    public async Task<DatabaseHealthSnapshot> CheckDatabaseAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(configuration.GetConnectionString("Catalog")))
            return new("not-configured", "not-configured", Array.Empty<DatabaseMigrationInfo>());

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(3));
        try
        {
            // Reading the ledger proves connectivity and schema access in one query.
            var migrations = await DatabaseMigrationRunner.ListAsync(configuration, timeout.Token);
            return new("healthy", migrations.Count > 0 ? "tracked" : "empty", migrations);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception) when (exception is NpgsqlException or TimeoutException
            or OperationCanceledException or ArgumentException or InvalidOperationException)
        {
            // Do not emit connection strings, host names, SQL, or provider messages.
            logger.LogWarning("API database readiness check failed ({FailureType}).", exception.GetType().Name);
            return new("unhealthy", "unavailable", Array.Empty<DatabaseMigrationInfo>());
        }
    }
}

public sealed record DatabaseHealthSnapshot(
    string Database, string MigrationStatus, IReadOnlyCollection<DatabaseMigrationInfo> Migrations)
{
    public bool IsReady => Database == "healthy" && MigrationStatus == "tracked";
}
