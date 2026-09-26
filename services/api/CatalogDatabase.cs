using System.Text.Json;
using Npgsql;
using NpgsqlTypes;

public sealed class CatalogDatabase(IConfiguration configuration, ILogger<CatalogDatabase> logger, InventoryLedgerDatabase ledger)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        const string sql = """
            create table if not exists products (
                id uuid primary key,
                title text not null,
                slug text not null unique,
                category text not null,
                origin text not null,
                currency varchar(3) not null,
                unit_type varchar(16) not null check (unit_type in ('Weight','Count')),
                is_published boolean not null,
                created_at timestamptz not null
            );
            alter table products add column if not exists short_description text not null default '';
            alter table products add column if not exists description text not null default '';
            alter table products add column if not exists seo_title text not null default '';
            alter table products add column if not exists seo_description text not null default '';
            alter table products add column if not exists seo_keywords text not null default '';
            alter table products add column if not exists primary_image text not null default '';
            alter table products add column if not exists gallery_images jsonb not null default '[]'::jsonb;
            alter table products add column if not exists specifications jsonb not null default '{}'::jsonb;

            create table if not exists product_variants (
                id uuid primary key,
                product_id uuid not null references products(id) on delete cascade,
                sku text not null unique,
                quantity numeric(12,3) not null check (quantity > 0),
                base_unit varchar(16) not null check (base_unit in ('gram','piece')),
                display_label text not null,
                price numeric(18,2) not null check (price >= 0),
                available_packages integer not null check (available_packages >= 0)
            );
            alter table product_variants add column if not exists cost_price numeric(18,2) not null default 0;

            create table if not exists categories (
                id uuid primary key,
                name text not null,
                slug text not null unique,
                description text not null default '',
                seo_title text not null default '',
                seo_description text not null default '',
                sort_order integer not null default 0 check (sort_order >= 0),
                is_active boolean not null default true,
                created_at timestamptz not null
            );
            insert into categories (id,name,slug,description,seo_title,seo_description,sort_order,is_active,created_at)
            values
                (gen_random_uuid(),'پسته و مغزیجات','nuts','مغزیجات و خشکبار منتخب','پسته و مغزیجات مزه‌دونه','خرید پسته و مغزیجات باکیفیت',10,true,now()),
                (gen_random_uuid(),'تخمه و تنقلات','seeds-snacks','تخمه و تنقلات سالم','تخمه و تنقلات سالم مزه‌دونه','خرید تخمه و تنقلات تازه',20,true,now()),
                (gen_random_uuid(),'کوکی و کیک سالم','healthy-bakery','کوکی و خوراکی‌های سالم','کوکی و کیک سالم مزه‌دونه','خرید کوکی و خوراکی سالم',30,true,now())
            on conflict (slug) do nothing;

            create index if not exists ix_products_published_category on products(is_published, category, title);
            create index if not exists ix_product_variants_product_id on product_variants(product_id);
            create index if not exists ix_categories_active_sort on categories(is_active, sort_order, name);
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync(cancellationToken);
        logger.LogInformation("Catalog PostgreSQL schema is ready.");
    }

    public async Task<IReadOnlyCollection<Category>> LoadCategoriesAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return DefaultCategories();
        const string sql = "select id,name,slug,description,seo_title,seo_description,sort_order,is_active,created_at from categories order by sort_order,name;";
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var categories = new List<Category>();
        while (await reader.ReadAsync(cancellationToken))
            categories.Add(new Category(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetString(5), reader.GetInt32(6), reader.GetBoolean(7), reader.GetFieldValue<DateTimeOffset>(8)));
        return categories;
    }

    public async Task<Category> InsertCategoryAsync(CreateCategoryRequest request, CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new Category(Guid.NewGuid(), request.Name.Trim(), request.Slug.Trim().ToLowerInvariant(), request.Description?.Trim() ?? "", request.SeoTitle?.Trim() ?? request.Name.Trim(), request.SeoDescription?.Trim() ?? "", request.SortOrder, request.IsActive, DateTimeOffset.UtcNow);
        const string sql = """
            insert into categories (id,name,slug,description,seo_title,seo_description,sort_order,is_active,created_at)
            values (@id,@name,@slug,@description,@seo_title,@seo_description,@sort_order,@is_active,@created_at)
            returning id,name,slug,description,seo_title,seo_description,sort_order,is_active,created_at;
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        var category = new Category(Guid.NewGuid(), request.Name.Trim(), request.Slug.Trim().ToLowerInvariant(), request.Description?.Trim() ?? "", request.SeoTitle?.Trim() ?? request.Name.Trim(), request.SeoDescription?.Trim() ?? "", request.SortOrder, request.IsActive, DateTimeOffset.UtcNow);
        command.Parameters.AddWithValue("id", category.Id);
        command.Parameters.AddWithValue("name", category.Name);
        command.Parameters.AddWithValue("slug", category.Slug);
        command.Parameters.AddWithValue("description", category.Description);
        command.Parameters.AddWithValue("seo_title", category.SeoTitle);
        command.Parameters.AddWithValue("seo_description", category.SeoDescription);
        command.Parameters.AddWithValue("sort_order", category.SortOrder);
        command.Parameters.AddWithValue("is_active", category.IsActive);
        command.Parameters.AddWithValue("created_at", category.CreatedAt);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        await reader.ReadAsync(cancellationToken);
        return new Category(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetString(5), reader.GetInt32(6), reader.GetBoolean(7), reader.GetFieldValue<DateTimeOffset>(8));
    }

    public async Task<IReadOnlyCollection<Product>> LoadAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<Product>();
        const string sql = """
            select p.id,p.title,p.slug,p.category,p.origin,p.currency,p.unit_type,p.is_published,
                   p.short_description,p.description,p.seo_title,p.seo_description,p.seo_keywords,p.primary_image,
                   p.gallery_images,p.specifications,p.created_at,
                   v.sku,v.quantity,v.base_unit,v.display_label,v.price,v.available_packages,v.cost_price
            from products p left join product_variants v on v.product_id = p.id
            order by p.category,p.title,v.quantity;
            """;
        var products = new Dictionary<Guid, ProductAccumulator>();
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var id = reader.GetGuid(0);
            if (!products.TryGetValue(id, out var item))
            {
                item = new ProductAccumulator(
                    id, reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetString(5),
                    Enum.Parse<ProductUnitType>(reader.GetString(6)), reader.GetBoolean(7), reader.GetString(8), reader.GetString(9),
                    reader.GetString(10), reader.GetString(11), reader.GetString(12), reader.GetString(13),
                    JsonSerializer.Deserialize<IReadOnlyCollection<string>>(reader.GetFieldValue<string>(14)) ?? Array.Empty<string>(),
                    JsonSerializer.Deserialize<IReadOnlyDictionary<string,string>>(reader.GetFieldValue<string>(15)) ?? new Dictionary<string,string>(),
                    reader.GetFieldValue<DateTimeOffset>(16));
                products[id] = item;
            }
            if (!reader.IsDBNull(17))
                item.Variants.Add(new ProductVariant(reader.GetString(17), reader.GetDecimal(18), reader.GetString(19), reader.GetString(20), reader.GetDecimal(21), reader.GetInt32(22), reader.GetDecimal(23)));
        }
        return products.Values.Select(item => item.ToProduct()).ToArray();
    }

    public async Task InsertAsync(Product product, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await InsertProductRowAsync(connection, transaction, product, cancellationToken);
        foreach (var variant in product.Variants)
        {
            await InsertVariantAsync(connection, transaction, product.Id, variant, cancellationToken);
            await ledger.RecordAsync(connection, transaction, variant.Sku, variant.AvailablePackages, "InitialStock", variant.AvailablePackages, null, "system", "catalog-initial-stock", cancellationToken);
        }
        await transaction.CommitAsync(cancellationToken);
    }

    public async Task UpdateAsync(Product product, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        const string productSql = """
            update products set title=@title,category=@category,origin=@origin,currency=@currency,unit_type=@unit_type,
              short_description=@short_description,description=@description,seo_title=@seo_title,seo_description=@seo_description,
              seo_keywords=@seo_keywords,primary_image=@primary_image,gallery_images=@gallery_images,specifications=@specifications
            where id=@id;
            """;
        await using (var command = new NpgsqlCommand(productSql, connection, transaction))
        {
            AddProductParameters(command, product);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        foreach (var variant in product.Variants)
        {
            const string updateVariant = """
                update product_variants set quantity=@quantity,base_unit=@base_unit,display_label=@display_label,price=@price,cost_price=@cost_price
                where product_id=@product_id and sku=@sku;
                """;
            await using var command = new NpgsqlCommand(updateVariant, connection, transaction);
            command.Parameters.AddWithValue("product_id", product.Id);
            command.Parameters.AddWithValue("sku", variant.Sku);
            command.Parameters.AddWithValue("quantity", variant.Quantity);
            command.Parameters.AddWithValue("base_unit", variant.BaseUnit);
            command.Parameters.AddWithValue("display_label", variant.DisplayLabel);
            command.Parameters.AddWithValue("price", variant.Price);
            command.Parameters.AddWithValue("cost_price", variant.CostPrice);
            if (await command.ExecuteNonQueryAsync(cancellationToken) == 0)
            {
                await InsertVariantAsync(connection, transaction, product.Id, variant, cancellationToken);
                await ledger.RecordAsync(connection, transaction, variant.Sku, variant.AvailablePackages, "InitialStock", variant.AvailablePackages, null, "system", "catalog-variant-added", cancellationToken);
            }
        }
        await transaction.CommitAsync(cancellationToken);
    }

    public async Task SetPublicationAsync(Guid productId, bool isPublished, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("update products set is_published=@published where id=@id", connection);
        command.Parameters.AddWithValue("id", productId);
        command.Parameters.AddWithValue("published", isPublished);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<bool> CanConnectAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return false;
        try
        {
            await using var connection = new NpgsqlConnection(_connectionString);
            await connection.OpenAsync(cancellationToken);
            return true;
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "Catalog database health check failed.");
            return false;
        }
    }

    private static async Task InsertProductRowAsync(NpgsqlConnection connection, NpgsqlTransaction transaction, Product product, CancellationToken cancellationToken)
    {
        const string sql = """
            insert into products (id,title,slug,category,origin,currency,unit_type,is_published,created_at,short_description,description,seo_title,seo_description,seo_keywords,primary_image,gallery_images,specifications)
            values (@id,@title,@slug,@category,@origin,@currency,@unit_type,@is_published,@created_at,@short_description,@description,@seo_title,@seo_description,@seo_keywords,@primary_image,@gallery_images,@specifications);
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        AddProductParameters(command, product);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task InsertVariantAsync(NpgsqlConnection connection, NpgsqlTransaction transaction, Guid productId, ProductVariant variant, CancellationToken cancellationToken)
    {
        const string sql = "insert into product_variants (id,product_id,sku,quantity,base_unit,display_label,price,available_packages,cost_price) values (@id,@product_id,@sku,@quantity,@base_unit,@display_label,@price,@available_packages,@cost_price);";
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("id", Guid.NewGuid());
        command.Parameters.AddWithValue("product_id", productId);
        command.Parameters.AddWithValue("sku", variant.Sku);
        command.Parameters.AddWithValue("quantity", variant.Quantity);
        command.Parameters.AddWithValue("base_unit", variant.BaseUnit);
        command.Parameters.AddWithValue("display_label", variant.DisplayLabel);
        command.Parameters.AddWithValue("price", variant.Price);
        command.Parameters.AddWithValue("available_packages", variant.AvailablePackages);
        command.Parameters.AddWithValue("cost_price", variant.CostPrice);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static void AddProductParameters(NpgsqlCommand command, Product product)
    {
        command.Parameters.AddWithValue("id", product.Id);
        command.Parameters.AddWithValue("title", product.Title);
        command.Parameters.AddWithValue("slug", product.Slug);
        command.Parameters.AddWithValue("category", product.Category);
        command.Parameters.AddWithValue("origin", product.Origin);
        command.Parameters.AddWithValue("currency", product.Currency);
        command.Parameters.AddWithValue("unit_type", product.UnitType.ToString());
        command.Parameters.AddWithValue("is_published", product.IsPublished);
        command.Parameters.AddWithValue("created_at", product.CreatedAt);
        command.Parameters.AddWithValue("short_description", product.ShortDescription);
        command.Parameters.AddWithValue("description", product.Description);
        command.Parameters.AddWithValue("seo_title", product.SeoTitle);
        command.Parameters.AddWithValue("seo_description", product.SeoDescription);
        command.Parameters.AddWithValue("seo_keywords", product.SeoKeywords);
        command.Parameters.AddWithValue("primary_image", product.PrimaryImage);
        command.Parameters.AddWithValue("gallery_images", NpgsqlDbType.Jsonb, JsonSerializer.Serialize(product.GalleryImages ?? Array.Empty<string>()));
        command.Parameters.AddWithValue("specifications", NpgsqlDbType.Jsonb, JsonSerializer.Serialize(product.Specifications ?? new Dictionary<string,string>()));
    }

    private sealed record ProductAccumulator(
        Guid Id,string Title,string Slug,string Category,string Origin,string Currency,ProductUnitType UnitType,bool IsPublished,
        string ShortDescription,string Description,string SeoTitle,string SeoDescription,string SeoKeywords,string PrimaryImage,
        IReadOnlyCollection<string> GalleryImages,IReadOnlyDictionary<string,string> Specifications,DateTimeOffset CreatedAt)
    {
        public List<ProductVariant> Variants { get; } = [];
        public Product ToProduct() => new(Id,Title,Slug,Category,Origin,Currency,UnitType,IsPublished,Variants.ToArray(),CreatedAt,ShortDescription,Description,SeoTitle,SeoDescription,SeoKeywords,PrimaryImage,GalleryImages,Specifications);
    }

    private static IReadOnlyCollection<Category> DefaultCategories() =>
    [
        new(Guid.NewGuid(), "پسته و مغزیجات", "nuts", "مغزیجات و خشکبار منتخب", "پسته و مغزیجات مزه‌دونه", "خرید پسته و مغزیجات باکیفیت", 10, true, DateTimeOffset.UtcNow),
        new(Guid.NewGuid(), "تخمه و تنقلات", "seeds-snacks", "تخمه و تنقلات سالم", "تخمه و تنقلات سالم مزه‌دونه", "خرید تخمه و تنقلات تازه", 20, true, DateTimeOffset.UtcNow),
        new(Guid.NewGuid(), "کوکی و کیک سالم", "healthy-bakery", "کوکی و خوراکی‌های سالم", "کوکی و کیک سالم مزه‌دونه", "خرید کوکی و خوراکی سالم", 30, true, DateTimeOffset.UtcNow)
    ];
}
