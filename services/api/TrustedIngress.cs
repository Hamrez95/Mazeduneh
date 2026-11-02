using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

public static class TrustedIngress
{
    // Only the explicitly addressed local ingress may assert client IP or HTTPS.
    public static IServiceCollection AddTrustedIngress(this IServiceCollection services, IConfiguration configuration)
    {
        var addresses = configuration.GetSection("ReverseProxy:KnownProxies").Get<string[]>() ?? [];
        var proxies = addresses.Select(value => IPAddress.TryParse(value, out var address)
            ? address : throw new InvalidOperationException("ReverseProxy:KnownProxies must contain IP addresses.")).ToArray();
        services.Configure<ForwardedHeadersOptions>(options =>
        {
            options.ForwardedHeaders = proxies.Length == 0 ? ForwardedHeaders.None
                : ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
            options.ForwardLimit = 1;
            options.KnownProxies.Clear();
            options.KnownIPNetworks.Clear();
            foreach (var proxy in proxies) options.KnownProxies.Add(proxy);
        });
        return services;
    }
}
