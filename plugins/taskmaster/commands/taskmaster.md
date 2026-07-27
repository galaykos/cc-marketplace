---
description: Shorthand for /taskmaster:task — grill to zero ambiguity, then emit a spec and single-prompt task cards
argument-hint: [task-description]
---

Alias of `/taskmaster:task`. Read `${CLAUDE_PLUGIN_ROOT}/commands/task.md` and
execute it with $ARGUMENTS verbatim — same pipeline, same boost preamble, same
steps. This file intentionally restates none of it: it was a 105-line byte-copy
whose parity a gate had to police; the alias carries nothing that can drift
(scripts/validate.sh enforces this shape).
