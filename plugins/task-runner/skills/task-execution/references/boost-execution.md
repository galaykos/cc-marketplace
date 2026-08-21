# Extreme Boost at execution time

Read this when `00-INDEX.md` carries an `Ultra: true` or `Goal: true` marker. On a
standard run none of it applies, which is why it left the SKILL body on
2026-08-20: it was ~1.9 kB of the body's 11.9 kB, on lines of 150-530 characters,
loaded on every card execution including the unboosted ones.

## The rules

**Extreme Boost:** when `00-INDEX.md` carries an `Ultra: true` or `Goal: true` marker, dispatch the reviewer, delegated worker, and **code-redteam** panel agents with the
resolved `model:` override — excluding `opinion-lens` — so the boost reaches execution even in a fresh session; code-redteam never reads the index itself, so pass it the
resolved `(model, effort)`. A batch carries no tier override of its own — it dispatches like any other card (`references/routing.md` § Batch dispatch). Read BOTH markers:
tier from `Ultra:` when present, ELSE from `Goal:` (a lone `Goal:` still escalates workers — goal implies the boost); the autonomy axis comes from `Goal:`. A trailing
`(model=…, effort=…)` sets the tier — `model=auto` resolves HERE, to the executing session's model or opus, whichever is higher (haiku<sonnet<opus<fable); a malformed one
falls to the marker's legacy default (`Ultra:`→opus/xhigh, `Goal:`→opus/xhigh). Announce the tier once at run start, boosted or not: `⚡ Ultra run — workers
model=<marker-model>→<resolved>, effort=<effort>` / `▷ Standard run — workers inherit the session model (<model>) · effort: <effort>` (standard `<effort>` =
`$CLAUDE_EFFORT` when the harness exposes it — `echo ${CLAUDE_EFFORT:-inherit}` — else the literal `inherit`). The Agent tool escalates model only (marker `effort`
applies on the `Workflow` path). Delegated stack implementers also get delegation-contracts § Skill priming (resolve+inject `Read <abs-path>` per `Skills to apply`).
Under the marker, ALSO run the **code-redteam** pass (its skill) over the produced diff — at each serial milestone boundary and once before completion (in `--tracks`:
once on the merged branch) — routing confirmed findings to reopen the targeted card under a fresh budget. **Under `Goal:`** (hands-off): auto-take pipeline gates — the
run-plan preview is DISPLAYED, then execution proceeds without waiting; post-run "Retry parked" is bounded to at most ONE auto-retry, and only on forward progress (a task
moved parked→done), else surface the parked list and stop. Halt-with-evidence, mis-specified-task halts, and the full-suite completion gate are UNCHANGED and NEVER
suppressed under Goal.

## Why it lives here and not in the `ultra` skill

`taskmaster:ultra` owns the boost CONTRACT — what a boosted run promises. This
file is the execution-side binding: which dispatches carry the resolved tier, what
a malformed marker falls back to, and what Goal mode may auto-take. Two different
questions, and the runner must answer the second without loading the first.
