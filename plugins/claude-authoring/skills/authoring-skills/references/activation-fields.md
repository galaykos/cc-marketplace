# `paths:` and `disable-model-invocation:` — what they cost, measured

> Measured 2026-08-21 against Claude Code 2.1.237 with probe skills in both
> scopes. Re-measure before trusting on a later build; the plugin-vs-project
> asymmetry below is behaviour, not spec, and the docs state neither half.

Two frontmatter fields change WHEN a skill loads. Both are documented; neither
does what a token-cost argument assumes.

## `paths: ["**/*.ext"]`

Activation trigger, and the trigger is an **edit**:

| Condition | Project/personal skill | Plugin skill |
| --- | --- | --- |
| no matching file touched | hidden from the listing; `/name` returns `Unknown command` | **still listed** |
| matching file merely present | hidden | listed |
| matching file **read** | hidden | listed |
| matching file **written or edited** | activates | activates |

- A `Read` does not activate it. A `Write`/`Edit` does, in the same turn.
- **For a PLUGIN skill it saves no context.** The description stays in the
  listing whether or not anything matches, so `paths:` on a shipped skill adds a
  trigger and buys nothing back. Use it for reach, never as a budget move.
- It has no equivalent of a manifest check — nothing distinguishes a Vue 2 repo
  from a Vue 3 one — and no arbitration when several skills match one file.

## `disable-model-invocation: true`

Removes the description from context entirely: the skill disappears from the
model's listing while its `<plugin>:<skill>` slash command still runs it. Measured, both halves.

This is the only field that reliably buys always-on tokens, and it costs the
skill its ONLY automatic channel. Apply it when the skill is a command's
implementation with no natural-language trigger of its own. Do NOT apply it to a
skill whose description is prompt-shaped — "Use when adding smooth scroll", "Use
when a prompt says ultra-task" — because the description IS the trigger there,
and deleting it to save ~100 tokens deletes the skill's reachability.

## The meter disagrees, and the meter is wrong

`claude plugin details` charged a `disable-model-invocation` skill the same
always-on tokens as a visible sibling (~60 vs ~60) for a description the session
listing does not contain. It is a static estimate over the files, not a read of
what the harness loads. Useful — it models the host's per-component floor, which
a bytes/4 estimate misses — but not ground truth.
