"""In-Blender test runner for the forge library.
blender -b --factory-startup --python-exit-code 1 --python run.py -- [test_module ...] [-k substring]
Each test_*() runs on a fresh empty scene; a test taking a `tmp` parameter gets its own empty directory."""
import importlib
import inspect
import sys
import tempfile
import traceback
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "blender_lib"))
sys.path.insert(0, str(HERE))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    pattern = ""
    if "-k" in argv:
        i = argv.index("-k")
        pattern = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    modules = argv or sorted(p.stem for p in HERE.glob("test_*.py"))
    passed, failed = 0, []
    for mod_name in modules:
        try:
            module = importlib.import_module(mod_name)
        except Exception:
            failed.append(mod_name)
            print(f"FAIL: {mod_name} (import)\n{traceback.format_exc()}")
            continue
        for name, fn in sorted(inspect.getmembers(module, inspect.isfunction)):
            if not name.startswith("test_") or fn.__module__ != module.__name__ or pattern not in f"{mod_name}::{name}":
                continue
            bpy.ops.wm.read_factory_settings(use_empty=True)
            label = f"{mod_name}::{name}"
            try:
                if "tmp" in inspect.signature(fn).parameters:
                    with tempfile.TemporaryDirectory(prefix="forge-test-") as tmp:
                        fn(tmp=Path(tmp))
                else:
                    fn()
            except Exception:
                failed.append(label)
                print(f"FAIL: {label}\n{traceback.format_exc()}")
            else:
                passed += 1
                print(f"PASS: {label}")
    print(f"\n{passed} passed, {len(failed)} failed")
    for label in failed:
        print(f"  failed: {label}")
    sys.exit(1 if failed else 0)


main()
