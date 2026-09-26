using Npgsql;

public sealed class CatalogDatabase(IConfiguration configuration, ILogger<CatalogDatabase> logger)
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
            create index if not exists ix_products_published_category on products(is_published, category, title);
            create index if not exists ix_product_variants_product_id on product_variants(product_id);
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync(cancellationToken);
        logger.LogInformation("Catalog PostgreSQL schema is ready.");
    }

    public async Task<IReadOnlyCollection<Product>> LoadAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<Product>();
        const string sql = """
            select p.id, p.title, p.slug, p.category, p.origin, p.currency,
                   p.unit_type, p.is_published, p.created_at,
                   v.sku, v.quantity, v.base_unit, v.display_label, v.price, v.available_packages
            from products p left join product_variants v on v.product_id = p.id
            order by p.category, p.title, v.quantity;
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
                item = new ProductAccumulator(id, reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetString(5), Enum.Parse<ProductUnitType>(reader.GetString(6)), reader.GetBoolean(7), reader.GetFieldValue<DateTimeOffset>(8));
                products[id] = item;
            }
            if (!reader.IsDBNull(9))
                item.Variants.Add(new ProductVariant(reader.GetString(9), reader.GetDecimal(10), reader.GetString(11), reader.GetString(12), reader.GetDecimal(13), reader.GetInt32(14)));
        }
        return products.Values.Select(item => item.ToProduct()).ToArray();
    }

    public async Task InsertAsync(Product product, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        const string productSql = "insert into products (id,title,slug,category,origin,currency,unit_type,is_published,created_at) values (@id,@title,@slug,@category,@origin,@currency,@unit_type,@is_published,@created_at);";
        await using (var command = new NpgsqlCommand(productSql, connection, transaction))
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
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
        const string variantSql = "insert into product_variants (id,product_id,sku,quantity,base_unit,display_label,price,available_packages) values (@id,@product_id,@sku,@quantity,@base_unit,@display_label,@price,@available_packages);";
        foreach (var variant in product.Variants)
        {
            await using var command = new NpgsqlCommand(variantSql, connection, transaction);
            command.Parameters.AddWithValue("id", Guid.NewGuid());
            command.Parameters.AddWithValue("product_id", product.Id);
            command.Parameters.AddWithValue("sku", variant.Sku);
            command.Parameters.AddWithValue("quantity", variant.Quantity);
            command.Parameters.AddWithValue("base_unit", variant.BaseUnit);
            command.Parameters.AddWithValue("display_label", variant.DisplayLabel);
            command.Parameters.AddWithValue("price", variant.Price);
            command.Parameters.AddWithValue("available_packages", variant.AvailablePackages);
            await command.ExecuteNonQueryAsync(cancellationToken);
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

    private sealed record ProductAccumulator(Guid Id,string Title,string Slug,string Category,string Origin,string Currency,ProductUnitType UnitType,bool IsPublished,DateTimeOffset CreatedAt)
    {
        public List<ProductVariant> Variants { get; } = [];
        public Product ToProduct() => new(Id,Title,Slug,Category,Origin,Currency,UnitType,IsPublished,Variants.ToArray(),CreatedAt);
    }
}
