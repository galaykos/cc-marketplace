---
name: analyzer-triage
description: Use when grading PHP, TypeScript, JavaScript, React, Vue or CSS code against the project's own static analysis, lint or typecheck — phpstan, psalm, tsc, vue-tsc, eslint, biome, stylelint — before reporting any defect: which config CI enforces, what the baseline forgives, and which rules are switched off. Also when that output needs triage, or a project has no analyzer.
---

The rule this skill exists for: **grade against the project's configuration, never
against a remembered checklist.** Four best-practice checklists for these exact
stacks were measured at zero-to-negative delta against a blind control and then
removed after baseline testing (`rationale/stack-skill-baselines.md`,
`rationale/measured-zero-shapes.md`). What survives measurement is a decision
procedure whose ORDER is the content, and manifest-reading behaviour. That is all
this skill carries.

## The order is the rule

Each step's output is the next step's input. Running them out of order produces a
confident report about the wrong config.

### 1. Detect before grading

    bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-analyzers.sh" [project-root]

Exit 1 means no analyzer is configured. **Say so and stop.** Do not substitute a
remembered rubric — that substitution is the measured-negative shape. The useful
report in that case is one line naming what is missing and the cheapest thing to
add, not a list of style opinions.

### 2. Establish which config is authoritative — BEFORE reading any of them

A repo can carry three analyzer configs and enforce one. The `ci` records name the
workflow files that invoke each tool. Grade against the enforced one; a finding from
an unenforced config is a *suggestion*, and must be labelled as one.

A `ci` record ends in `direct` or `via-script`. Workflows usually do not name the
tool: `run: composer ci:check` can hide four analyzers two script levels down, so the
detector resolves composer and npm script chains to depth 4 and labels the reading.
Measured on a real Laravel project — grepping the workflow alone reported zero of its
four enforced tools.

When no `ci` record names any detected tool, the analyzer is advisory in this repo.
Say that in the report — it changes what a finding obliges the reader to do. Check for
a wrapper the detector could not read (a shell script, a Makefile, a reusable workflow)
before asserting it: the honest line is "no workflow I could read runs it".

### 3. Read the baseline — BEFORE running the tool

A baseline file is a list of defects the project has already decided to carry.
Re-reporting them is noise that buries the new ones, and "fixing" one silently
breaks the build for everyone whose baseline still lists it.

- phpstan: `phpstan-baseline.neon`, usually included from the main config.
- psalm: `psalm-baseline.xml`.
- eslint: inline `eslint-disable` comments are the per-line equivalent — a
  disable carrying a reason is a decision; a bare one is undocumented debt.

### 4. Run it, and report the real exit code

Run the exact invocation the detector printed. Never paraphrase the tool's verdict
from reading the source: the analyzer resolves types, config layering and plugin
rules that no read-through reproduces.

If it cannot run — missing `vendor/`, missing `node_modules/`, a version conflict —
report *that*, with the error. An unrunnable analyzer is a finding about the
project, not a licence to fall back to opinion.

**Empty output is not a clean run.** A non-zero exit with zero bytes on both stdout and
stderr is a crash, and it looks identical to success to anything that only reads text.
Measured 2026-09-15: phpstan hitting PHP's default 128M limit exits 255 silently, and the
memory flag lived only inside a composer script, so the documented invocation "passed"
while checking nothing. Always pair the exit code with the output; when they disagree,
the exit code wins. If a tool exposes a verbose flag, a surprising count is the moment to
use it — the same run truncated its details until `-v` was passed.

### 5. Triage every line into exactly three buckets

| Bucket | Meaning | What the reader owes it |
|---|---|---|
| **new defect** | The tool flags it and no baseline forgives it | Fix, or add to baseline with a reason |
| **baselined debt** | Already suppressed | Nothing now — name the count, not the lines |
| **config gap** | The tool CANNOT see this class because a rule is off | The highest-value finding; see below |

### 6. Report the config gaps last, and loudest

This is the output a remembered checklist can never produce, because it depends on
files the model has not seen. The `strictness` records from step 1 are the evidence:

- `strictness tsconfig strict false` or `strict absent` — every null-safety and
  implicit-any defect in the diff is invisible to the type checker. Findings the
  reader believes are covered are not.
- `strictness phpstan level N` — levels are cumulative; a level-5 run does not check
  what level 6+ checks. Name the bug class the configured level cannot reach rather
  than the level number alone.
- `strictness eslint react-hooks/exhaustive-deps warn` — the rule that catches stale
  closures and missing dependencies is present but demoted, so CI stays green while
  the defect ships. `off` is worse and reads identical in a passing build.
- `strictness psalm errorLevel N` — higher numbers are LOOSER; errorLevel 1 is
  strictest. Stating "errorLevel 3" without that direction misleads every reader.

A config gap is reported as a gap, never as a defect list: you are asserting the
analyzer is blind here, which is checkable, not that specific bugs exist, which is
not.

## Anti-patterns

- **Checklist fallback.** No analyzer found, so the report becomes generic advice.
  This is the shape that measured negative: it narrowed a review from twelve real
  findings to five. Report the absence instead.
- **Baseline blindness.** Running the tool before reading the baseline, then
  reporting suppressed debt as new. Wastes the reader's attention on decided
  questions.
- **Config laundering.** Grading against the strictest config in the repo when CI
  runs a looser one, and presenting the extra findings as build failures.
- **Paraphrasing the tool.** Reading the source and predicting what the analyzer
  would say. If the invocation is in the report, its output must be too.
- **Formatter findings.** Reporting spacing, quote style or import order as defects.
  A formatter owns those; the useful artifact is the config path, which the detector
  already printed on a `formatter` line. Findings there are noise with a rule id.
- **Silent tool substitution.** Running plain `tsc` on a project with single-file
  Vue components. It cannot parse them; the detector reports `vue-tsc` for exactly
  this reason.

## Standing

**Gate** for the detector's own contract — `scripts/__tests__/detect-analyzers.test.sh`
runs on every PR through the repo-wide plugin-harness glob, and asserts that an
analyzer-free project exits 1 rather than returning a checklist.

**Agent-graded** for everything else on this page. No script can prove an agent read
the baseline before running the tool, or that it labelled an unenforced config's
findings as suggestions. Saying so is the point: the order is enforced by the
reader, not by the build.
