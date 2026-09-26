using System.Security.Cryptography;
using System.Text;
using Npgsql;

public sealed class CheckoutDatabase(IConfiguration configuration, ILogger<CheckoutDatabase> logger)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        const string sql = """
            create table if not exists checkout_orders (
                id uuid primary key,
                receipt_token text not null unique,
                customer_name text not null,
                mobile varchar(20) not null,
                province text not null,
                city text not null,
                address text not null,
                postal_code varchar(20) not null,
                currency varchar(3) not null,
                subtotal numeric(18,2) not null check (subtotal >= 0),
                shipping numeric(18,2) not null check (shipping >= 0),
                discount numeric(18,2) not null check (discount >= 0),
                payable numeric(18,2) not null check (payable >= 0),
                state varchar(32) not null check (state in ('AwaitingPayment','Paid','Cancelled','Expired')),
                created_at timestamptz not null,
                reservation_expires_at timestamptz not null
            );
            create table if not exists checkout_order_lines (
                id uuid primary key,
                order_id uuid not null references checkout_orders(id) on delete cascade,
                product_title text not null,
                sku text not null,
                variant_label text not null,
                quantity integer not null check (quantity > 0),
                unit_price numeric(18,2) not null check (unit_price >= 0),
                line_total numeric(18,2) not null check (line_total >= 0)
            );
            create table if not exists checkout_order_transitions (
                id uuid primary key,
                order_id uuid not null references checkout_orders(id) on delete cascade,
                state varchar(32) not null check (state in ('AwaitingPayment','Paid','Cancelled','Expired')),
                actor text not null,
                occurred_at timestamptz not null,
                reason text not null
            );
            create table if not exists checkout_idempotency (
                idempotency_key varchar(100) primary key,
                fingerprint varchar(64) not null,
                order_id uuid not null unique references checkout_orders(id) on delete cascade,
                created_at timestamptz not null
            );
            create index if not exists ix_checkout_orders_state_expiry
                on checkout_orders(state, reservation_expires_at);
            create index if not exists ix_checkout_order_lines_order
                on checkout_order_lines(order_id);
            create index if not exists ix_checkout_order_transitions_order
                on checkout_order_transitions(order_id, occurred_at);
            """;

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync(cancellationToken);
        logger.LogInformation("Checkout PostgreSQL schema is ready.");
    }

    public async Task<PersistedCheckoutResult> CreateAsync(
        string idempotencyKey,
        string fingerprint,
        CheckoutRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            throw new InvalidOperationException("Checkout database is not configured.");

        try
        {
            await using var connection = new NpgsqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken);
            await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

            var existing = await FindByIdempotencyAsync(connection, transaction, idempotencyKey, cancellationToken);
            if (existing is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return existing.Value.Fingerprint == fingerprint
                    ? PersistedCheckoutResult.Replayed(existing.Value.Order)
                    : PersistedCheckoutResult.Conflict("این Idempotency-Key قبلاً برای درخواست دیگری استفاده شده است.");
            }

            var lines = new List<CheckoutLine>();
            var unavailable = new List<string>();
            var stockLevels = new List<StockLevelChange>();

            foreach (var requested in request.Lines.OrderBy(item => item.Sku, StringComparer.OrdinalIgnoreCase))
            {
                const string selectSql = """
                    select p.title, v.sku, v.display_label, v.price, v.available_packages
                    from product_variants v
                    join products p on p.id = v.product_id
                    where upper(v.sku) = upper(@sku) and p.is_published = true
                    for update of v;
                    """;
                await using var select = new NpgsqlCommand(selectSql, connection, transaction);
                select.Parameters.AddWithValue("sku", requested.Sku.Trim());
                await using var reader = await select.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                {
                    unavailable.Add(requested.Sku.Trim().ToUpperInvariant());
                    continue;
                }

                var productTitle = reader.GetString(0);
                var sku = reader.GetString(1);
                var label = reader.GetString(2);
                var price = reader.GetDecimal(3);
                var available = reader.GetInt32(4);
                await reader.CloseAsync();

                if (available < requested.Quantity)
                {
                    unavailable.Add(sku);
                    continue;
                }

                lines.Add(new CheckoutLine(productTitle, sku, label, requested.Quantity, price, price * requested.Quantity));
            }

            if (unavailable.Count > 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PersistedCheckoutResult.OutOfStock(
                    "حداقل یک کالا موجودی کافی ندارد یا منتشر نشده است.", unavailable);
            }

            foreach (var line in lines)
            {
                const string reserveSql = """
                    update product_variants
                    set available_packages = available_packages - @quantity
                    where upper(sku) = upper(@sku) and available_packages >= @quantity
                    returning available_packages;
                    """;
                await using var reserve = new NpgsqlCommand(reserveSql, connection, transaction);
                reserve.Parameters.AddWithValue("quantity", line.Quantity);
                reserve.Parameters.AddWithValue("sku", line.Sku);
                var remaining = await reserve.ExecuteScalarAsync(cancellationToken);
                if (remaining is null)
                {
                    await transaction.RollbackAsync(cancellationToken);
                    return PersistedCheckoutResult.OutOfStock(
                        "موجودی هنگام ثبت سفارش تغییر کرد؛ سبد خرید را دوباره بررسی کنید.", [line.Sku]);
                }
                stockLevels.Add(new StockLevelChange(line.Sku, Convert.ToInt32(remaining)));
            }

            var subtotal = lines.Sum(item => item.LineTotal);
            var shipping = subtotal >= 15_000_000 ? 0 : 750_000;
            var now = DateTimeOffset.UtcNow;
            var order = new CheckoutOrder(
                Guid.NewGuid(),
                Convert.ToHexString(RandomNumberGenerator.GetBytes(24)).ToLowerInvariant(),
                request.CustomerName.Trim(), request.Mobile.Trim(), request.Province.Trim(), request.City.Trim(),
                request.Address.Trim(), request.PostalCode.Trim(), "IRR", lines, subtotal, shipping, 0,
                subtotal + shipping, OrderState.AwaitingPayment, now, now.AddMinutes(20),
                [new OrderTransition(OrderState.AwaitingPayment, "customer", now, "checkout-created")]);

            await InsertOrderAsync(connection, transaction, order, cancellationToken);
            const string idempotencySql = """
                insert into checkout_idempotency (idempotency_key, fingerprint, order_id, created_at)
                values (@key, @fingerprint, @order_id, @created_at);
                """;
            await using (var command = new NpgsqlCommand(idempotencySql, connection, transaction))
            {
                command.Parameters.AddWithValue("key", idempotencyKey);
                command.Parameters.AddWithValue("fingerprint", fingerprint);
                command.Parameters.AddWithValue("order_id", order.Id);
                command.Parameters.AddWithValue("created_at", now);
                await command.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
            return PersistedCheckoutResult.Created(order, stockLevels);
        }
        catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            await using var connection = new NpgsqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken);
            var existing = await FindByIdempotencyAsync(connection, null, idempotencyKey, cancellationToken);
            if (existing is not null)
                return existing.Value.Fingerprint == fingerprint
                    ? PersistedCheckoutResult.Replayed(existing.Value.Order)
                    : PersistedCheckoutResult.Conflict("این Idempotency-Key قبلاً برای درخواست دیگری استفاده شده است.");
            throw;
        }
    }

    public async Task<CheckoutOrder?> FindAsync(Guid orderId, string receiptToken, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        var order = await LoadOrderAsync(connection, null, orderId, cancellationToken);
        if (order is null) return null;

        var expected = Encoding.UTF8.GetBytes(order.ReceiptToken);
        var supplied = Encoding.UTF8.GetBytes(receiptToken ?? string.Empty);
        return expected.Length == supplied.Length && CryptographicOperations.FixedTimeEquals(expected, supplied)
            ? order
            : null;
    }

    public async Task<IReadOnlyCollection<StockLevelChange>> ReleaseExpiredAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<StockLevelChange>();
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        const string expiredSql = """
            select id
            from checkout_orders
            where state = 'AwaitingPayment' and reservation_expires_at <= @now
            order by reservation_expires_at
            for update skip locked
            limit 100;
            """;
        var orderIds = new List<Guid>();
        await using (var command = new NpgsqlCommand(expiredSql, connection, transaction))
        {
            command.Parameters.AddWithValue("now", DateTimeOffset.UtcNow);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken)) orderIds.Add(reader.GetGuid(0));
        }

        var changes = new List<StockLevelChange>();
        foreach (var orderId in orderIds)
        {
            const string linesSql = "select sku, quantity from checkout_order_lines where order_id=@order_id;";
            var lines = new List<(string Sku, int Quantity)>();
            await using (var command = new NpgsqlCommand(linesSql, connection, transaction))
            {
                command.Parameters.AddWithValue("order_id", orderId);
                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                while (await reader.ReadAsync(cancellationToken)) lines.Add((reader.GetString(0), reader.GetInt32(1)));
            }

            foreach (var line in lines)
            {
                const string releaseSql = """
                    update product_variants
                    set available_packages = available_packages + @quantity
                    where upper(sku) = upper(@sku)
                    returning available_packages;
                    """;
                await using var release = new NpgsqlCommand(releaseSql, connection, transaction);
                release.Parameters.AddWithValue("quantity", line.Quantity);
                release.Parameters.AddWithValue("sku", line.Sku);
                var available = await release.ExecuteScalarAsync(cancellationToken);
                if (available is not null)
                    changes.Add(new StockLevelChange(line.Sku, Convert.ToInt32(available)));
            }

            var now = DateTimeOffset.UtcNow;
            await using (var update = new NpgsqlCommand(
                "update checkout_orders set state='Expired' where id=@id and state='AwaitingPayment';", connection, transaction))
            {
                update.Parameters.AddWithValue("id", orderId);
                await update.ExecuteNonQueryAsync(cancellationToken);
            }
            await using (var transition = new NpgsqlCommand(
                "insert into checkout_order_transitions (id,order_id,state,actor,occurred_at,reason) values (@id,@order_id,'Expired','system',@at,'reservation-expired');",
                connection, transaction))
            {
                transition.Parameters.AddWithValue("id", Guid.NewGuid());
                transition.Parameters.AddWithValue("order_id", orderId);
                transition.Parameters.AddWithValue("at", now);
                await transition.ExecuteNonQueryAsync(cancellationToken);
            }
        }

        await transaction.CommitAsync(cancellationToken);
        if (orderIds.Count > 0) logger.LogInformation("Released {Count} expired checkout reservations.", orderIds.Count);
        return changes;
    }

    private static async Task InsertOrderAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        CheckoutOrder order,
        CancellationToken cancellationToken)
    {
        const string orderSql = """
            insert into checkout_orders
            (id,receipt_token,customer_name,mobile,province,city,address,postal_code,currency,subtotal,shipping,discount,payable,state,created_at,reservation_expires_at)
            values
            (@id,@receipt_token,@customer_name,@mobile,@province,@city,@address,@postal_code,@currency,@subtotal,@shipping,@discount,@payable,@state,@created_at,@reservation_expires_at);
            """;
        await using (var command = new NpgsqlCommand(orderSql, connection, transaction))
        {
            command.Parameters.AddWithValue("id", order.Id);
            command.Parameters.AddWithValue("receipt_token", order.ReceiptToken);
            command.Parameters.AddWithValue("customer_name", order.CustomerName);
            command.Parameters.AddWithValue("mobile", order.Mobile);
            command.Parameters.AddWithValue("province", order.Province);
            command.Parameters.AddWithValue("city", order.City);
            command.Parameters.AddWithValue("address", order.Address);
            command.Parameters.AddWithValue("postal_code", order.PostalCode);
            command.Parameters.AddWithValue("currency", order.Currency);
            command.Parameters.AddWithValue("subtotal", order.Subtotal);
            command.Parameters.AddWithValue("shipping", order.Shipping);
            command.Parameters.AddWithValue("discount", order.Discount);
            command.Parameters.AddWithValue("payable", order.Payable);
            command.Parameters.AddWithValue("state", order.State.ToString());
            command.Parameters.AddWithValue("created_at", order.CreatedAt);
            command.Parameters.AddWithValue("reservation_expires_at", order.ReservationExpiresAt);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        foreach (var line in order.Lines)
        {
            const string lineSql = """
                insert into checkout_order_lines
                (id,order_id,product_title,sku,variant_label,quantity,unit_price,line_total)
                values (@id,@order_id,@product_title,@sku,@variant_label,@quantity,@unit_price,@line_total);
                """;
            await using var command = new NpgsqlCommand(lineSql, connection, transaction);
            command.Parameters.AddWithValue("id", Guid.NewGuid());
            command.Parameters.AddWithValue("order_id", order.Id);
            command.Parameters.AddWithValue("product_title", line.ProductTitle);
            command.Parameters.AddWithValue("sku", line.Sku);
            command.Parameters.AddWithValue("variant_label", line.VariantLabel);
            command.Parameters.AddWithValue("quantity", line.Quantity);
            command.Parameters.AddWithValue("unit_price", line.UnitPrice);
            command.Parameters.AddWithValue("line_total", line.LineTotal);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        foreach (var item in order.Transitions)
        {
            const string transitionSql = """
                insert into checkout_order_transitions (id,order_id,state,actor,occurred_at,reason)
                values (@id,@order_id,@state,@actor,@occurred_at,@reason);
                """;
            await using var command = new NpgsqlCommand(transitionSql, connection, transaction);
            command.Parameters.AddWithValue("id", Guid.NewGuid());
            command.Parameters.AddWithValue("order_id", order.Id);
            command.Parameters.AddWithValue("state", item.State.ToString());
            command.Parameters.AddWithValue("actor", item.Actor);
            command.Parameters.AddWithValue("occurred_at", item.At);
            command.Parameters.AddWithValue("reason", item.Reason);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
    }

    private static async Task<(string Fingerprint, CheckoutOrder Order)?> FindByIdempotencyAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        string key,
        CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            "select fingerprint, order_id from checkout_idempotency where idempotency_key=@key;", connection, transaction);
        command.Parameters.AddWithValue("key", key);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        var fingerprint = reader.GetString(0);
        var orderId = reader.GetGuid(1);
        await reader.CloseAsync();
        var order = await LoadOrderAsync(connection, transaction, orderId, cancellationToken)
            ?? throw new InvalidOperationException("Idempotency record points to a missing order.");
        return (fingerprint, order);
    }

    private static async Task<CheckoutOrder?> LoadOrderAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        Guid orderId,
        CancellationToken cancellationToken)
    {
        const string orderSql = """
            select id,receipt_token,customer_name,mobile,province,city,address,postal_code,currency,
                   subtotal,shipping,discount,payable,state,created_at,reservation_expires_at
            from checkout_orders where id=@id;
            """;
        Guid id;
        string receiptToken, customerName, mobile, province, city, address, postalCode, currency;
        decimal subtotal, shipping, discount, payable;
        OrderState state;
        DateTimeOffset createdAt, expiresAt;
        await using (var command = new NpgsqlCommand(orderSql, connection, transaction))
        {
            command.Parameters.AddWithValue("id", orderId);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken)) return null;
            id = reader.GetGuid(0);
            receiptToken = reader.GetString(1);
            customerName = reader.GetString(2);
            mobile = reader.GetString(3);
            province = reader.GetString(4);
            city = reader.GetString(5);
            address = reader.GetString(6);
            postalCode = reader.GetString(7);
            currency = reader.GetString(8);
            subtotal = reader.GetDecimal(9);
            shipping = reader.GetDecimal(10);
            discount = reader.GetDecimal(11);
            payable = reader.GetDecimal(12);
            state = Enum.Parse<OrderState>(reader.GetString(13));
            createdAt = reader.GetFieldValue<DateTimeOffset>(14);
            expiresAt = reader.GetFieldValue<DateTimeOffset>(15);
        }

        var lines = new List<CheckoutLine>();
        await using (var command = new NpgsqlCommand(
            "select product_title,sku,variant_label,quantity,unit_price,line_total from checkout_order_lines where order_id=@id order by id;",
            connection, transaction))
        {
            command.Parameters.AddWithValue("id", orderId);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                lines.Add(new CheckoutLine(reader.GetString(0), reader.GetString(1), reader.GetString(2),
                    reader.GetInt32(3), reader.GetDecimal(4), reader.GetDecimal(5)));
        }

        var transitions = new List<OrderTransition>();
        await using (var command = new NpgsqlCommand(
            "select state,actor,occurred_at,reason from checkout_order_transitions where order_id=@id order by occurred_at,id;",
            connection, transaction))
        {
            command.Parameters.AddWithValue("id", orderId);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                transitions.Add(new OrderTransition(Enum.Parse<OrderState>(reader.GetString(0)), reader.GetString(1),
                    reader.GetFieldValue<DateTimeOffset>(2), reader.GetString(3)));
        }

        return new CheckoutOrder(id, receiptToken, customerName, mobile, province, city, address, postalCode,
            currency, lines, subtotal, shipping, discount, payable, state, createdAt, expiresAt, transitions);
    }
}

public sealed record StockLevelChange(string Sku, int AvailablePackages);

public sealed record PersistedCheckoutResult(
    CheckoutStatus Status,
    CheckoutOrder? Order = null,
    string? Message = null,
    IReadOnlyCollection<string>? UnavailableSkus = null,
    IReadOnlyCollection<StockLevelChange>? StockLevels = null)
{
    public static PersistedCheckoutResult Created(CheckoutOrder order, IReadOnlyCollection<StockLevelChange> levels) =>
        new(CheckoutStatus.Created, order, StockLevels: levels);
    public static PersistedCheckoutResult Replayed(CheckoutOrder order) => new(CheckoutStatus.Replayed, order);
    public static PersistedCheckoutResult Conflict(string message) => new(CheckoutStatus.Conflict, Message: message);
    public static PersistedCheckoutResult OutOfStock(string message, IReadOnlyCollection<string> skus) =>
        new(CheckoutStatus.OutOfStock, Message: message, UnavailableSkus: skus);
}

public sealed class CheckoutSchemaInitializer(CheckoutDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken) => database.InitializeAsync(cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

public sealed class ReservationExpiryWorker(
    CheckoutDatabase database,
    ProductCatalog catalog,
    ILogger<ReservationExpiryWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!database.IsConfigured) return;
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
        try
        {
            do
            {
                var changes = await database.ReleaseExpiredAsync(stoppingToken);
                foreach (var item in changes) catalog.SetAvailablePackages(item.Sku, item.AvailablePackages);
            }
            while (await timer.WaitForNextTickAsync(stoppingToken));
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            logger.LogInformation("Checkout reservation expiry worker stopped.");
        }
    }
}
