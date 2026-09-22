---
description: Make a slide deck from a brief or an outline file — a self-contained HTML deck with speaker notes on the local preview URL, exported to PDF and editable PPTX on request
argument-hint: "[brief | path/to/outline.md] [--theme design-system/tokens.json] [--pdf] [--pptx]"
---

Invoke the `slides` skill (this plugin) and follow it exactly. $ARGUMENTS is
either a brief, or a path to a markdown outline; `--theme <file>` overrides the
design-system lookup; `--pdf` / `--pptx` request exports after the build. Every
script call goes through `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh"`; run
`dk.sh check` first and repeat its one line.

1. If $ARGUMENTS is empty, read `.design-kit/workshop.json` and offer in one
   AskUserQuestion round: "A review deck of the last decision (board, pick, knobs,
   what rendered it — from `design-system/DECISIONS.md` and the board's PNGs via
   `dk.sh export <board> --png`)" when a `board` entry exists / "A deck from a
   brief" (then ask what it is for, the audience, and roughly how many minutes —
   the slide count follows from the minutes) / "Stop".
2. Write or adopt the outline per the skill's `references/outline-format.md` under
   `.design-kit/decks/<slug>.outline.md`, then `dk.sh slides <outline> [--theme F]`.
   It builds, starts or reuses the server and prints `deck=` and `url=`; give the
   user the URL. Fix any exit-2 finding by editing the outline, not by passing
   `--allow-long`, unless the user asked for that density.
3. Iterate one axis per round until the user is done.
4. Exports only when `--pdf`/`--pptx` was passed or the user asks:
   - `--pdf`: `dk.sh export <deck> --pdf`; on exit 3 relay the install options it
     prints and stop.
   - `--pptx` needs the `pptxgenjs` npm package in `.design-kit/.cache/`. When it
     is not there yet, ask (AskUserQuestion): "Download pptxgenjs into
     .design-kit/.cache (this project only) (Recommended)" / "Skip the PPTX";
     on the first, `DESIGN_KIT_PPTX_INSTALL=1 dk.sh export <deck> --pptx`.
5. Report: the outline path, the deck URL, export paths, the theme file used
   (or "built-in neutral"), and what the PPTX does not carry.
