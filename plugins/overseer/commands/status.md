---
description: Print the overseer program board — milestones, branches, evidence, and what comes next
argument-hint: [--json]
disable-model-invocation: true
---

Run `${CLAUDE_PLUGIN_ROOT}/scripts/program.sh status` (pass `--json` through when
`$ARGUMENTS` carries it) and print its output unchanged. When it reports no program,
point to `/overseer:start`. This command reads; it never edits state or code — the
`overseer` skill is loaded only by `/overseer:start` and `/overseer:resume`.
