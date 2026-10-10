# Graphify in agent workspaces

Use a local Mazeduneh checkout and Python 3.10 or newer. From the repository root, run:

```sh
python scripts/graphify.py --version
python scripts/graphify.py . --code-only --no-viz
python scripts/graphify.py query "Which files handle checkout?"
python scripts/graphify.py update .
```

The first command creates `.graphify-venv/` and installs the public `graphifyy` package at the version recorded by both Graphify skills. The isolated environment is ignored by Git. Keep `.agents/skills/graphify/.graphify_version` and `.codex/skills/graphify/.graphify_version` aligned when updating the vendored skill.

`--code-only` builds the AST graph without an LLM key. Graphify writes generated output under `graphify-out/`; its interpreter pointer and transient cache files are ignored so a local absolute path is not committed. CI uses a temporary source fixture to verify the version, build, query, and incremental update without secrets.

If the execution surface cannot mount a checkout, Graphify cannot run there. Use focused GitHub code searches or open the relevant files in the browser as a limited fallback, and state that graph generation was not run. Do not present remote browsing as Graphify output. In Codex, use a repository worktree when one is available.
