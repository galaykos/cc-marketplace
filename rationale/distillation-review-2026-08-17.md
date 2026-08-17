# Did the distillation encode the habits, or only the artifacts?

Review of the 2026-08-17 quality-distillation run (branch `worktree-quality-distill`),
against the question that prompted it: were the improvements really made, and will
they keep working?

Placed in `rationale/` rather than `taskmaster-docs/` deliberately. The finding
below is that process knowledge from this run landed in gitignored or repo-local
files; writing the review of that failure into a gitignored file would repeat it.

---

## 1. Verdict in one line

**The artifacts were distilled. Most of the habits were not.** Four concrete
defects are fixed and mechanically defended. The reasoning that FOUND them is
recorded in files that either do not ship or do not survive a clone.

---

## 2. What will keep working without anyone remembering (enforced)

| Artifact | Standing | What defends it |
| --- | --- | --- |
| `scan.sh` / `density.sh` / `route.sh` context keys hashed | gate | `pc_marker_key` fails the build if reintroduced |
| `pc_marker_key` itself | gate | `marker-key-tests.sh`, 9 cases, wired as its own CI step |
| Three harnesses now send the real payload | gate | each case was checked to FAIL against the unfixed hook before being kept |
| `test-shape.sh` | advisory | `test-shape.test.sh`, 14 cases, picked up by the shared `plugins/*/scripts/__tests__/*.test.sh` glob |
| `utility-palette` / `utility-font` | gate | 3 fixtures in `craft-gates.test.sh`, incl. a false-positive guard |

These are real. Each was neutered on purpose and the harness went red, so none of
them is a check that returns 0 unconditionally.

## 3. What happened once and is not encoded anywhere that runs

| Habit exercised this run | Where it ended up | Will it recur? |
| --- | --- | --- |
| **Audit before building** — the premise "nothing detects the sameness fingerprint" was wrong; ~10 assertions already existed. Same for "test proportion is measured" (it was prose). | `taskmaster-docs/` — **gitignored** | No |
| **Verify a reported finding by execution before acting** — the audit's claim contradicted live session evidence; running the hook both ways showed both were right, on different versions | nowhere | No |
| **Do not invent a threshold** — the ad-hoc scope counter was refused because its number would have been guessed | `taskmaster-docs/` — **gitignored** | No |
| **Correct a measurement that lies** — the first scorer produced three false negatives on idiomatic code and was restructured into counted-vs-read tiers | `cc-market-test/score.sh` — **outside the repo entirely** | No |
| **Recount recorded numbers, never copy them** — CLAUDE.md's CI figures were stale in both directions | `CLAUDE.md` — tracked, but repo-local | For contributors here only |

## 4. The structural problem, in the repo's own words

`CLAUDE.md:50` already states the rule this run broke:

> the canonical statement lives in the `claude-authoring` plugin … **because that
> one SHIPS** — a convention that exists only in this file reaches contributors to
> this repo and nobody who installs from it.

Measured against that rule, this run's process knowledge went to the two worst
places available: `taskmaster-docs/` (gitignored — so "written down" means deleted
on clone) and `CLAUDE.md` (repo-local — invisible to anyone installing a plugin).

**The sharpest instance:** `plugins/claude-authoring/skills/authoring-hooks/SKILL.md`
is the shipped artifact whose job is teaching people to write hooks. Measured:

- mentions of `transcript_path` or the context key: **0**
- mentions of proving a gate fails / demonstrated-failing fixtures: **0**

The lesson that cost three simultaneous live defects is absent from the artifact
that exists to teach exactly that.

## 5. Measured conditions that make recurrence likely

Not opinions — counts taken 2026-08-17 on this branch:

| Condition | Count | Why it matters |
| --- | --- | --- |
| `pc_*` author-time checks defined | **20** | |
| …that any harness exercises | **2** (`lanes` covers 5, `marker-key` covers 1) | ~14 checks have never been watched fail. Each is indistinguishable from `return 0`. |
| Smoke harnesses under `scripts/smoke/` | **20** | |
| …that send `transcript_path` | **7** | 13 still exercise only the fallback branch — the exact hole that hid this bug for a whole release |
| Plugin hooks shipped | **38** | |
| …stating a LIMITATION or Standing | **20** | |
| …checks enforcing that they do | **0** | the has-teeth convention is itself in the `recorded` tier |

`pc_marker_key` closed the specific defect. Nothing closed the condition that
produced it: a harness may still be written that tests only the payload shape the
host never sends.

## 6. Did the improvements work in the simulation?

Control vs distilled, one run per cell, four fixtures. **Not a demonstrated
improvement**, and the plan said in advance not to read a 1-run delta on
agent-graded measures as a result.

- Mechanism demonstrably fires: 7 comment-discipline denies and 3 `test-shape`
  reports on `laravel-app`, 0 in every control run.
- Where it fired hardest, the intended effect appeared: laravel comment lines
  77 → 36.
- Measures otherwise moved both directions (tests −64% on react, +364% on
  tanstack; file count rose on all four, against the lean goal).
- **One clear regression:** the distilled arm introduced 23 indigo utilities
  across 5 Blade views where control used none — and `utility-palette`, written
  in this very run to catch that, never ran, because `divergence.mjs` is invoked
  only by `/craft-layer:audit` and `/craft-layer:craft`. The simulation confirmed
  the reachability residual instead of the fix.

## 7. What would actually encode the habits

Ordered by leverage, smallest first. None of these is built yet.

1. **Move the context-key lesson into `authoring-hooks`** (a shipped skill). It is
   the one artifact that reaches hook authors outside this repo, and it is silent
   on the failure that cost three defects.
2. **`pc_harness_payload`** — fail a smoke harness that builds a hook payload with
   `session_id` and no `transcript_path`, unless blessed. This closes the
   *condition*, where `pc_marker_key` only closed the instance.
3. **Reachability decision for `divergence.mjs`.** Section 6 is the evidence: the
   gate cannot catch what it never runs on, and `/ui-ux:build` is by ui-ux's own
   `build.md:75` the most reachable UI entry point here.
4. **A harness-coverage report for `pc_*` checks** — name the ~14 with no fixture.
   Report, not gate: some are structural and a fixture would be ceremony.

## 8. Honest limitation of this review

It counts artifacts and greps for strings. It cannot show that a rule written into
a shipped skill is actually *followed* — that is agent-graded, with real variance,
and the only way to know is a control/treatment run like section 6, which at n=1
per cell was not decisive. Two of the four habits in section 3 may also simply be
model behaviour rather than anything this marketplace can install; distinguishing
those needs a run where the same model works with and without the artifact, which
has not been done.
