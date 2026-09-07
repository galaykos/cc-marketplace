---
name: harvest
description: "Use when asked to mine this project’s past Codex tasks or provided transcripts for recurring friction and propose evidence-backed instructions or skills."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

# Harvest project history

Locate history through the actual available task-list/read tools or user-provided transcript paths. Filter to the current project's verified path or project identity before reading content. Follow pagination when needed. Do not assume a private transcript schema or scan unrelated projects. If only summaries are available, label that limitation and do not fabricate quotes or counts.

Select up to five unprocessed sessions by default, or the requested count/all. When supported metrics exist, rank by `3 * friction_events + 2 * errors + turns`; otherwise use recency and state that ranking. Read selected history without modifying it. Skip malformed/missing content with a recorded reason. Use read-only subagents for independent sessions only when the actual tools and current delegation policy allow it; otherwise mine sequentially inline.

Extract corrections, recurring chores, failed approaches, and what succeeded instead. Keep source task IDs and exact quotes. Cluster across sessions. Rules and skill/plugin proposals require evidence from at least two distinct sessions. Park single-session observations. Check existing AGENTS.md instructions and the available skills catalog before proposing anything; existing coverage becomes a routing/compliance finding, not a duplicate rule.

Report five sections: prior proposal outcome check (correlation only; unavailable if insufficient history), friction statistics with observed versus unavailable fields, AGENTS.md rule candidates, skill/plugin ideas, and failed-approach warnings. For each proposal name the destination and cite the supporting sessions.

Apply only proposals the user selected or already explicitly authorized. Repository conventions go to the appropriate AGENTS.md. Personal preferences must not be imposed on the team: present them for the user's chosen personal instruction location, without assuming a writable Codex memory API or file schema. Use an available skill-creator/plugin-creator skill for selected ideas, or provide a scaffold brief. Approved shared warnings can live in a project documentation file, with a separately approved AGENTS.md pointer.

If a local harvest store is requested, use a user-selected location or a project-keyed directory under `${CODEX_HOME:-$HOME/.codex}/hindsight/`. Report/ledger writes require the normal filesystem permission boundary. Store processed source IDs and applied proposals with timestamps and evidence IDs; update atomically, mark processed only after a successful report, and retain enough identity to avoid mixing projects. A report can complete without applying any proposal. Never claim a passive history collector or before/after metric exists unless it actually ran.
