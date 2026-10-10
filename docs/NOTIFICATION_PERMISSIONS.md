# Notification API domain permissions

Issues #96 and #91. `GET /api/v1/admin/notifications` still requires an authenticated session and `dashboard.read`. Its response is now projected on the server using the signed `AdminPrincipal` from the shared authorization filter:

| Granted permission | Returned notices and counts |
| --- | --- |
| `orders.read` | `awaiting-payment`, `new-orders`, and the real `awaitingPayment` count |
| `inventory.read` | `low-stock` and the real `lowStockItems` count |
| Neither domain permission | Empty `items`, zero counts; neither domain query is executed |
| Owner | Existing full response |
| No session | 401 |
| Session without `dashboard.read` | 403 |

The JSON schema remains `{ awaitingPayment, lowStockItems, items: [{ type, title, detail }] }`. An unauthorized count is zero, not an estimate; clients should interpret it only in the context of their granted domains. Permissions are derived server-side; no request query/body can opt into hidden domains. Inventory titles/SKUs and order counts are not loaded for a caller without the corresponding read permission. Unknown future domains must add their own explicit permission projection.

This is a read-only endpoint, so no mutation audit, before/after data or migration is needed. Sensitive writes keep their existing audit trail. Request completion uses the shared request-ID logging contract. No money or stock quantity is calculated in the client.

## QA

`python3 scripts/tests/notification_permissions.py` runs against the disposable CI PostgreSQL database after the Release build. It creates one draft low-stock fixture and one pending test order through the API, then starts separate API processes with Owner, dashboard-only, order-only, inventory-only, combined and no-dashboard permission sets. Assertions cover positive notices, exact response schema, hidden counts, no leaked inventory marker, Owner regression and 401/403. Fixtures are confined to the ephemeral CI database; no payment is initiated.

No schema changes. Rollback by reverting this slice restores the previous projection; it reopens the visibility gap for roles with dashboard access. This does not implement store isolation or membership-backed login; #91/#99 remain open for those controls. Notifications are still aggregate queue notices.

Skills: lifecycle-architecture-review (permission boundary and small reversible slice), vercel:deployments-cicd (runtime contract in CI). No frontend change. Graphify version/query/update is unavailable in the executor; targeted search was used. dotnet is unavailable locally; runtime validation must pass CI before merge.
