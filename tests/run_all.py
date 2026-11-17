"""Run every test script against a mock of the WoW API.

Usage: python3 tests/run_all.py        (needs: pip install lupa)

Tests run under LuaJIT when available, which matches the game's Lua 5.1.
Each script loads the addon fresh; a script fails if it raises an error or
if the addon recorded any errors of its own (JPMF_DB.errors).
"""
import os
import sys

try:
    from lupa import luajit21 as lua
except ImportError:
    import lupa as lua

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE) + os.sep
SCRIPTS = ["run.lua", "fresh.lua", "accounts.lua", "extras.lua", "levels.lua"]


def run(script, verbose):
    L = lua.LuaRuntime(unpack_returned_tuples=True)
    with open(os.path.join(HERE, "mock.lua")) as f:
        L.execute(f.read())
    L.globals().DIR = ADDON
    try:
        with open(os.path.join(HERE, script)) as f:
            L.execute(f.read())
        errors = L.eval("#JPMF_DB.errors")
    except Exception as e:  # a Lua error escaped
        print(f"FAIL {script}: {e}")
        return False
    finally:
        if verbose:
            for line in L.globals().PRINTS.values():
                print("   ", line)
    ok = errors == 0
    print(f"{'ok  ' if ok else 'FAIL'} {script} ({errors} addon errors)")
    return ok


if __name__ == "__main__":
    verbose = "-v" in sys.argv
    results = [run(s, verbose) for s in SCRIPTS]
    sys.exit(0 if all(results) else 1)
