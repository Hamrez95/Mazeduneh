# Branch audit — 2026-10-09

After `git fetch --all --prune`, the repository has 9 remote branches (excluding `origin/HEAD`). The reviewed cleanup removed branches whose merged PRs or commit ancestry showed no work missing from `main`. The previously merged PWA branch for PR #27 was deleted after confirming its tip had no remaining delta. PR #187 was merged and its branch removed; its squash commit is now in `main`.

## Remote branches retained

| Branch | Evidence | Decision |
| --- | --- | --- |
| `main` | Protected default delivery branch. | Preserve. |
| `dev` | Protected integration branch; currently behind `main`. | Preserve. |
| `feat/169-f-typed-navigation-ui` | Open PR #185; CI #483 passes. | Keep pending required independent permission/route review. |
| `codex/admin-permission-form-review` | Open PR #186; CI #477 passes. | Keep pending required independent permission/security review. |
| `codex/local-launcher` | PR #184 is merged; active launcher worktree is still attached. | Preserve while the worktree/process needs it. |
| `codex/admin-edit-permissions-form-layout` | No PR; unique permission UI/API changes. | Preserve for review and recovery. |
| `feat/admin-media-picker` | Closed PR #56 is unmerged; unique storage API/UI work. | Preserve for a follow-up decision. |
| `feat/inventory-ledger` | No PR; unique inventory implementation. | Preserve because it is data-critical. |
| `feat/storefront-mockup-followup` | Closed PR #63 is unmerged; unique storefront UX changes. | Preserve for design review. |

`feat/admin-media-picker-v2` was deleted after `git merge-base --is-ancestor origin/feat/admin-media-picker-v2 origin/main` succeeded and the three-way diff was empty. `feat/mazedoone-brand-storefront-pwa` was deleted after verifying PR #27 is merged and the branch has no current delta. `feat/169-f-batch-aware-navigation-contract` and the merged PR #182 and #181 branches were deleted after their merges were confirmed. The original PR #183 is in `main`.

The local-only branch `refactor/169-e-remove-legacy-operations-shell` is retained: it diverges from its deleted remote ref and may contain recoverable commits. No local branches attached to active worktrees were deleted.

## Open delivery work

- #169 remains open. A–E and the responsive shell slice are in `main`; PR #185 completes the typed-navigation UI slice of F, but has no independent review yet. CI #483 passed at `b569d63`. The required Sol permission/route review is still outstanding, so do not mark the epic Done.
- #91 remains open for MFA/step-up and expanded IDOR review. PR #186 completes only the per-user permission editor slice; CI #477 passed at `e3ce2ab`, but the required independent Sol permission/security review is still outstanding.
- #92 remains open for deeper profit/cost analytics, service-health alerts and additional drill-downs. PR #187 completed role dashboard preferences and merged as `77ed2ee92cb4f5cae5c7476ebf6c6b4376395be4`; CI #475 passed. The issue remains open for its remaining acceptance criteria.

## Validation and cleanup

- `git fetch --all --prune` succeeded and confirmed the removed refs are absent locally.
- All remote deletions were made only for the exact branches in the verified merged/no-delta audit set. `main`, `dev`, open PR branches, unique branches, and the active launcher branch were preserved.
- Graphify is unavailable in this workspace (`command not found`); focused `rg` searches were used as recorded in Issue #151.
- Local PostgreSQL/Docker-backed launcher startup is still unverified because Docker is unavailable. See `docs/LOCAL_CODEX_HANDOFF.md`.

