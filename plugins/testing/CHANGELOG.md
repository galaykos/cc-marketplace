# Changelog

All notable changes to the testing plugin.

Started at 0.8.0, the release that added this plugin's first hook. Earlier
versions have no entries rather than invented ones — a backfilled history in the
file whose job is history is worse than an honest starting point.

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
