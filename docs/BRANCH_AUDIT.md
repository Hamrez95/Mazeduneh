# Branch audit — 2026-10-08

Scope: 123 real remote branch refs, checked against the fetched `origin/main`; `origin/HEAD -> origin/dev` is a symbolic ref and is not a branch. PR associations were checked on GitHub, including merged PRs whose branch commits are not ancestors of `main`.

## Result

| Classification | Count | Decision |
| --- | ---: | --- |
| Protected | 2 | Preserve `main` and `dev`. |
| Merged PR verified in main | 109 | Redundant; safe to delete. |
| Direct ancestor of main | 6 | Redundant; safe to delete. |
| Merged PR with no branch-only diff | 1 | `feat/mazedoone-brand-storefront-pwa` (#27); safe to delete. |
| Needs individual review or active work | 5 | Preserve. |

The safe set is 116 refs. The audit uses PR merge evidence and branch-only diffs; `git branch --merged` alone is not used to classify squash-merged work. No older open PR remains from the audited set: #182, #181, #183, and #184 are merged. Their merged changes are present on `main`; the current `origin/main` is `3ce28e5c87941d0105f774f4e0bebd8f8ff15798`.

## Branches retained for work or review

| Ref | Evidence | Decision |
| --- | --- | --- |
| `codex/admin-edit-permissions-form-layout` | No PR; unique permission-form and `AdminSecurity`/`AdminUsers` changes. | Preserve for authorization/security review. |
| `feat/169-f-typed-navigation-ui` | No PR; contains the remaining UI wiring for #169 F. | Active worktree `codex/169-f-navigation-ui`; finish and merge through PR. |
| `feat/admin-media-picker` | Closed #56; unique media/storage implementation not in main. | Preserve pending product/security review. |
| `feat/inventory-ledger` | No PR; unique predecessor ledger changes. | Preserve because inventory history is data-critical. |
| `feat/storefront-mockup-followup` | Closed #63; unique storefront/design work. | Preserve pending comparison with current storefront. |

`feat/mazedoone-brand-storefront-pwa` (#27) is not in the hold list: GitHub confirms its PR merged, and the branch has no branch-only diff against `main`. Retain `origin/HEAD -> origin/dev`; it is a symbolic ref, not a branch.

## Validation notes

- #182 passed responsive secure-shell validation and was merged at `e5ee4a2aaa5e3ae057a2ab38cdde1b6cd9683014`.
- #181 was revalidated after #182; the restricted-menu test assertion was corrected, local tests and CI #463 passed, and it was merged at `f815d3de9706d42df532058b73543009e8ddfed0`.
- #183 was refreshed on the new main, validated, passed required CI #468, and merged at `3ce28e5c87941d0105f774f4e0bebd8f8ff15798`.
- #184 delivered the local launcher at `b6f116d`; CI #465 passed. Full live startup remains blocked by Docker Desktop/PostgreSQL not being installed in this Windows environment.
- Graphify is unavailable in this workspace. The project Issue #151 fallback uses targeted `rg` searches and direct consumer tracing.

## Next cleanup

After #169 F is validated and merged, recheck the exact current refs and delete the 116 proven redundant refs, plus the finished #169 UI branch. Keep the five review/active branches, `main`, `dev`, and refs attached to active worktrees. Remote deletion is still pending; local refs are cleaned only after checking they contain no unmerged work.
