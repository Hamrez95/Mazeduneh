# Batch-backed selling prices

Admin → انبار → محاسبه قیمت فروش → select SKU/package and purchase → edit formula → پیش‌نمایش قیمت → اعمال قیمت فروش → confirm → inventory. Empty history directs to ثبت خرید. Failed inputs retain the form. Editing any input invalidates the previous preview; pending actions are disabled. Conflicting/stale prices require refresh and a new preview. A lost response may have committed: refresh before retrying. Success refreshes inventory and the catalog price. Inventory-read allows preview; applying requires both pricing.write and products.write. Read-only roles get a clear explanation and disabled Apply.

Amounts in API are rial, UI toman. Costs are per sellable package, not per kilogram. The most recent 250 receipts by purchase/receipt date are offered. Saved formula is reused; if its receipt is outside that window, the recent receipt is selected for a fresh preview. Bulk/raw-material inventory and full history pagination remain future #5 scope.

Server formula:

- packaging = round(packing fixed amount × packing multiplier + purchase cost × packing percentage / 100, 2).
- additional = round(additional fixed amount + purchase cost × additional percentage / 100, 2).
- total = purchase + packaging + additional.
- sale = ceil(total × (1 + markup / 100) / rounding step) × rounding step, rounded to two rial decimals.
- profit = sale − total; margin = profit / sale × 100.

Markup is a percentage of total cost; margin is a percentage of selling price. The price excludes order tax/shipping (existing server checkout settings apply separately). The selected receipt supplies purchase cost; clients cannot override it. Original receipts, batch actual costs and old order price/cost snapshots are never rewritten. The formula models estimated sale cost; accounting still uses original receipt allocation cost, not retroactively revised packaging estimates.

## API

GET `/api/v1/admin/inventory/pricing/{sku}` returns currentPrice, saved recipe and recent batches. POST `/{sku}/preview` takes recipe: batchId, packagingCost, packagingMultiplier, packagingPercent, additionalCost, additionalPercent, markupPercent, roundingStep. It returns purchaseCost, packagingCost, additionalCost, totalCost, sellingPrice, profit, marginPercent and does not mutate. POST `/{sku}/apply` takes `{recipe, expectedPrice}` and recomputes from the server receipt, locks the variant, validates expected price and writes price/costs, saved rule and audit in one transaction. Missing recipe/expectedPrice or invalid ranges: 400; missing SKU: 404 on GET; wrong receipt/nonpositive total/stale price: 409; missing permission: 403; no auth: 401; database unconfigured: 503. Exact same saved recipe/current price is a no-op without duplicate audit.

Migration inventory/004-pricing-rules adds variant_pricing_rules, FK to existing receipt and server-owned recipe JSON. Backward-compatible logical rollback leaves the table intact and restores the old API; historical receipts/order snapshots remain untouched. Every mutation audit records authenticated actor, timestamp/request ID and before/after price, costs and formula. Existing single-store boundary remains #99; this does not establish multi-tenant RLS. API-managed database tables must not be publicly exposed in Supabase Data API.

Catalog reads use the configured PostgreSQL source so a committed price appears on Storefront/Admin without restart, including across API instances. Checkout already locks/reads the DB price. Demo without a DB retains its existing in-memory catalog. Customer projections continue zeroing private costs.

## Validation

Pure C# unit checks validate decimal arithmetic, markup vs margin, upward rounding and input bounds. Real PostgreSQL/API gate checks preview no-op, stale/duplicate/no-op safety, persistence, permission combinations, audit, immediate Storefront price, Admin costs, original receipts and old/new order snapshots. Widget flow covers 360/768/1280px, 200% mobile text, preview invalidation, explicit confirmation, empty/error/forbidden states. Skills: frontend-design, accessibility-audit, lifecycle-architecture-review, Supabase security guidance. Graphify version/query/update unavailable (command not found); local dotnet/Flutter unavailable, runtime verified in CI before merge.
