using System.Text.Json;
using Npgsql;
using NpgsqlTypes;

public sealed class CatalogDatabase(
    IConfiguration configuration,
    ILogger<CatalogDatabase> logger,
    InventoryLedgerDatabase ledger,
    AdminAuditLogDatabase audit)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    private readonly List<Category> _fallbackCategories = DefaultCategories().ToList();
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task ApplyMigrationsAsync(CancellationToken cancellationToken)
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
        await DatabaseMigrationRunner.ApplyAsync(connection, "catalog", "001-bootstrap", sql, cancellationToken);
        const string nutritionCostingSql = """
            alter table products add column if not exists ingredients text not null default '';
            alter table products add column if not exists allergens jsonb not null default '[]'::jsonb;
            alter table products add column if not exists nutrition_facts jsonb not null default '{}'::jsonb;
            alter table products add column if not exists storage_instructions text not null default '';
            alter table products add column if not exists shelf_life_days integer;
            alter table products add column if not exists net_weight numeric(12,3);
            alter table products add column if not exists net_weight_unit varchar(16) not null default 'gram';
            alter table products add column if not exists expiry_label varchar(32) not null default 'best-before';
            alter table product_variants add column if not exists packaging_cost numeric(18,2) not null default 0;
            alter table product_variants add column if not exists additional_cost numeric(18,2) not null default 0;
            """;
        await DatabaseMigrationRunner.ApplyAsync(connection, "catalog", "002-nutrition-costing", nutritionCostingSql, cancellationToken);
        logger.LogInformation("Catalog PostgreSQL schema is ready.");
    }

    public async Task<IReadOnlyCollection<Category>> LoadCategoriesAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return _fallbackCategories.OrderBy(item => item.SortOrder).ThenBy(item => item.Name).ToArray();
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

    public async Task<Category> InsertCategoryAsync(CreateCategoryRequest request, string actor, string requestId, CancellationToken cancellationToken)
    {
        if (!IsConfigured)
        {
            var fallback = new Category(Guid.NewGuid(), request.Name.Trim(), request.Slug.Trim().ToLowerInvariant(), request.Description?.Trim() ?? "", request.SeoTitle?.Trim() ?? request.Name.Trim(), request.SeoDescription?.Trim() ?? "", request.SortOrder, request.IsActive, DateTimeOffset.UtcNow);
            _fallbackCategories.Add(fallback);
            return fallback;
        }
        const string sql = """
            insert into categories (id,name,slug,description,seo_title,seo_description,sort_order,is_active,created_at)
            values (@id,@name,@slug,@description,@seo_title,@seo_description,@sort_order,@is_active,@created_at)
            returning id,name,slug,description,seo_title,seo_description,sort_order,is_active,created_at;
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection, transaction);
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
        Category inserted;
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            await reader.ReadAsync(cancellationToken);
            inserted = new Category(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetString(5), reader.GetInt32(6), reader.GetBoolean(7), reader.GetFieldValue<DateTimeOffset>(8));
        }
        await audit.RecordAsync(connection, transaction, actor, "category.created", "Category", inserted.Id.ToString(),
            null, inserted, "ایجاد دسته‌بندی", requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return inserted;
    }

    public async Task<Category?> UpdateCategoryAsync(string slug, UpdateCategoryRequest request, string actor, string requestId, CancellationToken cancellationToken)
    {
        var normalizedSlug = slug.Trim().ToLowerInvariant();
        var name = request.Name.Trim();
        var newSlug = request.Slug.Trim().ToLowerInvariant();
        var description = request.Description?.Trim() ?? "";
        var seoTitle = request.SeoTitle?.Trim() ?? name;
        var seoDescription = request.SeoDescription?.Trim() ?? "";
        if (!IsConfigured)
        {
            var index = _fallbackCategories.FindIndex(item => item.Slug.Equals(normalizedSlug, StringComparison.OrdinalIgnoreCase));
            if (index < 0) return null;
            var fallbackUpdated = _fallbackCategories[index] with { Name = name, Slug = newSlug, Description = description, SeoTitle = seoTitle, SeoDescription = seoDescription, SortOrder = request.SortOrder, IsActive = request.IsActive };
            _fallbackCategories[index] = fallbackUpdated;
            return fallbackUpdated;
        }

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        Category? before;
        await using (var find = new NpgsqlCommand("select id,name,slug,description,seo_title,seo_description,sort_order,is_active,created_at from categories where slug=@slug for update;", connection, transaction))
        {
            find.Parameters.AddWithValue("slug", normalizedSlug);
            await using var reader = await find.ExecuteReaderAsync(cancellationToken);
            before = await reader.ReadAsync(cancellationToken)
                ? new Category(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetString(5), reader.GetInt32(6), reader.GetBoolean(7), reader.GetFieldValue<DateTimeOffset>(8))
                : null;
        }
        if (before is null) return null;
        await using (var productCommand = new NpgsqlCommand("update products set category=@new_name where category=@old_name", connection, transaction))
        {
            productCommand.Parameters.AddWithValue("new_name", name); productCommand.Parameters.AddWithValue("old_name", before.Name);
            await productCommand.ExecuteNonQueryAsync(cancellationToken);
        }
        const string sql = "update categories set name=@name,slug=@new_slug,description=@description,seo_title=@seo_title,seo_description=@seo_description,sort_order=@sort_order,is_active=@is_active where slug=@slug returning id,created_at;";
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("name", name); command.Parameters.AddWithValue("new_slug", newSlug); command.Parameters.AddWithValue("description", description);
        command.Parameters.AddWithValue("seo_title", seoTitle); command.Parameters.AddWithValue("seo_description", seoDescription); command.Parameters.AddWithValue("sort_order", request.SortOrder);
        command.Parameters.AddWithValue("is_active", request.IsActive); command.Parameters.AddWithValue("slug", normalizedSlug);
        Guid id;
        DateTimeOffset createdAt;
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            if (!await reader.ReadAsync(cancellationToken)) return null;
            id = reader.GetGuid(0);
            createdAt = reader.GetFieldValue<DateTimeOffset>(1);
        }
        var updated = new Category(id, name, newSlug, description, seoTitle, seoDescription, request.SortOrder, request.IsActive, createdAt);
        await audit.RecordAsync(connection, transaction, actor, "category.updated", "Category", id.ToString(),
            before, updated, "به‌روزرسانی دسته‌بندی", requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return updated;
    }

    public async Task<Category?> SetCategoryActiveAsync(string slug, bool isActive, string actor, string requestId, CancellationToken cancellationToken)
    {
        var current = (await LoadCategoriesAsync(cancellationToken)).FirstOrDefault(item => item.Slug.Equals(slug.Trim(), StringComparison.OrdinalIgnoreCase));
        if (current is null) return null;
        return await UpdateCategoryAsync(current.Slug, new UpdateCategoryRequest(current.Name, current.Slug, current.Description, current.SeoTitle, current.SeoDescription, current.SortOrder, isActive), actor, requestId, cancellationToken);
    }

    public async Task<int> CountProductsInCategoryAsync(string categoryName, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return 0;
        await using var connection = new NpgsqlConnection(_connectionString); await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand("select count(*) from products where category=@category", connection);
        command.Parameters.AddWithValue("category", categoryName);
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
    }

    public async Task<(bool Deleted, int ProductCount)> DeleteCategoryAsync(string slug, string actor, string requestId, CancellationToken cancellationToken)
    {
        var normalizedSlug = slug.Trim().ToLowerInvariant();
        if (!IsConfigured)
        {
            var current = _fallbackCategories.FirstOrDefault(item => item.Slug.Equals(normalizedSlug, StringComparison.OrdinalIgnoreCase));
            if (current is null) return (false, -1);
            _fallbackCategories.RemoveAll(item => item.Id == current.Id);
            return (true, 0);
        }

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        Category? before;
        await using (var find = new NpgsqlCommand("select id,name,slug,description,seo_title,seo_description,sort_order,is_active,created_at from categories where slug=@slug for update;", connection, transaction))
        {
            find.Parameters.AddWithValue("slug", normalizedSlug);
            await using var reader = await find.ExecuteReaderAsync(cancellationToken);
            before = await reader.ReadAsync(cancellationToken)
                ? new Category(reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetString(5), reader.GetInt32(6), reader.GetBoolean(7), reader.GetFieldValue<DateTimeOffset>(8))
                : null;
        }
        if (before is null) return (false, -1);

        int productCount;
        await using (var count = new NpgsqlCommand("select count(*) from products where category=@category;", connection, transaction))
        {
            count.Parameters.AddWithValue("category", before.Name);
            productCount = Convert.ToInt32(await count.ExecuteScalarAsync(cancellationToken));
        }
        if (productCount > 0) return (false, productCount);

        await using (var delete = new NpgsqlCommand("delete from categories where id=@id;", connection, transaction))
        {
            delete.Parameters.AddWithValue("id", before.Id);
            await delete.ExecuteNonQueryAsync(cancellationToken);
        }
        await audit.RecordAsync(connection, transaction, actor, "category.deleted", "Category", before.Id.ToString(),
            before, null, "حذف دسته‌بندی", requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return (true, 0);
    }

    public async Task<IReadOnlyCollection<Product>> LoadAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<Product>();
        const string sql = """
            select p.id,p.title,p.slug,p.category,p.origin,p.currency,p.unit_type,p.is_published,
                   p.short_description,p.description,p.seo_title,p.seo_description,p.seo_keywords,p.primary_image,
                   p.gallery_images,p.specifications,p.created_at,
                   p.ingredients,p.allergens,p.nutrition_facts,p.storage_instructions,p.shelf_life_days,
                   p.net_weight,p.net_weight_unit,p.expiry_label,
                   v.sku,v.quantity,v.base_unit,v.display_label,v.price,v.available_packages,v.cost_price,
                   v.packaging_cost,v.additional_cost
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
                    reader.GetFieldValue<DateTimeOffset>(16),
                    reader.GetString(17),
                    JsonSerializer.Deserialize<IReadOnlyCollection<string>>(reader.GetFieldValue<string>(18)) ?? Array.Empty<string>(),
                    JsonSerializer.Deserialize<IReadOnlyDictionary<string,decimal>>(reader.GetFieldValue<string>(19)) ?? new Dictionary<string,decimal>(),
                    reader.GetString(20),
                    reader.IsDBNull(21) ? null : reader.GetInt32(21),
                    reader.IsDBNull(22) ? null : reader.GetDecimal(22),
                    reader.GetString(23),
                    reader.GetString(24));
                products[id] = item;
            }
            if (!reader.IsDBNull(25))
            {
                var variant = new ProductVariant(reader.GetString(25), reader.GetDecimal(26), reader.GetString(27), reader.GetString(28), reader.GetDecimal(29), reader.GetInt32(30), reader.GetDecimal(31))
                {
                    PackagingCost = reader.GetDecimal(32),
                    AdditionalCost = reader.GetDecimal(33)
                };
                item.Variants.Add(variant);
            }
        }
        return products.Values.Select(item => item.ToProduct()).ToArray();
    }

    public async Task InsertAsync(Product product, string actor, string requestId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await InsertProductRowAsync(connection, transaction, product, cancellationToken);
        foreach (var variant in product.Variants)
        {
            await InsertVariantAsync(connection, transaction, product.Id, variant, cancellationToken);
            await RecordInitialStockAsync(connection, transaction, variant, "catalog-initial-stock", cancellationToken);
            await audit.RecordAsync(connection, transaction, actor, "product.variant-added", "ProductVariant",
                variant.Sku, null, new { variant.Sku, variant.Price, product.Currency },
                "ثبت گونهٔ اولیهٔ محصول با قیمت", requestId, cancellationToken);
        }
        await audit.RecordAsync(connection, transaction, actor, "product.created", "Product", product.Id.ToString(),
            null, ProductAuditSnapshot(product), "ایجاد محصول", requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
    }

    public async Task<bool> SeedDemoCatalogIfEmptyAsync(
        IReadOnlyCollection<Product> demoProducts,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured) throw new InvalidOperationException("ConnectionStrings:Catalog must be configured before seeding demo products.");

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using (var lockCommand = new NpgsqlCommand(
            "select pg_advisory_xact_lock(hashtextextended('mazeduneh.demo-catalog-seed', 0));",
            connection, transaction))
            await lockCommand.ExecuteNonQueryAsync(cancellationToken);

        await using (var countCommand = new NpgsqlCommand("select count(*) from products;", connection, transaction))
        {
            if (Convert.ToInt64(await countCommand.ExecuteScalarAsync(cancellationToken)) > 0)
            {
                await transaction.CommitAsync(cancellationToken);
                return false;
            }
        }

        foreach (var product in demoProducts)
        {
            await InsertProductRowAsync(connection, transaction, product, cancellationToken);
            foreach (var variant in product.Variants)
            {
                await InsertVariantAsync(connection, transaction, product.Id, variant, cancellationToken);
                await RecordInitialStockAsync(connection, transaction, variant, "catalog-demo-seed", cancellationToken);
            }
        }

        await transaction.CommitAsync(cancellationToken);
        return true;
    }

    public async Task<Product> UpdateAsync(
        Product product,
        Product before,
        bool canWriteCosts,
        string actor,
        string requestId,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured) return product;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        const string productSql = """
            update products set title=@title,category=@category,origin=@origin,currency=@currency,unit_type=@unit_type,
              short_description=@short_description,description=@description,seo_title=@seo_title,seo_description=@seo_description,
              seo_keywords=@seo_keywords,primary_image=@primary_image,gallery_images=@gallery_images,specifications=@specifications,
              ingredients=@ingredients,allergens=@allergens,nutrition_facts=@nutrition_facts,storage_instructions=@storage_instructions,
              shelf_life_days=@shelf_life_days,net_weight=@net_weight,net_weight_unit=@net_weight_unit,expiry_label=@expiry_label
            where id=@id;
            """;
        await using (var command = new NpgsqlCommand(productSql, connection, transaction))
        {
            AddProductParameters(command, product);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        foreach (var variant in product.Variants)
        {
            await using var command = new NpgsqlCommand(
                "select exists(select 1 from product_variants where product_id=@product_id and sku=@sku)",
                connection,
                transaction);
            command.Parameters.AddWithValue("product_id", product.Id);
            command.Parameters.AddWithValue("sku", variant.Sku);
            var variantExists = (bool)(await command.ExecuteScalarAsync(cancellationToken) ?? false);
            var previous = before.Variants.FirstOrDefault(v => v.Sku.Equals(variant.Sku, StringComparison.OrdinalIgnoreCase));
            if (variantExists && previous is null)
                throw new CatalogPriceConflictException();
            if (variantExists && previous is not null && previous.Price != variant.Price)
            {
                // Content-only edits must not restore a stale cached selling price.
                // A deliberate price edit uses compare-and-swap and keeps batch costs,
                // reservations, stock and historical order snapshots unchanged.
                await using var priceCommand = new NpgsqlCommand("""
                    update product_variants set price=@price
                    where product_id=@product_id and sku=@sku and price=@previous;
                    """, connection, transaction);
                priceCommand.Parameters.AddWithValue("product_id", product.Id);
                priceCommand.Parameters.AddWithValue("sku", variant.Sku);
                priceCommand.Parameters.AddWithValue("price", variant.Price);
                priceCommand.Parameters.AddWithValue("previous", previous.Price);
                if (await priceCommand.ExecuteNonQueryAsync(cancellationToken) != 1)
                    throw new CatalogPriceConflictException();
                await audit.RecordAsync(connection, transaction, actor, "product.selling-price-updated", "ProductVariant",
                    variant.Sku, new { Price = previous.Price }, new { variant.Price, product.Currency },
                    "اصلاح مستقیم قیمت فروش بسته از فرم محصول", requestId, cancellationToken);
            }
            if (!variantExists)
            {
                await InsertVariantAsync(connection, transaction, product.Id, variant, cancellationToken);
                await RecordInitialStockAsync(connection, transaction, variant, "catalog-variant-added", cancellationToken);
                await audit.RecordAsync(connection, transaction, actor, "product.variant-added", "ProductVariant",
                    variant.Sku, null, new { variant.Sku, variant.Price, product.Currency },
                    "ثبت گونهٔ تازه با قیمت اولیه", requestId, cancellationToken);
            }
        }
        await audit.RecordAsync(connection, transaction, actor, "product.updated", "Product", product.Id.ToString(),
            ProductAuditSnapshot(before), ProductAuditSnapshot(product), "ویرایش اطلاعات محصول", requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return (await LoadAsync(cancellationToken)).Single(item => item.Id == product.Id);
    }

    public async Task SetPublicationAsync(Guid productId, bool wasPublished, bool isPublished, string actor, string requestId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await using (var command = new NpgsqlCommand("update products set is_published=@published where id=@id", connection, transaction))
        {
            command.Parameters.AddWithValue("id", productId);
            command.Parameters.AddWithValue("published", isPublished);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        await audit.RecordAsync(connection, transaction, actor, "product.publication", "Product", productId.ToString(),
            new { IsPublished = wasPublished }, new { IsPublished = isPublished },
            isPublished ? "انتشار محصول" : "خارج کردن محصول از انتشار", requestId, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
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

    private Task RecordInitialStockAsync(
        NpgsqlConnection connection, NpgsqlTransaction transaction, ProductVariant variant,
        string reason, CancellationToken cancellationToken) =>
        // A zero opening balance is valid catalog data, not a stock movement.
        variant.AvailablePackages == 0 ? Task.CompletedTask :
            ledger.RecordAsync(connection, transaction, variant.Sku, variant.AvailablePackages,
                "InitialStock", variant.AvailablePackages, null, "system", reason, cancellationToken);

    private static async Task InsertProductRowAsync(NpgsqlConnection connection, NpgsqlTransaction transaction, Product product, CancellationToken cancellationToken)
    {
        const string sql = """
            insert into products (id,title,slug,category,origin,currency,unit_type,is_published,created_at,short_description,description,seo_title,seo_description,seo_keywords,primary_image,gallery_images,specifications,ingredients,allergens,nutrition_facts,storage_instructions,shelf_life_days,net_weight,net_weight_unit,expiry_label)
            values (@id,@title,@slug,@category,@origin,@currency,@unit_type,@is_published,@created_at,@short_description,@description,@seo_title,@seo_description,@seo_keywords,@primary_image,@gallery_images,@specifications,@ingredients,@allergens,@nutrition_facts,@storage_instructions,@shelf_life_days,@net_weight,@net_weight_unit,@expiry_label);
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        AddProductParameters(command, product);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static object ProductAuditSnapshot(Product product) => new
    {
        product.Id,
        product.Title,
        product.Slug,
        product.Category,
        product.Origin,
        product.Currency,
        product.UnitType,
        product.IsPublished,
        product.ShortDescription,
        product.Description,
        product.SeoTitle,
        product.SeoDescription,
        product.SeoKeywords,
        product.PrimaryImage,
        product.GalleryImages,
        product.Specifications,
        product.Ingredients,
        product.Allergens,
        product.NutritionFacts,
        product.StorageInstructions,
        product.ShelfLifeDays,
        product.NetWeight,
        product.NetWeightUnit,
        product.ExpiryLabel,
        Variants = product.Variants.Select(variant => new
        {
            variant.Sku,
            variant.Quantity,
            variant.BaseUnit,
            variant.DisplayLabel
        }).ToArray()
    };

    private static async Task InsertVariantAsync(NpgsqlConnection connection, NpgsqlTransaction transaction, Guid productId, ProductVariant variant, CancellationToken cancellationToken)
    {
        const string sql = "insert into product_variants (id,product_id,sku,quantity,base_unit,display_label,price,available_packages,cost_price,packaging_cost,additional_cost) values (@id,@product_id,@sku,@quantity,@base_unit,@display_label,@price,@available_packages,@cost_price,@packaging_cost,@additional_cost);";
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
        command.Parameters.AddWithValue("packaging_cost", variant.PackagingCost);
        command.Parameters.AddWithValue("additional_cost", variant.AdditionalCost);
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
        command.Parameters.AddWithValue("ingredients", product.Ingredients);
        command.Parameters.AddWithValue("allergens", NpgsqlDbType.Jsonb, JsonSerializer.Serialize(product.Allergens));
        command.Parameters.AddWithValue("nutrition_facts", NpgsqlDbType.Jsonb, JsonSerializer.Serialize(product.NutritionFacts));
        command.Parameters.AddWithValue("storage_instructions", product.StorageInstructions);
        command.Parameters.AddWithValue("shelf_life_days", (object?)product.ShelfLifeDays ?? DBNull.Value);
        command.Parameters.AddWithValue("net_weight", (object?)product.NetWeight ?? DBNull.Value);
        command.Parameters.AddWithValue("net_weight_unit", product.NetWeightUnit);
        command.Parameters.AddWithValue("expiry_label", product.ExpiryLabel);
    }

    private sealed record ProductAccumulator(
        Guid Id,string Title,string Slug,string Category,string Origin,string Currency,ProductUnitType UnitType,bool IsPublished,
        string ShortDescription,string Description,string SeoTitle,string SeoDescription,string SeoKeywords,string PrimaryImage,
        IReadOnlyCollection<string> GalleryImages,IReadOnlyDictionary<string,string> Specifications,DateTimeOffset CreatedAt,
        string Ingredients,IReadOnlyCollection<string> Allergens,IReadOnlyDictionary<string,decimal> NutritionFacts,
        string StorageInstructions,int? ShelfLifeDays,decimal? NetWeight,string NetWeightUnit,string ExpiryLabel)
    {
        public List<ProductVariant> Variants { get; } = [];
        public Product ToProduct() => new(Id,Title,Slug,Category,Origin,Currency,UnitType,IsPublished,Variants.ToArray(),CreatedAt,ShortDescription,Description,SeoTitle,SeoDescription,SeoKeywords,PrimaryImage,GalleryImages,Specifications)
        {
            Ingredients = Ingredients,
            Allergens = Allergens,
            NutritionFacts = NutritionFacts,
            StorageInstructions = StorageInstructions,
            ShelfLifeDays = ShelfLifeDays,
            NetWeight = NetWeight,
            NetWeightUnit = NetWeightUnit,
            ExpiryLabel = ExpiryLabel
        };
    }

    private static IReadOnlyCollection<Category> DefaultCategories() =>
    [
        new(Guid.NewGuid(), "پسته و مغزیجات", "nuts", "مغزیجات و خشکبار منتخب", "پسته و مغزیجات مزه‌دونه", "خرید پسته و مغزیجات باکیفیت", 10, true, DateTimeOffset.UtcNow),
        new(Guid.NewGuid(), "تخمه و تنقلات", "seeds-snacks", "تخمه و تنقلات سالم", "تخمه و تنقلات سالم مزه‌دونه", "خرید تخمه و تنقلات تازه", 20, true, DateTimeOffset.UtcNow),
        new(Guid.NewGuid(), "کوکی و کیک سالم", "healthy-bakery", "کوکی و خوراکی‌های سالم", "کوکی و کیک سالم مزه‌دونه", "خرید کوکی و خوراکی سالم", 30, true, DateTimeOffset.UtcNow)
    ];
}


public sealed class CatalogPriceConflictException() : Exception("قیمت این بسته هم‌زمان تغییر کرده است؛ محصول را تازه‌سازی کنید و دوباره قیمت را ثبت کنید.");
