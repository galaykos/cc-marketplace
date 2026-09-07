---
name: consult
description: "Use after two repeated failed fix attempts or before an irreversible decision to obtain a facts-only independent second opinion."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

# Fresh take

Write a brief with four fields: moment (`stuck-debug` or `irreversible`), observable problem with actual output, attempt history or exact planned action, and relevant absolute file paths. Omit the preferred answer, current hypothesis, and ranked options. Run this plugin's `scripts/brief-lint.sh` against the brief by resolving the plugin root from this skill's installed path; reread for semantic anchoring even if the lint passes.

When a subagent tool is available and delegation is permitted, dispatch exactly one read-only consultant using a fresh context and the brief. Use the tool's actual schema and inherit the session model; do not translate another host's model names into assumed Codex tiers. Include these role instructions directly: verify the brief against code, inspect one ring of callers/configuration beyond the starting paths, identify what the failed attempts assumed or what the irreversible action forecloses, and return exactly `Take`, `Risks`, and `Alternative` (one concrete route). Ground the Take in path/line or output evidence. No edits or execution of the proposed irreversible action.

Relay those three sections faithfully and mark the result as advice only. A failed/empty consult gets one notice and no retry loop. When delegation is unavailable, perform a separate read-only review inline using the same evidence and output contract, explicitly identifying it as an inline review rather than an independent consultant. Advice does not change existing user authorization or safety requirements.
