#!/usr/bin/env bash
# Provisions the local Lua runtime used by the test + syntax harness.
set -euo pipefail
cd "$(dirname "$0")/.."

VENV="${VENV:-.venv}"

if [ ! -d "$VENV" ]; then
  echo "==> creating virtualenv at $VENV"
  python3 -m venv "$VENV"
fi

echo "==> installing lupa (embedded Lua runtime)"
"$VENV/bin/pip" -q install --upgrade pip lupa

echo "==> ready. run ./scripts/test.sh"
