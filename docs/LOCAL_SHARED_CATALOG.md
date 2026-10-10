# Local Admin and Storefront share one catalog

Run `pwsh -File ./scripts/dev.ps1` from the root. Storefront 3000 and active Admin (`lib/secure_main.dart`) 8080 read/write the API on 5080. The launcher and CI both use the secure entry point with session validation and the shared theme. No cloud deployment or data deletion occurs.

Admin → Products → edit title, price, images/specifications, description or publication → Save → reload the storefront or return focus to its tab. Home, Shop, header/footer category links and related products read the shared CatalogProvider. Published products with zero stock remain visible and cannot be added. Draft products are excluded by the public API. The public no-API preview preserves its sample presentation.

Configured API loading/failure/empty never falls back to demo products. Failed refresh retains only the last live catalog with a clear stale notice and keyboard-accessible retry. Requests abort/ignore older generations. Prices/inventory are verified on the server during checkout; this read model does not change accounting or stock.

Without PostgreSQL, API catalog changes are in memory and reset on API restart. Database-backed inventory/orders/settings still need a PostgreSQL connection. Models are in services/api/CatalogModels.cs; API is the source of catalog truth. Browser cart/favorites are not the catalog database. Product artwork/layout defaults are presentation; editable marketing content and store settings remain #98.

Validation: catalog state/adapter/fetch contracts; real authenticated API edit → public read/publication/privacy regression; Playwright home/shop/detail/related/admin-like edit/empty/error/stale/keyboard at 360/768/1280px. Local typecheck and contract tests pass. Local Chromium download returned a truncated ZIP; browser test runs in CI. Skills frontend-design, accessibility-audit, lifecycle-architecture-review. Graphify version/query/update unavailable, recorded rather than fabricated.
