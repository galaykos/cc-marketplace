# CLAUDE.md incident log — how each number and claim in that file went wrong

`CLAUDE.md` is instructions for the model. Until 2026-09-22 about one sentence in seven
was the story of a past mistake the file had made about itself, clustered in the
enforcement sections a reader must act on. The rules stayed in `CLAUDE.md`; the
stories moved here. Add to this file, not to that one, when the next number rots.
**Standing: `recorded`** — nothing reads this back.

## The rule the incidents teach

Two files carrying one number is how they drift apart (`scripts/done-gate.sh:7`).
`CLAUDE.md` therefore carries one count on purpose — the CI step count, recounted by
the command beside it — and prints a recount command for every other quantity it
mentions. A check's derivation lives in the check's own header
(`scripts/lib/plugin-checks.sh`); the file cites headers and does not restate them.

## Incidents, by the paragraph that carried them

- **"Say what has teeth" adoption count.** The count of plugins carrying a
  `Standing:` line was wrong twice in two days, once within the same branch that
  wrote it. Replaced with a `grep … | wc -l` recount.
- **Gate derivations restated.** The "Plugin change gates" section used to restate
  each `pc_*` header, and described `pc_budget_crowding`'s ceiling as 150 lines four
  days after it had moved to 200. Replaced with a citation to the headers. On
  2026-09-22 the same section's "9-29 lines" header-size range was found false at both
  ends (4 and 71) and dropped.
- **Lane check count.** The `pc_lanes_*` count was wrong within a day of a check being
  added. Replaced with `grep -c '^pc_lanes_[a-z_]*() {'`.
- **"Run all four".** The pre-push list read as if the four scripts were all the
  enforcement; the smoke harnesses, plugin harnesses and host validator were not
  named. The "Every enforcement surface, by tier" section exists because of it.
- **CI step count.** Stale in both directions five times before the recount command
  was added beside it; the count is still carried because `done-gate.sh` reads it.
- **Smoke-step list.** The paragraph once named 20 steps and listed them; stale within
  two commits, and contradicted the sentence next to it. It carried a wrong count three
  times before it stopped carrying one. The CI glob over
  `plugins/*/scripts/__tests__/*.test.sh` is the right fix because a list here is not.
- **Advisory hook counted as enforcement.** `authoring-guard.sh` is fail-open and
  cannot block; listing it as enforcement was the tier over-claim the file's own
  convention forbids.
- **Unrouted skill count.** Recorded stale three times; replaced with the python
  one-liner recount.
- **Bundle table "not gated".** The remove-plugin paragraph asserted "nothing gates
  that table" for three weeks while the `generate.sh --check` paragraph above it said
  the opposite. `pc_version_stamp` carried the same inversion — described as a warning
  21 days after it started blocking. The lesson: a gate mis-tiered as toothless makes
  someone rebuild what exists.
- **Eval suites "all three".** "All three suites have now been executed" sat four
  lines under "Count it, don't quote a count" while five suites existed; dated on
  2026-09-22.
- **Turn-cost ledgers "empty in every project".** Measured false on 2026-09-01
  (records existed under the projects where plugins are used; the folded script had
  read only the current project) and left as doctrine for three weeks.
- **Chassis samples.** A `{{skillHome}}` key added to a template on 2026-08-25 passed
  all four gates and broke `chassis-template-tests.sh`, because `generate.sh` enriches
  manifests before rendering and the harness renders frozen fixtures raw. That case is
  still told in `CLAUDE.md` because it changes what a contributor must run.
- **`check-version-bumps.sh` reads HEAD.** A regenerated catalog was green locally and
  red in CI on 2026-09-15 because the change was uncommitted when the gate ran. Also
  still told in `CLAUDE.md`, for the same reason.

## 2026-10-28: history moved out of CLAUDE.md

`CLAUDE.md` went from 451 lines to under 200, written for a contributor's first day. Its
reference material (the escape-hatch markers, each gate script's details, the lane checks and
the enforcement tour) moved to the `repo-gates` project skill,
`.claude/skills/repo-gates/SKILL.md` and its `references/enforcement-tiers.md`. Its history moved
here, word for word. `…` marks where a quoted sentence's rule stayed live in `CLAUDE.md` or in
that skill. The two cases above still told in `CLAUDE.md` (chassis samples, HEAD) now keep only
their instruction there; their stories are below. Line numbers are the old file's.

### Eval suites (lines 38-75)

On CLI 2.1.270 the two suites shipping the `prompt.md` shape loaded zero cases
(`invalid case.yaml: graders: Required`) because their `graders/*.md` carried no
`type:` frontmatter — prose from line 1 — so two of the three shipped suites had
never run and nobody noticed, because nothing runs them in CI. Both were converted
to `case.yaml`. The shape itself is valid: a `prompt.md` beside a typed grader
loaded and scored on 2.1.273 (measured 2026-09-16,
`rationale/marketplace-trend-audit-2026-09-16.md` A1) …

**Standing of the eval surface itself: `recorded`, and now partly measured.** … The three
suites that existed on 2026-09-14 were executed with a
control arm on CLI 2.1.270 (suites added since have loaded but not run) — the numbers are in
`rationale/marketplace-endgame-review-2026-09-14.md` §8 wave D, where the one
NEGATIVE delta was WITHDRAWN a day later: it did not replicate. Read the amendment,
not the table above it. Nothing runs them in CI, which is how two dead suites
survived … Two rules that cost $10 to
learn and are cheap to read: …

[A case whose control arm passes] … including two written
specifically to be hard for the base model.

[Three runs] … The −1.00 above was three
runs agreeing; three more runs a day later disagreed. …

The consequence that matters: … — and the one time that was measured by
hand (`rationale/eval-ablation-2026-08-20.md`), the skill under test scored
**zero delta in every arm**.

### Project skills (lines 81-83)

… not a plugin: the authoring skills moved there 2026-09-03.

### The four laws (lines 103-107)

It was a shipped plugin until
2026-09-03; it is a tracked project skill now because the doctrine has one user,
this repository, and a plugin with one user is the Admission law's own
counter-example. … — that is a smaller reach than before, stated, not hidden.

### Say what has teeth (lines 121-122)

(Until 2026-09-03
it shipped as a plugin "because that one SHIPS"; it has one user, so it does not.)

### Header convention (lines 145-149)

(Why: the 2026-10-21
retro found incident narration in 13 of 16 shipped plugins it read, in files whose
installers have no `rationale/`.) … What follows is only what you need in hand while editing.

### Load the authoring skill (lines 155-157)

(Why: in
the three sessions the 2026-10-21 retro read, hooks and skills were edited with zero
Skill calls for any of these.)

### generate.sh renderers (lines 249-252)

The review-command template was retired
2026-09-22 (it rendered one file) and the suite-uninstall template 2026-09-26 with the
suites, taking the README bundle table and no-suite leaf list with it; the three
surviving renderers are worker agents, reminder hooks, boost hooks.

### check-version-bumps.sh reads HEAD (lines 306-310)

Measured 2026-09-15 — a `generate.sh --write`
regenerated stack-scan's scout catalog, the local pass was green because the change was
still uncommitted, and CI went red on the next push. This is the same "the gate you run and
the gate that breaks can read different inputs" lesson as the chassis-sample case below,
reached by a different route: there the INPUTS differ, here the REVISION does.

### Chassis samples (lines 312-325)

**The four are not sufficient, and here is the case that proves it.** On
2026-08-25 a change added a `{{skillHome}}` key to
`templates/review-command.md.tmpl` and did not update
`templates/samples/*.json`. All four scripts passed. `scripts/smoke/chassis-template-tests.sh`
— an unguarded CI step — went red, and the branch was pushed that way.

The reason is structural, not carelessness: `generate.sh` ENRICHES every chassis
manifest before rendering — `skillHome` is computed and injected by the script
(grep `skillHome` in `generate.sh`; a line number here went stale once already),
so `--check` never sees a manifest missing it, and no
`.chassis.json` on disk contains the key at all. The harness feeds the FROZEN
sample fixtures to the template engine raw, so those must carry every key
literally, and did not. …

### Every enforcement surface, by tier (lines 378-446)

The glob is the right fix precisely because a counted list here is not.

… because the pre-push loop above
skips exactly one file BY NAME, so the second such script silently spent real model
calls on anyone who followed the instruction.

… and age
missed the Astryx digest (49 days old, materially wrong after a 0.x minor).

… it absorbed `scripts/retirement-queue.sh` (deleted
2026-08-31: it defaulted to the current project, where neither ledger had records,
and answered with an empty table — the records existed in the projects where plugins
are used, which that default never read).

It has no bundle
branches: the suites were retired 2026-09-26 and no plugin may declare
`dependencies`.
