---
name: code-redteam
description: Use when a boosted (ultra/goal) run produced code and the diff must be red-teamed before trust — N=3 blind refuter panel plus completeness-critic over the SHIPPED code, not just spec/cards. Composes orchestration:verification-panels; single inline pass when panels unavailable.
---

# Code Red-Team

The ultra/goal boost red-teams the *input* — the spec and the task cards — hard, then
ships the *output* code unexamined. A card that verified green locally can still carry a
subtle defect the per-card verify never exercised. This skill closes that gap: it points
an independent adversarial panel at the produced diff, the same way `orchestration:ultra-assess`
red-teams its own findings before returning them.

It is deliberately thin. All panel mechanics live in `orchestration:verification-panels` —
this skill only supplies the target (the code diff), the lenses, and the reopen rule.

## What this skill composes — do not reimplement

Read `orchestration:verification-panels` and reuse it wholesale:

- **Refuter voting** — N independent skeptics, each told to REFUTE, diverse lenses.
- **Completeness-critic** — a closing pass asking only "what defect was never looked for?"
- **Loop-until-dry** — repeat rounds until two consecutive rounds surface nothing new, capped at 3 rounds whichever comes first (the cap is owned by that skill, not re-derived here).

Do NOT re-derive the voting, independence, or dedup discipline here. If you find yourself
writing panel logic, stop — it already exists in that skill and this one only wires it to
the produced code.

## The target: the produced code diff

The panel attacks code, not prose. Get the exact slice from the harness:

```
plugins/task-runner/scripts/code-redteam-diff.sh --base <base-ref> [--paths <glob>...]
```

`--base` prints `git diff <ref>..HEAD`. The base is INCREMENTAL: each milestone-boundary
pass uses `--base <previous-boundary-ref>` — the ref recorded when the previous boundary
pass ran (run-start for the first milestone) — so the panel attacks only the NEW
milestone's diff instead of re-reading code an earlier boundary already cleared. Record
`git rev-parse HEAD` at each boundary as the next pass's base. The single FINAL completion
pass keeps the run-start ref as its base — one whole-run backstop sweep so nothing slips
between boundaries or through a cross-milestone interaction. Scope with `--paths` when only
part of the tree was in play. Feed that diff, verbatim, to every refuter. Never let a
refuter reason about the spec instead of the code; the whole point is to examine the
deliverable the input-side red-team skipped.

## The N=3 refuter panel — diverse lenses

Spawn exactly three blind refuters over the diff, independent (no refuter sees another's
verdict), each handed the same diff but a DIFFERENT attack lens.

**Tier — the caller supplies it.** This skill never reads `00-INDEX.md`; the caller
(`task-execution`, or `track-orchestration` on the tracks path) passes the **already
resolved** `(model, effort)` in, so `auto` is resolved before it reaches here per
`task-execution/SKILL.md`'s resolution rule. Dispatch the refuters **and** the
completeness-critic with those values as `agent()` parameters: `model:` and `effort:` on
the `Workflow` panel path, `model:` **only** on the inline fallback below — the plain Agent
tool has **no effort knob** (`ultra/references/dispatch-tiers.md`). Absent a supplied tier,
run native rather than guessing.

The lenses:

1. **Correctness** — does this code do what the card claimed? Hunt off-by-one, wrong
   branch, unhandled return, broken invariant, silent data loss.
2. **Security** — injection, unvalidated input, secret exposure, unsafe deserialization,
   auth/authz gaps, path traversal in exactly these changed lines.
3. **Does-the-test-have-teeth** — would the verify command actually FAIL if the code were
   wrong? Hunt asserts that can't fire, mocks that swallow the real path, a test that
   passes against a deliberately broken implementation.

Each refuter is prompted to disprove the code's fitness, with "defect present" as the
tie-break when uncertain — the adversarial framing from verification-panels. Identical
lenses share blind spots; the three lenses above are chosen so a defect one lens is blind
to, another catches.

## Discovery, not majority vote

This is a DISCOVERY task, so the arithmetic is different from a single contested claim:

- **Any evidence-backed refuter defect is a finding.** A real defect surfaced by only 1 of
  the 3 refuters is NOT voted away — the other two were simply looking through a different
  lens. Absence of a second vote is not counter-evidence.
- **Majority voting applies only to adjudicating one contested claim** — when refuters
  disagree about whether a specific named defect is real, spawn a refuter round on THAT
  claim and let the majority-refute rule from verification-panels settle it.
- **Dedup against confirmed findings** every round, via the harness:

  ```
  ... | code-redteam-diff.sh --dedup <confirmed-findings-file>
  ```

  It removes any finding whose `file:line` plus normalized title already appears in the
  seen file, printing only novel findings. SEEN means seen — carry every confirmed finding
  forward so the loop converges instead of resurfacing the same defect each round.

## Confirmed findings reopen cards — fresh budget

A confirmed defect is not a note in a report; it reopens the specific card(s) whose code
carries it. Crucially, reopening grants a **fresh, bounded 3-cycle budget** — the reopened
card does NOT inherit the per-card cycle ceiling it already spent producing the defective
code. Red-team is a distinct phase; its findings buy a new bounded attempt, not a
zero-budget dead end. That fresh budget is itself capped at three cycles so no unbounded
loop opens: three failed fix cycles on the reopened card halts it with the evidence, same
as any other task.

Map each finding to the narrowest card that owns the touched lines; a finding that spans no
single card's scope is a new card, not a silent edit.

## Inline fallback — never a silent skip

If `orchestration:verification-panels` or the `Workflow` fan-out tool is unavailable
(headless, cron, or the opt-in gate is unmet), do NOT skip the red-team. Run one inline
single-agent code-redteam pass over the same diff from the harness: one agent walks the
three lenses in sequence, records evidence-backed defects, and dedups them via
`--dedup`. Less parallelism, same deliverable — a code red-team always runs, the run just
degrades to a single reader. A skipped red-team is a silent regression, never an option.

## When it fires

This pass is wired and active whenever `00-INDEX.md` carries an `Ultra:`/`Goal:` marker:
task-execution runs it at each milestone boundary with `--base <previous-boundary-ref>`
(only the new milestone's diff), and once before the completion gate with the run-start
ref as the whole-run backstop; track-orchestration runs it once on the merged branch. On a
non-boosted run it is a deliberate no-op — there is no marker, so no code red-team fires.

## Anti-patterns

- **Red-teaming the spec, shipping the code.** The input-side boost already attacks the
  spec; examining it again while the produced code goes unexamined repeats the exact gap.
- **Majority-voting a discovery finding away.** A 1-of-3 evidence-backed defect is a
  finding; only a single contested claim gets the majority-refute rule.
- **Dedup against confirmed only in memory.** Use the harness `--dedup` against the seen
  file so rejected-then-resurfaced defects don't spin the loop forever.
- **Reopening a card at zero budget.** A finding that reopens a card must grant a fresh
  bounded 3-cycle budget, not inherit the spent ceiling.
- **Silent skip on missing panels.** Fall back to the inline pass; never let "panels
  unavailable" mean "no red-team ran".
