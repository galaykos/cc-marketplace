---
name: godot-headless-testing
description: Use when running Godot GDScript tests from a terminal or CI — `godot --headless --script`, a SceneTree test runner, a GitHub Actions job that must fail on a failing `.gd` test — or when a headless run hangs, opens a window, exits 0 despite failed checks, or reports `Identifier "X" not declared in the current scope` only on a fresh checkout.
---

> Last verified: 2026-10-26 — https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
<!-- version-tail-ok: the stamp points at Godot's command-line docs; the engine ships as a binary with
     no npm/composer/pypi package, so check-doc-staleness --live has nothing to compare. -->

Generic test doctrine (what to test, determinism, pyramid) is `testing:testing-best-practices`.
This skill is only the Godot mechanics that make a CLI run lie or hang.

## Before anything

- Read the engine minor from `project.godot` (`config/features`) and use a `godot` binary of
  that minor; `godot --headless --version` must print a version, not open a window.
- If the project already ships a test addon (`addons/gut/`, `addons/gdUnit4/`), run that
  addon's own command line instead. The runner below is for projects with none.

## The rules

| Rule | Why it bites | Standing |
|---|---|---|
| On a clean checkout run `godot --headless --path <dir> --import` before tests | `.godot/` is not committed, so `class_name` types fail with `Identifier "X" not declared in the current scope` and assets with `No loader found for resource` | **recorded** |
| The runner `extends SceneTree` and works in `_initialize()`; no scene needed | A scene-based runner drags in a main scene and a window | **recorded** |
| Count failures and end with `quit(1 if failed > 0 else 0)` | `push_error()` never changes the exit code; a runner that does not call `quit()` with a code always exits 0, or never exits | **gate** for the CI job once the runner does this — the step fails on exit 1 |
| No bare `assert()` in tests | A failed `assert()` in a debug build stops the function before `quit()` runs: the process never exits and CI waits for its timeout | **recorded** |
| Each test returns `bool` and ends `return true`; count anything else as a failure | A runtime error (a method called on `null`) aborts only that test function; the caller gets a default value back and the run would still exit 0 | **recorded** — the runner below enforces it for tests that follow the shape |
| `await process_frame` before using `root`, timers or signals | During `_initialize()` `root` is not in the tree yet: a Timer started there errors and never fires, and the run hangs | **recorded** |
| Every `await` has a timeout path, and the CI step has `timeout-minutes` | An awaited signal that never fires hangs the runner forever | **recorded**; the CI timeout is the only backstop that fires unasked |
| From PowerShell or a wrapper shell, redirect stdout and stderr to files and read them after exit | `push_error()` goes to stderr; live capture can reorder or drop it | **recorded** |

## The runner

```gdscript
# res://tests/run_tests.gd
# godot --headless --path . --script res://tests/run_tests.gd
extends SceneTree

var tests := ["test_add", "test_timer_fires"]
var passed := 0
var failed := 0

func _initialize() -> void:
    await process_frame  # root is in the tree from here on
    for t in tests:
        var ok = await call(t)  # a non-coroutine test returns at once
        if ok == true:
            passed += 1
        else:
            failed += 1
            push_error("FAIL %s (returned %s: failed check or runtime error)" % [t, ok])
    print("Results: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

func check(cond: bool, label: String) -> bool:
    if not cond:
        push_error("check failed: %s" % label)
    return cond

func test_add() -> bool:
    return check(2 + 2 == 4, "2 + 2")

func test_timer_fires() -> bool:
    var timer := Timer.new()
    timer.one_shot = true  # a Timer restarts after timeout by default
    root.add_child(timer)
    timer.start(0.1)
    await timer.timeout
    timer.queue_free()
    return true
```

## The CI step

```yaml
- name: Import project (fills .godot/ on a fresh checkout)
  run: godot --headless --path . --import
- name: GDScript tests
  timeout-minutes: 5
  run: godot --headless --path . --script res://tests/run_tests.gd
```

No flag makes Godot fail the step; the runner's `quit()` code does. Check that
`godot --help` on your minor lists `--import` before relying on it.

## Anti-patterns

- **The green that never ran** — a runner that ends in `quit()` or `quit(0)` unconditionally.
- **The silent skip** — tests declared `-> void`, so a test aborted by a runtime error is
  indistinguishable from one that passed.
- **Assert-and-hope** — bare `assert()` as the failure signal; it hangs instead of failing.
- **Timer at time zero** — starting a Timer in `_initialize()` before `await process_frame`.
