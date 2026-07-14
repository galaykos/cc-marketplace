# shadcn-studio

Greenfield interactive shadcn staging. Stands up a self-contained shadcn + Vite
(Tailwind v4) sandbox on its own dev server and renders agent-authored component
variants **side by side** with real interactivity — sort, filter, dialog — not
static HTML. For idea-stage or non-React work where `design-preview` cannot run
because there is no host Vite+React app to borrow.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install shadcn-studio@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/shadcn-studio:stage <decision>` | Detect/route, consent-gate, provision a sandbox, render real interactive variants at its own URL, collect the pick, clean up |

## How it works

1. **Detection, never assumption.** A runnable Vite+React host routes to
   `design-preview:real-preview` (the project's own components). Node older than
   20.19, or absent, falls back to the static shell. Otherwise — greenfield or a
   non-React stack — shadcn-studio runs.
2. **Ships source, not binaries.** The `template/` is a pinned shadcn + Vite +
   Tailwind-v4 app as source plus a lockfile; `node_modules` is never committed,
   only materialized by one isolated `npm ci` into a scratch dir.
3. **Scratch outside the work tree.** The sandbox lives in the session scratchpad
   by default, so it can never dirty git; an in-repo path uses `.git/info/exclude`.
4. **Its own server.** Vite serves the harness on a dedicated port (`8124`,
   auto-bumping), bound to `127.0.0.1`, identified by a `/__studio` marker route.
   It never touches another skill's server or files.
5. **Guaranteed, verified cleanup.** Kill the server it started, delete the
   scratch dir, verify by search; a delete failure retries then reports.

## Fidelity ladder position

ASCII wireframe → static shell mockup (taskmaster `visual-decisions`) →
**real interactive components (this plugin, greenfield)** / `design-preview`
(real components, existing Vite+React host). Escalate only when the decision
needs real interactivity; cheaper rungs stay below.

## Pairs well with

- **taskmaster** — a visual/creative decision at idea stage escalates here for a
  live interactive demo instead of static HTML.
- **design-preview** — the sibling for existing Vite+React hosts; shadcn-studio
  covers the greenfield / non-React case it cannot.
- **ui-ux** — `shadcn-best-practices` governs the components authored in a stage.
