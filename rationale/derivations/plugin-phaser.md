# phaser: derivations and sources (2026-11-09)

Written on 2026-11-09, when `plugins/phaser` 0.2.0 added four v3→v4 rows, its first script, and a note on Phaser's
own agent skills. Every fact below was read that day from the URL given beside it. Standing: `recorded` — no gate
reads this file.

## Sources

- `https://github.com/phaserjs/phaser/blob/master/changelog/v4/4.0/MIGRATION-GUIDE.md`, at repo HEAD
  02d8931b626d9764c133cbb3fbf99966c03c757c (423 lines, read in full). §2: "The Canvas renderer is still available
  but should be considered deprecated." §6: compressed textures "must be re-compressed with the Y axis starting at
  the bottom". §7: "`DynamicTexture` and `RenderTexture` must now call `render()` to execute all buffered drawing
  commands." §14: "`Math.PI2` | Removed | Use `Math.TAU` instead."
- `changelog/v4/4.0/CHANGELOG-v4.0.0.md` (800 lines). Only searched for the four items: "almost everything new in
  Phaser 4 is not available in Canvas", "`Math.PI2` has been removed", "Allow `TextureSource#setFlipY` to affect all
  textures (except compressed textures, which have fixed orientation)".
- Phaser 4.2.1 source at tag v4.2.1 (41be1e462bc600064e498cba370bfa8c5c055a22). `src/math/const.js` has `TAU` and
  `PI_OVER_2` and no `PI2`. `src/const.js` keeps `CANVAS: 1`. `RenderTexture#renderMode` defaults to `'render'`;
  `RenderTextureWebGLRenderer.js` calls `render()` itself only in `'redraw'` and `'all'`. The buffered
  `DynamicTexture` commands are `fill`, `clear`, `stamp`, `erase`, `draw`, `capture`, `repeat`, `callback` and
  `preserve`. `TextureManager#addDynamicTexture` and the `renderTexture` factory and creator exist. npm `latest`
  was 4.2.1.

## plugins/phaser/scripts/check_phaser_v4.py

### Why it exists

All three patterns fail quietly in v4. `Math.PI2` reads `undefined`, and the maths built on it becomes `NaN`. An
unrendered texture shows nothing, with no error. `type: Phaser.CANVAS` runs without most v4 features. A model writes
each of them from v3 memory, and a reviewer reads past them. An exit code on the project's own source is the one
artifact here that a table row cannot replace.

### Design

- Major: the `phaser` entry of `dependencies`, `devDependencies`, `peerDependencies` or `optionalDependencies`. Only a
  range that pins exactly one major is read (`4.2.1`, `^4`, `~4.0.0`, `4.x`, `4.0.0-rc.7`). `latest`, `*`, `>=`,
  `||` and git URLs exit 2 and ask for `--major`. The task asked for `package.json`, so the lockfile is not read,
  although the skill tells the model to read it.
- Lexing: comments are blanked in both views; string and regex-literal bodies, and a template literal's text, are
  blanked in the code view. The `${}` code inside a template is lexed as code, nested templates included. A regex literal is assumed after `( , = : [ ! & | ? { } ; + - * % < > ~ ^`, at the start of the file,
  or after `return`, `typeof` and similar keywords.
- Unrendered texture: each creation call (`add.renderTexture`, `make.renderTexture`, `textures.addDynamicTexture`,
  `new [Phaser.GameObjects.]RenderTexture`, `new [Phaser.Textures.]DynamicTexture`) names a receiver (`rt`,
  `this.trail`, `scene.minimap`), or none when the result is used inline. Every `.method()` chain on that receiver
  in the same file is walked. A draw (`draw`, `fill`, `stamp`, `erase`, `capture`, `repeat`) with no `render()` on
  the receiver is reported. `setRenderMode(x)` or `renderMode = x` with any value except `'render'` counts as
  auto-render. `clear()` alone is not a draw: a texture that is only cleared is not reported.
- `--src` is relative to the project folder, or absolute. A file outside the project folder is reported by its path
  relative to it (`../shared/util.js`).
- Severities: `pi2-removed` and `render-missing` are errors, because the result is wrong. `canvas-renderer` is a
  warning, because Canvas still runs.

### Measured on 2026-11-09

- `scripts/__tests__/check_phaser_v4.test.sh`: 11 cases, all pass. A review on 2026-11-09 found two more faults. A
  template literal was blanked whole, so `${Phaser.Math.PI2 * t}` went unseen. An absolute `--src` outside the
  project folder raised `ValueError`, a traceback with exit 1 that reads as "errors found". One case each was
  added (13); both failed on the first cut.
- Seven seeded faults each failed the suite: blanking off, `setRenderMode` ignored, any `setRenderMode` treated as
  auto, a Phaser 3 project scanned, `render()` not seen, regex literals not lexed, and `renderMode =` ignored. The
  first draft survived two of them: a dotted receiver (`scene.minimap`) was not tracked, and the regex fixture could
  not match. Both were fixed before shipping.
- No browser and no Phaser build ran. The fixtures encode the guide as read.

### What it does not catch

- A texture rendered from another file or through a helper is reported (a false positive). A receiver renamed,
  destructured or passed in as a parameter is not tracked (missed).
- `PMath.PI2` after `import { Math as PMath }`, `const { PI2 } = Phaser.Math`, a quoted `'type'` key, and `CANVAS`
  imported by name.
- Files outside `--src` (default `src/`), `.d.ts` files, and anything under `node_modules`, `dist` or `build`.
- Compressed-texture orientation: it lives inside the binary file, which nothing here reads.

## plugins/phaser/skills/phaser-best-practices/SKILL.md § vendor skills

- `https://github.com/phaserjs/phaser/tree/master/skills` lists 28 directories, among them `v3-to-v4-migration`,
  `render-textures` and `v4-new-features`. The last commit touching the folder was f84916099a on 2026-06-03.
- Phaser's README (master) says: "This repository includes a comprehensive set of AI agent skills … Point your AI
  coding agent at the `skills/` folder". No install command, plugin manifest or marketplace entry was found.
- `https://data.jsdelivr.com/v1/packages/npm/phaser@4.2.1?structure=flat`: 36 files under `/skills`, 28 of them
  `SKILL.md`. So `node_modules/phaser/skills/` exists in an installed 4.2.1.
- GitHub search of the `phaserjs` org: `phaser-game-agent` (no description, last push 2026-07-01, not opened) and
  `editor-mcp-server` (Phaser Editor's MCP server, last push 2025-09-19). Neither was read; neither is a Claude Code
  plugin by its name.
- Phaser's `render-textures` skill (441 lines) and `v3-to-v4-migration` skill (430 lines) were only searched for the
  four rows; both state them. Whether they, or this plugin, change what a model writes is unmeasured.
