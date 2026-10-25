# Controlled release runbook

## Current delivery scope — 2026-10-17

Desktop browsers are the first release target for both Storefront and Admin. Native mobile/desktop app packaging and physical-device checks are deferred. The default Windows local path uses portable PostgreSQL and does not require Docker or SQL Server. Follow [browser-first delivery and acceptance](BROWSER_FIRST_DELIVERY.md): local browser testing and owner acceptance precede staging deployment; staging payment, backup recovery, HTTPS and rollback remain required. Container-specific steps below apply only when that deployment option is selected.

Issue: [#100](https://github.com/Hamrez95/Mazeduneh/issues/100)

This runbook separates repeatable CI evidence from checks that require an actual staging account. A green build is necessary, but it is not proof that live payment, database, storage, backup, alerting, or rollback paths work.

## Release record

Record these values in the release pull request or an access-controlled release log. Never add credentials, connection strings, payment merchant codes, customer data, or backup files to the repository or a public issue.

| Field | Required value |
| --- | --- |
| Release commit | Full `main` SHA |
| CI run | Link showing all required jobs succeeded for that SHA |
| Hosting provider and project owner | Chosen provider, account/team owner, and service names |
| Storefront, Admin, and API | Staging HTTPS URLs |
| Database and object storage | Staging resource identifiers; credentials stay in the host's secret manager |
| Release operator and rollback operator | Named owners with access to the host and data services |
| Previous known-good release | Image or deployment IDs and matching database migration state |

Do not promote while any field above is missing. Keep staging and production credentials, databases, buckets, payment configuration, and domains separate.

## Before staging deployment

1. Open a feature pull request into the protected default branch `main`; require the Storefront, API, Admin Flutter, Graphify, Production container images, and partner demo checks to pass. `dev` can be used for optional integration work.
2. Record the exact merge SHA and its green CI run. Use the latest [launch checklist](LAUNCH_CHECKLIST_2026-10-25.md) for evidence and remaining server gates.
3. Build the Storefront with the staging API URL, demo mode disabled, and staging Admin/site URLs. Build Admin with the same staging API origin. These public URLs are build inputs, not secrets.
4. Configure API secrets only in the staging host's secret manager. Use a non-production PostgreSQL database, a separate S3-compatible bucket, staging CORS origins, a unique Admin credential, and Zibal sandbox settings. Never enable the sandbox provider as the production payment provider.
5. Confirm the staging database starts from an empty state and records its applied migrations. Review seed behavior before using any production database; never use local reset or demo seed commands against production data.

## Staging smoke and recovery drill

Run each check against staging and retain the deployment ID, UTC time, release SHA, request IDs, and pass/fail result. Use synthetic accounts and products only.

| Check | Pass condition |
| --- | --- |
| Process and dependency health | `/health/live` returns 200; `/health/ready` returns 200 only when PostgreSQL, migration ledger, and Admin authentication are ready. |
| Catalog and Admin | Staging Storefront loads API-backed products; Admin login succeeds with the staging owner; unauthorized access is rejected. |
| Storage | Upload and read back a non-sensitive test image from the staging bucket; verify its public URL uses the staging API/storage configuration. |
| Payment success | A Zibal sandbox order uses the server-calculated amount, is verified by the API, and changes state once. |
| Payment decline/cancel/network failure | The customer sees a recoverable result; the order is not marked paid and reserved stock follows the tested release policy. |
| Duplicate callback and verify retry | Replaying the callback or verification produces no second payment, transition, inventory movement, or audit event. |
| Backup and restore | Take a staging-only database backup, restore it to a separate empty staging database, verify the migration ledger and sample order, then point a temporary API instance at the restored database. |
| Rollback | Restore the previous application image/configuration without deleting the current database; verify readiness and the last known-good synthetic order. If a migration is not backward compatible, use a separately restored database and switch only after validation. |

Do not test restore by overwriting the only staging database or by using production data. Keep the original backup until the restored environment passes verification.

## Monitoring and launch decision

Before a public pilot, configure alerts in the selected host or monitoring service for:

- API readiness failures and sustained API error rate/latency.
- PostgreSQL unavailability, connection exhaustion, and backup/restore failures.
- Object storage upload/read failures and capacity limits.
- Payment create/verify errors, repeated pending payments, and callback backlog.
- Low stock, expiring batches, and overdue order follow-up.

Choose thresholds from staging measurements and expected pilot volume; document the threshold, notification destination, on-call owner, and response action for every alert. Verify one test notification per alert route. Do not claim observability is active based only on local JSON logs or GitHub CI.

The release owner records **GO** only after all staging rows pass, alerts reach their owner, the rollback operator completes the drill, and the exact `main` SHA has green required CI. Otherwise record **NO-GO**, link the failing evidence, and keep production domains and payment credentials unchanged.

## Current repository gates

- CI runs Storefront, API, Admin Flutter, Graphify, and production container-image builds on pull requests to `dev` and `main`.
- Container images are built on the GitHub runner and discarded; CI does not push, deploy, or receive staging/production secrets.
- Provider-specific deployment commands and environment variables are in [`LIARA_DEPLOYMENT.md`](LIARA_DEPLOYMENT.md) and [`HOST_CONFIGURATION.md`](HOST_CONFIGURATION.md). The Liara file is an example configuration, not proof that an account or live services exist.
- Readiness and safe request-correlation behavior are documented in [`API_READINESS.md`](API_READINESS.md) and [`API_OBSERVABILITY.md`](API_OBSERVABILITY.md).

Until a host, staging database, staging bucket, and alert destination are provisioned, the staging, restore, live payment, and rollback rows are **not verified** and issue #100 remains open.

## Production configuration preflight

Load the reviewed environment into the process through the host secret manager, then run `node scripts/release-preflight.mjs` from the repository root. It validates public HTTPS origins, API/demo/static mode, owner authentication/MFA, CORS, media persistence and disabled sandbox payment, without printing values or changing data. After the merchant is issued, run the same command with `--payments` to check the real merchant and exact callback/return origins and paths. A successful configuration check does not replace staging acceptance.

The non-secret [environment template](production.env.example) lists the required names. Store the completed copy outside Git. Node also supports `node --env-file=/private/release.env scripts/release-preflight.mjs --payments`; .NET services still need the same settings loaded by the host. The planned API/Admin subdomains in the template do not represent provisioned services.

Build the actual Storefront server with `MAZEDUNEH_RELEASE_BUILD=true`, `NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE=false` and the public API/site/Admin origins. For the container build pass `--build-arg MAZEDUNEH_RELEASE_BUILD=true` as well as the public origins. Keep `MAZEDUNEH_STATIC_EXPORT` unset. The current Cloudflare Pages static preview is not the live commerce server: newly published product slugs need the Next.js server. The public Pages preview can remain available until the approved server cutover.

Build Admin using `lib/secure_main.dart` and `--no-web-resources-cdn` so Flutter rendering resources are served with the application. The production Admin image enables gzip for JavaScript, CSS, JSON, SVG and WebAssembly. Keep the API and Admin on the same reviewed release as the Storefront.
