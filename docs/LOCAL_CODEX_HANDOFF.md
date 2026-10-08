# Local Codex handoff

Updated: 2026-10-08

- Current delivery worktree: `codex/local-launcher` (created from `origin/main` after #181).
- Current `origin/main`: `f815d3de9706d42df532058b73543009e8ddfed0`.
- Delivered in this pass: #182 merged at `e5ee4a2`; #181 merged at `f815d3d` after correcting and passing its restricted-menu regression test.
- Active dependency: #183 (`feat/169-f-batch-aware-navigation-contract`) needs a rebase/merge resolution against current main before it can be merged.
- Launcher status: `scripts/dev.ps1` now selects a detached, ignored local worktree of fresh `origin/main` by default; `-CurrentBranch` explicitly runs the caller's checkout. It starts Compose PostgreSQL, requires `/health/ready`, configures the API with the local database, synchronizes lockfile dependencies, and verifies ownership before stopping recorded processes.
- Local validation completed: PowerShell parser validation passed. `pwsh -File .\scripts\dev.ps1 -Component api -NoBrowser` correctly stopped with exit code 1 because Docker is absent; it did not report a ready system. Docker Desktop/PostgreSQL installation is the remaining environment blocker for the full live run.
- Tools: PowerShell 7.6.5, Node 22.14.0/npm 11.19.1, Flutter 3.47.2/Dart 3.13.2, and user .NET SDK 10.0.401 are available. Docker and PostgreSQL CLI are unavailable.
- Branch audit: see `docs/BRANCH_AUDIT.md`. Graphify is unavailable; targeted code searches were used as the Issue #151 fallback.
- Next: resolve and validate #183, merge it, then implement the typed navigation UI slice for #169 F. Run the full launcher after Docker Desktop is available.

