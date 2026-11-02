using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

internal static class TrustedIngressFixture
{
    public static async Task RunAsync()
    {
        await VerifyAsync("172.30.21.2", ["172.30.21.2"], "https", "203.0.113.5");
        await VerifyAsync("172.30.21.3", ["172.30.21.2"], "http", "172.30.21.3");
        await VerifyAsync("172.30.21.2", [], "http", "172.30.21.2");
        try
        {
            new ServiceCollection().AddTrustedIngress(Configuration(["not-an-ip"]));
            throw new Exception("Malformed trusted proxy was accepted.");
        }
        catch (InvalidOperationException) { }
        Console.WriteLine("Trusted ingress: HTTPS/client IP, spoof rejection, default-off and malformed configuration passed.");
    }

    private static IConfiguration Configuration(string[] proxies) => new ConfigurationBuilder()
        .AddInMemoryCollection(proxies.Select((address, index) =>
            new KeyValuePair<string, string?>($"ReverseProxy:KnownProxies:{index}", address))).Build();

    private static async Task VerifyAsync(string peer, string[] proxies, string scheme, string client)
    {
        using var services = new ServiceCollection().AddLogging().AddTrustedIngress(Configuration(proxies)).BuildServiceProvider();
        var options = services.GetRequiredService<IOptions<ForwardedHeadersOptions>>();
        var middleware = new ForwardedHeadersMiddleware(_ => Task.CompletedTask,
            services.GetRequiredService<ILoggerFactory>(), options);
        var request = new DefaultHttpContext();
        request.Connection.RemoteIpAddress = IPAddress.Parse(peer);
        request.Request.Scheme = "http";
        request.Request.Headers["X-Forwarded-For"] = "203.0.113.5";
        request.Request.Headers["X-Forwarded-Proto"] = "https";
        await middleware.Invoke(request);
        if (request.Request.Scheme != scheme || request.Connection.RemoteIpAddress?.ToString() != client)
            throw new Exception("Trusted ingress boundary produced an unexpected client identity.");
    }
}
