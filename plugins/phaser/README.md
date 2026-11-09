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

## Scripts

| Script | Run it when |
|---|---|
| `scripts/check_phaser_v4.py` | After writing Phaser 4 code: `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_phaser_v4.py" <project-dir> [--json] [--strict] [--src DIR] [--major N]`. It reports `Math.PI2`, `type: Phaser.CANVAS`, and a `RenderTexture`/`DynamicTexture` drawn with no `render()` in the same file. Read-only, Python 3 standard library. Exit 0 clean or not v4, 1 errors, 2 no `phaser` dependency, no single major, or no `src/` |

**Phaser's own agent skills.** Phaser ships 28 skill folders under `skills/` in its repo and in
the npm package (`node_modules/phaser/skills/`). Its README says to point the agent at that
folder; there is no Claude Code plugin or install command. The skill above points to them for API
detail it does not carry.

## What has teeth

| Rule | Standing |
|---|---|
| Read the major from the lockfile first; never mix v3 and v4 snippets | agent-graded |
| The v3→v4 table | recorded — true at the skill's `Last verified` stamp. `check-doc-staleness.sh --live` warns when npm ships a newer `phaser` minor; it cannot say what changed |
| `setTintFill` and `TAU` | unenforceable by this plugin — Phaser 4 logs or computes instead of throwing, which is why they are listed |
| No `Math.PI2`, `type: Phaser.CANVAS` or drawn-but-unrendered `RenderTexture`/`DynamicTexture` in `src/` | **gate where run** — `check_phaser_v4.py` exits 1 (CANVAS warns). Running it is recorded: no hook runs it. A texture rendered from another file is reported, and an aliased `Math` or a destructured `PI2` is missed |
| The checker's own behaviour | **gate** — `scripts/__tests__/check_phaser_v4.test.sh`, 11 end-to-end cases, runs in this repo's CI. It includes comment, string and regex-literal cases and a Phaser 3 project that stay silent. It proves the codes, not that Phaser agrees: no browser runs |
| Compressed textures re-compressed Y-up | unenforceable here — the orientation is inside the binary texture |
| The vendor-skills note | recorded — read from Phaser's README and the 4.2.1 npm file list on 2026-11-09 |
| The Arcade footguns | recorded — read from the Phaser 4.2.1 Arcade source |

Measured: nothing — no control-arm eval.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here; this plugin ships no upstream scripts (its one script is original), so it carries no NOTICE.
