# bevy

One skill for Bevy, the Rust ECS game engine. It covers what changed between 0.17 and 0.20
and still gets written the old way, plus the footguns those changes created. It is not an
ECS tutorial: `App`, `Query`, `Commands`, schedules and run conditions are what the model
already knows, and restating them measured at zero elsewhere in this marketplace
(`rationale/measured-zero-shapes.md`).

## Install

```bash
claude plugin install bevy@cc-plugins-marketplace
```

**Pairs with `gamedev`.** That plugin holds the engine-agnostic shipping and workflow
material; this one holds only Bevy. Nothing installs the pair for you, because no plugin
here may declare `dependencies`. `stack-scan` is also worth having:
`stack-scan:installed-versions` decides which file is the version authority when
`Cargo.lock` and the toolchain files disagree.

## Skills

| Skill | Reach for it when |
|---|---|
| `bevy-best-practices` | `Cargo.toml` depends on `bevy`, or a compile error or startup panic names `On<Add, T>`, `Pointer<Press>`, `set_if_neq`, `Name::new`, `iter_many`, `IsResource`, B0001 or B0002 — the 0.17–0.20 rename table and the resource-entity, `Mesh2d` sprite and weak-ordering footguns |

## What has teeth

| Rule | Standing |
|---|---|
| Read the resolved version from `Cargo.lock` first, and write to that minor | agent-graded |
| The 0.17–0.20 rename table | recorded — true as of the skill's `Last verified` stamp. `check-doc-staleness.sh` reads npm, composer and pypi tails, never crates.io, so nothing flags the table when 0.21 ships |
| Double `Resource`/`Component` derives, broad queries beside `Res<T>` | rustc and Bevy's startup panic enforce these, not this plugin |

Measured: nothing — no control-arm eval.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here; this plugin ships no upstream scripts, so it carries no NOTICE.
