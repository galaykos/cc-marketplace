# The taskmaster-suite reform council, 2026-08-28

**Standing: `recorded`.** Nothing reads this file back. The four changes it
records are enforced by the gates named against each; this document explains why
they were made and, more usefully, what was deliberately NOT made.

## What this was

Seven delegates audited the `taskmaster-suite` pipeline — all 31 dependencies,
both the contract it imposes on a user's codebase and the suite's own internals —
against four commissioned ends: better flow, cleaner code, minimum comments,
design patterns taken into account.

Charters live in `.claude/agents/council-*.md` (gitignored, like the existing
`distill-*` reviewers). Position papers are in `taskmaster-docs/council/positions/`
(gitignored working area, per the doc-location rule). Only this record is tracked.

The structure was three constraints, and each earned its place:

- **Blind.** No delegate saw another's position. Seven honest partisan reads
  beat one agent trying to be balanced and going vague.
- **Yield.** Each had to name the delegate whose territory outranked it on a
  question. This is why the record has no turf fights: the Architect yielded
  bundle economics to Product, the DBA yielded ORM idiom to PHP, Design yielded
  component logic to TypeScript. Every seat used it.
- **100 points.** Each allocated exactly 100 across its own motions, which
  converts seven wishlists into one ranking.

## What convergence bought

Four seats independently reached the same finding by four unrelated routes: the
plugin owning the commission's third end was not installable from the bundle
implementing it. The DBA found it hunting migration verifies, the Architect
measuring the deps directly, TypeScript tracing router rules, Design chasing a
CSS comment branch, PHP pricing docblock culture. None had seen the others.

That is what the blind structure is for. A single reviewer finds this once and it
reads as one opinion; five seats arriving from five directions makes it a fact
about the artifact rather than about the reviewer.

## Applied

Each was confirmed **at the source by the chair** before any edit — the delegate's
report was treated as a lead, never as evidence.

| Change | Seats | Standing |
|---|---|---|
| `verify-teeth-lint.sh`: PHP runners + `migration-run-only` check | DBA 25, PHP 30 | gate |
| `scope.sh`: path-boundary match | TypeScript 22 | gate |
| `taskmaster-suite`: `comment-discipline` dependency | 5 seats, incl. Product 24 | gate |
| `remind.sh`: name the off-ramp | Product 32 | recorded |
| `task-cards`: stamp `pattern-selection` on unit-creating cards | 4 seats | agent-graded |
| README: drop the removed-plugin Livewire claim | PHP 5 | recorded |

Two notes on how these were shaped, because the shaping mattered more than the
finding in both cases:

**verify-teeth.** `runner_re` knew twelve test runners and zero PHP ones, so
`pest`, `phpunit`, `php artisan test` and `composer test` all passed bare while
`npm test` blocked. The PHP delegate flagged that widening `runner_re` without
adding `--filter` to `named_re` would false-block every correctly-named Pest line
— a regression its own motion would have caused. Both landed in one change.
Migration runners got a *separate* check rather than joining `runner_re`: a
migration command is not a test runner, so `bare-suite-pass` would have misnamed
it, and CLAUDE.md warns that harnesses assert exact message strings. Harness
24 -> 34 cases.

**scope.sh.** Filed as a `.ts`/`.tsx` issue; the defect is language-agnostic. A
raw `startswith` made every allow entry a prefix of unrelated paths — `app/Models`
admitted `app/ModelsBackup/X.php`. Harness 10 -> 14 cases.

## Held back, deliberately

**Reviewer coverage for parallel/track leaves** (Architect 34 — the single
highest-pointed motion on the table — and TypeScript 20). Both delegates
described it accurately. The chair declined it anyway, and the reason is the
useful part of this record.

`reviewer-routing.md` does not omit this. It declares the gap, names it an
"Accepted MVP limitation", and ships bookkeeping — `review-skip.sh --exempt leaf`
— with the completion gate blocking any leaf card carrying neither a dispatch nor
an exemption. Adopting the motion means **overturning a documented decision that
already accounts for itself honestly**, not patching an oversight. That is a
different bar, it is argued on cost/benefit rather than on evidence of a defect,
and it is the user's call rather than a fix branch's.

The distinction generalises, and it is the thing worth keeping from this exercise:
*a gap a repo declares and books is not the same artifact as a gap it does not
know it has.* Both are gaps. Only the second is a defect. A council that ranks by
points alone cannot tell them apart — the top-pointed motion here was the one that
should not ship.

## Filed, not actioned

Real findings that need their own decision:

- **System Designer M1.** `pc_hook_timeout` scans `plugins/*/hooks/hooks.json`
  only. The repo's own `.claude/settings.json` hooks — `done-gate.sh` (Stop) and
  `authoring-guard.sh` (PostToolUse) — are outside its scope and **neither
  declares a timeout**. Confirmed. The delegate additionally measured the
  done-gate branch at 2m27s; the chair could not reproduce that (a `{}` payload
  hits the fallback branch, which is exactly the `pc_harness_payload` failure
  CLAUDE.md documents) and records it as the delegate's measurement, not a
  verified one.
- **System Designer M2.** `completion-gate.sh` instructs a blocked model to delete
  `active-run.json` — the gate's own sentinel — while `rv-consent` gates far
  smaller reductions.
- **Product M1's evidence.** `retirement-queue.sh` reports every one of 116
  shipped skills at `invoked: 0` across 23 sessions. Weak evidence about usage
  generally (one machine, and the repo that authors the pipeline rather than
  consumes it); strong evidence that in 23 recorded sessions the maintainers did
  not once run their own spine.
- **Product's ranking of the commission.** It ruled end #4 (design patterns)
  worth less than the other three and an honest sub-clause of end #2, on the
  grounds that a user cannot observe whether a pattern was "taken into account" —
  they observe the shape of the code. The wiring shipped because it was cheap;
  the ranking stands unresolved.

## Open questions

- Do `PostToolUse` hooks fire inside a subagent session? `scope.sh:15-17` and
  `task-executor.md` assume opposite answers. If they do not, the scope fix
  matters only on the inline path and the delegated scope story is prose-only.
  A probe was run and did not return a usable answer.
- Does an ask-tier `command-guard` verdict stall a headless `ultra-goal` run
  instead of halting with evidence? Conditions the DBA's M1 rollout.
- Symfony has zero routing coverage; `rules.tsv:99` is laravel-marker-gated.
