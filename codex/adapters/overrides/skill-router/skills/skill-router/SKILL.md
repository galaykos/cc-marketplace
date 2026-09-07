---
name: skill-router
description: Use when beginning repository work or editing files to find relevant installed skills from the active Codex catalog and the actual project stack.
---

# Route to available skills

Inspect the current request, relevant manifests, and files being changed. Match concrete framework/package evidence and file types to the descriptions in the active Codex skill catalog. Read a selected SKILL.md using its advertised path before applying it. A catalog name must resolve to an available skill; do not infer installation from a sibling cache directory or call a host-specific slash command.

At work start, consider whether a clearly relevant skill improves the requested deliverable. When the user explicitly chose a workflow, preserve that choice; mention a materially better alternative without silently replacing it. If no workflow was named and one clearly fits, briefly name it and proceed. Close calls and weak keyword overlaps require no suggestion. Do not repeatedly offer a route the user declined.

For changed files, check the plugin's `rules.tsv` as an optional signal index: extension/path evidence is strong; content words such as password, async, or try/catch need context. Validate optional stack markers against actual manifests before selecting database/framework-specific guidance. Only use routes whose target is available in the current catalog. Review the changed code against that guidance, once per meaningful signal during the task; avoid repeating the same nudge on every edit.

This is an explicit/description-triggered skill workflow. It does not assert that prompt interception, post-edit routing, session deduplication, or a session-end ledger is installed. If Codex hooks expose any of those mechanisms, rely only on the events and behavior documented in this package's compatibility report. Keep routing advisory and continue useful work when no specialized skill is available.
