# Changelog — defold

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-26

- **New plugin: `defold-best-practices` and `scripts/check_defold_project.py`.**
  - **The checker** is read-only, Python 3.10+, stdlib only. It reports references Bob will fail to resolve before you run Bob:
    - `game.project` roots without the compiled `c` suffix, or missing (Defold's defaults are checked when a key is absent);
    - quoted `/paths` in collections, game objects, atlases, GUI and other resources, including the escaped embedded `data:` strings;
    - `require "a.b"` modules and `resource.*` properties in scripts;
    - letter-case mismatches that break only on Linux, `.defignore`d files, and paths from fetched library archives.
    - Exit 0 clean, 1 on errors (`--strict`: on warnings too), 2 when there is no `game.project`. `--json` prints one object.
  - **The skill:**
    - version reading (`game.project` has no version key);
    - the check → Bob → headless-smoke loop with each step's standing;
    - the footguns: Bob's one-letter-short error, `_generated_*.factory` errors, slash-path `require`, proxy socket clashes, `fixed_update` needing two settings, a headless engine that keeps running after a Lua error, Remotery port collisions, JDK 25.
  - **References:** the Bob smoke-test recipe and minimal editor-file shapes, both run on 1.14.0.
- **Standing:** the checker is a gate wherever someone runs it, and its 25 end-to-end cases run in CI through `scripts/__tests__/check_defold_project.test.sh`. The rest is agent-graded or recorded. Unmeasured: no eval with a control arm covers it.
- **Credit.** Adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b (Apache-2.0). The checker and its tests were copied and modified; see `NOTICE`.
