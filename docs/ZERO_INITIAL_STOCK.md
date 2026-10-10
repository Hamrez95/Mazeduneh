# Zero initial stock — catalog regression

Issue #2. A product or newly added variant can validly start with zero available packages. The catalog previously recorded an `InitialStock` movement for that zero amount, violating the existing `stock_movements.quantity_delta <> 0` constraint and rolling back the transaction with a 500 response.

Both product creation and adding a variant now use one shared opening-stock helper:

- Save the variant and its zero balance in the existing catalog transaction.
- Record an InitialStock movement only when the opening quantity is nonzero.
- Preserve positive initial stock movements, their existing actor/reason and the nonzero ledger constraint.
- Receive later stock through the existing inventory adjustment/receiving flow, with server validation and audit actor/before/after.

No schema or migration change is required. The API contracts and permissions remain unchanged: authorized product create/update accepts zero stock; negative stock is rejected; draft products remain hidden from public catalog. Zero stock is represented by the variant balance, without an invented ledger movement. Money and stock remain server-owned.

## Admin flow

Products → new draft → enter package/SKU/price with quantity zero → save. Add further packages from the same product editor. The draft appears in Admin; receive actual stock through Inventory when it arrives. Successful save uses the existing UI state and returns to the product list/editor. Existing field validation, error/retry and forbidden states are unchanged; no new frontend component or text is introduced.

## Regression gate

CI starts the real API against its disposable PostgreSQL database and verifies:

1. Product creation with mixed zero and positive opening stock returns 201.
2. Zero opening stock has no ledger row; positive opening stock has one InitialStock row.
3. Adding another zero-stock variant succeeds and editing does not duplicate opening movements.
4. Receiving five units on the initially empty SKU creates one audited movement with the real actor.
5. Negative opening stock returns 400.
6. After API restart, all three variant balances and movement counts persist; draft stays private.

Run `python3 scripts/tests/catalog_initial_stock.py` after the Release build against the ephemeral CI environment. No payment is made. Revert the helper to roll back code; no data needs rollback, but zero-stock creation would fail again.

Skills: lifecycle-architecture-review and vercel:deployments-cicd. No frontend or Supabase change. Graphify version/query/update was unavailable; targeted code search traced the validator, catalog transaction and ledger constraint. dotnet is absent locally; all runtime/build checks must pass GitHub CI before merge.
