# Branch audit — 2026-10-10

## Remote branches

GitHub branch search after merge cleanup shows exactly `main` and `dev`. The merged remote branches `codex/handoff-update` (#199), `codex/dev-docker-readiness` (#200), and `codex/docker-ready-return` (#201) were deleted through the repository branch page after checking their merged PRs. `origin/HEAD` points to the default branch and is not an additional branch.

`main` is at `26b50be6cdfc05a5d45191aae5980015d0700ef`. `dev` remains the integration branch.

| PR | Delivery | Merge SHA | Verification |
| --- | --- | --- | --- |
| #199 | Branch audit and local handoff documentation | `fe130aab15ec26474e3a0623b8312ff05e277d20` | CI #527 passed |
| #200 | Docker Desktop readiness and per-user install path | `7c8c06f1a1e4c3c80e45191aae5980015d0700ef` | CI #533 passed; follow-up correction in #201 |
| #201 | Correctly return success after Docker becomes ready | `26b50be6cdfc05a5d45191aae5980015d0700ef` | CI #535 and Vercel status passed |

## Local branches and worktrees

The repository root is clean on `main`. Local branch refs are `main`, `dev`, and `codex/storefront-admin-operations-finance`.

The only extra local branch is checked out in `C:/Users/HamidReza Pakpour/.codex/worktrees/mazeduneh-commerce/Mazeduneh`, a worktree not attached to this Codex task. It contains three unique commits (`6bba276`, `782fb9c`, `dc01b05`) covering media/catalog/inventory/finance and storefront changes, plus untracked Flutter metadata and platform files. These changes have not been reconciled with current modular Admin/API implementations. Preserve this branch and its worktree until its owner reviews and promotes or abandons the valuable work; do not delete its branch while checked out or remove its untracked files.

Other worktrees are detached snapshots or ignored launcher worktrees. The nested `.local-dev/main-worktree` under the managed launcher worktree runs the storefront preview; keep it while that process uses it. No additional local feature branch refs remain.

## Remaining project work

- Issue #169 stays open. The implementation slices are present, but final privacy/security review and hands-on keyboard, focus, screen-reader and physical-device acceptance checks remain. The owner plans to do physical testing after code work.
- Issue #91 (P0) stays open for MFA and broader IDOR/security review. The pricing step-up slices do not complete the epic.
- Issue #92 stays open for remaining analytics acceptance criteria.
- The local launch menu and Docker readiness logic are fixed, but full PostgreSQL/API/Admin startup is not verified: Docker Desktop is not installed. `wsl --status` reports WSL is absent; winget reached an Administrator request and failed with installer exit code `4294967290`. Install WSL 2 with Administrator approval and restart Windows, then install/start Docker Desktop and rerun the launcher.
- Graphify is unavailable (`graphify --version` not found); focused `rg` and source review were used instead.

## Cleanup result

GitHub is clean with only `main` and `dev`. Local refs are reduced to those two plus the preserved finance work branch in its active, unowned worktree. Deleting that branch now would risk valuable work and untracked files; it requires review in that worktree first.


## Current branches after PR #202

- `main`: `e97ed1af8b49eb917c5bcaaf9f339644b11fcb68` at session start.
- `dev`: retained integration branch; its current check is failing and it is not a cleanup candidate.
- `codex/branch-audit-refresh`: PR #202 merged; delete after verifying merge SHA on main.
- `codex/91-product-cost-privacy`: open PR #203; retain through independent security review and merge.
- `codex/dev-menu-readiness`: open PR #204; retain through CI and merge.

Latest delivery state: #203 CI run #544 passed all three required jobs. #204 PowerShell checks passed locally; its CI is pending. The finance branch in the separate unowned worktree remains preserved as documented above.
