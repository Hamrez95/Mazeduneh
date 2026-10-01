using System.Text.Json;
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
            string? q,
            int? limit,
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
        {
            if (!string.IsNullOrWhiteSpace(state) && !Enum.TryParse<OrderState>(state, true, out _))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["state"] = ["وضعیت سفارش معتبر نیست."] });
            if (q?.Length > 120)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["q"] = ["عبارت جست‌وجو نمی‌تواند بیشتر از ۱۲۰ نویسه باشد."] });
            return Results.Ok(await database.ListAsync(state, q, Math.Clamp(limit ?? 100, 1, 250), cancellationToken));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/orders/{orderId:guid}", async (
            Guid orderId,
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
        {
            var detail = await database.GetDetailAsync(orderId, cancellationToken);
            return detail is null ? Results.NotFound(new { message = "سفارش پیدا نشد." }) : Results.Ok(detail);
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapPost("/orders/{orderId:guid}/notes", async (
            Guid orderId,
            AdminOrderNoteInput input,
            OrderManagementDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(input.Note) || input.Note.Trim().Length > 2_000)
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(input.Note)] = ["یادداشت باید بین ۱ تا ۲۰۰۰ نویسه باشد."] });
            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var note = await database.AddNoteAsync(orderId, input.Note, actor, cancellationToken);
            return note is null ? Results.NotFound(new { message = "سفارش پیدا نشد." }) : Results.Created($"/api/v1/admin/orders/{orderId}/notes/{note.Id}", note);
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapPatch("/orders/{orderId:guid}/shipping", async (
            Guid orderId,
            AdminShipmentUpdateInput input,
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
        {
            var errors = new Dictionary<string, string[]>();
            if (input.Carrier is { Length: > 120 }) errors[nameof(input.Carrier)] = ["نام شرکت حمل نمی‌تواند بیشتر از ۱۲۰ نویسه باشد."];
            if (input.TrackingCode is { Length: > 120 }) errors[nameof(input.TrackingCode)] = ["کد رهگیری نمی‌تواند بیشتر از ۱۲۰ نویسه باشد."];
            if (input.ActualShippingCost is < 0 or > 1_000_000_000) errors[nameof(input.ActualShippingCost)] = ["هزینه واقعی ارسال باید بین صفر تا یک میلیارد باشد."];
            if (errors.Count > 0) return Results.ValidationProblem(errors);
            var updated = await database.UpdateShippingAsync(orderId, input, cancellationToken);
            return updated is null ? Results.NotFound(new { message = "سفارش پیدا نشد." }) : Results.Ok(updated);
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/dashboard", async (
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
            Results.Ok(await database.DashboardAsync(cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/analytics", async (
            int? days,
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
            Results.Ok(await database.AnalyticsAsync(Math.Clamp(days ?? 30, 1, 365), cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/notifications", async (
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
            Results.Ok(await database.NotificationsAsync(cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapPatch("/orders/{orderId:guid}/state", async (
            Guid orderId,
            SetOrderStateRequest request,
            OrderManagementDatabase database,
            ProductCatalog catalog,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (!Enum.TryParse<OrderState>(request.State, true, out var requestedState))
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(request.State)] = ["وضعیت سفارش معتبر نیست."] });

            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var result = await database.TransitionAsync(orderId, requestedState, request.Reason, actor, cancellationToken);
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

public sealed class OrderManagementDatabase(IConfiguration configuration, ILogger<OrderManagementDatabase> logger, InventoryLedgerDatabase ledger)
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
        await DatabaseMigrationRunner.ApplyAsync(connection, "orders", "001-bootstrap", sql, cancellationToken);
        const string notesSql = """
            create table if not exists order_internal_notes (
                id uuid primary key,
                order_id uuid not null references checkout_orders(id) on delete cascade,
                note text not null check (char_length(note) between 1 and 2000),
                actor varchar(180) not null,
                created_at timestamptz not null
            );
            create index if not exists ix_order_internal_notes_order on order_internal_notes(order_id, created_at desc);
            """;
        await DatabaseMigrationRunner.ApplyAsync(connection, "orders", "002-internal-notes", notesSql, cancellationToken);
        const string shippingDetailsSql = """
            alter table checkout_orders add column if not exists shipping_carrier varchar(120);
            alter table checkout_orders add column if not exists tracking_code varchar(120);
            alter table checkout_orders add column if not exists shipped_at timestamptz;
            create index if not exists ix_checkout_orders_tracking_code on checkout_orders(tracking_code);
            """;
        await DatabaseMigrationRunner.ApplyAsync(connection, "orders", "003-shipping-details", shippingDetailsSql, cancellationToken);
        logger.LogInformation("Order-management schema constraints are ready.");
    }

    public async Task<IReadOnlyCollection<AdminOrderSummary>> ListAsync(
        string? state,
        string? query,
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
              and (@query = '' or o.id::text ilike '%' || @query || '%'
                   or o.customer_name ilike '%' || @query || '%'
                   or o.mobile ilike '%' || @query || '%'
                   or o.city ilike '%' || @query || '%')
            group by o.id,p.reference,p.state
            order by o.created_at desc
            limit @limit;
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("state", state?.Trim() ?? string.Empty);
        command.Parameters.AddWithValue("query", query?.Trim() ?? string.Empty);
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

    public async Task<AdminOrderDetail?> GetDetailAsync(Guid orderId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string orderSql = """
            select o.id,o.customer_name,o.mobile,o.province,o.city,o.address,o.postal_code,
                   o.currency,o.subtotal,o.shipping,o.shipping_expense,o.discount,o.payable,
                   o.tax_rate_percent,o.tax,o.shipping_method,o.shipping_carrier,o.tracking_code,o.shipped_at,
                   o.state,o.created_at,o.reservation_expires_at,
                   count(l.id)::int,coalesce(p.reference,''),coalesce(p.state,'')
            from checkout_orders o
            left join checkout_order_lines l on l.order_id=o.id
            left join payments p on p.order_id=o.id
            where o.id=@id
            group by o.id,p.reference,p.state;
            """;
        await using var orderCommand = new NpgsqlCommand(orderSql, connection);
        orderCommand.Parameters.AddWithValue("id", orderId);
        await using var reader = await orderCommand.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;

        var summary = new AdminOrderSummary(
            reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4),
            reader.GetDecimal(12), reader.GetString(7), Enum.Parse<OrderState>(reader.GetString(19)),
            reader.GetFieldValue<DateTimeOffset>(20), reader.GetFieldValue<DateTimeOffset>(21), reader.GetInt32(22),
            EmptyToNull(reader.GetString(23)), EmptyToNull(reader.GetString(24)));
        var detail = new AdminOrderDetail(
            summary, reader.GetString(5), reader.GetString(6), reader.GetDecimal(8), reader.GetDecimal(9),
            reader.GetDecimal(10), reader.GetDecimal(11), reader.GetDecimal(14), reader.GetDecimal(13),
            reader.GetString(15), EmptyToNull(reader.GetString(16)), EmptyToNull(reader.GetString(17)),
            reader.IsDBNull(18) ? null : reader.GetFieldValue<DateTimeOffset>(18),
            Array.Empty<AdminOrderLine>(), Array.Empty<AdminOrderTransition>(), Array.Empty<AdminOrderNote>());
        await reader.CloseAsync();

        var lines = new List<AdminOrderLine>();
        const string linesSql = "select product_title,sku,variant_label,quantity,unit_price,line_total from checkout_order_lines where order_id=@id order by id;";
        await using (var command = new NpgsqlCommand(linesSql, connection))
        {
            command.Parameters.AddWithValue("id", orderId);
            await using var lineReader = await command.ExecuteReaderAsync(cancellationToken);
            while (await lineReader.ReadAsync(cancellationToken))
                lines.Add(new AdminOrderLine(lineReader.GetString(0), lineReader.GetString(1), lineReader.GetString(2), lineReader.GetInt32(3), lineReader.GetDecimal(4), lineReader.GetDecimal(5)));
        }

        var transitions = new List<AdminOrderTransition>();
        const string transitionsSql = "select state,actor,occurred_at,reason from checkout_order_transitions where order_id=@id order by occurred_at;";
        await using (var command = new NpgsqlCommand(transitionsSql, connection))
        {
            command.Parameters.AddWithValue("id", orderId);
            await using var transitionReader = await command.ExecuteReaderAsync(cancellationToken);
            while (await transitionReader.ReadAsync(cancellationToken))
                transitions.Add(new AdminOrderTransition(Enum.Parse<OrderState>(transitionReader.GetString(0)), transitionReader.GetString(1), transitionReader.GetFieldValue<DateTimeOffset>(2), transitionReader.GetString(3)));
        }

        var notes = new List<AdminOrderNote>();
        const string notesSql = "select id,note,actor,created_at from order_internal_notes where order_id=@id order by created_at desc;";
        await using (var command = new NpgsqlCommand(notesSql, connection))
        {
            command.Parameters.AddWithValue("id", orderId);
            await using var noteReader = await command.ExecuteReaderAsync(cancellationToken);
            while (await noteReader.ReadAsync(cancellationToken))
                notes.Add(new AdminOrderNote(noteReader.GetGuid(0), noteReader.GetString(1), noteReader.GetString(2), noteReader.GetFieldValue<DateTimeOffset>(3)));
        }

        AdminPayment? payment = null;
        const string paymentSql = "select provider,amount,currency,state,reference,created_at,completed_at from payments where order_id=@id;";
        await using (var command = new NpgsqlCommand(paymentSql, connection))
        {
            command.Parameters.AddWithValue("id", orderId);
            await using var paymentReader = await command.ExecuteReaderAsync(cancellationToken);
            if (await paymentReader.ReadAsync(cancellationToken))
                payment = new AdminPayment(paymentReader.GetString(0), paymentReader.GetDecimal(1), paymentReader.GetString(2), Enum.Parse<PaymentState>(paymentReader.GetString(3)), EmptyToNull(paymentReader.GetString(4)), paymentReader.GetFieldValue<DateTimeOffset>(5), paymentReader.IsDBNull(6) ? null : paymentReader.GetFieldValue<DateTimeOffset>(6));
        }

        return detail with { Lines = lines, Transitions = transitions, Notes = notes, Payment = payment };
    }

    public async Task<AdminOrderNote?> AddNoteAsync(Guid orderId, string note, string actor, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string sql = """
            insert into order_internal_notes(id,order_id,note,actor,created_at)
            select @id,@order_id,@note,@actor,now()
            where exists(select 1 from checkout_orders where id=@order_id)
            returning id,note,actor,created_at;
            """;
        await using var command = new NpgsqlCommand(sql, connection);
        var id = Guid.NewGuid();
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("order_id", orderId);
        command.Parameters.AddWithValue("note", note.Trim());
        command.Parameters.AddWithValue("actor", actor);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken)
            ? new AdminOrderNote(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetFieldValue<DateTimeOffset>(3))
            : null;
    }

    public async Task<AdminOrderDetail?> UpdateShippingAsync(Guid orderId, AdminShipmentUpdateInput input, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string sql = """
            update checkout_orders
            set shipping_carrier=@carrier, tracking_code=@tracking_code, shipping_expense=@expense,
                shipped_at=case when @tracking_code is not null and nullif(@tracking_code,'') is not null then coalesce(shipped_at,now()) else shipped_at end
            where id=@id;
            """;
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("carrier", (object?)input.Carrier?.Trim() ?? DBNull.Value);
        command.Parameters.AddWithValue("tracking_code", (object?)input.TrackingCode?.Trim() ?? DBNull.Value);
        command.Parameters.AddWithValue("expense", input.ActualShippingCost ?? 0m);
        command.Parameters.AddWithValue("id", orderId);
        if (await command.ExecuteNonQueryAsync(cancellationToken) == 0) return null;
        return await GetDetailAsync(orderId, cancellationToken);
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

    public async Task<AdminAnalytics> AnalyticsAsync(int days, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return new AdminAnalytics(days, 0, 0, 0, 0, 0, 0);
        var from = DateTimeOffset.UtcNow.AddDays(-days);
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string orderSql = """
            select count(*)::int, coalesce(sum(payable),0), coalesce(sum(tax),0), coalesce(sum(shipping_expense),0)
            from checkout_orders
            where created_at >= @from and state in ('Paid','Preparing','Shipped','Delivered');
            """;
        int orderCount;
        decimal revenue;
        decimal tax;
        decimal shippingExpense;
        await using (var command = new NpgsqlCommand(orderSql, connection))
        {
            command.Parameters.AddWithValue("from", from);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            await reader.ReadAsync(cancellationToken);
            orderCount = reader.GetInt32(0);
            revenue = reader.GetDecimal(1);
            tax = reader.GetDecimal(2);
            shippingExpense = reader.GetDecimal(3);
        }

        const string lineSql = """
            select coalesce(sum(l.quantity),0)::int, coalesce(sum(l.quantity*(l.cost_price+l.packaging_cost+l.additional_cost)),0), coalesce(sum(l.line_total),0)
            from checkout_order_lines l join checkout_orders o on o.id=l.order_id
            where o.created_at >= @from and o.state in ('Paid','Preparing','Shipped','Delivered');
            """;
        int units;
        decimal cost;
        decimal merchandiseRevenue;
        await using (var command = new NpgsqlCommand(lineSql, connection))
        {
            command.Parameters.AddWithValue("from", from);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            await reader.ReadAsync(cancellationToken);
            units = reader.GetInt32(0);
            cost = reader.GetDecimal(1);
            merchandiseRevenue = reader.GetDecimal(2);
        }

        var profit = revenue - cost;
        var netProfit = profit - shippingExpense - tax;
        var margin = revenue <= 0 ? 0 : profit / revenue * 100;
        return new AdminAnalytics(days, orderCount, units, revenue, cost, profit, margin, tax, netProfit, shippingExpense);
    }

    public async Task<AdminNotifications> NotificationsAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return new AdminNotifications(0, 0, Array.Empty<AdminNotification>());
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string orderSql = """
            select count(*) filter (where state='AwaitingPayment')::int,
                   count(*) filter (where created_at >= now() - interval '24 hours' and state not in ('Cancelled','Expired'))::int
            from checkout_orders;
            """;
        int awaitingPayment;
        int recentOrders;
        await using (var command = new NpgsqlCommand(orderSql, connection))
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            await reader.ReadAsync(cancellationToken);
            awaitingPayment = reader.GetInt32(0);
            recentOrders = reader.GetInt32(1);
        }

        const string stockSql = "select p.title,v.sku,v.available_packages from product_variants v join products p on p.id=v.product_id where v.available_packages <= 5 order by v.available_packages,p.title limit 20;";
        var items = new List<AdminNotification>();
        await using (var command = new NpgsqlCommand(stockSql, connection))
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken))
                items.Add(new AdminNotification("low-stock", $"موجودی {reader.GetString(0)} کم است.", $"{reader.GetString(1)} · {reader.GetInt32(2)} بسته"));

        if (awaitingPayment > 0)
            items.Insert(0, new AdminNotification("awaiting-payment", $"{awaitingPayment} سفارش در انتظار پرداخت است.", "نیازمند بررسی پنل سفارش‌ها"));
        if (recentOrders > 0)
            items.Insert(0, new AdminNotification("new-orders", $"{recentOrders} سفارش در ۲۴ ساعت اخیر ثبت یا پردازش شده.", "مرور سفارش‌ها و وضعیت ارسال"));
        return new AdminNotifications(awaitingPayment, items.Count(item => item.Type == "low-stock"), items);
    }

    public async Task<OrderOperationResult> TransitionAsync(
        Guid orderId,
        OrderState requestedState,
        string? reason,
        string actor,
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
            const string linesSql = "select sku,quantity,batch_allocations from checkout_order_lines where order_id=@id;";
            var lines = new List<(string Sku, int Quantity, string BatchAllocationsJson)>();
            await using (var command = new NpgsqlCommand(linesSql, connection, transaction))
            {
                command.Parameters.AddWithValue("id", orderId);
                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                while (await reader.ReadAsync(cancellationToken))
                    lines.Add((reader.GetString(0), reader.GetInt32(1), reader.GetString(2)));
            }
            foreach (var line in lines)
            {
                var allocations = JsonSerializer.Deserialize<IReadOnlyCollection<CheckoutBatchAllocation>>(line.BatchAllocationsJson)
                    ?? Array.Empty<CheckoutBatchAllocation>();
                foreach (var allocation in allocations)
                {
                    await using var batchCommand = new NpgsqlCommand(
                        "update inventory_batches set remaining_packages=least(received_packages,remaining_packages+@quantity) where upper(sku)=upper(@sku) and batch_code=@batch_code;",
                        connection, transaction);
                    batchCommand.Parameters.AddWithValue("quantity", allocation.Quantity);
                    batchCommand.Parameters.AddWithValue("sku", line.Sku);
                    batchCommand.Parameters.AddWithValue("batch_code", allocation.BatchCode);
                    await batchCommand.ExecuteNonQueryAsync(cancellationToken);
                }

                await using var command = new NpgsqlCommand(
                    "update product_variants set available_packages=available_packages+@quantity where upper(sku)=upper(@sku) returning available_packages;",
                    connection, transaction);
                command.Parameters.AddWithValue("quantity", line.Quantity);
                command.Parameters.AddWithValue("sku", line.Sku);
                var available = await command.ExecuteScalarAsync(cancellationToken);
                if (available is not null)
                {
                    var availablePackages = Convert.ToInt32(available);
                    await ledger.RecordAsync(
                        connection, transaction, line.Sku, line.Quantity, "ReservationReleased",
                        availablePackages, orderId, actor, "owner-cancelled-before-payment", cancellationToken);
                    stockLevels.Add(new StockLevelChange(line.Sku, availablePackages));
                }
            }        }

        var now = DateTimeOffset.UtcNow;
        await using (var command = new NpgsqlCommand("update checkout_orders set state=@state where id=@id;", connection, transaction))
        {
            command.Parameters.AddWithValue("state", requestedState.ToString());
            command.Parameters.AddWithValue("id", orderId);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        await using (var command = new NpgsqlCommand(
            "insert into checkout_order_transitions (id,order_id,state,actor,occurred_at,reason) values (@transition_id,@order_id,@state,@actor,@at,@reason);",
            connection, transaction))
        {
            command.Parameters.AddWithValue("transition_id", Guid.NewGuid());
            command.Parameters.AddWithValue("order_id", orderId);
            command.Parameters.AddWithValue("state", requestedState.ToString());
            command.Parameters.AddWithValue("actor", actor);
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
public sealed record AdminOrderNoteInput(string Note);
public sealed record AdminShipmentUpdateInput(string? Carrier, string? TrackingCode, decimal? ActualShippingCost);
public sealed record AdminOrderSummary(Guid Id, string CustomerName, string Mobile, string Province, string City,
    decimal Payable, string Currency, OrderState State, DateTimeOffset CreatedAt, DateTimeOffset ReservationExpiresAt,
    int LineCount, string? PaymentReference, string? PaymentState);
public sealed record AdminOrderDetail(AdminOrderSummary Summary, string Address, string PostalCode, decimal Subtotal,
    decimal Shipping, decimal ShippingExpense, decimal Discount, decimal Tax, decimal TaxRatePercent, string ShippingMethod,
    string? ShippingCarrier, string? TrackingCode, DateTimeOffset? ShippedAt,
    IReadOnlyCollection<AdminOrderLine> Lines, IReadOnlyCollection<AdminOrderTransition> Transitions,
    IReadOnlyCollection<AdminOrderNote> Notes, AdminPayment? Payment = null)
{
    public Guid Id => Summary.Id;
    public string CustomerName => Summary.CustomerName;
    public string Mobile => Summary.Mobile;
    public string Province => Summary.Province;
    public string City => Summary.City;
    public decimal Payable => Summary.Payable;
    public string Currency => Summary.Currency;
    public OrderState State => Summary.State;
    public DateTimeOffset CreatedAt => Summary.CreatedAt;
    public DateTimeOffset ReservationExpiresAt => Summary.ReservationExpiresAt;
    public int LineCount => Summary.LineCount;
    public string? PaymentReference => Summary.PaymentReference;
    public string? PaymentState => Summary.PaymentState;
}
public sealed record AdminOrderLine(string ProductTitle, string Sku, string VariantLabel, int Quantity, decimal UnitPrice, decimal LineTotal);
public sealed record AdminOrderTransition(OrderState State, string Actor, DateTimeOffset OccurredAt, string Reason);
public sealed record AdminOrderNote(Guid Id, string Note, string Actor, DateTimeOffset CreatedAt);
public sealed record AdminPayment(string Provider, decimal Amount, string Currency, PaymentState State, string? Reference, DateTimeOffset CreatedAt, DateTimeOffset? CompletedAt);
public sealed record LowStockItem(string ProductTitle, string Sku, string VariantLabel, int AvailablePackages);
public sealed record AdminDashboard(int AwaitingPayment, int Processing, int Shipped, int Delivered,
    decimal PaidRevenue, decimal TodayRevenue, IReadOnlyCollection<LowStockItem> LowStock);
public sealed record AdminAnalytics(int Days, int OrderCount, int UnitsSold, decimal Revenue, decimal Cost, decimal GrossProfit, decimal GrossMarginPercent, decimal Tax = 0, decimal NetProfit = 0, decimal ShippingExpense = 0);
public sealed record AdminNotification(string Type, string Title, string Detail);
public sealed record AdminNotifications(int AwaitingPayment, int LowStockItems, IReadOnlyCollection<AdminNotification> Items);
public enum OrderOperationStatus { Updated, NotFound, Conflict }
public sealed record OrderOperationResult(OrderOperationStatus Status, AdminOrderSummary? Order = null,
    string? Message = null, IReadOnlyCollection<StockLevelChange>? StockLevels = null)
{
    public static OrderOperationResult Updated(AdminOrderSummary order, IReadOnlyCollection<StockLevelChange>? levels = null) =>
        new(OrderOperationStatus.Updated, order, StockLevels: levels);
    public static OrderOperationResult NotFound(string message) => new(OrderOperationStatus.NotFound, Message: message);
    public static OrderOperationResult Conflict(string message) => new(OrderOperationStatus.Conflict, Message: message);
}
