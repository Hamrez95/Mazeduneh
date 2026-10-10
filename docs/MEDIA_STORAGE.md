# Media storage

The API exposes one media contract for development and production:

- `Media:Provider=Local` stores generated keys under `Media:RootPath` for local development.
- `Media:Provider=S3` uses an S3-compatible bucket and never exposes a local filesystem path.
- Upload: `POST /api/v1/admin/media` with an authenticated multipart field named `file`.
- Download: `GET /media/{key}`.
- Metadata: `GET /api/v1/admin/media/metadata/{key}`.
- Delete: `DELETE /api/v1/admin/media/{key}`.

Production environment variables use the normal .NET configuration mapping:

```
Media__Provider=S3
Media__S3__Endpoint=https://...
Media__S3__Bucket=...
Media__S3__Region=...
Media__S3__AccessKey=...
Media__S3__SecretKey=...
Media__S3__ForcePathStyle=true
```

The API generates the object key and returns a stable API URL. Credentials are never read from source-controlled files and the numeric/product data contracts remain unchanged.
