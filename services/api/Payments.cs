using System.Security.Cryptography;
using System.Text;
using Npgsql;

public static class PaymentModule
{
    public static IServiceCollection AddPayments(this IServiceCollection services)
    {
        services.AddSingleton<PaymentDatabase>();
        services.AddHostedService<PaymentSchemaInitializer>();
        return services;
    }

    public static IEndpointRouteBuilder MapPayments(this IEndpointRouteBuilder endpoints)
    {
        var payments = endpoints.MapGroup("/api/v1/payments").WithTags("Payments");

        payments.MapPost("/orders/{orderId:guid}/intent", async (
            Guid orderId,
            PaymentIntentRequest request,
            PaymentDatabase database,
            CancellationToken cancellationToken) =>
        {
            var result = await database.CreateIntentAsync(orderId, request.ReceiptToken, cancellationToken);
            return result.Status switch
            {
                PaymentOperationStatus.Created => Results.Created($"/api/v1/payments/sandbox/{result.Payment!.Authority}", result.Payment),
                PaymentOperationStatus.Replayed => Results.Ok(result.Payment),
                PaymentOperationStatus.Disabled => Results.Problem(title: "پرداخت آزمایشی غیرفعال است.", statusCode: 503),
                PaymentOperationStatus.NotFound => Results.NotFound(new { message = result.Message }),
                _ => Results.Conflict(new { message = result.Message })
            };
        });

        payments.MapPost("/sandbox/{authority}/complete", async (
            string authority,
            SandboxPaymentCompleteRequest request,
            PaymentDatabase database,
            CancellationToken cancellationToken) =>
        {
            var result = await database.CompleteSandboxAsync(authority, request.ReceiptToken, cancellationToken);
            return result.Status switch
            {
                PaymentOperationStatus.Succeeded or PaymentOperationStatus.Replayed => Results.Ok(result.Payment),
                PaymentOperationStatus.Disabled => Results.Problem(title: "پرداخت آزمایشی غیرفعال است.", statusCode: 503),
                PaymentOperationStatus.NotFound => Results.NotFound(new { message = result.Message }),
                _ => Results.Conflict(new { message = result.Message })
            };
        });

        return endpoints;
    }
}

public sealed class PaymentDatabase(IConfiguration configuration, ILogger<PaymentDatabase> logger)
{
    private readonly string? _connectionString = configuration.GetConnectionString("Catalog");
    private readonly bool _sandboxEnabled = configuration.GetValue("Payments:SandboxEnabled", false);

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);
    public bool SandboxEnabled => _sandboxEnabled && IsConfigured;

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return;
        const string sql = """
            create table if not exists payments (
                id uuid primary key,
                order_id uuid not null unique references checkout_orders(id) on delete restrict,
                provider varchar(32) not null,
                authority varchar(100) not null unique,
                amount numeric(18,2) not null check (amount >= 0),
                currency varchar(3) not null,
                state varchar(24) not null check (state in ('Pending','Succeeded')),
                reference text null,
                created_at timestamptz not null,
                completed_at timestamptz null
            );
            create index if not exists ix_payments_state_created on payments(state, created_at);
            """;
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync(cancellationToken);
        logger.LogInformation("Payment PostgreSQL schema is ready; sandbox enabled: {Enabled}.", SandboxEnabled);
    }

    public async Task<PaymentOperationResult> CreateIntentAsync(
        Guid orderId,
        string receiptToken,
        CancellationToken cancellationToken)
    {
        if (!SandboxEnabled) return PaymentOperationResult.Disabled();
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        var order = await LoadOrderForUpdateAsync(connection, transaction, orderId, cancellationToken);
        if (order is null || !TokenEquals(order.Value.ReceiptToken, receiptToken))
        {
            await transaction.RollbackAsync(cancellationToken);
            return PaymentOperationResult.NotFound("سفارش یا مجوز رسید پیدا نشد.");
        }

        if (order.Value.State == OrderState.Paid)
        {
            var completed = await FindByOrderAsync(connection, transaction, orderId, cancellationToken);
            await transaction.RollbackAsync(cancellationToken);
            return completed is null
                ? PaymentOperationResult.Conflict("سفارش پرداخت شده اما رکورد پرداخت پیدا نشد.")
                : PaymentOperationResult.Replayed(completed);
        }

        if (order.Value.State != OrderState.AwaitingPayment || order.Value.ReservationExpiresAt <= DateTimeOffset.UtcNow)
        {
            await transaction.RollbackAsync(cancellationToken);
            return PaymentOperationResult.Conflict("این سفارش دیگر امکان پرداخت ندارد یا رزرو آن منقضی شده است.");
        }

        var existing = await FindByOrderAsync(connection, transaction, orderId, cancellationToken);
        if (existing is not null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return PaymentOperationResult.Replayed(existing);
        }

        var now = DateTimeOffset.UtcNow;
        var payment = new PaymentRecord(
            Guid.NewGuid(), orderId, "Sandbox", Convert.ToHexString(RandomNumberGenerator.GetBytes(18)).ToLowerInvariant(),
            order.Value.Payable, order.Value.Currency, PaymentState.Pending, null, now, null);

        const string sql = """
            insert into payments (id,order_id,provider,authority,amount,currency,state,reference,created_at,completed_at)
            values (@id,@order_id,@provider,@authority,@amount,@currency,@state,null,@created_at,null);
            """;
        await using (var command = new NpgsqlCommand(sql, connection, transaction))
        {
            command.Parameters.AddWithValue("id", payment.Id);
            command.Parameters.AddWithValue("order_id", payment.OrderId);
            command.Parameters.AddWithValue("provider", payment.Provider);
            command.Parameters.AddWithValue("authority", payment.Authority);
            command.Parameters.AddWithValue("amount", payment.Amount);
            command.Parameters.AddWithValue("currency", payment.Currency);
            command.Parameters.AddWithValue("state", payment.State.ToString());
            command.Parameters.AddWithValue("created_at", payment.CreatedAt);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return PaymentOperationResult.Created(payment);
    }

    public async Task<PaymentOperationResult> CompleteSandboxAsync(
        string authority,
        string receiptToken,
        CancellationToken cancellationToken)
    {
        if (!SandboxEnabled) return PaymentOperationResult.Disabled();
        if (string.IsNullOrWhiteSpace(authority)) return PaymentOperationResult.NotFound("شناسه پرداخت پیدا نشد.");

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        var payment = await FindByAuthorityForUpdateAsync(connection, transaction, authority.Trim(), cancellationToken);
        if (payment is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return PaymentOperationResult.NotFound("شناسه پرداخت پیدا نشد.");
        }

        var order = await LoadOrderForUpdateAsync(connection, transaction, payment.OrderId, cancellationToken);
        if (order is null || !TokenEquals(order.Value.ReceiptToken, receiptToken))
        {
            await transaction.RollbackAsync(cancellationToken);
            return PaymentOperationResult.NotFound("سفارش یا مجوز رسید پیدا نشد.");
        }

        if (payment.State == PaymentState.Succeeded && order.Value.State == OrderState.Paid)
        {
            await transaction.RollbackAsync(cancellationToken);
            return PaymentOperationResult.Replayed(payment);
        }

        if (order.Value.State != OrderState.AwaitingPayment || order.Value.ReservationExpiresAt <= DateTimeOffset.UtcNow)
        {
            await transaction.RollbackAsync(cancellationToken);
            return PaymentOperationResult.Conflict("رزرو سفارش منقضی شده یا سفارش دیگر قابل پرداخت نیست.");
        }

        if (payment.Amount != order.Value.Payable || !string.Equals(payment.Currency, order.Value.Currency, StringComparison.Ordinal))
        {
            await transaction.RollbackAsync(cancellationToken);
            logger.LogError("Payment amount mismatch for order {OrderId}.", order.Value.Id);
            return PaymentOperationResult.Conflict("مبلغ پرداخت با مبلغ سفارش تطبیق ندارد.");
        }

        var now = DateTimeOffset.UtcNow;
        var reference = $"SANDBOX-{now:yyyyMMddHHmmss}-{payment.Id.ToString("N")[..8]}";
        const string updatePayment = """
            update payments set state='Succeeded', reference=@reference, completed_at=@completed_at
            where id=@id and state='Pending';
            """;
        await using (var command = new NpgsqlCommand(updatePayment, connection, transaction))
        {
            command.Parameters.AddWithValue("id", payment.Id);
            command.Parameters.AddWithValue("reference", reference);
            command.Parameters.AddWithValue("completed_at", now);
            var changed = await command.ExecuteNonQueryAsync(cancellationToken);
            if (changed != 1)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PaymentOperationResult.Conflict("وضعیت پرداخت هم‌زمان تغییر کرده است؛ دوباره وضعیت را بررسی کنید.");
            }
        }

        await using (var command = new NpgsqlCommand(
            "update checkout_orders set state='Paid' where id=@id and state='AwaitingPayment';", connection, transaction))
        {
            command.Parameters.AddWithValue("id", order.Value.Id);
            var changed = await command.ExecuteNonQueryAsync(cancellationToken);
            if (changed != 1)
            {
                await transaction.RollbackAsync(cancellationToken);
                return PaymentOperationResult.Conflict("سفارش هم‌زمان تغییر کرده است؛ دوباره وضعیت را بررسی کنید.");
            }
        }

        await using (var command = new NpgsqlCommand(
            "insert into checkout_order_transitions (id,order_id,state,actor,occurred_at,reason) values (@id,@order_id,'Paid','payment-sandbox',@at,'sandbox-payment-verified');",
            connection, transaction))
        {
            command.Parameters.AddWithValue("id", Guid.NewGuid());
            command.Parameters.AddWithValue("order_id", order.Value.Id);
            command.Parameters.AddWithValue("at", now);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return PaymentOperationResult.Succeeded(payment with
        {
            State = PaymentState.Succeeded,
            Reference = reference,
            CompletedAt = now
        });
    }

    private static async Task<OrderPaymentSnapshot?> LoadOrderForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid orderId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            select id,receipt_token,payable,currency,state,reservation_expires_at
            from checkout_orders where id=@id for update;
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("id", orderId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new OrderPaymentSnapshot(reader.GetGuid(0), reader.GetString(1), reader.GetDecimal(2), reader.GetString(3),
            Enum.Parse<OrderState>(reader.GetString(4)), reader.GetFieldValue<DateTimeOffset>(5));
    }

    private static async Task<PaymentRecord?> FindByOrderAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid orderId,
        CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            "select id,order_id,provider,authority,amount,currency,state,reference,created_at,completed_at from payments where order_id=@order_id;",
            connection, transaction);
        command.Parameters.AddWithValue("order_id", orderId);
        return await ReadPaymentAsync(command, cancellationToken);
    }

    private static async Task<PaymentRecord?> FindByAuthorityForUpdateAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string authority,
        CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            "select id,order_id,provider,authority,amount,currency,state,reference,created_at,completed_at from payments where authority=@authority for update;",
            connection, transaction);
        command.Parameters.AddWithValue("authority", authority);
        return await ReadPaymentAsync(command, cancellationToken);
    }

    private static async Task<PaymentRecord?> ReadPaymentAsync(NpgsqlCommand command, CancellationToken cancellationToken)
    {
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new PaymentRecord(reader.GetGuid(0), reader.GetGuid(1), reader.GetString(2), reader.GetString(3),
            reader.GetDecimal(4), reader.GetString(5), Enum.Parse<PaymentState>(reader.GetString(6)),
            reader.IsDBNull(7) ? null : reader.GetString(7), reader.GetFieldValue<DateTimeOffset>(8),
            reader.IsDBNull(9) ? null : reader.GetFieldValue<DateTimeOffset>(9));
    }

    private static bool TokenEquals(string expectedToken, string? suppliedToken)
    {
        var expected = Encoding.UTF8.GetBytes(expectedToken);
        var supplied = Encoding.UTF8.GetBytes(suppliedToken ?? string.Empty);
        return expected.Length == supplied.Length && CryptographicOperations.FixedTimeEquals(expected, supplied);
    }

    private readonly record struct OrderPaymentSnapshot(Guid Id, string ReceiptToken, decimal Payable, string Currency,
        OrderState State, DateTimeOffset ReservationExpiresAt);
}

public sealed class PaymentSchemaInitializer(PaymentDatabase database) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken) => database.InitializeAsync(cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

public sealed record PaymentIntentRequest(string ReceiptToken);
public sealed record SandboxPaymentCompleteRequest(string ReceiptToken);
public enum PaymentState { Pending, Succeeded }
public enum PaymentOperationStatus { Created, Succeeded, Replayed, Disabled, NotFound, Conflict }
public sealed record PaymentRecord(Guid Id, Guid OrderId, string Provider, string Authority, decimal Amount,
    string Currency, PaymentState State, string? Reference, DateTimeOffset CreatedAt, DateTimeOffset? CompletedAt);

public sealed record PaymentOperationResult(
    PaymentOperationStatus Status,
    PaymentRecord? Payment = null,
    string? Message = null)
{
    public static PaymentOperationResult Created(PaymentRecord payment) => new(PaymentOperationStatus.Created, payment);
    public static PaymentOperationResult Succeeded(PaymentRecord payment) => new(PaymentOperationStatus.Succeeded, payment);
    public static PaymentOperationResult Replayed(PaymentRecord payment) => new(PaymentOperationStatus.Replayed, payment);
    public static PaymentOperationResult Disabled() => new(PaymentOperationStatus.Disabled);
    public static PaymentOperationResult NotFound(string message) => new(PaymentOperationStatus.NotFound, Message: message);
    public static PaymentOperationResult Conflict(string message) => new(PaymentOperationStatus.Conflict, Message: message);
}
