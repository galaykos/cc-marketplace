# Changelog — taskmaster

Consumer-facing changes only. Newest first. Started at 0.50.4; earlier versions have no entries rather than invented ones.

## 0.52.0 — 2026-11-05

- **A fifth card lint checks the card against the tree: `scripts/card-paths-lint.sh --card <file>`.** It exits 2 on an unreplaced template token (`__B__`, an all-caps `{{CARD_ID}}`), on a `mode="edit"` file that does not exist, and on a path the `<verify>` line runs that neither exists nor is created by this card or a sibling card. PHP magic constants (`__DIR__`), Blade/Vue `{{ $x }}`, URLs, flags, globs and absolute paths are not hits. task-cards runs it beside the other card lints, and `references/card-shape.md` lists it as a gate. Why: in the 2026-11-05 retro (issue 9) cards halted workers on missing files, a verify target that did not exist and `__B__` left in verify lines. Pinned by `scripts/__tests__/card-paths-lint.test.sh` (12 cases). It flagged none of the 40 role-tagged cards in this repository's own `taskmaster-docs`. Misses: a file the change needs but the card never lists, and a stale card number in prose.

## 0.51.0 — 2026-11-05

- **task-cards copies a brief's `Verify: range` line into the index.** When the brief `/taskmaster:task` was given (overseer writes one per milestone), or the spec header, carries it, `00-INDEX.md` gets the exact line beside any `Ultra:`/`Goal:` marker; task-runner and candor read it. Never added on taskmaster's own judgment. `skills/task-cards/references/index-markers.md`.

## 0.50.6 — 2026-10-28

- **A bare `goal` first token is now described as what it does: boost + hands-off, the same as `ultra-goal`.** The `ultra` skill's description and trigger list, and the preambles of `/taskmaster:task`, `/taskmaster:redteam`, `/taskmaster:brainstorm` and `/taskmaster:coverage`, said hands-off only; each command's next sentence already ran it as `ultra-goal`. The `ultra` description also reads in short, plain sentences, with the same tokens and markers.
- **The `experience-walkthrough`, `erd` and `coverage-check` skills' descriptions now read in short, plain sentences.** Same triggers; each keeps the words the model matches it on.

## 0.50.5 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `scripts/card-lint-record.sh`, `scripts/card-shape-lint.sh`, `scripts/goal-ledger-check.sh`, `scripts/phase-sentinel.sh`, `scripts/preview-cleanup.sh`, `scripts/skills-stamp-lint.sh`, `scripts/spec-ledger-lint.sh`, `scripts/theme-axis-check.py`, `scripts/verify-teeth-lint.sh`, `skills/visual-decisions/assets/serve.py`; `hooks/card-lint-observe.sh`, `hooks/clarify-gate.sh`, `hooks/preview-guard.sh` (shared-block comments); `hooks/remind.sh`, `hooks/ultra.sh` (generated hooks): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain. `--help` of `scripts/card-shape-lint.sh`, `scripts/goal-ledger-check.sh`, `scripts/skills-stamp-lint.sh`, `scripts/spec-ledger-lint.sh`, `scripts/verify-teeth-lint.sh` no longer prints the history prose; usage, flags and exit codes are unchanged.

## 0.50.4 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/card-lint-observe.sh`, `hooks/clarify-gate.sh`, `hooks/preview-guard.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-taskmaster.md (preview-guard.sh, ui-ux's twin: plugin-ui-ux.md), which an install does not contain. Every hook parses to the same code as before (comments ignored).
