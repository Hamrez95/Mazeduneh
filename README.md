# MAZEDUNEH

MAZEDUNEH is a modern commerce platform for premium nuts, dried fruits, gifts, and healthy snacks.

## Product surfaces

- **Storefront:** SEO-first, responsive Next.js web application for customers.
- **Admin:** Flutter application targeting Android and installable web/PWA.
- **API:** ASP.NET Core modular monolith.
- **Data:** PostgreSQL with an auditable stock ledger.

## Local development

### Local demo on Windows

```powershell
pwsh -File ./scripts/dev.ps1
```

The launcher runs the latest fetched `origin/main` in an ignored detached worktree, so a developer's current branch and uncommitted work remain untouched. It starts the persistent local PostgreSQL Compose service, then the API, storefront, and secure Admin web entry point. Everything listens on `127.0.0.1`; it does not use Supabase, Cloudflare, Vercel, Liara, or a production account. The API connects to that PostgreSQL instance and applies its existing compatible migrations; it does not drop or reset data.

Use these commands from the repository root:

```powershell
pwsh -File ./scripts/dev.ps1 -Status
pwsh -File ./scripts/dev.ps1 -Stop
pwsh -File ./scripts/dev.ps1 -CurrentBranch -NoBrowser
```

The admin login is printed when the launcher starts. Its random local-demo password is stored in the ignored `.local-dev` folder so it remains the same between runs. Keep this launcher bound to this computer; it is not a public deployment setup.

To run only the storefront or API, use `-Component storefront` or `-Component api`. `-Component admin` starts both the API and admin app; `-Component storefront` also starts the API. The default runs the latest fetched main. Use `-CurrentBranch` only when intentionally testing the current checkout.

Prerequisites: PowerShell 7.4+, Git, Docker Desktop with Compose, Node.js/npm, .NET 10 SDK, and Flutter stable. The launcher synchronizes npm and Flutter dependencies from their lockfiles, waits for PostgreSQL and API readiness, and prints the exact main SHA it runs. It never installs system tools automatically; when a required tool is missing it exits with the command to install or start it.

### Storefront order submission

Set `NEXT_PUBLIC_MAZEDUNEH_API_URL` in the storefront build environment to the public HTTPS origin of the API. Configure the API's `Cors__AllowedOrigins__0` with the storefront origin (for example, `https://mazedoone-storefront-preview.vercel.app`) and use PostgreSQL for durable order and inventory data. Live products carry their server SKU; preview-only cart lines stay blocked instead of creating an invalid order. A submitted order remains `AwaitingPayment` until a real payment provider is integrated and confirms payment server-side.

### Liara deployment preparation

Docker deployment files and the release checklist are in [`docs/LIARA_DEPLOYMENT.md`](docs/LIARA_DEPLOYMENT.md). Deploying remains separate until production data, secrets, domains, and Liara services are ready.

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

## Status

The platform foundation is on `dev`. `main` remains the stable release branch until production gates pass.

