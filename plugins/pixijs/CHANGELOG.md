# Changelog — pixijs

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-26

- **New plugin: `pixijs-best-practices`.** The v7→v8 changes a remembered answer still writes the v7 way, each with what the v7 form does in v8: constructor options ignored (the warning exists only in debug builds) until `await app.init()`, `app.canvas` for `app.view`, the Ticker passed to `ticker.add` callbacks, `pointermove` firing only over the object (`globalpointermove` for drags), `eventMode` defaulting to `'passive'`, `Texture.from` no longer loading URLs, children only on Containers, shape-first `Graphics`, `cacheAsTexture()`, `TextureSource` scale modes, `Particle` + `addParticle`, and the options-object `Filter` constructor.
- v8 footguns that are not renames: `ParticleContainer` reports empty bounds (`boundsArea`), `preference` as a hint or a list, the 8.22 federated `contextmenu` event for right-click menus, `releaseGlobalResources` when re-creating an app. `references/custom-filters.md` covers the filter constructor, the GLSL ES ban on uniform initialisers, and converting `vTextureCoord` to 0–1 with `uInputSize`/`uOutputFrame`.
- **Standing:** recorded. Every row was read on 2026-10-26 from the v8 migration guide, the 8.22.0 release notes or the 8.22.0 source. Unmeasured: no control-arm eval shows the base model getting these wrong.
- **Credit:** adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b (Apache-2.0); prose rewritten, no file copied.
