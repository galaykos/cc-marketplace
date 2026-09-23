# Card shape — standing of each rule

The template is in the SKILL body. Tags name what the author DECIDED about each
sentence; attributes carry the decision's evidence — a forbidden file names why, an
interface names its consumer, an edited file names the line. Measured before shipping
(8 fresh-model runs, 4 per shape; `rationale/card-shape-ablation-2026-09-23.md` in the
marketplace repository): the READING side showed zero delta. The shape earns its place
at authoring time only, and only because the **gate** rows below are a script.

## What has teeth

| rule | standing |
|---|---|
| `<goal>`, `<facts>`, `<must>`, `<proof>`, `<depends-on>`, `<agent>` present | **gate** — `card-shape-lint.sh` `missing-section` |
| exactly one `<verify>`, on one line | **gate** — `verify-count` / `verify-multiline` |
| `<proof>` has at least one `<criterion>` | **gate** — `no-criterion` |
| every `<file>` in `<facts>` has `mode`; `mode="edit"` has `line` | **gate** — `file-mode` / `file-line` |
| every element in `<must-not>` has a non-empty `reason` | **gate** — `must-not-reason` |
| every `<interface>` has `consumer` | **gate** — `interface-consumer` |
| every `<skill>` has `name` | **gate** — `skill-name` |
| `<agent>` value is in the closed vocabulary | **gate** — `agent-vocabulary`, list read from `agent-tags.md` at run time |
| the `<verify>` text names an assertion | **gate** — `verify-teeth-lint.sh` |
| a framework card names a real skill | **gate** — `skills-stamp-lint.sh` |
| a `<criterion>` describes behaviour, not the diff | **agent-graded** — coverage-check reads it; no script can |
| a `reason` is true; the `<change>` is the right change | **agent-graded** — spec-redteam and the reviewer pass |
| the lints ran at all | **recorded + observed** — `hooks/card-lint-observe.sh` warns once per run on a card with no record |

`<file>`, `<interface>`, `<skill>`, `<verify>`, `<agent>` are one per line — the scripts
grep them. `<change>`, `<current>`, `<target>`, `<criterion>`, `<rule>` may span lines.

## Legacy cards

A card with no `<card>` wrapper and a `**Verify:**` line is the bold-label shape emitted
before taskmaster 0.45.0. All three linters accept it: the shape lint prints a NOTE and
exits 0; the other two read the bold line when no element is present, so an in-flight
set keeps executing. task-cards never emits it — the acceptance is for cards already
written. Dropping the branch is a later release's call.
