# Branch audit — 2026-10-08

Scope: all 123 `origin/*` refs were compared with `origin/main` after `git fetch --all --prune`. Each PR association was read from GitHub; merged PRs were checked with their merge commit rather than branch age alone.

## Result

| Classification | Count | Decision |
| --- | ---: | --- |
| Protected | 2 | Preserve `main` and `dev`. |
| Merged PR verified in main | 109 | Safe to delete after a final remote-ref check. |
| Direct ancestor of main | 4 | Safe to delete after a final remote-ref check. |
| Open PR | 1 | Keep and finish #183. |
| Needs individual review | 7 | Preserve. |

The four direct ancestors are `feat/admin-media-picker-v2`, `fix/169-f-admin-shell-responsive-ink` (#182), `refactor/169-e-admin-shell` (#180), and `refactor/169-e-remove-legacy-operations-shell` (#181). PR #182 merged as `e5ee4a2aaa5e3ae057a2ab38cdde1b6cd9683014`; #181 merged as `f815d3de9706d42df532058b73543009e8ddfed0`.

The 109 verified merged refs span the delivered catalog, inventory, orders, identity, RBAC, customer, reporting, media, storefront, audit, and admin-shell work. They are retained temporarily until #183 is complete so that no useful recovery point is removed during the dependent release work.

## Branches retained for work or review

| Ref | Evidence | Decision |
| --- | --- | --- |
| `feat/169-f-batch-aware-navigation-contract` | Open PR #183. CI #453 was green at `9b89be7`, but its base predates #181 and GitHub reports a merge conflict. | Rebase/merge against current main, rerun validation, then merge. |
| `codex/admin-edit-permissions-form-layout` | No PR; changes both admin permission UI and `AdminSecurity`/`AdminUsers`. | Preserve for security review and recovery. |
| `feat/169-f-typed-navigation-ui` | No PR; provides the UI half of #169 F typed targets. | Preserve; evaluate after #183 API contract lands. |
| `feat/admin-media-picker` | Closed #56, not in main; includes storage API and UI. | Preserve pending product decision. |
| `feat/inventory-ledger` | No PR; isolated predecessor implementation. | Preserve because inventory is data-critical. |
| `feat/mazedoone-brand-storefront-pwa` | #27 is merged but this ref diverged after its merged head. | Preserve pending diff review. |
| `feat/storefront-mockup-followup` | Closed #63, not in main. | Preserve pending design review. |

`origin/HEAD -> origin` is a remote symbolic ref, not a branch, and must not be deleted.

## Validation notes

- #182 was merged only after a clean local merge onto current main, `flutter analyze`, and the secure-shell responsive tests passed.
- #181 was revalidated on top of #182. A duplicate text assertion was corrected to target the sidebar menu; the related Flutter test suite passed locally and CI #463 passed at `7f85846` before merge.
- Graphify is unavailable in this workspace (`command not found`). The targeted `rg` fallback is recorded in Issue #151 and used for the changes above.

## Next cleanup

After #183 merges and its main SHA is verified, delete the 113 refs in the two safe categories locally and remotely in small, auditable batches. Do not remove the seven retained refs, `main`, `dev`, or branches attached to active worktrees.

