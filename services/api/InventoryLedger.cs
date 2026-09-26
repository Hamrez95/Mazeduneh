using Npgsql;

public sealed class InventoryLedgerDatabase(IConfiguration configuration, ILogger<InventoryLedgerDatabase> logger)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        const string sql = """
            create table if not exists stock_movements (
                id uuid primary key,
                sku text not null,
                quantity_delta integer not null check (quantity_delta <> 0),
                movement_type varchar(32) not null,
                balance_after integer not null check (balance_after >= 0),
                order_id uuid null,
                actor text not null,
                reason text not null,
                created_at timestamptz not null
            );
            create index if not exists ix_stock_movements_sku_created
                on stock_movements(sku, created_at desc);
            create index if not exists ix_stock_movements_order
                on stock_movements(order_id, created_at);
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync(cancellationToken);
        logger.LogInformation("Inventory stock ledger schema is ready.");
    }

    public async Task RecordAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string sku,
        int quantityDelta,
        string movementType,
        int balanceAfter,
        Guid? orderId,
        string actor,
        string reason,
        CancellationToken cancellationToken)
    {
        const string sql = """
            insert into stock_movements
                (id,sku,quantity_delta,movement_type,balance_after,order_id,actor,reason,created_at)
            values
                (@id,@sku,@quantity_delta,@movement_type,@balance_after,@order_id,@actor,@reason,@created_at);
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("id", Guid.NewGuid());
        command.Parameters.AddWithValue("sku", sku);
        command.Parameters.AddWithValue("quantity_delta", quantityDelta);
        command.Parameters.AddWithValue("movement_type", movementType);
        command.Parameters.AddWithValue("balance_after", balanceAfter);
        command.Parameters.AddWithValue("order_id", (object?)orderId ?? DBNull.Value);
        command.Parameters.AddWithValue("actor", actor);
        command.Parameters.AddWithValue("reason", reason);
        command.Parameters.AddWithValue("created_at", DateTimeOffset.UtcNow);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<StockMovement>> ListAsync(
        string? sku,
        int limit,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<StockMovement>();
        const string sql = """
            select id,sku,quantity_delta,movement_type,balance_after,order_id,actor,reason,created_at
            from stock_movements
            where (@sku = '' or upper(sku)=upper(@sku))
            order by created_at desc
            limit @limit;
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("sku", sku?.Trim() ?? string.Empty);
        command.Parameters.AddWithValue("limit", limit);
        var result = new List<StockMovement>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new StockMovement(
                reader.GetGuid(0),
                reader.GetString(1),
                reader.GetInt32(2),
                reader.GetString(3),
                reader.GetInt32(4),
                reader.IsDBNull(5) ? null : reader.GetGuid(5),
                reader.GetString(6),
                reader.GetString(7),
                reader.GetFieldValue<DateTimeOffset>(8)));
        }
        return result;
    }
}

public static class InventoryLedgerModule
{
    public static IEndpointRouteBuilder MapInventoryLedger(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/admin/inventory/movements", async (
            string? sku,
            int? limit,
            InventoryLedgerDatabase database,
            CancellationToken cancellationToken) =>
            Results.Ok(await database.ListAsync(sku, Math.Clamp(limit ?? 100, 1, 250), cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>();
        return endpoints;
    }
}

public sealed record StockMovement(
    Guid Id,
    string Sku,
    int QuantityDelta,
    string MovementType,
    int BalanceAfter,
    Guid? OrderId,
    string Actor,
    string Reason,
    DateTimeOffset CreatedAt);
