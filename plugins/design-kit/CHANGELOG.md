# Changelog — design-kit

Consumer-facing changes only. Newest first.

## 0.6.1 — 2026-09-26

- The four meta-bundles (core-, frontend-, craft-, workflow-suite) were retired on 2026-09-26; install through `all-plugins` or `/stack-scan:suggest`. The `system` skill's install hint names design-kit directly instead of the retired `craft-suite`.

## 0.6.0 — 2026-09-25

- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

### Fixed
- **The unread-pick nudge reads the phase sentinel and the board at the project root, not
  wherever the shell had `cd`'d to.** The hook's payload `cwd` follows the model's `cd`
  (finding 2 of `rationale/2026-09-25-session-plugin-usage-review.md`, in the marketplace
  repository), so a `build` phase declared at the root was invisible from `app/Models` and
  the nudge spoke through it, and a board built at the root went unannounced after a `cd`.
  It now resolves the git root (outside git, `CLAUDE_PROJECT_DIR` when the cwd is under
  it) and reads `.claude/cc-phase.json` and `.design-kit/decisions.jsonl` there, and only
  there. A stray `<subdir>/.design-kit/` left by an older `dk.sh` is no longer announced:
  `dk decision --consume` could never clear it, so the line would repeat on every prompt.
  The harness gained the subdirectory-cwd cases.
- **`.design-kit/` lives at the project root, whichever directory the shell is in.**
  `dk.sh` wrote `./.design-kit`, so a verb run after the model had `cd`'d into `src/` built
  a second one there, with its own board, decisions and usage log. The unread-pick hook
  never saw it, and `dk decision` run from the root never saw it either. `dk.sh` now
  resolves the root with the same shared state-root block the hook uses, and exports
  `DESIGN_KIT_DIR` so every script it runs writes there. Run on their own, `deck-build.py`,
  `board-build.py`, `artifact-bundle.py`, `deck-export.sh` and `snapshot.sh` fall back to
  `.design-kit/` at the git toplevel. At the root every printed path is unchanged; from a
  subdirectory it is absolute. An explicit `DESIGN_KIT_DIR` is still used exactly as given.
  The `.gitignore` block stays root-relative. `dk review --base <git-ref>` now reads the
  committed shots from the toplevel: `git archive` refuses a path outside the cwd, so from
  a subdirectory it found none. `dk --help` no longer writes the `.gitignore` block before
  printing. `design-system/` is not anchored: `dk check` and `dk decision --record` still
  read the shell's directory. Standing: **gate**. `dk.test.sh` runs board, slides,
  decision, a standalone `deck-build.py` and an explicit override from a subdirectory.
  `snapshot.test.sh` runs a review from one, with a directory base and with a git-ref base.
  `unread-pick.test.sh` checks that the stray board stays silent.

### Added
- **`dk snapshot --storage-state <file>`: before/after behind a login.** Until now a route
  behind a login shot the login page, so none of the authenticated apps in the measured
  sessions could get a before/after. The file is a Playwright `storageState` JSON (cookies,
  plus localStorage per origin), saved once from the walk user's sign-in and never from the
  user's own account. The README's "Behind a login" gives a one-call save for the
  Playwright MCP browser. That call keeps only the app's cookies: a plain `storageState()`
  from a browser attached to a real profile saved 48 cookies of the user's own sessions
  beside the app's one. The CLI screenshot cannot take a cookie, so this path drives the
  same Chromium browser over the DevTools protocol on a pipe (python3 stdlib only). It
  settles in real time: the load event, then 500 ms of network quiet, at most 3 s. A route
  that ends on another URL (a sign-in redirect, an expired session) is still shot, with a
  `WARN` naming where it landed. A file holding cookies for other hosts draws a `WARN` too.
  **A state file inside a git work tree that git does not ignore is refused with exit 1**,
  and a tracked file never counts as ignored: it holds a live session token. Keep it under
  `.design-kit/` or outside the repo. Standing: **gate** for the refusals (missing,
  malformed, empty, un-ignored, tracked). With a browser installed, the harness shoots a
  cookie-guarded route where the server logs the cookie and the seeded localStorage, and an
  expired session that must `WARN`. Run by hand once on 2026-09-25 (Chrome 153, Playwright
  MCP): signed in through a form on a throwaway app, saved with the README call (2 cookies
  plus localStorage), then `dk snapshot` from `app/Models` shot the signed-in dashboard at
  1440 and 390. Not carried: sessionStorage, IndexedDB, HTTP auth headers.

## 0.5.0 — 2026-09-22

### Added
- **`dk snapshot` and `dk review` — the before/after this plugin could not show.** Every
  surface here produced a picture of a design and none of them could show what a change
  did to a screen: the only shots taken anywhere were the current-state ones a craft gate
  writes, with nothing to compare them to. `scripts/snapshot.sh` adds
  `dk snapshot [--routes …] [--device desktop|mobile|both] [--base-url …] [--out …]`,
  which loads each route in the Chromium-family browser `board-export.sh` already locates
  (asked for as `board-export.sh --which`, so the discovery and its install hint stay in
  one place) and writes `<out>/<device>/<route-slug>.png` under
  `.design-kit/shots/<git short sha, else a UTC timestamp>/`; and
  `dk review --base <dir|git-ref>`, which pairs the newest shot set against that base and
  writes `.design-kit/reviews/<pair>.html` — before | after | a pixel-diff heatmap per
  route — served on the same preview URL, with one table row per route carrying the
  changed-pixel percentage. A second shoot at the same commit writes `<sha>-2` rather than
  over the set you are about to compare against. The heatmap and the percentage need
  `python3` with Pillow; without it the page shows the pair alone and every row reads
  `no diff engine: install Pillow`. No hook, no command, no threshold.
  Standing: **gate** for the exit codes and the pairing — `0` shot/rendered, `1` bad
  arguments, `2` browser or server unreachable, printed as `NOT MEASURED` and never as
  "no change"; `scripts/__tests__/snapshot.test.sh` drives the argument errors, that
  exit, both diff-engine branches, the pairing over fixture PNG dirs, and one real shoot
  when a browser is installed, saying so when there is none. Reading the pair is
  **agent-graded**: nothing here asserts a pixel. Not covered: auth flows, per-component
  crops, settling past one 3 s budget, device emulation beyond the viewport size.

## 0.4.0 — 2026-09-22

### Added
- **`dk drift` — the literal-colour check on the project's own components.** Until now the
  only drift reader ran on an imported handoff bundle; `dk check` compared `tokens.json` to
  its own re-extraction, and the palette nag fired once a session on nine hexes. A component
  hardcoding `#6366f1`, or reaching a colour through `bg-indigo-500`, went unseen by all
  three — the named palette utility never reaches a stylesheet, so every token-reading check
  stays green over it. `handoff-drift.py` gained a `--scan` mode over
  `.tsx/.jsx/.vue/.blade.php/.css/.scss` sharing the bundle mode's token reader, and
  `dk drift [PATHS|--staged|--diff <base>] [--ci]` drives it. `--ci` exits 1 on any hit; no
  token source anywhere exits 2 (`not measured`), never a green; an empty `--staged`/`--diff`
  selection scans nothing rather than the whole tree. `bg-primary` and `var(--primary)` are
  clean by construction, a `--name:` declaration line is the token being defined and never a
  hit, and `href`/`to` values are blanked so a `#dad` anchor is not read as a colour.
  Standing: **gate where you wire it** — nothing in this plugin runs it for you, so not run
  is not clean; `scripts/__tests__/drift.test.sh` drives hit, clean, both exits and the git
  selectors, and CI runs it with every other plugin harness.

### Fixed
- **`hooks/unread-pick.sh` starts `#!/bin/bash`.** A hook that promises to fail open cannot
  depend on `/usr/bin/env` resolving: on a stripped PATH the kernel returns 127 before the
  fail-open code runs.

## 0.3.0 — 2026-09-22

### Fixed
- **`hooks/unread-pick.sh` could fail on every prompt, and could be muted forever by a run
  that died.** It was the only hook in the marketplace carrying `set -euo pipefail` and it
  called `python3` unguarded, so a machine without `python3` on PATH got rc=127 on each
  prompt. It also hand-rolled the phase-sentinel read: no TTL, no `session_id` check, and a
  hardcoded `build|verify|review|ship` list that let it speak through `plan` while its own
  `lane.tsv` row claims `decide`. It now guards `python3` like `jq`, drops `set -e`, and runs
  the marketplace's shared phase guard against its OWN `lane.tsv` row, so the phase list
  cannot drift from the declaration. `unread-pick.test.sh` gained the two probes:
  python3 off PATH → exit 0, silent; a dead session's sentinel aged past the 120-minute TTL
  → the hook speaks again and the stale file is unlinked.

### Added
- **design-kit is in a bundle.** It joined `craft-suite` (0.8.0) alongside craft-layer and <!-- removed-ok -->
  ui-ux, which had zero references to it between them, and craft-layer's Reuse map now names
  the two moves it owns: pre-build artboards, and the extracted `design-system/` record.
- **A DTCG interop paragraph in the README.** Names the Format Module 2025.10 draft, the two
  places `tokens.json` deviates from it (colour and dimension stay the strings the source
  wrote), and Tokens Studio and Style Dictionary as the consumers that read this structure
  and need those two forms converted. The "Figma import or export: not in this release" line
  now points at it instead of reading as a dead end.
- The `system` skill says in one line that it RECORDS values and `/ui-ux:theme` GENERATES
  them, which is the next move when the `## Not found` list says the source has no palette.

### Changed
- `/design-kit:in-codebase` glosses what the "scratch entry" consent actually buys at the
  point of the ask, rather than offering an undecodable label.
- Two more steps route through `dk.sh` (`scratch --detect`, `export`). The README's claim of
  "one permission rule" is corrected rather than repeated: four steps deliberately call a
  script directly because `dk` has no verb that does only what they need, and the README now
  names all four and the second rule they draw.

## 0.2.0 — 2026-09-22

The experience pass after the simulation (`rationale/design-kit-experience-ideas-2026-09-22.md` ideas 1–4, 6).

### Added
- `scripts/dk.sh`: one entry point for every surface (one permission rule); `.design-kit/workshop.json` state so commands default their next step; `.design-kit/usage.jsonl` per verb; `dk status`; `dk check` before every command.
- Decision channel: the board posts picks, knobs and text edits to the server's loopback-only `/_decision` route; `dk decision --latest --consume` reads them back as the copy-as-prompt prose; `dk decision --record` appends to tracked `design-system/DECISIONS.md`; a UserPromptSubmit hook names an unread pick in one line (`CC_DESIGN_KIT_PICK=off`).
- Gallery: flow strip and a per-page token badge (green current / amber moved) from the `design-kit-tokens` stamp; `_index.json` carries it.
- `/design-kit:system`: writes `design-system/components.json` (typed props, defaults, required flags, variants, stories, honest `gaps`); `--check` compares a fresh extraction against the committed tokens and exits 1 with one `check:` line per moved token.
- `/design-kit:in-codebase`: the scratch page is pre-filled from components.json — stylesheet, alias-aware imports, prop signatures, a variant strip with required props filled or commented out, a `gap:` comment per extractor blind spot.
- Every deck, board and artifact is stamped `design-kit-tokens` (tokens sha12 + git revision).
- Measured: skill-router rows for every surface and `scripts/dk-usage.sh` (created / revisited / picked / rendered / exported / shared / followed-by-commit per project); the README states the kill trigger as a number — 30 days after 0.2.0, ≥3 projects, followed-by-commit = 0 and shared = 0 → retire.

### Fixed (second simulation, a Laravel Blade fixture)
- `/design-kit:system`: a Blade view without `@props` that is the template of a class component now takes its props from `app/View/Components/<Name>.php`'s promoted constructor parameters, with types.
- `/design-kit:in-codebase`: a required Blade prop with no declared type is filled from the brief instead of commenting the component out; the scratch page wraps in `<x-app-layout>` only when the project defines one, otherwise it is a standalone page carrying the layout's `@vite` directive.

### Added (scratch hygiene)
- The first `dk` verb inside a git repo appends a managed `.gitignore` block for `.design-kit/` and `__design-kit__/`; never for a path with tracked files; `DESIGN_KIT_IGNORE=off` skips it.

### Changed
- The server's contract: "no write route" became one loopback-only, header-gated, append-only route; export and publish stay scripts.

## 0.1.0 — 2026-09-22

### Added
- First release: five commands mirroring the Claude Desktop design picker as local
  files — `/design-kit:slides`, `/design-kit:design`, `/design-kit:in-codebase`,
  `/design-kit:system`, `/design-kit:artifact` — plus the plugin's own preview server
  (`scripts/serve.py`: gallery, live reload, `--lan`) and a harness per script.
- `/design-kit:slides`: outline → self-contained HTML deck with notes, overview and print CSS; PDF via a local Chromium-family browser, editable PPTX via consent-gated pptxgenjs; the builder gates the 6-line rule and self-containment.
- `/design-kit:in-codebase`: render a design with the project's own components on its dev server (Vite React/Vue, Next, Nuxt, Laravel) behind a consent gate, with marked scratch files a verify-gated cleanup removes; Claude Design handoff bundles get a colour/font drift table against the repo's tokens first.
- `/design-kit:artifact`: one self-contained HTML artifact from a page, markdown, folder or brief — bundled and versioned by script into a local gallery; LAN, pages-branch (dry run, then `--push` on a second yes) and zip sharing, each behind a question.
- `/design-kit:design`: local artboard board (2–4 directions, editable text, adjustment knobs, pick-and-copy prompt) with `board-build.py` gates and `board-export.sh` PNG/PDF.
- `/design-kit:system`: extract tokens, typefaces and a component inventory from a repo, URL or brand folder into `design-system/` (DTCG-shaped `tokens.json` with sources and dark modes, `DESIGN-SYSTEM.md` with the host-readable block, an `@dsCard` UI-kit page); deterministic, harness-gated.
