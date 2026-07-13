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
   out-of-set edit reclaims the card.
5. Run the project's full check suite at the end, not only the per-card verify.
6. Defer rule: a mis-specified card (wrong file, impossible criterion, a decision you
   were not given) is **reported, not reinterpreted**.
7. Final message is data for the orchestrator: a completion table
   (task / status / verify command / evidence line) plus any parked items. No preamble
   prose, no file dumps.
