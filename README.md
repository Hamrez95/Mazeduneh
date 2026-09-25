# MAZEDUNEH

MAZEDUNEH is a modern commerce platform for premium nuts, dried fruits, gifts, and healthy snacks.

## Product surfaces

- **Storefront:** SEO-first, responsive Next.js web application for customers.
- **Admin:** Flutter application targeting Android and installable web/PWA.
- **API:** ASP.NET Core modular monolith.
- **Data:** PostgreSQL with an auditable stock ledger.

## Local development

### One-command Windows launcher

```powershell
./scripts/dev.ps1
```

You can also run one component:

```powershell
./scripts/dev.ps1 -Component storefront
./scripts/dev.ps1 -Component api
./scripts/dev.ps1 -Component admin
```

### Manual commands

```bash
cd apps/storefront
npm install
npm run dev
```

```bash
cd services/api
dotnet watch run
```

```bash
cd apps/admin
flutter create --platforms=android,web --project-name mazeduneh_admin .
flutter pub get
flutter run -d chrome
```

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
