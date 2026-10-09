# Local Codex handoff

Updated: 2026-10-09

- Current task: make `scripts/dev.ps1` menu-driven and handle missing Docker and port conflicts cleanly; branch `codex/dev-launcher-menu`, based on main `cddab4784663f010c9806c487f70b287ba0448a0` (PR pending).
- Local validation: PowerShell 7.6.5 parsed the launcher; the default menu opened; selecting full mode with Docker absent printed install/start guidance and exited without a PowerShell exception; `storefront-preview` synchronized `package-lock.json` dependencies and became ready at `http://127.0.0.1:3000`; `-Status` recognized the owned PID; `-Stop` stopped it and released the port; an occupied-port test left the unrelated listener untouched; `git diff --check` passed.
- Environment limit: Docker CLI/Desktop is not installed. This PowerShell session is not elevated, so Docker Desktop installation may require Administrator approval and possibly a restart. Full PostgreSQL/API/Admin startup and database-backed launcher paths are not verified locally. Menu option 8 uses official Docker Desktop via winget or starts the installed app.
- Previous delivery: PR #194 completed one step-up slice for #91, merged to main as `cddab4784663f010c9806c487f70b287ba0448a0`; CI run #516 passed Storefront, API/PostgreSQL, and Admin Flutter. #91 remains open for MFA and broader IDOR/audit/step-up work.
- #169 D is merged via PR #173 (`12a2f0f7652893c552f20e395d7ecbc8c2ae6ca5`); its acceptance items are checked. #169 remains open for other acceptance work. PR #193 covers exact dashboard drill-down behavior; accessibility evidence remains outstanding.
- Branch cleanup: remote `feat/inventory-ledger` was removed after confirming its incomplete prototype is superseded by #172. Other branch dispositions are pending a fresh audit; keep `main`, `dev`, and every branch with an active worktree or unique unmerged changes until resolved.
- Graphify is unavailable in this workspace (`command not found`); focused `rg` consumer searches are used as the documented #151 fallback. No Graphify execution is claimed.
- Next: finish launcher checks, open and validate its PR, then continue branch/issue audit and preserve only verified `main`/`dev` refs after all useful work is merged or safely discarded.
