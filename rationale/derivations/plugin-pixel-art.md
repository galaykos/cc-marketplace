# pixel-art: derivations (2026-11-02)

Standing: `recorded`. No gate reads this file.

## plugins/pixel-art/hooks/sheet-check.sh

Added 2026-11-02 (pixel-art 0.2.0). Until then `check_sprite_sheet.py` and `check_tilemaps.py` were
**gates** only where someone ran them. The README said nothing ran them unasked. Without that run,
an Aseprite export with `--ignore-empty`, or a map pointing at a moved tileset, reached the engine
and loaded wrong with only a warning (Phaser skips an external tileset).

**The bracket.** It uses the same per-call PreToolUse/PostToolUse marker as meshy's `glb-check.sh`
(`rationale/derivations/plugin-meshy.md` § plugins/meshy/hooks/glb-check.sh). An `aseprite -b`
export writes its `--sheet` and `--data` files through a writer no shared block names. The marker
is written when the command names a sheet tool (`aseprite`, `libresprite`, `texturepacker`,
`tiled`, `ldtk`) or a word such as `sprite`, `sheet` or `.png/.json/.tmx/.tmj/.ldtk`.

**Which file, which checker:**

- a JSON holding `"frames"` goes to `check_sprite_sheet.py`, and a bare `package.json` never does;
- a PNG stands for the JSON beside it with the same stem;
- `.tmx`, `.tmj` and `.ldtk` go to `check_tilemaps.py`;
- each file is checked on its own, so a finding names its file.

`.tsx`/`.tsj`/`.ldtkl` are left out: the user named sheets and three map extensions.

**Cost.** A cheap exit takes 14–15 ms median, 16 ms max, over 20 runs. A bracketed scan of this
repository took 21 ms median over 10 runs.

Standing: firing and silence are a **gate** in `scripts/smoke/game-checker-hooks-tests.sh`.
Acting on a finding is **agent-graded**.
