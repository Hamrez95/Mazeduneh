using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

public static class CheckoutModule
{
    public static IServiceCollection AddCheckout(this IServiceCollection services)
    {
        services.AddSingleton<CheckoutDatabase>();
        services.AddSingleton<CheckoutService>();
        services.AddHostedService<CheckoutSchemaInitializer>();
        services.AddHostedService<ReservationExpiryWorker>();
        return services;
    }

    public static IEndpointRouteBuilder MapCheckout(this IEndpointRouteBuilder endpoints)
    {
        var checkout = endpoints.MapGroup("/api/v1/checkout").WithTags("Checkout");

        checkout.MapPost("/orders", async (
            HttpRequest httpRequest,
            CheckoutRequest request,
            CheckoutService service,
            CancellationToken cancellationToken) =>
        {
            if (!httpRequest.Headers.TryGetValue("Idempotency-Key", out var values) || string.IsNullOrWhiteSpace(values.FirstOrDefault()))
                return Results.BadRequest(new { message = "هدر Idempotency-Key برای جلوگیری از سفارش تکراری الزامی است." });

            var result = await service.CreateAsync(values.First()!, request, cancellationToken);
            return result.Status switch
            {
                CheckoutStatus.Created => Results.Created($"/api/v1/checkout/orders/{result.Order!.Id}", result.Order),
                CheckoutStatus.Replayed => Results.Ok(result.Order),
                CheckoutStatus.Conflict => Results.Conflict(new { message = result.Message }),
                CheckoutStatus.OutOfStock => Results.Conflict(new { message = result.Message, unavailableSkus = result.UnavailableSkus }),
                _ => Results.ValidationProblem(result.Errors!)
            };
        });

        checkout.MapGet("/orders/{orderId:guid}", async (
            Guid orderId,
            string receiptToken,
            CheckoutService service,
            CancellationToken cancellationToken) =>
            await service.FindAsync(orderId, receiptToken, cancellationToken) is { } order
                ? Results.Ok(order)
                : Results.NotFound(new { message = "سفارش پیدا نشد." }));

        return endpoints;
    }
}

public sealed class CheckoutService(ProductCatalog catalog, CheckoutDatabase database)
{
    private readonly object _gate = new();
    private readonly ConcurrentDictionary<string, StoredCheckout> _idempotency = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<Guid, CheckoutOrder> _orders = new();

    public async Task<CheckoutResult> CreateAsync(
        string idempotencyKey,
        CheckoutRequest request,
        CancellationToken cancellationToken)
    {
        idempotencyKey = idempotencyKey.Trim();
        if (idempotencyKey.Length is < 12 or > 100)
            return CheckoutResult.Invalid(new Dictionary<string, string[]> { ["Idempotency-Key"] = ["کلید باید بین ۱۲ تا ۱۰۰ نویسه باشد."] });

        var errors = request.Validate();
        if (errors.Count > 0) return CheckoutResult.Invalid(errors);

        var fingerprint = Fingerprint(request);
        if (!database.IsConfigured)
            return CreateInMemory(idempotencyKey, fingerprint, request);

        var persisted = await database.CreateAsync(idempotencyKey, fingerprint, request, cancellationToken);
        if (persisted.Status == CheckoutStatus.Created && persisted.StockLevels is not null)
        {
            foreach (var item in persisted.StockLevels)
                catalog.SetAvailablePackages(item.Sku, item.AvailablePackages);
        }

        return persisted.Status switch
        {
            CheckoutStatus.Created => CheckoutResult.Created(persisted.Order!),
            CheckoutStatus.Replayed => CheckoutResult.Replayed(persisted.Order!),
            CheckoutStatus.Conflict => CheckoutResult.Conflict(persisted.Message!),
            CheckoutStatus.OutOfStock => CheckoutResult.OutOfStock(persisted.Message!, persisted.UnavailableSkus!),
            _ => throw new InvalidOperationException("Unexpected persisted checkout result.")
        };
    }

    public Task<CheckoutOrder?> FindAsync(Guid id, string receiptToken, CancellationToken cancellationToken)
    {
        if (database.IsConfigured)
            return database.FindAsync(id, receiptToken, cancellationToken);

        var found = _orders.TryGetValue(id, out var order) && FixedTimeTokenEquals(order.ReceiptToken, receiptToken)
            ? order
            : null;
        return Task.FromResult(found);
    }

    private CheckoutResult CreateInMemory(string idempotencyKey, string fingerprint, CheckoutRequest request)
    {
        if (_idempotency.TryGetValue(idempotencyKey, out var existing))
            return existing.Fingerprint == fingerprint
                ? CheckoutResult.Replayed(existing.Order)
                : CheckoutResult.Conflict("این Idempotency-Key قبلاً برای درخواست دیگری استفاده شده است.");

        lock (_gate)
        {
            if (_idempotency.TryGetValue(idempotencyKey, out existing))
                return existing.Fingerprint == fingerprint
                    ? CheckoutResult.Replayed(existing.Order)
                    : CheckoutResult.Conflict("این Idempotency-Key قبلاً برای درخواست دیگری استفاده شده است.");

            var catalogItems = catalog.All()
                .SelectMany(product => product.Variants.Select(variant => new { product, variant }))
                .ToDictionary(item => item.variant.Sku, StringComparer.OrdinalIgnoreCase);

            var unavailable = new List<string>();
            var lines = new List<CheckoutLine>();
            foreach (var requested in request.Lines)
            {
                if (!catalogItems.TryGetValue(requested.Sku.Trim(), out var item) || item.variant.AvailablePackages < requested.Quantity)
                {
                    unavailable.Add(requested.Sku.Trim().ToUpperInvariant());
                    continue;
                }

                lines.Add(new CheckoutLine(item.product.Title, item.variant.Sku, item.variant.DisplayLabel,
                    requested.Quantity, item.variant.Price, item.variant.Price * requested.Quantity));
            }

            if (unavailable.Count > 0)
                return CheckoutResult.OutOfStock("حداقل یک کالا موجودی کافی ندارد یا منتشر نشده است.", unavailable);

            foreach (var requested in request.Lines)
                catalog.Reserve(requested.Sku, requested.Quantity);

            var subtotal = lines.Sum(line => line.LineTotal);
            var shipping = subtotal >= 15_000_000 ? 0 : 750_000;
            var now = DateTimeOffset.UtcNow;
            var order = new CheckoutOrder(
                Guid.NewGuid(),
                Convert.ToHexString(RandomNumberGenerator.GetBytes(24)).ToLowerInvariant(),
                request.CustomerName.Trim(), request.Mobile.Trim(), request.Province.Trim(), request.City.Trim(),
                request.Address.Trim(), request.PostalCode.Trim(), "IRR", lines, subtotal, shipping, 0, subtotal + shipping,
                OrderState.AwaitingPayment, now, now.AddMinutes(20),
                [new OrderTransition(OrderState.AwaitingPayment, "customer", now, "checkout-created")]);

            _orders[order.Id] = order;
            _idempotency[idempotencyKey] = new StoredCheckout(fingerprint, order);
            return CheckoutResult.Created(order);
        }
    }

    private static bool FixedTimeTokenEquals(string expectedToken, string? suppliedToken)
    {
        var expected = Encoding.UTF8.GetBytes(expectedToken);
        var supplied = Encoding.UTF8.GetBytes(suppliedToken ?? string.Empty);
        return expected.Length == supplied.Length && CryptographicOperations.FixedTimeEquals(expected, supplied);
    }

    private static string Fingerprint(CheckoutRequest request)
    {
        var canonical = JsonSerializer.Serialize(request with
        {
            Lines = request.Lines.OrderBy(line => line.Sku, StringComparer.OrdinalIgnoreCase).ToArray()
        });
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));
    }

    private sealed record StoredCheckout(string Fingerprint, CheckoutOrder Order);
}

public sealed record CheckoutRequest(string CustomerName, string Mobile, string Province, string City,
    string Address, string PostalCode, IReadOnlyCollection<CheckoutItemRequest> Lines)
{
    public Dictionary<string, string[]> Validate()
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(CustomerName)) errors[nameof(CustomerName)] = ["نام تحویل‌گیرنده الزامی است."];
        if (string.IsNullOrWhiteSpace(Mobile) || Mobile.Trim().Length is < 10 or > 15) errors[nameof(Mobile)] = ["شماره موبایل معتبر الزامی است."];
        if (string.IsNullOrWhiteSpace(Province)) errors[nameof(Province)] = ["استان الزامی است."];
        if (string.IsNullOrWhiteSpace(City)) errors[nameof(City)] = ["شهر الزامی است."];
        if (string.IsNullOrWhiteSpace(Address)) errors[nameof(Address)] = ["نشانی الزامی است."];
        if (string.IsNullOrWhiteSpace(PostalCode)) errors[nameof(PostalCode)] = ["کدپستی الزامی است."];
        if (Lines is null || Lines.Count == 0) errors[nameof(Lines)] = ["سبد خرید خالی است."];
        else
        {
            if (Lines.Count > 30) errors[nameof(Lines)] = ["حداکثر ۳۰ ردیف کالا مجاز است."];
            var duplicateSkus = Lines.GroupBy(line => line.Sku?.Trim() ?? string.Empty, StringComparer.OrdinalIgnoreCase)
                .Where(group => group.Count() > 1).Select(group => group.Key).ToArray();
            if (duplicateSkus.Length > 0) errors["Lines.Sku"] = ["هر SKU فقط یک بار باید ارسال شود."];
            foreach (var (line, index) in Lines.Select((line, index) => (line, index)))
            {
                if (string.IsNullOrWhiteSpace(line.Sku)) errors[$"Lines[{index}].Sku"] = ["SKU الزامی است."];
                if (line.Quantity is < 1 or > 50) errors[$"Lines[{index}].Quantity"] = ["تعداد هر ردیف باید بین ۱ تا ۵۰ باشد."];
            }
        }
        return errors;
    }
}

public sealed record CheckoutItemRequest(string Sku, int Quantity);
public sealed record CheckoutLine(string ProductTitle, string Sku, string VariantLabel, int Quantity, decimal UnitPrice, decimal LineTotal);
public sealed record CheckoutOrder(Guid Id, string ReceiptToken, string CustomerName, string Mobile, string Province,
    string City, string Address, string PostalCode, string Currency, IReadOnlyCollection<CheckoutLine> Lines,
    decimal Subtotal, decimal Shipping, decimal Discount, decimal Payable, OrderState State, DateTimeOffset CreatedAt,
    DateTimeOffset ReservationExpiresAt, IReadOnlyCollection<OrderTransition> Transitions);
public sealed record OrderTransition(OrderState State, string Actor, DateTimeOffset At, string Reason);
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum OrderState { AwaitingPayment, Paid, Preparing, Shipped, Delivered, Cancelled, Expired }
public enum CheckoutStatus { Created, Replayed, Invalid, Conflict, OutOfStock }

public sealed record CheckoutResult(CheckoutStatus Status, CheckoutOrder? Order = null, string? Message = null,
    Dictionary<string, string[]>? Errors = null, IReadOnlyCollection<string>? UnavailableSkus = null)
{
    public static CheckoutResult Created(CheckoutOrder order) => new(CheckoutStatus.Created, order);
    public static CheckoutResult Replayed(CheckoutOrder order) => new(CheckoutStatus.Replayed, order);
    public static CheckoutResult Invalid(Dictionary<string, string[]> errors) => new(CheckoutStatus.Invalid, Errors: errors);
    public static CheckoutResult Conflict(string message) => new(CheckoutStatus.Conflict, Message: message);
    public static CheckoutResult OutOfStock(string message, IReadOnlyCollection<string> skus) => new(CheckoutStatus.OutOfStock, Message: message, UnavailableSkus: skus);
}
