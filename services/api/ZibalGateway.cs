using System.Net.Http.Json;

public sealed class ZibalGateway(HttpClient client, IConfiguration configuration, ILogger<ZibalGateway> logger)
{
    private readonly string _merchant = configuration["Payments:Zibal:Merchant"]?.Trim() ?? string.Empty;
    private readonly string _callbackUrl = configuration["Payments:Zibal:CallbackUrl"]?.Trim() ?? string.Empty;
    private readonly string _returnUrl = configuration["Payments:Zibal:ReturnUrl"]?.Trim() ?? string.Empty;

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(_merchant) &&
        IsPublicHttpsUrl(_callbackUrl) &&
        IsPublicHttpsUrl(_returnUrl);

    public async Task<ZibalRequestResult> RequestAsync(PaymentOrderSnapshot order, CancellationToken cancellationToken)
    {
        var payload = new ZibalRequest(
            _merchant,
            decimal.ToInt64(decimal.Round(order.Payable, 0, MidpointRounding.AwayFromZero)),
            _callbackUrl,
            $"سفارش مزه‌دونه {order.Id:N}",
            order.Id.ToString("N"),
            order.Mobile);
        try
        {
            using var response = await client.PostAsJsonAsync("/v1/request", payload, cancellationToken);
            var body = await response.Content.ReadFromJsonAsync<ZibalResponse>(cancellationToken: cancellationToken);
            if (!response.IsSuccessStatusCode || body is null || body.Result != 100 || body.TrackId is null || body.TrackId.Value <= 0)
            {
                logger.LogWarning("Zibal payment request was rejected with HTTP {StatusCode} and result {Result}.", (int)response.StatusCode, body?.Result);
                return ZibalRequestResult.Failed();
            }
            return ZibalRequestResult.Succeeded(body.TrackId.Value.ToString());
        }
        catch (HttpRequestException exception)
        {
            logger.LogWarning(exception, "Zibal payment request could not reach the gateway.");
            return ZibalRequestResult.Failed();
        }
        catch (TaskCanceledException exception) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(exception, "Zibal payment request timed out.");
            return ZibalRequestResult.Failed();
        }
        catch (System.Text.Json.JsonException exception)
        {
            logger.LogWarning(exception, "Zibal payment request returned an invalid response.");
            return ZibalRequestResult.Failed();
        }
    }

    public async Task<ZibalVerifyResult> VerifyAsync(string trackId, CancellationToken cancellationToken)
    {
        if (!long.TryParse(trackId, out var parsedTrackId) || parsedTrackId <= 0) return ZibalVerifyResult.Failed();
        try
        {
            using var response = await client.PostAsJsonAsync("/v1/verify", new ZibalVerifyRequest(_merchant, parsedTrackId), cancellationToken);
            var body = await response.Content.ReadFromJsonAsync<ZibalResponse>(cancellationToken: cancellationToken);
            if (response.IsSuccessStatusCode && body is not null)
            {
                var result = InterpretVerification(body);
                if (result.IsSuccess || result.IsFinalFailure) return result;
            }
            else
                logger.LogWarning("Zibal payment verification returned HTTP {StatusCode}.", (int)response.StatusCode);
        }
        catch (HttpRequestException exception)
        {
            logger.LogWarning(exception, "Zibal payment verification could not reach the gateway.");
        }
        catch (TaskCanceledException exception) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(exception, "Zibal payment verification timed out.");
        }
        catch (System.Text.Json.JsonException exception)
        {
            logger.LogWarning(exception, "Zibal payment verification returned an invalid response.");
        }
        return await InquireAsync(parsedTrackId, cancellationToken);
    }

    private async Task<ZibalVerifyResult> InquireAsync(long trackId, CancellationToken cancellationToken)
    {
        try
        {
            using var response = await client.PostAsJsonAsync("/v1/inquiry", new ZibalVerifyRequest(_merchant, trackId), cancellationToken);
            var body = await response.Content.ReadFromJsonAsync<ZibalResponse>(cancellationToken: cancellationToken);
            if (!response.IsSuccessStatusCode || body is null)
            {
                logger.LogWarning("Zibal payment inquiry returned HTTP {StatusCode}.", (int)response.StatusCode);
                return ZibalVerifyResult.Unconfirmed();
            }
            var result = InterpretVerification(body);
            if (!result.IsSuccess && !result.IsFinalFailure)
                logger.LogWarning("Zibal inquiry could not confirm payment; result {Result} and status {PaymentStatus}.", body.Result, body.Status);
            return result;
        }
        catch (HttpRequestException exception)
        {
            logger.LogWarning(exception, "Zibal payment inquiry could not reach the gateway.");
            return ZibalVerifyResult.Unconfirmed();
        }
        catch (TaskCanceledException exception) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(exception, "Zibal payment inquiry timed out.");
            return ZibalVerifyResult.Unconfirmed();
        }
        catch (System.Text.Json.JsonException exception)
        {
            logger.LogWarning(exception, "Zibal payment inquiry returned an invalid response.");
            return ZibalVerifyResult.Unconfirmed();
        }
    }

    private static ZibalVerifyResult InterpretVerification(ZibalResponse body)
    {
        if (body.Result != 100 || body.Status is null) return ZibalVerifyResult.Unconfirmed();
        if (body.Status == 1 && body.Amount is not null)
            return ZibalVerifyResult.Succeeded(body.Amount.Value, body.OrderId, body.RefNumber?.ToString());
        return body.Status == 1 ? ZibalVerifyResult.Unconfirmed() : ZibalVerifyResult.Declined(body.OrderId);
    }

    public string StartUrl(string trackId) => $"https://gateway.zibal.ir/start/{Uri.EscapeDataString(trackId)}";

    public string ReturnUrl(Guid orderId, string outcome) =>
        $"{_returnUrl.TrimEnd('/')}?payment={Uri.EscapeDataString(outcome)}&orderId={Uri.EscapeDataString(orderId.ToString("N"))}";


    private static bool IsPublicHttpsUrl(string value) => Uri.TryCreate(value, UriKind.Absolute, out var uri) && uri.Scheme == Uri.UriSchemeHttps;
}

public sealed record PaymentOrderSnapshot(Guid Id, string Mobile, decimal Payable, string Currency, OrderState State, DateTimeOffset ReservationExpiresAt);
public sealed record ZibalRequest(string Merchant, long Amount, string CallbackUrl, string Description, string OrderId, string Mobile);
public sealed record ZibalVerifyRequest(string Merchant, long TrackId);
public sealed record ZibalResponse(long? TrackId, int Result, string? Message, int? Status, long? Amount, long? RefNumber, string? OrderId);
public sealed record ZibalRequestResult(bool IsSuccess, string? TrackId)
{
    public static ZibalRequestResult Succeeded(string trackId) => new(true, trackId);
    public static ZibalRequestResult Failed() => new(false, null);
}
public sealed record ZibalVerifyResult(bool IsSuccess, bool IsFinalFailure, long Amount, string? OrderId, string? Reference)
{
    public static ZibalVerifyResult Succeeded(long amount, string? orderId, string? reference) => new(true, false, amount, orderId, reference);
    public static ZibalVerifyResult Declined(string? orderId) => new(false, true, 0, orderId, null);
    public static ZibalVerifyResult Unconfirmed() => new(false, false, 0, null, null);
    public static ZibalVerifyResult Failed() => new(false, false, 0, null, null);
}
