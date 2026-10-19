using System.Text.Json;
using System.Text;
using System.Security.Cryptography;
using Microsoft.Extensions.Options;
using Npgsql;

public static class OrderManagementModule
{
    public static IServiceCollection AddOrderManagement(this IServiceCollection services)
    {
        services.AddSingleton<OrderManagementDatabase>();
        return services;
    }

    public static IEndpointRouteBuilder MapOrderManagement(this IEndpointRouteBuilder endpoints)
    {
        var admin = endpoints.MapGroup("/api/v1/admin").WithTags("Admin Orders");

        admin.MapGet("/orders", async (
            string? state,
            string? q,
            int? limit,
            DateTimeOffset? from,
            DateTimeOffset? to,
            OrderManagementDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (!IsValidOrderFilter(state))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["state"] = ["وضعیت سفارش معتبر نیست."] });
            if (q?.Length > 120)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["q"] = ["عبارت جست‌وجو نمی‌تواند بیشتر از ۱۲۰ نویسه باشد."] });
            if (!DashboardPeriod.TryCreate(from, to, DateTimeOffset.UtcNow, out var period))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["from"] = ["بازهٔ زمانی نامعتبر است؛ شروع و پایان معتبر را حداکثر برای یک سال انتخاب کنید."] });
            var rows = await database.ListAsync(
                state, q, Math.Clamp(limit ?? 100, 1, 250), cancellationToken,
                CustomerPrivacy.CanReadPii(context), period?.From, period?.To);
            return Results.Ok(rows.Select(row => OrderPrivacy.Project(row, context)));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/orders/export.csv", async (
            string? state,
            string? q,
            int? limit,
            DateTimeOffset? from,
            DateTimeOffset? to,
            OrderManagementDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (!IsValidOrderFilter(state))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["state"] = ["وضعیت سفارش معتبر نیست."] });
            if (q?.Length > 120)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["q"] = ["عبارت جست‌وجو نمی‌تواند بیشتر از ۱۲۰ نویسه باشد."] });
            if (!DashboardPeriod.TryCreate(from, to, DateTimeOffset.UtcNow, out var period))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["from"] = ["بازهٔ زمانی نامعتبر است؛ شروع و پایان معتبر را حداکثر برای یک سال انتخاب کنید."] });
            var orders = await database.ListAsync(
                state, q, Math.Clamp(limit ?? 1_000, 1, 5_000), cancellationToken,
                CustomerPrivacy.CanReadPii(context), period?.From, period?.To);
            static string Csv(object? value)
            {
                var text = value?.ToString() ?? string.Empty;
                return $"\"{text.Replace("\"", "\"\"")}\"";
            }
            var builder = new StringBuilder("\uFEFFشناسه سفارش,نوع سفارش,مشتری,موبایل,شهر,وضعیت,مبلغ,ارز,تعداد اقلام,زمان ثبت,وضعیت پرداخت,شناسه پرداخت\n");
            foreach (var rawOrder in orders)
            {
                var order = OrderPrivacy.Project(rawOrder, context);
                builder.AppendJoin(',', new[] { Csv(order.Id), Csv(order.IsPrivate ? "خصوصی" : "سایت"), Csv(order.CustomerName), Csv(order.Mobile), Csv($"{order.Province}، {order.City}"),
                    Csv(order.State), Csv(order.Payable.ToString("0.##")), Csv(order.Currency), Csv(order.LineCount),
                    Csv(order.CreatedAt.ToString("O")), Csv(order.PaymentState), Csv(order.PaymentReference) }).Append('\n');
            }
            return Results.File(Encoding.UTF8.GetBytes(builder.ToString()), "text/csv; charset=utf-8", "mazeduneh-orders.csv");
        }).AddEndpointFilter<OwnerAuthorizationFilter>()
          .AddEndpointFilter<StepUpAuthorizationFilter>()
          .WithMetadata(new StepUpPermissionRequirement(AdminPermissionCatalog.OrdersExport));

        admin.MapGet("/orders/{orderId:guid}", async (
            Guid orderId,
            OrderManagementDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var detail = await database.GetDetailAsync(orderId, cancellationToken);
            return detail is null ? Results.NotFound(new { message = "سفارش پیدا نشد." }) : Results.Ok(OrderPrivacy.Project(detail, context));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/orders/{orderId:guid}/invoice", async (
            Guid orderId,
            OrderManagementDatabase database,
            HttpResponse response,
            CancellationToken cancellationToken) =>
        {
            var detail = await database.GetDetailAsync(orderId, cancellationToken);
            if (detail is null) return Results.NotFound(new { message = "سفارش پیدا نشد." });
            response.Headers.ContentDisposition = $"inline; filename=\"mazeduneh-invoice-{orderId:N}.html\"";
            return Results.Content(InvoiceRenderer.Render(detail.ToCheckoutOrder()), "text/html; charset=utf-8", Encoding.UTF8);
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/orders/{orderId:guid}/packing-slip", async (
            Guid orderId,
            OrderManagementDatabase database,
            HttpResponse response,
            CancellationToken cancellationToken) =>
        {
            var detail = await database.GetDetailAsync(orderId, cancellationToken);
            if (detail is null) return Results.NotFound(new { message = "سفارش پیدا نشد." });
            response.Headers.ContentDisposition = $"inline; filename=\"mazeduneh-packing-slip-{orderId:N}.html\"";
            return Results.Content(PackingSlipRenderer.Render(detail.ToCheckoutOrder()), "text/html; charset=utf-8", Encoding.UTF8);
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
            return note is null ? Results.NotFound(new { message = "سفارش پیدا نشد." }) : Results.Created($"/api/v1/admin/orders/{orderId}/notes/{note.Id}", OrderPrivacy.Project(note, context));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapPost("/orders/private", async (
            CheckoutRequest request,
            CheckoutDatabase checkout,
            AdminAuditLogDatabase audit,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var cleanRequest = request with { CouponCode = null, MarketingConsent = false };
            var errors = cleanRequest.Validate();
            if (errors.Count > 0) return Results.ValidationProblem(errors);
            var principal = (AdminPrincipal?)context.Items["AdminPrincipal"];
            if (principal is null) return Results.Unauthorized();
            var idempotencyKey = $"private-order:{Guid.NewGuid():N}";
            var fingerprint = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(cleanRequest))));
            var created = await checkout.CreateAsync(idempotencyKey, fingerprint, cleanRequest, cancellationToken, isPrivate: true);
            if (created.Status == CheckoutStatus.OutOfStock)
                return Results.Conflict(new { message = created.Message, unavailableSkus = created.UnavailableSkus });
            if (created.Status == CheckoutStatus.Conflict)
                return Results.Conflict(new { message = created.Message });
            if (created.Status != CheckoutStatus.Created || created.Order is null)
                return Results.Problem("ثبت سفارش خصوصی انجام نشد.", statusCode: StatusCodes.Status503ServiceUnavailable);
            var order = created.Order;
            await audit.RecordAsync(principal.Email, "order.private-created", "Order", order.Id.ToString("D"), null,
                new { order.Payable, Currency = order.Currency, LineCount = order.Lines.Count, order.ShippingMethod },
                "ثبت سفارش سفارشی فقط برای عملیات داخلی؛ در سایت و حساب مشتری نمایش داده نمی‌شود.", context.TraceIdentifier,
                cancellationToken, principal.StoreId);
            return Results.Created($"/api/v1/admin/orders/{order.Id}", new
            {
                id = order.Id,
                order.Payable,
                order.Currency,
                state = order.State,
                lineCount = order.Lines.Count,
                createdAt = order.CreatedAt,
                isPrivate = true
            });
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapPost("/orders/{orderId:guid}/internal-costs", async (
            Guid orderId,
            AdminOrderInternalCostInput input,
            OrderManagementDatabase database,
            AdminAuditLogDatabase audit,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var errors = new Dictionary<string, string[]>();
            if (string.IsNullOrWhiteSpace(input.Title) || input.Title.Trim().Length > 160)
                errors[nameof(input.Title)] = ["عنوان هزینه باید بین ۱ تا ۱۶۰ نویسه باشد."];
            if (input.Amount is <= 0 or > 1_000_000_000_000)
                errors[nameof(input.Amount)] = ["مبلغ هزینه باید بیشتر از صفر و حداکثر یک‌هزار میلیارد ریال باشد."];
            if (errors.Count > 0) return Results.ValidationProblem(errors);
            var principal = (AdminPrincipal?)context.Items["AdminPrincipal"];
            if (principal is null) return Results.Unauthorized();
            var cost = await database.AddInternalCostAsync(orderId, input, principal.Email,
                context.TraceIdentifier, principal.StoreId, audit, cancellationToken);
            return cost is null
                ? Results.NotFound(new { message = "سفارش پیدا نشد." })
                : Results.Created($"/api/v1/admin/orders/{orderId}/internal-costs/{cost.Id}", cost);
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapDelete("/orders/{orderId:guid}/internal-costs/{costId:guid}", async (
            Guid orderId,
            Guid costId,
            OrderManagementDatabase database,
            AdminAuditLogDatabase audit,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var principal = (AdminPrincipal?)context.Items["AdminPrincipal"];
            if (principal is null) return Results.Unauthorized();
            var removed = await database.RemoveInternalCostAsync(orderId, costId, principal.Email,
                context.TraceIdentifier, principal.StoreId, audit, cancellationToken);
            return removed ? Results.NoContent() : Results.NotFound(new { message = "هزینه داخلی پیدا نشد." });
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapPatch("/orders/{orderId:guid}/shipping", async (
            Guid orderId,
            AdminShipmentUpdateInput input,
            OrderManagementDatabase database,
            AdminAuditLogDatabase audit,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var errors = new Dictionary<string, string[]>();
            if (input.Carrier is { Length: > 120 }) errors[nameof(input.Carrier)] = ["نام شرکت حمل نمی‌تواند بیشتر از ۱۲۰ نویسه باشد."];
            if (input.TrackingCode is { Length: > 120 }) errors[nameof(input.TrackingCode)] = ["کد رهگیری نمی‌تواند بیشتر از ۱۲۰ نویسه باشد."];
            if (input.UpdateActualShippingCost && (input.ActualShippingCost is < 0 or > 1_000_000_000)) errors[nameof(input.ActualShippingCost)] = ["هزینه واقعی ارسال باید بین صفر تا یک میلیارد باشد."];
            if (string.IsNullOrWhiteSpace(input.Reason) || input.Reason.Trim().Length > 500)
                errors[nameof(input.Reason)] = ["دلیل ثبت یا اصلاح اطلاعات ارسال باید بین ۱ تا ۵۰۰ نویسه باشد."];
            if (errors.Count > 0) return Results.ValidationProblem(errors);
            var principal = (AdminPrincipal?)context.Items["AdminPrincipal"];
            if (principal is null) return Results.Unauthorized();
            var updated = await database.UpdateShippingAsync(
                orderId, input, principal.Email, context.TraceIdentifier, audit, cancellationToken);
            return updated is null ? Results.NotFound(new { message = "سفارش پیدا نشد." }) : Results.Ok(OrderPrivacy.Project(updated, context));
        }).AddEndpointFilter<OwnerAuthorizationFilter>()
          .AddEndpointFilter<OrderShippingCostStepUpAuthorizationFilter>();

        admin.MapGet("/dashboard", async (
            int? days,
            DateTimeOffset? from,
            DateTimeOffset? to,
            OrderManagementDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (context.Items["AdminPrincipal"] is not AdminPrincipal principal) return Results.Unauthorized();
            if (!DashboardPeriod.TryCreate(from, to, DateTimeOffset.UtcNow, out var period))
                return Results.BadRequest(new { message = "بازهٔ انتخابی نامعتبر است؛ تاریخ پایان باید بعد از شروع و حداکثر یک سال باشد." });
            var dashboard = await database.DashboardAsync(Math.Clamp(days ?? 1, 1, 365), cancellationToken, period);
            var canReadOrders = AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.OrdersRead);
            var canReadInventory = AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.InventoryRead);
            var canReadCustomers = AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.CustomersRead);
            var canReadCorporate = AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.CorporateRead);
            var canReadReports = AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.ReportsRead);
            dashboard = dashboard with
            {
                AwaitingPayment = canReadOrders ? dashboard.AwaitingPayment : 0,
                Processing = canReadOrders ? dashboard.Processing : 0,
                Shipped = canReadOrders ? dashboard.Shipped : 0,
                Delivered = canReadOrders ? dashboard.Delivered : 0,
                PeriodOrderCount = canReadOrders ? dashboard.PeriodOrderCount : 0,
                ProblemOrders = canReadOrders ? dashboard.ProblemOrders : 0,
                LowStock = canReadInventory ? dashboard.LowStock : Array.Empty<LowStockItem>(),
                ExpiringSoon = canReadInventory ? dashboard.ExpiringSoon : Array.Empty<ExpiringStockItem>(),
                NewCustomers = canReadCustomers ? dashboard.NewCustomers : 0,
                CorporateNewRequests = canReadCorporate ? dashboard.CorporateNewRequests : 0,
                PaidRevenue = canReadReports ? dashboard.PaidRevenue : 0,
                TodayRevenue = canReadReports ? dashboard.TodayRevenue : 0,
                PeriodRevenue = canReadReports ? dashboard.PeriodRevenue : 0,
                AverageOrderValue = canReadReports ? dashboard.AverageOrderValue : 0,
                FinancialsVisible = canReadReports
            };
            return Results.Ok(dashboard);
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/dashboard/health", async (
            ApiHealthProbe healthProbe,
            AdminTokenService adminTokens,
            PaymentDatabase payments,
            ZibalGateway zibal,
            IOptions<MediaStorageOptions> mediaOptions,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (context.Items["AdminPrincipal"] is not AdminPrincipal) return Results.Unauthorized();
            context.Response.Headers.CacheControl = "no-store";
            var database = await healthProbe.CheckDatabaseAsync(cancellationToken);
            var authentication = adminTokens.IsConfigured ? "configured" : "not-configured";
            var payment = zibal.IsConfigured ? "zibal-configured" : payments.SandboxEnabled ? "sandbox-enabled" : "disabled";
            var storageOptions = mediaOptions.Value;
            var storage = storageOptions.Provider.Trim().ToLowerInvariant() switch
            {
                "local" or "" => "local",
                "s3" or "s3-compatible" => string.IsNullOrWhiteSpace(storageOptions.S3.Endpoint) ||
                    string.IsNullOrWhiteSpace(storageOptions.S3.Bucket) ||
                    string.IsNullOrWhiteSpace(storageOptions.S3.AccessKey) ||
                    string.IsNullOrWhiteSpace(storageOptions.S3.SecretKey)
                        ? "not-configured"
                        : "s3-configured",
                _ => "unknown"
            };
            var ready = database.IsReady && adminTokens.IsConfigured;
            return Results.Ok(new AdminDashboardHealth(
                "healthy", database.Database, database.MigrationStatus, authentication, payment, storage, ready));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/dashboard/preferences", async (
            OrderManagementDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (context.Items["AdminPrincipal"] is not AdminPrincipal principal) return Results.Unauthorized();
            return Results.Ok(await database.GetDashboardPreferencesAsync(
                principal.StoreId, principal.Role,
                principal.UserId?.ToString("N") ?? principal.Email.Trim().ToLowerInvariant(), cancellationToken));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapPut("/dashboard/preferences", async (
            DashboardPreferencesInput input,
            OrderManagementDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (context.Items["AdminPrincipal"] is not AdminPrincipal principal) return Results.Unauthorized();
            var errors = DashboardPreferences.Validate(input);
            if (errors.Count > 0) return Results.ValidationProblem(errors);
            var saved = await database.SaveDashboardPreferencesAsync(
                principal.StoreId, principal.Role,
                principal.UserId?.ToString("N") ?? principal.Email.Trim().ToLowerInvariant(),
                principal.Email, input.Widgets!, cancellationToken);
            return Results.Ok(saved);
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/analytics", async (
            int? days,
            DateTimeOffset? from,
            DateTimeOffset? to,
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
        {
            if (!DashboardPeriod.TryCreate(from, to, DateTimeOffset.UtcNow, out var period))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["from"] = ["بازهٔ زمانی نامعتبر است؛ شروع و پایان معتبر را حداکثر برای یک سال انتخاب کنید."] });
            return Results.Ok(await database.AnalyticsAsync(Math.Clamp(days ?? 30, 1, 365), cancellationToken, period));
        })
            .AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/analytics/products", async (
            int? days,
            DateTimeOffset? from,
            DateTimeOffset? to,
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
        {
            var windowDays = days ?? 30;
            if ((from is null && (windowDays is < 1 or > 365)) || !DashboardPeriod.TryCreate(from, to, DateTimeOffset.UtcNow, out var period))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["from"] = ["بازهٔ انتخابی نامعتبر است؛ تاریخ‌ها باید معتبر و حداکثر یک‌سال باشند."] });
            return Results.Ok(await database.ProductProfitabilityAsync(windowDays, cancellationToken, period));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/analytics/price-history", async (
            string? sku,
            int? days,
            DateTimeOffset? from,
            DateTimeOffset? to,
            OrderManagementDatabase database,
            CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(sku) || sku.Trim().Length > 100)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["sku"] = ["گونهٔ کالا را انتخاب کنید."] });
            var windowDays = Math.Clamp(days ?? 90, 1, 365);
            if (!DashboardPeriod.TryCreate(from, to, DateTimeOffset.UtcNow, out var period))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["from"] = ["بازهٔ زمانی نامعتبر است."] });
            return Results.Ok(await database.PriceHistoryAsync(sku.Trim(), windowDays, period, cancellationToken));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/analytics/price-history/skus", async (
            OrderManagementDatabase database,
            CancellationToken cancellationToken) => Results.Ok(await database.PriceHistorySkusAsync(cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/notifications", async (
            OrderManagementDatabase database, HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (context.Items["AdminPrincipal"] is not AdminPrincipal principal)
                return Results.Unauthorized();
            return Results.Ok(await database.NotificationsAsync(
                AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.OrdersRead),
                AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.InventoryRead),
                AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.CorporateRead),
                cancellationToken));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapGet("/shipping/overdue", async (
            int? days,
            OrderManagementDatabase database,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            var windowDays = days ?? 3;
            if (windowDays is < 1 or > 60)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["days"] = ["بازه تأخیر باید بین ۱ تا ۶۰ روز باشد."] });
            var rows = await database.ListOverdueShipmentsAsync(windowDays, cancellationToken);
            return Results.Ok(rows.Select(row => OrderPrivacy.Project(row, context)));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        admin.MapPatch("/orders/{orderId:guid}/state", async (
            Guid orderId,
            SetOrderStateRequest request,
            OrderManagementDatabase database,
            AdminAuditLogDatabase audit,
            ProductCatalog catalog,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (!Enum.TryParse<OrderState>(request.State, true, out var requestedState))
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(request.State)] = ["وضعیت سفارش معتبر نیست."] });

            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var result = await database.TransitionAsync(orderId, requestedState, request.Reason, actor, context.TraceIdentifier, audit, cancellationToken);
            if (result.StockLevels is not null)
                foreach (var item in result.StockLevels) catalog.SetAvailablePackages(item.Sku, item.AvailablePackages);

            return result.Status switch
            {
                OrderOperationStatus.Updated => Results.Ok(result.Order is null ? null : OrderPrivacy.Project(result.Order, context)),
                OrderOperationStatus.NotFound => Results.NotFound(new { message = result.Message }),
                _ => Results.Conflict(new { message = result.Message })
            };
        }).AddEndpointFilter<OwnerAuthorizationFilter>()
          .AddEndpointFilter<OrderCancellationStepUpAuthorizationFilter>();

        admin.MapPost("/orders/bulk-state", async (
            BulkOrderStateRequest request,
            OrderManagementDatabase database,
            AdminAuditLogDatabase audit,
            ProductCatalog catalog,
            HttpContext context,
            CancellationToken cancellationToken) =>
        {
            if (!Enum.TryParse<OrderState>(request.State, true, out var requestedState))
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(request.State)] = ["وضعیت سفارش معتبر نیست."] });
            if (request.OrderIds is null || request.OrderIds.Count is < 1 or > 50)
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(request.OrderIds)] = ["برای عملیات گروهی بین ۱ تا ۵۰ سفارش انتخاب کنید."] });
            if (request.OrderIds.Distinct().Count() != request.OrderIds.Count)
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(request.OrderIds)] = ["شناسه سفارش‌ها نباید تکراری باشد."] });
            if (request.Reason is { Length: > 500 })
                return Results.ValidationProblem(new Dictionary<string, string[]> { [nameof(request.Reason)] = ["دلیل عملیات نمی‌تواند بیشتر از ۵۰۰ نویسه باشد."] });

            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var updated = new List<AdminOrderSummary>();
            var failed = new List<object>();
            foreach (var orderId in request.OrderIds)
            {
                var result = await database.TransitionAsync(orderId, requestedState, request.Reason, actor, context.TraceIdentifier, audit, cancellationToken);
                if (result.Status == OrderOperationStatus.Updated && result.Order is not null)
                {
                    updated.Add(OrderPrivacy.Project(result.Order, context));
                    if (result.StockLevels is not null)
                        foreach (var item in result.StockLevels) catalog.SetAvailablePackages(item.Sku, item.AvailablePackages);
                }
                else failed.Add(new { id = orderId, message = result.Message ?? "تغییر وضعیت انجام نشد." });
            }

            return Results.Ok(new { updated, failed });
        }).AddEndpointFilter<OwnerAuthorizationFilter>()
          .AddEndpointFilter<OrderCancellationStepUpAuthorizationFilter>();

        return endpoints;
    }

    private static bool IsValidOrderFilter(string? state) =>
        string.IsNullOrWhiteSpace(state) ||
        state.Equals("Processing", StringComparison.OrdinalIgnoreCase) ||
        state.Equals("Problem", StringComparison.OrdinalIgnoreCase) ||
        Enum.TryParse<OrderState>(state, true, out _);
}

public sealed class OrderManagementDatabase(IConfiguration configuration, ILogger<OrderManagementDatabase> logger, InventoryLedgerDatabase ledger)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task ApplyMigrationsAsync(CancellationToken cancellationToken)
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
        const string internalCostsSql = """
            create table if not exists order_internal_costs (
                id uuid primary key,
                order_id uuid not null references checkout_orders(id) on delete cascade,
                title varchar(160) not null check (char_length(title) between 1 and 160),
                amount numeric(18,2) not null check (amount > 0),
                actor varchar(180) not null,
                created_at timestamptz not null
            );
            create index if not exists ix_order_internal_costs_order on order_internal_costs(order_id, created_at desc);
            """;
        await DatabaseMigrationRunner.ApplyAsync(connection, "orders", "006-internal-accounting-costs", internalCostsSql, cancellationToken);
        const string dashboardPreferencesSql = """
            create table if not exists admin_dashboard_role_preferences (
                store_id varchar(120) not null,
                role varchar(80) not null,
                widgets jsonb not null,
                updated_by varchar(180) not null,
                updated_at timestamptz not null,
                primary key (store_id, role)
            );
            """;
        await DatabaseMigrationRunner.ApplyAsync(connection, "orders", "004-dashboard-role-preferences", dashboardPreferencesSql, cancellationToken);
        const string dashboardUserPreferencesSql = """
            create table if not exists admin_dashboard_user_preferences (
                store_id varchar(120) not null,
                role varchar(80) not null,
                user_key text not null,
                widgets jsonb not null,
                updated_by varchar(320) not null,
                updated_at timestamptz not null,
                primary key (store_id, role, user_key)
            );
            """;
        await DatabaseMigrationRunner.ApplyAsync(connection, "orders", "005-dashboard-user-preferences", dashboardUserPreferencesSql, cancellationToken);
        logger.LogInformation("Order-management schema constraints are ready.");
    }

    public async Task<IReadOnlyCollection<AdminOrderSummary>> ListAsync(
        string? state,
        string? query,
        int limit,
        CancellationToken cancellationToken,
        bool allowContactSearch = true,
        DateTimeOffset? createdFrom = null,
        DateTimeOffset? createdTo = null)
    {
        if (!IsConfigured) return Array.Empty<AdminOrderSummary>();
        const string sql = """
            select o.id,o.customer_name,o.mobile,o.province,o.city,o.payable,o.currency,o.state,
                   o.created_at,o.reservation_expires_at,count(l.id)::int,
                   coalesce(p.reference,''),coalesce(p.state,''),o.is_private
            from checkout_orders o
            left join checkout_order_lines l on l.order_id=o.id
            left join payments p on p.order_id=o.id
            where (@state = ''
                or (lower(@state) = 'processing' and o.state in ('Paid','Preparing'))
                or (lower(@state) = 'problem' and o.state in ('Cancelled','Expired'))
                or lower(o.state)=lower(@state))
              and (@query = '' or o.id::text ilike '%' || @query || '%'
                   or exists (select 1 from checkout_order_lines searched_line
                              where searched_line.order_id = o.id
                                and searched_line.sku ilike '%' || @query || '%')
                   or (@contact_search and (o.customer_name ilike '%' || @query || '%'
                   or o.mobile ilike '%' || @query || '%'
                   or o.city ilike '%' || @query || '%')))
              and (@created_from is null or o.created_at >= @created_from)
              and (@created_to is null or o.created_at < @created_to)
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
        command.Parameters.AddWithValue("contact_search", allowContactSearch);
        command.Parameters.Add(new Npgsql.NpgsqlParameter("created_from", NpgsqlTypes.NpgsqlDbType.TimestampTz)
        {
            Value = createdFrom is null ? DBNull.Value : createdFrom.Value
        });
        command.Parameters.Add(new Npgsql.NpgsqlParameter("created_to", NpgsqlTypes.NpgsqlDbType.TimestampTz)
        {
            Value = createdTo is null ? DBNull.Value : createdTo.Value
        });
        var result = new List<AdminOrderSummary>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AdminOrderSummary(
                reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4),
                reader.GetDecimal(5), reader.GetString(6), Enum.Parse<OrderState>(reader.GetString(7)),
                reader.GetFieldValue<DateTimeOffset>(8), reader.GetFieldValue<DateTimeOffset>(9), reader.GetInt32(10),
                EmptyToNull(reader.GetString(11)), EmptyToNull(reader.GetString(12)), reader.GetBoolean(13)));
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
                   count(l.id)::int,coalesce(p.reference,''),coalesce(p.state,''),o.is_private
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
            EmptyToNull(reader.GetString(23)), EmptyToNull(reader.GetString(24)), reader.GetBoolean(25));
        var detail = new AdminOrderDetail(
            summary, reader.GetString(5), reader.GetString(6), reader.GetDecimal(8), reader.GetDecimal(9),
            reader.GetDecimal(10), reader.GetDecimal(11), reader.GetDecimal(14), reader.GetDecimal(13),
            reader.GetString(15), reader.IsDBNull(16) ? null : EmptyToNull(reader.GetString(16)),
            reader.IsDBNull(17) ? null : EmptyToNull(reader.GetString(17)),
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

        var internalCosts = new List<AdminOrderInternalCost>();
        const string internalCostsSelectSql = "select id,title,amount,actor,created_at from order_internal_costs where order_id=@id order by created_at desc;";
        await using (var command = new NpgsqlCommand(internalCostsSelectSql, connection))
        {
            command.Parameters.AddWithValue("id", orderId);
            await using var costReader = await command.ExecuteReaderAsync(cancellationToken);
            while (await costReader.ReadAsync(cancellationToken))
                internalCosts.Add(new AdminOrderInternalCost(costReader.GetGuid(0), costReader.GetString(1),
                    costReader.GetDecimal(2), costReader.GetString(3), costReader.GetFieldValue<DateTimeOffset>(4)));
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

        return detail with { Lines = lines, Transitions = transitions, Notes = notes, InternalCosts = internalCosts, Payment = payment };
    }

    public async Task<AdminOrderInternalCost?> AddInternalCostAsync(Guid orderId, AdminOrderInternalCostInput input,
        string actor, string requestId, string? storeId, AdminAuditLogDatabase audit, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        var id = Guid.NewGuid();
        const string sql = """
            insert into order_internal_costs(id,order_id,title,amount,actor,created_at)
            select @id,@order_id,@title,@amount,@actor,now()
            where exists(select 1 from checkout_orders where id=@order_id)
            returning id,title,amount,actor,created_at;
            """;
        AdminOrderInternalCost? added = null;
        await using (var command = new NpgsqlCommand(sql, connection))
        {
            command.Parameters.AddWithValue("id", id);
            command.Parameters.AddWithValue("order_id", orderId);
            command.Parameters.AddWithValue("title", input.Title.Trim());
            command.Parameters.AddWithValue("amount", input.Amount);
            command.Parameters.AddWithValue("actor", actor);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (await reader.ReadAsync(cancellationToken))
                added = new AdminOrderInternalCost(reader.GetGuid(0), reader.GetString(1), reader.GetDecimal(2), reader.GetString(3), reader.GetFieldValue<DateTimeOffset>(4));
        }
        if (added is not null)
            await audit.RecordAsync(actor, "order.internal-cost.added", "order", orderId.ToString("D"), null,
                added, "هزینه داخلی و غیرقابل‌مشاهده برای مشتری ثبت شد.", requestId, cancellationToken, storeId);
        return added;
    }

    public async Task<bool> RemoveInternalCostAsync(Guid orderId, Guid costId, string actor, string requestId,
        string? storeId, AdminAuditLogDatabase audit, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return false;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        AdminOrderInternalCost? removed = null;
        const string sql = "delete from order_internal_costs where id=@cost and order_id=@order returning id,title,amount,actor,created_at;";
        await using (var command = new NpgsqlCommand(sql, connection))
        {
            command.Parameters.AddWithValue("cost", costId);
            command.Parameters.AddWithValue("order", orderId);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (await reader.ReadAsync(cancellationToken))
                removed = new AdminOrderInternalCost(reader.GetGuid(0), reader.GetString(1), reader.GetDecimal(2), reader.GetString(3), reader.GetFieldValue<DateTimeOffset>(4));
        }
        if (removed is not null)
            await audit.RecordAsync(actor, "order.internal-cost.removed", "order", orderId.ToString("D"),
                removed, null, "هزینه داخلی از محاسبات حذف شد.", requestId, cancellationToken, storeId);
        return removed is not null;
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

    public async Task<AdminOrderDetail?> UpdateShippingAsync(
        Guid orderId,
        AdminShipmentUpdateInput input,
        string actor,
        string requestId,
        AdminAuditLogDatabase audit,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        const string beforeSql = """
            select shipping_carrier,tracking_code,shipping_expense,shipped_at
            from checkout_orders where id=@id for update;
            """;
        AdminShippingAuditSnapshot before;
        await using (var command = new NpgsqlCommand(beforeSql, connection, transaction))
        {
            command.Parameters.AddWithValue("id", orderId);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return null;
            }
            before = new AdminShippingAuditSnapshot(
                reader.IsDBNull(0) ? null : reader.GetString(0),
                reader.IsDBNull(1) ? null : reader.GetString(1),
                reader.GetDecimal(2),
                reader.IsDBNull(3) ? null : reader.GetFieldValue<DateTimeOffset>(3));
        }

        const string sql = """
            update checkout_orders
            set shipping_carrier=@carrier, tracking_code=@tracking_code,
                shipping_expense=case when @update_expense then @expense else shipping_expense end,
                shipped_at=case when @tracking_code is not null and nullif(@tracking_code,'') is not null then coalesce(shipped_at,now()) else shipped_at end
            where id=@id
            returning shipped_at;
            """;
        DateTimeOffset? shippedAt;
        await using (var command = new NpgsqlCommand(sql, connection, transaction))
        {
            command.Parameters.Add("carrier", NpgsqlTypes.NpgsqlDbType.Varchar).Value =
                (object?)input.Carrier?.Trim() ?? DBNull.Value;
            command.Parameters.Add("tracking_code", NpgsqlTypes.NpgsqlDbType.Varchar).Value =
                (object?)input.TrackingCode?.Trim() ?? DBNull.Value;
            command.Parameters.AddWithValue("expense", input.ActualShippingCost ?? 0m);
            command.Parameters.AddWithValue("update_expense", input.UpdateActualShippingCost);
            command.Parameters.AddWithValue("id", orderId);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            shippedAt = await reader.ReadAsync(cancellationToken) && !reader.IsDBNull(0)
                ? reader.GetFieldValue<DateTimeOffset>(0)
                : null;
        }

        var after = new AdminShippingAuditSnapshot(
            input.Carrier?.Trim(),
            input.TrackingCode?.Trim(),
            input.UpdateActualShippingCost ? input.ActualShippingCost ?? 0m : before.actualShippingCost,
            shippedAt);
        await audit.RecordAsync(
            connection, transaction, actor, "order.shipping-updated", "Order", orderId.ToString(),
            before, after, input.Reason!.Trim(), requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return await GetDetailAsync(orderId, cancellationToken);
    }

    public async Task<AdminDashboard> DashboardAsync(int days, CancellationToken cancellationToken, DashboardPeriod? period = null)
    {
        if (!IsConfigured) return new AdminDashboard(0, 0, 0, 0, 0, 0, Array.Empty<LowStockItem>());
        var end = period?.To ?? DateTimeOffset.UtcNow;
        var from = period?.From ?? (days == 1 ? new DateTimeOffset(DateTime.UtcNow.Date, TimeSpan.Zero) : DateTimeOffset.UtcNow.AddDays(-days));
        var periodDays = period is null ? days : Math.Clamp((int)Math.Ceiling((end - from).TotalDays), 1, 366);
        const string orderSql = """
            select
              count(*) filter (where state='AwaitingPayment')::int,
              count(*) filter (where state in ('Paid','Preparing'))::int,
              count(*) filter (where state='Shipped')::int,
              count(*) filter (where state='Delivered')::int,
              coalesce(sum(payable) filter (where state in ('Paid','Preparing','Shipped','Delivered')),0),
              coalesce(sum(payable) filter (where state in ('Paid','Preparing','Shipped','Delivered') and created_at >= @from and created_at < @to),0),
              count(*) filter (where state in ('Paid','Preparing','Shipped','Delivered') and created_at >= @from and created_at < @to)::int,
              coalesce(avg(payable) filter (where state in ('Paid','Preparing','Shipped','Delivered') and created_at >= @from and created_at < @to),0)
            from checkout_orders;
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        int awaiting, processing, shipped, delivered;
        int periodOrderCount;
        decimal paidRevenue, periodRevenue, averageOrderValue;
        await using (var command = new NpgsqlCommand(orderSql, connection))
        {
            command.Parameters.AddWithValue("from", from);
            command.Parameters.AddWithValue("to", end);
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            await reader.ReadAsync(cancellationToken);
            awaiting = reader.GetInt32(0);
            processing = reader.GetInt32(1);
            shipped = reader.GetInt32(2);
            delivered = reader.GetInt32(3);
            paidRevenue = reader.GetDecimal(4);
            periodRevenue = reader.GetDecimal(5);
            periodOrderCount = reader.GetInt32(6);
            averageOrderValue = reader.GetDecimal(7);
        }
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

        const string expirySql = """
            select p.title,v.sku,v.display_label,b.batch_code,b.expires_at,b.remaining_packages
            from inventory_batches b
            join product_variants v on upper(v.sku)=upper(b.sku)
            join products p on p.id=v.product_id
            where b.remaining_packages > 0 and b.expires_at > now() and b.expires_at <= now() + interval '30 days'
            order by b.expires_at,p.title,b.batch_code
            limit 20;
            """;
        var expiringSoon = new List<ExpiringStockItem>();
        await using (var command = new NpgsqlCommand(expirySql, connection))
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken))
                expiringSoon.Add(new ExpiringStockItem(
                    reader.GetString(0),
                    reader.GetString(1),
                    reader.GetString(2),
                    reader.GetString(3),
                    reader.GetFieldValue<DateTimeOffset>(4),
                    reader.GetInt32(5)));

        const string summarySql = """
            select
              (select count(*)::int from customers where created_at >= @from and created_at < @to),
              (select count(*)::int from corporate_requests where status='New' and created_at >= @from and created_at < @to),
              (select count(*)::int from checkout_orders where state in ('Cancelled','Expired') and created_at >= @from and created_at < @to);
            """;
        int newCustomers, corporateNewRequests, problemOrders;
        await using (var command = new NpgsqlCommand(summarySql, connection))
        {
            command.Parameters.AddWithValue("from", from);
            command.Parameters.AddWithValue("to", end);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            await reader.ReadAsync(cancellationToken);
            newCustomers = reader.GetInt32(0);
            corporateNewRequests = reader.GetInt32(1);
            problemOrders = reader.GetInt32(2);
        }

        return new AdminDashboard(awaiting, processing, shipped, delivered, paidRevenue, periodRevenue, lowStock, periodDays, periodOrderCount, periodRevenue, averageOrderValue, expiringSoon, newCustomers, corporateNewRequests, problemOrders);
    }

    public async Task<DashboardPreferences> GetDashboardPreferencesAsync(
        string storeId, string role, string userKey, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return DashboardPreferences.Default;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var userCommand = new NpgsqlCommand(
            "select widgets from admin_dashboard_user_preferences where store_id=@store and role=@role and user_key=@userKey;", connection);
        userCommand.Parameters.AddWithValue("store", storeId);
        userCommand.Parameters.AddWithValue("role", role);
        userCommand.Parameters.AddWithValue("userKey", userKey);
        var userJson = await userCommand.ExecuteScalarAsync(cancellationToken) as string;
        if (userJson is not null) return ParseDashboardPreferences(userJson);

        await using var command = new NpgsqlCommand(
            "select widgets from admin_dashboard_role_preferences where store_id=@store and role=@role;", connection);
        command.Parameters.AddWithValue("store", storeId);
        command.Parameters.AddWithValue("role", role);
        var json = await command.ExecuteScalarAsync(cancellationToken) as string;
        return json is null ? DashboardPreferences.Default : ParseDashboardPreferences(json);
    }

    private static DashboardPreferences ParseDashboardPreferences(string json)
    {
        try
        {
            var widgets = JsonSerializer.Deserialize<DashboardWidgetPreference[]>(json);
            return DashboardPreferences.IsValid(widgets) ? new DashboardPreferences(widgets!) : DashboardPreferences.Default;
        }
        catch (JsonException)
        {
            return DashboardPreferences.Default;
        }
    }

    public async Task<DashboardPreferences> SaveDashboardPreferencesAsync(
        string storeId, string role, string userKey, string actor,
        IReadOnlyList<DashboardWidgetPreference> widgets, CancellationToken cancellationToken)
    {
        var preferences = new DashboardPreferences(widgets.ToArray());
        if (!IsConfigured) return preferences;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("""
            insert into admin_dashboard_user_preferences (store_id,role,user_key,widgets,updated_by,updated_at)
            values (@store,@role,@userKey,@widgets::jsonb,@actor,now())
            on conflict (store_id,role,user_key) do update
              set widgets=excluded.widgets,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
            """, connection);
        command.Parameters.AddWithValue("store", storeId);
        command.Parameters.AddWithValue("role", role);
        command.Parameters.AddWithValue("userKey", userKey);
        command.Parameters.AddWithValue("widgets", JsonSerializer.Serialize(widgets));
        command.Parameters.AddWithValue("actor", actor);
        await command.ExecuteNonQueryAsync(cancellationToken);
        return preferences;
    }

    public async Task<AdminAnalytics> AnalyticsAsync(int days, CancellationToken cancellationToken, DashboardPeriod? period = null)
    {
        if (!IsConfigured) return new AdminAnalytics(days, 0, 0, 0, 0, 0, 0);
        var to = period?.To ?? DateTimeOffset.UtcNow;
        var from = period?.From ?? to.AddDays(-days);
        var periodDays = period is null ? days : Math.Clamp((int)Math.Ceiling((to - from).TotalDays), 1, 366);
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(System.Data.IsolationLevel.RepeatableRead, cancellationToken);
        const string orderSql = """
            select count(*)::int, coalesce(sum(payable),0), coalesce(sum(tax),0),
                   coalesce(sum(shipping_expense),0), coalesce(sum(shipping),0), coalesce(sum(discount),0),
                   coalesce(sum((select sum(c.amount) from order_internal_costs c where c.order_id=checkout_orders.id)),0)
            from checkout_orders
            where created_at >= @from and created_at < @to and state in ('Paid','Preparing','Shipped','Delivered');
            """;
        int orderCount;
        decimal revenue;
        decimal tax;
        decimal shippingExpense;
        decimal shippingRevenue;
        decimal discount;
        decimal internalCosts;
        await using (var command = new NpgsqlCommand(orderSql, connection, transaction))
        {
            command.Parameters.AddWithValue("from", from);
            command.Parameters.AddWithValue("to", to);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            await reader.ReadAsync(cancellationToken);
            orderCount = reader.GetInt32(0);
            revenue = reader.GetDecimal(1);
            tax = reader.GetDecimal(2);
            shippingExpense = reader.GetDecimal(3);
            shippingRevenue = reader.GetDecimal(4);
            discount = reader.GetDecimal(5);
            internalCosts = reader.GetDecimal(6);
        }

        const string lineSql = """
            select coalesce(sum(l.quantity),0)::int,
                   coalesce(sum(l.quantity*l.cost_price),0),
                   coalesce(sum(l.quantity*l.packaging_cost),0),
                   coalesce(sum(l.quantity*l.additional_cost),0),
                   coalesce(sum(l.line_total),0)
            from checkout_order_lines l join checkout_orders o on o.id=l.order_id
            where o.created_at >= @from and o.created_at < @to and o.state in ('Paid','Preparing','Shipped','Delivered');
            """;
        int units;
        decimal productCost;
        decimal packagingCost;
        decimal additionalCost;
        decimal merchandiseRevenue;
        await using (var command = new NpgsqlCommand(lineSql, connection, transaction))
        {
            command.Parameters.AddWithValue("from", from);
            command.Parameters.AddWithValue("to", to);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            await reader.ReadAsync(cancellationToken);
            units = reader.GetInt32(0);
            productCost = reader.GetDecimal(1);
            packagingCost = reader.GetDecimal(2);
            additionalCost = reader.GetDecimal(3);
            merchandiseRevenue = reader.GetDecimal(4);
        }

        // Aggregate line costs per order before joining to avoid multiplying order totals.
        const string dailySql = """
            with line_costs as (
                select l.order_id, sum(l.line_total) as merchandise,
                       sum(l.quantity * (l.cost_price + l.packaging_cost + l.additional_cost)) as cost,
                       coalesce((select sum(c.amount) from order_internal_costs c where c.order_id=l.order_id),0) as internal_cost
                from checkout_order_lines l join checkout_orders o on o.id=l.order_id
                where o.created_at >= @from and o.created_at < @to
                  and o.state in ('Paid','Preparing','Shipped','Delivered')
                group by l.order_id
            )
            select (o.created_at at time zone 'UTC')::date as day, count(*)::int,
                   coalesce(sum(o.payable),0),
                   coalesce(sum(coalesce(l.merchandise,0)-o.discount-coalesce(l.cost,0)+o.shipping-o.shipping_expense-coalesce(l.internal_cost,0)),0)
            from checkout_orders o left join line_costs l on l.order_id=o.id
            where o.created_at >= @from and o.created_at < @to
              and o.state in ('Paid','Preparing','Shipped','Delivered')
            group by day order by day;
            """;
        var dailySales = new List<AdminDailySales>();
        await using (var command = new NpgsqlCommand(dailySql, connection, transaction))
        {
            command.Parameters.AddWithValue("from", from);
            command.Parameters.AddWithValue("to", to);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                dailySales.Add(new AdminDailySales(reader.GetFieldValue<DateOnly>(0), reader.GetInt32(1), reader.GetDecimal(2), reader.GetDecimal(3)));
        }
        const string statesSql = """
            select state,count(*)::int from checkout_orders
            where created_at >= @from and created_at < @to group by state order by state;
            """;
        var orderStates = new List<AdminOrderStateCount>();
        await using (var command = new NpgsqlCommand(statesSql, connection, transaction))
        {
            command.Parameters.AddWithValue("from", from);
            command.Parameters.AddWithValue("to", to);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                orderStates.Add(new AdminOrderStateCount(reader.GetString(0), reader.GetInt32(1)));
        }
        await transaction.CommitAsync(cancellationToken);

        var cost = productCost + packagingCost + additionalCost + internalCosts;
        // Customer payments include shipping and tax; tax is payable to the tax authority, not profit.
        var netMerchandiseRevenue = merchandiseRevenue - discount;
        var profit = netMerchandiseRevenue - cost;
        var netProfit = profit + shippingRevenue - shippingExpense;
        var margin = netMerchandiseRevenue <= 0 ? 0 : profit / netMerchandiseRevenue * 100;
        return new AdminAnalytics(
            periodDays, orderCount, units, revenue, cost, profit, margin, tax, netProfit, shippingExpense,
            merchandiseRevenue, discount, shippingRevenue, productCost, packagingCost, additionalCost, dailySales, orderStates, internalCosts);
    }

    public async Task<IReadOnlyCollection<AdminProductProfitability>> ProductProfitabilityAsync(int days, CancellationToken cancellationToken, DashboardPeriod? period = null)
    {
        if (!IsConfigured) return Array.Empty<AdminProductProfitability>();
        var to = period?.To ?? DateTimeOffset.UtcNow;
        var from = period?.From ?? to.AddDays(-days);
        const string sql = """
            with grouped as (
                select l.product_title,l.sku,l.variant_label,
                       sum(l.quantity)::int as units_sold,
                       coalesce(sum(l.line_total),0) as revenue,
                       coalesce(sum(case when o.subtotal > 0
                           then o.discount * l.line_total / o.subtotal else 0 end),0) as discount,
                       coalesce(sum(l.quantity * (l.cost_price + l.packaging_cost + l.additional_cost)),0) as cost,
                        coalesce(sum(l.quantity * l.cost_price),0) as product_cost,
                        coalesce(sum(l.quantity * l.packaging_cost),0) as packaging_cost,
                        coalesce(sum(l.quantity * l.additional_cost),0) as additional_cost,
                       sum(l.quantity * l.item_quantity) as quantity_sold,
                       max(l.base_unit) as base_unit,
                       coalesce(sum(case when o.subtotal > 0 then
                           (select sum(c.amount) from order_internal_costs c where c.order_id=o.id) * l.line_total / o.subtotal
                           else 0 end),0) as allocated_internal_cost
                from checkout_order_lines l
                join checkout_orders o on o.id=l.order_id
                where o.created_at >= @from and o.created_at < @to
                  and o.state in ('Paid','Preparing','Shipped','Delivered')
                group by l.product_title,l.sku,l.variant_label
            )
            select product_title,sku,variant_label,units_sold,revenue,discount,cost,
                   product_cost,packaging_cost,additional_cost,quantity_sold,base_unit,allocated_internal_cost
            from grouped
            order by (revenue - discount - cost) desc, product_title
            limit 200;
            """;

        var rows = new List<AdminProductProfitability>();
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("from", from);
        command.Parameters.AddWithValue("to", to);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var revenue = reader.GetDecimal(4);
            var discount = reader.GetDecimal(5);
            var cost = reader.GetDecimal(6) + reader.GetDecimal(12);
            var productCost = reader.GetDecimal(7);
            var packagingCost = reader.GetDecimal(8);
            var additionalCost = reader.GetDecimal(9);
            rows.Add(new AdminProductProfitability(
                reader.GetString(0), reader.GetString(1), reader.GetString(2),
                reader.GetInt32(3), revenue, cost, revenue - discount - cost, discount,
                productCost, packagingCost, additionalCost,
                reader.IsDBNull(10) ? null : reader.GetDecimal(10),
                reader.IsDBNull(11) ? null : reader.GetString(11), reader.GetDecimal(12)));
        }
        return rows;
    }

    public async Task<IReadOnlyCollection<AdminPriceHistoryPoint>> PriceHistoryAsync(
        string sku, int days, DashboardPeriod? period, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<AdminPriceHistoryPoint>();
        var to = period?.To ?? DateTimeOffset.UtcNow;
        var from = period?.From ?? to.AddDays(-days);
        const string sql = """
            select occurred_at,kind,amount,reference from (
                select coalesce(purchased_at,created_at) as occurred_at, 'purchase'::text as kind,
                       cost_price+packaging_cost+additional_cost as amount, batch_code as reference
                from inventory_batches
                where upper(sku)=upper(@sku) and coalesce(purchased_at,created_at)>=@from and coalesce(purchased_at,created_at)<@to
                union all
                select occurred_at, 'sale'::text,
                       coalesce(nullif(after_json->>'Price','')::numeric,
                                nullif(after_json->>'price','')::numeric,
                                nullif(after_json #>> '{Quote,SellingPrice}','')::numeric,
                                nullif(after_json #>> '{quote,sellingPrice}','')::numeric),
                       action
                from admin_audit_logs
                where entity_type='ProductVariant' and upper(entity_id)=upper(@sku)
                  and action in ('product.variant-added','product.selling-price-updated','inventory.price.applied')
                  and occurred_at>=@from and occurred_at<@to
            ) history
            where amount is not null and amount>=0
            order by occurred_at;
            """;
        var rows = new List<AdminPriceHistoryPoint>();
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("sku", sku);
        command.Parameters.AddWithValue("from", from);
        command.Parameters.AddWithValue("to", to);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            rows.Add(new AdminPriceHistoryPoint(reader.GetFieldValue<DateTimeOffset>(0), reader.GetString(1),
                reader.GetDecimal(2), reader.GetString(3)));
        return rows;
    }

    public async Task<IReadOnlyCollection<AdminPriceHistorySku>> PriceHistorySkusAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<AdminPriceHistorySku>();
        const string sql = """
            select v.sku,p.title,v.display_label
            from product_variants v join products p on p.id=v.product_id
            order by p.title,v.display_label
            limit 500;
            """;
        var rows = new List<AdminPriceHistorySku>();
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            rows.Add(new AdminPriceHistorySku(reader.GetString(0), reader.GetString(1), reader.GetString(2)));
        return rows;
    }

    public async Task<AdminNotifications> NotificationsAsync(bool includeOrders, bool includeInventory, bool includeCorporate, CancellationToken cancellationToken)
    {
        if (!IsConfigured || (!includeOrders && !includeInventory && !includeCorporate))
            return new AdminNotifications(0, 0, Array.Empty<AdminNotification>());
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string orderSql = """
            select count(*) filter (where state='AwaitingPayment')::int,
                   count(*) filter (where created_at >= now() - interval '24 hours' and state not in ('Cancelled','Expired'))::int
            from checkout_orders;
            """;
        var awaitingPayment = 0;
        var recentOrders = 0;
        var corporateOverdueFollowUps = 0;
        if (includeOrders)
        {
            await using (var command = new NpgsqlCommand(orderSql, connection))
            await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
            {
                await reader.ReadAsync(cancellationToken);
                awaitingPayment = reader.GetInt32(0);
                recentOrders = reader.GetInt32(1);
            }
        }

        const string stockSql = "select p.title,v.sku,v.available_packages from product_variants v join products p on p.id=v.product_id where v.available_packages <= 5 order by v.available_packages,p.title limit 20;";
        var items = new List<AdminNotification>();
        if (includeInventory)
        {
            await using (var command = new NpgsqlCommand(stockSql, connection))
            await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
                while (await reader.ReadAsync(cancellationToken))
                    items.Add(new AdminNotification(
                        "low-stock",
                        $"موجودی {reader.GetString(0)} کم است.",
                        $"{reader.GetString(1)} · {reader.GetInt32(2)} بسته",
                        new AdminNavigationTarget("inventory", Sku: reader.GetString(1))));
        }

        if (includeCorporate)
        {
            const string countSql = """
                select count(*)::int
                from corporate_requests
                where status not in ('Finalized','Cancelled')
                  and next_follow_up_at is not null and next_follow_up_at<=now();
                """;
            await using (var command = new NpgsqlCommand(countSql, connection))
                corporateOverdueFollowUps = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));

            const string remindersSql = """
                select company_name,assigned_to,next_follow_up_at
                from corporate_requests
                where status not in ('Finalized','Cancelled')
                  and next_follow_up_at is not null and next_follow_up_at<=now()
                order by next_follow_up_at asc
                limit 10;
                """;
            await using var reminders = new NpgsqlCommand(remindersSql, connection);
            await using var reminderReader = await reminders.ExecuteReaderAsync(cancellationToken);
            while (await reminderReader.ReadAsync(cancellationToken))
            {
                var dueAt = reminderReader.GetFieldValue<DateTimeOffset>(2);
                var assignedTo = reminderReader.IsDBNull(1) || string.IsNullOrWhiteSpace(reminderReader.GetString(1))
                    ? "بدون مسئول"
                    : reminderReader.GetString(1);
                items.Add(new AdminNotification(
                    "corporate-follow-up",
                    "موعد پیگیری فروش سازمانی گذشته است.",
                    $"{reminderReader.GetString(0)} · {assignedTo} · {dueAt:yyyy-MM-dd HH:mm} UTC",
                    new AdminNavigationTarget("corporate")));
            }
        }

        if (awaitingPayment > 0)
            items.Insert(0, new AdminNotification(
                "awaiting-payment",
                $"{awaitingPayment} سفارش در انتظار پرداخت است.",
                "نیازمند بررسی پنل سفارش‌ها",
                new AdminNavigationTarget("orders", Filter: "AwaitingPayment")));
        if (recentOrders > 0)
            items.Insert(0, new AdminNotification(
                "new-orders",
                $"{recentOrders} سفارش در ۲۴ ساعت اخیر ثبت یا پردازش شده.",
                "مرور سفارش‌ها و وضعیت ارسال",
                new AdminNavigationTarget("orders")));
        return new AdminNotifications(awaitingPayment, items.Count(item => item.Type == "low-stock"), items, corporateOverdueFollowUps);
    }

    public async Task<IReadOnlyCollection<AdminOverdueShipment>> ListOverdueShipmentsAsync(int days, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<AdminOverdueShipment>();

        const string sql = """
            select o.id,o.customer_name,o.mobile,o.province,o.city,o.payable,o.currency,o.state,
                   o.created_at,o.reservation_expires_at,
                   coalesce((select count(*) from checkout_order_lines l where l.order_id=o.id),0)::int,
                   coalesce(o.shipping_carrier,''),coalesce(o.tracking_code,''),o.shipped_at,
                   greatest(1, floor(extract(epoch from (now() - o.shipped_at)) / 86400))::int
            from checkout_orders o
            where o.state='Shipped'
              and o.shipped_at is not null
              and o.shipped_at <= now() - (@days * interval '1 day')
            order by o.shipped_at asc
            limit 250;
            """;

        var shipments = new List<AdminOverdueShipment>();
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("days", days);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            shipments.Add(new AdminOverdueShipment(
                reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4),
                reader.GetDecimal(5), reader.GetString(6), Enum.Parse<OrderState>(reader.GetString(7)),
                reader.GetFieldValue<DateTimeOffset>(8), reader.GetFieldValue<DateTimeOffset>(9), reader.GetInt32(10),
                EmptyToNull(reader.GetString(11)), EmptyToNull(reader.GetString(12)),
                reader.GetFieldValue<DateTimeOffset>(13), reader.GetInt32(14)));
        }
        return shipments;
    }

    public async Task<OrderOperationResult> TransitionAsync(
        Guid orderId,
        OrderState requestedState,
        string? reason,
        string actor,
        string requestId,
        AdminAuditLogDatabase audit,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured) return OrderOperationResult.Conflict("دیتابیس سفارش تنظیم نشده است.");
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        const string selectSql = """
            select state,reservation_expires_at,is_private from checkout_orders where id=@id for update;
            """;
        OrderState currentState;
        DateTimeOffset expiresAt;
        bool isPrivate;
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
            isPrivate = reader.GetBoolean(2);
        }

        if (currentState == requestedState)
        {
            await transaction.RollbackAsync(cancellationToken);
            var existing = (await ListOneAsync(connection, null, orderId, cancellationToken))!;
            return OrderOperationResult.Updated(existing);
        }

        if (isPrivate && currentState == OrderState.AwaitingPayment && requestedState == OrderState.Paid && string.IsNullOrWhiteSpace(reason))
        {
            await transaction.RollbackAsync(cancellationToken);
            return OrderOperationResult.Conflict("برای تأیید پرداخت سفارش خصوصی، توضیح پرداخت را ثبت کنید.");
        }

        if (!IsAllowed(currentState, requestedState, isPrivate))
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
            foreach (var sku in lines.Select(line => line.Sku)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(value => value, StringComparer.OrdinalIgnoreCase)
                .ThenBy(value => value, StringComparer.Ordinal))
            {
                await using var variantLock = new NpgsqlCommand(
                    "select sku from product_variants where upper(sku)=upper(@sku) for update;", connection, transaction);
                variantLock.Parameters.AddWithValue("sku", sku);
                await variantLock.ExecuteScalarAsync(cancellationToken);
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

        var transitionReason = string.IsNullOrWhiteSpace(reason)
            ? $"owner-{requestedState.ToString().ToLowerInvariant()}"
            : reason.Trim();
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
            command.Parameters.AddWithValue("reason", transitionReason);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        await audit.RecordAsync(
            connection, transaction, actor, "order.state-changed", "Order", orderId.ToString(),
            new { state = currentState.ToString() },
            new { state = requestedState.ToString() },
            transitionReason, requestId, cancellationToken);

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
                   coalesce(p.reference,''),coalesce(p.state,''),o.is_private
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
            EmptyToNull(reader.GetString(11)), EmptyToNull(reader.GetString(12)), reader.GetBoolean(13));
    }

    private static bool IsAllowed(OrderState current, OrderState requested, bool isPrivate) => (current, requested) switch
    {
        (OrderState.AwaitingPayment, OrderState.Cancelled) => true,
        (OrderState.AwaitingPayment, OrderState.Paid) => isPrivate,
        (OrderState.Paid, OrderState.Preparing) => true,
        (OrderState.Preparing, OrderState.Shipped) => true,
        (OrderState.Shipped, OrderState.Delivered) => true,
        _ => false
    };

    private static string? EmptyToNull(string value) => string.IsNullOrEmpty(value) ? null : value;
}

public sealed record SetOrderStateRequest(string State, string? Reason);
public sealed record BulkOrderStateRequest(IReadOnlyCollection<Guid> OrderIds, string State, string? Reason);
public sealed record AdminOrderNoteInput(string Note);
public sealed record AdminShipmentUpdateInput(
    string? Carrier,
    string? TrackingCode,
    decimal? ActualShippingCost,
    string? Reason,
    bool UpdateActualShippingCost = true);
public sealed record AdminShippingAuditSnapshot(string? carrier, string? trackingCode, decimal actualShippingCost, DateTimeOffset? shippedAt);
public sealed record AdminOverdueShipment(Guid Id, string CustomerName, string Mobile, string Province, string City,
    decimal Payable, string Currency, OrderState State, DateTimeOffset CreatedAt, DateTimeOffset ReservationExpiresAt,
    int LineCount, string? ShippingCarrier, string? TrackingCode, DateTimeOffset ShippedAt, int DaysOverdue);

public sealed record AdminOrderSummary(Guid Id, string CustomerName, string Mobile, string Province, string City,
    decimal Payable, string Currency, OrderState State, DateTimeOffset CreatedAt, DateTimeOffset ReservationExpiresAt,
    int LineCount, string? PaymentReference, string? PaymentState, bool IsPrivate = false);
public sealed record AdminOrderDetail(AdminOrderSummary Summary, string Address, string PostalCode, decimal Subtotal,
    decimal Shipping, decimal ShippingExpense, decimal Discount, decimal Tax, decimal TaxRatePercent, string ShippingMethod,
    string? ShippingCarrier, string? TrackingCode, DateTimeOffset? ShippedAt,
    IReadOnlyCollection<AdminOrderLine> Lines, IReadOnlyCollection<AdminOrderTransition> Transitions,
    IReadOnlyCollection<AdminOrderNote> Notes, AdminPayment? Payment = null,
    IReadOnlyCollection<AdminOrderInternalCost>? InternalCosts = null)
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
    public bool IsPrivate => Summary.IsPrivate;

    public CheckoutOrder ToCheckoutOrder() => new(
        Id, string.Empty, CustomerName, Mobile, Province, City, Address, PostalCode, Currency,
        Lines.Select(line => new CheckoutLine(line.ProductTitle, line.Sku, line.VariantLabel, line.Quantity, line.UnitPrice, line.LineTotal)).ToArray(),
        ShippingMethod, Subtotal, Shipping, ShippingExpense, Discount, TaxRatePercent, Tax, Payable, State, CreatedAt,
        ReservationExpiresAt, Transitions.Select(item => new OrderTransition(item.State, item.Actor, item.OccurredAt, item.Reason)).ToArray());
}
public sealed record AdminOrderLine(string ProductTitle, string Sku, string VariantLabel, int Quantity, decimal UnitPrice, decimal LineTotal);
public sealed record AdminOrderTransition(OrderState State, string Actor, DateTimeOffset OccurredAt, string Reason);
public sealed record AdminOrderNote(Guid Id, string Note, string Actor, DateTimeOffset CreatedAt);
public sealed record AdminOrderInternalCost(Guid Id, string Title, decimal Amount, string Actor, DateTimeOffset CreatedAt);
public sealed record AdminOrderInternalCostInput(string Title, decimal Amount);
public sealed record AdminPayment(string Provider, decimal Amount, string Currency, PaymentState State, string? Reference, DateTimeOffset CreatedAt, DateTimeOffset? CompletedAt);
public sealed record LowStockItem(string ProductTitle, string Sku, string VariantLabel, int AvailablePackages);
public sealed record ExpiringStockItem(
    string ProductTitle,
    string Sku,
    string VariantLabel,
    string BatchCode,
    DateTimeOffset ExpiresAt,
    int RemainingPackages);
public sealed record AdminNavigationTarget(
    string Module,
    string? Filter = null,
    string? Sku = null,
    string? BatchCode = null);
public sealed record AdminDashboard(int AwaitingPayment, int Processing, int Shipped, int Delivered,
    decimal PaidRevenue, decimal TodayRevenue, IReadOnlyCollection<LowStockItem> LowStock,
    int PeriodDays = 1, int PeriodOrderCount = 0, decimal PeriodRevenue = 0, decimal AverageOrderValue = 0,
    IReadOnlyCollection<ExpiringStockItem>? ExpiringSoon = null, int NewCustomers = 0, int CorporateNewRequests = 0, int ProblemOrders = 0, bool FinancialsVisible = true);
public sealed record AdminDashboardHealth(
    string Api,
    string Database,
    string Migrations,
    string AdminAuthentication,
    string Payment,
    string MediaStorage,
    bool Ready);
public sealed record DashboardPeriod(DateTimeOffset From, DateTimeOffset To)
{
    public static bool TryCreate(DateTimeOffset? from, DateTimeOffset? to, DateTimeOffset now, out DashboardPeriod? period)
    {
        period = null;
        if (from is null && to is null) return true;
        if (from is null || to is null) return false;

        var start = from.Value.ToUniversalTime();
        var end = to.Value.ToUniversalTime();
        if (start >= end || start > now || end > now.AddDays(2) || end - start > TimeSpan.FromDays(366)) return false;
        period = new DashboardPeriod(start, end);
        return true;
    }
}
public sealed record DashboardWidgetPreference(string Id, bool Visible);
public sealed record DashboardPreferencesInput(IReadOnlyList<DashboardWidgetPreference>? Widgets);
public sealed record DashboardPreferences(IReadOnlyList<DashboardWidgetPreference> Widgets)
{
    public static readonly string[] AvailableWidgets = ["metrics", "quickActions", "alerts", "lowStock", "expiring"];
    public static readonly DashboardPreferences Default = new(AvailableWidgets.Select(id => new DashboardWidgetPreference(id, true)).ToArray());

    public static bool IsValid(IReadOnlyList<DashboardWidgetPreference>? widgets) =>
        widgets is { Count: 5 } && widgets.All(widget => widget is not null && AvailableWidgets.Contains(widget.Id, StringComparer.Ordinal)) &&
        widgets.Select(widget => widget.Id).Distinct(StringComparer.Ordinal).Count() == AvailableWidgets.Length;

    public static Dictionary<string, string[]> Validate(DashboardPreferencesInput input) => IsValid(input.Widgets)
        ? new Dictionary<string, string[]>()
        : new Dictionary<string, string[]> { [nameof(input.Widgets)] = ["ترتیب باید هر پنج بخش داشبورد را دقیقاً یک بار داشته باشد."] };
}
public sealed record AdminProductProfitability(
    string ProductTitle,
    string Sku,
    string VariantLabel,
    int UnitsSold,
    decimal Revenue,
    decimal Cost,
    decimal GrossProfit,
    decimal Discount = 0,
    decimal ProductCost = 0,
    decimal PackagingCost = 0,
    decimal AdditionalCost = 0,
    decimal? QuantitySold = null,
    string? BaseUnit = null,
    decimal OrderInternalCost = 0);
public sealed record AdminAnalytics(
    int Days, int OrderCount, int UnitsSold, decimal Revenue, decimal Cost, decimal GrossProfit,
    decimal GrossMarginPercent, decimal Tax = 0, decimal NetProfit = 0, decimal ShippingExpense = 0,
    decimal MerchandiseRevenue = 0, decimal Discount = 0, decimal ShippingRevenue = 0,
    decimal ProductCost = 0, decimal PackagingCost = 0, decimal AdditionalCost = 0,
    IReadOnlyCollection<AdminDailySales>? DailySales = null,
    IReadOnlyCollection<AdminOrderStateCount>? OrderStates = null,
    decimal OrderInternalCosts = 0);
public sealed record AdminDailySales(DateOnly Day, int OrderCount, decimal Revenue, decimal NetProfit);
public sealed record AdminOrderStateCount(string State, int Count);
public sealed record AdminPriceHistoryPoint(DateTimeOffset OccurredAt, string Kind, decimal Amount, string Reference);
public sealed record AdminPriceHistorySku(string Sku, string ProductTitle, string VariantLabel);
public sealed record AdminNotification(
    string Type,
    string Title,
    string Detail,
    AdminNavigationTarget? Target = null);
public sealed record AdminNotifications(int AwaitingPayment, int LowStockItems, IReadOnlyCollection<AdminNotification> Items, int CorporateOverdueFollowUps = 0);
public enum OrderOperationStatus { Updated, NotFound, Conflict }
public sealed record OrderOperationResult(OrderOperationStatus Status, AdminOrderSummary? Order = null,
    string? Message = null, IReadOnlyCollection<StockLevelChange>? StockLevels = null)
{
    public static OrderOperationResult Updated(AdminOrderSummary order, IReadOnlyCollection<StockLevelChange>? levels = null) =>
        new(OrderOperationStatus.Updated, order, StockLevels: levels);
    public static OrderOperationResult NotFound(string message) => new(OrderOperationStatus.NotFound, Message: message);
    public static OrderOperationResult Conflict(string message) => new(OrderOperationStatus.Conflict, Message: message);
}


