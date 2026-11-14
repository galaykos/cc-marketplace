# Changelog — hindsight

Consumer-facing changes only. Newest first. Started at 0.12.2; earlier versions have no entries rather than invented ones.

## 0.14.0 — 2026-11-14

- **Picked warnings go to `.cc-artifacts/hindsight/anti-patterns.md`**, not `.claude/hindsight/anti-patterns.md`. Claude Code refuses a Write into `.claude/` as a sensitive path, and `.cc-artifacts/` is the one folder a project gitignores for what plugins write during development. When only the old folder exists, the harvest copies it over once before the first pick and never touches it. The README says how a team tracks the file instead of ignoring it, and the proposed CLAUDE.md pointer may replace one that names the old path. Standing: agent-graded — the skill tells the model to copy, no script checks it.
- **Brain notes and the existing-coverage check use the brain map's new home, `.cc-artifacts/brain/`** (brain 0.5.0). A map still in `brain/` is read there, and copied over once before the first note is written. Standing: agent-graded.
- Unchanged: the ledger, reports and skill-use log stay under `~/.claude/hindsight/<slug>/`, outside the project.

## 0.13.0 — 2026-11-12

- **Removed: `/hindsight:claude-md` and its stale-reference script.** No logged use in 40 days on the maintainer's machine. For auditing a CLAUDE.md use the host's `/doctor prompt-audit` (Claude Code 2.1.283+).
- **Removed: the outcome check and `applied.jsonl`.** The before-and-after table opened every harvest. Its one real output graded six rules applied together as six identical "worsened" rows, so it could not tell rules apart. An existing `applied.jsonl` is ignored; delete it if you like. The harvest report has four sections now.
- **New: `scripts/select.sh` ranks the candidates and marks them mined.** Both were prose steps the model was asked to do by hand, and the marking was unreliable: on the maintainer's machine one harvest marked its sessions and the next marked almost none, so mined sessions were offered again. One row per conversation now: a resumed session used to count twice, and a forked session was offered beside its parent. Standing: gate in the marketplace repository (`scripts/__tests__/select.test.sh`, 31 cases).
- **New: `since N days` and `all projects`.** A harvest can take a date window. Other projects are read only when you ask for every project in so many words; the default is still the current one. Standing: recorded.
- **`hooks/skill-use.sh` no longer claims the harvest reads its log.** Nothing in this plugin does; the README says who does and how to turn it off.

## 0.12.4 — 2026-10-28

- **The `harvest` skill's description now reads in short, plain sentences.** Same triggers and outputs; it keeps the words the model matches it on.

## 0.12.3 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `scripts/claude-md-check.sh`, `scripts/outcome.sh`; `hooks/skill-use.sh` (shared-block comments): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.

## 0.12.2 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/collect.sh`, `hooks/skill-use.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-hindsight.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).
