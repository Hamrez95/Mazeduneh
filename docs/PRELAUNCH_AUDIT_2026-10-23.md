# Prelaunch audit — 2026-10-23

Base: `0d60e27e5b0222c63462dc933c63c21591635145` (main, after Google Admin sign-in #323).

## Fixes

- Storefront cart and checkout read active shipping rules and tax from the API. No live hardcoded shipping threshold or silent fallback to preview settings. Failed pricing loads block checkout and offer retry.
- Existing cart lines refresh their SKU price/stock from the live catalog. Other tabs synchronize cart changes. Payment confirmation clears persisted cart storage. Several variants of one product have distinct summary keys and labels.
- Persian and Arabic phone/postal input is normalized for the server. Persian phone input passes browser validation.
- Guest order tracking uses the existing browser receipt without exposing receipt tokens in links. It does not advertise unimplemented customer registration.
- Contact, returns, shipping, FAQ, privacy and terms now describe current operations. Telegram uses the supplied phone deep link; Bale offers the same number for copying/contact lookup. No fabricated Bale username or Instagram account, phone-call CTA or email address.
- Return copy covers spoilage, expiry and mismatch with published information, asks for order/photos/package retention, and preserves statutory rights. Actual business identity/address and jurisdiction-specific legal approval remain the owner's responsibility before publication.
- Sidebar count badges have bounded widths, including enlarged text; they no longer squeeze navigation labels vertically.
- Invalid JSON binding returns HTTP 400 instead of a misleading HTTP 500. Null nested variants/lines/shipping methods and invalid units/currency are rejected. Catalog/inventory/shipping/internal-cost money rejects precision that PostgreSQL would silently round.
- CI builds privacy fixtures before serving the API and includes the new checkout/accounting reconciliation contract.

## Evidence

All integration tests use disposable databases, synthetic customers, local sandbox payments and a separate local runtime directory. User data and credentials remain outside Git.

- API Release build and full unit harness passed.
- Admin analysis and all 214 Flutter tests passed (including badge layout at normal/doubled text size).
- Storefront TypeScript, six source/arithmetic contracts and production build passed.
- Live catalog browser contract passed at 360, 768 and 1280 pixels, including Persian checkout input and support/policy pages.
- Receipt browser contract passed at 360, 768 and 1280 pixels: server-confirmed success, cart clearing, reload, authorized download and failed/expired/cancelled states.
- Local PostgreSQL backup/restore passed into a separate empty database; row counts matched across all 34 public tables, including order and migration records. Source and backup were retained privately. This is not a real-server recovery drill.
- Real PostgreSQL reconciliation passed: two weights, tax, nondefault shipping, forged totals ignored, concurrent checkout replay, repeated payment confirmation, stock reservation, internal costs, analytics quantities/revenue/profit, invoice privacy and invalid inputs.
- Real PostgreSQL contracts passed for initial stock, purchasing, batch prices, inventory adjustments, advanced promotions, corporate planning, dashboard preferences, notification permissions, order privacy, request observability, membership and owner MFA.

A successful build/test is evidence for that path, not proof that every screen or a future hosting environment has been accepted. Final PR CI and merge revision must be checked separately.

## Git reconciliation

- Remote fetch configuration referenced a deleted branch; restored normal all-branch fetching.
- Completed remote slices are represented by merged PRs. Closed superseded PRs are not merged a second time.
- Original dirty worktrees were snapshotted under ignored `.local-dev/prelaunch-review/20261023` before review. Exact copies/already-applied patches need no duplicate commit; older dashboard/order/formatting snippets are superseded by current main. Original personal files were preserved.
- No branch deleted. No reset of the original checkout. No changes under `sources/`. GitHub identity: `Hamrez95`.

## Remaining release gates

1. Exact final main SHA must have green required CI and owner browser acceptance.
2. Real payment merchant settings and end-to-end gateway success/decline/callback verification remain external setup.
3. After explicit owner approval: provision server, HTTPS/domain, production secrets/database/media storage, automated backups and restore drill, monitoring/alerts and rollback. These cannot be honestly marked verified on a local machine. See `RELEASE_READINESS.md`.
4. Replace demo/test catalog data using an explicit reviewed launch procedure; do not clear existing local data during this audit.
5. Confirm public business details and legal policies before publication. Optional Google login requires the owner's OAuth configuration; password login remains available.

No server deployment is authorized by this audit. Issues #244 and #100 retain owner acceptance and real-server gates.
