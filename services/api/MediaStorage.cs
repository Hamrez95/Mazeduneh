using Microsoft.AspNetCore.Http;

public sealed record StoredMedia(string FileName, string Url, string ContentType, long SizeBytes);

public sealed class MediaStorage(IConfiguration configuration)
{
    private const long MaxBytes = 8 * 1024 * 1024;
    private static readonly IReadOnlyDictionary<string, string> AllowedTypes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        ["image/jpeg"] = ".jpg",
        ["image/png"] = ".png",
        ["image/webp"] = ".webp",
        ["image/avif"] = ".avif"
    };

    private string RootPath => configuration["Media:RootPath"] is { Length: > 0 } configured
        ? Path.GetFullPath(configured)
        : Path.Combine(AppContext.BaseDirectory, "media");

    private string PublicPrefix => (configuration["Media:PublicPrefix"] ?? "/media").TrimEnd('/');

    public async Task<StoredMedia> SaveAsync(IFormFile file, CancellationToken cancellationToken)
    {
        if (file.Length <= 0) throw new InvalidDataException("فایل تصویر خالی است.");
        if (file.Length > MaxBytes) throw new InvalidDataException("حجم تصویر نباید بیشتر از ۸ مگابایت باشد.");
        if (!AllowedTypes.TryGetValue(file.ContentType, out var extension))
            throw new InvalidDataException("فرمت مجاز تصویر فقط JPG، PNG، WEBP یا AVIF است.");

        Directory.CreateDirectory(RootPath);
        var safeName = $"{Guid.NewGuid():N}{extension}";
        var destination = Path.Combine(RootPath, safeName);

        await using var stream = File.Create(destination);
        await file.CopyToAsync(stream, cancellationToken);
        return new StoredMedia(safeName, $"{PublicPrefix}/{safeName}", file.ContentType, file.Length);
    }

    public string? Resolve(string fileName)
    {
        var safeName = Path.GetFileName(fileName);
        if (!string.Equals(safeName, fileName, StringComparison.Ordinal) || string.IsNullOrWhiteSpace(safeName))
            return null;

        var path = Path.Combine(RootPath, safeName);
        return File.Exists(path) ? path : null;
    }
}
