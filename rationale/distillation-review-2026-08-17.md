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

**The sharpest instance — since CLOSED, see §7 item 1.**
`plugins/claude-authoring/skills/authoring-hooks/SKILL.md` is the shipped artifact
whose job is teaching people to write hooks. As measured on the morning of
2026-08-17:

- mentions of `transcript_path` or the context key: **0**
- mentions of proving a gate fails / demonstrated-failing fixtures: **0**

The lesson that cost three simultaneous live defects was absent from the artifact
that exists to teach exactly that. It now carries a `## One-shot state` section
and a worked-case reference. Note what that cost and what it did NOT buy: +18
always-on tokens, and the rule is still **agent-graded** outside this repo —
nothing there runs `pc_marker_key`, so the skill is a checklist a reader chooses
to apply. Inside this repo the same three rules are gates. Same words, two
different standings, and conflating them would be the tier over-claim this
marketplace's own convention forbids.

## 5. Measured conditions that make recurrence likely

Not opinions — counts taken 2026-08-17 on this branch:

| Condition | Count | Why it matters |
| --- | --- | --- |
| `pc_*` author-time checks defined | **21** | |
| …that any harness exercises | **18** | **CORRECTED 2026-08-17.** This row first read "2 harnesses, so ~14 never watched fail" — arrived at by counting harness FILES rather than tracing which checks each file exercises. `rules-overlap-tests.sh` alone covers six. The real figure is **3 uncovered**: `pc_doc_location`, `pc_phase_guard`, `pc_version_stamp`. Recount with `scripts/gate-coverage.sh`; do not copy this number either. |
| Smoke harnesses under `scripts/smoke/` | **20** | |
| …that send `transcript_path` | **7 → 9** | **CLOSED 2026-08-17 by `pc_harness_payload`** (§7 item 2). Of 15 payload-building harnesses, 6 already complied, 7 exercise hooks with no context key so the field would be ceremony, and exactly **2 were real offenders** — `code-review/conventions-hook.test.sh` and `security/write-scan.test.sh`. Both fixed rather than blessed. |
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

1. ~~**Move the context-key lesson into `authoring-hooks`**~~ — **DONE
   2026-08-17.** A `## One-shot state` section (four rules) plus
   `references/one-shot-state.md` carrying the worked case: the exact marker path
   that could not be written, why a failed write turns a *blocking* gate off, the
   same line's three different symptoms, and why the suite stayed green. The
   skill's description now names one-shot state and payload testing so it routes
   on the failure it teaches. This is the only item here that reaches anyone
   outside this repo. Cost, paid deliberately: **+18 always-on tokens** and the
   SKILL body at exactly 150/150 against its ceiling — which is why the worked
   case is a reference and not prose in the body.
2. ~~**`pc_harness_payload`**~~ — **DONE 2026-08-17.** Fails a harness that
   exercises a context-keyed hook while sending only `session_id`. Scoped by
   resolving each harness to the hooks it actually exercises, so the 7 harnesses
   whose hooks never read the key are out of scope rather than blessed — a gate
   that must be waived seven times to catch two is one people route around.
   Both real offenders were fixed, not blessed. 6 fixture cases in
   `marker-key-tests.sh`, including the false-positive and out-of-scope guards.
   Writing it surfaced a bug in its own test: the first `write-scan` fixture used
   content matching none of that hook's five patterns, so the hook was correct to
   stay silent and the test was wrong — and a sibling assertion (`find` for any
   lock dir) passed on locks left by earlier cases, proving nothing. Both fixed.
3. **Reachability decision for `divergence.mjs`.** Section 6 is the evidence: the
   gate cannot catch what it never runs on, and `/ui-ux:build` is by ui-ux's own
   `build.md:75` the most reachable UI entry point here.
4. ~~**A harness-coverage report for `pc_*` checks**~~ — **DONE 2026-08-17**,
   `scripts/gate-coverage.sh`. Maintainer path, always exits 0. Running it
   immediately falsified this review's own "~14" (see §5) — which is the argument
   for shipping a script instead of a number: a recorded count is a measurement
   someone will trust and nobody will recompute. It over-reports by design —
   "covered" means a harness names the function, not that any assertion watches it
   fail — so a NONE is certain and a hit is only probable.

   **The three with NONE are left uncovered deliberately, not overlooked.**
   `pc_phase_guard` has a natural home (`lanes-tests.sh`, its documented family)
   and is the one worth doing next. `pc_doc_location` and `pc_version_stamp` have
   no topical harness, and forcing them into an ill-fitting one buys a green tick
   rather than a caught defect. Naming which three, and why each is where it is,
   is the deliverable — not driving the number to zero.

## 8. Honest limitation of this review

It counts artifacts and greps for strings. It cannot show that a rule written into
a shipped skill is actually *followed* — that is agent-graded, with real variance,
and the only way to know is a control/treatment run like section 6, which at n=1
per cell was not decisive. Two of the four habits in section 3 may also simply be
model behaviour rather than anything this marketplace can install; distinguishing
those needs a run where the same model works with and without the artifact, which
has not been done.
