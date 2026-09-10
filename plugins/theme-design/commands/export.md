---
description: Export the open theme-design session — tokens.css (light + dark), the prototype pages, a design brief from the session's decisions, and optionally a direct write into the project's theme file — then stop the server
argument-hint: [tokens|pages|brief|write ...]
---

Export the current theme-design session per the `design-session` skill's
`references/export-targets.md`. $ARGUMENTS names the deliverables to produce;
empty means ask once with all four offered. Read `.theme-design/decisions.md`
and `transcript.md` before writing the brief; run the contrast and light/dark
completeness checks before copying `tokens.css`; show the diff and ask before the
direct write. Then stop the server only if this session started it, and report
where every file went.
