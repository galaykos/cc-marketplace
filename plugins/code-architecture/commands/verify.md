---
description: Verify completed work against success criteria with evidence
argument-hint: [task-or-change]
---

Invoke the work-verification skill from this plugin to verify $ARGUMENTS (the task or change
described there, or the current uncommitted work if no argument is given). Steps:

1. Invoke the work-verification skill and follow its evidence-before-assertion discipline.
2. Identify or restate the success criteria for the work (tests, lint, type-check, manual
   checks) — if none were defined up front, state that and derive reasonable ones from the
   project's conventions (e.g., its test and lint scripts).
3. Run the project's actual test and lint commands (and any other relevant checks, such as a
   build or type-check step). Do not assume — run them.
4. Report pass/fail for each criterion with the exact command and its actual output, per the
   exact-command + expected-output discipline. Include failures and warnings, not just passes.
5. If something fails, report it plainly and stop short of claiming the work is done.

6. If any criterion failed, ask via AskUserQuestion: "Fix the failing checks
   now (Recommended)" / "Stop here — report only". On fix, address the
   failures and re-run this verification. Headless: report only.
