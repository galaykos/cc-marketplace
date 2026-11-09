# Changelog — phaser

Consumer-facing changes only. Newest first.

## 0.2.0 — 2026-11-09

- **Four more v3→v4 rows** in `phaser-best-practices`, read from Phaser's own v4 migration guide and 4.0.0 changelog. `RenderTexture`/`DynamicTexture` draws buffer until `render()` (or `setRenderMode('redraw'|'all')`). `Math.PI2` is removed (use `TAU`). Compressed textures must be re-compressed Y-up, and `setFlipY` does not affect them. The Canvas renderer is deprecated.
- **New script: `scripts/check_phaser_v4.py`.** It reads the `phaser` range in `package.json` (or `--major`). On Phaser 4 it reports `Math.PI2` (error), `type: Phaser.CANVAS` (warning), and a texture created and drawn in one `src/` file with no `render()` there (error). It skips comments, strings, regex literals and a template literal's text, but scans the code inside its `${}`; a Phaser 3 project stays silent. Exit 0/1/2; `--json`, `--strict`, `--src`.
- **Vendor-skills note.** Phaser ships 28 agent-skill folders under `skills/` (repo and npm package). The skill points to them; they have no Claude Code install command.
- **Standing:** the rows are recorded. The checker is a gate where run, and its harness (13 cases) runs in this repo's CI. Unmeasured: no control-arm eval.

## 0.1.0 — 2026-10-26

- **New plugin: `phaser-best-practices`.** The Phaser 3→4 changes a remembered answer still writes the v3 way, each with what the v3 form does in v4: `preFX`/`postFX` and `BitmapMask` replaced by `enableFilters()` and `filters.internal`/`.external`, `setPipeline('Light2D')` by `setLighting(true)`, `setTintFill` reduced to a console error (use `setTint().setTintMode(Phaser.TintModes.FILL)`), `Phaser.Math.TAU` corrected from π/2 to 2π (`PI_OVER_2` for the old meaning), `Geom.Point` removed for `Vector2`, `roundPixels` off by default, custom pipelines rewritten as render nodes.
- Plus the `scene.launch` restart of a running scene, and three Arcade Physics footguns in `references/arcade-physics.md`: two-sided collision masks with group-and-member checks, `onFloor()` never true on an ordinary dynamic body, drag skipped while the axis accelerates.
- **Standing:** recorded. Every row was read on 2026-10-26 from Phaser's 3→4 migration post or the Phaser 4.2.1 dist source. Unmeasured: no control-arm eval shows the base model getting these wrong.
- **Credit:** adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b (Apache-2.0); prose rewritten, no file copied.
