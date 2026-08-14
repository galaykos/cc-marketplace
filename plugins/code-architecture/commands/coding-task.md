---
description: Start ad-hoc coding work with the house rules already loaded — detects the stack, loads the always-relevant discipline skills, primes the stack-matched ones by path, and states in one line whether the task proceeds inline or belongs in the taskmaster pipeline.
argument-hint: [what you want built]
---

Start work on $ARGUMENTS with this repository's standing rules in context before the first
edit.

1. Invoke the `coding-entry` skill from this plugin and follow it — it owns the load/prime
   split, the detection map, the triage rule, and the output shape. Cite it; do not restate
   it here.

2. Detect the stack from manifests only: `composer.json`, `package.json`, a compose file,
   `components.json`, `.github/workflows/`, and whether `migrations/` or `tests/` exist.
   When the `stack-scan` plugin is installed, use its `installed-versions` skill for
   versions instead of parsing them yourself, and say which path you took. No network
   calls, no subagents — this step is a few file reads.

3. Load the five always-relevant skills named in `coding-entry`, and prime the
   stack-matched ones per `coding-entry/references/skill-map.md`. Name every signal whose
   owning plugin is not installed; a silent skip reads as "nothing applies".

4. Print the four-line block from `coding-entry` § Output shape — `stack:`, `loaded:`,
   `primed:`, `triage:` — and nothing else before acting.

5. Act on the triage verdict, without exception:
   - `trivial` → do the work now, applying the loaded skills, reading a primed path when
     the work reaches that surface.
   - `needs a spec` → **stop**. Print the unresolved unknown and hand off:
     `/taskmaster:task $ARGUMENTS`. Do not write code, and do not start a question round —
     grill owns that and does it better.
   - `already spec'd` → hand off to `/task-runner:run` and stop.

If $ARGUMENTS is empty, ask for the one-line request first; there is nothing to detect
against and nothing to triage.

**What this command deliberately does not do:** clarifying question rounds, specs, task
cards, red-teams (all `taskmaster`), or executing a defined task list with scope lock and
verify loops (`task-runner`). It primes and triages. If it grows a pipeline it duplicates
two that already exist.
