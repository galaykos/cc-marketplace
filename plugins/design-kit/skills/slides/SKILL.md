---
name: slides
description: Use when asked for a deck, slides, a presentation, a pitch or a talk from a brief, notes or a repo — a self-contained HTML deck with speaker notes on the local preview URL, exported to PDF and an editable PPTX by script. Not for reading or editing an existing .pptx file.
---

## What this makes

One HTML file under `.design-kit/decks/` that opens anywhere, needs no network,
presents from a browser (arrow keys, touch, `S` notes, `O` overview, `P` print),
and exports to PDF (browser print) and to an editable PPTX (native text boxes,
notes, pictures — never screenshots). The deck is built from an OUTLINE file by
`scripts/deck-build.py`; you write the outline, the script writes the HTML. Never
hand-write deck HTML: the shell carries navigation, print CSS and theme wiring you
would otherwise re-invent per deck.

The outline grammar is `references/outline-format.md`. Read it before writing the
first outline; the `=>` big-figure line, `fragments`, and `> notes:` are the parts
memory gets wrong.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| One idea per slide; a slide body has at most 6 visible lines | **gate** — `deck-build.py` exits 2 over 6 (`--allow-long` warns instead; use it only when the user asked for a dense slide) |
| The deck is self-contained: no external `src`/`href`, images inlined | **gate** — `deck-build.py` exits 2 on any external reference |
| Exactly one title, at least one slide | **gate** — `deck-build.py` |
| A headline states the CLAIM, not the topic ("Retention drove Q3 growth", not "Q3 results") | agent-graded — read every `##` back as a sentence someone could disagree with |
| One number gets the `=>` big figure; a comparison gets a chart or a short list, never a pasted table | agent-graded — a table on a slide is a spreadsheet, not a slide |
| The prose lives in `> notes:`; the slide shows the anchor, the notes carry what you would say | agent-graded — a slide the speaker reads aloud is a handout |
| No decoration slides (section dividers with nothing to say, "Questions?", stock photo slides) | agent-graded |
| Type and colour come from `design-system/` when it exists, else the neutral built-in set — never a per-deck palette | recorded — the builder reads the design system; nothing checks you did not override it |
| Contrast: the built-in tokens pass 4.5:1; a project theme is checked by `/design-kit:system`, not here | recorded — state it when a theme is applied |

## Flow

1. **Source.** A brief → write the outline yourself from the brief and, when the
   deck is about this repo, from the repo (README, changelog, recent commits,
   real numbers from real files — never invented figures; a figure you cannot
   source becomes a question to the user). A path to an existing `.md` → treat it
   as the outline, fix only what breaks the grammar. Write the outline to
   `.design-kit/decks/<slug>.outline.md` so the user can edit it and rebuild.
2. **Build.** `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/deck-build.py <outline>`; on
   exit 2 fix the outline (split the long slide — do not reach for `--allow-long`
   to silence it). The stderr names the theme file used, if any.
3. **Serve.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/preview.sh` and give the user the
   deck URL (the base `preview.sh` printed plus `/decks/<file>.html`). The page reloads itself on
   every rebuild; the gallery at `/` lists every deck. `--lan` puts it on the
   network for a phone — say that a page leaves the machine before using it.
4. **Iterate** one axis per round: order, then headlines, then figures, then
   notes. Rebuild after each edit; the open tab follows.
5. **Export** only when asked: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/deck-export.sh
   <deck.html> --pdf` (needs a Chromium-family browser; exit 3 prints what to
   install, and pressing `P` in any browser is the same output) and `--pptx`
   (needs Node; the script refuses to download `pptxgenjs` until
   `DESIGN_KIT_PPTX_INSTALL=1` — ask the user first via AskUserQuestion, then rerun
   with the variable; the package lands in `.design-kit/.cache/`, never global).
   Report the paths, and for PPTX what is not carried: fragments, transitions,
   nesting beyond one level, theme colours other than the accent.

## What this is not

- Not a `.pptx` reader or editor — an existing PowerPoint file is the host `pptx`
  skill's job; this skill starts from an outline.
- Not a chart engine — a chart is an image or inline SVG you make elsewhere and
  reference by path; the `=>` figure covers the single-number case.
- Not a theme designer — `/design-kit:system` decides tokens; this reads them.

## Honest limits

The PDF is whatever the browser prints; fonts fall back to the system stack when
a theme names a font not installed. PPTX layout is a fixed 16:9 grid of text
boxes, good for editing, not a pixel match of the HTML. Nothing here proves the
deck reads well — open the URL and page through it before calling it done.
