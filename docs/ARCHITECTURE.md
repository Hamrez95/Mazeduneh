# Architecture baseline

## Applications

- `apps/storefront`: Next.js App Router storefront, RTL-first and SEO-first.
- `apps/admin`: Flutter responsive admin targeting Android and web/PWA.
- `services/api`: ASP.NET Core modular monolith.

## Backend modules

- Identity and access
- Catalog
- Pricing and promotions
- Cart
- Orders
- Payments
- Shipping
- Inventory
- Customers
- Reviews
- Notifications
- Reporting
- Audit

Modules share one deployable process in MVP but own their domain rules and persistence boundaries.

## Data

- PostgreSQL is the source of truth.
- Product media uses S3-compatible object storage.
- Redis is optional for distributed caching and short-lived reservations; it is not a source of truth.
- Inventory is represented by immutable stock movements plus calculated balances.

## Critical invariants

- Money uses decimal values and an explicit currency.
- Payment callback data is never trusted without server-to-server verification.
- Payment and order transitions are idempotent.
- Stock is reserved before redirecting to payment and released after expiration/failure.
- No inventory quantity is changed without a stock-ledger record.
- Administrative price, stock, refund, and order-state changes are audited.

## Environments

- Local: Docker Compose.
- Staging: production-like data services with fake/sandbox payment.
- Production: separate secrets, database, object storage, and monitoring.

`main` contains only release-ready code. `dev` is the integration branch. Features enter `dev` through reviewed pull requests.
