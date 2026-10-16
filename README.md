# MAZEDUNEH

MAZEDUNEH is a modern commerce platform for premium nuts, dried fruits, gifts, and healthy snacks.

## Product surfaces

- **Storefront:** SEO-first, responsive Next.js web application for customers.
- **Admin:** Flutter application targeting Android and installable web/PWA.
- **API:** ASP.NET Core modular monolith.
- **Data:** PostgreSQL with an auditable stock ledger.

## Local development

### Run the whole system (Windows, macOS, Linux)

The quick path needs only **PowerShell 7.4+** and **Docker Desktop** (Windows/macOS), or Docker Engine with Compose (Linux). Node.js, .NET, Flutter, PostgreSQL, and app dependencies are installed inside the containers.

```powershell
git clone https://github.com/Hamrez95/Mazeduneh.git
cd Mazeduneh
pwsh -File ./scripts/stack.ps1
```

On Windows, you can double-click [`start-local.cmd`](start-local.cmd) instead. It starts the same full stack and prints a PowerShell 7.4 install command if PowerShell 7 is missing.

The first run builds all three apps, starts PostgreSQL, applies migrations, and creates a local Admin account. The default addresses are Storefront `http://127.0.0.1:3000`, Admin `http://127.0.0.1:8080`, and API `http://127.0.0.1:5080`; if one is already in use, the launcher selects the next available local port and prints the actual addresses. The generated Admin password is printed once per run and saved under the ignored `.local-dev` folder.

```powershell
pwsh -File ./scripts/stack.ps1 -Action status
pwsh -File ./scripts/stack.ps1 -Action stop
```

Stopping removes app containers but keeps the PostgreSQL database and uploaded media. To reset demo data, use Docker Desktop to remove the `mazeduneh` volumes explicitly.

This stack binds every published port to `127.0.0.1`, uses a local PostgreSQL volume, and enables sandbox payments. It does not connect to a production account or external database. Never reuse its credentials or settings for production.

On Windows, if Docker reports that its engine cannot start, enable **Intel VT-x/Intel Virtualization Technology** (or **AMD-V/SVM**) in BIOS/UEFI, turn on **Windows Subsystem for Linux** and **Virtual Machine Platform**, and restart Windows. The launcher detects disabled firmware virtualization and prints this specific recovery path. macOS and Linux users need a running Docker engine with Compose.

### Host-based development

For faster hot reload while editing, `scripts/dev.ps1` can run the app processes directly on the host. This path also needs Node.js 24, the .NET 10 SDK, Flutter stable, and Docker for PostgreSQL. It uses a detached copy of `origin/main` by default; add `-CurrentBranch` only when you intend to run the current checkout.

```powershell
pwsh -File ./scripts/dev.ps1 -Status
pwsh -File ./scripts/dev.ps1 -Stop
pwsh -File ./scripts/dev.ps1 -CurrentBranch -NoBrowser
pwsh -File ./scripts/dev.ps1 -Component storefront-preview -NoBrowser
```

The host-based launcher synchronizes npm and Flutter dependencies from their lockfiles, waits for PostgreSQL and API readiness, and leaves PostgreSQL data intact when app processes stop. `storefront-preview` can browse sample products without Docker/API, but cannot submit real orders or start Admin.

### Storefront order submission

Set `NEXT_PUBLIC_MAZEDUNEH_API_URL` in the storefront build environment to the public HTTPS origin of the API. Configure the API's `Cors__AllowedOrigins__0` with the storefront origin (for example, `https://mazedoone-storefront-preview.vercel.app`) and use PostgreSQL for durable order and inventory data. Live products carry their server SKU; preview-only cart lines stay blocked instead of creating an invalid order. A submitted order remains `AwaitingPayment` until Zibal verifies it server-side. See [`docs/ZIBAL_PAYMENT.md`](docs/ZIBAL_PAYMENT.md) for the required production settings.

### Liara deployment preparation

Docker deployment files and the controlled launch checklist are in [`docs/LIARA_DEPLOYMENT.md`](docs/LIARA_DEPLOYMENT.md) and [`docs/RELEASE_READINESS.md`](docs/RELEASE_READINESS.md). CI builds all three production container images; deployment remains separate until a host, staging data services, secrets, and domains are configured.

## Branching

- `main`: stable and release-ready only.
- `dev`: integration branch.
- `feat/*`, `fix/*`, `chore/*`: short-lived branches merged into `dev` by pull request.

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

The platform foundation is on `dev`. `main` remains the stable release branch until production gates pass.

