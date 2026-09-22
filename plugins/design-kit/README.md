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
never used here. One write route exists, `/_decision` — loopback only, header-gated,
append-only (see the next section); export and publish stay scripts.

Standing: `scripts/__tests__/serve.test.sh` and `preview.test.sh` drive start, static
serving, reload injection, the listing, path traversal and stop — **gate** (CI runs
every `plugins/*/scripts/__tests__/*.test.sh`). Nothing proves a browser rendered a
page — **recorded**.

## One entry point: dk

Every command's MAIN path runs through `bash ${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh <verb>`,
so `Bash(bash */design-kit/scripts/dk.sh*)` is the one rule that covers ordinary use.
**It is not the only rule you will be asked for.** Four steps deliberately call a script
directly, because `dk` has no verb that does only what they need: the deck build alone
(`deck-build.py`, so a long-slide exit 2 can be fixed before anything is served), the
artifact bundle alone (`artifact-bundle.py`), the handoff-drift table
(`handoff-drift.py`), and the system extraction's dry run (`system-extract.py --dry-run`,
which `dk system` only ever runs as the first half of a full extraction). Those draw a
second prompt, or a second rule — `Bash(python3 */design-kit/scripts/*)` — and saying
"one permission rule" full stop was wrong.
`dk` keeps `.design-kit/workshop.json` (brief, device, theme, the last system stamp, board,
scratch, artifacts, deck) so a command with no argument offers the natural next step, and
appends one line per verb to `.design-kit/usage.jsonl` — the record the Measured section
reads. `dk status` prints the flow; the gallery shows it as a strip, and stamps each page
green or amber ("tokens moved since build") against the current `design-system/tokens.json`.

The board talks back. "Pick this", a knob move or a text edit posts to the server's one
write route, `/_decision`: loopback only, header-gated, append-only into
`.design-kit/decisions.jsonl`; a phone on the LAN is not recorded. `dk decision --latest
--consume` prints exactly the prose the "Copy edits as prompt" button gives, and
`/design-kit:in-codebase` with no arguments renders that pick. A UserPromptSubmit hook
says one line when a pick is waiting and nothing otherwise (`CC_DESIGN_KIT_PICK=off`).
Every pick a command acts on lands as one line in tracked `design-system/DECISIONS.md`.

Standing: `dk.test.sh` drives every verb, `serve.test.sh` the route's accept and three
reject paths and both badge states, `unread-pick.test.sh` the hook — **gate**. That the
model reads the prose as requirements is **agent-graded**.

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

Since 0.4.0 the same reader asks that question of the project's OWN components:

```
dk drift [PATHS | --staged | --diff <base>] [--ci]
```

It reads `.tsx/.jsx/.vue/.blade.php/.css/.scss` and reports two kinds of hit — a literal
hex/rgb/hsl/oklch colour that resolves to no declared token, and a NAMED TAILWIND PALETTE
utility (`bg-indigo-500`, `text-slate-700/50`) whose scale is not a declared token name. That
second kind is the gap that made this exist: it never reaches a stylesheet, so `dk check` and
the bundle table above both stay green while the components drift. `bg-primary` and
`var(--primary)` are clean by construction, which is the whole test. Without `--ci` the table
is the output and the exit is 0; with `--ci` any hit exits 1. No token source anywhere exits 2
(`not measured`) — a drift check that cannot find the tokens has not cleared anything, and an
empty `--staged`/`--diff` selection scans nothing rather than the whole tree.

**Standing: `gate` only where you wire it.** Nothing in this plugin runs `dk drift` for you —
no hook, no command step. It is a script with a harness (`scripts/__tests__/drift.test.sh`,
run by CI's plugin-harness step), and `--ci` is what makes it block, in a CI step or a
pre-commit hook you add. Not run is not clean. What it does NOT catch: spacing, radius, shadow
and font drift; a colour computed at runtime; the right token used in the wrong role. The
script's own header carries the full residual list.

What has teeth: the scratch-file cleanup (`--verify`), the bundle drift table and `dk drift`'s
scan are **gates** — scripts under `scripts/__tests__/` drive all three. Consent before the first write is an AskUserQuestion, once
per session. Finding the right component, passing only real props, rendering all four states, and
never touching a real file are **agent-graded**; `git status` after cleanup is the check.

Limits: stacks it does not detect (Angular, SvelteKit, Rails) fall back to `/design-kit:design`;
a Laravel + separate Vite SPA repo resolves to Laravel unless `--stack` overrides; the bundle
format is undocumented by Anthropic, so detection is lenient and says which files it read; nothing
here proves the page rendered — the browser does. Spacing/radius/shadow drift is read by eye.

Since 0.2.0, `--create <slug> --brief "<line>"` reads `design-system/components.json` when
`/design-kit:system` has written it: the scratch page opens with the app's stylesheet, every
component imported (alias-aware), its prop signature as a comment, and a strip rendering each
union variant with the brief as content. Required props get type-shaped values; one the strip
cannot fake is commented out naming the prop; each extractor blind spot (a generic, an
`extends`, an intersection) is a `gap:` comment naming the file to open. Without
components.json the plain template is written, as before. That the imports resolve is the
dev server's overlay, not a script — **agent-graded**; the filled shape is **gate**.

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

**Where these tokens can go.** The target is the DTCG **Format Module 2025.10** draft
(designtokens.org, Draft Community Group Report of 2026-09-08, which carries its own
"do not attempt to implement this version" warning). The structure matches it: one object
per token with `$type` and `$value`, plain nested groups, `{group.token}` aliases,
`$extensions` for tool data. It diverges in exactly two places, both written down in
`skills/system/references/tokens-format.md`: a `color` `$value` stays the string the
source wrote — a hex, an `oklch()` call, a shadcn HSL triplet — rather than the draft's
`{colorSpace, components, hex}` object, and a `dimension` stays `0.5rem` or `24px` rather
than `{value, unit}`. Both because the form the source used is evidence, and because
`%`/`em` have no conforming object form to convert into. What that costs a consumer:
**Tokens Studio** (the Figma plugin that reads and writes DTCG) and **Style Dictionary**
(which compiles DTCG into CSS, iOS and Android output) both read this structure, and both
need those two value forms converted on their side. This plugin ships neither converter —
standing: **recorded**, nothing here has been run against either tool.

Since 0.2.0 it also writes `components.json` (props with types, defaults, required flags;
variants; stories; honest `gaps`) and gains `--check`: against the committed `tokens.json` it
prints one `check:` line per moved token and exits 1, writing nothing — every command runs it
first through `dk check`. Every deck, board and artifact carries `<meta name="design-kit-tokens">`,
the sha of the tokens file it read (or `none`) plus the git revision, which the gallery badge
reads. Determinism, `--check` and the stamps are **gate** (harness-driven).

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

## Snapshots and review

Two `dk` verbs, no command and no hook — a UI change is easier to judge beside the screen
it replaced than from a diff:

```bash
dk snapshot --routes /,/pricing --device both        # one PNG per route per device
# …change the UI…
dk snapshot --routes /,/pricing --device both
dk review --base .design-kit/shots/<the first set>   # or a git ref whose shots were committed
```

`snapshot` loads each route in the same Chromium-family browser `board-export.sh` finds
(it asks that script, so one install hint serves both) and writes
`<out>/<device>/<route-slug>.png` — `<out>` defaults to
`.design-kit/shots/<git short sha, else a UTC timestamp>/`, desktop is 1440x900, mobile
390x844, and `--base-url` defaults to the dev URL `dk scratch --detect` reports. A second
shoot at the same commit writes `<sha>-2` rather than over the set you are about to
compare against. `review` pairs the newest set (or `--current`) against `--base`, writes
`.design-kit/reviews/<pair>.html` with **before | after | a pixel-diff heatmap** per
route, serves it on the same preview URL as everything else, and prints one table row per
route with the changed-pixel percentage. The heatmap and the percentage need `python3`
with Pillow; without it the page shows the pair alone and every row reads
`no diff engine: install Pillow`.

**Exit codes are the contract** — **gate**, `scripts/__tests__/snapshot.test.sh` drives
each: `0` shot or rendered, `1` bad arguments, `2` the browser or the server was
unreachable, printed as `NOT MEASURED` and never as "no change" — a shot nobody took is
not a screen that did not change. Reading the pair is **agent-graded**: nothing here
asserts a pixel, so there is no threshold and no failing build. Also not here: auth flows
(a route behind a login shoots the login page), per-component crops, scroll or animation
settling past one 3 s budget, and device emulation beyond the viewport size — no touch,
no mobile UA, no DPR change. Two machines' antialiasing counts as changed pixels.

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

A design plugin with one real invocation across ten projects was retired from this
marketplace on 2026-09-14. This one starts from zero and says now what would retire it.

**How it is measured.** `bash scripts/dk-usage.sh --projects <dir>...` (in this plugin)
prints one row per surface per project — created, revisited, picked, rendered, exported,
shared, followed-by-commit — from `.design-kit/usage.jsonl` (one line per `dk` verb),
`.design-kit/decisions.jsonl` (one line per board pick), file mtimes, and `git log` over
the seven days after each decision, restricted to the component paths the decision names.
`followed-by-commit` reads `n/a`, never 0, when no decision names a path. The router side:
skill-router carries a `**/dir/**` row per surface, so `turn-cost.sh --skills` at the
marketplace root can count offers; without those rows it read zero by construction.

**The kill trigger, as a number.** Thirty days after 0.2.0, with at least three projects
that have a `.design-kit/` directory: `followed-by-commit = 0` across all of them AND
`shared = 0` → retire the plugin on the same evidence that retired its predecessor. The
script prints the verdict inputs; the decision is a human's. A non-zero count proves a
surface fired, not that it helped — the only column that means "a design decision changed
code" is `followed-by-commit`.

**Blind spots, stated.** Subagent turns are invisible. A pick pasted from the clipboard is
prose in a transcript, not a decision row, so it counts as nothing. A deck opened in a
browser leaves no record. A project not passed to the script is not measured.

Standing: the script and its harness (`scripts/__tests__/dk-usage.test.sh`) — **gate**;
the thirty-day reading and the retirement call — **recorded**, a human reads the table.

## What gets ignored, and what is yours

The first `dk` verb inside a git repo appends one managed block to `.gitignore` with
`.design-kit/` and `__design-kit__/` — previews, exports, decisions and scratch never
reach a commit by accident. It never adds a path that already has tracked files, and
`DESIGN_KIT_IGNORE=off` skips it. `design-system/` is deliberately not in the block: it
is the tracked record. Standing: `dk.test.sh` drives first run, idempotence, the
tracked-path refusal and the off switch — **gate**. A marketplace-wide sweep across
every plugin's scratch paths lives in git-workflow (`scratch-ignore.sh`, run by
`/git-workflow:finish`).

## Disabling

Uninstall the plugin. `DESIGN_KIT_PORT` moves the server. `.design-kit/` is safe to
delete at any time; `design-system/` is yours and is not.

## Not in this release

Reading comments on a shared page, a version picker in the browser, Figma import or
export, image generation, a component registry, and any hosted publishing beyond a git
pages branch you push yourself.

No Figma bridge does not mean no route out: `design-system/tokens.json` is DTCG-shaped,
and the paragraph under `/design-kit:system` names the two value forms a Tokens Studio or
Style Dictionary consumer has to convert to use it.
