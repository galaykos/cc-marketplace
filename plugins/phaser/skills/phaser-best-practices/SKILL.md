---
name: phaser-best-practices
description: Use when writing, reviewing or migrating Phaser game code — `phaser` in package.json, `Phaser.Game`, `Phaser.Scene`, `preFX`/`postFX`, `BitmapMask`, `setTintFill`, `setPipeline('Light2D')`, `Phaser.Math.TAU`, `Geom.Point`, pixel art that blurs or shimmers, a HUD scene that keeps resetting, Arcade colliders, collision categories or `onFloor()` — the Phaser 3→4 changes memory still writes the v3 way.
---

> Last verified: 2026-10-26 — https://phaser.io/news/2026/04/migrating-from-phaser-3-to-phaser-4-what-you-need-to-know — npm:phaser@4.2

## Read the major first

- Read the resolved `phaser` version from the lockfile (`package-lock.json`, `pnpm-lock.yaml`,
  `yarn.lock`); `package.json` holds only a range. Write to that major.
- A Phaser 3 project stays on 3 unless the user asks for the migration. Run a migration on
  its own, through the official guide above, apart from feature work.
- Never paste a v3 snippet into a v4 project. Most tutorials, examples and answers are v3,
  and several v3 calls below still run in v4 and do nothing.

## Phaser 3 → 4: what memory writes

| Phaser 3 (memory) | Phaser 4 | The v3 form in v4 |
|---|---|---|
| `sprite.preFX.addGlow()`, `postFX.addBlur()`, camera `postFX` | `obj.enableFilters()`, then `obj.filters.internal.addGlow()` or `obj.filters.external.addBlur()`; on a camera `camera.filters.internal.addBlur()` | `preFX`/`postFX` do not exist: a TypeError on the first call |
| `BitmapMask` | the Mask filter, `obj.enableFilters().filters.internal.addMask(texture)` | removed |
| `setPipeline('Light2D')` | `setLighting(true)` | replaced |
| `setTintFill(color)` | `setTint(color).setTintMode(Phaser.TintModes.FILL)` | logs a `console.error` and changes nothing — no tint, no throw |
| `Phaser.Math.TAU` used as π/2 (v3 had it wrong) | `Phaser.Math.PI_OVER_2`; `TAU` is now 2π | every angle built on it is 4× too large, silently |
| `Phaser.Geom.Point` | `Phaser.Math.Vector2` — each Point method has a counterpart | removed |
| crisp pixel art with no config | `pixelArt: true` in the game config (turns antialias off and `roundPixels` on), or `roundPixels: true` | `roundPixels` defaults to `false` in v4: sprites blur or shimmer while moving |
| a custom `WebGLPipeline` / `PostFXPipeline` class | rewrite it as a v4 render node | does not port; never copy v3 renderer internals across |

## Scene flow — the one restart nobody expects

- `this.scene.launch(key)` on a scene that is already running shuts it down and starts it
  again: launch goes through the Scene Manager's `start`, which restarts a running, paused or
  sleeping scene. Launch a HUD once, guard with `this.scene.isActive('hud')`, and toggle it
  with `setVisible()` or `sleep`/`wake`.
- Scene operations are queued until the next Scene Manager update. The target has not
  started on the line after `start`/`launch`; react in its `create`, not there.
- Scenes draw in scene-list order, not launch order. A HUD listed before the gameplay scene
  renders underneath it until `this.scene.bringToTop('hud')`.

## Arcade Physics footguns

- **Collision categories are two-sided.** A pair collides only when EACH body's mask holds
  the other's category. A body you never touched keeps mask `1`, so moving the player into
  a new category silently cuts it off from the untouched ground.
- **A group and its members are both checked**, and the group's category is not copied to
  them. Set both. Defaults differ: a dynamic `physics.add.group()` starts with every mask
  bit set; a body, a static body and a static group start with mask `1`.
- **`onFloor()` / `blocked.down` stays `false` on an ordinary dynamic body.** Two pushable
  bodies only set `touching`. Make the platform static, `setImmovable(true)` or
  `setPushable(false)` before using it as a ground check.
- **Drag acts only while that axis has zero acceleration.** Zero the acceleration when
  input stops, or `setDrag` appears to do nothing.

Code for each, and the category helpers (`this.physics.nextCategory()`, `setCollidesWith`,
`resetCollisionCategory`): `references/arcade-physics.md`.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| Read the major from the lockfile; never mix v3 and v4 snippets | agent-graded — a reviewer can check the lockfile was read; nothing fails the build |
| The v3→v4 table | recorded — true at the `Last verified` stamp; `check-doc-staleness.sh --live` flags a newer `phaser` minor on npm, never what changed in it |
| `setTintFill`, `TAU`, `roundPixels` | unenforceable here — Phaser itself does not throw, which is why they are in the table |
| The Arcade footguns | recorded — read from Phaser 4.2.1's Arcade source; collision categories date from 3.70 by its `@since` tags |

## Anti-patterns

- **v3 tutorial paste** — `preFX`, `BitmapMask`, `setPipeline` or `Geom.Point` in a v4 tree.
- **Silent tint** — `setTintFill` left in after an upgrade; the console error is the only trace.
- **TAU rotation** — a quarter-turn written as `TAU` from v3 code, now a full turn.
- **HUD relaunch** — `scene.launch('hud')` in a gameplay `create`, wiping the HUD every restart.
- **One-sided mask** — a new collision category set on one side only.
