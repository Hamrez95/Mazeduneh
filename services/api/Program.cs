using System.Collections.Concurrent;
using System.Text.Json.Serialization;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.AddJsonConsole(options =>
{
    // Framework request scopes contain raw paths; keep them out of console logs.
    options.IncludeScopes = false;
    options.UseUtcTimestamp = true;
    options.TimestampFormat = "O";
});
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
    context.ProblemDetails.Extensions["requestId"] = context.HttpContext.TraceIdentifier);
builder.Services.AddSingleton<ApiHealthProbe>();
builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddCors(options => options.AddPolicy("Storefront", policy =>
{
    var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
        ?? ["http://localhost:3000", "http://localhost:8080"];
    policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod().WithExposedHeaders("X-Request-ID");
}));
builder.Services.AddSingleton<ProductCatalog>();
builder.Services.AddSingleton<CatalogDatabase>();
builder.Services.AddSingleton<InventoryLedgerDatabase>();
builder.Services.AddSingleton<AdminAuditLogDatabase>();
builder.Services.AddHostedService<AdminAuditLogSchemaInitializer>();
builder.Services.AddSingleton<AdminUsersDatabase>();
builder.Services.AddHostedService<AdminUserSchemaInitializer>();
builder.Services.AddAdminSecurity(builder.Configuration);
builder.Services.AddCheckout();
builder.Services.AddPayments();
builder.Services.AddOrderManagement();
builder.Services.AddMediaStorage(builder.Configuration);
builder.Services.AddInventoryBatches();
builder.Services.AddInventoryPricing();
builder.Services.AddCommercePricing();
builder.Services.AddCorporateSales();

var app = builder.Build();
app.UseMiddleware<RequestObservabilityMiddleware>();
app.UseExceptionHandler();
app.UseHttpsRedirection();
app.UseCors("Storefront");
app.UseRateLimiter();
app.MapAdminSecurity();
app.MapCheckout();
app.MapPayments();
app.MapOrderManagement();
app.MapInventoryLedger();
app.MapMediaStorage();
app.MapInventoryBatches();
app.MapInventoryPricing();
app.MapCommercePricing();
app.MapCorporateSales();

var catalog = app.Services.GetRequiredService<ProductCatalog>();
var database = app.Services.GetRequiredService<CatalogDatabase>();
if (database.IsConfigured)
{
    await database.InitializeAsync(app.Lifetime.ApplicationStopping);
    await app.Services.GetRequiredService<InventoryLedgerDatabase>().InitializeAsync(app.Lifetime.ApplicationStopping);
    await app.Services.GetRequiredService<InventoryBatchDatabase>().InitializeAsync(app.Lifetime.ApplicationStopping);
    await app.Services.GetRequiredService<CommercePricingDatabase>().InitializeAsync(app.Lifetime.ApplicationStopping);
    await app.Services.GetRequiredService<CorporateRequestDatabase>().InitializeAsync(app.Lifetime.ApplicationStopping);
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

app.MapApiHealth();

app.MapGet("/api/v1/categories", async (CatalogDatabase db, CancellationToken cancellationToken) => Results.Ok(await db.LoadCategoriesAsync(cancellationToken)));
app.MapGet("/api/v1/categories/admin", async (CatalogDatabase db, CancellationToken cancellationToken) => Results.Ok(await db.LoadCategoriesAsync(cancellationToken)))
    .AddEndpointFilter<OwnerAuthorizationFilter>();

app.MapPost("/api/v1/categories", async (CreateCategoryRequest request, CatalogDatabase db, CancellationToken cancellationToken) =>
{
    var errors = request.Validate();
    if (errors.Count > 0) return Results.ValidationProblem(errors);
    try
    {
        return Results.Created($"/api/v1/categories/{request.Slug}", await db.InsertCategoryAsync(request, cancellationToken));
    }
    catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
    {
        return Results.Conflict(new { message = "دسته‌ای با این شناسه آدرس وجود دارد." });
    }
})
.AddEndpointFilter<OwnerAuthorizationFilter>();

app.MapPut("/api/v1/categories/{slug}", async (string slug, UpdateCategoryRequest request, CatalogDatabase db, CancellationToken cancellationToken) =>
{
    var errors = request.Validate();
    if (errors.Count > 0) return Results.ValidationProblem(errors);
    var before = (await db.LoadCategoriesAsync(cancellationToken)).FirstOrDefault(item => item.Slug.Equals(slug, StringComparison.OrdinalIgnoreCase));
    var updated = await db.UpdateCategoryAsync(slug, request, cancellationToken);
    if (before is not null && updated is not null) app.Services.GetRequiredService<ProductCatalog>().RenameCategory(before.Name, updated.Name);
    return updated is null ? Results.NotFound(new { message = "دسته‌بندی موردنظر پیدا نشد." }) : Results.Ok(updated);
}).AddEndpointFilter<OwnerAuthorizationFilter>();

app.MapPatch("/api/v1/categories/{slug}/active", async (string slug, SetCategoryActiveRequest request, CatalogDatabase db, CancellationToken cancellationToken) =>
{
    var updated = await db.SetCategoryActiveAsync(slug, request.IsActive, cancellationToken);
    return updated is null ? Results.NotFound(new { message = "دسته‌بندی موردنظر پیدا نشد." }) : Results.Ok(new { message = request.IsActive ? "دسته‌بندی فعال شد." : "دسته‌بندی غیرفعال شد.", category = updated });
}).AddEndpointFilter<OwnerAuthorizationFilter>();

app.MapDelete("/api/v1/categories/{slug}", async (string slug, CatalogDatabase db, ProductCatalog productCatalog, CancellationToken cancellationToken) =>
{
    var category = (await db.LoadCategoriesAsync(cancellationToken)).FirstOrDefault(item => item.Slug.Equals(slug, StringComparison.OrdinalIgnoreCase));
    if (category is not null && productCatalog.AllIncludingDrafts().Any(product => product.Category.Equals(category.Name, StringComparison.OrdinalIgnoreCase)))
        return Results.Conflict(new { message = "این دسته‌بندی به محصول متصل است و حذف نمی‌شود. ابتدا محصولات را جابه‌جا یا دسته را غیرفعال کنید." });
    var result = await db.DeleteCategoryAsync(slug, cancellationToken);
    if (result.ProductCount == -1) return Results.NotFound(new { message = "دسته‌بندی موردنظر پیدا نشد." });
    if (!result.Deleted) return Results.Conflict(new { message = $"این دسته‌بندی به {result.ProductCount} محصول متصل است و حذف نمی‌شود. ابتدا محصولات را جابه‌جا یا دسته را غیرفعال کنید." });
    return Results.Ok(new { message = "دسته‌بندی با موفقیت حذف شد." });
}).AddEndpointFilter<OwnerAuthorizationFilter>();

app.MapGet("/api/v1/catalog/unit-types", () => Results.Ok(new[]
{
    new { value = nameof(ProductUnitType.Weight), baseUnit = "gram", titleFa = "وزنی / گرم" },
    new { value = nameof(ProductUnitType.Count), baseUnit = "piece", titleFa = "عددی / عدد" }
}));

var products = app.MapGroup("/api/v1/products").WithTags("Products");
products.MapGet("/", async (
    ProductCatalog productCatalog,
    CatalogDatabase liveDatabase,
    InventoryBatchDatabase batches,
    CancellationToken cancellationToken) =>
    Results.Ok(await CatalogWithExpiryAsync(await CurrentCatalogAsync(productCatalog, liveDatabase, false, cancellationToken), batches, cancellationToken)));
products.MapGet("/admin", async (
    ProductCatalog productCatalog,
    CatalogDatabase liveDatabase,
    InventoryBatchDatabase batches,
    CancellationToken cancellationToken) =>
    Results.Ok(await CatalogWithExpiryAsync(await CurrentCatalogAsync(productCatalog, liveDatabase, true, cancellationToken), batches, cancellationToken, includeCosts: true)))
    .AddEndpointFilter<OwnerAuthorizationFilter>();
products.MapGet("/{slug}", async (
    string slug,
    ProductCatalog productCatalog,
    CatalogDatabase liveDatabase,
    InventoryBatchDatabase batches,
    CancellationToken cancellationToken) =>
{
    var product = (await CurrentCatalogAsync(productCatalog, liveDatabase, false, cancellationToken)).FirstOrDefault(p => p.Slug.Equals(slug, StringComparison.OrdinalIgnoreCase));
    if (product is null) return Results.NotFound(new { message = "محصول پیدا نشد یا هنوز منتشر نشده است." });
    var enriched = (await CatalogWithExpiryAsync([product], batches, cancellationToken)).Single();
    return Results.Ok(enriched);
});

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
    if (request.IsPublished)
    {
        var publicationErrors = productCatalog.ValidateForPublication(product);
        if (publicationErrors.Count > 0) return Results.ValidationProblem(publicationErrors);
    }
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

products.MapPut("/{slug}", async (
    string slug,
    UpdateProductRequest request,
    ProductCatalog productCatalog,
    CatalogDatabase db,
    CancellationToken cancellationToken) =>
{
    var existing = productCatalog.FindBySlug(slug);
    if (existing is null) return Results.NotFound(new { message = "محصول موردنظر پیدا نشد." });
    var errors = request.Validate();
    if (errors.Count > 0) return Results.ValidationProblem(errors);
    var updated = productCatalog.Update(existing, request);
    if (existing.IsPublished)
    {
        var publicationErrors = productCatalog.ValidateForPublication(updated);
        if (publicationErrors.Count > 0) return Results.ValidationProblem(publicationErrors);
    }
    await db.UpdateAsync(updated, cancellationToken);
    productCatalog.Add(updated);
    return Results.Ok(updated);
})
.AddEndpointFilter<OwnerAuthorizationFilter>();

products.MapPatch("/{slug}/publication", async (
    string slug,
    SetProductPublicationRequest request,
    ProductCatalog productCatalog,
    CatalogDatabase db,
    AdminAuditLogDatabase audit,
    HttpContext context,
    CancellationToken cancellationToken) =>
{
    var existing = productCatalog.FindBySlug(slug);
    if (existing is null)
        return Results.NotFound(new { message = "محصول موردنظر پیدا نشد." });

    if (request.IsPublished)
    {
        var publicationErrors = productCatalog.ValidateForPublication(existing);
        if (publicationErrors.Count > 0) return Results.ValidationProblem(publicationErrors);
    }
    var updated = existing with { IsPublished = request.IsPublished };
    await db.SetPublicationAsync(existing.Id, request.IsPublished, cancellationToken);
    productCatalog.Add(updated);
    var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
    await audit.RecordAsync(
        actor,
        "product.publication",
        "Product",
        existing.Id.ToString(),
        new { existing.Slug, existing.IsPublished },
        new { updated.Slug, updated.IsPublished },
        request.IsPublished ? "انتشار محصول" : "خارج کردن محصول از انتشار",
        context.TraceIdentifier,
        cancellationToken);

    return Results.Ok(new
    {
        message = request.IsPublished ? "محصول با موفقیت منتشر شد." : "محصول از فروشگاه خارج شد.",
        product = updated
    });
})
.AddEndpointFilter<OwnerAuthorizationFilter>();

app.Run();

static async Task<IReadOnlyCollection<Product>> CurrentCatalogAsync(ProductCatalog catalog, CatalogDatabase database, bool includeDrafts, CancellationToken ct)
{
    var products = database.IsConfigured ? await database.LoadAsync(ct) : catalog.AllIncludingDrafts();
    return products.Where(p => includeDrafts || p.IsPublished).ToArray();
}

static async Task<IReadOnlyCollection<Product>> CatalogWithExpiryAsync(
    IReadOnlyCollection<Product> products,
    InventoryBatchDatabase batches,
    CancellationToken cancellationToken,
    bool includeCosts = false)
{
    var expiryBySku = await batches.EarliestExpiryBySkuAsync(cancellationToken);
    return products.Select(product =>
    {
        var expiry = product.Variants
            .Select(variant => expiryBySku.TryGetValue(variant.Sku, out var value) ? value : (DateTimeOffset?)null)
            .Where(value => value is not null)
            .Min();
        return product with {
            EarliestAvailableExpiryAt = expiry,
            Variants = includeCosts ? product.Variants : product.Variants.Select(variant =>
                variant with { CostPrice = 0, PackagingCost = 0, AdditionalCost = 0 }).ToArray()
        };
    }).ToArray();
}

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

    public Dictionary<string, string[]> ValidateForPublication(Product product)
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(product.Title) || string.IsNullOrWhiteSpace(product.Category) || string.IsNullOrWhiteSpace(product.Origin))
            errors["publication"] = ["عنوان، دسته‌بندی و مبدأ محصول باید پیش از انتشار کامل باشند."];
        if (product.Variants.Count == 0)
            errors["publication.variants"] = ["برای انتشار حداقل یک بسته قابل فروش ثبت کنید."];
        else if (product.Variants.Any(variant => string.IsNullOrWhiteSpace(variant.Sku) || string.IsNullOrWhiteSpace(variant.DisplayLabel) || variant.Price <= 0))
            errors["publication.variants"] = ["برای همه بسته‌ها SKU، عنوان بسته و قیمت بیشتر از صفر ثبت کنید."];
        return errors;
    }

    public Product Build(CreateProductRequest request)
    {
        var unitType = Enum.Parse<ProductUnitType>(request.UnitType, true);
        var baseUnit = unitType == ProductUnitType.Weight ? "gram" : "piece";
        var product = new Product(Guid.NewGuid(), request.Title.Trim(), request.Slug.Trim().ToLowerInvariant(),
            request.Category.Trim(), request.Origin.Trim(), request.Currency.Trim().ToUpperInvariant(), unitType,
            request.IsPublished, request.Variants.Select(item => new ProductVariant(item.Sku.Trim().ToUpperInvariant(),
                item.Quantity, baseUnit, item.DisplayLabel.Trim(), item.Price, item.AvailablePackages, item.CostPrice)
                {
                    PackagingCost = item.PackagingCost,
                    AdditionalCost = item.AdditionalCost
                }).ToArray(), DateTimeOffset.UtcNow,
            request.ShortDescription?.Trim() ?? string.Empty, request.Description?.Trim() ?? string.Empty,
            request.SeoTitle?.Trim() ?? request.Title.Trim(), request.SeoDescription?.Trim() ?? request.ShortDescription?.Trim() ?? string.Empty,
            request.SeoKeywords?.Trim() ?? string.Empty, request.PrimaryImage?.Trim() ?? string.Empty,
            request.GalleryImages?.Where(item => !string.IsNullOrWhiteSpace(item)).Select(item => item.Trim()).Distinct().ToArray() ?? [],
            request.Specifications ?? new Dictionary<string, string>())
        {
            Ingredients = request.Ingredients?.Trim() ?? string.Empty,
            Allergens = request.Allergens ?? Array.Empty<string>(),
            NutritionFacts = request.NutritionFacts ?? new Dictionary<string, decimal>(),
            StorageInstructions = request.StorageInstructions?.Trim() ?? string.Empty,
            ShelfLifeDays = request.ShelfLifeDays,
            NetWeight = request.NetWeight,
            NetWeightUnit = request.NetWeightUnit?.Trim() ?? "gram",
            ExpiryLabel = request.ExpiryLabel?.Trim() ?? "best-before"
        };
        return product;
    }

    public Product Update(Product existing, UpdateProductRequest request)
    {
        var unitType = Enum.Parse<ProductUnitType>(request.UnitType, true);
        var baseUnit = unitType == ProductUnitType.Weight ? "gram" : "piece";
        return existing with
        {
            Title = request.Title.Trim(),
            Category = request.Category.Trim(),
            Origin = request.Origin.Trim(),
            UnitType = unitType,
            ShortDescription = request.ShortDescription?.Trim() ?? string.Empty,
            Description = request.Description?.Trim() ?? string.Empty,
            SeoTitle = request.SeoTitle?.Trim() ?? request.Title.Trim(),
            SeoDescription = request.SeoDescription?.Trim() ?? request.ShortDescription?.Trim() ?? string.Empty,
            SeoKeywords = request.SeoKeywords?.Trim() ?? string.Empty,
            PrimaryImage = request.PrimaryImage?.Trim() ?? string.Empty,
            GalleryImages = request.GalleryImages?.Where(item => !string.IsNullOrWhiteSpace(item)).Select(item => item.Trim()).Distinct().ToArray() ?? [],
            Specifications = request.Specifications ?? new Dictionary<string, string>(),
            Ingredients = request.Ingredients?.Trim() ?? string.Empty,
            Allergens = request.Allergens ?? Array.Empty<string>(),
            NutritionFacts = request.NutritionFacts ?? new Dictionary<string, decimal>(),
            StorageInstructions = request.StorageInstructions?.Trim() ?? string.Empty,
            ShelfLifeDays = request.ShelfLifeDays,
            NetWeight = request.NetWeight,
            NetWeightUnit = request.NetWeightUnit?.Trim() ?? "gram",
            ExpiryLabel = request.ExpiryLabel?.Trim() ?? "best-before",
            Variants = request.Variants.Select(item => new ProductVariant(item.Sku.Trim().ToUpperInvariant(), item.Quantity, baseUnit, item.DisplayLabel.Trim(), item.Price, item.AvailablePackages, item.CostPrice)
            {
                PackagingCost = item.PackagingCost,
                AdditionalCost = item.AdditionalCost
            }).ToArray()
        };
    }

    public void Add(Product product) => _products[product.Id] = product;
    public void RenameCategory(string previousName, string newName)
    {
        foreach (var product in _products.Values.Where(item => item.Category.Equals(previousName, StringComparison.OrdinalIgnoreCase)))
            _products[product.Id] = product with { Category = newName };
    }
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

public partial class Program;
