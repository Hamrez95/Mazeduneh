using Npgsql;
using NpgsqlTypes;
using System.Security.Cryptography;
using System.Text.Json;

public static class CorporateRequestStatuses
{
    public static readonly string[] All = [
        "New", "Reviewing", "Contacted", "NeedsInformation", "ProformaSent",
        "Negotiating", "Approved", "Preparing", "Shipped", "Finalized", "Cancelled"
    ];

    public static string Title(string status) => status switch
    {
        "New" => "جدید", "Reviewing" => "در حال بررسی", "Contacted" => "تماس گرفته شد",
        "NeedsInformation" => "نیازمند اطلاعات بیشتر", "ProformaSent" => "پیش‌فاکتور ارسال شد",
        "Negotiating" => "در حال مذاکره", "Approved" => "تأیید شد", "Preparing" => "در حال آماده‌سازی",
        "Shipped" => "ارسال شد", "Finalized" => "نهایی شد", "Cancelled" => "لغو شد", _ => status
    };

    private static readonly IReadOnlyDictionary<string, HashSet<string>> AllowedTransitions =
        new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase)
        {
            ["New"] = Set("Reviewing", "Contacted", "Cancelled"),
            ["Reviewing"] = Set("Contacted", "NeedsInformation", "Cancelled"),
            ["Contacted"] = Set("NeedsInformation", "ProformaSent", "Negotiating", "Cancelled"),
            ["NeedsInformation"] = Set("Reviewing", "Contacted", "Cancelled"),
            ["ProformaSent"] = Set("Negotiating", "Approved", "Cancelled"),
            ["Negotiating"] = Set("ProformaSent", "Approved", "Cancelled"),
            ["Approved"] = Set("Preparing", "Cancelled"),
            ["Preparing"] = Set("Shipped", "Cancelled"),
            ["Shipped"] = Set("Finalized"),
            ["Finalized"] = Set(),
            ["Cancelled"] = Set()
        };

    public static bool CanTransition(string? current, string? next) =>
        !string.IsNullOrWhiteSpace(current) &&
        !string.IsNullOrWhiteSpace(next) &&
        (string.Equals(current, next, StringComparison.OrdinalIgnoreCase) ||
            AllowedTransitions.TryGetValue(current, out var allowed) && allowed.Contains(next));

    private static HashSet<string> Set(params string[] statuses) => new(statuses, StringComparer.OrdinalIgnoreCase);
}

public enum CorporateRequestStatusChangeKind { Updated, NotFound, InvalidTransition }
public sealed record CorporateRequestStatusChangeResult(CorporateRequestStatusChangeKind Kind, CorporateRequestDetail? Request = null);

public sealed record CorporateRequestCreate(
    string CustomerName, string CompanyName, string Mobile, string? Email, string City,
    string Occasion, int OrderQuantity, string PackageType, decimal? Budget,
    DateOnly? DeliveryDate, bool CustomPackaging, string? Description, string? LogoKey,
    string? PackageCode = null);

public sealed record CorporateRequestStatusChange(string Status, string? Note);
public sealed record CorporateRequestAssignment(string? AssignedTo);
public sealed record CorporateRequestFollowUp(DateTimeOffset? NextFollowUpAt);
public sealed record CorporateRequestNoteInput(string Note);
public sealed record CorporateRequestMessageInput(string Body, string Channel);

public sealed record CorporateRequestSummary(
    Guid Id, string CustomerName, string CompanyName, string Mobile, string City,
    string Occasion, int OrderQuantity, string PackageType, string Status,
    string? AssignedTo, DateTimeOffset? NextFollowUpAt, DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);

public sealed record CorporateRequestDetail(
    Guid Id, string CustomerName, string CompanyName, string Mobile, string? Email, string City,
    string Occasion, int OrderQuantity, string PackageType, decimal? Budget, DateOnly? DeliveryDate,
    bool CustomPackaging, string? Description, string? LogoUrl, string? ProformaUrl, string Status,
    string? AssignedTo, DateTimeOffset? NextFollowUpAt, string? InternalNote,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt, IReadOnlyCollection<CorporateRequestEvent> Events,
    IReadOnlyCollection<CorporateRequestMessage> Messages, string? PackageCode = null,
    CorporatePackageSnapshot? PackageSnapshot = null);

public sealed record CorporateRequestEvent(Guid Id, string EventType, string? FromStatus, string? ToStatus, string Actor, string? Note, DateTimeOffset CreatedAt);
public sealed record CorporateRequestMessage(Guid Id, string SenderType, string Body, string Channel, DateTimeOffset CreatedAt);
public sealed record CorporateRequestMetrics(
    int NewCount,
    int UnfollowedCount,
    int TotalCount,
    int ActiveCount,
    int FinalizedCount,
    decimal ConversionRatePercent,
    decimal ActivePipelineBudget,
    decimal AverageHoursToFirstContact,
    int FirstContactCount);

public static class CorporateSalesModule
{
    public static IServiceCollection AddCorporateSales(this IServiceCollection services)
    {
        services.AddSingleton<CorporatePackageDatabase>();
        services.AddSingleton<CorporateRequestDatabase>();
        return services;
    }

    public static IEndpointRouteBuilder MapCorporateSales(this IEndpointRouteBuilder endpoints)
    {
        var packageApi = endpoints.MapGroup("/api/v1/corporate-packages").WithTags("Corporate Packages");
        packageApi.MapGet("", async (CorporatePackageDatabase database, CancellationToken cancellationToken) =>
            Results.Ok(await database.ListAsync(activeOnly: true, cancellationToken)));

        var publicApi = endpoints.MapGroup("/api/v1/corporate-requests").WithTags("Corporate Sales");
        publicApi.MapPost("/upload", async (HttpRequest request, MediaStorage storage, CancellationToken cancellationToken) =>
        {
            if (!request.HasFormContentType) return Results.BadRequest(new { message = "درخواست باید شامل فایل لوگو باشد." });
            try
            {
                var form = await request.ReadFormAsync(cancellationToken);
                var file = form.Files.GetFile("file");
                if (file is null) return Results.BadRequest(new { message = "فایل لوگو ارسال نشده است." });
                if (file.ContentType is null || !file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
                    return Results.BadRequest(new { message = "لوگو باید یک فایل تصویری باشد." });
                var stored = await storage.SaveAsync(file, "corporate/logos", cancellationToken);
                return Results.Created(stored.Url, new { stored.Key, stored.Url, stored.ContentType, stored.SizeBytes });
            }
            catch (MediaStorageValidationException exception) { return Results.BadRequest(new { message = exception.Message }); }
            catch (MediaStorageConfigurationException exception) { return Results.Problem(title: "ذخیره‌سازی فایل پیکربندی نشده است.", detail: exception.Message, statusCode: 503); }
        });

        publicApi.MapPost("", async (CorporateRequestCreate request, CorporateRequestDatabase database, CancellationToken cancellationToken) =>
        {
            var errors = Validate(request);
            if (errors.Count > 0) return Results.ValidationProblem(errors);
            var created = await database.CreateAsync(request, cancellationToken);
            if (created.Error is not null)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["packageCode"] = [created.Error] });
            return Results.Created($"/api/v1/corporate-requests/{created.Id}", new
            {
                id = created.Id, accessToken = created.AccessToken,
                message = "درخواست شما با موفقیت ثبت شد. کارشناسان مزه‌دونه به‌زودی با شما تماس می‌گیرند."
            });
        });

        publicApi.MapGet("/{id:guid}", async (Guid id, HttpRequest httpRequest, CorporateRequestDatabase database, CancellationToken cancellationToken) =>
        {
            var accessToken = httpRequest.Headers["X-Corporate-Request-Token"].ToString();
            return await database.FindPublicAsync(id, accessToken, cancellationToken) is { } request
                ? Results.Ok(request) : Results.NotFound(new { message = "درخواست پیدا نشد." });
        });

        var admin = endpoints.MapGroup("/api/v1/admin/corporate-requests").WithTags("Admin Corporate Sales");
        admin.MapGet("/packages", async (CorporatePackageDatabase database, CancellationToken cancellationToken) =>
            Results.Ok(await database.ListAsync(activeOnly: false, cancellationToken)))
            .AddEndpointFilter<OwnerAuthorizationFilter>();
        admin.MapPut("/packages/{code}", async (
            string code, CorporatePackageUpsert input, CorporatePackageDatabase database,
            AdminAuditLogDatabase audit, HttpContext context, CancellationToken cancellationToken) =>
        {
            var errors = CorporatePackageValidation.Validate(code, input);
            if (errors.Count > 0) return Results.ValidationProblem(errors);
            if (!database.IsConfigured)
                return Results.Problem(title: "کاتالوگ بسته‌ها پیکربندی نشده است.", statusCode: StatusCodes.Status503ServiceUnavailable);
            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var saved = await database.SaveAsync(code.Trim().ToLowerInvariant(), input, actor,
                context.TraceIdentifier, audit, cancellationToken);
            return Results.Ok(saved);
        }).AddEndpointFilter<OwnerAuthorizationFilter>();
        admin.MapGet("", async (string? status, string? city, string? query, DateTimeOffset? from, DateTimeOffset? to, int? minQuantity, int? maxQuantity, bool? overdue, bool? needsPlanning, CorporateRequestDatabase database, CancellationToken cancellationToken) =>
        {
            if (overdue == true && needsPlanning == true)
                return (IResult)Results.ValidationProblem(new Dictionary<string, string[]> { ["filters"] = ["یکی از صف‌های عقب‌افتاده یا نیازمند برنامه‌ریزی را انتخاب کنید."] });
            return Results.Ok(await database.ListAsync(status, city, query, from, to, minQuantity, maxQuantity,
                overdue ?? false, needsPlanning ?? false, cancellationToken));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();
        admin.MapGet("/summary", async (CorporateRequestDatabase database, CancellationToken cancellationToken) => Results.Ok(await database.SummaryAsync(cancellationToken))).AddEndpointFilter<OwnerAuthorizationFilter>();
        admin.MapGet("/{id:guid}", async (Guid id, CorporateRequestDatabase database, CancellationToken cancellationToken) =>
            await database.FindAsync(id, cancellationToken) is { } request ? Results.Ok(request) : Results.NotFound(new { message = "درخواست پیدا نشد." }))
            .AddEndpointFilter<OwnerAuthorizationFilter>();
        admin.MapPatch("/{id:guid}/status", async (Guid id, CorporateRequestStatusChange input, CorporateRequestDatabase database, HttpContext context, CancellationToken cancellationToken) =>
        {
            if (!CorporateRequestStatuses.All.Contains(input.Status, StringComparer.OrdinalIgnoreCase)) return Results.ValidationProblem(new Dictionary<string, string[]> { ["status"] = ["وضعیت درخواست معتبر نیست."] });
            var actor = ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin";
            var result = await database.ChangeStatusAsync(id, input.Status, input.Note, actor, cancellationToken);
            return result.Kind switch
            {
                CorporateRequestStatusChangeKind.Updated => Results.Ok(result.Request),
                CorporateRequestStatusChangeKind.InvalidTransition => Results.Conflict(new { message = "این تغییر وضعیت با روند پیگیری درخواست سازگار نیست." }),
                _ => Results.NotFound(new { message = "درخواست پیدا نشد." })
            };
        }).AddEndpointFilter<OwnerAuthorizationFilter>();
        admin.MapPost("/{id:guid}/assign", async (Guid id, CorporateRequestAssignment input, CorporateRequestDatabase database, CancellationToken cancellationToken) =>
            await database.AssignAsync(id, input.AssignedTo, cancellationToken) is { } request ? Results.Ok(request) : Results.NotFound(new { message = "درخواست پیدا نشد." })).AddEndpointFilter<OwnerAuthorizationFilter>();
        admin.MapPost("/{id:guid}/follow-up", async (Guid id, CorporateRequestFollowUp input, CorporateRequestDatabase database, CancellationToken cancellationToken) =>
            await database.FollowUpAsync(id, input.NextFollowUpAt, cancellationToken) is { } request ? Results.Ok(request) : Results.NotFound(new { message = "درخواست پیدا نشد." })).AddEndpointFilter<OwnerAuthorizationFilter>();
        admin.MapPost("/{id:guid}/notes", async (Guid id, CorporateRequestNoteInput input, CorporateRequestDatabase database, HttpContext context, CancellationToken cancellationToken) =>
            await database.AddNoteAsync(id, input.Note, ((AdminPrincipal?)context.Items["AdminPrincipal"])?.Email ?? "admin", cancellationToken) ? Results.Ok(new { message = "یادداشت ثبت شد." }) : Results.NotFound(new { message = "درخواست پیدا نشد." })).AddEndpointFilter<OwnerAuthorizationFilter>();
        admin.MapPost("/{id:guid}/messages", async (Guid id, CorporateRequestMessageInput input, CorporateRequestDatabase database, CancellationToken cancellationToken) =>
            await database.AddMessageAsync(id, input, cancellationToken) ? Results.Ok(new { message = "پیام در تاریخچه ثبت شد." }) : Results.NotFound(new { message = "درخواست پیدا نشد." })).AddEndpointFilter<OwnerAuthorizationFilter>();
        admin.MapPost("/{id:guid}/proforma", async (Guid id, HttpRequest request, MediaStorage storage, CorporateRequestDatabase database, CancellationToken cancellationToken) =>
        {
            if (!request.HasFormContentType) return Results.BadRequest(new { message = "درخواست باید شامل فایل پیش‌فاکتور باشد." });
            try
            {
                var form = await request.ReadFormAsync(cancellationToken); var file = form.Files.GetFile("file");
                if (file is null) return Results.BadRequest(new { message = "فایل پیش‌فاکتور ارسال نشده است." });
                var stored = await storage.SaveAsync(file, "corporate/proformas", cancellationToken);
                return await database.SetProformaAsync(id, stored.Key, stored.Url, cancellationToken) ? Results.Ok(stored) : Results.NotFound(new { message = "درخواست پیدا نشد." });
            }
            catch (MediaStorageValidationException exception) { return Results.BadRequest(new { message = exception.Message }); }
            catch (MediaStorageConfigurationException exception) { return Results.Problem(title: "ذخیره‌سازی فایل پیکربندی نشده است.", detail: exception.Message, statusCode: 503); }
        }).AddEndpointFilter<OwnerAuthorizationFilter>();
        return endpoints;
    }

    private static Dictionary<string, string[]> Validate(CorporateRequestCreate input)
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(input.CustomerName)) errors[nameof(input.CustomerName)] = ["نام و نام خانوادگی الزامی است."];
        if (string.IsNullOrWhiteSpace(input.CompanyName)) errors[nameof(input.CompanyName)] = ["نام شرکت الزامی است."];
        if (string.IsNullOrWhiteSpace(input.Mobile) || input.Mobile.Trim().Length < 7) errors[nameof(input.Mobile)] = ["شماره تماس معتبر وارد کنید."];
        if (string.IsNullOrWhiteSpace(input.City)) errors[nameof(input.City)] = ["شهر الزامی است."];
        if (string.IsNullOrWhiteSpace(input.Occasion)) errors[nameof(input.Occasion)] = ["نوع مناسبت را انتخاب کنید."];
        if (input.OrderQuantity is < 1 or > 1_000_000) errors[nameof(input.OrderQuantity)] = ["تعداد سفارش باید معتبر باشد."];
        if (string.IsNullOrWhiteSpace(input.PackageCode) && string.IsNullOrWhiteSpace(input.PackageType))
            errors[nameof(input.PackageType)] = ["نوع بسته را انتخاب کنید."];
        if (input.PackageCode is { Length: > 80 }) errors[nameof(input.PackageCode)] = ["کد بسته معتبر نیست."];
        if (input.Email is { Length: > 0 } && !input.Email.Contains('@')) errors[nameof(input.Email)] = ["ایمیل معتبر وارد کنید."];
        return errors;
    }
}

public sealed class CorporateRequestDatabase(
    IConfiguration configuration, ILogger<CorporateRequestDatabase> logger, CorporatePackageDatabase packages)
{
    private readonly string? connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(connectionString);

    public async Task ApplyMigrationsAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        const string sql = """
            create extension if not exists pgcrypto;
            create table if not exists corporate_requests (
              id uuid primary key default gen_random_uuid(), public_access_token varchar(96) not null unique,
              customer_name varchar(180) not null, company_name varchar(180) not null, mobile varchar(40) not null,
              email varchar(180), city varchar(100) not null, occasion varchar(120) not null,
              order_quantity integer not null check (order_quantity > 0), package_type varchar(120) not null,
              budget numeric(18,2), delivery_date date, custom_packaging boolean not null default false,
              description text, logo_key varchar(512), proforma_key varchar(512), status varchar(40) not null default 'New',
              assigned_to varchar(180), next_follow_up_at timestamptz, internal_note text,
              created_at timestamptz not null default now(), updated_at timestamptz not null default now()
            );
            create table if not exists corporate_request_events (
              id uuid primary key default gen_random_uuid(), request_id uuid not null references corporate_requests(id) on delete cascade,
              event_type varchar(60) not null, from_status varchar(40), to_status varchar(40), actor varchar(180) not null, note text, created_at timestamptz not null default now()
            );
            create table if not exists corporate_request_messages (
              id uuid primary key default gen_random_uuid(), request_id uuid not null references corporate_requests(id) on delete cascade,
              sender_type varchar(40) not null, body text not null, channel varchar(40) not null, created_at timestamptz not null default now()
            );
            create index if not exists ix_corporate_requests_status_created on corporate_requests(status, created_at desc);
            create index if not exists ix_corporate_requests_follow_up on corporate_requests(next_follow_up_at);
            """;
        await using var connection = new NpgsqlConnection(connectionString); await connection.OpenAsync(cancellationToken);
        await DatabaseMigrationRunner.ApplyAsync(connection, "corporate-sales", "001-bootstrap", sql, cancellationToken);
        logger.LogInformation("Corporate-sales schema is ready.");
    }

    public async Task<CorporateRequestCreateResult> CreateAsync(CorporateRequestCreate input, CancellationToken ct)
    {
        if (!IsConfigured)
        {
            if (!string.IsNullOrWhiteSpace(input.PackageCode)) return new(null, null, "کاتالوگ بسته‌ها در دسترس نیست.");
            return new(Guid.NewGuid(), Convert.ToHexString(Guid.NewGuid().ToByteArray()));
        }
        var id = Guid.NewGuid();
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var packageCode = string.IsNullOrWhiteSpace(input.PackageCode) ? null : input.PackageCode.Trim().ToLowerInvariant();
        var packageType = input.PackageType?.Trim() ?? string.Empty;
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);
        CorporatePackageSnapshot? snapshot = null;
        if (packageCode is not null)
        {
            var package = await packages.FindAsync(connection, transaction, packageCode, true, true, ct);
            if (package is null)
            {
                await transaction.RollbackAsync(ct);
                return new(null, null, "بسته انتخاب‌شده دیگر در دسترس نیست؛ فهرست بسته‌ها را تازه کنید.");
            }
            packageType = package.Name;
            snapshot = new(package.Code, package.Name, package.Description, package.UnitPrice, input.OrderQuantity,
                decimal.Round(package.UnitPrice * input.OrderQuantity, 2, MidpointRounding.AwayFromZero), package.Items);
        }
        const string sql = """
            insert into corporate_requests(
                id,public_access_token,customer_name,company_name,mobile,email,city,occasion,order_quantity,
                package_type,budget,delivery_date,custom_packaging,description,logo_key,package_code,package_snapshot)
            values (@id,@token,@customer,@company,@mobile,@email,@city,@occasion,@quantity,
                @package,@budget,@delivery,@custom,@description,@logo,@package_code,@package_snapshot);
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        Add(command,"id",id); Add(command,"token",token); Add(command,"customer",input.CustomerName.Trim());
        Add(command,"company",input.CompanyName.Trim()); Add(command,"mobile",input.Mobile.Trim());
        Add(command,"email",(object?)input.Email?.Trim()??DBNull.Value); Add(command,"city",input.City.Trim());
        Add(command,"occasion",input.Occasion.Trim()); Add(command,"quantity",input.OrderQuantity);
        Add(command,"package",packageType); Add(command,"budget",(object?)input.Budget??DBNull.Value);
        Add(command,"delivery",(object?)input.DeliveryDate??DBNull.Value); Add(command,"custom",input.CustomPackaging);
        Add(command,"description",(object?)input.Description?.Trim()??DBNull.Value);
        Add(command,"logo",(object?)input.LogoKey??DBNull.Value);
        Add(command,"package_code",(object?)packageCode??DBNull.Value);
        command.Parameters.Add(new NpgsqlParameter("package_snapshot", NpgsqlDbType.Jsonb)
        { Value = snapshot is null ? DBNull.Value : JsonSerializer.Serialize(snapshot) });
        await command.ExecuteNonQueryAsync(ct);
        await transaction.CommitAsync(ct);
        return new(id, token);
    }

    public async Task<IReadOnlyCollection<CorporateRequestSummary>> ListAsync(string? status, string? city, string? query, DateTimeOffset? from, DateTimeOffset? to, int? minQuantity, int? maxQuantity, bool overdueOnly, bool needsPlanningOnly, CancellationToken ct)
    {
        if (!IsConfigured) return [];
        const string sql = """
            select id,customer_name,company_name,mobile,city,occasion,order_quantity,package_type,
                   status,assigned_to,next_follow_up_at,created_at,updated_at
            from corporate_requests
            where (@status='' or status=@status)
              and (@city='' or city ilike '%'||@city||'%')
              and (@query='' or customer_name ilike '%'||@query||'%'
                   or company_name ilike '%'||@query||'%' or mobile ilike '%'||@query||'%')
              and (@from is null or created_at>=@from) and (@to is null or created_at<=@to)
              and (@min is null or order_quantity>=@min) and (@max is null or order_quantity<=@max)
              and (@overdue=false or (next_follow_up_at is not null and next_follow_up_at<=now()
                   and status not in ('Finalized','Cancelled')))
              and (@needs_planning=false or (status not in ('Finalized','Cancelled')
                   and (nullif(btrim(assigned_to),'') is null or next_follow_up_at is null)))
            order by created_at desc limit 250;
            """;
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand(sql, connection);
        Add(command,"status",status?.Trim()??""); Add(command,"city",city?.Trim()??""); Add(command,"query",query?.Trim()??"");
        AddTyped(command,"from",NpgsqlDbType.TimestampTz,from); AddTyped(command,"to",NpgsqlDbType.TimestampTz,to);
        AddTyped(command,"min",NpgsqlDbType.Integer,minQuantity); AddTyped(command,"max",NpgsqlDbType.Integer,maxQuantity);
        Add(command,"overdue",overdueOnly); Add(command,"needs_planning",needsPlanningOnly);
        var result = new List<CorporateRequestSummary>(); await using var reader = await command.ExecuteReaderAsync(ct); while (await reader.ReadAsync(ct)) result.Add(ReadSummary(reader)); return result;
    }

    public async Task<CorporateRequestMetrics> SummaryAsync(CancellationToken ct)
    {
        if (!IsConfigured) return new(0, 0, 0, 0, 0, 0m, 0m, 0m, 0);
        const string sql = """
            with first_contact as (
                select request_id, min(created_at) as contacted_at
                from corporate_request_events
                where event_type='status' and to_status='Contacted'
                group by request_id
            )
            select count(*) filter(where r.status='New')::int,
                   count(*) filter(where r.next_follow_up_at is not null and r.next_follow_up_at<=now()
                       and r.status not in ('Finalized','Cancelled'))::int,
                   count(*)::int,
                   count(*) filter(where r.status not in ('Finalized','Cancelled'))::int,
                   count(*) filter(where r.status='Finalized')::int,
                   coalesce(count(*) filter(where r.status='Finalized') * 100.0 / nullif(count(*), 0), 0)::numeric,
                   coalesce(sum(r.budget) filter(where r.status not in ('Finalized','Cancelled')), 0)::numeric,
                   coalesce(avg(extract(epoch from (first_contact.contacted_at-r.created_at))/3600), 0)::numeric,
                   count(first_contact.contacted_at)::int
            from corporate_requests r
            left join first_contact on first_contact.request_id=r.id;
            """;
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(ct);
        await reader.ReadAsync(ct);
        return new(
            reader.GetInt32(0), reader.GetInt32(1), reader.GetInt32(2), reader.GetInt32(3),
            reader.GetInt32(4), reader.GetDecimal(5), reader.GetDecimal(6), reader.GetDecimal(7),
            reader.GetInt32(8));
    }

    public async Task<CorporateRequestDetail?> FindAsync(Guid id, CancellationToken ct) =>
        await FindCoreAsync(id, null, ct, requireAccessToken: false);

    public async Task<object?> FindPublicAsync(Guid id, string? token, CancellationToken ct) =>
        await FindCoreAsync(id, token, ct, requireAccessToken: true) is { } request
            ? new { request.Id, request.CustomerName, request.CompanyName, request.Status, statusTitle = CorporateRequestStatuses.Title(request.Status), request.CreatedAt, request.UpdatedAt }
            : null;

    private async Task<CorporateRequestDetail?> FindCoreAsync(Guid id, string? token, CancellationToken ct, bool requireAccessToken)
    {
        if (!IsConfigured || (requireAccessToken && string.IsNullOrWhiteSpace(token))) return null;
        const string selectSql = """
            select id,customer_name,company_name,mobile,email,city,occasion,order_quantity,package_type,budget,delivery_date,custom_packaging,description,logo_key,proforma_key,status,assigned_to,next_follow_up_at,internal_note,created_at,updated_at,package_code,package_snapshot
            from corporate_requests
            where id=@id
            """;
        var sql = requireAccessToken ? $"{selectSql} and public_access_token=@token;" : $"{selectSql};";
        await using var connection = new NpgsqlConnection(connectionString); await connection.OpenAsync(ct); await using var command = new NpgsqlCommand(sql, connection); Add(command,"id",id);
        if (requireAccessToken) Add(command,"token",token!);
        await using var reader = await command.ExecuteReaderAsync(ct); if (!await reader.ReadAsync(ct)) return null; var detail = ReadDetail(reader); await reader.CloseAsync();
        detail = detail with { Events = await EventsAsync(connection, id, ct), Messages = await MessagesAsync(connection, id, ct) }; return detail;
    }

    public async Task<CorporateRequestStatusChangeResult> ChangeStatusAsync(Guid id, string status, string? note, string actor, CancellationToken ct)
    {
        if (!IsConfigured) return new(CorporateRequestStatusChangeKind.NotFound);
        await using var connection = new NpgsqlConnection(connectionString); await connection.OpenAsync(ct); await using var transaction = await connection.BeginTransactionAsync(ct);
        var previous = await ScalarStringAsync(connection, transaction, "select status from corporate_requests where id=@id for update", id, ct);
        if (previous is null)
        {
            await transaction.RollbackAsync(ct);
            return new(CorporateRequestStatusChangeKind.NotFound);
        }
        if (!CorporateRequestStatuses.CanTransition(previous, status))
        {
            await transaction.RollbackAsync(ct);
            return new(CorporateRequestStatusChangeKind.InvalidTransition);
        }
        await ExecuteAsync(connection, transaction, "update corporate_requests set status=@status,updated_at=now() where id=@id", ct, new("status",status), new("id",id));
        if (!string.Equals(previous, status, StringComparison.OrdinalIgnoreCase))
            await ExecuteAsync(connection, transaction, "insert into corporate_request_events(request_id,event_type,from_status,to_status,actor,note) values(@id,'status',@from,@to,@actor,@note)", ct, new("id",id), new("from",previous), new("to",status), new("actor",actor), new("note",(object?)note??DBNull.Value));
        await transaction.CommitAsync(ct);
        return new(CorporateRequestStatusChangeKind.Updated, await FindAsync(id, ct));
    }
    public Task<CorporateRequestDetail?> AssignAsync(Guid id, string? assignee, CancellationToken ct) => UpdateAndFindAsync(id, "update corporate_requests set assigned_to=@value,updated_at=now() where id=@id", new("value",(object?)assignee??DBNull.Value), ct);
    public Task<CorporateRequestDetail?> FollowUpAsync(Guid id, DateTimeOffset? value, CancellationToken ct) => UpdateAndFindAsync(id, "update corporate_requests set next_follow_up_at=@value,updated_at=now() where id=@id", new("value",(object?)value??DBNull.Value), ct);
    private async Task<CorporateRequestDetail?> UpdateAndFindAsync(Guid id, string sql, NpgsqlParameter value, CancellationToken ct) { await using var connection = new NpgsqlConnection(connectionString); await connection.OpenAsync(ct); await using var command = new NpgsqlCommand(sql, connection); command.Parameters.Add(value); command.Parameters.AddWithValue("id", id); return await command.ExecuteNonQueryAsync(ct)==0 ? null : await FindAsync(id, ct); }
    public async Task<bool> AddNoteAsync(Guid id, string note, string actor, CancellationToken ct) { if (string.IsNullOrWhiteSpace(note)) return false; return await ExecuteExistsAsync(id, "update corporate_requests set internal_note=@note,updated_at=now() where id=@id", ct, new NpgsqlParameter("note", note.Trim())); }
    public async Task<bool> AddMessageAsync(Guid id, CorporateRequestMessageInput input, CancellationToken ct) => await ExecuteExistsAsync(id, "insert into corporate_request_messages(request_id,sender_type,body,channel) select @id,'admin',@body,@channel where exists(select 1 from corporate_requests where id=@id)", ct, new NpgsqlParameter("body", input.Body.Trim()), new NpgsqlParameter("channel", input.Channel.Trim()));
    public async Task<bool> SetProformaAsync(Guid id, string key, string url, CancellationToken ct) => await ExecuteExistsAsync(id, "update corporate_requests set proforma_key=@key,updated_at=now() where id=@id", ct, new NpgsqlParameter("key", key));

    private async Task<bool> ExecuteExistsAsync(Guid id, string sql, CancellationToken ct, params NpgsqlParameter[] values) { await using var connection = new NpgsqlConnection(connectionString); await connection.OpenAsync(ct); await using var command = new NpgsqlCommand(sql, connection); command.Parameters.AddWithValue("id",id); foreach(var value in values) command.Parameters.Add(value); return await command.ExecuteNonQueryAsync(ct)>0; }
    private static async Task<string?> ScalarStringAsync(NpgsqlConnection c, NpgsqlTransaction t, string sql, Guid id, CancellationToken ct) { await using var command = new NpgsqlCommand(sql,c,t); command.Parameters.AddWithValue("id",id); return await command.ExecuteScalarAsync(ct) as string; }
    private static async Task ExecuteAsync(NpgsqlConnection c,NpgsqlTransaction t,string sql,CancellationToken ct,params NpgsqlParameter[] values) { await using var command=new NpgsqlCommand(sql,c,t); foreach(var value in values) command.Parameters.Add(value); await command.ExecuteNonQueryAsync(ct); }
    private static void Add(NpgsqlCommand command,string name,object value) => command.Parameters.AddWithValue(name,value);
    private static void AddTyped<T>(NpgsqlCommand command, string name, NpgsqlDbType type, T? value) where T : struct { var parameter = command.Parameters.Add(name, type); parameter.Value = value.HasValue ? value.Value : DBNull.Value; }
    private static CorporateRequestSummary ReadSummary(NpgsqlDataReader r) => new(r.GetGuid(0),r.GetString(1),r.GetString(2),r.GetString(3),r.GetString(4),r.GetString(5),r.GetInt32(6),r.GetString(7),r.GetString(8),r.IsDBNull(9)?null:r.GetString(9),r.IsDBNull(10)?null:r.GetFieldValue<DateTimeOffset>(10),r.GetFieldValue<DateTimeOffset>(11),r.GetFieldValue<DateTimeOffset>(12));
    private static CorporateRequestDetail ReadDetail(NpgsqlDataReader r) => new(r.GetGuid(0),r.GetString(1),r.GetString(2),r.GetString(3),r.IsDBNull(4)?null:r.GetString(4),r.GetString(5),r.GetString(6),r.GetInt32(7),r.GetString(8),r.IsDBNull(9)?null:r.GetDecimal(9),r.IsDBNull(10)?null:r.GetFieldValue<DateOnly>(10),r.GetBoolean(11),r.IsDBNull(12)?null:r.GetString(12),MediaPath(r.IsDBNull(13)?null:r.GetString(13)),MediaPath(r.IsDBNull(14)?null:r.GetString(14)),r.GetString(15),r.IsDBNull(16)?null:r.GetString(16),r.IsDBNull(17)?null:r.GetFieldValue<DateTimeOffset>(17),r.IsDBNull(18)?null:r.GetString(18),r.GetFieldValue<DateTimeOffset>(19),r.GetFieldValue<DateTimeOffset>(20),[],[],r.IsDBNull(21)?null:r.GetString(21),r.IsDBNull(22)?null:JsonSerializer.Deserialize<CorporatePackageSnapshot>(r.GetString(22)));
    private static string? MediaPath(string? key) => string.IsNullOrWhiteSpace(key) ? null : "/media/" + string.Join("/", key.Split('/').Select(Uri.EscapeDataString));
    private static async Task<IReadOnlyCollection<CorporateRequestEvent>> EventsAsync(NpgsqlConnection c,Guid id,CancellationToken ct) { const string sql="select id,event_type,from_status,to_status,actor,note,created_at from corporate_request_events where request_id=@id order by created_at desc"; await using var command=new NpgsqlCommand(sql,c); command.Parameters.AddWithValue("id",id); await using var r=await command.ExecuteReaderAsync(ct); var result=new List<CorporateRequestEvent>(); while(await r.ReadAsync(ct)) result.Add(new(r.GetGuid(0),r.GetString(1),r.IsDBNull(2)?null:r.GetString(2),r.IsDBNull(3)?null:r.GetString(3),r.GetString(4),r.IsDBNull(5)?null:r.GetString(5),r.GetFieldValue<DateTimeOffset>(6))); return result; }
    private static async Task<IReadOnlyCollection<CorporateRequestMessage>> MessagesAsync(NpgsqlConnection c,Guid id,CancellationToken ct) { const string sql="select id,sender_type,body,channel,created_at from corporate_request_messages where request_id=@id order by created_at desc"; await using var command=new NpgsqlCommand(sql,c); command.Parameters.AddWithValue("id",id); await using var r=await command.ExecuteReaderAsync(ct); var result=new List<CorporateRequestMessage>(); while(await r.ReadAsync(ct)) result.Add(new(r.GetGuid(0),r.GetString(1),r.GetString(2),r.GetString(3),r.GetFieldValue<DateTimeOffset>(4))); return result; }
}
