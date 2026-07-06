# vite

Vite best practices: `VITE_`-prefix env security, dep pre-bundling and
`optimizeDeps`, code splitting with dynamic `import()` and `manualChunks`, `base`
for sub-path deploys, dev `server.proxy`, `define` stringify pitfalls,
`import.meta.glob`, asset handling, `build.target` alignment, SSR, library mode,
plugin order, HMR guards.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install vite@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/vite:review [files-or-diff]` | Review Vite config or a Vite-built app against the skill, pinned to the locked vite version and the project's vite.config |

## Example

```bash
/vite:review vite.config.ts
/vite:review         # reviews the current diff
```

Advice is version-aware: Node floors and default `build.target` differ across
Vite 5 / 6 / 7, the Environment API and `resolve.conditions` defaults land in 6,
and Rolldown is opt-in in 7 — all resolved from the lockfile, never assumed.

## Pairs well with

- **typescript** — covers the type layer and `tsconfig` this plugin leaves alone
- **react / vue3** — framework review plugins; this one covers the build tool they skip
- **stack-scan** — supplies the locked vite version the advice pins against
