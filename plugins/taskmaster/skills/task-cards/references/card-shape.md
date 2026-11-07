# Card shape — standing of each rule

Template: the SKILL body. Tags name what the author DECIDED; attributes carry the
evidence (a forbidden file's why, an interface's consumer, an edited file's line). It
earns its place at authoring time only, via the **gate** rows (why:
`rationale/2026-09-26-taskmaster-prose-derivations.md`).

## What has teeth

| rule | standing |
|---|---|
| `<goal>`, `<facts>`, `<must>`, `<proof>`, `<depends-on>`, `<agent>` present | **gate** — `card-shape-lint.sh` `missing-section` |
| exactly one `<verify>`, on one line | **gate** — `verify-count` / `verify-multiline` |
| `<proof>` has at least one `<criterion>` | **gate** — `no-criterion` |
| each `<facts>` `<file>` has `mode`; `mode="edit"` has `line` | **gate** — `file-mode` / `file-line` |
| each `<must-not>` element has a non-empty `reason` | **gate** — `must-not-reason` |
| every `<interface>` has `consumer` | **gate** — `interface-consumer` |
| every `<skill>` has `name` | **gate** — `skill-name` |
| `<agent>` value is in the closed vocabulary | **gate** — `agent-vocabulary`, list read from `agent-tags.md` at run time |
| the `<verify>` text names an assertion | **gate** — `verify-teeth-lint.sh` |
| a UI card's `<verify>` is more than types/lint/build/grep | **WARN** — `verify-teeth-lint.sh` `ui-static-only` |
| a UI card has one `<walk surface="/route" widths="1280,375">state</walk>` in `<proof>` | **agent-graded** for presence; the group-close walk reads it (task-runner `skills/task-execution/references/ui-walk.md`) |
| a `<walk>` surface is not a media file (`.png`, `.glb` …) | **gate** — `card-shape-lint.sh` `walk-surface` |
| a look check on a render goes in `<change>`: render to PNG, Read it, state what it shows | **agent-graded** — Read views images only (video/audio/3D: render first) |
| a card needing a browser names its driver in `<verify>`/`<walk>` (Playwright MCP, a `playwright` dep) | **agent-graded** — "browser smoke" alone once sent a worker to an uninstalled host extension |
| a framework card names a real skill | **gate** — `skills-stamp-lint.sh` |
| no unreplaced template token (`__B__`, `{{CARD_ID}}`); a `mode="edit"` file exists; a path `<verify>` runs exists or this/a sibling card creates it | **gate** — `card-paths-lint.sh` `placeholder` / `edit-missing` / `verify-target-missing` (retro 2026-11-05: cards halted on all three) |
| set order: real acyclic `<depends-on>`; every producer precedes its consumers | **gate** — `card-set-lint.sh` |
| a bare `<skill>` stamp shadowed by a same-named project skill (`.claude/skills/<name>`, a plugin's, a known Laravel Boost twin) | **WARN** — `skills-stamp-lint.sh` `shadowed-skill` (prints the `plugin:skill` stamp) |
| a limit is proved by lowering it in the test, not exceeding a production-sized constant | **agent-graded** — spec-redteam and the reviewer; no lint reads a criterion's size |
| a `<criterion>` describes behaviour, not the diff | **agent-graded** — coverage-check reads it; no script can |
| a `guided` card's `<change>` opens `Direction (…):` with no edit list | **agent-graded** — `spec-ledger-lint.sh` reads only the spec's `Detail:` |
| a `reason` is true; the `<change>` is the right change | **agent-graded** — spec-redteam and the reviewer |
| the lints ran at all | **recorded + observed** — `hooks/card-lint-observe.sh` warns once per run (main thread) on a card with no record |

`<file>`, `<interface>`, `<skill>`, `<verify>`, `<walk>`, `<agent>` are one per line — the
scripts grep them. `<change>`, `<current>`, `<target>`, `<criterion>`, `<rule>` may span lines.

## Legacy cards

A card with no `<card>` wrapper and a `**Verify:**` line is the pre-0.45.0 bold-label
shape. All four linters accept it: the shape lint NOTEs and exits 0; the other
three read the bold line when no element exists, so in-flight sets keep running.
task-cards never emits it; dropping the branch is a later release's call.
