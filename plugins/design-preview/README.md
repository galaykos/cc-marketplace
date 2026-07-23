# design-preview

Real-component visual decisions for Vite + React projects: renders 2–3
candidate variants with the project's OWN components on its own dev server,
via a scratch HTML entry that touches zero existing files. The escalation tier
above static shell mockups — for when token-mimicry isn't enough and the
decision needs the real design system.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install design-preview@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/design-preview:preview <decision>` | Detect Vite/React, consent-gate, render real-component variants at `/design-preview.html`, collect the pick, clean up |

## How it works

1. Detection, never assumption: `vite.config.*`, `@vitejs/plugin-react`, a dev
   script, and component paths must all be present — otherwise it falls back.
2. Strict consent before any write into the source tree: the exact scratch
   files and the dev-server command are named up front.
3. Scratch surface: `design-preview.html` (root) + `src/__design-preview__/` —
   Vite serves extra HTML entries with their own module graph, so no router or
   config edits happen, ever.
4. The page renders 2–3 variants on ONE axis using the project's own components
   through its aliases, with realistic data; iteration is in-place via HMR.
5. Guaranteed cleanup: both scratch paths deleted and verified by search; the
   dev server is killed only if this flow started it.

## Fidelity ladder position

ASCII wireframe → static shell mockup (taskmaster visual-decisions, theme
tokens, ~90% look) → **real components (this plugin)**. Escalate only when the
decision hinges on the real design system; everything cheaper stays below.

## Pairs well with

- **taskmaster** — visual-decisions hands off here for real-component fidelity
  and takes the pick back into its ambiguity ledger; its shell mockup is this
  plugin's fallback.
- **stack-scan** — detection reuses its required-vs-installed inventory.
- **ui-ux** — shadcn best-practices and theming for the components being shown.

## Preview-port registry

Every static-mockup surface across the marketplace shares ONE session preview
server, addressed by the `PREVIEW_PORT` convention — the port token is
`${PREVIEW_PORT:-8123}` (env override, default `8123`). Artifacts land in
`taskmaster-docs/mockups/` under per-purpose file slots so producers never clobber
each other's tab. shadcn-studio is the exception: it runs its OWN Vite dev server
on a dedicated port (`Number(process.env.PREVIEW_PORT) || 8124`), never the shared
static one.

The preferred first rung for the shared server is the taskmaster plugin's
visual-decisions `assets/serve.py` (threaded static + SSE push-reload on
`/events`, localhost-only by default); plain static rungs
(`python3 -m http.server --bind 127.0.0.1`, `php -S 127.0.0.1:`, `npx serve`)
work identically except consumers fall back to polling reload.

| Port | Slot | Plugin — surface |
|------|------|------------------|
| `${PREVIEW_PORT:-8123}` | `current.html` | taskmaster — `visual-decisions` |
| `${PREVIEW_PORT:-8123}` | `diagram.html` | taskmaster — `erd` |
| `${PREVIEW_PORT:-8123}` | `walkthrough.html` | taskmaster — `experience-walkthrough` |
| `${PREVIEW_PORT:-8123}` | `theme.html` | ui-ux — `README`, `commands/theme.md`, `shadcn-theming` |
| `${PREVIEW_PORT:-8123}` | `diagram.html` | code-architecture — `plan-before-code` |
| `${PREVIEW_PORT:-8123}` | `api.html` | api-design — `api-design` |
| `${PREVIEW_PORT:-8123}` | `diagram.html` | dev-env — `compose-init` |
| `Number(process.env.SHADCN_STUDIO_PORT) || 8124` | own harness | shadcn-studio — dedicated Vite dev server (own var, not PREVIEW_PORT) |
