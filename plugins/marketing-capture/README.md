# marketing-capture

Turn the real running app into marketing assets. Auto-detects whatever browser
backend is available, gets the app on screen, and — behind an up-front consent
gate — writes framed screenshots and a native-only demo GIF to `docs/marketing/`.
No installs, ever; reuses `design-preview` as an opportunistic live-app driver.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install marketing-capture@cc-plugins-marketplace
```

## Skills

| Skill | What it does |
|-------|--------------|
| `capture-assets` | Detect a backend, consent-gate, shoot a user shotlist of the real app, frame each screenshot, and record a demo GIF where the backend supports it — all into `docs/marketing/` |

## How it works

1. **Backend auto-detect ladder**, never assumption: `claude-in-chrome` →
   Playwright MCP → `Claude_Preview` → Puppeteer MCP. First present wins; it
   says which. None present → it stops and names what it looked for.
2. **Real app on screen:** reuse a running server, or `design-preview` when the
   project is Vite + React, or a user-supplied URL. Never installs anything.
3. **Consent gate up front**, once per session, naming the exact files it will
   write and the server it may start.
4. **User shotlist** of routes + captions — no auto-crawl.
5. **Framed screenshots** via an HTML frame shell (zero image-lib deps) and a
   **native-only GIF** (`claude-in-chrome`'s recorder); on a GIF-less backend it
   emits screenshots plus a clear note instead of failing.

## Pairs well with

- **design-preview** — opportunistic live-app driver for Vite + React projects.
- **marketing-copy** — consumes the shotlist captions so copy matches the shots.
- **taskmaster** — its `visual-decisions` shell technique inspires the frame shell.
