# Order contact privacy (#169 B)

Server authorization is required even for direct HTTP requests. JSON shape and ASP.NET hosting configuration stay compatible; privacy is applied only to admin response projections, never to stored records or public receipt-token routes.

| Route | Required permissions | Without `customers.pii.read` |
| --- | --- | --- |
| list/detail | orders.read | Names, phones, province/city/address/postcode masked; tracking/payment references removed; internal notes omitted; transition actors/reasons masked |
| shipping/overdue | orders.read | Contact and tracking fields masked |
| export.csv | orders.read + orders.export | Masked rows; contact search disabled |
| invoice/packing-slip | orders.read + orders.documents.read + customers.pii.read | 403, including trailing-slash routes |
| mutations | orders.write | Existing operation remains authorized; returned summaries/details/notes projected through the same policy |

Order ID search stays available to read-only roles. Name/mobile/city search requires contact access. Operational states, amounts, line items, dates and transition states remain visible.

| Default role | Contacts in orders | CSV | Documents |
| --- | --- | --- | --- |
| Owner, StoreManager | full | yes | yes |
| SalesOperator, CustomerSupport | full | no | yes |
| WarehouseOperator | full | no | yes |
| Accountant | masked | yes (masked) | no |
| ReadOnlyAnalyst | masked | no | no |
| Other roles | only if orders.read is granted | only with export permission | only with all document permissions |

Warehouse contact access supports address labels and fulfillment; it does not grant access to the customer directory, which still requires customers.read. Role overrides must carry every listed permission. Documents without contacts would be unusable, so they are forbidden rather than rendered deceptively.

Validation: API unit projections with PII-bearing notes/timeline/payment/overdue fixtures; direct HTTP list/detail/search/CSV/invoice/packing-slip/401/403/404 tests in scripts/tests/order_privacy.py. The latter uses only the disposable CI database. Flutter action visibility test complements server checks.

Rollout has no migration. Rollback must keep document/export/contact restrictions in place; do not restore the leaking release. Restrict affected endpoints if an emergency rollback is required.
