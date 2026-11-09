# Changelog — pixijs

Consumer-facing changes only. Newest first.

## 0.2.0 — 2026-11-09

- **Retired to a pointer.** `pixijs-best-practices` no longer carries the v7→v8 table, the v8 footguns or `references/custom-filters.md`. It now links the v8 guides, the migration guide, the API reference, the release notes and `llms.txt`. It also names the PixiJS team's own MIT-licensed `pixijs/pixijs-skills` and its install lines, labelled third-party and unmeasured here. The description names a v7→v8 migration and drops the rows the body no longer carries.
- **Why: four control-armed eval cases showed no lift.** `evals/` holds `filter-object-space-uv`, `particle-sparks-culled`, `contextmenu-per-card` and `drag-and-spin`. Each grades one fact from the retired table, checked this run against the 8.22.0 source, its release notes or the v8 migration guide. With `claude plugin eval --ablation with-without`, 3 runs per arm and a haiku judge, every case scored 3/3 both with and without the 0.1.0 skill ($2.22). The cases stay as regression guards. The README "Evals" section has the run.
- **The measurement names its scope.** It ran on `opus` only and covers the rows judged most likely missed. The skill names the rows no case covers and tells other models to read the migration guide. Each case's `skill-fired` grader now runs only in the with-plugin arm (`arm: with-only`).

## 0.1.0 — 2026-10-26

- **New plugin: `pixijs-best-practices`.** The v7→v8 changes a remembered answer still writes the v7 way, each with what the v7 form does in v8: constructor options ignored (the warning exists only in debug builds) until `await app.init()`, `app.canvas` for `app.view`, the Ticker passed to `ticker.add` callbacks, `pointermove` firing only over the object (`globalpointermove` for drags), `eventMode` defaulting to `'passive'`, `Texture.from` no longer loading URLs, children only on Containers, shape-first `Graphics`, `cacheAsTexture()`, `TextureSource` scale modes, `Particle` + `addParticle`, and the options-object `Filter` constructor.
- v8 footguns that are not renames: `ParticleContainer` reports empty bounds (`boundsArea`), `preference` as a hint or a list, the 8.22 federated `contextmenu` event for right-click menus, `releaseGlobalResources` when re-creating an app. `references/custom-filters.md` covers the filter constructor, the GLSL ES ban on uniform initialisers, and converting `vTextureCoord` to 0–1 with `uInputSize`/`uOutputFrame`.
- **Standing:** recorded. Every row was read on 2026-10-26 from the v8 migration guide, the 8.22.0 release notes or the 8.22.0 source. Unmeasured: no control-arm eval shows the base model getting these wrong.
- **Credit:** adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b (Apache-2.0); prose rewritten, no file copied.
