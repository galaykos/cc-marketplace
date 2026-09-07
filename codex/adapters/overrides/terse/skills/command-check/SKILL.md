---
name: command-check
description: Use when measuring accessible assistant replies against the current terse output budget; report only.
---

Read the requested messages through the available task/history tools or an explicitly provided transcript. Default to final assistant replies in this task; `--last N` limits the selection. Honor a provided `--session-file` only after inspecting its actual schema. Do not pass Codex history to the source Claude-JSONL scanner or search an invented history directory.

Measure prose characters divided by approximately 100, rounded up per message, excluding code blocks, tables, and trees. Use the current level's report ceiling (lite 18, full 12, ultra 6; wenyan variants share the ceilings). If level is unset, report raw measurements without an over-budget claim. Report count, mean, maximum, percentage over ceiling, and per-message rows, plus one sentence on the trend.

Distinguish actual final replies from summaries or truncated history. If only summaries are accessible, say the original replies cannot be measured and ask for the transcript if necessary. Token counts require an available tokenizer for the actual model; character counts are not token counts. This metric uses a report ceiling for all reply types and does not judge whether requested detail was appropriate.
