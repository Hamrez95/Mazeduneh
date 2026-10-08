# Local Codex handoff

Updated: 2026-10-09

- Current documentation branch: `codex/branch-audit-handoff`, based on `origin/main` after PR #187.
- Current `origin/main`: `77ed2ee92cb4f5cae5c7476ebf6c6b4376395be4` (squash merge of PR #187).
- Recently delivered: #182, #181 and #183 completed the responsive shell and API contract slices for #169 F. PR #187 completed role dashboard preferences for #92 and merged at `77ed2ee`.
- Open PR #185 (`feat/169-f-typed-navigation-ui`): head `b569d63daaf087c6f5e61e60623662ebac8d3a1b`; CI #483 and Vercel preview passed. Local Flutter navigation tests (including system-back regression) passed. The independent Sol permission/route review required by #169 is outstanding; keep #169 open.
- Open PR #186 (`codex/admin-permission-form-review`): head `e3ce2abb3ea9962cc4e95edc8a8e31b0466b3eff`; CI #477 and Vercel preview passed. It completes only a user-permission editing slice of #91. The independent Sol security review is outstanding; MFA/step-up and expanded IDOR work also remain.
- Issue #92 remains open for deeper profit/cost analytics, service-health alerts and additional drill-downs after #187. Do not close either #91, #92 or #169 early.
- Branch audit: `docs/BRANCH_AUDIT.md`. Nine remote branches remain: protected `main`/`dev`, the two open PR branches, the active `codex/local-launcher` worktree, and four unique branches preserved for review/recovery. The verified merged/no-delta branch cleanup has been fetched and pruned locally.
- Launcher: `scripts/dev.ps1` selects a detached, ignored local worktree of fresh `origin/main` by default; `-CurrentBranch` explicitly runs the caller's checkout. It starts Compose PostgreSQL, requires `/health/ready`, configures the API with the local database, synchronizes lockfile dependencies, and verifies ownership before stopping recorded processes.
- Local validation completed for the launcher: PowerShell parser validation passed. `pwsh -File .\scripts\dev.ps1 -Component api -NoBrowser` exited 1 because Docker is absent; it did not report a ready system. Full PostgreSQL-backed startup remains unverified until Docker Desktop is available.
- Tools detected: PowerShell 7.6.5, Node 22.14.0/npm 11.19.1, Flutter 3.47.2/Dart 3.13.2, and .NET SDK 10.0.401. Docker and PostgreSQL CLI are unavailable.
- Graphify is unavailable in this workspace (`command not found`); focused `rg` searches were used as the Issue #151 fallback.
- Next: obtain the required independent reviews for #185/#186; then merge only if the reviewer and required checks pass. Continue #91 after #169 review, then the remaining #92 acceptance criteria. Run the full launcher when Docker is available.

