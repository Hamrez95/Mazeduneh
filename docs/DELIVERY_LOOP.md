# Product delivery loop

Every vertical slice moves through the same evidence-driven loop. A slice is not complete merely because code was written.

## Round table

Each review applies these perspectives:

- Product manager: customer outcome, scope, acceptance criteria, metrics.
- Technical lead: architecture, security, maintainability, observability.
- Storefront developer: SEO, performance, accessibility, responsive behavior.
- API developer: domain invariants, idempotency, validation, tests.
- Flutter developer: adaptive UI, installability, notifications, offline behavior.
- UI/UX designer: hierarchy, Persian RTL quality, friction and accessibility.
- Brand/graphic designer: consistency, packaging compatibility, campaign assets.
- QA engineer: happy paths, edge cases, regression and device coverage.
- Growth/marketing: acquisition, trust, conversion and retention.
- Sales manager: promotions, bundles, corporate orders and customer objections.
- Warehouse operator: receiving, picking, packing, waste and stock accuracy.
- Accountant: purchase cost, sales, refunds, reconciliation and audit trail.
- Dried-fruit specialist: grade, origin, freshness, storage, allergens and shelf life.
- Scrum facilitator: WIP limits, blockers, review cadence and retrospective actions.

## Loop

1. **Discover:** define the customer/job, business rule, risk and measurable success.
2. **Design:** map journey, states, data, error handling and acceptance criteria.
3. **Build:** implement the smallest end-to-end slice behind safe configuration.
4. **Verify:** automated checks, manual exploratory tests, responsive and accessibility checks.
5. **Critique:** round-table review records objections and evidence, not preferences alone.
6. **Correct:** fix release-blocking findings and document accepted trade-offs.
7. **Measure:** observe real behavior on staging/production and feed evidence into the backlog.

## Definition of done

- Acceptance criteria demonstrated.
- Unit/integration/widget checks pass.
- Sensitive operations are authorized and audited.
- Empty, loading, success and failure states exist.
- Mobile, tablet and desktop behavior is reviewed where relevant.
- Persian wording and RTL layout are reviewed.
- Operational instructions and rollback are documented.
- No high-severity security or data-integrity finding remains.

## Release gates

- `feat/*` → pull request → `dev` after review and green CI.
- Staging release from `dev` for end-to-end validation.
- Release candidate PR from `dev` to `main`.
- `main` is tagged only after payment, order, inventory and backup smoke tests pass.
