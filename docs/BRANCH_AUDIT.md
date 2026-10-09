# Branch audit — 2026-10-09

## Remote

`git fetch origin --prune` succeeded. GitHub branch search and the fetched refs show only `main` and `dev` (plus the symbolic `origin/HEAD`). All other remote feature branches from the earlier audit have been merged or deleted. The newest `main` is `78836f8af35aef162fd3bd12bc49d0a24f02c9e0`; `dev` remains protected and is intentionally retained.

Recently merged slices verified on `main`:

| PR | Work | Merge SHA | CI |
| --- | --- | --- | --- |
| #195 | Local launcher menu and Docker setup guidance | `d193d5d28ce61517722ee651c419f86542a9d915` | #518 passed |
| #196 | Branch audit and local handoff docs | `d2edfc1fb958b4dfc3bf3282d2f9619adb8ca8cb` | #520 passed |
| #197 | Admin expiry text at narrow widths and large text scale | `893420dcbb83eb080ec86b88aeb51eb62e0104a9` | #522 passed |
| #198 | Step-up authorization and audit for commerce pricing settings | `78836f8af35aef162fd3bd12bc49d0a24f02c9e0` | #525 passed |

Remote branches for these merged PRs were deleted after merge verification. Historical refs are not retained on GitHub.

## Local branches and worktrees

The local checkout has extra branch names because this machine still has managed worktrees. Their changes must be accounted for before reducing local refs to only `main` and `dev`; deleting a branch checked out in a worktree or discarding its working files would lose recoverable work.

| Local branch(es) | Evidence / current disposition |
| --- | --- |
| `codex/169-c-stock-ledger`, `codex/169-f-accessibility`, `codex/169-f-exact-navigation`, `codex/169-f-navigation-ui`, `codex/185-main-a735`, `codex/185-main-refresh`, `codex/185-refresh` | PR #185/#193/#197 navigation and accessibility work is present on `main`; the related worktrees include an untracked deep-navigation test, so retain that file until reviewed and either promoted or explicitly classified as scratch. |
| `codex/186-main-a735`, `codex/186-scope-fix`, `codex/admin-edit-permissions-form-layout` | The permission editor slice is present on `main` through PR #186; one worktree has an uncommitted membership test change. Preserve it pending review. |
| `codex/91-sensitive-step-up`, `codex/91-step-up-approval`, `codex/91-step-up-commerce-settings` | Role dashboards and inventory/commerce step-up slices are in `main` (#187, #194/#198). `codex/91-sensitive-step-up` has a generated `analysis_options.yaml` modification; do not include or discard it without inspection. |
| `codex/92-service-health`, `codex/handoff-refresh`, `codex/dashboard-role-widgets` | Dashboard health, role preferences and time-range work are in `main` (#187/#189/#192/#193); the handoff worktree has two uncommitted documentation edits to inspect before cleanup. |
| `codex/dev-launcher-menu`, `codex/local-launcher`, `codex/storefront-followup` | Launcher work is in `main` through #184/#195. The current launcher worktree is clean; retain until the final local launcher verification and worktree lifecycle are complete. |
| `codex/branch-audit-handoff`, `codex/branch-audit-refresh` | Documentation snapshots superseded by this audit. Root handoff branch is clean; refresh worktree is clean and attached. |
| `codex/storefront-admin-operations-finance` | Three unique commits include catalog, inventory, finance and storefront work not established as merged by commit ancestry. Six worktree entries (including untracked Flutter metadata) need classification; preserve. |
| `refactor/169-e-remove-legacy-operations-shell` | Two local commits and a narrow secure-entry test diff remain outside ancestry; preserve pending comparison against current secure entry tests. |
| `main`, `dev` | Protected delivery and integration branches; preserve. |

These are local-only references; GitHub has no corresponding feature refs. A local branch deletion pass is still required after the noted dirty/untracked work is reviewed and any valuable slice is promoted. The repository must not be reported as locally reduced to two branches until that pass is completed and rechecked.

## Remaining delivery work

- Issue #169 remains open: section A, B, C, D, E and F have independent slices, but privacy/security review, remaining acceptance checks, and the explicit physical keyboard/focus/screen-reader checks are not complete. Merging its listed PRs does not complete the epic.
- Issue #91 remains open: step-up was added for inventory and commerce pricing changes, but MFA/session revocation, broader IDOR review, and full permission/audit criteria remain.
- Issue #92 remains open for the remaining analytics acceptance criteria.
- Full local PostgreSQL/API/Admin startup has not been verified on this Windows host because Docker Desktop/Compose is unavailable. The launcher correctly reports that prerequisite failure; no full-stack readiness is claimed.
- Graphify is unavailable here; use the documented focused-search fallback and do not claim Graphify queries ran.

## Required final cleanup checks

1. Inspect and preserve all dirty or untracked worktree files.
2. Compare any potentially valuable local-only commits against `origin/main` by content and PR evidence, not only ancestry (squash merges rewrite ancestry).
3. Remove only local branch refs whose work is confirmed present on `main` or whose unique work was deliberately abandoned after review; detach/archive associated managed worktrees safely first.
4. Verify `git branch --format='%(refname:short)'` lists only `dev` and `main`, and verify the same on GitHub.
