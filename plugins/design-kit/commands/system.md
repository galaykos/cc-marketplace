---
description: Extract this project's design system — tokens, typefaces, component inventory — from the repo, a live URL, or a brand-asset folder into design-system/ (DTCG tokens.json, DESIGN-SYSTEM.md, a UI-kit page on the local preview URL)
argument-hint: "[repo | https://url | brand-dir] [--out design-system]"
---

Invoke the `system` skill and follow it exactly; this command is the entry point,
the skill holds the rules.

1. Resolve the target from `$ARGUMENTS`: a URL, a directory, or nothing (= the
   current repo). Do not guess a URL from the project name. `--out` overrides the
   output directory; default `design-system/` at the project root.
2. Dry-run first on a repo you have not seen:
   `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/system-extract.py" <target> --dry-run`
   and read the table. If two sources disagree on one token (two `primary`
   rows with different sources), ask the user which is canonical BEFORE the
   full run, one question, and record the answer for step 5.
3. Full run: the same command without `--dry-run`. Report the summary line it
   prints (tokens, components, sources) and every `note:` line verbatim — the
   URL-mode "without running JavaScript" caveat is part of the answer, not noise.
4. Show the kit: `mkdir -p .design-kit/previews && cp design-system/kit.html
   .design-kit/previews/kit.html`, then `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preview.sh"`
   and give the user `http://127.0.0.1:8124/previews/kit.html`. The gallery at `/`
   lists it too. If `.design-kit/` is not in `.gitignore`, say so once; do not edit
   `.gitignore` unasked.
5. Offer, with AskUserQuestion, exactly two options: "Append the `## Design system`
   block to CLAUDE.md so every artifact, design and deck starts from it" /
   "Leave CLAUDE.md alone — the block stays in design-system/DESIGN-SYSTEM.md
   (Recommended)". Append only on the first; if CLAUDE.md already has a
   `## Design system` heading, replace that section rather than adding a second.
6. Close with the `## Not found` list from `DESIGN-SYSTEM.md` in one line each, so
   the user knows what the source does not define. Never fill a gap by hand.

Untested claims stay untested: `kit.html` proves the inventory, not the look of a
component — that is `/design-kit:in-codebase`.
