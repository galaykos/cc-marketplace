---
description: Make a slide deck from a brief or an outline file — a self-contained HTML deck with speaker notes on the local preview URL, exported to PDF and editable PPTX on request
argument-hint: "[brief | path/to/outline.md] [--theme design-system/tokens.json] [--pdf] [--pptx]"
---

Invoke the `slides` skill (this plugin) and follow it exactly. $ARGUMENTS is
either a brief, or a path to a markdown outline; `--theme <file>` overrides the
design-system lookup; `--pdf` / `--pptx` request exports after the build.

1. If $ARGUMENTS is empty, ask in one round (AskUserQuestion): what the deck is
   for, the audience, and roughly how many minutes it should run — the slide
   count follows from the minutes, not the other way round.
2. Write or adopt the outline per the skill's `references/outline-format.md`,
   build it with `scripts/deck-build.py`, start `scripts/preview.sh` if it is not
   running, and give the user the deck URL. Fix any exit-2 finding by editing
   the outline, not by passing `--allow-long`, unless the user asked for that
   density.
3. Iterate one axis per round until the user is done.
4. Exports only when `--pdf`/`--pptx` was passed or the user asks:
   - `--pdf` runs `scripts/deck-export.sh <deck> --pdf`; on exit 3 relay the
     install options it prints and stop.
   - `--pptx` needs the `pptxgenjs` npm package in `.design-kit/.cache/`. When it
     is not there yet, ask (AskUserQuestion): "Download pptxgenjs into
     .design-kit/.cache (this project only) (Recommended)" / "Skip the PPTX";
     on the first, rerun the exporter with `DESIGN_KIT_PPTX_INSTALL=1`.
5. Report: the outline path, the deck URL, export paths, the theme file used
   (or "built-in neutral"), and what the PPTX does not carry.
