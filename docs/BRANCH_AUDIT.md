# Branch audit — 2026-10-09

Audited remote refs after refreshing `main` to `b533a64fcaff44afeb63ae49841b2f94dc67ba3e`. The repository currently has 11 branches (excluding `origin/HEAD`). Decisions below use PR status, merge evidence and whether unique commits remain; branch age alone is not used.

## Remote branches retained

| Branch | Evidence | Decision |
| --- | --- | --- |
| `main` | Current default delivery branch. | Preserve. |
| `dev` | Integration branch; not a cleanup candidate. | Preserve. |
| `feat/169-f-typed-navigation-ui` | Open PR #185; all four checks green on head `247fb4a`; required independent Sol permission/route review is absent and base needs refreshing. | Keep; review and revalidate before merge. |
| `codex/admin-permission-form-review` | Open PR #186; all four checks green on head `ff098d3`; required independent Sol security review is absent and base needs refreshing. | Keep; review and revalidate before merge. |
| `codex/local-launcher` | PR #184 is merged; the launcher worktree remains active and full Docker startup is blocked by missing Docker Desktop/WSL. | Preserve while the worktree is active. |
| `codex/92-dashboard-custom-range` | PR #189 is merged as `4fde631`; tip `41f60d5` was the reviewed PR head. | Delete after merge confirmation; deletion is pending because no authenticated delete-ref path is available in this environment. |
| `codex/92-dashboard-health` | PR #190 is merged as `b533a64`; tip `d9bba1d` passed all four checks. | Delete after merge confirmation; deletion is pending because no authenticated delete-ref path is available in this environment. |
| `codex/admin-edit-permissions-form-layout` | No open PR; unique permission UI/API work remains. | Preserve for review and recovery. |
| `feat/admin-media-picker` | Closed PR #56 is unmerged; unique storage API/UI work remains. | Preserve for follow-up. |
| `feat/inventory-ledger` | No open PR; unique, data-critical implementation remains. | Preserve for review and recovery. |
| `feat/storefront-mockup-followup` | Closed PR #63 is unmerged; unique storefront UX work remains. | Preserve for design review. |

Previously verified merged/no-delta branches are absent from the current remote list: `feat/admin-media-picker-v2`, `feat/mazedoone-brand-storefront-pwa`, `feat/169-f-batch-aware-navigation-contract`, and the merged #181/#182 branch refs. The local-only `refactor/169-e-remove-legacy-operations-shell` remains preserved because it diverges from its deleted remote ref and may contain recoverable commits. The local duplicate working branch `codex/92-dashboard-next` was removed after confirming its implementation had landed in #190 and retaining no unique commit.

## Open delivery work

- #169 remains open. A–E and responsive shell work are in `main`. #185 contains the typed-navigation F slice, but the mandatory independent permission/route review is absent; its CI is green on the old base, so refresh and revalidate before merge.
- #91 remains open. #186 contains only the per-user permission editor slice; independent security review is absent and MFA/step-up plus expanded IDOR work remain.
- #92 remains open. PR #187 delivered role preferences, #189 delivered device-local date ranges, and #190 delivered an authenticated safe readiness summary. Remaining work includes actionable health alerts, broader cross-module drill-downs and other acceptance criteria in the issue.

## Cleanup and validation

- Remote deletion was attempted for merged #190 branch `codex/92-dashboard-health`; `git push` could not authenticate (`fatal: could not read Username`). The GitHub connector exposes branch create/update but no branch delete operation. The merged #189 ref is likewise still present. Do not claim either remote ref has been deleted.
- `main`, `dev`, open-PR branches, branches with unique work and the active launcher worktree were preserved. No shared branch was force-pushed.
- Graphify is unavailable (`command not found`); focused `rg` consumer searches were used as the #151 fallback.
- Full local launcher readiness is not verified: Docker Desktop/WSL are unavailable. See `docs/LOCAL_CODEX_HANDOFF.md`.

