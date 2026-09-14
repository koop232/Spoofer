# CI configuration

`github-actions.yml` is the CI pipeline for this project. It is stored here
rather than in `.github/workflows/` because the GitHub App used to push this
branch does not hold the `workflows` permission and the push is rejected
outright when a workflow file is included.

To enable it:

```bash
mkdir -p .github/workflows
git mv ci/github-actions.yml .github/workflows/ci.yml
git commit -m "Enable CI workflow"
```

It runs on every push and pull request:

1. `python tools/syntax_check.py` — parses every Lua file
2. `python tools/run_lua.py tests/run_tests.lua` — 70 unit assertions
3. `python build/bundle.py --check` — fails if `dist/` is stale
4. `python tools/run_lua.py tests/smoke_bundle.lua` — loads the shipped bundle

The same four steps run locally via `./scripts/test.sh`.
