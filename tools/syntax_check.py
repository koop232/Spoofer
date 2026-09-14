#!/usr/bin/env python3
"""Parse every Lua source in the repository and report syntax errors."""
import glob
import sys

from lupa import LuaRuntime

PATTERNS = ("src/**/*.lua", "dist/*.lua", "tests/*.lua")


def main() -> int:
    runtime = LuaRuntime()
    check = runtime.eval(
        """
        function(source, name)
            local fn, err = load(source, name)
            if fn then return '' else return err end
        end
        """
    )

    files: list[str] = []
    for pattern in PATTERNS:
        files.extend(glob.glob(pattern, recursive=True))
    files = sorted(set(files))

    bad = 0
    for path in files:
        with open(path, encoding="utf-8") as handle:
            error = check(handle.read(), "@" + path)
        if error:
            print(f"SYNTAX  {path}: {error}")
            bad += 1
        else:
            print(f"ok      {path}")

    print(f"\n{len(files) - bad}/{len(files)} files parse")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
