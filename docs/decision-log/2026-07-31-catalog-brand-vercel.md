# MAZEDUNEH decision log — 2026-07-31

This document records product decisions and their rationale. It is intentionally a concise decision record, not private chain-of-thought.

## Participants represented

Product management, technical leadership, Next.js, ASP.NET Core, Flutter, UX/UI, graphic design, QA, marketing, sales, warehouse operations, accounting, Scrum facilitation, and dried-fruit domain expertise.

## D-001 — Separate customer and admin deployments

**Decision:** Use two Vercel projects:

- `mazeduneh-storefront`: customer-facing commerce experience.
- `mazeduneh-admin`: installable admin preview/PWA.

**Why:** Independent domains, release cycles, access controls, environment variables, caching, and rollback.

**Current project IDs:**

- Storefront: `prj_Gkh0CfVrt9BdYRkDBk5gW1qB5VsZ`
- Admin: `prj_M0WzOLw6olcdpGs2XtVSzz77CwDJ`

**Current boundary:** Deployed previews are review environments. Real orders and financial operations remain disabled until API, database, authentication, payment verification, and stock invariants are production-ready.

## D-002 — Product units

A product owns one base unit type:

- `Weight`: base unit is gram.
- `Count`: base unit is piece.

Each sellable package is an independent variant with:

- SKU
- quantity in the base unit
- customer-facing label
- selling price
- available package count

Examples:

- Pistachio: 250 g, 500 g, and 1000 g variants.
- Protein cookie: one piece, four-piece pack, and eight-piece pack variants.

Inventory is tracked per sellable variant. This avoids mixing physical units and supports independent pricing and stock.

## D-003 — Database without another Supabase project

**Decision:** Do not create a duplicate Supabase account or delete an unrelated project.

Development will use PostgreSQL through Docker. Production will use a managed PostgreSQL provider selected close to pilot launch. The API remains provider-neutral.

**Why:** No vendor lock-in, no immediate cost, clear migration path, and separation from the user's other Supabase projects.

## D-004 — Brand direction

The first identity system uses:

- dark botanical green for trust and premium quality;
- warm cream for food and hospitality;
- pistachio green, apricot, peach, and lilac as pastel campaign colors;
- an abstract seed/leaf symbol incorporating the Persian letter `ن`.

The mark must remain recognizable at favicon and app-icon sizes. The current SVG is a testable identity direction, not yet the final print-master package.

## D-005 — Educational development log

For every meaningful loop, record:

1. problem and user outcome;
2. alternatives considered;
3. decision and rationale;
4. implementation evidence;
5. review findings by discipline;
6. corrections and remaining risks.

Raw private reasoning is not published. Decisions, evidence, assumptions, and trade-offs are published.

## Next release slice

1. Persist products and variants in PostgreSQL.
2. Implement admin product creation for Weight and Count units.
3. Consume the catalog API from the storefront.
4. Add product-detail and variant-selection journeys.
5. Add automated API validation tests.
6. Replace preview-only Vercel deployments with repository-driven deployments.
