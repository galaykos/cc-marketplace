---
name: pixijs-best-practices
description: Use when writing, reviewing or porting PixiJS code — `pixi.js` in package.json, `new Application`, `app.init`, `app.ticker.add`, `Assets.load`, `Texture.from`, `eventMode`, a drag that stops at the sprite's edge, `beginFill`, `cacheAsBitmap`, `ParticleContainer`, a custom `Filter` or `vTextureCoord`, a browser menu on right-click — the v7→v8 changes memory still writes the v7 way.
---

> Last verified: 2026-10-26 — https://pixijs.com/8.x/guides/migrations/v8 — npm:pixi.js@8.22

## Read the major first

- Read the resolved `pixi.js` version from the lockfile; `package.json` holds only a range.
  Write to that major, and to the minor where a row below names one.
- A v7 project stays on v7 unless the user asks for the migration. Run a migration on its
  own, through the v8 guide above, apart from feature work. Never mix v7 and v8 snippets.

## v7 → v8: what memory writes

| v7 (memory) | v8 | The v7 form in v8 |
|---|---|---|
| `new Application({ width, background })` | `const app = new Application(); await app.init({ width, background })` | options ignored; the deprecation warning exists only in debug builds. `app.renderer`, `app.canvas` and `app.screen` are unusable until `init()` resolves |
| `app.view` | `app.canvas` | deprecated getter |
| `app.ticker.add((delta) => { s.rotation += delta; })` | `app.ticker.add((ticker) => { s.rotation += ticker.deltaTime; })` | the argument is the Ticker: the maths yields `NaN`, nothing moves, nothing throws |
| `pointermove` to drag | `globalpointermove`, ended on `pointerup` and `pointerupoutside` | fires only while the pointer is over the object: the drag stops at its edge |
| no `eventMode` set (v7.2 default `auto`) | `eventMode = 'static'`, or `'dynamic'` for things that move under a still cursor | the default is `'passive'`: the object gets no events, its children still do |
| `Texture.from(url)` | `const tex = await Assets.load(url)` | no longer loads a URL; it reads only what `Assets` already loaded |
| `sprite.addChild(child)` | a `Container` holding both | only Containers may have children; deprecated on Sprite, Mesh and Graphics |
| `beginFill(c).drawRect(...).endFill()` | `new Graphics().rect(...).fill(c)` — shape first, then fill or stroke | deprecated |
| `container.cacheAsBitmap = true` | `container.cacheAsTexture(true)`; `cacheAsTexture(false)` before destroying it | replaced |
| `baseTexture.scaleMode = SCALE_MODES.NEAREST` | `texture.source.scaleMode = 'nearest'` | `BaseTexture` is gone; `TextureSource` replaces it |
| `ParticleContainer` + `addChild(sprite)` | `new Particle(texture)` + `container.addParticle(p)`, with `dynamicProperties` | particles are not Sprites |
| `new Filter(vertex, fragment, { uTime: 0 })` | `new Filter({ glProgram: GlProgram.from({ vertex, fragment }), resources: {...} })`, each uniform with a `type` | constructor changed; textures are resources, not uniforms |

## v8 footguns that are not renames

- **`ParticleContainer` measures nothing.** It reports empty bounds, so set `boundsArea` to
  the region the particles cover, or culling and hit tests see an empty box. Only
  `position` is dynamic by default; after changing a static property, call
  `container.update()`.
- **`preference` is a hint or a list.** A string tries that renderer first and falls back
  through the default order (`webgl`, `webgpu`, `canvas`); an array tries only those, in
  order. Branch on `app.renderer.name` before backend-specific code.
- **Right-click menu over the canvas.** From 8.22, Containers receive a federated
  `contextmenu` event: call `event.preventDefault()` in it. On 8.21 and older, add a native
  `contextmenu` listener to `app.canvas` instead.
- **Re-creating an app in the same tab.** Destroy the old one with
  `app.destroy({ removeView: true, releaseGlobalResources: true })` (`app.destroy(true)`
  also releases them); otherwise global resource pools and caches carry into the new app.
- **Custom filter coordinates.** `vTextureCoord` spans the pooled input texture, not 0–1
  over the filtered object, and GLSL ES rejects `uniform float x = 0.05;`. The conversion,
  the uniform setup and a working filter: `references/custom-filters.md`.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| Read the major from the lockfile; never mix v7 and v8 snippets | agent-graded — nothing fails the build |
| The v7→v8 table | recorded — true at the `Last verified` stamp; `check-doc-staleness.sh --live` flags a newer `pixi.js` minor on npm, never what changed in it |
| Ticker argument, `pointermove`, `eventMode` | unenforceable here — v8 runs the v7 form without an error, which is why they are listed |
| The `contextmenu` event | recorded — 8.22.0 release notes (2026-10-01) |

## Anti-patterns

- **Configured constructor** — options in `new Application(...)`; production builds drop them silently.
- **Delta as a number** — `ticker.add((dt) => ...)` doing arithmetic on the Ticker.
- **Edge-bound drag** — `pointermove` on the dragged object instead of `globalpointermove`.
- **URL into `Texture.from`** — a blank texture because nothing awaited `Assets.load`.
- **Children on a Sprite** — v7 nesting that v8 deprecates.
- **Unbounded particles** — a `ParticleContainer` with no `boundsArea`.
