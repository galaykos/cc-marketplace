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
summary tools for that reason. Harness: `scripts/__tests__/review-state.test.sh`, 14 cases with the host's payload
shapes.
