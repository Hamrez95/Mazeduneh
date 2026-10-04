using System.Diagnostics;

public sealed class RequestObservabilityMiddleware(
    RequestDelegate next, ILogger<RequestObservabilityMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        // Use the same server-owned identifier as sensitive-operation audit rows.
        // Do not trust an incoming correlation header as an audit identifier.
        var requestId = context.TraceIdentifier;
        context.Response.OnStarting(() =>
        {
            context.Response.Headers["X-Request-ID"] = requestId;
            return Task.CompletedTask;
        });
        var started = Stopwatch.GetTimestamp();
        var failed = false;
        try
        {
            await next(context);
        }
        catch
        {
            failed = true;
            throw;
        }
        finally
        {
            var status = context.RequestAborted.IsCancellationRequested ? 499
                : failed ? StatusCodes.Status500InternalServerError : context.Response.StatusCode;
            // Route templates contain no customer IDs, SKU values, query strings,
            // credentials, tokens, request bodies, headers, or remote addresses.
            var route = (context.GetEndpoint() as RouteEndpoint)?.RoutePattern.RawText ?? "(unmatched)";
            var elapsed = Math.Round(Stopwatch.GetElapsedTime(started).TotalMilliseconds, 2);
            logger.Log(status >= 500 ? LogLevel.Warning : LogLevel.Information,
                new EventId(1000, "HttpRequestCompleted"),
                "HTTP request completed {RequestId} {Method} {Route} {StatusCode} {ElapsedMilliseconds}",
                requestId, context.Request.Method, route, status, elapsed);
        }
    }
}
