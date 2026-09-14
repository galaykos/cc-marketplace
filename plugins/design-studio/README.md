# design-studio

Three ways to decide how something looks, in one plugin, each doing what the
others cannot. A **design session** (`/design-studio:init`) is direct manipulation
in the browser: you chat, select, drag, resize, edit text and pick colours on a
canvas this plugin serves, and the running Claude Code session applies every
gesture to real files. A **real-component preview** (`/design-studio:preview`)
renders two or three variants with the project's own components on its own dev
server, so a decision is made on the real thing. Two **registry MCP servers** read
the Aceternity, shadcn, Magic UI and ReUI component registries from the source, so
no build picks a component from recall. theme-design 0.4.1 and design-lab 0.2.1
were merged into this plugin on 2026-09-14; the working directory is now
`.design-studio/`.

| Command / server | What it does |
|---|---|
| `/design-studio:init [html \| proxy <url>] [--skin <name>] [brief]` | Start or resume a design session. `html` serves standalone prototypes under `.design-studio/pages/` driven by one `tokens.css` and one `skin.css`; `proxy` overlays the editor on your running dev server and edits go to project source. No mode given: detects a dev server and asks once |
| `/design-studio:export [tokens\|pages\|brief\|write]` | Write `tokens.css` (light + dark, contrast-checked), the prototype pages, a design brief built from the session's decisions and transcript, and optionally merge tokens into the project's theme file after showing the diff. Stops the server if this session started it |
| `/design-studio:preview [decision-description]` | Render 2–3 candidate variants with the project's **own** components on its own dev server — Vite (React or Vue/Nuxt) or Laravel Blade/Livewire — on a scratch surface removed at cleanup, behind a strict consent gate. Falls back to static shell mockups when neither stack is detected |
| `registry-source` MCP server | Read component registries from the source, never from memory: live list/search/get across Aceternity, shadcn and Magic UI, 24h-cached, every answer carrying its source URL, fetch date and a stale flag |
| `reui` MCP server | ReUI's own hosted registry, delivered by install and authenticated by your own browser sign-in |

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install design-studio@cc-plugins-marketplace
```

The session server needs `python3` (stdlib only) and `curl`; the prompt hook needs
`jq` and is silent without it. The registry server is dependency-free node. Ships
in the **craft-suite** bundle.

## Which surface, when

| Situation | Surface |
|---|---|
| Shaping a look by talking and moving things, before or instead of a spec | `/design-studio:init` — the `design-session` skill |
| A runnable Vite (React/Vue/Nuxt) or Laravel Blade host with components present, and a choice between variants | `/design-studio:preview` — the `real-preview` skill |
| Empty/greenfield dir, or a stack with no Vite/Laravel host | the taskmaster `visual-decisions` shell mockup, offered by `/design-studio:preview` as its fallback |
| A running design session (`.design-studio/` present) | that session owns the preview surface; hand the decision there and do not start a second server on it (lane edge in `lane.tsv`; no script checks the marker at runtime) |
| Installing or reviewing a registry component (shadcn, ReUI, Aceternity, Magic UI) | the MCP servers, via ui-ux's stack skills |
| Colour-only theming with candidates | `/ui-ux:theme` — it proposes, you pick |

## The design session

```
browser panel ──POST /__td/event──▶ .design-studio/events.jsonl
                                          │
Claude (this session) ◀──GET /__td/next── long-poll, advances cursor
      │ edits tokens.css / pages / project source
      └──POST /__td/reply──▶ SSE ──▶ panel line + reload
```

No API key, no second app: the session you already pay for is the brain, so every
project skill and CLAUDE.md rule it knows applies to the design work too. The
Claude side is one `curl` per wait, run from the session with a five-minute
timeout; an empty batch is polled again silently. Esc in the terminal interrupts a
wait. If you type in the terminal while events are pending, the plugin's
`UserPromptSubmit` hook injects them into that turn and advances the same cursor,
so nothing is delivered twice.

Working files live in `.design-studio/` at the project root: `tokens.css`, `pages/`,
`events.jsonl`, `transcript.md`, `decisions.md`, `state.json` (live pid, port, mode)
and `cursor`. Track it or ignore it; the plugin suggests `.gitignore` once and never
decides.

### Fidelity: wireframe to rich, same files

Two dials in the panel. **Skin** swaps the look; **rich** turns on imagery,
chart shapes, depth and motion on the same page, injected at serve time so the
page on disk stays clean. A prototype starts as a greyscale wireframe and ends
looking like an app without a rebuild: every page is built from one component
vocabulary (`server/skins/base.css`, about forty classes: app shell, stats,
tables, kanban, tabs, dialogs, toasts, empty states, skeletons, forms, charts,
icons), pages are started from a page archetype
(`skills/design-session/references/patterns.md`), states are variants toggled
in the panel, and the viewport select narrows the page in place through
container queries.

### Skins: how it could look, not what it is built with

A prototype here is a wireframe of what to build. The panel's skin selector (or
`--skin` at init, or "show me this in MUI" in chat) swaps one stylesheet,
`.design-studio/skin.css`, so the same structure renders in the feel of
`wireframe` (default, greyscale), `shadcn`, `bootstrap`, `mui` or `astryx`.
**Every skin is a lookalike authored from the library's public defaults, not the
library** — no CDN, no React runtime, no registry install; the panel and the
export brief say so. Real components are `/design-studio:preview`'s job. The
vocabulary a skin styles and the honesty line per skin:
`skills/design-session/references/skins.md`.

### Multi-page flows

One file per screen under `pages/`, plain relative links between them, and the
panel's **Go** tool (or Alt+click in any tool) walks them; the page switcher
lists every page. `partials/<name>.html` + `<!-- include: name -->` is the shared
sidebar or top bar, inlined at serve time and at export. `flow.json` is the
record of which link leads where: Claude writes it as links are added or walked,
the panel shows "Flows from this page", and the brief draws it as a mermaid
graph. States (empty, error, logged-out) are variants of one page, not pages.
Contract: `skills/design-session/references/flows.md`.

### What each gesture becomes

| in the panel | Claude does |
|---|---|
| chat message (with an element selected) | the request, scoped to that element |
| drag and drop on a sibling | reorders the DOM; a drop with no target becomes a layout change in that direction, never `position:absolute` |
| corner-handle resize | width, column span, basis, padding or aspect, by the element's role, said in the reply |
| colour pick | the nearest token in `tokens.css`, or a new one under both `:root` and `.dark` |
| double-click text edit | verbatim content change |
| note on an element | a brief scoped to it |
| Go tool / Alt+click on a link | the browser follows it; Claude adds the edge to `flow.json` if the record lacked it |
| "link this to reports" with a selection | href set, edge recorded, page created from the shell if missing |
| skin selector, rich checkbox | nothing to edit — the server swapped `skin.css` / `rich`; Claude logs the preference |
| viewport, state selectors | preview only; context for the next gesture |
| End session | export, then stop |

Three picks on one axis in a row make Claude offer candidates side by side instead
of a fourth single reveal. The full contract is
`skills/design-session/references/event-protocol.md`.

## The real-component preview

The renderer is consent-gated, writes only scratch files it can prove are its own,
and verifies cleanup: `scripts/preview-cleanup.sh <project-root>` removes every
`__design-preview__` artefact and exits non-zero if anything remains. Registry
components (ReUI, Aceternity, Magic UI) in a variant are looked up through the MCP
servers below, never recited. Variant depth — lanes, states, serves/trades/breaks —
is `skills/real-preview/references/variant-depth.md`.

## Component registries (MCP)

An MCP server that reads component registries **from the source**, so a build never
picks a component — or estimates what a registry contains — from recall.

### Why it exists

Two skills in this marketplace already forbid working from memory, in plain words:

- `ui-ux/skills/reui-best-practices` — *"never write ReUI API details from memory"*
- `ui-ux/skills/aceternity-best-practices` — *"do not reconstruct the component from memory"*

A run breached both anyway, three times in one session:

| claim made from recall | actual |
| --- | --- |
| "a ~60-component registry" | **270** components |
| "the library is licence-gated, unavailable" | install API is paid; **the code is MIT on GitHub** |
| "the library is free and open-source" (after reading a marketing page) | the **endpoint** does require a key |

None of that was disobedience. Recall does not feel like breaking a rule — it feels like
knowing something, and the moment a check would have helped is the moment it feels least
necessary. Prose cannot fire there. A tool in the tool list can, because it makes reaching
for the source cheaper than remembering.

### Why a cache and not a scraped copy

The obvious alternative — scrape the registries once into a tidy file for the model — puts
the same bug one layer out, and this repo can prove it twice over: the hand-written
inventory in `ui-ux/skills/aceternity-best-practices/references/aceternity.md` was five days
old and said "100+" against an actual 270, and the gate copied into a built project was
already older than the plugin that shipped it.

So every answer carries `source`, `fetched_at`, `from` (`network` | `cache`) and `stale`
beside the data. Same bytes on disk as a scraped copy; opposite epistemics. The cache is a
speed and offline concession, never an authority — when the network is gone it says how old
what it is serving is, and when there is no cache either it says *unreachable* rather than
letting a plausible reconstruction through.

### Tools

| tool | answers |
| --- | --- |
| `registry_list` | everything in a registry (or all of them): name, kind, deps, heaviness, count |
| `registry_search` | which component does X — matched on name, kind and dependency |
| `registry_get` | one component's real entry: exact deps, file list, source, install command |

`heavy` flags anything pulling a 3D/particle runtime (`three`, `@react-three/*`,
`three-globe`, `cobe`, `@tsparticles/*`, `simplex-noise`). A registry index is the only place
a build can learn what a block **costs** before installing it, which is what craft-layer's
ambition floors and its "house motion must not satisfy a reach floor" clause both turn on.

### Registries

| registry | source | note |
| --- | --- | --- |
| `aceternity` | `ui.aceternity.com/registry.json` | motion-heavy marketing blocks; several are `heavy` |
| `shadcn` | `ui.shadcn.com/r/index.json` | the base primitives most registries build on |
| `magicui` | `magicui.design/r/registry.json` | animated marketing components |
| `reui` | **not served locally** — hosted MCP server at `mcp.reui.io` | see below |

**On ReUI.** `reui.io/r/*` answers `Authentication required … Bearer YOUR_LICENSE_KEY`, so
the local server has **no** ReUI entry at all — a credential-free scrape could only be a
half-working one, and a half-working entry teaches the model the registry is broken rather
than that it is paid. ReUI is served by its own hosted MCP server, declared beside this one
in `.mcp.json`. The local server does not hold, request, forge or route a licence key. That
is not a workaround — it is the licence working as written. A paywall on a convenience API
is a fact about paying for tooling; the LICENSE file (`github.com/keenthemes/reui`, MIT) is
the fact about the code, and the two answer different questions.

### Two servers, one install

| server | transport | auth |
| --- | --- | --- |
| `registry-source` | stdio, local, dependency-free | none |
| `reui` | http → `mcp.reui.io` | browser sign-in, once |

**The second entry exists because a marketplace has to DELIVER a capability, not describe
one.** ReUI's server was first set up by hand on one machine with `claude mcp add`, which
reaches exactly nobody who installs this marketplace. A plugin shipping `.mcp.json` is the
delivery mechanism; a note in a README saying "you could also add…" is not.

To authenticate: `/mcp` → **reui** → **Authenticate**. A browser sign-in the user completes
themselves, so **no credential is ever held in this repo, in a plugin, or by an agent**.
Until that is done it reports `Needs authentication` and the local server still answers for
Aceternity, shadcn and Magic UI, so nothing is blocked on it. Headless environments use a
personal token via an `Authorization` header, added locally and never committed. If you
previously added `reui` by hand, `claude mcp remove reui` once this plugin is installed, or
the same server is declared twice. Cache lives at `~/.cache/claude-registry-source/`, 24h
TTL, `refresh: true` on any tool to bypass it.

## What has teeth and what is recorded

| claim | standing |
|---|---|
| The bridge: seq-ordered events, single delivery through the cursor, editor injection, CSRF header on every mutation, traversal refusal, SSE reply and reload, proxy injection and `Location` rewrite, `--status`/`--stop`, skin list/switch/fallback, listening/away presence, partial inlining with a visible marker for a missing one, `/__td/flow`, base+delta skin assembly, rich toggle injecting `data-rich`, shipped icon and chart assets | **gate** — `scripts/__tests__/serve.test.sh`, run by CI's plugin-harness step |
| The hook injects only whole events, advances the cursor no further than the last one printed, and stays silent for `/design-studio:` prompts | **gate** — the same harness runs `hooks/pending-events.sh` against a live-pid fixture (skipped without `jq`, which is also when the hook itself is silent) |
| Preview cleanup leaves no `__design-preview__` artefact | **gate** — `scripts/preview-cleanup.sh` exits non-zero on leftovers, harnessed by `scripts/__tests__/preview-cleanup.test.sh`. Residual: a scratch file renamed away from the marker is invisible, which is why the skill forbids renaming |
| `flow.json` stays true to the links on disk | **agent-graded** — Claude writes it; `navigate` events surface a link the record missed, nothing else checks |
| A skin is presented as a lookalike, never as the library | **recorded** — the skin files and the panel label say it; nothing checks a reply repeats it |
| The hook is silent without a running session | **recorded** — the dynamic budget baseline records its silent cost; nothing else reads it |
| A gesture is applied faithfully to source, replies are one line, tokens over inline styles | **agent-graded** — the reply and the reload are the review; nothing scripts it |
| Contrast and light/dark completeness at export | **recorded** — the skill instructs the check; no script runs it |
| A registry answer is never reconstructed from memory | **recorded** — the tool makes the source cheaper than recall; nothing checks a build used it |

## Limits, stated

- The panel header says **listening** while the session is blocked on the poll and
  **away** otherwise. Away is not broken: what you send is kept and applied when
  the session polls again — or, if you type a prompt in the terminal that runs
  the session, the hook drains it into that turn. That terminal must be in the
  project that holds `.design-studio/`; a session driving another project's root
  from elsewhere never sees the hook.
- Editor changes are preview only until Claude writes them; the page reloads from disk.
- Selectors are heuristics (`#id`, `data-td`, class + `nth-of-type`). Framework-hashed
  classes in `proxy` mode can defeat them; Claude asks for the component name.
- `proxy` mode carries no websockets: Vite/Next HMR disconnects behind it, the page
  keeps working, Claude's `reload:true` is the refresh. Cross-origin iframes inside the
  app are not editable.
- Loopback only; one session per project root; nothing is published. The URL dies
  with `--stop`.
- The preview never scaffolds an app to render in: a greenfield dir gets the fallback.
- Someone wanting only the registry MCP installs the session server too. Both are
  small and dependency-free; the cost is the always-on description, stated in
  `scripts/context-budget-baseline.json`.

## Pairs well with

- **ui-ux** — `/ui-ux:theme` is candidate-driven colour theming: it proposes, you pick.
  The design session is direct manipulation: you gesture, the session applies. Both
  emit CSS variables; `/design-studio:export write` merges into the same project theme
  file `/ui-ux:theme` writes, diff shown first. ui-ux's stack skills are what call the
  registry tools.
- **taskmaster** — its `visual-decisions` shell mockup is the preview's fallback, and
  its walkthrough reads an open session's `flow.json`.
- **craft-layer** — the studio pipeline hands undecided forks to `/design-studio:preview`
  and reads registry cost (`heavy`) for its ambition floors.
- **craft-suite** — the design bundle carries this plugin.
