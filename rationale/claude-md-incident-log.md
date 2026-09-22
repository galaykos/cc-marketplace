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
