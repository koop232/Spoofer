#!/usr/bin/env bash
# Runs the syntax check, the unit suite, and the bundle freshness check.
set -euo pipefail
cd "$(dirname "$0")/.."

VENV="${VENV:-.venv}"
PY="$VENV/bin/python"

if [ ! -x "$PY" ]; then
  echo "no virtualenv found; run ./scripts/setup.sh first" >&2
  exit 1
fi

echo "==> syntax check"
"$PY" tools/syntax_check.py

echo
echo "==> unit tests"
"$PY" tools/run_lua.py tests/run_tests.lua

echo
echo "==> bundle freshness"
python3 build/bundle.py --check

echo
echo "==> bundle smoke test"
"$PY" tools/run_lua.py tests/smoke_bundle.lua
