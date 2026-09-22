# Changelog — design-kit

Consumer-facing changes only. Newest first.

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
