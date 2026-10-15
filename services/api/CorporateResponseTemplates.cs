using System.Text.RegularExpressions;
using Npgsql;

public sealed record CorporateResponseTemplate(string Code, string Title, string Body, bool IsActive,
    DateTimeOffset UpdatedAt, string UpdatedBy);
public sealed record CorporateResponseTemplateUpsert(string Title, string Body, bool IsActive);

public static class CorporateResponseTemplateValidation
{
    public static Dictionary<string, string[]> Validate(string code, CorporateResponseTemplateUpsert input)
    {
        var errors = new Dictionary<string, string[]>();
        var key = code.Trim().ToLowerInvariant();
        if (key.Length is < 2 or > 80 ||
            !Regex.IsMatch(key, "^[a-z0-9]+(?:-[a-z0-9]+)*$", RegexOptions.CultureInvariant))
            errors["code"] = ["کد پاسخ فقط شامل حروف انگلیسی کوچک، عدد و خط تیره باشد."];
        if (string.IsNullOrWhiteSpace(input.Title) || input.Title.Trim().Length > 120)
            errors[nameof(input.Title)] = ["عنوان پاسخ الزامی و حداکثر ۱۲۰ نویسه است."];
        if (string.IsNullOrWhiteSpace(input.Body) || input.Body.Trim().Length > 2000)
            errors[nameof(input.Body)] = ["متن پاسخ الزامی و حداکثر ۲۰۰۰ نویسه است."];
        return errors;
    }
}

public sealed class CorporateResponseTemplateDatabase(
    IConfiguration configuration, ILogger<CorporateResponseTemplateDatabase> logger)
{
    private readonly string? connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(connectionString);

    public async Task ApplyMigrationsAsync(CancellationToken ct)
    {
        if (!IsConfigured) return;
        const string sql = """
            create table if not exists corporate_response_templates (
                code varchar(80) primary key check (code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
                title varchar(120) not null,
                body varchar(2000) not null,
                is_active boolean not null default true,
                updated_at timestamptz not null default now(),
                updated_by varchar(180) not null
            );
            """;
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await DatabaseMigrationRunner.ApplyAsync(connection, "corporate-sales", "003-response-templates", sql, ct);
        logger.LogInformation("Corporate response template schema is ready.");
    }

    public async Task<IReadOnlyCollection<CorporateResponseTemplate>> ListAsync(bool activeOnly, CancellationToken ct)
    {
        if (!IsConfigured) return [];
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("""
            select code,title,body,is_active,updated_at,updated_by
            from corporate_response_templates
            where (@active=false or is_active=true)
            order by title,code;
            """, connection);
        command.Parameters.AddWithValue("active", activeOnly);
        var items = new List<CorporateResponseTemplate>();
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            items.Add(Read(reader));
        return items;
    }

    public async Task<CorporateResponseTemplate> SaveAsync(string code, CorporateResponseTemplateUpsert input,
        string actor, string requestId, AdminAuditLogDatabase audit, CancellationToken ct)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);
        var before = await FindAsync(connection, transaction, code, ct);
        const string sql = """
            insert into corporate_response_templates(code,title,body,is_active,updated_at,updated_by)
            values(@code,@title,@body,@active,now(),@actor)
            on conflict(code) do update set title=excluded.title,body=excluded.body,
                is_active=excluded.is_active,updated_at=excluded.updated_at,updated_by=excluded.updated_by
            returning code,title,body,is_active,updated_at,updated_by;
            """;
        CorporateResponseTemplate saved;
        await using (var command = new NpgsqlCommand(sql, connection, transaction))
        {
            command.Parameters.AddWithValue("code", code);
            command.Parameters.AddWithValue("title", input.Title.Trim());
            command.Parameters.AddWithValue("body", input.Body.Trim());
            command.Parameters.AddWithValue("active", input.IsActive);
            command.Parameters.AddWithValue("actor", actor.Trim());
            await using var reader = await command.ExecuteReaderAsync(ct);
            await reader.ReadAsync(ct);
            saved = Read(reader);
        }
        await audit.RecordAsync(connection, transaction, actor,
            before is null ? "corporate-response-template.create" : "corporate-response-template.update",
            "CorporateResponseTemplate", code, before, saved, "ثبت یا ویرایش پاسخ آمادهٔ فروش سازمانی", requestId, ct);
        await transaction.CommitAsync(ct);
        return saved;
    }

    private static async Task<CorporateResponseTemplate?> FindAsync(NpgsqlConnection connection,
        NpgsqlTransaction transaction, string code, CancellationToken ct)
    {
        await using var command = new NpgsqlCommand("""
            select code,title,body,is_active,updated_at,updated_by
            from corporate_response_templates where code=@code for update;
            """, connection, transaction);
        command.Parameters.AddWithValue("code", code);
        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? Read(reader) : null;
    }

    private static CorporateResponseTemplate Read(NpgsqlDataReader reader) =>
        new(reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetBoolean(3),
            reader.GetFieldValue<DateTimeOffset>(4), reader.GetString(5));
}
