# Changelog — claude-authoring

Consumer-facing changes only. Newest first. Started at 0.12.0; earlier versions
have no entries rather than invented ones.

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
