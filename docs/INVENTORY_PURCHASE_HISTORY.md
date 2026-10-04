# Complete receipt history

Inventory → سوابق خرید و تاریخ انقضا → مشاهده خریدهای قدیمی‌تر. The first 50 receipts are shown by recording time descending. Older pages remain reachable; the purchase date is displayed separately, so backdating does not hide a newly recorded purchase. New records appear on refresh. Expired and depleted receipts remain historical evidence. Records survive deletion of their catalog SKU, with a clear deleted-product fallback label.

GET `/api/v1/admin/inventory/purchases?sku=<optional>&limit=50&cursor=<optional>` returns `{items,nextCursor}`. Limit 1–250; invalid cursor/range returns 400. Cursor is an opaque encoded timestamp/UUID boundary, not a credential. Every request requires inventory.read; SKU filter is applied on every page. Newly inserted receipts do not shift older-page boundaries. Legacy batches endpoint/FEFO ordering remains compatible. Migration inventory/005-purchase-pagination adds two indexes only; logical rollback retains them.

More-page errors retain already loaded records and offer retry; authorization failures clear private history. Full refresh invalidates any pending page response. Duplicate client rows are excluded. Reading history never changes stock/cost/price. The saved pricing selector still offers its recent 250 purchase-date candidates; this history is independently traversable beyond that limit.

Checks: cursor unit validation, real API insertion-between-pages/restart/validation/authorization regression, Admin keyboard activation and retry at 360/768/1280px with 200% mobile text. Skills frontend-design/accessibility-audit/lifecycle-architecture-review/Supabase guidance. Graphify version/query/update unavailable; local dotnet/Flutter unavailable, runtime gates are CI.

## SKU filter and concurrent refresh

In Inventory → purchase history, «خریدهای کدام کالا؟» selects a product/variant SKU or «همهٔ کالاها». The server applies the selection to the first and every older page; changing it resets the cursor. Historical receipts for deleted catalog products remain visible through All. A selected deleted SKU keeps a fallback option. Empty results explain how to switch to All or register a purchase. Stock and movements remain store-wide; only purchase history is filtered.

Refresh generation also protects the first-page result/error/loading status: an older concurrent refresh cannot replace newer data. No new endpoint, migration or mutation. Widget coverage checks selection and next-page SKU at 360/768/1280px, 200% text on mobile, and late failed refresh. API contract verifies a different SKU cannot read receipts through another SKU’s cursor. Graphify version/query/update unavailable in executor; skills frontend-design/accessibility-audit/lifecycle-architecture-review.
