# design-preview

Real-component visual decisions for Vite (React or Vue/Nuxt) and Laravel
Blade/Livewire projects: renders 2–3 candidate variants with the project's OWN components on its own dev server,
on a scratch surface it removes afterwards. The escalation tier
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
| `/design-preview:preview <decision>` | Detect the stack (Vite or Laravel), consent-gate, render real-component variants, collect the pick, clean up |

## How it works

1. Detection, never assumption — two separate paths, and a miss on both falls back
   to static mockups rather than guessing:
   - **Vite** — `vite.config.*`, `@vitejs/plugin-react` **or** `@vitejs/plugin-vue`, a
     dev script, and component paths must all be present.
   - **Laravel (Blade/Livewire)** — `artisan`, `composer.json` requiring
     `laravel/framework`, and `@vite` in a Blade layout.
2. Strict consent before any write into the source tree: the exact scratch
   files and the dev-server command are named up front.
3. Scratch surface, and it differs by path — the Vite trick does NOT transfer to
   Laravel, because PHP owns routing:
   - **Vite** — `design-preview.html` (root) + `src/__design-preview__/`. Vite serves
     extra HTML entries with their own module graph, so no router or config edit
     happens on this path, and no existing file is touched.
   - **Laravel** — a scratch route file plus a scratch Blade view, reached by one
     clearly marked, marker-carrying line added to `routes/web.php`. That is an edit
     to an existing file, it is named in the consent gate before it happens, and it
     is reverted at cleanup.
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
on a dedicated port (`Number(process.env.SHADCN_STUDIO_PORT) || 8124`), never the shared
static one.

The preferred first rung for the shared server is the taskmaster plugin's
visual-decisions `assets/serve.py` (threaded static + SSE push-reload on
`/events`, localhost-only by default); plain static rungs
(`python3 -m http.server --bind 127.0.0.1`, `php -S 127.0.0.1:`, `npx serve`)
work identically except consumers fall back to polling reload.

**Surface rung above all of those.** On Claude Code's desktop app the harness owns
server lifecycle: `mcp__Claude_Browser__preview_start` runs a server named in
`.claude/launch.json`, reuses one already up, and opens the Browser pane on it,
and the harness instructs the model to use it rather than Bash. Where that tool
exists, register the port as a `launch.json` configuration and start it that way;
the `PREVIEW_PORT` slot table below is unchanged, because it addresses which file
each producer writes, not who started the process. The Bash rungs remain the CLI
path.

| Port | Slot | Plugin — surface |
|------|------|------------------|
| `${PREVIEW_PORT:-8123}` | `current.html` | taskmaster — `visual-decisions` |
| `${PREVIEW_PORT:-8123}` | `diagram.html` | taskmaster — `erd` |
| `${PREVIEW_PORT:-8123}` | `walkthrough.html` | taskmaster — `experience-walkthrough` |
| `${PREVIEW_PORT:-8123}` | `theme.html` | ui-ux — `README`, `commands/theme.md`, `shadcn-theming` |
| `${PREVIEW_PORT:-8123}` | `modules.html` | code-architecture — `plan-before-code` |
| `${PREVIEW_PORT:-8123}` | `api.html` | api-design — `api-design` |
| `${PREVIEW_PORT:-8123}` | `compose.html` | devops — `compose-init` |
| `Number(process.env.SHADCN_STUDIO_PORT) || 8124` | own harness | shadcn-studio — dedicated Vite dev server (own var, not PREVIEW_PORT) |
