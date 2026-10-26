# godot

Godot 4 skills that hold only what a model gets wrong from memory: advice that INVERTED
between Godot 4.3 and 4.7, footguns a capable model plausibly misses, hard limits — plus two
mechanisms, a headless GDScript test runner that fails CI honestly and a project reference
checker with an exit code. The Godot manual is not restated here; the model already knows it.

> **Pairs with `gamedev`.** That plugin carries the engine-agnostic shipping and workflow
> material; this one carries Godot only. Nothing installs the pair for you — no plugin here
> may declare `dependencies`:
>
> ```bash
> claude plugin install gamedev@cc-plugins-marketplace
> ```

## Install

```bash
claude plugin install godot@cc-plugins-marketplace
```

## What it ships

| Artifact | Reach for it when |
|---|---|
| `godot-best-practices` (skill) | Writing or reviewing `.gd`, `.tscn`, `.tres`, `.gdshader`, `project.godot`, `export_presets.cfg` or Godot C#, or after a 4.6/4.7 upgrade changed behaviour. References: Jolt Physics 3D, multiplayer, export/web/C#, 4.3→4.7 changes |
| `godot-headless-testing` (skill) | Running GDScript tests from a terminal or CI, or a headless run that hangs or exits 0 despite failures |
| `godot-project-check` (skill) | After creating, moving, renaming or hand-editing scenes, resources or scripts; on `Failed loading resource`, `invalid UID`, a missing main scene or autoload |
| `scripts/check_godot_project.py` | `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_godot_project.py" <project-dir> [--json] [--strict]` — read-only, Python 3.10+ standard library, no Godot binary; exit 0 clean, 1 errors, 2 not a project |

Every skill reads the engine minor from `project.godot` (`config/features`) before advising
and never mixes Godot 3 and 4 snippets.

## What has teeth

| Rule | Standing |
|---|---|
| Broken `res://` paths, path case, uids, resource ids, scene `parent=`/connection paths, main scene and autoloads | **gate** for whoever runs `check_godot_project.py` — exit 1, deterministic. Running it is **recorded**: no hook runs it on an edit |
| The checker's own behaviour | **gate** — `scripts/__tests__/check_godot_project.test.sh`, 44 end-to-end cases on throwaway projects, runs in this repo's CI. It proves the checker's codes, not that Godot agrees: no engine binary runs in the tests |
| A CI test job fails on a failing GDScript test | **gate** in the user's CI once the runner from `godot-headless-testing` is used — its `quit()` code fails the step. Whether the runner is used is **recorded** |
| The version-read rule and every trap in `godot-best-practices` and its references | **recorded** — nothing here runs Godot or lints `.gd`; **agent-graded** only when a reviewer applies them to a diff |

Measured: nothing — no control-arm eval. Whether these skills change what the model writes is
unmeasured; the facts were re-read against the Godot 4.7 documentation on 2026-10-26.

## Credit

Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here, scripts copied and modified (see NOTICE).
