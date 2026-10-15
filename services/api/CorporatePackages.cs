using System.Text.Json;
using System.Text.RegularExpressions;
using Npgsql;
using NpgsqlTypes;

public sealed record CorporatePackageItemInput(string Name, decimal Quantity, string Unit, decimal UnitPrice);
public sealed record CorporatePackageItem(string Name, decimal Quantity, string Unit, decimal UnitPrice);
public sealed record CorporatePackageUpsert(string Name, string? Description, bool IsActive, IReadOnlyCollection<CorporatePackageItemInput>? Items);
public sealed record CorporatePackage(string Code, string Name, string? Description, bool IsActive, decimal UnitPrice, IReadOnlyCollection<CorporatePackageItem> Items);
public sealed record CorporatePackageSnapshot(string Code, string Name, string? Description, decimal UnitPrice, int OrderQuantity, decimal EstimatedTotal, IReadOnlyCollection<CorporatePackageItem> Items);
public sealed record CorporateRequestCreateResult(Guid? Id, string? AccessToken, string? Error = null);

public static class CorporatePackageValidation
{
    public static Dictionary<string, string[]> Validate(string code, CorporatePackageUpsert input)
    {
        var errors = new Dictionary<string, string[]>();
        var key = code.Trim().ToLowerInvariant();
        if (key.Length is < 2 or > 80 || !Regex.IsMatch(key, "^[a-z0-9]+(?:-[a-z0-9]+)*$", RegexOptions.CultureInvariant))
            errors["code"] = ["کد بسته فقط شامل حروف انگلیسی کوچک، عدد و خط تیره باشد."];
        if (string.IsNullOrWhiteSpace(input.Name) || input.Name.Trim().Length > 120)
            errors[nameof(input.Name)] = ["نام بسته الزامی و حداکثر ۱۲۰ نویسه است."];
        if (input.Description is { Length: > 500 })
            errors[nameof(input.Description)] = ["توضیحات حداکثر ۵۰۰ نویسه است."];
        var items = input.Items?.ToArray() ?? [];
        if (items.Length is < 1 or > 40) errors[nameof(input.Items)] = ["بسته باید بین ۱ تا ۴۰ قلم داشته باشد."];
        foreach (var item in items)
        {
            if (string.IsNullOrWhiteSpace(item.Name) || item.Name.Trim().Length > 120 ||
                string.IsNullOrWhiteSpace(item.Unit) || item.Unit.Trim().Length > 40 ||
                item.Quantity is <= 0 or > 1000000 || item.Quantity != decimal.Round(item.Quantity, 3) ||
                item.UnitPrice is < 0 or > 1000000000000m || item.UnitPrice != decimal.Round(item.UnitPrice, 2))
                errors[nameof(input.Items)] = ["نام، واحد، تعداد و قیمت قلم معتبر نیست؛ تعداد حداکثر سه و قیمت حداکثر دو رقم اعشار دارد."];
        }
        try
        {
            if (items.Length > 0 && decimal.Round(items.Sum(item => item.Quantity * item.UnitPrice), 2) <= 0)
                errors[nameof(input.Items)] = ["قیمت کل هر بسته باید بیشتر از صفر باشد."];
        }
        catch (OverflowException) { errors[nameof(input.Items)] = ["قیمت کل بسته از محدودهٔ مجاز بیشتر است."]; }
        return errors;
    }
}

public sealed class CorporatePackageDatabase(IConfiguration configuration, ILogger<CorporatePackageDatabase> logger)
{
    private readonly string? connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(connectionString);

    public async Task ApplyMigrationsAsync(CancellationToken ct)
    {
        if (!IsConfigured) return;
        const string sql = """
            create table if not exists corporate_packages (
                code varchar(80) primary key check (code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
                name varchar(120) not null, description varchar(500),
                is_active boolean not null default true, updated_at timestamptz not null default now(),
                updated_by varchar(180) not null
            );
            create table if not exists corporate_package_items (
                id uuid primary key, package_code varchar(80) not null references corporate_packages(code) on delete cascade,
                name varchar(120) not null, quantity numeric(12,3) not null check(quantity > 0),
                unit varchar(40) not null, unit_price numeric(18,2) not null check(unit_price >= 0),
                position integer not null
            );
            alter table corporate_requests add column if not exists package_code varchar(80);
            alter table corporate_requests add column if not exists package_snapshot jsonb;
            do $migration$
            begin
                if not exists (select 1 from pg_constraint where conname='fk_corporate_requests_package_code') then
                    alter table corporate_requests add constraint fk_corporate_requests_package_code
                    foreign key(package_code) references corporate_packages(code) on delete set null;
                end if;
            end;
            $migration$;
            create index if not exists ix_corporate_package_items_order on corporate_package_items(package_code,position);
            """;
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await DatabaseMigrationRunner.ApplyAsync(connection, "corporate-sales", "002-package-catalog-snapshots", sql, ct);
        logger.LogInformation("Corporate package catalog schema is ready.");
    }

    public async Task<IReadOnlyCollection<CorporatePackage>> ListAsync(bool activeOnly, CancellationToken ct)
    {
        if (!IsConfigured) return [];
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("select code from corporate_packages where (@active=false or is_active) order by name,code", connection);
        command.Parameters.AddWithValue("active", activeOnly);
        var codes = new List<string>();
        await using (var reader = await command.ExecuteReaderAsync(ct))
            while (await reader.ReadAsync(ct)) codes.Add(reader.GetString(0));
        var result = new List<CorporatePackage>();
        foreach (var code in codes)
            if (await FindAsync(connection, null, code, activeOnly, false, ct) is { } item) result.Add(item);
        return result;
    }

    public async Task<CorporatePackage?> FindAsync(NpgsqlConnection connection, NpgsqlTransaction? tx, string code, bool activeOnly, bool lockForShare, CancellationToken ct)
    {
        var query = "select code,name,description,is_active from corporate_packages where code=@code" +
            (activeOnly ? " and is_active=true" : "") + (lockForShare ? " for share" : "");
        string name, key; string? description; bool active;
        await using (var command = new NpgsqlCommand(query, connection, tx))
        {
            command.Parameters.AddWithValue("code", code);
            await using var reader = await command.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct)) return null;
            key = reader.GetString(0); name = reader.GetString(1);
            description = reader.IsDBNull(2) ? null : reader.GetString(2); active = reader.GetBoolean(3);
        }
        var items = new List<CorporatePackageItem>();
        await using (var command = new NpgsqlCommand("select name,quantity,unit,unit_price from corporate_package_items where package_code=@code order by position,id", connection, tx))
        {
            command.Parameters.AddWithValue("code", key);
            await using var reader = await command.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct)) items.Add(new(reader.GetString(0), reader.GetDecimal(1), reader.GetString(2), reader.GetDecimal(3)));
        }
        return new(key, name, description, active, decimal.Round(items.Sum(x => x.Quantity * x.UnitPrice), 2, MidpointRounding.AwayFromZero), items);
    }

    public async Task<CorporatePackage> SaveAsync(string code, CorporatePackageUpsert input, string actor, string requestId, AdminAuditLogDatabase audit, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var tx = await connection.BeginTransactionAsync(ct);
        var before = await FindAsync(connection, tx, code, false, true, ct);
        const string upsert = """
            insert into corporate_packages(code,name,description,is_active,updated_at,updated_by)
            values(@code,@name,@description,@active,now(),@actor)
            on conflict(code) do update set name=excluded.name,description=excluded.description,
            is_active=excluded.is_active,updated_at=now(),updated_by=excluded.updated_by;
            """;
        await using (var command = new NpgsqlCommand(upsert, connection, tx))
        {
            command.Parameters.AddWithValue("code", code); command.Parameters.AddWithValue("name", input.Name.Trim());
            command.Parameters.AddWithValue("description", (object?)input.Description?.Trim() ?? DBNull.Value);
            command.Parameters.AddWithValue("active", input.IsActive); command.Parameters.AddWithValue("actor", actor.Trim());
            await command.ExecuteNonQueryAsync(ct);
        }
        await using (var command = new NpgsqlCommand("delete from corporate_package_items where package_code=@code", connection, tx))
        { command.Parameters.AddWithValue("code", code); await command.ExecuteNonQueryAsync(ct); }
        var items = input.Items!.Select(x => new CorporatePackageItemInput(x.Name.Trim(), x.Quantity, x.Unit.Trim(), x.UnitPrice)).ToArray();
        for (var i=0; i<items.Length; i++)
        {
            var item=items[i];
            await using var command = new NpgsqlCommand("insert into corporate_package_items(id,package_code,name,quantity,unit,unit_price,position) values(@id,@code,@name,@quantity,@unit,@price,@position)", connection, tx);
            command.Parameters.AddWithValue("id", Guid.NewGuid()); command.Parameters.AddWithValue("code", code);
            command.Parameters.AddWithValue("name", item.Name); command.Parameters.AddWithValue("quantity", item.Quantity);
            command.Parameters.AddWithValue("unit", item.Unit); command.Parameters.AddWithValue("price", item.UnitPrice);
            command.Parameters.AddWithValue("position", i); await command.ExecuteNonQueryAsync(ct);
        }
        var afterItems=items.Select(x=>new CorporatePackageItem(x.Name,x.Quantity,x.Unit,x.UnitPrice)).ToArray();
        var saved=new CorporatePackage(code,input.Name.Trim(),string.IsNullOrWhiteSpace(input.Description)?null:input.Description.Trim(),
            input.IsActive,decimal.Round(afterItems.Sum(x=>x.Quantity*x.UnitPrice),2,MidpointRounding.AwayFromZero),afterItems);
        await audit.RecordAsync(connection,tx,actor,before is null?"corporate-package.create":"corporate-package.update",
            "CorporatePackage",code,before,saved,"ثبت یا ویرایش کاتالوگ بستهٔ فروش سازمانی",requestId,ct);
        await tx.CommitAsync(ct);
        return saved;
    }
}
