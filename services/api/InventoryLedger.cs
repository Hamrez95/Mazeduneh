using Npgsql;

public sealed class InventoryLedgerDatabase(IConfiguration configuration, ILogger<InventoryLedgerDatabase> logger, AdminAuditLogDatabase audit)
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
        await DatabaseMigrationRunner.ApplyAsync(connection, "inventory", "001-bootstrap", sql, cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "inventory", "007-adjustment-replays", """
            create table if not exists inventory_adjustment_operations (
                actor text not null,
                operation_key varchar(120) not null,
                sku text not null,
                quantity_delta integer not null,
                reason text not null,
                balance_after integer not null,
                batch_code text null,
                primary key (actor, operation_key)
            );
            """, cancellationToken);
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

    public async Task<StockAdjustmentResult> AdjustAsync(StockAdjustmentRequest request, string actor, string requestId, CancellationToken cancellationToken, string? operationKey = null)
    {
        if (!IsConfigured) return StockAdjustmentResult.Failed("دیتابیس موجودی تنظیم نشده است.");
        if (request.QuantityDelta == 0) return StockAdjustmentResult.Failed("مقدار تغییر باید صفر نباشد.");
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        var replay = await TryReplayAsync(connection, transaction, actor, operationKey, request.Sku, request.QuantityDelta, request.Reason, null, cancellationToken);
        if (replay is not null) return replay;

        // Every receiver, checkout and waste flow locks the variant before batch rows.
        await using (var variantLock = new NpgsqlCommand("select sku from product_variants where upper(sku)=upper(@sku) for update;", connection, transaction))
        {
            variantLock.Parameters.AddWithValue("sku", request.Sku.Trim());
            if (await variantLock.ExecuteScalarAsync(cancellationToken) is null)
                return StockAdjustmentResult.Failed("SKU پیدا نشد.");
        }
        await using (var batchCheck = new NpgsqlCommand("select exists(select 1 from inventory_batches where upper(sku)=upper(@sku));", connection, transaction))
        {
            batchCheck.Parameters.AddWithValue("sku", request.Sku.Trim());
            if ((bool)(await batchCheck.ExecuteScalarAsync(cancellationToken))!)
                return StockAdjustmentResult.Failed("این کالا سابقهٔ بچ دارد؛ برای ورود از ثبت خرید و برای خروج از ضایعات با انتخاب بچ استفاده کنید.");
        }
        const string sql = """
            update product_variants
            set available_packages = available_packages + @delta
            where upper(sku)=upper(@sku) and available_packages::bigint + @delta between 0 and 2147483647
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
        await RecordAsync(connection, transaction, sku, request.QuantityDelta, "ManualAdjustment", balance, null, actor, request.Reason.Trim(), cancellationToken);
        await audit.RecordAsync(
            connection,
            transaction,
            actor,
            "inventory.adjustment",
            "ProductVariant",
            sku,
            new { sku, availablePackages = balance - request.QuantityDelta },
            new { sku, availablePackages = balance },
            request.Reason.Trim(),
            requestId,
            cancellationToken);
        await RecordOperationAsync(connection, transaction, actor, operationKey, sku, request.QuantityDelta, request.Reason, balance, null, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return StockAdjustmentResult.Success(sku, balance);
    }

    public async Task<StockAdjustmentResult> WriteOffBatchAsync(
        string sku,
        string batchCode,
        int quantity,
        string actor,
        string reason,
        string requestId,
        CancellationToken cancellationToken, string? operationKey = null)
    {
        if (!IsConfigured) return StockAdjustmentResult.Failed("دیتابیس موجودی تنظیم نشده است.");
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        var replay = await TryReplayAsync(connection, transaction, actor, operationKey, sku, -quantity, reason, batchCode, cancellationToken);
        if (replay is not null) return replay;

        const string variantLockSql = """
            select sku,available_packages from product_variants
            where upper(sku)=upper(@sku)
            for update;
            """;
        string canonicalSku;
        int availableBefore;
        await using (var command = new NpgsqlCommand(variantLockSql, connection, transaction))
        {
            command.Parameters.AddWithValue("sku", sku.Trim());
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StockAdjustmentResult.Failed("SKU پیدا نشد.");
            }
            canonicalSku = reader.GetString(0);
            availableBefore = reader.GetInt32(1);
        }
        if (quantity > availableBefore)
        {
            await transaction.RollbackAsync(cancellationToken);
            return StockAdjustmentResult.Failed("موجودی قابل‌فروش برای ثبت این ضایعات کافی نیست.");
        }

        const string batchSql = """
            select remaining_packages from inventory_batches
            where upper(sku)=upper(@sku) and upper(batch_code)=upper(@batch_code)
            for update;
            """;
        int batchRemaining;
        await using (var command = new NpgsqlCommand(batchSql, connection, transaction))
        {
            command.Parameters.AddWithValue("sku", sku.Trim());
            command.Parameters.AddWithValue("batch_code", batchCode.Trim());
            var result = await command.ExecuteScalarAsync(cancellationToken);
            if (result is null || result is DBNull)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StockAdjustmentResult.Failed("بچ پیدا نشد.");
            }
            batchRemaining = Convert.ToInt32(result);
        }
        if (quantity > batchRemaining)
        {
            await transaction.RollbackAsync(cancellationToken);
            return StockAdjustmentResult.Failed("تعداد ضایعات از ماندهٔ این بچ بیشتر است.");
        }

        const string updateBatchSql = """
            update inventory_batches set remaining_packages=remaining_packages-@quantity
            where upper(sku)=upper(@sku) and upper(batch_code)=upper(@batch_code)
              and remaining_packages>=@quantity;
            """;
        await using (var command = new NpgsqlCommand(updateBatchSql, connection, transaction))
        {
            command.Parameters.AddWithValue("sku", sku.Trim());
            command.Parameters.AddWithValue("batch_code", batchCode.Trim());
            command.Parameters.AddWithValue("quantity", quantity);
            if (await command.ExecuteNonQueryAsync(cancellationToken) != 1)
            {
                await transaction.RollbackAsync(cancellationToken);
                return StockAdjustmentResult.Failed("ماندهٔ بچ تغییر کرده است؛ انبار را تازه‌سازی و دوباره تلاش کنید.");
            }
        }

        const string updateStockSql = """
            update product_variants set available_packages=available_packages-@quantity
            where upper(sku)=upper(@sku) and available_packages>=@quantity
            returning sku,available_packages;
            """;
        int balance;
        await using (var command = new NpgsqlCommand(updateStockSql, connection, transaction))
        {
            command.Parameters.AddWithValue("sku", sku.Trim());
            command.Parameters.AddWithValue("quantity", quantity);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return StockAdjustmentResult.Failed("موجودی قابل‌فروش برای ثبت این ضایعات کافی نیست.");
            }
            canonicalSku = reader.GetString(0);
            balance = reader.GetInt32(1);
        }

        await RecordAsync(connection, transaction, canonicalSku, -quantity, "Waste", balance, null, actor, reason, cancellationToken);
        await audit.RecordAsync(
            connection, transaction, actor, "inventory.waste", "ProductVariant", canonicalSku,
            new { sku = canonicalSku, batchCode = batchCode.Trim(), availablePackages = balance + quantity, batchRemaining = batchRemaining },
            new { sku = canonicalSku, batchCode = batchCode.Trim(), availablePackages = balance, batchRemaining = batchRemaining - quantity },
            reason, requestId, cancellationToken);
        await RecordOperationAsync(connection, transaction, actor, operationKey, canonicalSku, -quantity, reason, balance, batchCode, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return StockAdjustmentResult.Success(canonicalSku, balance);
    }

    private static async Task<StockAdjustmentResult?> TryReplayAsync(NpgsqlConnection connection, NpgsqlTransaction transaction,
        string actor, string? key, string sku, int delta, string reason, string? batchCode, CancellationToken cancellationToken)
    {
        if (key is null) return null;
        await using var operationLock = new NpgsqlCommand("select pg_advisory_xact_lock(hashtextextended(@key,0));", connection, transaction);
        operationLock.Parameters.AddWithValue("key", "inventory-adjust:" + actor + ":" + key);
        await operationLock.ExecuteNonQueryAsync(cancellationToken);
        await using var command = new NpgsqlCommand("select sku,quantity_delta,reason,balance_after,batch_code from inventory_adjustment_operations where actor=@actor and operation_key=@key;", connection, transaction);
        command.Parameters.AddWithValue("actor", actor);
        command.Parameters.AddWithValue("key", key);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        var previousBatch = reader.IsDBNull(4) ? null : reader.GetString(4);
        if (!string.Equals(reader.GetString(0), sku.Trim(), StringComparison.OrdinalIgnoreCase) || reader.GetInt32(1) != delta ||
            reader.GetString(2) != reason.Trim() || !string.Equals(previousBatch, batchCode?.Trim(), StringComparison.OrdinalIgnoreCase))
            return StockAdjustmentResult.Failed("شناسهٔ عملیات قبلاً با مقادیر دیگری استفاده شده است.");
        return StockAdjustmentResult.Success(reader.GetString(0), reader.GetInt32(3));
    }

    private static async Task RecordOperationAsync(NpgsqlConnection connection, NpgsqlTransaction transaction,
        string actor, string? key, string sku, int delta, string reason, int balance, string? batchCode, CancellationToken cancellationToken)
    {
        if (key is null) return;
        await using var command = new NpgsqlCommand("insert into inventory_adjustment_operations(actor,operation_key,sku,quantity_delta,reason,balance_after,batch_code) values (@actor,@key,@sku,@delta,@reason,@balance,@batch);", connection, transaction);
        command.Parameters.AddWithValue("actor", actor);
        command.Parameters.AddWithValue("key", key);
        command.Parameters.AddWithValue("sku", sku);
        command.Parameters.AddWithValue("delta", delta);
        command.Parameters.AddWithValue("reason", reason.Trim());
        command.Parameters.AddWithValue("balance", balance);
        command.Parameters.AddWithValue("batch", NpgsqlTypes.NpgsqlDbType.Text, (object?)batchCode?.Trim() ?? DBNull.Value);
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
        endpoints.MapPost("/api/v1/admin/inventory/adjust", async (StockAdjustmentRequest request, InventoryLedgerDatabase database, HttpContext context, CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(request.Sku) || string.IsNullOrWhiteSpace(request.Reason))
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(request.Sku)] = ["SKU و دلیل تغییر الزامی است."] });
            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var key = context.Request.Headers["Idempotency-Key"].ToString();
            if (key.Length is < 8 or > 120 || !System.Text.RegularExpressions.Regex.IsMatch(key, "^[A-Za-z0-9_-]+$"))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["Idempotency-Key"] = ["شناسهٔ عملیات الزامی و باید معتبر باشد."] });
            if (request.QuantityDelta is < -1_000_000 or > 1_000_000 || request.Reason.Trim().Length > 500)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["quantityDelta"] = ["تعداد یا طول دلیل خارج از محدودهٔ مجاز است."] });
            var result = await database.AdjustAsync(request, actor, context.TraceIdentifier, cancellationToken, key);
            return result.IsSuccess ? Results.Ok(result) : Results.Conflict(new { message = result.Message });
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        endpoints.MapPost("/api/v1/admin/inventory/waste", async (
            StockWasteRequest request,
            InventoryLedgerDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var errors = new Dictionary<string, string[]>();
            if (string.IsNullOrWhiteSpace(request.Sku) || request.Sku.Trim().Length > 120)
                errors[nameof(request.Sku)] = ["SKU معتبر الزامی است."];
            if (string.IsNullOrWhiteSpace(request.BatchCode) || request.BatchCode.Trim().Length > 80)
                errors[nameof(request.BatchCode)] = ["کد بچ معتبر الزامی است."];
            if (request.Quantity is < 1 or > 1_000_000)
                errors[nameof(request.Quantity)] = ["تعداد ضایعات باید بین ۱ تا یک میلیون بسته باشد."];
            if (string.IsNullOrWhiteSpace(request.Reason) || request.Reason.Trim().Length > 500)
                errors[nameof(request.Reason)] = ["دلیل ضایعات باید بین ۱ تا ۵۰۰ نویسه باشد."];
            if (errors.Count > 0) return Results.ValidationProblem(errors);

            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var key = context.Request.Headers["Idempotency-Key"].ToString();
            if (key.Length is < 8 or > 120 || !System.Text.RegularExpressions.Regex.IsMatch(key, "^[A-Za-z0-9_-]+$"))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["Idempotency-Key"] = ["شناسهٔ عملیات الزامی و باید معتبر باشد."] });
            var result = await database.WriteOffBatchAsync(
                request.Sku, request.BatchCode, request.Quantity, actor, request.Reason.Trim(), context.TraceIdentifier, cancellationToken, key);
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
public sealed record StockWasteRequest(string Sku, string BatchCode, int Quantity, string Reason);
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
