# Derivations: asset-forge

## plugins/asset-forge/hooks/review-state.sh

The build prompt asked for four hooks: a SessionStart setup check, a PostToolUse dirty flag on
`execute_blender_code`, a PostToolUse clear on `render_review_set`, a post-export validation hook and a Stop gate.
Two were folded away on 2026-11-08 (asset-forge 0.5.0):

- **SessionStart setup**: the server needs no venv (standard library only), and a one-line status on every
  session start is always-on context the marketplace's ceiling had no room for; `env_check` answers the same
  question on demand.
- **Post-export validation**: moved into the `export_asset` tool as `post_export_audit` (re-import into an empty
  scene, check expected objects, no extras, faces, n-gons, UVs, materials). A tool result cannot be skipped the
  way a hook can be disabled, and it needs no Blender launch from a 5-second hook.

The three remaining roles share one script. The gate keys on the transcript path (subagents get their own) and
fires only when the context used asset-forge (a forge tool, or `forge` imported through `execute_blender_code`),
so plain Blender work in other sessions is never blocked. It blocks once per change cycle: the cycle starts at the
first execute call after a review and ends at the next successful `render_review_set` (one whose result names a
`contact_sheet`). Read-only execute calls also mark a change; the pipeline skill sends read-only inspection to the
summary tools for that reason. Harness: `scripts/__tests__/review-state.test.sh`, 16 cases with the host's payload
shapes.

**2026-11-21 (0.7.1): a review of a stale snapshot no longer clears the gate.** The dirty flag held only the time of
the first change in a cycle, and any successful `render_review_set` removed it, whatever `blend_path` it rendered.
So snapshot, more live edits, then a review of the old snapshot let Stop pass on a scene nobody had reviewed. A
reviewer found it by reading the hook (thinking-disciplines follow-up, finding 1). Now every `execute_blender_code`
call except a snapshot (its code names `save_as_mainfile` and `copy=True`) touches a `last` file, and a review
clears the flag only when its `blend_path` (`~/` expanded, a relative path read from the payload's `cwd`) is newer
than `last` (`[ -nt ]`, sub-second where the file system keeps it). No `last` yet means no live edit was seen, and
the review clears as before. A path the hook cannot stat clears nothing, so the gate fails toward one reminder.
Residuals: one call that saves the snapshot and then edits counts as a snapshot; a snapshot written by another route
than an execute call is judged by its file time alone. Two harness cases: a review of the older of two snapshots
still blocks (it failed on the 0.7.0 hook, run from a copy), and a review of the newer one clears. 18 cases.
