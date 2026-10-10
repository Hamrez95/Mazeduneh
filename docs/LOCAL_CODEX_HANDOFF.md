# Local Codex handoff

Updated: 2026-10-10

- Current root checkout: clean `main` at `26b50be6cdfc05a5d45191aae5980015d0700ef`.
- PR #199 merged at `fe130aab15ec26474e3a0623b8312ff05e277d20`; PR #200 at `7c8c06f1a1e4c3c80e45191aae5980015d0700ef`; PR #201 corrected Docker readiness at `26b50be6cdfc05a5d45191aae5980015d0700ef`. Required CI passed for all three; #201 Vercel status passed.
- Branch cleanup: GitHub now lists only `main` and `dev`. Local refs list `main`, `dev`, and `codex/storefront-admin-operations-finance`, which remains checked out in an unowned worktree with three unique commits and untracked files. Preserve it until reviewed; details are in `docs/BRANCH_AUDIT.md`.
- Launcher fix: `Start-OrExplainDocker` now recognizes machine-wide and per-user Docker Desktop paths and returns success when the Docker engine becomes ready. PowerShell parse and mocked Windows startup integration passed; interactive menu displayed and exited cleanly.
- Full-stack startup remains unverified. Docker CLI/Desktop is absent, `wsl --status` reports WSL is not installed, and the winget installer failed after reporting an Administrator request (`4294967290`). Required host action is to install WSL 2 with Administrator approval, restart Windows, then install/start Docker Desktop and rerun `pwsh -File ./scripts/dev.ps1`.
- Full-mode missing-Docker behavior was tested: it prints actionable install guidance and exits with code 2. This is a prerequisite result, not a successful API/Admin/PostgreSQL launch. Storefront preview had previously run at SHA `78836f8af35aef162fd3bd12bc49d0a24f02c9e0`.
- API/Admin/Storefront CI jobs for #200 and #201 passed. The #201 Windows mock simulated a per-user install and an engine becoming ready after launch.
- Open acceptance work: #169 physical accessibility/privacy checks; #91 MFA and broader IDOR/security; #92 analytics criteria. Do not close these issues early.
- Graphify is unavailable; only focused `rg` and source review are claimed.
- Next: once WSL/Docker is ready, run the full launcher and exercise product edits through Admin and Storefront. Then continue the P0 #91 security review; preserve physical acceptance for the owner's test pass.
