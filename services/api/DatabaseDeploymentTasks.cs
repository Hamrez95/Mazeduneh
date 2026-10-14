public sealed class DatabaseDeploymentTasks(
    IConfiguration configuration,
    CatalogDatabase catalog,
    CheckoutDatabase checkout,
    PaymentDatabase payments,
    OrderManagementDatabase orders,
    CustomerIdentityDatabase customers,
    InventoryLedgerDatabase inventoryLedger,
    InventoryBatchDatabase inventoryBatches,
    InventoryPricingDatabase inventoryPricing,
    CommercePricingDatabase commerce,
    CorporateRequestDatabase corporateSales,
    AdminAuditLogDatabase audit,
    AdminUsersDatabase adminUsers,
    ProductCatalog products)
{
    public async Task MigrateAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(configuration.GetConnectionString("Catalog")))
            throw new InvalidOperationException("ConnectionStrings:Catalog must be configured for database migrations.");

        await catalog.ApplyMigrationsAsync(cancellationToken);
        await inventoryLedger.ApplyMigrationsAsync(cancellationToken);
        await inventoryBatches.ApplyMigrationsAsync(cancellationToken);
        await inventoryPricing.ApplyMigrationsAsync(cancellationToken);
        await commerce.ApplyMigrationsAsync(cancellationToken);
        await corporateSales.ApplyMigrationsAsync(cancellationToken);
        await checkout.ApplyMigrationsAsync(cancellationToken);
        await customers.ApplyMigrationsAsync(cancellationToken);
        await orders.ApplyMigrationsAsync(cancellationToken);
        await payments.ApplyMigrationsAsync(cancellationToken);
        await audit.ApplyMigrationsAsync(cancellationToken);
        await adminUsers.ApplyMigrationsAsync(cancellationToken);

        var applied = await DatabaseMigrationRunner.ListAsync(configuration, cancellationToken);
        var appliedKeys = applied
            .Select(migration => new DatabaseMigrationKey(migration.Component, migration.Version))
            .ToHashSet();
        var missingMigrations = DatabaseMigrationCatalog.Required
            .Where(migration => !appliedKeys.Contains(migration))
            .ToArray();
        if (missingMigrations.Length > 0)
            throw new InvalidOperationException(
                $"Database migration is incomplete. Missing: {string.Join(", ", missingMigrations)}.");
    }

    public Task SeedAdminAsync(CancellationToken cancellationToken) =>
        adminUsers.SeedOwnerMembershipAsync(cancellationToken);

    public async Task SeedDemoCatalogAsync(CancellationToken cancellationToken)
    {
        if (await catalog.SeedDemoCatalogIfEmptyAsync(products.AllIncludingDrafts().ToArray(), cancellationToken))
            return;

        Console.WriteLine("Demo seed skipped because the catalog already contains products.");
    }
}

public sealed record DatabaseMigrationKey(string Component, string Version);

public static class DatabaseMigrationCatalog
{
    public static IReadOnlyList<DatabaseMigrationKey> Required { get; } =
    [
        new("catalog", "001-bootstrap"),
        new("catalog", "002-nutrition-costing"),
        new("inventory", "001-bootstrap"),
        new("inventory", "002-batches-expiry"),
        new("inventory", "003-purchase-history"),
        new("inventory", "004-pricing-rules"),
        new("inventory", "005-purchase-pagination"),
        new("inventory", "006-supplier-details"),
        new("inventory", "007-adjustment-replays"),
        new("commerce", "001-pricing-settings"),
        new("corporate-sales", "001-bootstrap"),
        new("checkout", "001-bootstrap"),
        new("checkout", "002-shipping-expense"),
        new("customers", "001-bootstrap"),
        new("orders", "001-bootstrap"),
        new("orders", "002-internal-notes"),
        new("orders", "003-shipping-details"),
        new("orders", "004-dashboard-role-preferences"),
        new("payments", "001-bootstrap"),
        new("payments", "002-failed-zibal-attempts"),
        new("admin-audit", "001-bootstrap"),
        new("admin-users", "001-memberships"),
        new("admin-users", "002-member-login"),
        new("admin-users", "003-member-permissions"),
        new("admin-users", "004-totp-replay-guard")
    ];
}
