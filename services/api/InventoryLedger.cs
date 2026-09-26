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

    public async Task<StockAdjustmentResult> AdjustAsync(StockAdjustmentRequest request, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return StockAdjustmentResult.Failed("دیتابیس موجودی تنظیم نشده است.");
        if (request.QuantityDelta == 0) return StockAdjustmentResult.Failed("مقدار تغییر باید صفر نباشد.");
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        const string sql = """
            update product_variants
            set available_packages = available_packages + @delta
            where upper(sku)=upper(@sku) and available_packages + @delta >= 0
            returning sku,available_packages;
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("sku", request.Sku.Trim());
        command.Parameters.AddWithValue("delta", request.QuantityDelta);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            await transaction.RollbackAsync(cancellationToken);
            return StockAdjustmentResult.Failed("SKU پیدا نشد یا موجودی نمی‌تواند منفی شود.");
        }
        var sku = reader.GetString(0);
        var balance = reader.GetInt32(1);
        await reader.CloseAsync();
        await RecordAsync(connection, transaction, sku, request.QuantityDelta, "ManualAdjustment", balance, null, "owner", request.Reason.Trim(), cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return StockAdjustmentResult.Success(sku, balance);
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
        endpoints.MapPost("/api/v1/admin/inventory/adjust", async (StockAdjustmentRequest request, InventoryLedgerDatabase database, CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(request.Sku) || string.IsNullOrWhiteSpace(request.Reason))
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(request.Sku)] = ["SKU و دلیل تغییر الزامی است."] });
            var result = await database.AdjustAsync(request, cancellationToken);
            return result.IsSuccess ? Results.Ok(result) : Results.Conflict(new { message = result.Message });
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

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

public sealed record StockAdjustmentRequest(string Sku, int QuantityDelta, string Reason);
public sealed record StockAdjustmentResult(bool IsSuccess, string? Sku = null, int? BalanceAfter = null, string? Message = null)
{
    public static StockAdjustmentResult Success(string sku, int balance) => new(true, sku, balance);
    public static StockAdjustmentResult Failed(string message) => new(false, Message: message);
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
