# Local Codex handoff

Updated: 2026-10-08

- Current active worktree: `codex/169-f-navigation-ui`, based on the #169 F typed-navigation UI branch and merged with current `origin/main` (`3ce28e5c87941d0105f774f4e0bebd8f8ff15798`).
- Merged since the prior handoff: #182 at `e5ee4a2`; #181 at `f815d3d`; #183 at `3ce28e5`; #184 at `b6f116d`.
- Current task: finish Issue #169 F by routing typed API targets from dashboards and notifications into exact order-state or inventory SKU/batch filters, preserving permissions and back navigation. UI wiring and targeted tests are committed locally at `10b7028`; PR #185 is open for CI/review.
- Local checks: `flutter test test/admin_navigation_flow_test.dart test/dashboard_guided_navigation_test.dart test/notification_navigation_test.dart test/admin_shell_navigation_test.dart` passed (24 tests); `flutter analyze` passed with no issues.
- Branch audit: 123 remote branches excluding symbolic `origin/HEAD`; 116 verified redundant refs can be removed after final ref checks. Five unique branches are preserved for security, product, inventory, design, or active #169 work. See `docs/BRANCH_AUDIT.md`.
- Local launcher: `scripts/dev.ps1` runs a fresh fetched `origin/main` in an ignored worktree by default and offers `-CurrentBranch`. Script parsing and status paths were validated, but full live startup has not been verified because Docker Desktop/PostgreSQL are absent. Do not describe static checks as a successful full launch.
- Available tools: PowerShell 7.6.5, Node 22.14.0/npm 11.19.1, Flutter 3.47.2/Dart 3.13.2, and user .NET SDK 10.0.401. Graphify is unavailable; follow Issue #151's targeted-search fallback.
- Next: complete #169 F acceptance checks, create and validate its PR on current main, merge after CI/review, update the issue/Project status only for completed criteria, then remove proven redundant local/remote branches. After #169, inspect open issues and prioritize P0/security/operational work; the launcher still needs a live Docker-backed run.
