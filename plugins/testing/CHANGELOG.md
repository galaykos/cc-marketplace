# Changelog

All notable changes to the testing plugin.

Started at 0.8.0, the release that added this plugin's first hook. Earlier
versions have no entries rather than invented ones — a backfilled history in the
file whose job is history is worse than an honest starting point.

## 0.11.0

### Fixed
- **`test-shape` detected nothing in Python, Go or Ruby.** The path glob admitted `*_test.py`, `*_test.go` and `*_spec.rb`; the block-opener vocabulary matched only JS and PHP, so all three found zero test blocks and the hook stayed silent — the same output a clean file produces, which is why nobody noticed. `is_opener()` now reads `def test…`, `func Test…` and RSpec's paren-less `it "…" do`, and the assertion vocabulary gains pytest's bare `assert` statement, Go's `t.Error`/`t.Fatal` and testify's `require.`/`assert.`, and RSpec's `expect { }`/`is_expected`/`should` forms. Declared skips in those languages live in the block BODY or on the decorator line above rather than on the opener, so exclusions are now tested against every line of a block; Go's `TestMain` is excluded outright. The header's LIMITATION section now separates the two vocabularies and says which failure each produces — a missing OPENER dialect reads as *no test file*, a missing ASSERTION dialect reads as assertion-free — and names the dialects still absent (JUnit, Rust, C++, Elixir).
- **`protect-tests` let every paren-less Ruby skip through.** `xit "adds" do`, `pending "…"` and a bare `skip "…"` are how RSpec, minitest and bats spell a skip, and every Ruby arm of the matcher required a `(`. They deny now when followed by a quote; `items.skip 2` still does not, and the same-line-reason escape still clears them.
- **A payload `cwd` that no longer exists is no longer rebuilt.** `test-shape` ran `mkdir -p` on it, recreating a deleted project tree to hold its own state file. It now requires `[ -d "$cwd" ]` and resolves its state dir through `git rev-parse --show-toplevel`, so one repository gets one bound instead of one per working directory.

## 0.10.3

### Fixed
- **`flake-hunt --help` documented a class the script never emits.** Its header taught
  `leaky` ("passes alone, fails in the full suite") as the third shape, while the script
  classifies into `BROKEN` / `NON-DETERMINISTIC` / `ORDER-DEPENDENT` — the same
  invented-taxonomy defect 0.8.3 fixed in the README, still live in the file `--help`
  prints. A user reading `--help` looked for a class no run can produce.
- **The no-shuffle hint gave the opposite pytest flag to the command's own table.** The
  script suggested `"-p no:randomly" inverted`, which DISABLES randomization;
  `/testing:flake-hunt`'s runner table says `-p randomly`. The script now matches the table.
- `--update-baseline` is a real flag and was documented nowhere. The README row and the
  command's `argument-hint` now name it, alongside what `--baseline FILE` actually does
  (exit 2 only on a flake that is not already in the file).

## 0.10.2

### Changed
- **`protect-tests` is now declared in `lane.tsv`.** It can deny a tool call, and until now the marketplace's territory gate could not see it — 14 hooks could return a permission verdict and only 3 were declared.

## 0.10.1

### Fixed
- **`protect-tests` denied ordinary code in two languages it deliberately covers.** An
  unanchored `.skip(` matched `list.stream().skip(1)` in a `*Test.java` and
  `items.iter().skip(2)` in a `*_test.rs`; a first fix that allowed trailing letters
  after the keyword still matched `iter` inside `items.iter()`. The pattern now requires
  a word-bounded test keyword (`it`, `test`, `describe`, `context`, …) with optional
  chained calls, which still catches `it.each([1]).skip(`.
- **The documented escape hatch failed when it was used.** A reasoned new skip was
  denied if the same hunk carried a pre-existing unreasoned marker through unchanged,
  because every marker line in the new text was judged rather than only the added ones.
- The README documents the hook, its standing and `CC_PROTECT_TESTS`; the 0.10.0
  changelog section was duplicated.
## 0.10.0

### Added
- **`protect-tests`, a PreToolUse guard against fake green.** It denies an edit that
  adds a skip or exclusive marker to a test file with no reason on the same line
  (`.skip`, `.only`, `.todo`, `xit`, `xdescribe`, `@pytest.mark.skip`,
  `markTestSkipped`, `t.Skip(`, `#[ignore]`, `@Disabled`, `@Ignore`), and an edit that
  rewrites a test file into one with no tests left. Skipping the failing test is the
  best-documented way a run reports success it did not earn, and it is invisible in a
  summary: the suite passes and the count quietly drops. The reason requirement is the
  whole mechanism — a quarantined flake has one (`it.skip('…') // skip: flaky on CI,
  #1421`, which this allows), a fake-green skip does not. It does not catch a test
  weakened rather than skipped; that stays agent-graded. `CC_PROTECT_TESTS=off`
  disables it; `scripts/__tests__/protect-tests.test.sh` drives 24 cases — including
  the regression a branch review caught before merge: an unanchored `.skip(` matched
  `list.stream().skip(1)` in Java and `items.iter().skip(2)` in Rust, denying ordinary
  edits in two languages this hook deliberately covers.

### Removed
- **`/testing:review` is retired.** `/code-review:review` loads `testing-best-practices`
  for any diff touching tests or untested production code, in one pass with every other
  matching rubric — the fan-in this command handed its whole scope to anyway. The rubric
  did not change; one listing entry did. `/testing:flake-hunt` stays: it runs a suite
  repeatedly and classifies failures, which no fan-in does.

## 0.9.2

### Changed
- **`.claude/testing/` ignores itself.** The directory now writes a self-ignoring `.gitignore` (`*`) the first time a hook creates it. Plugin state under the user's `.claude/` showed up as untracked in `git status` in every repo without a hand-written ignore line — observed live, and named by overseer's acceptance protocol as "other plugins' scratch" — one `git add -A` away from being committed. One harness assertion per plugin. (`hooks/test-shape.sh`.)
- A header comment no longer cites the removed `lean` plugin's hook. No behaviour change.

## 0.9.1

- `README.md` and the `hooks/test-shape.sh` header no longer point at the `lean` plugin's
  `cost-model` skill as a live source — that plugin was removed from the marketplace on
  2026-09-14; `testing-best-practices/references/proportionality.md` carries the same
  refusal of a count/ratio threshold. No behaviour change.

## 0.9.0

### Added
- `testing-best-practices/references/clock.md` — the clock as an injected boundary
  and what each global freeze does NOT reach (`Carbon::setTestNow` vs `time()`, the DB's
  own `CURRENT_TIMESTAMP`; Vitest fake timers vs `queueMicrotask`, and `waitFor` not
  detecting them), per-test teardown, DST / month-end / leap-day / ISO-week / epoch
  boundaries as named fixtures, why `sleep` is never a synchronisation primitive and
  the replacement per wait shape, TTL assertions at T−1 / T / T+1 with whole-second
  freezes, and CI zone pinning plus the hostile-zone second run. Cited from the
  "Determinism" section in one line; loaded only when the skill fires. Written from
  training knowledge, not a live re-read — its stamp says so.

## 0.8.10

### Changed
- Citations of the four-laws / has-teeth doctrine now point at
  `.claude/skills/authoring-skills/SKILL.md` in the marketplace repository — the
  authoring plugin was demoted to a tracked project skill on 2026-09-03. Prose only;
  no behaviour change.

## 0.8.9

### Changed
- `lane.tsv` rows for this plugin's chassis-generated artifacts are now rendered by
  `scripts/generate.sh` from `lane` keys on its `.chassis.json` objects (a
  `# generated:start` … `# generated:end` block) instead of being typed by hand —
  same territory, trigger and yields_to; `generate.sh --check` fails if the two drift.
  `/testing:review` had no lane row before: it now declares `test-code-review`
  (phase review, yields to `code-review:code-reviewer`) — a new row, not a lift.
  No behaviour change for a user of the plugin.

## 0.8.8

### Changed
- **Worker agents default to no comment.** The "Code shape" section no longer says
  "match the surrounding file's comment density". The default is no comment; a comment
  is one line for a fact the code cannot show, a docblock that repeats the signature is
  deleted, and only a house style stated in the project's CLAUDE.md overrides it. The
  matching hooks (deny lanes and the 0.4:1 ceiling) ship in code-review.

## 0.8.7

### Changed
- **`tdd` names the tautology tell and the seam rule.** A test whose assertion
  recomputes the expected value the way the code does passes by construction and
  red-before-green never catches it; expected values come from an independent source.
  The test list now names the seam each behavior is tested at, confirmed with the
  user in ad-hoc work and taken from the card's `Verify` line in a taskmaster run.
  Both drawn from a 2026-09-02 review of mattpocock/skills; unmeasured.

## 0.8.6

### Fixed
- **The flaky-cause → fix mapping is restored.** `d69678a` compressed six sections
  to stay at the 150-line ceiling and its message claimed "no rule was dropped";
  four things went, and this was the substantive one — the only text pairing each of
  the five root causes with its remedy (frozen clock, msw or `Http::fake`, per-test
  state, shuffled order, auto-waiting assertions). Also restored: "animation and"
  render races in the cause list, "not a better mocking library" as the rebuttal to
  the obvious wrong response, and "rather than waiting them out".

## 0.8.5

### Changed
- **Every hook entry now declares a `timeout`.** `test-shape.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.8.4

### Changed
- **`test-engineer` regenerated from the shared worker template**: reviewer
  findings are now confirmed against the code before any change lands — the
  template previously forbade re-opening the review without distinguishing
  verification of the finding from re-litigation of it.

## 0.8.3

### Fixed
- The `/testing:flake-hunt` row added to the README in 0.8.2 described a command
  that does not exist: it advertised `[files-or-diff]` when the script takes
  `[--runs N] [--shuffle "<flag>"] [--baseline FILE]` and exits 3 on a bare path,
  and it invented a four-class taxonomy ("order dependence, shared state, timing,
  isolation-halt") where the command classifies into three (order-dependent /
  non-deterministic / broken). "isolation-halt" appeared nowhere else in the
  plugin. A user following that row got exit 3 and never saw the listed classes.

## 0.8.2

### Fixed
- The README Commands table and the plugin.json description both omitted
  `/testing:flake-hunt`, which has shipped since 2026-08-02 with its own script
  and CI harness. A user reading either surface could not discover it. Both now
  name it.

## 0.8.1

### Fixed
- **The assertion vocabulary missed whole dialects**, so correct tests were reported
  as "no assertion: the block runs code and proves nothing" — chai should-style
  (`user.name.should.equal(...)`) and ava/tape/node:test (`t.is`, `t.throws`). The
  hook's own LIMITATION admitted only the narrower project-helper case, so the
  residual as written was smaller than the real one. Found by an adversarial audit
  on 2026-08-18. Both dialects added, two silence fixtures pin them, and the
  limitation now says plainly that a dialect absent from the list reads as
  assertion-free and the fix is to add it — not to widen to any function call.

## 0.8.0

### Added
- **`hooks/test-shape.sh`** — a `PostToolUse` advisory that reads a written test
  file's **body**. Until now nothing in this marketplace did: every mechanism
  touching test redundancy read a surrogate instead — the card's Verify line as
  text, the runner's collected count (which only reports at zero), the
  comment:code ratio, or a reviewer's judgment of prose, whose own reference file
  opens "Standing: agent-graded. No script measures this." A suite of twenty
  assertion-free blocks therefore passed every gate the repo ships, and each gate
  was correct to pass it.

  It names three shapes at a `path:line`, each a text fact rather than a judgment:
  a test block with no assertion token; three or more blocks that are identical
  once digit runs and quoted strings are blanked; and a block reaching a
  non-public member by reflection. At most 4 findings per file and 3 files per
  context, keyed on the transcript so a subagent gets its own budget.

  **Standing: advisory** — `additionalContext` is not a blocking key and the hook
  exits 0 on every path. There is deliberately **no** test-count or test:code
  ratio threshold: `lean`'s `cost-model` skill and
  `testing-best-practices/references/proportionality.md` both refuse one on the
  record, because there is no correct ratio — a number fires on legitimately
  dense work and waves through a bloated suite sitting under it. Naming a
  specific shape at a line is a different claim from scoring a count.

  Silence with `CC_TEST_SHAPE=off`, or `CC_REMIND=off` for every advisory nudge
  in this marketplace.

  Known gaps, stated in the hook header rather than left for a reader to find: it
  cannot see test count growing faster than behaviour count (one file, no diff —
  that stays agent-graded); it cannot see the same rule proved at three layers,
  because those blocks live in different files and each asserts something real;
  an assertion hidden in a helper named neither `assert` nor `expect` reads as
  assertion-free; and its own token cost is unmetered, because
  `scripts/context-budget.sh` measures the dynamic channel with a synthetic
  `Edit` that never targets a test path.

- **`scripts/__tests__/test-shape.test.sh`** — 14 cases, picked up by the shared
  CI step. The silence cases carry as much weight as the findings: an advisory
  that always fires is noise a reader learns to skip. Two false positives were
  found and fixed while writing it — `describe()`/`context()` have no assertion
  by construction and were flagging every correctly written Vitest file on its
  outermost line, and the last block in a file absorbs its class's closing braces,
  so the Nth of N identical tests never joined its own duplicate group.
