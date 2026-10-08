# Branch audit — 2026-10-09

Repository: `Hamrez95/Mazeduneh`; base: `main` at `3ce28e5c87941d0105f774f4e0bebd8f8ff15798`. GitHub's current branch API returned 124 remote branches; local `git fetch --all --prune` completed, and the local refs matched GitHub except for the three current open PR heads documented below. The audit excludes the symbolic `origin/HEAD` ref.

## Outcome

| Classification | Count | Evidence and action |
| --- | ---: | --- |
| Protected | 2 | Keep `main` and `dev`. |
| Merged PR heads | 108 | Exact branch head matched its merged PR head, and the merge commit is reachable from `main`; full branch, PR, and head-SHA inventory below. Safe to delete after the pending action-time confirmation. |
| Direct ancestors | 6 | Branch tip is reachable from `main`; the PRs are merged where applicable. Safe to delete after the pending action-time confirmation. |
| Merged PR with no current branch delta | 1 | PR #27's merge commit is in `main`; current branch tip's tree equals its merge-base tree after the later revert/align commit. Safe to delete after confirmation. |
| Open PRs | 3 | Keep and finish #185, #186, #187. |
| Preserve for review/work | 4 | Unique changes or closed-PR follow-up not proven redundant; details below. |

There are 115 proven-redundant remote refs (108 merged PR heads + 6 ancestors + 1 merged PR with no current branch delta). `codex/local-launcher` is attached to an active worktree, so it remains for now; 114 refs are otherwise eligible for cleanup. No merged PR evidence is inferred from branch age or `git branch --merged` alone. No force-push was used.

## Open pull requests

| PR | Branch | Latest code SHA | Status |
| --- | --- | --- | --- |
| #185 | `feat/169-f-typed-navigation-ui` | `5c096c9345e5c2cf20b1317b86fc5a03e826e1be` | CI #481 passed on code SHA `5c096c9` (API, Admin Flutter, Storefront); the current commit after that is docs-only. Vercel success. Local navigation-flow test passed with device/system-back coverage. Required independent permission/route review is still absent. Completes only one UI slice of #169 F. |
| #186 | `codex/admin-permission-form-review` | `e3ce2abb3ea9962cc4e95edc8a8e31b0466b3eff` | CI #477 passed after isolating the authorization test from the intentional five-request login rate limit. Requires independent Sol security review. |
| #187 | `codex/dashboard-role-widgets` | `b20622ad10721ea7ebd20852e3c4471fa8339de1` | CI #475 passed all jobs after using distinct canonical operator roles in the isolation test. |

The branch updates above retain their GitHub PRs open. Merge only after the current CI result, review requirements, and current-main validation pass.

## Preserve for review/work

| Branch | Evidence | Decision |
| --- | --- | --- |
| `codex/admin-edit-permissions-form-layout` | No PR. Contains permission editor/API work overlapping #186 but is not proven entirely contained in that open PR. | Keep until #186 is merged and its ancestry/content is rechecked. |
| `feat/admin-media-picker` | Closed PR #56; its remaining diff has not been proven redundant with merged PR #57. | Keep and compare before deciding. |
| `feat/inventory-ledger` | No PR; data-critical inventory changes remain outside `main`. | Keep for review. |
| `feat/storefront-mockup-followup` | Closed PR #63; unique design follow-up remains outside `main`. | Keep for product/design review. |

## Merged PR with no current branch delta

| Branch | PR | Evidence | Decision |
| --- | --- | --- | --- |
| `feat/mazedoone-brand-storefront-pwa` | #27 | PR #27 merged at `d9cba6ab99083c8305d77a6d90e2d0a198789573`, reachable from `main`. Current branch tip `313bdb63b4f53dee8096b0439345ec356a744c26` has the same tree as merge-base `96d16a3e5ed86526e7d15b499ec59b7460339be5`; the post-merge align commit leaves no effective branch delta. | Safe to delete after confirmation. |

## Direct ancestors of main

| Branch | PR | Head SHA | Evidence |
| --- | --- | --- | --- |
| `codex/local-launcher` | #184 | `b4fe815ad8438424f0460a66537b98c307b44e19` | Merged and reachable from `main`; retain only while its active worktree is in use. |
| `feat/169-f-batch-aware-navigation-contract` | #183 | `1413d73112a85fffaefd694b0907b2757bfb8d6c` | Merged; reachable from `main`. |
| `feat/admin-media-picker-v2` | — | `d5ea093600d11f3965c9c03078e5976de4a2dabb` | Tip is reachable from `main`; no unique commits after it. |
| `fix/169-f-admin-shell-responsive-ink` | #182 | `13b83a14dd4a98053a6e1ecf9b0668a23776ede7` | Merged; reachable from `main`. |
| `refactor/169-e-admin-shell` | #180 | `d9edff1103331ba8df2592df524922889490b220` | Merged; reachable from `main`. |
| `refactor/169-e-remove-legacy-operations-shell` | #181 | `7f85846230ed3e9046ea2db4fb2a32afdbf98b33` | Merged; reachable from `main`. |

## Local branches and worktrees

The local checkout has no uncommitted changes. The following refs are deliberately retained because they are active, differ from their remote/main counterpart, or contain work not yet proven redundant:

| Local branch/worktree | Current evidence | Decision |
| --- | --- | --- |
| `codex/169-f-navigation-ui` | Active PR #185 worktree; local test commit `3f9e3b0` mirrors remote `5c096c9`, while audit/handoff commits remain separate. | Keep until #185 is reviewed/merged. |
| `codex/admin-edit-permissions-form-layout` | Unique permission editor/API branch; preserved above. | Keep. |
| `codex/admin-permission-form-review` | Active PR #186 worktree with a newer local rate-limit test fix; CI #477 passed on the pushed commit. | Keep. |
| `codex/dashboard-role-widgets` | Active PR #187 worktree; CI #475 passed on the pushed commit. | Keep. |
| `codex/local-launcher` | Active worktree; local `ef2f524` differs from merged remote PR #184/main and contains launcher/security/test changes. | Keep for review; do not delete the connected remote ref yet. |
| `codex/storefront-admin-operations-finance` | Active worktree with untracked/generated project files and branch-specific commerce changes. | Keep; preserve its working files. |
| `refactor/169-e-remove-legacy-operations-shell` | Remote PR #181 is merged, but the local branch has two commits beyond `main` and differing shell/order/test files. | Keep pending comparison; remote merge does not prove the local-only work is redundant. |
| `dev`, `main` | Protected/release refs. | Keep. |

Local `codex/validate-183` was removed after confirming its tip is an ancestor of `main` and it was not attached to a worktree. The stale local `feat/169-f-typed-navigation-ui` ref was removed after confirming it is an ancestor of the active PR #185 head; its duplicate, detached merge worktree was archived as a recoverable snapshot. No staged or untracked work was discarded.

## Verified merged PR heads

Each row records the exact current remote branch tip and its merged PR number. The PR merge commit is present in `main`; no branch-only commits remain.

| Branch | Merged PR | Remote head SHA |
| --- | ---: | --- || `chore/portable-host-config` | #146 | `699463920480f88440adf293374089cb6479e48b` |
| `chore/remove-ci-debug-diagnostics` | #107 | `391086c4e9e694d5bf343f5cd897ce2ec654ab9c` |
| `codex/admin-audit-log-foundation` | #126 | `d2fb00ac0864fbce8febe240297a200252793564` |
| `codex/admin-audit-log-ui` | #127 | `37096be78ffb5552842305d92e84bad3af6df7f7` |
| `codex/admin-bulk-order-state` | #123 | `8f6167b5e2c4ddd4e5484567e730a688b5f03116` |
| `codex/admin-dashboard-period-kpis` | #124 | `c00902228a10f07b756898ca0d6b4958cb055d31` |
| `codex/admin-permission-navigation` | #129 | `40c4f3e3a82ae2b61162669fed63ee4c8499161b` |
| `codex/admin-session-revocation` | #125 | `e0077776c26152db7d8e53e49a2392b3df41728e` |
| `codex/admin-user-management-ui` | #131 | `f66c61cd32429e20e564f6caec417e51abacd16e` |
| `codex/admin-user-memberships` | #130 | `c7a55cc0432064ac7eb6e3a00446fc40b23d9cd9` |
| `codex/catalog-publication-readiness` | #121 | `bd778a4f198acbc3620ae3a1123a27cef989f253` |
| `codex/corporate-follow-up-queue` | #135 | `2e99e945326bdd2ecc99e329a2034acdbf1bc8bf` |
| `codex/crm-customer-export` | #120 | `9356f98e0af9d27af1f5fda838a68369123be003` |
| `codex/crm-customer-purchase-metrics` | #122 | `d079edec06fb63e349805264f386deb121663fa6` |
| `codex/inventory-expiry-alerts` | #117 | `c56cb09e5eee0c70948d40f2e4627dfb8ed2c671` |
| `codex/operations-dashboard-alerts` | #132 | `19a00c02fdceae1515e8b683940d10eadffcd31a` |
| `codex/order-packing-slip` | #118 | `a6f598c388b4b1de9372224ec4c0a4e248e44591` |
| `codex/orders-csv-and-expiry-regression` | #119 | `e26c623756e97115fb2587743b1e1dfaa4a9da2d` |
| `codex/overdue-shipping-report` | #133 | `9beed0c433842b9d8983075ba39a8a27bed2b470` |
| `codex/product-profitability-report` | #134 | `220578ea7fd8077ad89162f537c78a3d1f5c5481` |
| `codex/rbac-permission-matrix` | #128 | `e773a12ddaa665be2364d6cda68d17761276d562` |
| `feat/admin-category-lifecycle` | #61 | `4d2d087b1c9bd6ab6cd68ac4385e38e272d7bfb7` |
| `feat/admin-category-management` | #58 | `56bc6ddf9d41acf1ebd32e742495c89649cf8936` |
| `feat/admin-customer-operations` | #79 | `812a09c53420f015445321b124dd2783c00717f1` |
| `feat/admin-dashboard-guided-operations` | #102 | `72f559070c701497cf8090a660ecc9aa5a1bc5c1` |
| `feat/admin-design-system-dashboard` | #52 | `8304eed15787a4a2f19209668fa8536ea65f5f0e` |
| `feat/admin-inventory-ui` | #51 | `41ca923b745059fd5fe203ef2ded5b619c2b7abd` |
| `feat/admin-media-picker-rebased` | #57 | `cbebe41beca4c26f29913c80def68746e31588da` |
| `feat/admin-media-ux` | #54 | `af70a388bdd0d4203812953088a310d7c2d741e9` |
| `feat/admin-membership-login` | #152 | `b1c644e1307aacdf2c592fef51fda51d52dc142b` |
| `feat/admin-mobile-navigation-overflow` | #104 | `0614b69af1b63a66f596c308fa240b522f437810` |
| `feat/admin-notification-center` | #60 | `9b5a31426d952e4f1dfcfb8ba6e3b05064e3ad88` |
| `feat/admin-order-detail-timeline` | #113 | `dcd56c7f7e0126bb01dbd22db360cad9d8d005b4` |
| `feat/admin-order-internal-notes` | #114 | `48a2d122b61447d4aad380b92fbd2c41897ecc32` |
| `feat/admin-order-invoice-export` | #116 | `d183564e365f8a5a7f0290f4444930c6c4de205b` |
| `feat/admin-order-search-filter` | #111 | `2cb17e8ac63cd87b123c03c38e67bfaef0628ae6` |
| `feat/admin-order-shipping-tracking` | #115 | `db16b08f50c2e48bd4f14a1f29154334e210b692` |
| `feat/admin-orders-ui` | #50 | `45275f88b898ddd13bf172211050b11dc350da0e` |
| `feat/admin-persian-numerals` | #71 | `3e56c7c2cbe00ebe1b4b475c57c3f96339f8bdee` |
| `feat/admin-pricing-and-invoice` | #85 | `7fa6d9fd58fae314d8535e9bca5df3c95d902f05` |
| `feat/admin-product-content` | #59 | `d5b3377026b74178135103cd6e16de6127defeea` |
| `feat/admin-reports-ui` | #53 | `2b92dd49278bd042627230ff879f891438279e1b` |
| `feat/admin-session-identity-contract` | #105 | `13c425e5ad23a4260303d7ca9ab70c10370b3707` |
| `feat/admin-shared-request-states` | #73 | `4bf97416107b341b03aff608cdb885435f440a15` |
| `feat/admin-shared-state-primitives` | #103 | `3b6314d067f555c249d23cf1c9330072fa315b78` |
| `feat/api-admin-permission-contract` | #108 | `5dba452d9df20bb1ac389853d1d0f44c8ab8af1f` |
| `feat/api-request-observability` | #138 | `d24616b41fd89682d3b5fd073bde0dfeef68d091` |
| `feat/audit-order-shipping` | #157 | `62d3708d334a10b0167f4983f807029f042d817d` |
| `feat/audit-order-state-transitions` | #158 | `21394b672cbce74ae6efc9a55b015b0e0d063b9c` |
| `feat/batch-selling-price` | #145 | `0c4968cf7e533686d07a2ea568e321ddf17db7b7` |
| `feat/commerce-pricing-and-invoices` | #84 | `5b2162ce1545b8d285f34ca2397f32c9aae731a3` |
| `feat/corporate-admin-controls` | #90 | `6e3e1d03c89321a60ac3069e8774d9d90cf30a67` |
| `feat/corporate-planning-queue` | #143 | `b78a6bbe8396b9a8320ae33e9cc4aa2c5701ae82` |
| `feat/corporate-sales-platform` | #89 | `6d21a6e7e85366eba02a453f16808e04a1bbe37b` |
| `feat/customer-consent-filter` | #164 | `53ff174250a50832c9258915ebcbab7a8fa3c921` |
| `feat/customer-identity-guest-checkout` | #78 | `05f63079dd376371d52bf3f725b3d39e714b13ca` |
| `feat/customer-profile-details` | #81 | `e5fd7e081f930da7ae143d3c0b43be4cc02edf89` |
| `feat/customer-server-search` | #166 | `d98a0cbdb4296a3955223f5630ac895a6189c2c6` |
| `feat/dashboard-kpi-drilldowns` | #163 | `00b46adf5f45c8f84d76411830b835c4bb27f816` |
| `feat/fefo-accounting-invoices` | #87 | `99b2ca8dabf9b104a5657477544f58372049dfee` |
| `feat/inventory-batch-waste` | #161 | `2bbd468b292a100d68b90a83ec09a171fde77322` |
| `feat/inventory-batches-expiry` | #86 | `219f642149a26e621c75ee35949a4508ecae0e9b` |
| `feat/inventory-purchase-filter` | #148 | `e8e5eeba1e68755b460f8dde003ad3cd818a90a9` |
| `feat/inventory-purchase-history` | #147 | `377149bddcc7d5ed4ddbdebca05748b5db0d2f0f` |
| `feat/inventory-purchase-pricing` | #144 | `a0164c7b1c921b31a5e07ea15adc480001351303` |
| `feat/inventory-supplier-snapshot` | #150 | `1f9d45aa0708d1abc2f1afa643abd2420e4bad07` |
| `feat/media-storage-provider` | #70 | `0f06a63bebbeb9c78dabea2f37bb43e88726c7b4` |
| `feat/media-upload-storage` | #55 | `809d566627b89f41864bde7a5998731acbe036db` |
| `feat/notification-guided-navigation` | #139 | `b25245d3e714714146837a56de1ba251df0cee9f` |
| `feat/product-nutrition-and-costing` | #83 | `1ee31c4587b75624cbb708552ea41b5dd6008562` |
| `feat/shipping-expense-admin-numerals` | #88 | `3a1fe18709466a1e2ac105055ba13935be3762af` |
| `feat/storefront-data-driven-media` | #72 | `723e306f0dd09815dea85cea5335d881228ef314` |
| `feat/storefront-header-and-media-fix` | #66 | `433cfe35fa256d3666a7e7eab044c39c64e3922c` |
| `feat/storefront-media-and-mobile-header-fix` | #67 | `c8ce44c725c1a79b6dc4ee44c70455afc83da359` |
| `feat/storefront-mobile-header-layout` | #68 | `eb6ed6e24d93ded4c4992c4f3234d958cd142e96` |
| `feat/storefront-mockup-followup-v2` | #64 | `edc17b91c02d66fd424c9f7a853e08bcdda9291d` |
| `feat/storefront-mockup-foundation` | #62 | `e4f441da9933aff98d49eecf86350a59aee4a9d6` |
| `feat/storefront-navigation-unification` | #65 | `2df2d1a910b9b0f31b5b0205f5accd34a305f559` |
| `feat/storefront-product-gallery-localization` | #69 | `b80e64f8267269c647c1c0b71ee1bba9c34d6db1` |
| `feat/versioned-database-migrations` | #80 | `f7ebcf3b53d7a058899ac7fd702b02ca69f96ed2` |
| `fix/169-a-secure-entry` | #170 | `bf5a56c0a1a5c54a3164ff2553582de3412a2fad` |
| `fix/169-b-order-privacy` | #171 | `281689fbb49c06fee7fbe60e6e1620625b92eb1f` |
| `fix/169-c-stock-invariant` | #172 | `e112deb01996713259ab06f8b1124ced284fc035` |
| `fix/169-d-strict-integers` | #173 | `69581f771bb7eef396369ad42ef8ee9ef623df49` |
| `fix/admin-secure-pwa-entrypoint` | #155 | `10aa328dc548f3d2877ee97e8ed73864e86e935c` |
| `fix/api-audit-actor-propagation` | #110 | `dbbf616b50dde720c0138c4e0789476c6f1d2ed0` |
| `fix/api-order-search-validation` | #112 | `928cff96c29171257e5929e43d7e3ccd5072b482` |
| `fix/api-readiness-gate` | #136 | `c18a9b63b636774963088d5f1e3c89d4da7bf21e` |
| `fix/catalog-zero-initial-stock` | #141 | `611da94f0c1a85f9fe51943d17b01d5d7a13ea13` |
| `fix/corporate-mobile-filters` | #142 | `e8dcf02bbc054d37d638bc04049d8b07fb95c096` |
| `fix/customer-export-permission-ui` | #168 | `a9e074ffc13c9fa0ffc07cacdbf4af356bae3dbc` |
| `fix/customer-export-pii-permissions` | #165 | `30d5a2c6280039a41ee2508f68bc9010c375b8bd` |
| `fix/customer-pii-role-masking` | #162 | `3dc32fde93bf39c9102147f3b7f2bb4372e549be` |
| `fix/dashboard-permission-actions` | #137 | `27cae6f70bf7c86ee53be15d052c9c530c27a0d9` |
| `fix/dashboard-role-data` | #160 | `8bff0be58f376b597cacc5785d0fb628606c7924` |
| `fix/notification-permission-projection` | #140 | `8bf7583663525cc397e0ec7dcf507f9558719c56` |
| `fix/order-bulk-menu-action` | #167 | `ee7de2d2fc005098a82ae5adddf9a7e45fbfb2af` |
| `fix/storefront-admin-source` | #154 | `41deb3342b55fd711c2d3c862110b186ad5b482f` |
| `refactor/169-e-catalog-page` | #179 | `2cc9b292b597a5e8f9549f762e75f0137a2126be` |
| `refactor/169-e-dashboard-page` | #176 | `d28f7775b6296b7c29aa56a4952a89f36ffb7e64` |
| `refactor/169-e-inventory-page` | #178 | `993e3b72bfd14529d44c8811746a3f7e010afd7f` |
| `refactor/169-e-notifications-page` | #175 | `b7ac9806e88a878782a851da3b56c918b819fdf0` |
| `refactor/169-e-orders-page` | #177 | `309a530c2423ae9502a68f303fd9bfe15b498371` |
| `refactor/169-e-reports-page` | #174 | `a5abe3687d66da08470a3bf97e10512866e631c2` |
| `refactor/admin-theme-foundation` | #156 | `961dafa524c26e9b260c4ed6fbcc75456725aba4` |
| `refactor/admin-theme-provider` | #159 | `cc7651e2ada84a0a7b81d07d608a23b22a150e23` |
| `test/admin-cross-store-isolation` | #153 | `23bc5d37ca9db0e6f3146f459e7691b848f13bfb` |
| `test/ci-admin-permissions-contract` | #109 | `9987ab4f7e9cd713fc3f2465c14f23ed93ee0fae` |

