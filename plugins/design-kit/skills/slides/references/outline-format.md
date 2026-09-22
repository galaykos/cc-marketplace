# Outline format — what `deck-build.py` reads

One markdown file, one deck. Everything the model would otherwise improvise is fixed here.

```markdown
# Deck title                      ← required, exactly one; becomes the title slide
Optional subtitle line(s)         ← plain paragraphs before the first ## land on the title slide

## Slide headline                 ← one slide per ##; write the CLAIM, not the topic
- bullet                          ← `-` or `*`; two-space indent nests one level
  - sub-bullet
1. numbered item                  ← `1.` … renders an ordered list
A plain paragraph.                ← ≤ 34em wide, use sparingly
### Small heading                 ← a muted h3 inside the slide
=> 118% | net revenue retention   ← a BIG FIGURE: value | caption; the way to show one number
![alt text](relative/path.png)    ← inlined as a data URI; a missing file is skipped with a warning
fragments                         ← the word alone on a line: this slide reveals items one by one
> notes: first line of speaker notes
> continuation lines of notes     ← any `> ` line after a `> notes:` line joins the notes
```

Fenced code blocks (```lang) stay code on the slide and are written into the
PPTX as monospace text. Inline `code`, **bold**, *italic* and [links](url) work
everywhere. A link to an external URL is allowed in text; an external `src`
(a remote image) is not — the build fails, because the deck must open offline
and on the LAN.

## What the builder enforces (exit 2)

| Rule | Why |
|---|---|
| exactly one `# ` title | the title slide, the file name, the PPTX metadata |
| at least one `## ` slide | an empty deck is not a deck |
| ≤ 6 visible lines per slide body (`--max-lines`, `--allow-long` to warn instead) | the rule the model breaks most; the notes carry the prose |
| no external `src=`/`href=` in the output | self-contained: the PDF print and the phone-on-LAN path both depend on it |

Visible lines = top-level bullets + paragraphs + code blocks + figures + images.
Nested bullets and `###` headings do not count; keep them few anyway.

## What it does not enforce

Whether the headline states a claim, whether a number should be a figure, whether
a slide exists only to decorate — the skill's rules, agent-graded.

## Theme

With no `--theme`, the builder looks for `design-system/tokens.json` (DTCG
`$value` leaves — `color.*background|surface`, `*text|foreground|ink`,
`*primary|accent|brand`, `*muted`, `*border`, `font*family*`) and then
`design-system/DESIGN-SYSTEM.md` (`primary #hex`, `surface #hex`, `Inter for
body`, `JetBrains Mono for code` phrasing). Found values become `--dk-*`
variables in the deck; everything else keeps the neutral built-in set. The
stderr line names which file and which slots were used.

## Output

`.design-kit/decks/YYYY-MM-DD-<slug>.html`, or `--out`. Slide `n` is `#/n`.
Keys: ← → Space · `S` notes panel · `O` overview grid · `P` print · `Esc` leave overview.
