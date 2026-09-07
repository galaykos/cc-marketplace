---
name: command-level
description: Use when setting or reporting this task’s terse output level (lite, full, ultra, wenyan variants, off, or status).
---

Parse the user's first argument. Accept lite, full, ultra, wenyan-lite, wenyan-full, wenyan-ultra, off, status; wenyan aliases wenyan-full. Unknown values produce the supported list without changing anything.

Set the requested preference for the current conversation and load `terse-output` from the available catalog. Confirm the level and answer/report budgets in one line: lite 10/18, full 6/12, ultra 3/6 prose lines of approximately 100 characters. Wenyan variants use the corresponding budgets with the classical-Chinese register from terse-output's references. `off` restores normal response length. `status` or no argument reports the last explicit preference in this conversation, or unset.

This command does not rely on a prompt hook to write a global mode file and does not claim cross-session persistence. When the user explicitly requests persistence, use their chosen instruction location and normal authorization; do not invent a Codex settings key. Brevity affects chat prose only, preserving verification, file contents, delegation prompts, and substantive findings.
