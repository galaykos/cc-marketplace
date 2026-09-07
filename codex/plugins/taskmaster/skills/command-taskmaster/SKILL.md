---
name: command-taskmaster
description: "Shorthand for taskmaster:command-task."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

Alias of `taskmaster:command-task`. Read `${CLAUDE_PLUGIN_ROOT}/skills/command-task/SKILL.md` and
execute it with the user-supplied arguments verbatim — same pipeline, same boost preamble, same
steps. This file intentionally restates none of it: it was a 105-line byte-copy
whose parity a gate had to police; the alias carries nothing that can drift
(scripts/validate.sh enforces this shape).
