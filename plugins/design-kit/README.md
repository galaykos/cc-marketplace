# design-kit

The Claude Desktop design picker — **Slides, Design, Design in codebase, Design
System, Artifacts** — as five local, own-your-files plugin commands. Every surface is a
plain HTML file under `.design-kit/` in your project, served on one localhost URL by
this plugin's own preview server, exported by scripts you can read. Nothing leaves the
machine unless a command names the path and you say yes.

## What it does

| Desktop option | Command | Produces |
|---|---|---|
| Slides | `/design-kit:slides` | a self-contained HTML deck with speaker notes; PDF and PPTX by script |
| Design | `/design-kit:design` | an artboard canvas of 2–4 directions with editable text, adjustment knobs, PNG/PDF export, and a "copy edits as prompt" bring-back |
| Design in codebase | `/design-kit:in-codebase` | the design rendered with the project's OWN components on its dev server, cleaned up after the pick; intake of a Claude Design handoff bundle with a token-drift table |
| Design System | `/design-kit:system` | `design-system/`: DTCG `tokens.json`, `DESIGN-SYSTEM.md` in the format the host's artifact skill reads, and a UI-kit page with `@dsCard`-marked cards |
| Artifacts | `/design-kit:artifact` | one self-contained, versioned HTML page in a local gallery; LAN, pages-branch or zip sharing on explicit consent |

Why a plugin when the host has `/design`, `/design-sync` and the `Artifact` tool: those
need a claude.ai-backed login, a paid plan, and Anthropic's servers, and the design
system they build lives at claude.ai/design. This plugin keeps the same five moves on
disk, in the repo, reviewable in a diff. The study that sized this is
`rationale/claude-desktop-design-parity-2026-09-22.md`; the retirement of the previous
design plugin on usage evidence (`rationale/marketplace-endgame-review-2026-09-14.md`
§6) is why the **Measured** section below exists.

## Install

```bash
claude plugin install design-kit@cc-plugins-marketplace
```

Needs `python3` (stdlib only) for every script. PDF and PNG export need a Chrome,
Chromium or Edge binary on a common path, or Playwright's chromium; PPTX export
needs Node and installs `pptxgenjs` into `.design-kit/.cache/` after asking.

## The preview server

`scripts/serve.py` (launched by `scripts/preview.sh`) serves `.design-kit/` on
`http://127.0.0.1:8124/`: a gallery of every deck, board, preview and artifact at `/`,
live reload over Server-Sent Events injected into each page, `/_index.json` for
scripts. `--lan` binds every interface so a phone on your network can open it — that
is the only way a page leaves the machine through the server, and every command says
so before using it. Port 8123 belongs to the taskmaster/ui-ux mockup server and is
never used here. No write route exists; export and publish are scripts.

Standing: `scripts/__tests__/serve.test.sh` and `preview.test.sh` drive start, static
serving, reload injection, the listing, path traversal and stop — **gate** (CI runs
every `plugins/*/scripts/__tests__/*.test.sh`). Nothing proves a browser rendered a
page — **recorded**.

## Commands

### `/design-kit:slides` — a deck you own

`/design-kit:slides <brief | outline.md> [--theme <tokens>] [--pdf] [--pptx]` writes an
outline (`.design-kit/decks/<slug>.outline.md`; grammar in the skill's
`references/outline-format.md`) and builds it into one self-contained HTML deck with
`scripts/deck-build.py`: keyboard/touch navigation, `S` speaker notes, `O` overview,
`P` print, `#/n` per slide, theme tokens from `design-system/` when present. It opens
on the preview URL and reloads on every rebuild.

Exports on request: `scripts/deck-export.sh <deck> --pdf` prints one 1280×720 page per
slide with a Chromium-family browser found on the machine (exit 3 names what to
install; pressing `P` in any browser is the same output); `--pptx` writes native text
boxes, notes and pictures with pptxgenjs, which the script downloads into
`.design-kit/.cache/` only after the command asked you (`DESIGN_KIT_PPTX_INSTALL=1`).

What has teeth: the builder FAILS a slide over 6 visible lines, an outline without a
title or slides, and any external `src`/`href` — **gate**. Headline-states-a-claim,
one-number-gets-a-figure, prose-lives-in-notes — **agent-graded**. Limits: the PDF is
the browser's print; the PPTX is an editable 16:9 grid, not a pixel match, and drops
fragments, transitions and nesting past one level. Not a `.pptx` reader — an existing
PowerPoint is the host `pptx` skill's job.

### `/design-kit:design` — directions as artboards on one local canvas

`/design-kit:design <brief> [--screens 2-4] [--device phone|tablet|desktop] [--theme tokens.json]`
drafts 2–4 UI directions as artboards on one canvas, `.design-kit/boards/<date>-<slug>.html`,
served at the plugin's preview URL. Directions differ on structure (navigation, hierarchy, density,
first screen), not colour — the knobs do colour. On the board: edit any text in place, move
spacing/radius/hue/type/density/scheme knobs globally or per artboard (persisted in that browser's
localStorage), pick an artboard, and "Copy edits as prompt" pastes the decision back into the
session as plain requirements. `scripts/board-export.sh` writes a PNG per artboard or one PDF
through a headless Chromium-family browser (exit 3 with the install hint when none is found).

What has teeth: `board-build.py` exits 2 on fewer than 2 or more than 4 artboards, an empty body,
lorem ipsum, or any external asset — a board renders offline — **gate**. That the directions
diverge structurally, that content is real, and the accessibility floor of a hand-written body
are **agent-graded**. Nothing here measures contrast — **recorded**.

Limits: the artboard HTML is a decision aid, never a starting point for implementation (the pick
goes to `/design-kit:in-codebase` or the project's UI build command); knobs restyle the shell's
primitives only; the hue knob rotates the accent and cannot express a near-neutral brand accent
(use `design-system/tokens.json`); localStorage means edits do not travel to another browser.
Claude Code's own `/design` publishes artboards to claude.ai and needs a signed-in session; this
one stays on disk.

### `/design-kit:in-codebase` — the design, built from the real components

`/design-kit:in-codebase <brief | board.html#board=N | handoff-dir>` renders a design with the
project's OWN components on its OWN dev server. `codebase-scaffold.sh --detect` reads the stack
from disk (Vite React/Vue, Next.js App Router, Nuxt, Laravel Blade) and `--create <slug>` writes a
scratch entry under `__design-kit__/` paths, every file marked on line 1; the model fills it by
importing real components and providers, opens it on the dev URL, and after the pick
`codebase-cleanup.sh` removes every trace — `--verify` exits 1 if anything is left.

A Claude Design handoff bundle (a folder of exported .html plus a README) goes through
`handoff-drift.py` first: every colour and font in the export against the repo's tokens
(`--*` custom properties incl. Tailwind v4 `@theme`, `tailwind.config.*`, `design-system/tokens.json`),
one row per value — `match`, `near (Δ)`, `no token` — and each `no token` row is a question, never a
literal in the tree. The export is a reference; its HTML and class names never land in the project.

What has teeth: the scratch-file cleanup (`--verify`) and the drift table are **gates** — scripts
under `scripts/__tests__/` drive both. Consent before the first write is an AskUserQuestion, once
per session. Finding the right component, passing only real props, rendering all four states, and
never touching a real file are **agent-graded**; `git status` after cleanup is the check.

Limits: stacks it does not detect (Angular, SvelteKit, Rails) fall back to `/design-kit:design`;
a Laravel + separate Vite SPA repo resolves to Laravel unless `--stack` overrides; the bundle
format is undocumented by Anthropic, so detection is lenient and says which files it read; nothing
here proves the page rendered — the browser does. Spacing/radius/shadow drift is read by eye.

### `/design-kit:system` — the design system as a record, not a proposal

`/design-kit:system [repo | https://url | brand-dir]` runs `scripts/system-extract.py`
and writes `design-system/`: `tokens.json` (DTCG-shaped: `$type`, `$value`, `{alias}`,
dark values under `$extensions.design-kit.modes`, every token with a `path:line` source),
`DESIGN-SYSTEM.md` (the plain `## Design system` block Claude Code's artifact skill reads,
a component inventory with props and variants, and a `## Not found` list), and `kit.html`
(a UI-kit page whose every card carries an `@dsCard` marker, shown on the preview URL).

What it reads: `:root`/dark-selector custom properties, `@theme {}`, SCSS `$vars`,
Tailwind `theme.extend` literals, `components.json`, `@font-face`/`font-family`, and
component files (TS Props, `defineProps`, cva variants, Blade `@props`, PHP view
components, stories). URL mode fetches the page and its stylesheets without JavaScript
and says so in the output. Brand mode reads `.css`, `.svg` fills and `.md` hex lines.

What has teeth: nothing enters the record without a source, and the same source
gives byte-identical files — **gate**, `scripts/__tests__/system-extract.test.sh` runs
it twice and compares. Which of two primaries is canonical is asked, not decided —
**agent-graded**. Appending the block to CLAUDE.md is an explicit yes; default is no.

Not this: it does not evaluate JS (a Tailwind config built from functions yields only
its literal entries), does not render real components (`kit.html` cards are static
stand-ins that name the component and its props — `/design-kit:in-codebase` renders
the real thing), and does not conform to the DTCG 2025.10 object forms for colour and
dimension — values stay as the source wrote them; `references/tokens-format.md` says why.

### `/design-kit:artifact` — one self-contained page, versioned, shared on a question

`/design-kit:artifact [file.html | file.md | dir | brief] [--name slug] [--zip]` — every
stylesheet, script, image and font inlined by `scripts/artifact-bundle.py` — written to
`.design-kit/artifacts/<slug>.html`, versioned (`.versions/<slug>/vN.html` +
`<slug>.versions.json`), and served on the plugin's preview URL with live reload. A `.md`
source renders through the page shell (ATX headings, one-level lists, pipe tables, fenced
code, links; no nested lists, footnotes or reference links). A brief means the model
writes the page from one of five patterns (walkthrough, compare, dashboard, checklist,
bring-back) with data from this session.

Sharing is a question every time, default "keep it local": LAN (`preview.sh --lan`),
a pages branch (`scripts/artifact-publish.sh`, dry run first, pushed only on a second
yes, never enables Pages, never force-pushes), or a zip. There is no other network path.

What has teeth: the bundler's inlining, UTF-8 refusal, stamp, version ledger, network
and unresolved-link reports, and the publisher's worktree isolation are **gates** —
`scripts/__tests__/artifact-*.test.sh` drive each. Page quality is **agent-graded**.
Not here: comments on a page, refresh from live data, runtime asset loads (a page that
fetches assets from JavaScript keeps those references unreported), `srcset` rewriting.

## Boundary with the host

- `/design`, `/design sync|import|export`, `/design-sync` and the `Artifact` tool are
  Claude Code built-ins. This plugin never calls them and never blocks them. When they
  are available, `/design-kit:system`'s `DESIGN-SYSTEM.md` is the record the host's own
  artifact design skill reads first, and its `@dsCard`-marked kit cards are the shape the
  host's design-system sync indexes.
- The `pptx`, `theme-factory` and `web-artifacts-builder` skills synced from claude.ai
  are Anthropic's. `/design-kit:slides` exports through its own script so a deck exists
  without them; when the `pptx` skill is present it is the better editor of a `.pptx`.

## Measured

A plugin with one real invocation across ten projects was retired from this
marketplace. This one starts with zero. `bash scripts/turn-cost.sh --skills` from the
marketplace root is the retirement queue: it names every design-kit skill with its
router-ledger and transcript counts. Zero proves nobody used it here; non-zero proves it
fired, not that it helped. The first version after this one should cite that table.

## Disabling

Uninstall the plugin. `DESIGN_KIT_PORT` moves the server. `.design-kit/` is safe to
delete at any time; `design-system/` is yours and is not.

## Not in this release

Reading comments on a shared page, a version picker in the browser, Figma import or
export, image generation, a component registry, and any hosted publishing beyond a git
pages branch you push yourself.
