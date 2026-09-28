using System.Text.Json;
using Npgsql;

public sealed record ShippingMethodDefinition(string Code, string Title, decimal Price, decimal FreeAbove = 0, bool IsActive = true);

public sealed record CommerceSettings(decimal TaxRatePercent, IReadOnlyCollection<ShippingMethodDefinition> ShippingMethods, DateTimeOffset UpdatedAt);

public sealed record CommerceSettingsRequest(decimal TaxRatePercent, IReadOnlyCollection<ShippingMethodDefinition> ShippingMethods)
{
    public Dictionary<string, string[]> Validate()
    {
        var errors = new Dictionary<string, string[]>();
        if (TaxRatePercent is < 0 or > 100) errors[nameof(TaxRatePercent)] = ["نرخ مالیات باید بین صفر تا ۱۰۰ درصد باشد."];
        if (ShippingMethods is null || ShippingMethods.Count == 0)
        {
            errors[nameof(ShippingMethods)] = ["حداقل یک روش ارسال لازم است."];
            return errors;
        }

        var duplicates = ShippingMethods
            .Where(item => string.IsNullOrWhiteSpace(item.Code))
            .ToArray();
        if (duplicates.Length > 0) errors["ShippingMethods.Code"] = ["کد روش ارسال الزامی است."];

        var repeated = ShippingMethods
            .GroupBy(item => item.Code.Trim(), StringComparer.OrdinalIgnoreCase)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .ToArray();
        if (repeated.Length > 0) errors["ShippingMethods.Code"] = ["کد روش‌های ارسال نباید تکراری باشد."];
        for (var index = 0; index < ShippingMethods.Count; index++)
        {
            var item = ShippingMethods.ElementAt(index);
            if (item.Price < 0) errors[$"ShippingMethods[{index}].Price"] = ["هزینه ارسال نمی‌تواند منفی باشد."];
            if (item.FreeAbove < 0) errors[$"ShippingMethods[{index}].FreeAbove"] = ["حداقل خرید ارسال رایگان نمی‌تواند منفی باشد."];
        }
        return errors;
    }
}

public sealed record CommerceQuote(string ShippingMethod, decimal Shipping, decimal TaxRatePercent, decimal Tax, decimal Payable);

public sealed class CommercePricingDatabase(IConfiguration configuration, ILogger<CommercePricingDatabase> logger)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    private readonly decimal _configuredTaxRate = configuration.GetValue("Commerce:TaxRatePercent", 10m);
    private readonly IReadOnlyCollection<ShippingMethodDefinition> _configuredShippingMethods = ReadConfiguredShipping(configuration);

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        const string sql = """
            create table if not exists commerce_settings (
                id integer primary key check (id = 1),
                tax_rate_percent numeric(7,4) not null check (tax_rate_percent >= 0 and tax_rate_percent <= 100),
                shipping_methods jsonb not null,
                updated_at timestamptz not null
            );
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "commerce", "001-pricing-settings", sql, cancellationToken);

        const string seedSql = """
            insert into commerce_settings (id, tax_rate_percent, shipping_methods, updated_at)
            values (@id, @tax_rate_percent, @shipping_methods::jsonb, @updated_at)
            on conflict (id) do nothing;
            """;
        await using var command = new NpgsqlCommand(seedSql, connection);
        command.Parameters.AddWithValue("id", 1);
        command.Parameters.AddWithValue("tax_rate_percent", _configuredTaxRate);
        command.Parameters.AddWithValue("shipping_methods", JsonSerializer.Serialize(_configuredShippingMethods));
        command.Parameters.AddWithValue("updated_at", DateTimeOffset.UtcNow);
        await command.ExecuteNonQueryAsync(cancellationToken);
        logger.LogInformation("Commerce pricing settings are ready.");
    }

    public async Task<CommerceSettings> GetAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new CommerceSettings(_configuredTaxRate, _configuredShippingMethods, DateTimeOffset.UtcNow);

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        const string sql = "select tax_rate_percent, shipping_methods, updated_at from commerce_settings where id=1;";
        await using var command = new NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
            return new CommerceSettings(_configuredTaxRate, _configuredShippingMethods, DateTimeOffset.UtcNow);

        var methods = JsonSerializer.Deserialize<IReadOnlyCollection<ShippingMethodDefinition>>(reader.GetString(1))
            ?? _configuredShippingMethods;
        return new CommerceSettings(reader.GetDecimal(0), methods, reader.GetFieldValue<DateTimeOffset>(2));
    }

    public async Task<CommerceSettings> UpdateAsync(CommerceSettingsRequest request, CancellationToken cancellationToken)
    {
        var errors = request.Validate();
        if (errors.Count > 0) throw new CommerceSettingsValidationException(errors);
        if (!IsConfigured)
            return new CommerceSettings(request.TaxRatePercent, request.ShippingMethods, DateTimeOffset.UtcNow);

        var updatedAt = DateTimeOffset.UtcNow;
        const string sql = """
            insert into commerce_settings (id, tax_rate_percent, shipping_methods, updated_at)
            values (1, @tax_rate_percent, @shipping_methods::jsonb, @updated_at)
            on conflict (id) do update set
                tax_rate_percent = excluded.tax_rate_percent,
                shipping_methods = excluded.shipping_methods,
                updated_at = excluded.updated_at;
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("tax_rate_percent", request.TaxRatePercent);
        command.Parameters.AddWithValue("shipping_methods", JsonSerializer.Serialize(request.ShippingMethods));
        command.Parameters.AddWithValue("updated_at", updatedAt);
        await command.ExecuteNonQueryAsync(cancellationToken);
        return new CommerceSettings(request.TaxRatePercent, request.ShippingMethods, updatedAt);
    }

    public async Task<(CommerceQuote? Quote, string? Error)> QuoteAsync(decimal subtotal, string? shippingMethod, CancellationToken cancellationToken)
    {
        var settings = await GetAsync(cancellationToken);
        var methodCode = string.IsNullOrWhiteSpace(shippingMethod)
            ? settings.ShippingMethods.FirstOrDefault(item => item.IsActive)?.Code
            : shippingMethod.Trim();
        var method = settings.ShippingMethods.FirstOrDefault(item =>
            item.IsActive && item.Code.Equals(methodCode, StringComparison.OrdinalIgnoreCase));
        if (method is null) return (null, "روش ارسال انتخاب‌شده فعال نیست.");
        var shipping = method.FreeAbove > 0 && subtotal >= method.FreeAbove ? 0 : method.Price;
        var tax = Math.Round(subtotal * settings.TaxRatePercent / 100m, 2, MidpointRounding.AwayFromZero);
        return (new CommerceQuote(method.Code, shipping, settings.TaxRatePercent, tax, subtotal + shipping + tax), null);
    }

    private static IReadOnlyCollection<ShippingMethodDefinition> ReadConfiguredShipping(IConfiguration configuration)
    {
        var methods = configuration.GetSection("Commerce:ShippingMethods").Get<IReadOnlyCollection<ShippingMethodDefinition>>();
        return methods is { Count: > 0 }
            ? methods
            : [
                new ShippingMethodDefinition("store-courier", "پیک فروشگاه", 750_000, 15_000_000),
                new ShippingMethodDefinition("post", "پست", 500_000, 0),
                new ShippingMethodDefinition("pickup", "تحویل حضوری", 0, 0)
            ];
    }
}

public sealed class CommerceSettingsValidationException(Dictionary<string, string[]> errors) : Exception("تنظیمات قیمت‌گذاری معتبر نیست.")
{
    public Dictionary<string, string[]> Errors { get; } = errors;
}

public static class CommercePricingModule
{
    public static IServiceCollection AddCommercePricing(this IServiceCollection services)
    {
        services.AddSingleton<CommercePricingDatabase>();
        services.AddHostedService<CommercePricingSchemaInitializer>();
        return services;
    }

    public static IEndpointRouteBuilder MapCommercePricing(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/commerce/shipping-methods", async (CommercePricingDatabase database, CancellationToken cancellationToken) =>
            Results.Ok(await database.GetAsync(cancellationToken)));

        endpoints.MapGet("/api/v1/admin/commerce/settings", async (CommercePricingDatabase database, CancellationToken cancellationToken) =>
            Results.Ok(await database.GetAsync(cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>();

        endpoints.MapPut("/api/v1/admin/commerce/settings", async (
            CommerceSettingsRequest request,
            CommercePricingDatabase database,
            CancellationToken cancellationToken) =>
        {
            var errors = request.Validate();
            if (errors.Count > 0) return Results.ValidationProblem(errors);
            return Results.Ok(await database.UpdateAsync(request, cancellationToken));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();

        return endpoints;
    }
}

public sealed class CommercePricingSchemaInitializer(CommercePricingDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken) => database.InitializeAsync(cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
