using Npgsql;

public static class OrderManagementModule
{
    public static IServiceCollection AddOrderManagement(this IServiceCollection services)
    {
        services.AddSingleton<OrderManagementDatabase>();
        services.AddHostedService<OrderManagementSchemaInitializer>();
        return services;
    }

    public static IEndpointRouteBuilder MapOrderManagement(this IEndpointRouteBuilder endpoints)
    {
        var admin = endpoints.MapGroup("/api/v1/admin").WithTags("Admin Orders");

        admin.MapGet("/orders", async (
            string? state,
            int? limit,
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
        {
            if (!string.IsNullOrWhiteSpace(state) && !Enum.TryParse<OrderState>(state, true, out _))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["state"] = ["وضعیت سفارش معتبر نیست."] });
            return Results.Ok(await database.ListAsync(state, Math.Clamp(limit ?? 100, 1, 250), cancellationToken));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/dashboard", async (
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
            Results.Ok(await database.DashboardAsync(cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapPatch("/orders/{orderId:guid}/state", async (
            Guid orderId,
            SetOrderStateRequest request,
            OrderManagementDatabase database,
            ProductCatalog catalog,
            CancellationToken cancellationToken) =>
        {
            if (!Enum.TryParse<OrderState>(request.State, true, out var requestedState))
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(request.State)] = ["وضعیت سفارش معتبر نیست."] });

            var result = await database.TransitionAsync(orderId, requestedState, request.Reason, cancellationToken);
            if (result.StockLevels is not null)
                foreach (var item in result.StockLevels) catalog.SetAvailablePackages(item.Sku, item.AvailablePackages);

            return result.Status switch
            {
                OrderOperationStatus.Updated => Results.Ok(result.Order),
                OrderOperationStatus.NotFound => Results.NotFound(new { message = result.Message }),
                _ => Results.Conflict(new { message = result.Message })
            };
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        return endpoints;
    }
}

public sealed class OrderManagementDatabase(IConfiguration configuration, ILogger<OrderManagementDatabase> logger)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        const string sql = """
            alter table checkout_orders drop constraint if exists checkout_orders_state_check;
            alter table checkout_orders add constraint checkout_orders_state_check
                check (state in ('AwaitingPayment','Paid','Preparing','Shipped','Delivered','Cancelled','Expired'));
            alter table checkout_order_transitions drop constraint if exists checkout_order_transitions_state_check;
            alter table checkout_order_transitions add constraint checkout_order_transitions_state_check
                check (state in ('AwaitingPayment','Paid','Preparing','Shipped','Delivered','Cancelled','Expired'));
            create index if not exists ix_checkout_orders_created_desc on checkout_orders(created_at desc);
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync(cancellationToken);
        logger.LogInformation("Order-management schema constraints are ready.");
    }

    public async Task<IReadOnlyCollection<AdminOrderSummary>> ListAsync(
        string? state,
        int limit,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<AdminOrderSummary>();
        const string sql = """
            select o.id,o.customer_name,o.mobile,o.province,o.city,o.payable,o.currency,o.state,
                   o.created_at,o.reservation_expires_at,count(l.id)::int,
                   coalesce(p.reference,''),coalesce(p.state,'')
            from checkout_orders o
            left join checkout_order_lines l on l.order_id=o.id
            left join payments p on p.order_id=o.id
            where (@state = '' or lower(o.state)=lower(@state))
            group by o.id,p.reference,p.state
            order by o.created_at desc
            limit @limit;
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("state", state?.Trim() ?? string.Empty);
        command.Parameters.AddWithValue("limit", limit);
        var result = new List<AdminOrderSummary>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AdminOrderSummary(
                reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4),
                reader.GetDecimal(5), reader.GetString(6), Enum.Parse<OrderState>(reader.GetString(7)),
                reader.GetFieldValue<DateTimeOffset>(8), reader.GetFieldValue<DateTimeOffset>(9), reader.GetInt32(10),
                EmptyToNull(reader.GetString(11)), EmptyToNull(reader.GetString(12))));
        }
        return result;
    }

    public async Task<AdminDashboard> DashboardAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return new AdminDashboard(0, 0, 0, 0, 0, 0, Array.Empty<LowStockItem>());
        const string orderSql = """
            select
              count(*) filter (where state='AwaitingPayment')::int,
              count(*) filter (where state in ('Paid','Preparing'))::int,
              count(*) filter (where state='Shipped')::int,
              count(*) filter (where state='Delivered')::int,
              coalesce(sum(payable) filter (where state in ('Paid','Preparing','Shipped','Delivered')),0),
              coalesce(sum(payable) filter (where state in ('Paid','Preparing','Shipped','Delivered') and created_at >= date_trunc('day',now())),0)
            from checkout_orders;
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        int awaiting, processing, shipped, delivered;
        decimal paidRevenue, todayRevenue;
        await using (var command = new NpgsqlCommand(orderSql, connection))
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            await reader.ReadAsync(cancellationToken);
            awaiting = reader.GetInt32(0);
            processing = reader.GetInt32(1);
            shipped = reader.GetInt32(2);
            delivered = reader.GetInt32(3);
            paidRevenue = reader.GetDecimal(4);
            todayRevenue = reader.GetDecimal(5);
        }

        const string stockSql = """
            select p.title,v.sku,v.display_label,v.available_packages
            from product_variants v join products p on p.id=v.product_id
            where v.available_packages <= 5
            order by v.available_packages,p.title
            limit 20;
            """;
        var lowStock = new List<LowStockItem>();
        await using (var command = new NpgsqlCommand(stockSql, connection))
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken))
                lowStock.Add(new LowStockItem(reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetInt32(3)));

        return new AdminDashboard(awaiting, processing, shipped, delivered, paidRevenue, todayRevenue, lowStock);
    }

    public async Task<OrderOperationResult> TransitionAsync(
        Guid orderId,
        OrderState requestedState,
        string? reason,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured) return OrderOperationResult.Conflict("دیتابیس سفارش تنظیم نشده است.");
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        const string selectSql = """
            select state,reservation_expires_at from checkout_orders where id=@id for update;
            """;
        OrderState currentState;
        DateTimeOffset expiresAt;
        await using (var command = new NpgsqlCommand(selectSql, connection, transaction))
        {
            command.Parameters.AddWithValue("id", orderId);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return OrderOperationResult.NotFound("سفارش پیدا نشد.");
            }
            currentState = Enum.Parse<OrderState>(reader.GetString(0));
            expiresAt = reader.GetFieldValue<DateTimeOffset>(1);
        }

        if (currentState == requestedState)
        {
            await transaction.RollbackAsync(cancellationToken);
            var existing = (await ListOneAsync(connection, null, orderId, cancellationToken))!;
            return OrderOperationResult.Updated(existing);
        }

        if (!IsAllowed(currentState, requestedState))
        {
            await transaction.RollbackAsync(cancellationToken);
            return OrderOperationResult.Conflict($"انتقال سفارش از {currentState} به {requestedState} مجاز نیست.");
        }

        var stockLevels = new List<StockLevelChange>();
        if (requestedState == OrderState.Cancelled)
        {
            if (expiresAt <= DateTimeOffset.UtcNow)
            {
                await transaction.RollbackAsync(cancellationToken);
                return OrderOperationResult.Conflict("رزرو سفارش منقضی شده و توسط سیستم آزاد خواهد شد.");
            }
            const string linesSql = "select sku,quantity from checkout_order_lines where order_id=@id;";
            var lines = new List<(string Sku, int Quantity)>();
            await using (var command = new NpgsqlCommand(linesSql, connection, transaction))
            {
                command.Parameters.AddWithValue("id", orderId);
                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                while (await reader.ReadAsync(cancellationToken)) lines.Add((reader.GetString(0), reader.GetInt32(1)));
            }
            foreach (var line in lines)
            {
                await using var command = new NpgsqlCommand(
                    "update product_variants set available_packages=available_packages+@quantity where upper(sku)=upper(@sku) returning available_packages;",
                    connection, transaction);
                command.Parameters.AddWithValue("quantity", line.Quantity);
                command.Parameters.AddWithValue("sku", line.Sku);
                var available = await command.ExecuteScalarAsync(cancellationToken);
                if (available is not null) stockLevels.Add(new StockLevelChange(line.Sku, Convert.ToInt32(available)));
            }
        }

        var now = DateTimeOffset.UtcNow;
        await using (var command = new NpgsqlCommand("update checkout_orders set state=@state where id=@id;", connection, transaction))
        {
            command.Parameters.AddWithValue("state", requestedState.ToString());
            command.Parameters.AddWithValue("id", orderId);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        await using (var command = new NpgsqlCommand(
            "insert into checkout_order_transitions (id,order_id,state,actor,occurred_at,reason) values (@transition_id,@order_id,@state,'owner',@at,@reason);",
            connection, transaction))
        {
            command.Parameters.AddWithValue("transition_id", Guid.NewGuid());
            command.Parameters.AddWithValue("order_id", orderId);
            command.Parameters.AddWithValue("state", requestedState.ToString());
            command.Parameters.AddWithValue("at", now);
            command.Parameters.AddWithValue("reason", string.IsNullOrWhiteSpace(reason) ? $"owner-{requestedState.ToString().ToLowerInvariant()}" : reason.Trim());
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        var updated = await FindAsync(orderId, cancellationToken)
            ?? throw new InvalidOperationException("Updated order could not be read.");
        return OrderOperationResult.Updated(updated, stockLevels);
    }

    private async Task<AdminOrderSummary?> FindAsync(Guid orderId, CancellationToken cancellationToken)
    {
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        return await ListOneAsync(connection, null, orderId, cancellationToken);
    }

    private static async Task<AdminOrderSummary?> ListOneAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction? transaction,
        Guid orderId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            select o.id,o.customer_name,o.mobile,o.province,o.city,o.payable,o.currency,o.state,
                   o.created_at,o.reservation_expires_at,count(l.id)::int,
                   coalesce(p.reference,''),coalesce(p.state,'')
            from checkout_orders o
            left join checkout_order_lines l on l.order_id=o.id
            left join payments p on p.order_id=o.id
            where o.id=@id
            group by o.id,p.reference,p.state;
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("id", orderId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new AdminOrderSummary(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3),
            reader.GetString(4), reader.GetDecimal(5), reader.GetString(6), Enum.Parse<OrderState>(reader.GetString(7)),
            reader.GetFieldValue<DateTimeOffset>(8), reader.GetFieldValue<DateTimeOffset>(9), reader.GetInt32(10),
            EmptyToNull(reader.GetString(11)), EmptyToNull(reader.GetString(12)));
    }

    private static bool IsAllowed(OrderState current, OrderState requested) => (current, requested) switch
    {
        (OrderState.AwaitingPayment, OrderState.Cancelled) => true,
        (OrderState.Paid, OrderState.Preparing) => true,
        (OrderState.Preparing, OrderState.Shipped) => true,
        (OrderState.Shipped, OrderState.Delivered) => true,
        _ => false
    };

    private static string? EmptyToNull(string value) => string.IsNullOrEmpty(value) ? null : value;
}

public sealed class OrderManagementSchemaInitializer(OrderManagementDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken) => database.InitializeAsync(cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

public sealed record SetOrderStateRequest(string State, string? Reason);
public sealed record AdminOrderSummary(Guid Id, string CustomerName, string Mobile, string Province, string City,
    decimal Payable, string Currency, OrderState State, DateTimeOffset CreatedAt, DateTimeOffset ReservationExpiresAt,
    int LineCount, string? PaymentReference, string? PaymentState);
public sealed record LowStockItem(string ProductTitle, string Sku, string VariantLabel, int AvailablePackages);
public sealed record AdminDashboard(int AwaitingPayment, int Processing, int Shipped, int Delivered,
    decimal PaidRevenue, decimal TodayRevenue, IReadOnlyCollection<LowStockItem> LowStock);
public enum OrderOperationStatus { Updated, NotFound, Conflict }
public sealed record OrderOperationResult(OrderOperationStatus Status, AdminOrderSummary? Order = null,
    string? Message = null, IReadOnlyCollection<StockLevelChange>? StockLevels = null)
{
    public static OrderOperationResult Updated(AdminOrderSummary order, IReadOnlyCollection<StockLevelChange>? levels = null) =>
        new(OrderOperationStatus.Updated, order, StockLevels: levels);
    public static OrderOperationResult NotFound(string message) => new(OrderOperationStatus.NotFound, Message: message);
    public static OrderOperationResult Conflict(string message) => new(OrderOperationStatus.Conflict, Message: message);
}
