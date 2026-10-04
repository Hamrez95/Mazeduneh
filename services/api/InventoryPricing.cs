using System.Text.Json;
using Npgsql;
using NpgsqlTypes;

public sealed record InventoryPriceRecipe(Guid BatchId, decimal PackagingCost, decimal PackagingMultiplier = 1,
    decimal PackagingPercent = 0, decimal AdditionalCost = 0, decimal AdditionalPercent = 0,
    decimal MarkupPercent = 0, decimal RoundingStep = 10)
{
    public Dictionary<string, string[]> Validate()
    {
        var errors = new Dictionary<string, string[]>();
        if (BatchId == Guid.Empty) errors[nameof(BatchId)] = ["یک خرید ثبت‌شده انتخاب کنید."];
        if (PackagingCost is < 0 or > 1_000_000_000_000m) errors[nameof(PackagingCost)] = ["مبلغ بسته‌بندی معتبر وارد کنید."];
        if (AdditionalCost is < 0 or > 1_000_000_000_000m) errors[nameof(AdditionalCost)] = ["هزینه جانبی معتبر وارد کنید."];
        if (PackagingMultiplier is < 0 or > 100) errors[nameof(PackagingMultiplier)] = ["ضریب بسته‌بندی بین صفر و ۱۰۰ باشد."];
        if (PackagingPercent is < 0 or > 1000) errors[nameof(PackagingPercent)] = ["درصد بسته‌بندی بین صفر و ۱۰۰۰ باشد."];
        if (AdditionalPercent is < 0 or > 1000) errors[nameof(AdditionalPercent)] = ["درصد جانبی بین صفر و ۱۰۰۰ باشد."];
        if (MarkupPercent is < 0 or > 1000) errors[nameof(MarkupPercent)] = ["درصد سود بین صفر و ۱۰۰۰ باشد."];
        if (RoundingStep is < 1 or > 1_000_000_000m) errors[nameof(RoundingStep)] = ["گام گردکردن مثبت و حداکثر ۱ میلیارد ریال باشد."];
        return errors;
    }
}
public sealed record InventoryPriceApply(InventoryPriceRecipe? Recipe, decimal? ExpectedPrice);
public sealed record InventoryPriceQuote(decimal PurchaseCost, decimal PackagingCost, decimal AdditionalCost,
    decimal TotalCost, decimal SellingPrice, decimal Profit, decimal MarginPercent);
public static class InventoryPriceCalculator
{
    public static InventoryPriceQuote Calculate(decimal purchaseCost, InventoryPriceRecipe recipe)
    {
        if (recipe.Validate().Count > 0 || purchaseCost is < 0 or > 1_000_000_000_000m) throw new ArgumentException("Invalid costing inputs");
        static decimal Money(decimal value) => Math.Round(value, 2, MidpointRounding.AwayFromZero);
        var packaging = Money(recipe.PackagingCost * recipe.PackagingMultiplier + purchaseCost * recipe.PackagingPercent / 100m);
        var additional = Money(recipe.AdditionalCost + purchaseCost * recipe.AdditionalPercent / 100m);
        var total = Money(purchaseCost + packaging + additional);
        var price = Money(Math.Ceiling(total * (1 + recipe.MarkupPercent / 100m) / recipe.RoundingStep) * recipe.RoundingStep);
        return new(purchaseCost, packaging, additional, total, price, price - total,
            price == 0 ? 0 : Money((price - total) / price * 100m));
    }
}

public sealed class InventoryPricingDatabase(IConfiguration configuration, AdminAuditLogDatabase audit)
{
    private readonly string? connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(connectionString);
    public async Task InitializeAsync(CancellationToken ct)
    {
        if (!IsConfigured) return;
        await using var connection = new NpgsqlConnection(connectionString); await connection.OpenAsync(ct);
        await DatabaseMigrationRunner.ApplyAsync(connection, "inventory", "004-pricing-rules", """
            create table if not exists variant_pricing_rules (
                sku text primary key,
                batch_id uuid not null references inventory_batches(id),
                recipe jsonb not null,
                updated_at timestamptz not null
            );
            """, ct);
    }
    public async Task<(decimal Price, InventoryPriceRecipe? Recipe)?> StateAsync(string sku, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(connectionString); await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("""
            select v.price,r.recipe::text from product_variants v
            left join variant_pricing_rules r on r.sku=v.sku where upper(v.sku)=upper(@sku);
            """, connection);
        command.Parameters.AddWithValue("sku", sku);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) return null;
        return (reader.GetDecimal(0), reader.IsDBNull(1) ? null : JsonSerializer.Deserialize<InventoryPriceRecipe>(reader.GetString(1)));
    }
    public async Task<(InventoryPriceQuote? Quote, string? Error)> ExecuteAsync(string sku, InventoryPriceRecipe recipe,
        decimal? expectedPrice, string actor, string requestId, bool apply, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(connectionString); await connection.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);
        await using var command = new NpgsqlCommand("""
            select v.sku,v.price,v.cost_price,v.packaging_cost,v.additional_cost,b.cost_price,
                   r.recipe::text
            from product_variants v
            join inventory_batches b on b.id=@batch and upper(b.sku)=upper(v.sku)
            left join variant_pricing_rules r on r.sku=v.sku
            where upper(v.sku)=upper(@sku) for update of v;
            """, connection, transaction);
        command.Parameters.AddWithValue("sku", sku); command.Parameters.AddWithValue("batch", recipe.BatchId);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) return (null, "خرید انتخاب‌شده متعلق به این کالا نیست یا پیدا نشد.");
        var canonicalSku = reader.GetString(0); var oldPrice = reader.GetDecimal(1);
        var before = new { Price = oldPrice, CostPrice = reader.GetDecimal(2), PackagingCost = reader.GetDecimal(3),
            AdditionalCost = reader.GetDecimal(4), Recipe = reader.IsDBNull(6) ? null : JsonSerializer.Deserialize<InventoryPriceRecipe>(reader.GetString(6)) };
        var quote = InventoryPriceCalculator.Calculate(reader.GetDecimal(5), recipe);
        await reader.CloseAsync();
        if (quote.SellingPrice <= 0) return (null, "بهای تمام‌شده باید بیشتر از صفر باشد.");
        if (!apply) return (quote, null);
        if (expectedPrice != oldPrice) return (null, "قیمت کالا تغییر کرده است؛ اطلاعات را تازه کنید و دوباره پیش‌نمایش بگیرید.");
        if (before.Recipe == recipe && quote.SellingPrice == oldPrice) return (quote, null);
        await using var update = new NpgsqlCommand("""
            update product_variants set price=@price,cost_price=@cost,packaging_cost=@packaging,additional_cost=@additional where sku=@sku;
            insert into variant_pricing_rules(sku,batch_id,recipe,updated_at) values(@sku,@batch,@recipe,now())
            on conflict(sku) do update set batch_id=excluded.batch_id,recipe=excluded.recipe,updated_at=excluded.updated_at;
            """, connection, transaction);
        update.Parameters.AddWithValue("sku", canonicalSku); update.Parameters.AddWithValue("batch", recipe.BatchId);
        update.Parameters.AddWithValue("price", quote.SellingPrice); update.Parameters.AddWithValue("cost", quote.PurchaseCost);
        update.Parameters.AddWithValue("packaging", quote.PackagingCost); update.Parameters.AddWithValue("additional", quote.AdditionalCost);
        update.Parameters.Add("recipe", NpgsqlDbType.Jsonb).Value = JsonSerializer.Serialize(recipe);
        await update.ExecuteNonQueryAsync(ct);
        await audit.RecordAsync(connection, transaction, actor, "inventory.price.applied", "ProductVariant", canonicalSku,
            before, new { Recipe = recipe, Quote = quote }, "batch-cost-selling-price", requestId, ct);
        await transaction.CommitAsync(ct);
        return (quote, null);
    }
}
public static class InventoryPricingModule
{
    public static IServiceCollection AddInventoryPricing(this IServiceCollection services)
    {
        services.AddSingleton<InventoryPricingDatabase>(); services.AddHostedService<InventoryPricingInitializer>(); return services;
    }
    public static IEndpointRouteBuilder MapInventoryPricing(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/v1/admin/inventory/pricing").AddEndpointFilter<OwnerAuthorizationFilter>();
        group.MapGet("/{sku}", async (string sku, InventoryPricingDatabase database, InventoryBatchDatabase batches, CancellationToken ct) =>
        {
            if (!database.IsConfigured) return (IResult)Results.Problem("دیتابیس قیمت‌گذاری تنظیم نشده است.", statusCode: 503);
            var state = await database.StateAsync(sku, ct);
            if (state is null) return Results.NotFound(new { message = "کالا پیدا نشد." });
            var history = await batches.ListAsync(sku, true, 250, ct, purchaseOrder: true);
            return Results.Ok(new { sku, currentPrice = state.Value.Price, recipe = state.Value.Recipe,
                batches = history.OrderByDescending(b => b.PurchasedAt ?? b.CreatedAt).ThenByDescending(b => b.CreatedAt) });
        });
        group.MapPost("/{sku}/preview", async (string sku, InventoryPriceRecipe recipe, InventoryPricingDatabase database, CancellationToken ct) =>
        {
            if (!database.IsConfigured) return (IResult)Results.Problem("دیتابیس قیمت‌گذاری تنظیم نشده است.", statusCode: 503);
            var errors = recipe.Validate(); if (errors.Count > 0) return Results.ValidationProblem(errors);
            var result = await database.ExecuteAsync(sku, recipe, null, "", "", false, ct);
            return result.Quote is null ? Results.Conflict(new { message = result.Error }) : Results.Ok(result.Quote);
        });
        group.MapPost("/{sku}/apply", async (string sku, InventoryPriceApply request, InventoryPricingDatabase database, HttpContext context, CancellationToken ct) =>
        {
            var principal = (AdminPrincipal)context.Items["AdminPrincipal"]!;
            if (!AdminPermissions.Allows(principal, AdminPermissions.ProductsWrite)) return (IResult)Results.StatusCode(403);
            if (!database.IsConfigured) return Results.Problem("دیتابیس قیمت‌گذاری تنظیم نشده است.", statusCode: 503);
            if (request.Recipe is null || request.ExpectedPrice is null or < 0) return Results.ValidationProblem(new Dictionary<string, string[]> { ["request"] = ["فرمول و قیمت فعلی برای تأیید لازم است."] });
            var errors = request.Recipe.Validate(); if (errors.Count > 0) return Results.ValidationProblem(errors);
            var result = await database.ExecuteAsync(sku, request.Recipe, request.ExpectedPrice, principal.Email, context.TraceIdentifier, true, ct);
            return result.Quote is null ? Results.Conflict(new { message = result.Error }) : Results.Ok(result.Quote);
        });
        return endpoints;
    }
}
public sealed class InventoryPricingInitializer(InventoryPricingDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken ct) => database.InitializeAsync(ct);
    public Task StopAsync(CancellationToken ct) => Task.CompletedTask;
}
