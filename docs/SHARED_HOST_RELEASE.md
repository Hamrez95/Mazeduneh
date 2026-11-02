# Mazeduneh release for the shared business host — 2026-11-02

The deployable storefront is the **Next.js server**, not the existing Cloudflare Pages
static demo. `infra/storefront-release.env` fixes the public production build inputs:
`mazeduneh.ir`, `api.mazeduneh.ir` and `admin.mazeduneh.ir`, live API mode, no static export.
Run `node scripts/build-release.mjs` after `npm ci` in `apps/storefront`. It prepares
`.next/standalone` with public/static assets. No provider account or live site is changed.

API and storefront images run as non-root users. The API's media directory is writable
by its app UID and must be mounted on persistent storage. Owner MFA is required in the
shared-host profile; use existing migrations and `--seed-admin`, never `--seed-demo`.
Production sandbox payment remains disabled. A real merchant and server-side verified
callback are required before commerce launch.

`ReverseProxy__KnownProxies__0=172.30.21.2` identifies the isolated shared ingress.
Only this peer may assert HTTPS/client IP. With no configured peers forwarding is
disabled, and malformed addresses fail startup. The ingress overwrites forwarded
headers after validating Cloudflare's source ranges. Do not expose API port 8080 publicly.

The shared host uses an independent PostgreSQL process/roles/TLS certificate, a local
persistent media volume, literal private environment files, encrypted off-host restic
backup and independent restore drills. S3 remains an optional future move; it is not
required to buy a separate object-storage server for the initial low-user deployment.

The canonical composition, operator commands, exact-release bundler and staging checklist
live in `Hamrez95/StrategicManagementPanel`, under `infra/shared-host/`. Its bundle pins
this repository and Stratino by full Git SHAs and records archive hashes. Keep all three
Mazeduneh images on the same commit. A separate builder/CI avoids build memory spikes
on the initial 8-GiB runtime host.

Prepared/tested locally: live-mode production Next build, new-after-build product deep
link and bounded metadata failure, API contract harness including proxy spoofing and
HTTPS handling. Container execution, actual SMTP/payment/storage, host recovery, external
alerts and real inventory/fulfillment acceptance require the future staging host.
The Cloudflare Pages preview is preserved until an explicitly reviewed server cutover.

See also [release readiness](RELEASE_READINESS.md), [host configuration](HOST_CONFIGURATION.md)
and [launch acceptance](LAUNCH_CHECKLIST_2026-10-25.md). No business data, pricing or legal
policy is invented by this preparation.
