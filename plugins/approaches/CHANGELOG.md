# Changelog

All notable changes to the approaches plugin. Started at 0.7.0; earlier versions
have no entries rather than invented ones.

## 0.9.0

### Added
- **`hooks/compact-recovery.sh` gives `.claude/approaches/deliberated.json` a 120-minute
  mtime TTL, and deletes the marker when it expires.** Nothing anywhere deleted this file
  and nothing bounded its age, so one abandoned deliberation announced itself on every
  compaction of every future session in that project — "written by prose, read by one
  hook, deleted by nobody". Same number and same mechanism as the shared phase sentinel
  (`templates/blocks/phase-guard.md`), deliberately: mtime, because portable shell cannot
  parse ISO-8601 and the file is rewritten whenever a new deliberation lands. Expiring
  early costs a re-deliberation; expiring late re-asserts a decision the session has moved
  past, so it errs toward forgetting. Three harness cases (3 h expires and unlinks, 1 h
  does not). The header's staleness limitation now says what the TTL does and does not
  remove: a marker inside the window from an abandoned task still announces exactly like
  a live one.

### Fixed
- **`hooks/remind.sh` and `hooks/consult-remind.sh` start `#!/bin/bash`, not
  `#!/usr/bin/env bash`.** The fail-open guarantee these hooks assert in their own headers
  has to hold under a stripped PATH, where `env bash` itself exits 127 — a guard that
  cannot start is a guard that allows, and the exit code it never produced looks to the
  host exactly like an allow. Rendered from `templates/reminder-hook.sh.tmpl`, not edited
  here; `pc_hook_shebang` reads the claim back and fails the build now that every shipped
  hook agrees with it.

## 0.8.1

### Fixed
- **Both reminder hooks' phase-guard comment cited a harness line number that had moved.**
  It pointed at `chassis-template-tests.sh:113` for the leaked-extraGuard assertion; the
  assertion is at 126, and 113 is an unrelated uninstall check. It now cites the assertion
  by name (`hook(plain): no extraGuard when null`), which does not drift. Comment only.

## 0.8.0

### Changed
- **`estimation` and `rollout-planning` catch their own vocabulary now.** "estimate", "how
  long will this take" and "S/M/L/XL" were all absent from the estimation description, and
  "rollout", "feature flag", "canary" and "migration sequencing" were absent from the
  rollout one — every one of them a phrase a user opens with, and every one of them already
  in the body being routed to. Triggers only; no behaviour changed.
- **`/approaches:compare`, `:opinions` and `:size` show their arguments in the slash menu.**
  All three took input and shipped no `argument-hint`.

### Fixed
- **`compact-recovery.sh` cited a line number that had moved.** It pointed at
  `approach-deliberation`'s SKILL.md:40 for "Check the MARKER, never memory"; the line was
  44. It now cites the heading, which does not drift.

## 0.7.3

### Fixed
- **`approach-deliberation` no longer fires on every multi-file change.** Its description claimed primacy ("FIRST") and its body triggered on "spans multiple files", while its own `lane.tsv` had always said "two-plus viable shapes". The wide reading collided head-on with `code-architecture:coding-entry`, which sends small mechanical work straight to the edit — so an ordinary three-file change got "proceed now" and "stop for a slate" in one turn.
- **The reminder no longer goes silent on the word "webhook".** The anti-self-reference guard matched `hook` inside `webhook`, so `fix the webhook handler` disarmed the nudge on exactly the API-integration prompts it exists for.

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

