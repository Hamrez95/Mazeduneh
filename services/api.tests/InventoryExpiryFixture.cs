using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;

public static class InventoryExpiryFixture
{
    private const string Command = "--expire-inventory-fixture-reservation";

    public static bool IsCommand(string[] args) => args.Length > 0 && args[0] == Command;

    public static async Task RunAsync(string[] args)
    {
        if (args.Length == 0) return;
        if (args.Length != 2 || args[0] != Command)
            throw new ArgumentException("Unknown API test fixture command.");
        if (Environment.GetEnvironmentVariable("MAZEDUNEH_TEST_FIXTURES") != "true")
            throw new InvalidOperationException("Inventory expiry fixtures are available only in test runs.");
        if (!Guid.TryParse(args[1], out var orderId))
            throw new ArgumentException("A fixture order id must be a GUID.");

        var configuration = new ConfigurationBuilder().AddEnvironmentVariables().Build();
        var connectionString = configuration.GetConnectionString("Catalog");
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new InvalidOperationException("The fixture database is not configured.");

        await using (var connection = new NpgsqlConnection(connectionString))
        {
            await connection.OpenAsync();
            await using var expire = new NpgsqlCommand("""
                update checkout_orders
                set reservation_expires_at=now()-interval '1 minute'
                where id=@order_id and state='AwaitingPayment' and customer_name='InventoryFixture'
                returning id;
                """, connection);
            expire.Parameters.AddWithValue("order_id", orderId);
            if (await expire.ExecuteScalarAsync() is not Guid)
            {
                await using var currentState = new NpgsqlCommand("select state from checkout_orders where id=@order_id;", connection);
                currentState.Parameters.AddWithValue("order_id", orderId);
                if ((string?)await currentState.ExecuteScalarAsync() != "Expired")
                    throw new InvalidOperationException("The fixture order is not an active or already-expired inventory test reservation.");
            }
        }

        var audit = new AdminAuditLogDatabase(configuration, NullLogger<AdminAuditLogDatabase>.Instance);
        var ledger = new InventoryLedgerDatabase(configuration, NullLogger<InventoryLedgerDatabase>.Instance, audit);
        var pricing = new CommercePricingDatabase(configuration, NullLogger<CommercePricingDatabase>.Instance);
        var checkout = new CheckoutDatabase(configuration, NullLogger<CheckoutDatabase>.Instance, ledger, pricing);
        await checkout.ReleaseExpiredAsync(CancellationToken.None);

        await using (var connection = new NpgsqlConnection(connectionString))
        {
            await connection.OpenAsync();
            await using var state = new NpgsqlCommand("select state from checkout_orders where id=@order_id;", connection);
            state.Parameters.AddWithValue("order_id", orderId);
            if ((string?)await state.ExecuteScalarAsync() != "Expired")
                throw new InvalidOperationException("The fixture order did not transition to Expired.");
        }

        Console.WriteLine("Expired inventory fixture reservation released.");
    }
}
