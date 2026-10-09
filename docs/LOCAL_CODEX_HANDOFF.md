# Local Codex handoff

Updated: 2026-10-09

- Documentation is being refreshed from current `origin/main` (`78836f8af35aef162fd3bd12bc49d0a24f02c9e0`).
- Delivered since the previous handoff: PR #197 merged at `893420dcbb83eb080ec86b88aeb51eb62e0104a9` (responsive expiry display and large text coverage); PR #198 merged at `78836f8af35aef162fd3bd12bc49d0a24f02c9e0` (step-up and audit for commerce pricing settings). CI #522 and #525 passed all required Storefront, API/PostgreSQL and Admin jobs.
- PR #195 launcher menu changes are on `main` at `d193d5d28ce61517722ee651c419f86542a9d915`, CI #518 passed. README documents `pwsh -File ./scripts/dev.ps1` and its options.
- Remote branch audit: after `git fetch origin --prune`, GitHub and local remote refs show only protected `main` and `dev` (plus `origin/HEAD`). Local extra refs remain attached to managed worktrees; see `docs/BRANCH_AUDIT.md` for each branch and its cleanup evidence. Several worktrees contain uncommitted or untracked material and must be reviewed before removing local refs.
- Latest local API checks: .NET 10.0.401 Release build passed with 0 warnings/errors; `services/api.tests` console checks passed for receipt validation, pricing arithmetic, pagination, permission catalog, step-up token/session/signature/lifetime, dashboard role preferences, and order privacy/output permissions.
- Latest local Admin checks: Flutter analyze passed; `flutter test --no-pub` passed all 127 tests, including commerce settings API header coverage. CI #525 passed the PostgreSQL integration checks for absent/invalid/successful step-up and audit actor/snapshots.
- Local launcher checks cover PowerShell parsing, menu/exit, missing-Docker guidance, storefront preview, rerun, status/stop and protection of an unrelated busy-port process. Full PostgreSQL/API/Admin startup remains unverified because Docker Desktop/Compose is unavailable on this host. Do not describe static inspection or prerequisite handling as a successful full-stack run.
- The local .NET SDK was installed under the current user's LocalAppData; no system-wide installation or administrator access was needed.
- Graphify is unavailable (`graphify --version` not found); focused `rg` search and targeted file review are the fallback. Do not claim Graphify ran.
- Open work remains: #169 privacy review and physical accessibility checks; #91 MFA/session revocation and broader IDOR criteria; #92 remaining analytics criteria. Do not close these issues until their full acceptance criteria pass.
- Next: review the local dirty/untracked worktree files and reconcile all local branch refs against squash-merged PR content; then continue the highest-priority open security/privacy slice. Keep all data and developer changes intact.
