# code-review

Stack-agnostic code review: correctness bugs, code smells, and convention
drift on any diff, branch, or PR — severity-sorted one-line findings
(`path:line — severity — problem — fix`). Structure/YAGNI concerns are
deferred to code-architecture, security depth to security, and stack idioms
to the per-framework review plugins.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install code-review@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/code-review:review [path, PR, or branch]` | Review a diff, branch, or path for correctness bugs, code smells, and convention drift — severity-sorted one-line findings |

## Example

```bash
/code-review:review src/Billing/
/code-review:review        # staged changes, else working tree vs default branch
```

Reviews state their coverage (`Checked:` / `Not checked:`) and close with a
one-line verdict — merge-ready, merge-after-blockers, or rework — with an
option to apply the fixes. The plugin also ships a `code-reviewer` agent
that reviews proactively after code is written, and the `code-smells` skill:
the smell catalog (with when-it-is-NOT-a-smell judgment) both apply.

## Pairs well with

- **code-architecture** — the structural/YAGNI depth this review defers to
- **security** — deep security review beyond the correctness pass here
- **php** / **typescript** — per-stack idiom review for detail this plugin skips
- **intent-guard** — checks the same diff stayed on the declared task intent
