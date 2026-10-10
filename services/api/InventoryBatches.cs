using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using Npgsql;

public sealed record InventoryBatchRequest(
    string Sku,
    string BatchCode,
    int ReceivedPackages,
    DateTimeOffset ProducedAt,
    DateTimeOffset ExpiresAt,
    decimal CostPrice,
    decimal PackagingCost = 0,
    decimal AdditionalCost = 0,
    DateTimeOffset? PurchasedAt = null,
    string? Supplier = null,
    string? SupplierContactName = null,
    string? SupplierPhone = null,
    string? SupplierEmail = null,
    string? SupplierAddress = null,
    string? SupplierNotes = null)
{
    public Dictionary<string, string[]> Validate()
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(Sku)) errors[nameof(Sku)] = ["SKU الزامی است."];
        if (string.IsNullOrWhiteSpace(BatchCode)) errors[nameof(BatchCode)] = ["کد بچ الزامی است."];
        if (ReceivedPackages is <= 0 or > 1_000_000) errors[nameof(ReceivedPackages)] = ["تعداد دریافتی باید بین ۱ و ۱ میلیون باشد."];
        if (ExpiresAt <= ProducedAt) errors[nameof(ExpiresAt)] = ["تاریخ انقضا باید بعد از تاریخ تولید باشد."];
        if (CostPrice is < 0 or > 1_000_000_000_000m) errors[nameof(CostPrice)] = ["قیمت خرید باید بین صفر و ۱ تریلیون ریال باشد."];
        if (PackagingCost is < 0 or > 1_000_000_000_000m) errors[nameof(PackagingCost)] = ["هزینه بسته‌بندی باید بین صفر و ۱ تریلیون ریال باشد."];
        if (AdditionalCost is < 0 or > 1_000_000_000_000m) errors[nameof(AdditionalCost)] = ["هزینه جانبی باید بین صفر و ۱ تریلیون ریال باشد."];
        if (BatchCode?.Trim().Length > 80) errors[nameof(BatchCode)] = ["کد بچ حداکثر ۸۰ کاراکتر است."];
        if (string.IsNullOrWhiteSpace(Supplier)) errors[nameof(Supplier)] = ["نام تأمین‌کننده الزامی است."];
        if (Supplier?.Trim().Length > 200) errors[nameof(Supplier)] = ["نام تأمین‌کننده حداکثر ۲۰۰ کاراکتر است."];
        if (SupplierContactName?.Trim().Length > 200) errors[nameof(SupplierContactName)] = ["نام شخص تماس حداکثر ۲۰۰ کاراکتر است."];
        if (SupplierPhone?.Trim().Length > 40) errors[nameof(SupplierPhone)] = ["شماره تماس حداکثر ۴۰ کاراکتر است."];
        if (SupplierEmail?.Trim() is { Length: > 0 } email && !new EmailAddressAttribute().IsValid(email)) errors[nameof(SupplierEmail)] = ["ایمیل تأمین‌کننده معتبر نیست."];
        if (SupplierEmail?.Trim().Length > 254) errors[nameof(SupplierEmail)] = ["ایمیل حداکثر ۲۵۴ کاراکتر است."];
        if (SupplierAddress?.Trim().Length > 500) errors[nameof(SupplierAddress)] = ["نشانی حداکثر ۵۰۰ کاراکتر است."];
        if (SupplierNotes?.Trim().Length > 1000) errors[nameof(SupplierNotes)] = ["یادداشت تأمین‌کننده حداکثر ۱۰۰۰ کاراکتر است."];
        if (PurchasedAt > DateTimeOffset.UtcNow) errors[nameof(PurchasedAt)] = ["تاریخ خرید نمی‌تواند در آینده باشد."];
        return errors;
    }
}

public sealed record InventoryBatch(
    Guid Id,
    string Sku,
    string ProductTitle,
    string VariantLabel,
    string BatchCode,
    int ReceivedPackages,
    int RemainingPackages,
    DateTimeOffset ProducedAt,
    DateTimeOffset ExpiresAt,
    decimal CostPrice,
    decimal PackagingCost,
    decimal AdditionalCost,
    bool IsExpired,
    DateTimeOffset CreatedAt,
    DateTimeOffset? PurchasedAt = null,
    string? Supplier = null,
    string? SupplierContactName = null,
    string? SupplierPhone = null,
    string? SupplierEmail = null,
    string? SupplierAddress = null,
    string? SupplierNotes = null)
{
    public decimal PurchaseTotal => CostPrice * ReceivedPackages;
}

public sealed class InventoryBatchDatabase(IConfiguration configuration, ILogger<InventoryBatchDatabase> logger, InventoryLedgerDatabase ledger, AdminAuditLogDatabase audit)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        const string sql = """
            create table if not exists inventory_batches (
                id uuid primary key,
                sku text not null,
                batch_code varchar(80) not null,
                received_packages integer not null check (received_packages > 0),
                remaining_packages integer not null check (remaining_packages >= 0 and remaining_packages <= received_packages),
                produced_at timestamptz not null,
                expires_at timestamptz not null,
                cost_price numeric(18,2) not null default 0 check (cost_price >= 0),
                packaging_cost numeric(18,2) not null default 0 check (packaging_cost >= 0),
                additional_cost numeric(18,2) not null default 0 check (additional_cost >= 0),
                created_at timestamptz not null,
                unique (sku, batch_code)
            );
            create index if not exists ix_inventory_batches_fefo
                on inventory_batches(sku, expires_at, remaining_packages);
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "inventory", "002-batches-expiry", sql, cancellationToken);
        const string purchaseSql = """
            alter table inventory_batches add column if not exists purchased_at timestamptz null;
            alter table inventory_batches add column if not exists supplier varchar(200) null;
            create index if not exists ix_inventory_batches_purchased
                on inventory_batches(sku, purchased_at desc);
            """;
        await DatabaseMigrationRunner.ApplyAsync(connection, "inventory", "003-purchase-history", purchaseSql, cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "inventory", "005-purchase-pagination", """
            create index if not exists ix_inventory_purchase_cursor on inventory_batches(created_at desc,id desc);
            create index if not exists ix_inventory_purchase_sku_cursor on inventory_batches(sku,created_at desc,id desc);
            """, cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "inventory", "006-supplier-details", """
            alter table inventory_batches add column if not exists supplier_contact_name varchar(200) null;
            alter table inventory_batches add column if not exists supplier_phone varchar(40) null;
            alter table inventory_batches add column if not exists supplier_email varchar(254) null;
            alter table inventory_batches add column if not exists supplier_address varchar(500) null;
            alter table inventory_batches add column if not exists supplier_notes varchar(1000) null;
            """, cancellationToken);
        logger.LogInformation("Inventory batch and expiry schema is ready.");
    }

    public async Task<(InventoryBatch? Batch, string? Error)> CreateAsync(InventoryBatchRequest request, string actor, string requestId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return (null, "دیتابیس موجودی تنظیم نشده است.");
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        const string variantSql = """
            select p.title,v.sku,v.display_label,v.available_packages
            from product_variants v join products p on p.id=v.product_id
            where upper(v.sku)=upper(@sku)
            for update of v;
            """;
        await using var variant = new NpgsqlCommand(variantSql, connection, transaction);
        variant.Parameters.AddWithValue("sku", request.Sku.Trim());
        await using var reader = await variant.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            await reader.CloseAsync();
            await transaction.RollbackAsync(cancellationToken);
            return (null, "SKU پیدا نشد.");
        }
        var title = reader.GetString(0);
        var sku = reader.GetString(1);
        var label = reader.GetString(2);
        var availablePackages = reader.GetInt32(3);
        await reader.CloseAsync();

        const string historySql = "select exists(select 1 from inventory_batches where upper(sku)=upper(@sku));";
        await using var history = new NpgsqlCommand(historySql, connection, transaction);
        history.Parameters.AddWithValue("sku", sku);
        var hasBatchHistory = (bool)(await history.ExecuteScalarAsync(cancellationToken) ?? false);

        const string pendingReservationSql = """
            select exists(
                select 1
                from checkout_orders o
                join checkout_order_lines l on l.order_id=o.id
                where o.state='AwaitingPayment' and upper(l.sku)=upper(@sku));
            """;
        await using var pendingReservation = new NpgsqlCommand(pendingReservationSql, connection, transaction);
        pendingReservation.Parameters.AddWithValue("sku", sku);
        var hasPendingReservation = (bool)(await pendingReservation.ExecuteScalarAsync(cancellationToken) ?? false);

        if (!hasBatchHistory && (availablePackages > 0 || hasPendingReservation))
        {
            await transaction.RollbackAsync(cancellationToken);
            return (null, "موجودی قدیمیِ بدون بچ یا رزرو پرداخت‌نشده باقی مانده است؛ پس از مصرف یا آزادسازی آن، ثبت اولین خرید بچ‌دار را انجام دهید.");
        }

        var id = Guid.NewGuid();
        var createdAt = DateTimeOffset.UtcNow;
        var purchasedAt = request.PurchasedAt?.ToUniversalTime() ?? createdAt;
        var supplier = request.Supplier?.Trim();
        var supplierContactName = string.IsNullOrWhiteSpace(request.SupplierContactName) ? null : request.SupplierContactName.Trim();
        var supplierPhone = string.IsNullOrWhiteSpace(request.SupplierPhone) ? null : request.SupplierPhone.Trim();
        var supplierEmail = string.IsNullOrWhiteSpace(request.SupplierEmail) ? null : request.SupplierEmail.Trim();
        var supplierAddress = string.IsNullOrWhiteSpace(request.SupplierAddress) ? null : request.SupplierAddress.Trim();
        var supplierNotes = string.IsNullOrWhiteSpace(request.SupplierNotes) ? null : request.SupplierNotes.Trim();
        const string insertSql = """
            insert into inventory_batches
                (id,sku,batch_code,received_packages,remaining_packages,produced_at,expires_at,cost_price,packaging_cost,additional_cost,created_at,purchased_at,supplier,supplier_contact_name,supplier_phone,supplier_email,supplier_address,supplier_notes)
            values
                (@id,@sku,@batch_code,@received,@remaining,@produced,@expires,@cost,@packaging,@additional,@created,@purchased,@supplier,@supplier_contact_name,@supplier_phone,@supplier_email,@supplier_address,@supplier_notes);
            """;
        await using (var insert = new NpgsqlCommand(insertSql, connection, transaction))
        {
            insert.Parameters.AddWithValue("id", id);
            insert.Parameters.AddWithValue("sku", sku);
            insert.Parameters.AddWithValue("batch_code", request.BatchCode.Trim());
            insert.Parameters.AddWithValue("received", request.ReceivedPackages);
            insert.Parameters.AddWithValue("remaining", request.ReceivedPackages);
            insert.Parameters.AddWithValue("produced", request.ProducedAt);
            insert.Parameters.AddWithValue("expires", request.ExpiresAt);
            insert.Parameters.AddWithValue("cost", request.CostPrice);
            insert.Parameters.AddWithValue("packaging", request.PackagingCost);
            insert.Parameters.AddWithValue("additional", request.AdditionalCost);
            insert.Parameters.AddWithValue("created", createdAt);
            insert.Parameters.AddWithValue("purchased", purchasedAt);
            insert.Parameters.AddWithValue("supplier", (object?)supplier ?? DBNull.Value);
            insert.Parameters.AddWithValue("supplier_contact_name", (object?)supplierContactName ?? DBNull.Value);
            insert.Parameters.AddWithValue("supplier_phone", (object?)supplierPhone ?? DBNull.Value);
            insert.Parameters.AddWithValue("supplier_email", (object?)supplierEmail ?? DBNull.Value);
            insert.Parameters.AddWithValue("supplier_address", (object?)supplierAddress ?? DBNull.Value);
            insert.Parameters.AddWithValue("supplier_notes", (object?)supplierNotes ?? DBNull.Value);
            try { await insert.ExecuteNonQueryAsync(cancellationToken); }
            catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
            {
                await transaction.RollbackAsync(cancellationToken);
                return (null, "این کد بچ برای SKU قبلاً ثبت شده است.");
            }
        }

        const string stockSql = """
            update product_variants set available_packages=available_packages+@quantity
            where upper(sku)=upper(@sku)
            returning available_packages;
            """;
        await using (var stock = new NpgsqlCommand(stockSql, connection, transaction))
        {
            stock.Parameters.AddWithValue("quantity", request.ReceivedPackages);
            stock.Parameters.AddWithValue("sku", sku);
            var balance = await stock.ExecuteScalarAsync(cancellationToken);
            if (balance is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return (null, "موجودی SKU به‌روزرسانی نشد.");
            }
            await ledger.RecordAsync(connection, transaction, sku, request.ReceivedPackages, "BatchReceived",
                Convert.ToInt32(balance), null, actor, "inventory-batch-received", cancellationToken);
        }

        var batch = new InventoryBatch(id, sku, title, label, request.BatchCode.Trim(), request.ReceivedPackages,
            request.ReceivedPackages, request.ProducedAt, request.ExpiresAt, request.CostPrice,
            request.PackagingCost, request.AdditionalCost, request.ExpiresAt <= DateTimeOffset.UtcNow, createdAt, purchasedAt, supplier,
            supplierContactName, supplierPhone, supplierEmail, supplierAddress, supplierNotes);
        await audit.RecordAsync(connection, transaction, actor, "inventory.purchase.received", "InventoryBatch",
            id.ToString(), null, batch, "inventory-purchase-received", requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return (batch, null);
    }

    public async Task<IReadOnlyDictionary<string, DateTimeOffset>> EarliestExpiryBySkuAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return new Dictionary<string, DateTimeOffset>(StringComparer.OrdinalIgnoreCase);
        const string sql = """
            select upper(sku), min(expires_at)
            from inventory_batches
            where remaining_packages > 0 and expires_at > now()
            group by upper(sku);
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        var result = new Dictionary<string, DateTimeOffset>(StringComparer.OrdinalIgnoreCase);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            result[reader.GetString(0)] = reader.GetFieldValue<DateTimeOffset>(1);
        return result;
    }

    public async Task<IReadOnlyCollection<InventoryBatch>> ListAsync(string? sku, bool includeExpired, int limit, CancellationToken cancellationToken, bool purchaseOrder = false)
    {
        if (!IsConfigured) return Array.Empty<InventoryBatch>();
        const string sql = """
            select b.id,b.sku,p.title,v.display_label,b.batch_code,b.received_packages,b.remaining_packages,
                   b.produced_at,b.expires_at,b.cost_price,b.packaging_cost,b.additional_cost,b.created_at,b.purchased_at,b.supplier,
                   b.supplier_contact_name,b.supplier_phone,b.supplier_email,b.supplier_address,b.supplier_notes
            from inventory_batches b
            join product_variants v on upper(v.sku)=upper(b.sku)
            join products p on p.id=v.product_id
            where (@sku='' or upper(b.sku)=upper(@sku))
              and (@include_expired or b.expires_at > now())
            order by case when @purchase_order then b.purchased_at end desc nulls last,
                     case when @purchase_order then b.created_at end desc, b.expires_at asc,b.created_at asc
            limit @limit;
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("sku", sku?.Trim() ?? string.Empty);
        command.Parameters.AddWithValue("include_expired", includeExpired);
        command.Parameters.AddWithValue("limit", limit);
        command.Parameters.AddWithValue("purchase_order", purchaseOrder);
        var result = new List<InventoryBatch>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            result.Add(ReadBatch(reader));
        return result;
    }
    private static InventoryBatch ReadBatch(NpgsqlDataReader reader) => new InventoryBatch(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3),
                reader.GetString(4), reader.GetInt32(5), reader.GetInt32(6), reader.GetFieldValue<DateTimeOffset>(7),
                reader.GetFieldValue<DateTimeOffset>(8), reader.GetDecimal(9), reader.GetDecimal(10), reader.GetDecimal(11),
                reader.GetFieldValue<DateTimeOffset>(8) <= DateTimeOffset.UtcNow, reader.GetFieldValue<DateTimeOffset>(12),
                reader.IsDBNull(13) ? null : reader.GetFieldValue<DateTimeOffset>(13),
                reader.IsDBNull(14) ? null : reader.GetString(14),
                reader.IsDBNull(15) ? null : reader.GetString(15), reader.IsDBNull(16) ? null : reader.GetString(16),
                reader.IsDBNull(17) ? null : reader.GetString(17), reader.IsDBNull(18) ? null : reader.GetString(18),
                reader.IsDBNull(19) ? null : reader.GetString(19));

    public async Task<InventoryPurchasePage> PurchasesAsync(
        string? sku,
        string? batchCode,
        InventoryPurchaseCursor? cursor,
        int limit,
        CancellationToken ct)
    {
        if (!IsConfigured) return new([], null);
        await using var connection = new NpgsqlConnection(_connectionString); await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("""
            select b.id,b.sku,coalesce(p.title,'کالای حذف‌شده'),coalesce(v.display_label,b.sku),b.batch_code,
                   b.received_packages,b.remaining_packages,b.produced_at,b.expires_at,b.cost_price,
                   b.packaging_cost,b.additional_cost,b.created_at,b.purchased_at,b.supplier,
                   b.supplier_contact_name,b.supplier_phone,b.supplier_email,b.supplier_address,b.supplier_notes
            from inventory_batches b
            left join product_variants v on upper(v.sku)=upper(b.sku)
            left join products p on p.id=v.product_id
            where (@sku='' or upper(b.sku)=upper(@sku))
              and (@batch_code='' or upper(b.batch_code)=upper(@batch_code))
              and (@first or (b.created_at,b.id)<(@before_at,@before_id))
            order by b.created_at desc,b.id desc limit @limit;
            """, connection);
        command.Parameters.AddWithValue("sku", sku?.Trim() ?? "");
        command.Parameters.AddWithValue("batch_code", batchCode?.Trim() ?? "");
        command.Parameters.AddWithValue("first", cursor is null);
        command.Parameters.AddWithValue("before_at", cursor?.CreatedAt.ToUniversalTime() ?? DateTimeOffset.UtcNow);
        command.Parameters.AddWithValue("before_id", cursor?.Id ?? Guid.Empty); command.Parameters.AddWithValue("limit", limit + 1);
        var items = new List<InventoryBatch>(); await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct)) items.Add(ReadBatch(reader));
        var more = items.Count > limit; if (more) items.RemoveAt(items.Count - 1);
        return new(items, more ? InventoryPurchaseCursor.Encode(new(items[^1].CreatedAt,items[^1].Id)) : null);
    }

}

public static class InventoryBatchModule
{
    public static IServiceCollection AddInventoryBatches(this IServiceCollection services)
    {
        services.AddSingleton<InventoryBatchDatabase>();
        services.AddHostedService<InventoryBatchSchemaInitializer>();
        return services;
    }

    public static IEndpointRouteBuilder MapInventoryBatches(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/admin/inventory/purchases", async (
            string? sku,
            string? batchCode,
            string? cursor,
            int? limit,
            InventoryBatchDatabase database,
            CancellationToken ct) =>
        {
            InventoryPurchaseCursor? decoded = null;
            if (limit is < 1 or > 250 || (cursor is not null && !InventoryPurchaseCursor.TryDecode(cursor, out decoded)))
                return (IResult)Results.ValidationProblem(new Dictionary<string, string[]> { ["pagination"] = ["صفحه یا تعداد دریافت معتبر نیست؛ فهرست را تازه کنید."] });
            return Results.Ok(await database.PurchasesAsync(sku, batchCode, decoded, limit ?? 50, ct));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();
        endpoints.MapPost("/api/v1/admin/inventory/batches", async (
            InventoryBatchRequest request,
            InventoryBatchDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var errors = request.Validate();
            if (errors.Count > 0) return Results.ValidationProblem(errors);
            var result = await database.CreateAsync(request, ((AdminPrincipal)context.Items["AdminPrincipal"]!).Email, context.TraceIdentifier, cancellationToken);
            return result.Batch is null ? Results.Conflict(new { message = result.Error }) : Results.Created($"/api/v1/admin/inventory/batches/{result.Batch.Id}", result.Batch);
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        endpoints.MapGet("/api/v1/admin/inventory/batches", async (
            string? sku,
            bool? includeExpired,
            int? limit,
            InventoryBatchDatabase database,
            CancellationToken cancellationToken) =>
            Results.Ok(await database.ListAsync(sku, includeExpired ?? true, Math.Clamp(limit ?? 100, 1, 250), cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>();
        return endpoints;
    }
}

public sealed class InventoryBatchSchemaInitializer(InventoryBatchDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken) => database.InitializeAsync(cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

public sealed record InventoryPurchasePage(IReadOnlyCollection<InventoryBatch> Items, string? NextCursor);
public sealed record InventoryPurchaseCursor(DateTimeOffset CreatedAt, Guid Id)
{
    public static string Encode(InventoryPurchaseCursor cursor) => Convert.ToBase64String(JsonSerializer.SerializeToUtf8Bytes(cursor));
    public static bool TryDecode(string input, out InventoryPurchaseCursor? cursor)
    {
        cursor = null;
        if (input.Length > 512) return false;
        try { cursor = JsonSerializer.Deserialize<InventoryPurchaseCursor>(Convert.FromBase64String(input)); }
        catch (Exception exception) when (exception is FormatException or JsonException) { return false; }
        return cursor is not null && cursor.Id != Guid.Empty && cursor.CreatedAt != default;
    }
}
