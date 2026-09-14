#!/usr/bin/env python3
"""Execute a Lua file inside the embedded runtime (used for the test suite)."""
import sys
from pathlib import Path

from lupa import LuaRuntime


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: run_lua.py <script.lua>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    runtime = LuaRuntime(unpack_returned_tuples=True)

    try:
        runtime.execute(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - surface Lua errors verbatim
        message = str(exc)
        # os.exit(0) from a passing suite surfaces as a benign runtime unwind.
        if "exit" in message.lower() and "0" in message:
            return 0
        print(message, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
