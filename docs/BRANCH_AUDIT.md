# Branch audit — 2026-10-09

Audited `Hamrez95/Mazeduneh` against `origin/main` at `d193d5d28ce61517722ee651c419f86542a9d915`, after fetching and pruning. The only remote branches are `main` and `dev`; `origin/HEAD` points to `dev`.

## Remote branch decisions

| Branch | Evidence | Decision |
| --- | --- | --- |
| `main` | Current delivery branch; includes PR #195 at `d193d5d`. CI run #518 passed Storefront, API/PostgreSQL, and Admin Flutter. | Keep. |
| `dev` | Integration branch, not a duplicate of `main`; it remains the repository's remote HEAD. | Keep. |
| `codex/dev-launcher-menu` | PR #195 merged into `main`; branch page showed the merged PR and successful checks. | Deleted after merge and verification. |
| `codex/admin-edit-permissions-form-layout` | No PR. Its permission editor and responsive product edit controls are present in the later merged PR #186 (`dc121c5`). | Superseded; deleted. |
| `feat/admin-media-picker` | Closed, unmerged PR #56 used a local-only media API. Current `main` has the media picker in product editing and the newer provider-based media storage with metadata/delete routes. | Superseded; deleted. |
| `feat/storefront-mockup-followup` | Closed, unmerged PR #63 used a hard-coded demo catalog and duplicated the storefront header. Current `main` has shared storefront chrome and Admin-backed catalog integration from #64, #65, and #154; applying the old commit conflicts with that newer implementation. | Superseded; deleted. |
| `feat/inventory-ledger` | Earlier branch audit found its unfinished inventory prototype superseded by merged PR #172. | Deleted after comparison with `main`. |

Merged feature branches for PRs #181–#195 were deleted only after their merges were confirmed. Local branches and worktrees with active or uncommitted work were preserved; remote cleanup does not authorize deleting those local checkouts. The root checkout is still on `codex/branch-audit-handoff` with its local commit and is ahead/behind `origin/main`; it was not reset or overwritten.

## Delivery status

- PR #195 delivered the menu-driven launcher and merged as `d193d5d28ce61517722ee651c419f86542a9d915`. Its required CI passed.
- `scripts/dev.ps1 -Component storefront-preview -NoBrowser` was run successfully twice, with `-Status`, `-Stop`, and occupied-port behavior verified. Full PostgreSQL/API/Admin startup remains unverified because Docker Desktop/CLI is absent on this machine.
- #169 remains open. A–E and parts of F have merged, but the Issue's remaining accessibility evidence for keyboard/focus/tap targets and Persian date/price clarity is not yet complete.
- #91 remains open for MFA/step-up on more sensitive operations and broader IDOR review. #92 remains open for deeper profit/cost analytics, health alerts, and additional drill-downs.
- Graphify is unavailable in this workspace (`graphify` is not found). Focused `rg` searches were used; no Graphify execution is claimed.

## Local branches and worktrees

Several Codex-managed worktrees still contain active task branches, including security, inventory, dashboard, navigation, and commerce work. They are retained to protect their local commits and working-tree changes. Review and archive those checkouts individually after their changes have been merged or explicitly abandoned; do not remove them as part of remote branch cleanup.

