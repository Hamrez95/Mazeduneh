using System.Globalization;
using System.Text;
using Npgsql;

public static class CustomerIdentityModule
{
    public static IServiceCollection AddCustomerIdentity(this IServiceCollection services)
    {
        services.AddSingleton<CustomerIdentityDatabase>();
        services.AddHostedService<CustomerIdentitySchemaInitializer>();
        return services;
    }

    public static IEndpointRouteBuilder MapCustomerIdentity(this IEndpointRouteBuilder endpoints)
    {
        var customers = endpoints.MapGroup("/api/v1/admin/customers").WithTags("Customers");
        customers.MapGet("/", async (
                string? q,
                bool? marketingConsent,
                int? limit,
                CustomerIdentityDatabase database,
                HttpContext context,
                CancellationToken cancellationToken) =>
        {
            if (q?.Length > 120)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["q"] = ["عبارت جست‌وجو نمی‌تواند بیشتر از ۱۲۰ نویسه باشد."] });
            var rows = await database.ListAsync(q, marketingConsent, Math.Clamp(limit ?? 200, 1, 500), cancellationToken);
            return Results.Ok(CanReadPii(context) ? rows : rows.Select(MaskPii).ToArray());
        })
            .AddEndpointFilter<OwnerAuthorizationFilter>();
        customers.MapGet("/export.csv", async (
                string? q,
                bool? marketingConsent,
                int? limit,
                CustomerIdentityDatabase database,
                CancellationToken cancellationToken) =>
        {
            if (q?.Length > 120)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["q"] = ["عبارت جست‌وجو نمی‌تواند بیشتر از ۱۲۰ نویسه باشد."] });
            var rows = await database.ListAsync(q, marketingConsent, Math.Clamp(limit ?? 1_000, 1, 5_000), cancellationToken);
            static string Csv(object? value)
            {
                var text = value?.ToString() ?? string.Empty;
                return $"\"{text.Replace("\"", "\"\"")}\"";
            }

            var builder = new StringBuilder("\uFEFFشناسه مشتری,نام,موبایل,تعداد سفارش,رضایت ارتباطی,اولین ثبت,آخرین فعالیت\n");
            foreach (var customer in rows)
            {
                builder.Append(string.Join(',', new[]
                {
                    Csv(customer.Id),
                    Csv(customer.FullName),
                    Csv(customer.Mobile),
                    Csv(customer.OrderCount),
                    Csv(customer.MarketingConsent ? "دارد" : "ثبت نشده"),
                    Csv(customer.CreatedAt.ToString("O", CultureInfo.InvariantCulture)),
                    Csv(customer.UpdatedAt.ToString("O", CultureInfo.InvariantCulture))
                })).Append('\n');
            }

            return Results.File(Encoding.UTF8.GetBytes(builder.ToString()), "text/csv; charset=utf-8", "mazeduneh-customers.csv");
        })
            .AddEndpointFilter<OwnerAuthorizationFilter>();
        customers.MapGet("/{customerId:guid}", async (
                Guid customerId,
                CustomerIdentityDatabase database,
                HttpContext context,
                CancellationToken cancellationToken) =>
            await database.FindProfileAsync(customerId, cancellationToken) is { } customer
                ? Results.Ok(CanReadPii(context) ? customer : MaskPii(customer))
                : Results.NotFound(new { message = "مشتری پیدا نشد." }))
            .AddEndpointFilter<OwnerAuthorizationFilter>();
        return endpoints;
    }

    private static bool CanReadPii(HttpContext context) =>
        context.Items["AdminPrincipal"] is AdminPrincipal principal &&
        AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.CustomersPiiRead);

    private static CustomerSummary MaskPii(CustomerSummary customer) => customer with
    {
        FullName = $"مشتری {customer.Id.ToString("N")[..6]}",
        Mobile = "مخفی بر اساس نقش",
        NormalizedMobile = string.Empty,
        Addresses = Array.Empty<CustomerAddressSummary>()
    };
}

public sealed class CustomerIdentityDatabase(IConfiguration configuration, ILogger<CustomerIdentityDatabase> logger)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;

        const string sql = """
            create extension if not exists pgcrypto;
            create table if not exists customers (
                id uuid primary key,
                full_name text not null,
                mobile text not null,
                mobile_normalized varchar(20) not null unique,
                marketing_consent boolean not null default false,
                created_at timestamptz not null,
                updated_at timestamptz not null
            );
            create table if not exists customer_addresses (
                id uuid primary key,
                customer_id uuid not null references customers(id) on delete cascade,
                province text not null,
                city text not null,
                address text not null,
                postal_code varchar(20) not null,
                is_default boolean not null default false,
                created_at timestamptz not null,
                last_used_at timestamptz not null
            );
            alter table checkout_orders
                add column if not exists customer_id uuid references customers(id);
            create index if not exists ix_checkout_orders_customer_id
                on checkout_orders(customer_id);
            create index if not exists ix_customer_addresses_customer
                on customer_addresses(customer_id, last_used_at desc);

            create or replace function mazeduneh_ensure_checkout_customer()
            returns trigger
            language plpgsql
            as $function$
            declare
                normalized_mobile text;
                resolved_customer_id uuid;
            begin
                normalized_mobile := translate(
                    regexp_replace(coalesce(new.mobile, ''), '[^0-9۰-۹+]', '', 'g'),
                    '۰۱۲۳۴۵۶۷۸۹',
                    '0123456789'
                );
                if normalized_mobile like '+98%' then
                    normalized_mobile := '0' || substring(normalized_mobile from 4);
                elsif normalized_mobile like '98%' then
                    normalized_mobile := '0' || substring(normalized_mobile from 3);
                end if;

                insert into customers (
                    id, full_name, mobile, mobile_normalized, created_at, updated_at
                )
                values (
                    gen_random_uuid(),
                    coalesce(nullif(trim(new.customer_name), ''), 'مشتری مزه‌دونه'),
                    new.mobile,
                    normalized_mobile,
                    now(),
                    now()
                )
                on conflict (mobile_normalized) do update
                    set full_name = excluded.full_name,
                        mobile = excluded.mobile,
                        updated_at = now()
                returning id into resolved_customer_id;

                new.customer_id := resolved_customer_id;

                insert into customer_addresses (
                    id, customer_id, province, city, address, postal_code,
                    is_default, created_at, last_used_at
                )
                select
                    gen_random_uuid(),
                    resolved_customer_id,
                    new.province,
                    new.city,
                    new.address,
                    new.postal_code,
                    not exists (
                        select 1 from customer_addresses
                        where customer_id = resolved_customer_id
                    ),
                    now(),
                    now()
                where not exists (
                    select 1 from customer_addresses
                    where customer_id = resolved_customer_id
                      and province = new.province
                      and city = new.city
                      and address = new.address
                      and postal_code = new.postal_code
                );

                return new;
            end;
            $function$;

            drop trigger if exists trg_checkout_orders_customer on checkout_orders;
            create trigger trg_checkout_orders_customer
                before insert on checkout_orders
                for each row
                execute function mazeduneh_ensure_checkout_customer();
            """;

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "customers", "001-bootstrap", sql, cancellationToken);
        logger.LogInformation("Customer identity schema and checkout trigger are ready.");
    }

    public async Task<IReadOnlyCollection<CustomerSummary>> ListAsync(
        string? query,
        bool? marketingConsent,
        int limit,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<CustomerSummary>();

        const string sql = """
            select c.id,c.full_name,c.mobile,c.mobile_normalized,c.marketing_consent,
                   c.created_at,c.updated_at,count(o.id)::int,
                   coalesce(sum(o.payable) filter (where o.state not in ('Cancelled', 'Expired')), 0),
                   coalesce(avg(o.payable) filter (where o.state not in ('Cancelled', 'Expired')), 0),
                   max(o.created_at) filter (where o.state not in ('Cancelled', 'Expired'))
            from customers c
            left join checkout_orders o on o.customer_id = c.id
            where (@query = '' or c.full_name ilike '%' || @query || '%' or c.mobile ilike '%' || @query || '%' or c.mobile_normalized ilike '%' || @query || '%')
              and (cast(@marketing_consent as boolean) is null or c.marketing_consent = cast(@marketing_consent as boolean))
            group by c.id
            order by c.updated_at desc
            limit @limit;
            """;

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("query", query?.Trim() ?? string.Empty);
        command.Parameters.AddWithValue("marketing_consent", (object?)marketingConsent ?? DBNull.Value);
        command.Parameters.AddWithValue("limit", limit);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var customers = new List<CustomerSummary>();
        while (await reader.ReadAsync(cancellationToken))
        {
            customers.Add(new CustomerSummary(
                reader.GetGuid(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetString(3),
                reader.GetBoolean(4),
                reader.GetFieldValue<DateTimeOffset>(5),
                reader.GetFieldValue<DateTimeOffset>(6),
                reader.GetInt32(7),
                reader.GetDecimal(8),
                reader.GetDecimal(9),
                reader.IsDBNull(10) ? null : reader.GetFieldValue<DateTimeOffset>(10)));
        }
        return customers;
    }

    public async Task<CustomerSummary?> FindAsync(Guid customerId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;

        const string sql = """
            select c.id,c.full_name,c.mobile,c.mobile_normalized,c.marketing_consent,
                   c.created_at,c.updated_at,count(o.id)::int,
                   coalesce(sum(o.payable) filter (where o.state not in ('Cancelled', 'Expired')), 0),
                   coalesce(avg(o.payable) filter (where o.state not in ('Cancelled', 'Expired')), 0),
                   max(o.created_at) filter (where o.state not in ('Cancelled', 'Expired'))
            from customers c
            left join checkout_orders o on o.customer_id = c.id
            where c.id = @id
            group by c.id;
            """;

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("id", customerId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new CustomerSummary(
            reader.GetGuid(0),
            reader.GetString(1),
            reader.GetString(2),
            reader.GetString(3),
            reader.GetBoolean(4),
            reader.GetFieldValue<DateTimeOffset>(5),
            reader.GetFieldValue<DateTimeOffset>(6),
            reader.GetInt32(7),
            reader.GetDecimal(8),
            reader.GetDecimal(9),
            reader.IsDBNull(10) ? null : reader.GetFieldValue<DateTimeOffset>(10));
    }

    public async Task<CustomerSummary?> FindProfileAsync(Guid customerId, CancellationToken cancellationToken)
    {
        var summary = await FindAsync(customerId, cancellationToken);
        if (summary is null || !IsConfigured) return summary;

        const string sql = """
            select id,province,city,address,postal_code,is_default,last_used_at
            from customer_addresses
            where customer_id = @customer_id
            order by is_default desc, last_used_at desc;
            """;

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("customer_id", customerId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var addresses = new List<CustomerAddressSummary>();
        while (await reader.ReadAsync(cancellationToken))
        {
            addresses.Add(new CustomerAddressSummary(
                reader.GetGuid(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetString(3),
                reader.GetString(4),
                reader.GetBoolean(5),
                reader.GetFieldValue<DateTimeOffset>(6)));
        }

        return summary with { Addresses = addresses };
    }
}

public sealed record CustomerAddressSummary(
    Guid Id,
    string Province,
    string City,
    string Address,
    string PostalCode,
    bool IsDefault,
    DateTimeOffset LastUsedAt);

public sealed record CustomerSummary(
    Guid Id,
    string FullName,
    string Mobile,
    string NormalizedMobile,
    bool MarketingConsent,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    int OrderCount,
    decimal TotalSpend,
    decimal AverageOrderValue,
    DateTimeOffset? LastPurchaseAt,
    IReadOnlyCollection<CustomerAddressSummary> Addresses = null!);

public sealed class CustomerIdentitySchemaInitializer(CustomerIdentityDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken) => database.InitializeAsync(cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
