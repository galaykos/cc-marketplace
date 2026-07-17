# Per-card crew (`--crew`, main-runner only)

The `--crew` flag adds a per-card verify **crew** after a card's build verify passes:
the read-only reviewers run concurrently, then a sequential test-only authoring pass, then
an unconditional verify re-run and a fresh bounded fix loop. Everything runs in the **same
working tree on the same branch** — no worktrees, no snapshots, no classifier, no revert.
Only the main `/task-runner:run` orchestrator runs a crew; a delegated leaf never can.

## Trigger — `--crew` only

`--crew` is the **sole** switch. No hook, no `Ultra: true` marker, and no `ultra-task` /
`ultra-assess` run ever engages crew; a run without `--crew` behaves exactly as today.
Ultra touches crew **only** by escalating crew-agent model when `--crew` is already active
(§ Ultra). `--crew` is a bare boolean; `--crew=<value>` is a usage error.

## Order per eligible card

After the card's build verify passes:

1. **Reviewer pass** (concurrent, § Reviewer pass).
2. **Test-only authoring** if the card is test-eligible (§ Eligibility, § Authoring).
3. **Unconditional card-verify re-run** — the runner re-runs the card's exact verify
   command before the card may close, so a card never closes on a stale pre-crew result.
4. **Fresh bounded fix loop** if any reviewer blocker/major finding or failing authored
   test remains (§ Fix loop).

## Reviewer pass

The reviewer set (baseline `code-reviewer` + diff-content-gated `ui-ux` /
`architecture` reviewers + the tag-routed reviewer) resolves and primes exactly as in
`reviewer-routing.md` — this file does not duplicate that map. Crew changes only *how* they
are dispatched:

- **Read-only reviewers run in one concurrent batch** over the live card diff.
- **Any reviewer that holds the `Bash` tool** (e.g. `devops:devops-reviewer`, tools
  `Read, Grep, Bash`) is **excluded from the concurrent batch and run serially** — a Bash
  reviewer can write build artifacts into the shared tree, so it must not run concurrently
  with anything.
- The `security:security-review` **skill** (no agent) runs **inline** in the orchestrator
  after the batch joins.

## Authoring — test files only

If eligible, dispatch `testing:test-engineer` as a scope-locked worker (the per-card dispatch
procedure — arm scope, inject the discipline preamble, dispatch):

- **Inputs:** the card diff + a **required test-output location** — the repo's detected test
  convention, or a per-language default when no convention exists yet.
- **It authors new test files ONLY and never edits source.** If a test would require a
  source change (e.g. exporting a symbol for testability), it does **not** make it — it
  reports that as a coverage gap. The runner may add the seam later as a re-reviewed
  fix-loop source edit.
- It runs **only the tests it authored**, non-interactively (never the whole suite), and
  **returns the list of test files it created.**

### Hardened scope check on return

Enforce with the existing diff-vs-declared-files check (`routing.md:44-48`), hardened for
the fact that authored tests are **new, untracked** files:

- Enumerate `test-engineer`'s touched paths **including untracked additions**
  (`git status --porcelain`, not bare `git diff`).
- Every touched path must be a **newly-created file under the required output location.**
  A modified tracked file, a path outside the location, or any returned path that is not
  new → the existing **reclaim/reject** (the self-reported returned list is never trusted),
  logged in the run report.

## Fix loop (fresh 3-cycle)

The crew fix loop has its **own fresh 3-cycle budget**, independent of the build-phase
verify loop. Feeders: reviewer blocker/major findings (severity-normalized per
`reviewer-routing.md`) + failing **authored tests only** (run by the returned test-file
list — pre-existing suite failures never enter, since authored files are new) + a
`vacuous`/`invalid-control` **negative-control** on the post-fix diff. A runner
source fix here (including a testability seam a parked test needs) is within the card's
source scope and is **re-reviewed** each cycle. Per cycle: apply source fixes → re-run the
card's verify command + the authored tests + re-review (reviewers only, live diff) → on a
green verify, run the negative-control on the post-fix diff (`references/negative-control.md`,
same script and standard exemptions) so a fix-loop source edit cannot silently defang a
verify that had teeth pre-crew. The authored-test set is **frozen after authoring**
(`test-engineer` is not re-dispatched).

**Precedence at exhaustion, in order:**

```
0. card verify command RED, or a `vacuous`/`invalid-control` negative-control on the
                               post-fix diff → HALT the card (never close red or teeth-less),
                               regardless of the rest; control `isolation-halt` (exit 5) halts always
1. else live reviewer blocker/major → HALT the card (dominates tests)
2. else unsatisfied authored test   → remove it (case-level if the file has passing
                                       siblings, else the file — an allowed orchestrator
                                       edit, not a re-author), record a backlog line
                                       flagged "authored test unsatisfied — may be a real
                                       defect, triage", and CLOSE the card
```

Removal in branch 2 keeps the full-suite completion gate green.

## Eligibility — the test half

The reviewer half runs on every directly-dispatched card. The **test-authoring half** fires
only when **all** hold, else it is skipped silently (logged, never a failure):

- the card touches ≥1 **code source file**, decided by a declared code-extension allowlist —
  at least `.ts .tsx .js .jsx .py .go .rb .php .java .rs`; docs/config/manifests and
  ambiguous types (`.sql`, `.tf`, shell) are **not** source and do not make a card eligible;
- a test runner is detected;
- `testing:test-engineer` is **reachable** (runner present but plugin absent → skip the test
  half; never fall back to `task-executor` for authoring);
- the card is **not** `testing`-tagged (its deliverable is already tests).

## Leaf exclusion

Crew runs **only for cards the main orchestrator dispatches directly**. A card delegated as
a parallel-group leaf (`SKILL.md:86-87`) or a track leaf gets neither crew nor
reviewers — a leaf cannot dispatch sub-workers.

## Ultra

When `00-INDEX.md` carries `Ultra: true (model=<model>, effort=<effort>)`, crew agents
(reviewers + `test-engineer`) are dispatched with the `model:` override — excluding
`opinion-lens`, which is not in the crew. The Agent tool has no effort parameter, so inline
dispatch escalates model only; the inline `security-review` skill runs at session model.

## Accepted risks

- **R1** — authored tests execute unreviewed in the completion gate. Accepted: first-party
  `test-engineer`, additive test files only; the residual risk is test quality; logged.
- **R2** — a parked failing authored test may have caught a real defect. Accepted: surfaced
  on the flagged backlog line; the card independently passed its own acceptance verify.
- **R3** — best-effort runner detection may false-positive. Accepted: `test-engineer` runs
  only its own new tests, bounding the blast radius; logged.
- **R4** — crew tests may overlap a downstream `testing` card. Accepted: logged; no de-dup.
