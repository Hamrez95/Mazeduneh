using System.Collections.Concurrent;
using System.Text.Json.Serialization;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddProblemDetails();
builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddCors(options => options.AddPolicy("Storefront", policy =>
{
    var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
        ?? ["http://localhost:3000", "http://localhost:8080"];
    policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
}));
builder.Services.AddSingleton<ProductCatalog>();
builder.Services.AddSingleton<CatalogDatabase>();
builder.Services.AddSingleton<InventoryLedgerDatabase>();
builder.Services.AddAdminSecurity(builder.Configuration);
builder.Services.AddCheckout();
builder.Services.AddPayments();
builder.Services.AddOrderManagement();

var app = builder.Build();
app.UseExceptionHandler();
app.UseHttpsRedirection();
app.UseCors("Storefront");
app.UseRateLimiter();
app.MapAdminSecurity();
app.MapCheckout();
app.MapPayments();
app.MapOrderManagement();
app.MapInventoryLedger();

var catalog = app.Services.GetRequiredService<ProductCatalog>();
var database = app.Services.GetRequiredService<CatalogDatabase>();
if (database.IsConfigured)
{
    await database.InitializeAsync(app.Lifetime.ApplicationStopping);
    var persistedProducts = await database.LoadAsync(app.Lifetime.ApplicationStopping);
    if (persistedProducts.Count == 0)
    {
        foreach (var seededProduct in catalog.AllIncludingDrafts())
            await database.InsertAsync(seededProduct, app.Lifetime.ApplicationStopping);
    }
    else
    {
        catalog.ReplaceWith(persistedProducts);
    }
}

app.MapGet("/health", async (
    CatalogDatabase db,
    AdminTokenService adminTokens,
    PaymentDatabase paymentDatabase,
    CancellationToken cancellationToken) =>
{
    var databaseStatus = !db.IsConfigured ? "not-configured" :
        await db.CanConnectAsync(cancellationToken) ? "healthy" : "unhealthy";

    return Results.Ok(new
    {
        status = databaseStatus == "unhealthy" ? "degraded" : "healthy",
        service = "mazeduneh-api",
        database = databaseStatus,
        adminAuthentication = adminTokens.IsConfigured ? "configured" : "not-configured",
        paymentSandbox = paymentDatabase.SandboxEnabled ? "enabled" : "disabled",
        utc = DateTimeOffset.UtcNow
    });
});

app.MapGet("/api/v1/catalog/unit-types", () => Results.Ok(new[]
{
    new { value = nameof(ProductUnitType.Weight), baseUnit = "gram", titleFa = "وزنی / گرم" },
    new { value = nameof(ProductUnitType.Count), baseUnit = "piece", titleFa = "عددی / عدد" }
}));

var products = app.MapGroup("/api/v1/products").WithTags("Products");
products.MapGet("/", (ProductCatalog productCatalog) => Results.Ok(productCatalog.All()));
products.MapGet("/admin", (ProductCatalog productCatalog) => Results.Ok(productCatalog.AllIncludingDrafts()))
    .AddEndpointFilter<OwnerAuthorizationFilter>();
products.MapGet("/{slug}", (string slug, ProductCatalog productCatalog) =>
    productCatalog.FindPublishedBySlug(slug) is { } product
        ? Results.Ok(product)
        : Results.NotFound(new { message = "محصول پیدا نشد یا هنوز منتشر نشده است." }));

products.MapPost("/", async (
    CreateProductRequest request,
    ProductCatalog productCatalog,
    CatalogDatabase db,
    CancellationToken cancellationToken) =>
{
    var errors = request.Validate();
    if (errors.Count > 0) return Results.ValidationProblem(errors);
    if (productCatalog.SlugExists(request.Slug))
        return Results.Conflict(new { message = "محصولی با این شناسه آدرس وجود دارد." });
    if (productCatalog.SkuExists(request.Variants.Select(item => item.Sku)))
        return Results.Conflict(new { message = "حداقل یک SKU قبلاً استفاده شده است." });

    var product = productCatalog.Build(request);
    try
    {
        await db.InsertAsync(product, cancellationToken);
        productCatalog.Add(product);
        return Results.Created($"/api/v1/products/{product.Slug}", product);
    }
    catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
    {
        return Results.Conflict(new { message = "شناسه آدرس یا SKU تکراری است." });
    }
})
.AddEndpointFilter<OwnerAuthorizationFilter>();

products.MapPatch("/{slug}/publication", async (
    string slug,
    SetProductPublicationRequest request,
    ProductCatalog productCatalog,
    CatalogDatabase db,
    CancellationToken cancellationToken) =>
{
    var existing = productCatalog.FindBySlug(slug);
    if (existing is null)
        return Results.NotFound(new { message = "محصول موردنظر پیدا نشد." });

    var updated = existing with { IsPublished = request.IsPublished };
    await db.SetPublicationAsync(existing.Id, request.IsPublished, cancellationToken);
    productCatalog.Add(updated);

    return Results.Ok(new
    {
        message = request.IsPublished ? "محصول با موفقیت منتشر شد." : "محصول از فروشگاه خارج شد.",
        product = updated
    });
})
.AddEndpointFilter<OwnerAuthorizationFilter>();

app.Run();

public enum ProductUnitType { Weight, Count }

public sealed class ProductCatalog
{
    private readonly ConcurrentDictionary<Guid, Product> _products = new();

    public ProductCatalog()
    {
        Add(Seed("پسته اکبری ممتاز", "pistachio-akbari-premium", "پسته و مغزیجات", "رفسنجان", ProductUnitType.Weight,
            [V("PI-AKB-250",250,"۲۵۰ گرم",2_450_000,18),V("PI-AKB-500",500,"۵۰۰ گرم",4_650_000,12),V("PI-AKB-1000",1000,"۱۰۰۰ گرم",8_900_000,6)]));
        Add(Seed("پسته احمدآقایی ممتاز", "pistachio-ahmad-aghaei-premium", "پسته و مغزیجات", "کرمان", ProductUnitType.Weight,
            [V("PI-AHM-250",250,"۲۵۰ گرم",2_350_000,16),V("PI-AHM-500",500,"۵۰۰ گرم",4_450_000,10),V("PI-AHM-1000",1000,"۱۰۰۰ گرم",8_500_000,5)]));
        Add(Seed("تخمه کدو گوشتی", "pumpkin-seeds", "تخمه و تنقلات", "ایران", ProductUnitType.Weight,
            [V("SE-PUM-250",250,"۲۵۰ گرم",950_000,22),V("SE-PUM-500",500,"۵۰۰ گرم",1_800_000,14),V("SE-PUM-1000",1000,"۱۰۰۰ گرم",3_400_000,7)]));
        Add(Seed("بادام درختی خام", "raw-almond", "پسته و مغزیجات", "چهارمحال", ProductUnitType.Weight,
            [V("NU-ALM-250",250,"۲۵۰ گرم",1_750_000,25),V("NU-ALM-500",500,"۵۰۰ گرم",3_300_000,16),V("NU-ALM-1000",1000,"۱۰۰۰ گرم",6_400_000,8)]));
        Add(Seed("مغز گردوی ایرانی", "iranian-walnut-kernel", "پسته و مغزیجات", "تویسرکان", ProductUnitType.Weight,
            [V("NU-WAL-250",250,"۲۵۰ گرم",1_620_000,18),V("NU-WAL-500",500,"۵۰۰ گرم",3_050_000,10),V("NU-WAL-1000",1000,"۱۰۰۰ گرم",5_900_000,5)]));
        Add(Seed("کوکی پروتئینی مزه‌دونه", "mazeduneh-protein-cookie", "کوکی و کیک سالم", "تولید روز", ProductUnitType.Count,
            [V("CK-PRO-1",1,"۱ عدد",950_000,48,"piece"),V("CK-PRO-4",4,"پک ۴ عددی",3_600_000,20,"piece"),V("CK-PRO-8",8,"پک ۸ عددی",6_900_000,10,"piece")]));
    }

    public IReadOnlyCollection<Product> All() => AllIncludingDrafts().Where(item => item.IsPublished).ToArray();
    public IReadOnlyCollection<Product> AllIncludingDrafts() => _products.Values.OrderBy(item => item.Category).ThenBy(item => item.Title).ToArray();
    public Product? FindBySlug(string slug) => _products.Values.FirstOrDefault(item => item.Slug.Equals(slug, StringComparison.OrdinalIgnoreCase));
    public Product? FindPublishedBySlug(string slug) => _products.Values.FirstOrDefault(item => item.IsPublished && item.Slug.Equals(slug, StringComparison.OrdinalIgnoreCase));
    public bool SlugExists(string slug) => _products.Values.Any(item => item.Slug.Equals(slug.Trim(), StringComparison.OrdinalIgnoreCase));
    public bool SkuExists(IEnumerable<string> skus)
    {
        var requested = skus.Select(item => item.Trim()).ToHashSet(StringComparer.OrdinalIgnoreCase);
        return _products.Values.SelectMany(item => item.Variants).Any(item => requested.Contains(item.Sku));
    }

    public Product Build(CreateProductRequest request)
    {
        var unitType = Enum.Parse<ProductUnitType>(request.UnitType, true);
        var baseUnit = unitType == ProductUnitType.Weight ? "gram" : "piece";
        return new Product(Guid.NewGuid(), request.Title.Trim(), request.Slug.Trim().ToLowerInvariant(),
            request.Category.Trim(), request.Origin.Trim(), request.Currency.Trim().ToUpperInvariant(), unitType,
            request.IsPublished, request.Variants.Select(item => new ProductVariant(item.Sku.Trim().ToUpperInvariant(),
                item.Quantity, baseUnit, item.DisplayLabel.Trim(), item.Price, item.AvailablePackages)).ToArray(), DateTimeOffset.UtcNow);
    }

    public void Add(Product product) => _products[product.Id] = product;
    public void ReplaceWith(IEnumerable<Product> products)
    {
        _products.Clear();
        foreach (var product in products) Add(product);
    }

    private static Product Seed(string title, string slug, string category, string origin, ProductUnitType type, ProductVariant[] variants) =>
        new(Guid.NewGuid(), title, slug, category, origin, "IRR", type, true, variants, DateTimeOffset.UtcNow);
    private static ProductVariant V(string sku, decimal quantity, string label, decimal price, int stock, string unit = "gram") =>
        new(sku, quantity, unit, label, price, stock);
}

public sealed record Product(Guid Id, string Title, string Slug, string Category, string Origin, string Currency,
    ProductUnitType UnitType, bool IsPublished, IReadOnlyCollection<ProductVariant> Variants, DateTimeOffset CreatedAt);
public sealed record ProductVariant(string Sku, decimal Quantity, string BaseUnit, string DisplayLabel, decimal Price, int AvailablePackages);

public sealed record CreateProductRequest(string Title, string Slug, string Category, string Origin, string Currency,
    string UnitType, bool IsPublished, IReadOnlyCollection<CreateProductVariantRequest> Variants)
{
    public Dictionary<string, string[]> Validate()
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(Title)) errors[nameof(Title)] = ["عنوان محصول الزامی است."];
        if (string.IsNullOrWhiteSpace(Slug)) errors[nameof(Slug)] = ["شناسه آدرس محصول الزامی است."];
        if (string.IsNullOrWhiteSpace(Category)) errors[nameof(Category)] = ["دسته‌بندی محصول الزامی است."];
        if (string.IsNullOrWhiteSpace(Origin)) errors[nameof(Origin)] = ["مبدأ یا برند محصول الزامی است."];
        if (string.IsNullOrWhiteSpace(Currency)) errors[nameof(Currency)] = ["واحد پول الزامی است."];
        if (!Enum.TryParse<ProductUnitType>(UnitType, true, out _)) errors[nameof(UnitType)] = ["نوع واحد باید Weight یا Count باشد."];
        if (Variants is null || Variants.Count == 0) { errors[nameof(Variants)] = ["حداقل یک بسته قابل فروش الزامی است."]; return errors; }
        var duplicates = Variants.Where(item => !string.IsNullOrWhiteSpace(item.Sku)).GroupBy(item => item.Sku.Trim(), StringComparer.OrdinalIgnoreCase).Where(group => group.Count() > 1).Select(group => group.Key).ToArray();
        if (duplicates.Length > 0) errors["Variants.Sku"] = [$"کدهای کالا تکراری هستند: {string.Join("، ", duplicates)}"];
        for (var index = 0; index < Variants.Count; index++)
        {
            var item = Variants.ElementAt(index);
            if (string.IsNullOrWhiteSpace(item.Sku)) errors[$"Variants[{index}].Sku"] = ["کد کالا الزامی است."];
            if (string.IsNullOrWhiteSpace(item.DisplayLabel)) errors[$"Variants[{index}].DisplayLabel"] = ["عنوان بسته الزامی است."];
            if (item.Quantity <= 0) errors[$"Variants[{index}].Quantity"] = ["مقدار بسته باید بیشتر از صفر باشد."];
            if (item.Price < 0) errors[$"Variants[{index}].Price"] = ["قیمت نمی‌تواند منفی باشد."];
            if (item.AvailablePackages < 0) errors[$"Variants[{index}].AvailablePackages"] = ["موجودی نمی‌تواند منفی باشد."];
        }
        return errors;
    }
}
public sealed record CreateProductVariantRequest(string Sku, decimal Quantity, string DisplayLabel, decimal Price, int AvailablePackages);
public sealed record SetProductPublicationRequest(bool IsPublished);
public partial class Program;
