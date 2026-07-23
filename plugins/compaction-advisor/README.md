# compaction-advisor

Advice-only nudge to run `/compact` when a session has grown long enough that an early
chunk of context is likely no longer relevant to what you are doing now — so compaction
happens at a good moment and the model works from a tighter, more relevant context.

It never runs `/compact` for you. It measures *length*, not meaning; the nudge text asks
the model to weigh whether the early context is still relevant.

## How it works

- A `UserPromptSubmit` hook (`remind.sh`) counts your turns in the session. On a repeating
  **50-turn interval** (turn 50, 100, 150, …) it prints one line suggesting `/compact`.
  That is the only output; the rest of the time it is silent.
- A `SessionStart` hook (`reset.sh`) zeroes the counter when the session starts from a
  compaction or a context clear (`source=compact` / `source=clear`), so you are never
  nagged right after compacting.
- Relevance is left to the model, and the nudge suggests a **guided** compaction, not a bare
  one — a manual `/compact <instructions>` is the only lever that actually shapes what the
  summary keeps (a `PreCompact` hook cannot steer compaction, verified against the Claude
  Code hook docs). The nudge says: *"if early context is now stale, a guided `/compact`
  sharpens output: e.g. `/compact keep the current task, key decisions, and file paths; drop
  resolved tangents`."*

## State

A single file per working tree at `.claude/compaction-advisor/state`, holding
`<session_id> <turns> <last_nudged_at>`. It is self-healing: a missing, corrupt, or
different-session file simply re-seeds the count — the advisor never gets stuck silent.

Add `.claude/compaction-advisor/` to your project's `.gitignore` (this plugin's
transient per-session state, not source). Do **not** ignore `.claude/` wholesale —
other plugins keep team-shared files there, e.g. plugin-scout's `--persist` writes
`.claude/settings.json`, which a wholesale ignore would silently drop from commits.

## Guarantees and limits

- **Warn-only and fail-open.** Any error — no `jq`, unreadable state, malformed input —
  exits 0 with no output. It can never block or slow a prompt.
- **Inert in a non-writable working tree** (it cannot write its state file there).
- **A mid-session `cd` to a different directory restarts the counter** (state is keyed to
  the working directory).
- No token-count API is used (none is available to a hook); the turn count is a deliberate,
  robust proxy. It does not read or measure the transcript.
