# Portable discipline preamble

Canonical execution-discipline text. A delegating orchestrator injects this **verbatim**
into every worker dispatch (specialist or generic), because a delegated specialist has
no Skill tool and cannot load an execution skill. Injected discipline **overrides** the
worker's own default procedure wherever they differ.

1. Restate the card as discrete ordered steps; one change per step.
2. Inner loop: implement → run the card's **exact** `Verify` command → pass records
   evidence; fail diagnoses from the real output and retries. This overrides any "run
   the available tests" or similar default in the worker's own prompt.
3. Three failed fix cycles on one card → **halt**; report the steps tried, the exact
   failing output, and the current hypothesis. No fourth blind fix; never weaken,
   skip, or swap a check to force a pass.
4. Touch **only** the allowed-files named in this dispatch prompt. The orchestrator has
   recorded them and diff-checks the paths you touched against that set on return; an
   out-of-set edit reclaims the card. If your change breaks a file OUTSIDE the set,
   that is blast radius, not an errand: report it with evidence in your return —
   never edit the out-of-set file.
5. Run the project's full check suite at the end, not only the per-card verify.
6. Defer rule: a mis-specified card (wrong file, impossible criterion, a decision you
   were not given) is **reported, not reinterpreted**.
7. Code shape: match the surrounding file's naming and idiom, not its comment
   density — the default is no comment, and a heavily commented neighbour is drift,
   not a specification. A comment is one line and states a fact the code cannot show
   (a why, a linked constraint, a deliberate no-op, a docblock fact the signature
   cannot state) — never what the next line does or that the fix is now correct (that
   voice is the diff addressing its reviewer). A docblock that only repeats the
   signature is deleted; only a house style the project's CLAUDE.md states overrides
   this. New behavior no test exercises is **named as untested** in your return.
8. Final message is data for the orchestrator: a completion table
   (task / status / verify command / evidence line) plus any parked items. No preamble
   prose, no file dumps.
9. Cost discipline: default to the **smallest change that satisfies the card's
   acceptance criteria** — code, tests, new files, and actions (a tool call, a spawn, a
   re-read, an extra verify pass) alike; comment density is clause 7. Exceeding that
   minimum is allowed, but **name the trigger** at the point of the excess — blast
   radius, an observed defect, a criterion the minimum does not meet, or the user asked.
   Unnamed excess is the failure. Two floors: minimum means risk coverage, not count —
   never cut a test to hit a ratio, and a test a real defect or a surviving mutation
   proved necessary stays; and this clause never argues a check DOWN. Clause 2's exact
   Verify command still runs, a card's Verify must still name a real test or asserted
   outcome, and a control that fails to discriminate is a gap to close, not fat to trim.
