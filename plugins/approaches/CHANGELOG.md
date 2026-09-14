# Changelog

All notable changes to the approaches plugin. Started at 0.7.0; earlier versions
have no entries rather than invented ones.

## 0.7.1

### Fixed
- **`consult-remind` no longer outranks `debugging`'s nudge on the repeated-attempt
  phrases.** Its own README said those phrases belong to debugging and its lane yields to
  `systematic-debugging`, while its arcRank of 10 beat debugging's 20 and took them. The
  ranks are swapped; rank now backs what the lane and the README always claimed.
- The Commands table is labelled for what it is: five command files plus two skills
  (`build-vs-buy`, `consult`) invoked the same way.
## 0.7.0

### Added
- **fresh-take merged in** (2026-09-14 consolidation plan §3.1): the `consult` skill
  behind `/approaches:consult`, the blind `consultant` agent, `scripts/brief-lint.sh`
  with its harness, and the irreversible-command reminder as a second chassis
  reminder hook, `hooks/consult-remind.sh` (`approaches:consult-remind`, phase `any`).
  The nudge line reads "approaches:" instead of "fresh-take:" and names the new
  command; regex, rank and phase are unchanged. `lane.tsv` gains rows for the agent
  and the skill (the skill yields the stuck moment to `debugging:systematic-debugging`).
- `scripts/generate.sh`: reminder-hook chassis objects accept an optional `file`
  (default `hooks/remind.sh`) so one plugin can carry two reminder hooks.

