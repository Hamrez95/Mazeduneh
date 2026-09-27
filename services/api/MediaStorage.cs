using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;
using System.Text.RegularExpressions;

public sealed record StoredMedia(string FileName, string Url, string ContentType, long SizeBytes, string Key);
public sealed record MediaContent(Stream Content, string FileName, string ContentType, long SizeBytes, string? ETag);
public sealed record MediaMetadata(string FileName, string ContentType, long SizeBytes, string? ETag);

public sealed class MediaStorageOptions
{
    public string Provider { get; set; } = "Local";
    public string RootPath { get; set; } = Path.Combine(AppContext.BaseDirectory, "media");
    public string PublicPrefix { get; set; } = "/media";
    public string PublicBaseUrl { get; set; } = string.Empty;
    public long MaxBytes { get; set; } = 8 * 1024 * 1024;
    public S3MediaStorageOptions S3 { get; set; } = new();
}

public sealed class S3MediaStorageOptions
{
    public string Endpoint { get; set; } = string.Empty;
    public string Bucket { get; set; } = string.Empty;
    public string Region { get; set; } = "us-east-1";
    public string AccessKey { get; set; } = string.Empty;
    public string SecretKey { get; set; } = string.Empty;
    public bool ForcePathStyle { get; set; } = true;
}

public sealed class MediaStorageConfigurationException(string message) : Exception(message);
public sealed class MediaStorageValidationException(string message) : Exception(message);

public interface IMediaStorageProvider
{
    Task PutAsync(string key, Stream content, string contentType, long sizeBytes, CancellationToken cancellationToken);
    Task<MediaContent?> GetAsync(string key, CancellationToken cancellationToken);
    Task<MediaMetadata?> GetMetadataAsync(string key, CancellationToken cancellationToken);
    Task<bool> DeleteAsync(string key, CancellationToken cancellationToken);
}

public static class MediaStorageContentTypes
{
    private static readonly IReadOnlyDictionary<string, string> Allowed = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["image/jpeg"] = ".jpg",
        ["image/png"] = ".png",
        ["image/webp"] = ".webp",
        ["image/avif"] = ".avif"
    };

    public static bool TryGetExtension(string? contentType, out string extension) =>
        contentType is not null && Allowed.TryGetValue(contentType.Trim(), out extension!);

    public static string FromKey(string key) =>
        Path.GetExtension(key).ToLowerInvariant() switch
        {
            ".png" => "image/png",
            ".webp" => "image/webp",
            ".avif" => "image/avif",
            _ => "image/jpeg"
        };
}

public static class MediaStorageExtensions
{
    public static IServiceCollection AddMediaStorage(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<MediaStorageOptions>(configuration.GetSection("Media"));
        services.AddSingleton<IMediaStorageProvider>(serviceProvider =>
        {
            var options = serviceProvider.GetRequiredService<IOptions<MediaStorageOptions>>().Value;
            return options.Provider.Trim().ToLowerInvariant() switch
            {
                "local" or "" => new LocalMediaStorageProvider(options),
                "s3" or "s3-compatible" => new S3CompatibleMediaStorageProvider(options),
                _ => throw new MediaStorageConfigurationException(
                    $"Media:Provider مقدار ناشناخته‌ای دارد: {options.Provider}. مقدار مجاز Local یا S3 است.")
            };
        });
        services.AddSingleton<MediaStorage>();
        return services;
    }

    public static void MapMediaStorage(this WebApplication app)
    {
        app.MapPost("/api/v1/admin/media", async Task<IResult> (
            HttpRequest request,
            MediaStorage storage,
            CancellationToken cancellationToken) =>
        {
            if (!request.HasFormContentType)
                return Results.BadRequest(new { message = "درخواست باید شامل فایل تصویر باشد." });

            try
            {
                var form = await request.ReadFormAsync(cancellationToken);
                var file = form.Files.GetFile("file");
                if (file is null)
                    return Results.BadRequest(new { message = "فایل تصویر ارسال نشده است." });

                var stored = await storage.SaveAsync(file, cancellationToken);
                return Results.Created(stored.Url, stored);
            }
            catch (MediaStorageValidationException exception)
            {
                return Results.BadRequest(new { message = exception.Message });
            }
            catch (MediaStorageConfigurationException exception)
            {
                return Results.Problem(
                    title: "ذخیره‌سازی رسانه پیکربندی نشده است.",
                    detail: exception.Message,
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }
        })
        .AddEndpointFilter<OwnerAuthorizationFilter>()
        .WithTags("Admin Media");

        app.MapGet("/media/{**key}", async Task<IResult> (
            string key,
            HttpContext context,
            MediaStorage storage,
            CancellationToken cancellationToken) =>
        {
            try
            {
                var media = await storage.GetAsync(key, cancellationToken);
                if (media is null) return Results.NotFound();

                context.Response.Headers.CacheControl = "public, max-age=31536000, immutable";
                context.Response.Headers["X-Content-Type-Options"] = "nosniff";
                context.Response.Headers.ContentDisposition = $"inline; filename=\"{media.FileName}\"";
                return Results.Stream(media.Content, media.ContentType, enableRangeProcessing: true);
            }
            catch (MediaStorageValidationException)
            {
                return Results.NotFound();
            }
            catch (MediaStorageConfigurationException exception)
            {
                return Results.Problem(
                    title: "ذخیره‌سازی رسانه پیکربندی نشده است.",
                    detail: exception.Message,
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }
        })
        .WithTags("Media");

        app.MapGet("/api/v1/admin/media/metadata/{**key}", async Task<IResult> (
            string key,
            MediaStorage storage,
            CancellationToken cancellationToken) =>
        {
            try
            {
                var metadata = await storage.GetMetadataAsync(key, cancellationToken);
                return metadata is null ? Results.NotFound() : Results.Ok(metadata);
            }
            catch (MediaStorageValidationException)
            {
                return Results.NotFound();
            }
            catch (MediaStorageConfigurationException exception)
            {
                return Results.Problem(
                    title: "ذخیره‌سازی رسانه پیکربندی نشده است.",
                    detail: exception.Message,
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }
        })
        .AddEndpointFilter<OwnerAuthorizationFilter>()
        .WithTags("Admin Media");

        app.MapDelete("/api/v1/admin/media/{**key}", async Task<IResult> (
            string key,
            MediaStorage storage,
            CancellationToken cancellationToken) =>
        {
            try
            {
                return await storage.DeleteAsync(key, cancellationToken)
                    ? Results.NoContent()
                    : Results.NotFound();
            }
            catch (MediaStorageValidationException)
            {
                return Results.NotFound();
            }
            catch (MediaStorageConfigurationException exception)
            {
                return Results.Problem(
                    title: "ذخیره‌سازی رسانه پیکربندی نشده است.",
                    detail: exception.Message,
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }
        })
        .AddEndpointFilter<OwnerAuthorizationFilter>()
        .WithTags("Admin Media");
    }
}

public sealed class MediaStorage(IOptions<MediaStorageOptions> options, IMediaStorageProvider provider)
{
    private static readonly Regex SafeKey = new("^[A-Za-z0-9._/-]+$", RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private static readonly IReadOnlyDictionary<string, string> AllowedTypes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["image/jpeg"] = ".jpg",
        ["image/png"] = ".png",
        ["image/webp"] = ".webp",
        ["image/avif"] = ".avif"
    };

    private MediaStorageOptions Options => options.Value;

    public async Task<StoredMedia> SaveAsync(IFormFile file, CancellationToken cancellationToken)
    {
        if (file.Length <= 0) throw new MediaStorageValidationException("فایل تصویر خالی است.");
        if (file.Length > Options.MaxBytes) throw new MediaStorageValidationException($"حجم تصویر نباید بیشتر از {Options.MaxBytes / (1024 * 1024)} مگابایت باشد.");

        var contentType = file.ContentType?.Trim().ToLowerInvariant();
        if (!AllowedTypes.TryGetValue(contentType ?? string.Empty, out var extension))
            throw new MediaStorageValidationException("فرمت مجاز تصویر فقط JPG، PNG، WEBP یا AVIF است.");

        var key = $"products/{Guid.NewGuid():N}{extension}";
        await using var content = file.OpenReadStream();
        await provider.PutAsync(key, content, contentType!, file.Length, cancellationToken);
        return new StoredMedia(
            Path.GetFileName(key),
            BuildPublicUrl(key),
            contentType!,
            file.Length,
            key);
    }

    public Task<MediaContent?> GetAsync(string key, CancellationToken cancellationToken) =>
        provider.GetAsync(NormalizeKey(key), cancellationToken);

    public Task<MediaMetadata?> GetMetadataAsync(string key, CancellationToken cancellationToken) =>
        provider.GetMetadataAsync(NormalizeKey(key), cancellationToken);

    public Task<bool> DeleteAsync(string key, CancellationToken cancellationToken) =>
        provider.DeleteAsync(NormalizeKey(key), cancellationToken);

    private string NormalizeKey(string key)
    {
        var normalized = Uri.UnescapeDataString(key ?? string.Empty).Trim('/');
        if (string.IsNullOrWhiteSpace(normalized) ||
            normalized.Length > 512 ||
            normalized.Contains('\\') ||
            normalized.Split('/').Any(segment => segment is "" or "." or "..") ||
            !SafeKey.IsMatch(normalized))
            throw new MediaStorageValidationException("شناسهٔ رسانه نامعتبر است.");
        return normalized;
    }

    private string BuildPublicUrl(string key)
    {
        var encodedKey = string.Join("/", key.Split('/').Select(Uri.EscapeDataString));
        var baseUrl = Options.PublicBaseUrl.TrimEnd('/');
        return string.IsNullOrWhiteSpace(baseUrl)
            ? $"{Options.PublicPrefix.TrimEnd('/')}/{encodedKey}"
            : $"{baseUrl}/{encodedKey}";
    }
}

public sealed class LocalMediaStorageProvider(MediaStorageOptions options) : IMediaStorageProvider
{
    private string RootPath => Path.GetFullPath(string.IsNullOrWhiteSpace(options.RootPath)
        ? Path.Combine(AppContext.BaseDirectory, "media")
        : options.RootPath);

    public async Task PutAsync(string key, Stream content, string contentType, long sizeBytes, CancellationToken cancellationToken)
    {
        var path = ResolvePath(key);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        await using var destination = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None, 64 * 1024, useAsync: true);
        await content.CopyToAsync(destination, cancellationToken);
    }

    public Task<MediaContent?> GetAsync(string key, CancellationToken cancellationToken)
    {
        var path = ResolvePath(key);
        if (!File.Exists(path)) return Task.FromResult<MediaContent?>(null);

        var info = new FileInfo(path);
        Stream content = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 64 * 1024, useAsync: true);
        return Task.FromResult<MediaContent?>(new MediaContent(
            content,
            Path.GetFileName(path),
            MediaStorageContentTypes.FromKey(key),
            info.Length,
            null));
    }

    public Task<MediaMetadata?> GetMetadataAsync(string key, CancellationToken cancellationToken)
    {
        var path = ResolvePath(key);
        if (!File.Exists(path)) return Task.FromResult<MediaMetadata?>(null);

        var info = new FileInfo(path);
        return Task.FromResult<MediaMetadata?>(new MediaMetadata(
            info.Name,
            MediaStorageContentTypes.FromKey(key),
            info.Length,
            null));
    }

    public Task<bool> DeleteAsync(string key, CancellationToken cancellationToken)
    {
        var path = ResolvePath(key);
        if (!File.Exists(path)) return Task.FromResult(false);
        File.Delete(path);
        return Task.FromResult(true);
    }

    private string ResolvePath(string key)
    {
        var root = RootPath.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        var path = Path.GetFullPath(Path.Combine(RootPath, key.Replace('/', Path.DirectorySeparatorChar)));
        if (!path.StartsWith(root, StringComparison.OrdinalIgnoreCase))
            throw new MediaStorageValidationException("مسیر رسانه نامعتبر است.");
        return path;
    }
}

public sealed class S3CompatibleMediaStorageProvider : IMediaStorageProvider, IDisposable
{
    private readonly IAmazonS3 client;
    private readonly string bucket;

    public S3CompatibleMediaStorageProvider(MediaStorageOptions options)
    {
        var s3 = options.S3;
        if (string.IsNullOrWhiteSpace(s3.Endpoint) ||
            string.IsNullOrWhiteSpace(s3.Bucket) ||
            string.IsNullOrWhiteSpace(s3.AccessKey) ||
            string.IsNullOrWhiteSpace(s3.SecretKey))
            throw new MediaStorageConfigurationException(
                "برای Media:Provider=S3 باید Media:S3:Endpoint، Bucket، AccessKey و SecretKey تنظیم شوند.");

        bucket = s3.Bucket.Trim();
        var config = new AmazonS3Config
        {
            ServiceURL = s3.Endpoint.TrimEnd('/'),
            ForcePathStyle = s3.ForcePathStyle,
            AuthenticationRegion = string.IsNullOrWhiteSpace(s3.Region) ? "us-east-1" : s3.Region
        };
        client = new AmazonS3Client(s3.AccessKey, s3.SecretKey, config);
    }

    public async Task PutAsync(string key, Stream content, string contentType, long sizeBytes, CancellationToken cancellationToken)
    {
        await client.PutObjectAsync(new PutObjectRequest
        {
            BucketName = bucket,
            Key = key,
            InputStream = content,
            ContentType = contentType,
            ContentLength = sizeBytes,
            AutoCloseStream = false
        }, cancellationToken);
    }

    public async Task<MediaContent?> GetAsync(string key, CancellationToken cancellationToken)
    {
        try
        {
            var response = await client.GetObjectAsync(new GetObjectRequest { BucketName = bucket, Key = key }, cancellationToken);
            return new MediaContent(
                response.ResponseStream,
                Path.GetFileName(key),
                response.Headers.ContentType ?? MediaStorageContentTypes.FromKey(key),
                response.ContentLength,
                response.ETag);
        }
        catch (AmazonS3Exception exception) when (exception.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task<MediaMetadata?> GetMetadataAsync(string key, CancellationToken cancellationToken)
    {
        try
        {
            var response = await client.GetObjectMetadataAsync(new GetObjectMetadataRequest { BucketName = bucket, Key = key }, cancellationToken);
            return new MediaMetadata(
                Path.GetFileName(key),
                response.Headers.ContentType ?? MediaStorageContentTypes.FromKey(key),
                response.ContentLength,
                response.ETag);
        }
        catch (AmazonS3Exception exception) when (exception.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task<bool> DeleteAsync(string key, CancellationToken cancellationToken)
    {
        try
        {
            await client.DeleteObjectAsync(new DeleteObjectRequest { BucketName = bucket, Key = key }, cancellationToken);
            return true;
        }
        catch (AmazonS3Exception exception) when (exception.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return false;
        }
    }

    public void Dispose() => client.Dispose();
}
