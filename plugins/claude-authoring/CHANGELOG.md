# Changelog — claude-authoring

Consumer-facing changes only. Newest first. Started at 0.12.0; earlier versions
have no entries rather than invented ones.

## 0.12.4

### Fixed
- **Both canonical `hooks.json` examples in `authoring-hooks` now carry `timeout`.**
  `pc_hook_timeout` gates that key; the examples taught a shape that fails the
  build, so a reader following them verbatim got a red CI run.
- **The body-budget numbers now read 200 lines / 14,000 bytes**, here and at four
  sibling sites (`authoring-plugins`, `/new-skill` frontmatter and body, README,
  `references/doctrine.md`). The cap moved on 2026-08-27; these said 150/10,000.

### Added
- **`authoring-hooks` names the standing of its four one-shot-state rules** — three
  are gates (`pc_context_key`, `pc_marker_key`, `pc_harness_payload`), one is
  agent-graded. Omitting that in the plugin that DEFINES the has-teeth convention
  was the convention contradicting itself.
- **`authoring-skills` regains the two real cases** deleted at `484a2a1` — the
  evidence for "a rule that keeps being broken is in the wrong tier". They survived
  nowhere else in the repo. The 210-char four-claim line at `:48` is also unjammed.

## 0.12.3

### Changed
- **`/new-skill`'s measured-zero-shapes check moved from step 6 to step 2** — it
  now runs BEFORE the scaffold is written. A refuter applied to a sunk cost
  approves; the check's own wording said "before writing a line" while sitting
  three steps after the write.

## 0.12.2

### Changed
- `model-tier-scoping.md` points at the surviving owners after two merges:
  what-to-split is plan-before-code, and the skip-clause example is the
  deliberation panel's. <!-- removed-ok -->

## 0.12.1

### Added
- `authoring-skills` § Activation fields + `references/activation-fields.md` —
  what `paths:` and `disable-model-invocation:` actually do, measured against
  Claude Code 2.1.237 rather than read off the docs. `paths:` fires on an EDIT
  (not a read, not mere presence) and does NOT hide a PLUGIN skill's description
  from the listing, so it buys reach and no budget; `disable-model-invocation`
  does hide it, at the cost of the skill's only automatic channel. Includes the
  case where `claude plugin details` disagrees with the harness and is wrong.

### Changed
- The body-budget section now states all three measures (150 lines, 10,000
  bytes, 300 characters per line) instead of the line count alone, which stopped
  measuring growth. Four restating passages were compressed to make room.

## 0.12.0

### Added
- **`authoring-hooks`: a `## One-shot state` section**, plus
  `references/one-shot-state.md` carrying the worked case. Four rules for a hook
  that must act only once per file or per context:

  1. Key on the context, not the session — a subagent shares its parent's
     `session_id` but has its own transcript, and `PostToolUse` is the only channel
     that reaches subagents at all.
  2. Hash that value before it becomes a filename — `transcript_path` is an
     absolute path, so raw interpolation names a file whose parent directories
     never existed and every write fails silently.
  3. Decide what a failed marker write means. A hook that blocks but cannot record
     that it blocked would block forever, so withholding is usually right — and it
     means a broken marker turns a gate off with nothing reporting it.
  4. Test the payload the host really sends. A harness supplying only `session_id`
     exercises the fallback branch; the branch that runs in production never does.

  These are not hypothetical. Ignoring 1–3 shipped **three** simultaneously broken
  hooks in this marketplace, and ignoring 4 is why 40+ passing tests never noticed:
  a blocking gate stopped blocking entirely, a warning cap stopped capping, and a
  router re-injected guidance the model already had, on every edit.

  **Standing depends on where you are, and the reference says so.** Inside this
  marketplace all four rules are gates (`pc_context_key`, `pc_marker_key`,
  `pc_harness_payload` in `scripts/lib/plugin-checks.sh`). In your repo none of
  those scripts run, so the skill is a checklist you choose to apply. Same words,
  two standings; treating the second as the first is the tier over-claim this
  plugin's own `authoring-skills` skill warns about.

  The reference carries the material that did not fit the SKILL body's 150-line
  ceiling: the exact unwritable marker path, why a failed write turns a *blocking*
  gate off rather than on, the same one line's three different symptoms, and a
  six-item checklist ending in "watch the test fail against the unfixed hook before
  trusting it".

### Changed
- The `authoring-hooks` description now names one-shot state and payload testing,
  so the skill routes on the failure it teaches. Cost: **+18 always-on tokens**,
  accepted deliberately and re-baselined.
