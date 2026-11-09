# pixijs

One pointer skill for PixiJS, the 2D WebGL/WebGPU renderer that browser games build on. It
links the official v8 docs, the v7→v8 migration guide, the API reference and the release
notes. It also names the PixiJS team's own agent skills, which are third party. Up to 0.1.0 it
carried a v7→v8 table and the v8 footguns. A control-armed eval found the base model already
writes every case that table covered, so 0.2.0 retired it (see Evals).

## Install

```bash
claude plugin install pixijs@cc-plugins-marketplace
```

**Pairs with `gamedev`** when the canvas is a game. That plugin holds the engine-agnostic
release and workflow material (Steam and itch.io uploads, asset checks); this one holds only
PixiJS. Nothing installs the pair for you, because no plugin here may declare `dependencies`:

```bash
claude plugin install gamedev@cc-plugins-marketplace
```

A PixiJS canvas on a marketing or product page is also graded by `craft-layer`'s audit as a
WebGL surface (lazy load, static fallback, reduced motion); this plugin does not repeat those
rules.

## Skills

| Skill | Reach for it when |
|---|---|
| `pixijs-best-practices` | `package.json` depends on `pixi.js`, or code touches `new Application`, `app.init`, `Assets.load`, `ParticleContainer`, a custom `Filter` or a v7→v8 migration. It links the v8 guides, the migration guide, the API reference, the release notes and `llms.txt`, and names `pixijs/pixijs-skills` (third party, MIT, not measured here) with its install lines |

## What has teeth

| Rule | Standing |
|---|---|
| The links and the vendor's install lines | recorded — true at the skill's `Last verified` stamp. `check-doc-staleness.sh --live` warns when npm ships a newer `pixi.js` minor and HEADs the stamped URL; it cannot say what changed |
| "The base model needs no v7→v8 table" | recorded — measured once (Evals), on one model with a haiku judge; nothing re-runs it when the model changes |

Credit: up to 0.1.0 the skill was adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors). The 0.2.0 pointer carries none of that prose.

## Evals

Four cases under `evals/`, run with `claude plugin eval plugins/pixijs`. Each grades one fact from the retired
v7→v8 table, checked on 2026-11-09 against the 8.22.0 source, its release notes or the v8 migration guide. Measured
2026-11-09 on CLI 2.1.319 with the `opus` model, against the 0.1.0 skill (the table, before retirement), 3 runs per
arm, haiku judge (3 votes per run), $2.22 in total:

| Case | With plugin | Without | Reading |
|---|---|---|---|
| `filter-object-space-uv`, `particle-sparks-culled`, `contextmenu-per-card`, `drag-and-spin` | 3/3 | 3/3 | the control arm passes, so these are regression guards and cannot show the plugin helping |

All 72 judge votes were PASS in both arms, so the delta is 0 on every case, at 3 runs. The skill fired in all 12
with-plugin runs. The cases were picked as the table's rows a model was most likely to miss: filter coordinates,
`ParticleContainer` bounds, and the 8.22 `contextmenu` event (released 2026-10-01). Without the plugin, the model
solved the right-click case with a native listener and a hit test; with it, the model used the federated event. Both
are correct, so the change is in form, not in outcome.

**No case showed the table helping, so 0.2.0 retired it to a pointer.** The cases stay as regression guards. Each
keeps its with-only `skill-fired` indicator (`tool_used: Skill`, not scored). The pointer still fires on PixiJS work,
and a with-plugin run where it never fired is identical to the control, so it guards nothing. The 0.2.0 pointer has
not been run through these cases, and the vendor's `pixijs/pixijs-skills` has not been measured as a third arm.
