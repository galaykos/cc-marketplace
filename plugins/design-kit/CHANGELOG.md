# Changelog — design-kit

Consumer-facing changes only. Newest first.

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
