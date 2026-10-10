# Database migrations

The API keeps PostgreSQL schema changes in a shared `schema_migrations` ledger.

Each bootstrap component records:

- `component`: catalog, checkout, inventory, payments, orders, or customers
- `version`: immutable migration identifier
- `checksum`: SHA-256 of the migration SQL
- `applied_at`: UTC application time

The runner takes a PostgreSQL advisory transaction lock before checking or applying a migration. Multiple API instances can therefore start safely without applying the same migration concurrently.

## Rules

1. Never edit SQL for an applied `component/version`.
2. Add a new version for every schema change.
3. Keep migrations idempotent when they must support databases created by the previous bootstrap.
4. Do not put credentials or connection strings in source control.
5. Treat `schema_migrations` as operational data and include it in backups.

The public `/health` response reports whether migrations are tracked, how many are applied, and the latest recorded component/version without exposing connection details.

The current `001-bootstrap` migrations preserve the existing schema bootstrap behavior while making the first applied version observable. Future destructive or backfill work must be introduced as a separate migration with a tested rollback or recovery plan.
