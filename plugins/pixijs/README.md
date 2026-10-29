# pixijs

One skill for PixiJS, the 2D WebGL/WebGPU renderer that browser games build on. It covers
what changed from v7 to v8 and still gets written the v7 way, and the v8 footguns that are
not renames. It is not a PixiJS tutorial: sprites, containers, the ticker and `Assets`
basics are what the model already knows, and restating them measured at zero elsewhere in
this marketplace (`rationale/measured-zero-shapes.md`).

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
| `pixijs-best-practices` | `package.json` depends on `pixi.js`, or code touches `new Application`, `app.ticker.add`, `Texture.from`, `eventMode`, `pointermove` drags, `beginFill`, `cacheAsBitmap`, `ParticleContainer`, a custom `Filter` or a right-click menu — the v7→v8 table, the v8 footguns, and `references/custom-filters.md` |

## What has teeth

| Rule | Standing |
|---|---|
| Read the major from the lockfile first; never mix v7 and v8 snippets | agent-graded |
| The v7→v8 table | recorded — true at the skill's `Last verified` stamp. `check-doc-staleness.sh --live` warns when npm ships a newer `pixi.js` minor; it cannot say what changed |
| Ticker argument, `pointermove`, `eventMode`, constructor options | unenforceable by this plugin — v8 runs the v7 form without an error, which is why they are listed |
| Filter coordinates and uniform initialisers | recorded — read from the 8.22.0 filter source and the GLSL ES 3.20 spec |

Measured: nothing — no control-arm eval.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here; this plugin ships no upstream scripts, so it carries no NOTICE.
