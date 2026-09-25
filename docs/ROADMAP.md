# MAZEDUNEH roadmap

## Milestone 0 — Product and platform foundation

- Monorepo, branch policy and CI.
- Product vision, architecture, design system and operational model.
- Responsive storefront concept.
- Responsive Flutter admin dashboard concept.
- API health and catalog vertical slice.

## Milestone 1 — Sellable catalog

- PostgreSQL persistence and migrations.
- Categories, products, variants, images and publish workflow.
- Search, filters, SEO metadata and structured product data.
- Admin product creation/editing with validation and image upload.
- Supplier, batch, grade, origin, allergens and storage metadata.

## Milestone 2 — Cart, checkout and order lifecycle

- Server-owned cart and price calculation.
- Address, shipping rules, coupons and final totals.
- Payment request, callback verification, idempotency and reconciliation.
- Order state machine, customer notifications and tracking.
- Stock reservation and release.

## Milestone 3 — Warehouse and fulfillment

- Immutable stock ledger.
- Receiving by supplier batch and purchase cost.
- Picking, packing, shipment handoff, waste, return and adjustment.
- Low-stock alerts and mobile warehouse flows.
- Printable invoice, packing slip and shipping label integration points.

## Milestone 4 — Reporting and commercial tools

- Sales, margin, order, inventory, waste and customer reports.
- Discount campaigns, bundles, free-shipping thresholds and gift packs.
- Corporate quote/order flow.
- Export to CSV/XLSX and accounting integration boundary.

## Milestone 5 — Production readiness

- Authentication, roles, MFA for privileged users and audit logs.
- Backups, monitoring, alerting, rate limiting and secret management.
- Accessibility, performance and security testing.
- Staging deployment, controlled real-order pilot and release checklist.

## Post-launch

- Verified reviews, wish lists and buy-again.
- Abandoned-cart communication with consent.
- Loyalty/referral and subscriptions after repeat-demand evidence.
- Native customer app only when usage data justifies it.
