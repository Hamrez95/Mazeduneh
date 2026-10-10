# API liveness and readiness

Issue: #100. These probes support traffic routing and dependency monitoring; they do not certify that the store is ready for a public launch.

| Endpoint | HTTP status | Purpose |
| --- | --- | --- |
| `GET /health/live` | 200 while the process serves requests | Liveness; no database I/O. Use for process restart checks. |
| `GET /health/ready` | 200 ready / 503 not ready | Traffic readiness; requires configured PostgreSQL, a readable nonempty migration ledger, and configured Admin authentication. |
| `GET /health` | 200 diagnostic response | Backward-compatible operational summary. Do not use its status code for traffic routing. |

All three endpoints are intentionally public, read-only, and do not change business data. Readiness/diagnostic responses use `Cache-Control: no-store`. No authentication token, connection string, provider error, customer data or SQL is returned. No migration or new permission is required.

Readiness response:

```json
{"status":"ready","database":"healthy","migrations":"tracked","adminAuthentication":"configured"}
```

Failure values:

- `database`: `not-configured` or `unhealthy`.
- `migrations`: `not-configured`, `unavailable`, or `empty`. `tracked` means the ledger can be read and contains entries; it does not independently verify every schema object or external migration release.
- `adminAuthentication`: `not-configured` when the configured email/password hash/signing key contract is incomplete.

The database probe has a three-second cancellation budget, including connection acquisition and ledger reads. Client cancellation propagates. Dependency failure is returned as 503 with safe status values; logs contain only the exception type. The legacy diagnostic endpoint returns a degraded summary instead of trying a second failed migration query.

## Operator flow

1. Configure the platform's restart probe as `/health/live`, and its traffic/deployment readiness probe as `/health/ready` over the service's configured HTTPS URL.
2. If readiness is 503, read the status fields. Check database connectivity and migration startup logs, or complete Admin environment settings in the secret store.
3. Leave the live process running during a database outage. Restore PostgreSQL and wait for readiness to return to 200.
4. Before promotion, also verify real storage upload/download, payment provider, backup/restore, domain/CORS and a synthetic order. These are separate launch gates and remain open in #100.

CI exercises the real API with missing database settings, incomplete Admin settings, PostgreSQL outage, live-process survival, safe diagnostic responses and database recovery without restarting the API. Run after the API Release build with `READINESS_POSTGRES_CONTAINER` set to a **disposable CI PostgreSQL container ID**:

```sh
python3 scripts/tests/api_readiness.py
```

The test stops and restores that container; never point it at a production database. CI's existing checkout/payment/inventory, Storefront and Admin jobs continue to run.

Rollback: revert this slice and restore platform probe URLs to their previous values. No persisted data changes.

Graphify was unavailable in the implementation executor (`graphify: command not found` for version/build/query/update). Targeted repository search was used; restore Graphify in the executor for subsequent analysis. Skills applied: lifecycle-architecture-review (failure isolation, small reversible slice), vercel:deployments-cicd (release gates); no frontend change.
