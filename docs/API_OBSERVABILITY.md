# API request correlation and safe completion logs

Issue #100. Every API response exposes a server-owned `X-Request-ID`; sensitive-operation audit records already use the same `HttpContext.TraceIdentifier`. Incoming `X-Request-ID` values do not replace it. Responses written by the ASP.NET Problem Details service also include `requestId`. Minimal API validation results can bypass that service, so `X-Request-ID` is the canonical correlation contract for every response, including validation failures.

The API emits JSON console logs. Its `HttpRequestCompleted` event (ID 1000) contains only:

| Field | Meaning |
| --- | --- |
| `RequestId` | Server-generated ID shared with response and audit |
| `Method` | HTTP method |
| `Route` | Endpoint route template, e.g. `/api/v1/products/{slug}`; `(unmatched)` for no endpoint |
| `StatusCode` | Result status; 499 for client cancellation, 500 for an unhandled exception |
| `ElapsedMilliseconds` | Total pipeline time |

The completion event never records raw paths, entity/SKU values, query strings, IP addresses, Authorization headers, cookies, request/response bodies or provider errors. Other application logs inherit the request-ID scope. Existing framework log levels are retained. This is correlation infrastructure; delivery to a remote log store, alert thresholds, retention and review of all older domain log messages remain launch work.

CORS exposes `X-Request-ID` to the configured Storefront/Admin origins; allowed origins and authorization policies do not change. Correlation adds no endpoint, migration, persisted data or new permission. The server remains the source of financial and inventory data.

## Operator flow

1. When an operation fails, capture its `X-Request-ID` from the network response, or `requestId` from Problem Details. Avoid copying tokens, personal data or request bodies into support notes.
2. Search structured logs by `RequestId` to find route, status and duration. For stock adjustment/product publication/membership changes, search the Admin Audit screen for the same request ID.
3. Investigate the existing permission or dependency failure and safely retry through the original page. A correlation ID does not confer access to any record.

JSON output can be forwarded by the deployment platform to its existing log service. No paid service, collector credential or deployment is configured by this slice. Keep log storage access and retention appropriately restricted.

## Verification and rollback

After the Release build, run `python3 scripts/tests/api_observability.py` against the disposable CI database. Tests start the real API and verify 200/400/401/404 response IDs, CORS exposure, validation response headers, unique server IDs, JSON completion fields and the absence of a sentinel passed through body, route, query and headers. Existing checkout CI also asserts that an inventory-adjustment response ID equals its persisted Audit request ID.

Revert the slice to restore prior console formatting and remove the response header; existing audit data is unchanged.

Skills: lifecycle-architecture-review and vercel:deployments-cicd. No frontend or database change. Graphify version/build/query/update commands failed because the executable is absent; targeted search was used. dotnet is absent locally, so the real runtime contract must pass in GitHub CI before merge.
