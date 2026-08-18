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
| Plugin hooks shipped | **39** (recount: `ls plugins/*/hooks/*.sh \| wc -l`) | |
| …stating a LIMITATION or Standing | **21** | |
| …checks enforcing that they do | **0** | the has-teeth convention is itself in the `recorded` tier |

`pc_marker_key` closed the specific defect. Nothing closed the condition that
produced it: a harness may still be written that tests only the payload shape the
host never sends.

## 6. Did the improvements work in the simulation?

Control vs distilled, one run per cell, four fixtures. **Not a demonstrated
improvement**, and the plan said in advance not to read a 1-run delta on
agent-graded measures as a result.

- Mechanism demonstrably fires: **4 blocking denies** plus 3 warn-lane firings from
  comment-discipline, and 3 `test-shape` reports, on `laravel-app` — 0 in every control
  run. (An earlier draft said "7 denies": that was the count of `looks like noise`
  messages across BOTH lanes, which inflated the blocking count by 75% in the one
  paragraph arguing the blocking mechanism fires. Recount:
  `grep -c 'permissionDecision\":\"deny' <debug.log>`.)
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
3. ~~**Reachability decision for `divergence.mjs`**~~ — **DONE 2026-08-17**,
   `plugins/ui-ux/hooks/palette-default.sh`. §6 is the evidence and it decided the
   design: the failure happened on a *bare prompt*, not a slash command, so adding
   a step to `/ui-ux:build` would not have caught it either. Only a PostToolUse
   hook reaches that path. Placed in ui-ux (10 bundles vs craft-layer's 4).

   Advisory, not a gate, and the reason is structural rather than cautious:
   craft-layer's `utility-palette` can demand a written waiver because a craft run
   has a contract to record one in; a bare edit has nowhere to record consent, so
   blocking would punish a legitimate violet brand with no way to say so.

   The cost is real and was accepted, not hidden: craft-layer shipped no
   PostToolUse hook, and this opens a dynamic channel that `context-budget.sh`
   scores at **0** because it probes with a synthetic `Edit` that is not a UI file.
   The one-shot-per-session bound is what stands in for a meter.
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

---

## 9. Adversarial audit, 2026-08-18 — what a clean reviewer found

A fresh Fable agent at xhigh effort, with none of this session's context, was asked
to **refute** this work. It ran the neuter-and-confirm-red test itself on four
checks and re-derived the simulation numbers. Its verdicts: **distilled — partial**;
**improvement — yes on the enforcement layer, unproven on generated output**. Both
match §1 and §6, which it called "accurate and mildly generous to itself."

It found seven defects. All were real. The three that mattered:

| Defect | Why it mattered | Fixed |
| --- | --- | --- |
| `pc_marker_key` caught only the one-step double-quoted form | It shipped the identical bug past the gate three ways — unquoted, two-step, `printf -v`. A gate against the *syntax of the commit that created it* is not a gate against the defect. | Rewritten as **taint tracking**: seed from the jq read, propagate through assignments, treat a hash or slash-strip as what CLEARS taint. All four forms now caught; 3 fixtures added. |
| `scripts/smoke/versioned-layout-tests.sh` was a live unblessed offender | It pipes `session_id`-only payloads into `route.sh` via `bash "$1/hooks/route.sh"`. `pc_harness_payload` could not follow a hook path through a variable — so **the very condition it was built to close was still open in the repo**, and §5's "exactly 2 offenders, derivation not convenience" was falsified. | Resolution widened to follow variable paths (then constrained to *unambiguous* hook filenames, because the first widening cross-matched `remind.sh` across five plugins and produced a false positive). Harness fixed. |
| `utility-palette` — a **gate** — passed `bg-[#6366f1]` while its PASS message asserted "no in-band arbitrary hex" | An inverted tier: the gate missed what the ui-ux **advisory** catches by literal list, and the in-file limitation claimed the named-utility path covered it, which is untrue — names are not hexes. | `DEFAULT_SWATCHES` set added; the false claim corrected; the PASS message no longer asserts more than it checked. |

Four lower-severity findings, all fixed: `test-shape.sh` flagged chai `should`-style
and ava/tape as assertion-free (whole correct dialects reported as proving nothing);
`pc_harness_payload` was satisfied by `transcript_path` appearing in a *comment*;
this review said "7 denies" where the log holds **4 denies + 3 warn-lane firings**,
inflating the blocking count 75% in the one paragraph arguing blocking works.

**And the finding that indicts this document.** §3 lists "recount recorded numbers,
never copy them" as a habit that did not distill. The auditor showed it did not
distill *here either*: CLAUDE.md's "20 plugins ship 28 harness files" was recounted
and accurate in this branch's **first** commit, then invalidated by this branch's
**own later commits** (now 21 / 30), and §5's hook counts had gone stale the same
way. The fix is not a third recount — it is that CLAUDE.md now carries the recount
*command* instead of the number, and this table cites `gate-coverage.sh`.

That is the honest summary of the whole exercise: **every mechanism held up under
adversarial execution; every prose number did not.**
