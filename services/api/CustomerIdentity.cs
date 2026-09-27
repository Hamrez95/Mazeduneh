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
        customers.MapGet("/", async (CustomerIdentityDatabase database, CancellationToken cancellationToken) =>
                Results.Ok(await database.ListAsync(cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>();
        customers.MapGet("/{customerId:guid}", async (
                Guid customerId,
                CustomerIdentityDatabase database,
                CancellationToken cancellationToken) =>
            await database.FindAsync(customerId, cancellationToken) is { } customer
                ? Results.Ok(customer)
                : Results.NotFound(new { message = "مشتری پیدا نشد." }))
            .AddEndpointFilter<OwnerAuthorizationFilter>();
        return endpoints;
    }
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
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync(cancellationToken);
        logger.LogInformation("Customer identity schema and checkout trigger are ready.");
    }

    public async Task<IReadOnlyCollection<CustomerSummary>> ListAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return Array.Empty<CustomerSummary>();

        const string sql = """
            select c.id,c.full_name,c.mobile,c.mobile_normalized,c.marketing_consent,
                   c.created_at,c.updated_at,count(o.id)::int
            from customers c
            left join checkout_orders o on o.customer_id = c.id
            group by c.id
            order by c.updated_at desc
            limit 200;
            """;

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
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
                reader.GetInt32(7)));
        }
        return customers;
    }

    public async Task<CustomerSummary?> FindAsync(Guid customerId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;

        const string sql = """
            select c.id,c.full_name,c.mobile,c.mobile_normalized,c.marketing_consent,
                   c.created_at,c.updated_at,count(o.id)::int
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
            reader.GetInt32(7));
    }
}

public sealed record CustomerSummary(
    Guid Id,
    string FullName,
    string Mobile,
    string NormalizedMobile,
    bool MarketingConsent,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    int OrderCount);

public sealed class CustomerIdentitySchemaInitializer(CustomerIdentityDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken) => database.InitializeAsync(cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
