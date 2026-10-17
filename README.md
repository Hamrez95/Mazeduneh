# MAZEDUNEH

MAZEDUNEH is a modern commerce platform for premium nuts, dried fruits, gifts, and healthy snacks.

## اجرای محلی و اولویت فعلی

فروشگاه و پنل در **مرورگر دسکتاپ** اولویت نسخهٔ اول هستند. `start-local.cmd` را اجرا کنید؛ PostgreSQL قابل حمل، API و دو رابط وب از همین checkout راه‌اندازی می‌شوند. Docker و ابزار موبایل لازم نیستند. [راهنمای اجرا، ترتیب توسعه و پذیرش سرور](docs/BROWSER_FIRST_DELIVERY.md).

## Product surfaces

- **Storefront:** SEO-first, responsive Next.js web application for customers.
- **Admin:** Flutter browser application; native apps deferred until after the web release.
- **API:** ASP.NET Core modular monolith.
- **Data:** PostgreSQL with an auditable stock ledger.

## Local development

### Windows: browser apps without Docker or SQL Server

On a fresh Windows PC, double-click `setup-local.cmd` once. It installs missing tools using winget and the official Flutter repository, then starts the system. Subsequent runs use `start-local.cmd`. Internet is required for the first downloads and dependency setup.

The launcher runs portable PostgreSQL, applies tracked migrations, seeds a local Owner and sample catalog, then opens the storefront and admin browser apps. The default ports are 3000, 8080 and 5080. Existing unrelated listeners are reported instead of stopped. Credentials and persistent data live under `%LOCALAPPDATA%/Mazeduneh/local`; a different drive can be selected with `-LocalHome` and `-RuntimeHome`.

```powershell
pwsh -File ./scripts/local.ps1 -Action status
pwsh -File ./scripts/local.ps1 -Action stop
pwsh -File ./scripts/local.ps1 -Action restart
pwsh -File ./scripts/install-desktop-shortcuts.ps1
```

Stopping preserves database and media files. The default `scripts/dev.ps1` path uses this same native browser stack and the current checkout. Admin compiles to web; Android Studio and native app build tools are unnecessary. Local sandbox payment has an explicit confirmation button and does not move money. See [full setup and delivery flow](docs/BROWSER_FIRST_DELIVERY.md).

### Optional container path (Windows, macOS, Linux)

`pwsh -File ./scripts/stack.ps1` remains available with a working Docker engine and Compose. Its status/stop commands, data volumes and credentials belong to that optional container environment. It is separate from the default native Windows launcher; stop one environment before using the other on the same ports.

### Storefront order submission

Set `NEXT_PUBLIC_MAZEDUNEH_API_URL` in the storefront build environment to the public HTTPS origin of the API. Configure the API's `Cors__AllowedOrigins__0` with the storefront origin (for example, `https://mazedoone-storefront-preview.vercel.app`) and use PostgreSQL for durable order and inventory data. Live products carry their server SKU; preview-only cart lines stay blocked instead of creating an invalid order. A submitted order remains `AwaitingPayment` until Zibal verifies it server-side. See [`docs/ZIBAL_PAYMENT.md`](docs/ZIBAL_PAYMENT.md) for the required production settings.

### Liara deployment preparation

Docker deployment files and the controlled launch checklist are in [`docs/LIARA_DEPLOYMENT.md`](docs/LIARA_DEPLOYMENT.md) and [`docs/RELEASE_READINESS.md`](docs/RELEASE_READINESS.md). CI builds all three production container images; deployment remains separate until a host, staging data services, secrets, and domains are configured.

## Branching

- `main`: stable and release-ready only.
- Feature branches: short-lived changes reviewed and checked, then merged into `main` by pull request.
- Preserve existing branches until their work is accounted for; branch deletion is deferred by the owner.

## Delivery loop

1. Plan and define acceptance criteria.
2. Implement a vertical product slice.
3. Run automated checks and manual review.
4. Critique from product, UX, technical, sales, warehouse, accounting, and domain perspectives.
5. Fix gaps and repeat until the release gate is met.

## Documentation

- `docs/PRODUCT_VISION.md`
- `docs/ARCHITECTURE.md`
- `docs/DESIGN_SYSTEM.md`
- `docs/BUSINESS_OPERATIONS.md`
- `docs/DELIVERY_LOOP.md`
- `docs/ROADMAP.md`
- `docs/ZIBAL_PAYMENT.md`

## Status

Implemented slices are merged into `main`. Browser acceptance and the controlled staging/payment/backup gates still determine launch readiness.

