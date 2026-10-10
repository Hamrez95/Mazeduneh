# Corporate planning queue

GET `/api/v1/admin/corporate-requests?needsPlanning=true` returns active requests missing a nonblank assigned owner OR a next-follow-up timestamp. Finalized and Cancelled requests are excluded. The optional flag defaults to false. Existing search, status, city, date and quantity filters still intersect the queue. Combining `needsPlanning=true` with `overdue=true` returns validation 400; malformed boolean values return 400. Authentication and the existing `corporate.read` endpoint permission remain required (401/403).

The predicate is evaluated in the existing database query. No table, migration, financial computation or new mutation is introduced. Existing assignment and follow-up endpoints remain the source of truth; completing both fields removes the request after refresh. Tenant isolation and mutation audit enhancements remain separate outstanding work in #99/#91.

## Admin journey

Enter **فروش سازمانی**, choose **نیازمند برنامه‌ریزی**, open a request and use the existing owner and next-follow-up controls. Return to the list and refresh after saving. The queue and overdue switches are mutually exclusive. Empty-state copy explains completion and recommends removing the filter to review all requests. Existing loading, authorization, retry and detail success states are reused. This prevents unassigned opportunities from disappearing between customer inquiry and eventual order conversion; it does not create an order or estimate profit.

## Validation

`corporate_planning.py` exercises the real API and disposable CI PostgreSQL: missing fields, whitespace owner, terminal exclusion, combined filters, existing assignment/follow-up flow, restart persistence, 400/401/403 and overdue regression. Flutter contract/widget tests verify parameters, mutually exclusive filters and empty copy at 360/768/1280px, keyboard search and 200% mobile text. All three CI jobs must pass before merge.

Skills: frontend-design, accessibility-audit, lifecycle-architecture-review and deployments-cicd for the CI gate. Graphify version/query/update are unavailable in this executor (`command not found`); inspection used the relevant real repository files. Local dotnet/Flutter are unavailable; CI supplies runtime validation.
