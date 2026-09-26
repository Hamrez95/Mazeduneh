public sealed record Product(Guid Id, string Title, string Slug, string Category, string Origin, string Currency,
    ProductUnitType UnitType, bool IsPublished, IReadOnlyCollection<ProductVariant> Variants, DateTimeOffset CreatedAt,
    string ShortDescription = "", string Description = "", string SeoTitle = "", string SeoDescription = "",
    string SeoKeywords = "", string PrimaryImage = "", IReadOnlyCollection<string>? GalleryImages = null,
    IReadOnlyDictionary<string, string>? Specifications = null);

public sealed record ProductVariant(string Sku, decimal Quantity, string BaseUnit, string DisplayLabel, decimal Price, int AvailablePackages, decimal CostPrice = 0);

public sealed record CreateProductRequest(string Title, string Slug, string Category, string Origin, string Currency,
    string UnitType, bool IsPublished, IReadOnlyCollection<CreateProductVariantRequest> Variants,
    string? ShortDescription = null, string? Description = null, string? SeoTitle = null, string? SeoDescription = null,
    string? SeoKeywords = null, string? PrimaryImage = null, IReadOnlyCollection<string>? GalleryImages = null,
    IReadOnlyDictionary<string, string>? Specifications = null)
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
            if (item.CostPrice < 0) errors[$"Variants[{index}].CostPrice"] = ["قیمت تمام‌شده نمی‌تواند منفی باشد."];
        }
        return errors;
    }
}

public sealed record CreateProductVariantRequest(string Sku, decimal Quantity, string DisplayLabel, decimal Price, int AvailablePackages, decimal CostPrice = 0);

public sealed record UpdateProductRequest(string Title, string Category, string Origin, string Currency, string UnitType,
    IReadOnlyCollection<CreateProductVariantRequest> Variants, string? ShortDescription = null, string? Description = null,
    string? SeoTitle = null, string? SeoDescription = null, string? SeoKeywords = null, string? PrimaryImage = null,
    IReadOnlyCollection<string>? GalleryImages = null, IReadOnlyDictionary<string, string>? Specifications = null)
{
    public Dictionary<string, string[]> Validate() =>
        new CreateProductRequest(Title, "existing", Category, Origin, Currency, UnitType, true, Variants).Validate();
}

public sealed record CreateCategoryRequest(string Name, string Slug, string? Description = null, string? SeoTitle = null, string? SeoDescription = null, int SortOrder = 0, bool IsActive = true)
{
    public Dictionary<string, string[]> Validate()
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(Name)) errors[nameof(Name)] = ["نام دسته‌بندی الزامی است."];
        if (string.IsNullOrWhiteSpace(Slug) || !System.Text.RegularExpressions.Regex.IsMatch(Slug.Trim(), "^[a-z0-9]+(?:-[a-z0-9]+)*$")) errors[nameof(Slug)] = ["شناسه انگلیسی معتبر وارد کنید."];
        if (SortOrder < 0) errors[nameof(SortOrder)] = ["ترتیب نمایش نمی‌تواند منفی باشد."];
        return errors;
    }
}

public sealed record Category(Guid Id, string Name, string Slug, string Description, string SeoTitle, string SeoDescription, int SortOrder, bool IsActive, DateTimeOffset CreatedAt);

public sealed record SetProductPublicationRequest(bool IsPublished);
