# phaser

One skill for Phaser, the HTML5 game framework. It covers what changed from Phaser 3 to
Phaser 4 and still gets written the v3 way, the scene restart nobody expects, and three
Arcade Physics footguns. It is not a Phaser tutorial: the `Game` config, the scene lifecycle,
the loader and basic Arcade movement are what the model already knows, and restating them
measured at zero elsewhere in this marketplace (`rationale/measured-zero-shapes.md`).

## Install

```bash
claude plugin install phaser@cc-plugins-marketplace
```

**Pairs with `gamedev`.** That plugin holds the engine-agnostic release and workflow
material (Steam and itch.io uploads, asset checks); this one holds only Phaser. Nothing
installs the pair for you, because no plugin here may declare `dependencies`:

```bash
claude plugin install gamedev@cc-plugins-marketplace
```

## Skills

| Skill | Reach for it when |
|---|---|
| `phaser-best-practices` | `package.json` depends on `phaser`, or code touches `preFX`/`postFX`, `BitmapMask`, `setTintFill`, `setPipeline('Light2D')`, `Phaser.Math.TAU`, `Geom.Point`, pixel-art blur, `scene.launch`, Arcade collision categories or `onFloor()` — the v3→v4 table and the Arcade footguns |

## What has teeth

| Rule | Standing |
|---|---|
| Read the major from the lockfile first; never mix v3 and v4 snippets | agent-graded |
| The v3→v4 table | recorded — true at the skill's `Last verified` stamp. `check-doc-staleness.sh --live` warns when npm ships a newer `phaser` minor; it cannot say what changed |
| `setTintFill` and `TAU` | unenforceable by this plugin — Phaser 4 logs or computes instead of throwing, which is why they are listed |
| The Arcade footguns | recorded — read from the Phaser 4.2.1 Arcade source |

Measured: nothing — no control-arm eval.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here; this plugin ships no upstream scripts, so it carries no NOTICE.
