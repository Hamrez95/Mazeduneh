# Database migrations

PostgreSQL schema changes are grouped by component and immutable version in the shared `schema_migrations` ledger. The API process reads the ledger for readiness and the latest applied version; it never creates or upgrades the schema during normal startup.

Each bootstrap component records:

- `component`: catalog, checkout, inventory, payments, orders, or customers
- `version`: immutable migration identifier
- `checksum`: SHA-256 of the migration SQL
- `applied_at`: UTC application time

The deployment command is `dotnet Mazeduneh.Api.dll --migrate` (or `dotnet run --project services/api/Mazeduneh.Api.csproj -- --migrate` from the repository root). It runs the component migrations in dependency order. Each migration uses a PostgreSQL advisory transaction lock and a checksum, so concurrent deployment jobs serialize and an edited applied migration fails with an actionable error. Run this as a one-shot deployment job before starting or promoting API instances, using the target environment's connection string.

## Rules

1. Never edit SQL for an applied `component/version`.
2. Add a new version for every schema change.
3. Keep migrations idempotent when they must support databases created by the previous bootstrap.
4. Do not put credentials or connection strings in source control.
5. Treat `schema_migrations` as operational data and include it in backups.

The public `/health` response reports whether migrations are tracked, how many are applied, and the latest recorded component/version without exposing connection details. `/health/ready` stays 503 until the database is reachable, the ledger is nonempty, and Admin authentication is configured.

The numbered migrations preserve existing installations while making each applied version observable. Their SQL remains with its owning database component. `DatabaseDeploymentTasks` coordinates dependency order, while `DatabaseMigrationCatalog.Required` is the central manifest: deployment fails if a required migration was omitted. Add every new immutable migration key to that manifest when adding its SQL to the owning component. Future destructive or backfill work must include a tested restore/recovery plan; do not add automatic down-migrations for business data.

## Migration manifest

| Component | Required versions |
| --- | --- |
| catalog | `001-bootstrap`, `002-nutrition-costing` |
| inventory | `001-bootstrap`, `002-batches-expiry`, `003-purchase-history`, `004-pricing-rules`, `005-purchase-pagination`, `006-supplier-details`, `007-adjustment-replays` |
| commerce | `001-pricing-settings` |
| corporate-sales | `001-bootstrap` |
| checkout | `001-bootstrap`, `002-shipping-expense` |
| customers | `001-bootstrap` |
| orders | `001-bootstrap`, `002-internal-notes`, `003-shipping-details`, `004-dashboard-role-preferences` |
| payments | `001-bootstrap`, `002-failed-zibal-attempts` |
| admin-audit | `001-bootstrap` |
| admin-users | `001-memberships`, `002-member-login`, `003-member-permissions` |

## Seed data is a separate operation

`--migrate` creates and upgrades schema only. It does not insert demo products or an Owner membership. For an explicitly local/demo database, run `dotnet Mazeduneh.Api.dll --seed-admin` and `dotnet Mazeduneh.Api.dll --seed-demo` as separate one-shot commands after migration. The local launcher does this automatically against its local-only database. CI verifies that migration alone leaves `products` and `admin_users` empty, that the seed commands are repeatable, and that existing catalog rows are not overwritten. Do not run `--seed-demo` against staging or production.

## Environment and recovery

Local, staging, and production must each use their own database name, database user/password, application secrets, and media credentials. Never reuse the local Compose password or CI credentials in a hosted environment. The CI migration gate uses a disposable PostgreSQL database as a staging drill: it runs two concurrent migrators on an empty database, repeats the migration, takes a custom-format `pg_dump`, restores into another empty database, then verifies the migration ledger and seeded records. This proves the repeat/concurrency and backup format path; operators must still run a backup/restore exercise against their actual staging service before release.

For deployment, stop promotion if `--migrate` exits nonzero or `/health/ready` remains 503. Restore a verified backup to a separate database for recovery. Do not reset, drop, or re-seed a production database to roll back application code.
