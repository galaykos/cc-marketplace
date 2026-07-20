# threejs

Three.js best practices: WebGPURenderer-first (automatic WebGL2 fallback;
WebGPU is browser Baseline since Jan 2026), TSL shaders, react-three-fiber +
drei integration, glTF/Draco/KTX2 asset pipelines, disposal and GPU-leak
discipline, render-loop and draw-call performance. Version-aware: three
releases every ~6–10 weeks (rXXX) — the skill resolves the locked revision
and checks its migration notes before advising.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install threejs@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/threejs:review [files-or-diff]` | Review Three.js scene, renderer, or R3F code against threejs-best-practices |

## Pairs well with

- **react** — component correctness around react-three-fiber trees
- **vite** — bundling/code-splitting the three chunk and asset handling
- **ui-ux** (motion skill) — DOM/CSS animation on the page around the canvas
- **performance** — measuring before optimizing what `renderer.info` surfaces
