public static class ProductCatalogCheckoutExtensions
{
    public static void Reserve(this ProductCatalog catalog, string sku, int quantity)
    {
        var variant = FindVariant(catalog, sku);
        if (variant.Variant.AvailablePackages < quantity)
            throw new InvalidOperationException("Insufficient stock for reservation.");
        catalog.SetAvailablePackages(sku, variant.Variant.AvailablePackages - quantity);
    }

    public static void Release(this ProductCatalog catalog, string sku, int quantity)
    {
        var variant = FindVariant(catalog, sku);
        catalog.SetAvailablePackages(sku, variant.Variant.AvailablePackages + quantity);
    }

    public static void SetAvailablePackages(this ProductCatalog catalog, string sku, int availablePackages)
    {
        if (availablePackages < 0)
            throw new ArgumentOutOfRangeException(nameof(availablePackages));

        var match = FindVariant(catalog, sku);
        var variants = match.Product.Variants.Select(item =>
            item.Sku.Equals(sku, StringComparison.OrdinalIgnoreCase)
                ? item with { AvailablePackages = availablePackages }
                : item).ToArray();
        catalog.Add(match.Product with { Variants = variants });
    }

    private static (Product Product, ProductVariant Variant) FindVariant(ProductCatalog catalog, string sku)
    {
        foreach (var product in catalog.AllIncludingDrafts())
        {
            var variant = product.Variants.FirstOrDefault(item => item.Sku.Equals(sku, StringComparison.OrdinalIgnoreCase));
            if (variant is not null) return (product, variant);
        }
        throw new InvalidOperationException("Product variant was not found.");
    }
}
