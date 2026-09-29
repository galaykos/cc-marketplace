---
name: system
description: Use when a project needs its design system written down from what actually exists — extract tokens, typefaces and a component inventory from the repo, a live URL, or a folder of brand assets into design-system/ (DTCG tokens.json, DESIGN-SYSTEM.md, a UI-kit page) — or when a design, artifact or deck must start from the project's real palette instead of a remembered one.
argument-hint: "[repo | https://url | brand-dir] [--out design-system]"
---

## Entry: /design-kit:system

Run this section only when a new extraction starts — the user typed `/design-kit:system`
or asked for a new one; when loaded mid-task (after an edit, or to review a change), skip
to the next section.

Every script call below goes through `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh"` (one
permission rule; it records the workshop state the other skills read).

1. Resolve the target from `$ARGUMENTS`: a URL, a directory, or nothing (= the
   current repo). Do not guess a URL from the project name. `--out` overrides the
   output directory; default `design-system/` at the project root.
2. Dry-run first on a repo you have not seen:
   `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/system-extract.py" <target> --dry-run`
   and read the table. If two sources disagree on one token (two `primary`
   rows with different sources), ask the user which is canonical BEFORE the
   full run, one question, and record the answer for step 5.
3. Full run + kit + server in one call: `dk.sh system <target> [--out DIR]`. It
   prints the summary line (tokens, components, sources), every `note:` line — the
   URL-mode "without running JavaScript" caveat is part of the answer, not noise —
   and `url=…/previews/kit.html`. Give the user that URL; the gallery at the base
   URL lists it too. If `.design-kit/` is not in `.gitignore`, say so once; do not
   edit `.gitignore` unasked.
4. Offer, with AskUserQuestion, exactly two options: "Append the `## Design system`
   block to CLAUDE.md so every artifact, design and deck starts from it" /
   "Leave CLAUDE.md alone — the block stays in design-system/DESIGN-SYSTEM.md
   (Recommended)". Append only on the first; if CLAUDE.md already has a
   `## Design system` heading, replace that section rather than adding a second.
5. Close with the `## Not found` list from `DESIGN-SYSTEM.md` in one line each, so
   the user knows what the source does not define. Never fill a gap by hand.

The other four skills run `dk.sh check` before they build and repeat its one line
(`design-system: current` / one `check:` line per moved token / none); this skill
is where a moved token gets re-extracted. Untested claims stay untested: `kit.html`
proves the inventory, not the look of a component — that is `/design-kit:in-codebase`.

## What this decides

A design system here is a **record of what the source already has**, not a proposal.
The script `scripts/system-extract.py` reads the source and writes three files under
`design-system/`; this skill is the judgment around it — what to run it on, how to
read what comes back, and what never to add by hand.

**Recording values is this skill; GENERATING them is `/ui-ux:theme`.** When the `## Not
found` list says the source has no palette, no dark mode or no scale, that is the
deliverable — and the next move is `/ui-ux:theme`, which derives a contrast-checked
light/dark token set with a live preview, written into the project's stylesheet. Re-run
the extraction afterwards and the record catches up. (`ui-ux` is a separate plugin,
installed by name; skipped if not installed.)

## The rule the model gets wrong

Left to memory, the model *remembers* a palette: a primary the repo never declared, a
"standard" 4/8/12/16 spacing scale, Inter because Inter is everywhere. Every one of
those is an invented token, and an invented token in `DESIGN-SYSTEM.md` is worse than
a missing one — the host's artifact skill, `/design-kit:design` and every deck will
build on it as if it were true. Therefore:

- **Nothing enters `tokens.json` without a `path:line` source.** The script enforces
  this (gate); do not hand-edit a value into it. If the source lacks a spacing scale,
  the `## Not found` list says so — that is the deliverable, not a gap to fill.
- **Two tiers stay two tiers.** `--primary` (semantic) and `--zinc-900` (primitive) are
  both emitted; do not collapse them into one "primary" line or drop the primitive.
  Aliases are kept as DTCG references (`{color.primary}`), never resolved by hand.
- **Dark mode is a mode, not a second palette.** A `.dark` / `[data-theme=dark]` /
  `prefers-color-scheme: dark` value lands in `$extensions.design-kit.modes.dark` on the
  same token. If the source has no dark block, the `## Not found` list says "a dark
  mode"; do not derive one.
- **Never name a family you did not find.** `typography.family.*` comes from
  `@font-face`, `font-family` declarations, `--font-*` or a Google Fonts link. The
  system font stack is not a family. (agent-graded — the script cannot see a font a
  designer named in a meeting)

## Running it

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/system-extract.py" <target> [--source repo|url|brand] [--out design-system] [--dry-run]
```

- **repo** (default for a directory with `package.json`, `composer.json`, `src/` or a
  Tailwind config): CSS custom properties in `:root`, dark selectors, `@theme {}` (v4),
  SCSS `$variables`, `theme.extend` in `tailwind.config.*` (literal entries only — no
  JS is evaluated), `components.json`, `@font-face` and `font-family`, and a component
  inventory (TS `Props` interfaces, `defineProps`, Blade `@props`, PHP view-component
  constructors, `*.stories.*` export names).
- **url**: the page plus its linked stylesheets, fetched without JavaScript. Runtime-
  injected styles are invisible and the output says so. Most-used literal colours are
  listed under `$extensions.design-kit.literalColors` — candidates, not tokens.
- **brand** (a directory with no manifest): `.css`, `.svg` fills and strokes, `.md`/`.txt`
  lines carrying a hex code or a "Typeface: X" phrase.

`--dry-run` prints the token table and touches nothing. Use it first on an unfamiliar
repo; the full run writes `design-system/tokens.json`, `DESIGN-SYSTEM.md`, `kit.html`.

## Reading what came back

1. **Conflicts are flagged, not resolved.** Two `primary` sources (a `:root` value and a
   Tailwind `extend.colors.primary`) both appear with their own `sources` list. Ask the
   user which is canonical; record the answer as a one-line note in `DESIGN-SYSTEM.md`
   under `## Notes` and, if they want the loser gone, remove it from the SOURCE and re-run.
   Editing `tokens.json` by hand is overwritten by the next run and leaves no trail.
2. **`literalColors` is evidence, not a palette.** A hex used forty times with no custom
   property behind it is a token the codebase never named. Offer to name it — in the
   source (a new custom property), then re-run — never by typing it into the record.
3. **Component cards are stand-ins.** `kit.html` renders a static approximation carrying
   the real component's name, path, props and variants. It proves the inventory, not
   the look. The look is the project's dev server (`/design-kit:in-codebase`).
4. **`## Not found` is a section to keep.** It tells the next reader what the source
   does not define, which is exactly what a design or deck must not assume.

## Where the record is read

Claude Code's built-in artifact design skill "looks for an existing design system in
your project before choosing its own", in the plain form `DESIGN-SYSTEM.md`'s
`## Design system` block uses, and ranks it: **prompt > your design system > its own
defaults**. Entry step 4 offers to append that block to `CLAUDE.md`; the default is to
leave `CLAUDE.md` alone and point at `design-system/DESIGN-SYSTEM.md` instead. Either
way, `/design-kit:design`, `/design-kit:slides` and `/design-kit:artifact` read the
block first (agent-graded — nothing proves a sibling skill read it).

`tokens.json` is DTCG-shaped (`$type`, `$value`, `{alias}`, `$extensions`) but keeps
colours and dimensions as the strings the source wrote, which the 2025.10 draft no
longer allows; the exact shape, the mode convention and what a consumer must tolerate
are in `references/tokens-format.md`.

## Re-running

The output is deterministic: the same source gives byte-identical files (gate — the
harness runs twice and compares). So `git diff design-system/` after a re-run is a
real change in the source, and a clean diff means nothing moved. Re-run after any
edit to a stylesheet, Tailwind config or component directory; this skill does not
watch for it.

## Anti-patterns

- Typing a hex into `DESIGN-SYSTEM.md` because "the brand is obviously blue".
- Renaming tokens to a nicer scheme in the record while the source keeps the old names —
  the record then describes a codebase that does not exist.
- Treating `kit.html` as the component library, or shipping it into the project tree.
- Running `url` mode against a site and calling the result that site's design system;
  it is the CSS the page happened to ship, minus anything JavaScript wrote.
