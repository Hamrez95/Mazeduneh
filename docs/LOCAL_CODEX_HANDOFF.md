# Local Codex handoff

Updated: 2026-10-09

- Current task: launcher delivery and repository branch audit. Main SHA: `d193d5d28ce61517722ee651c419f86542a9d915` (PR #195).
- PR #195 merged. CI run #518 passed Storefront, API/PostgreSQL, and Admin Flutter.
- Local launcher checks passed: PowerShell AST parse; menu/exit; clean missing-Docker guidance; Storefront preview startup twice; `-Status`; `-Stop`; occupied-port detection that left an unrelated listener untouched; `git diff --check`.
- Full local PostgreSQL/API/Admin startup is not verified: Docker Desktop and Docker CLI are missing on this Windows machine. The launcher offers official Docker Desktop setup/start from its menu; installation may need Administrator approval and a restart.
- Remote branches after cleanup: only `main` and `dev` (plus Git's `origin/HEAD` alias to `dev`). See `docs/BRANCH_AUDIT.md`. Local task worktrees and uncommitted changes remain preserved.
- #169 stays open for remaining production-entry accessibility evidence: keyboard/focus/tap-target checks and Persian date/price clarity. Its completed slices are not a reason to close the epic.
- #91 stays open for broader MFA/step-up and IDOR coverage. #92 stays open for deeper profit/cost analytics, alerts, and additional drill-downs.
- Graphify is unavailable here (`graphify --version` is not found); targeted `rg` searches are the documented fallback. No graph was generated or queried.
- Next: finish the remaining #169 accessibility checks on the secure production entry, then continue open P0 security and operations criteria from GitHub Issues. Keep each item open until its acceptance criteria, tests, review, CI, and merge are complete.

