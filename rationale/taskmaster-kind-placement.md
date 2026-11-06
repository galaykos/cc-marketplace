# Where taskmaster's kind-specific material lives (2026-11-06)

## Decision

A hybrid. An asset kind is owned by its domain plugin's skill (`blender:blender-best-practices`,
`meshy:meshy-generation`, `gamedev:asset-pipeline`), reached through the card's run-time-resolved
`<skill name="plugin:skill"/>` stamp, and opts in with one fixed `## Kind recipe` heading
(questions, proof command, look check); taskmaster stores no plugin list. Bugfix and research
have owners (`debugging:systematic-debugging`, `ultra-deep-research`); unowned kinds (refactor,
video, audio) go to `plugins/taskmaster/agents/spec-adversary.md` § Known-bug catalog, outside
the skill corpus. Not built yet: nothing reads `## Kind recipe`, the catalog has no refactor,
video or audio lines, and the missing-plugin line (`degraded: no kind recipe for <kind>`,
task-runner `routing.md`'s format) ships with the first recipe.

## Rejected

- Domain plugins only (unowned kinds get nothing); all in taskmaster agents (copies of rules
  the domain plugins carry drift); a core plus kind packs split (bumps everywhere, ~1.2 KB).

## Evidence

Three headless runs on 2026-11-06, one each, on taskmaster 0.53.0: a Blender chess-knight prompt
with blender, meshy and gamedev loaded; the same prompt with only taskmaster loaded (it still read
blender from its sibling directory: not a clean ablation); a Meshy-for-Godot prompt. All three
produced asset-shaped cards (`mode="create"` outputs, `blender_qa.py`/`inspect_glb.py` proofs, a
rendered look check, a credit yes before paying), so no `## Kind recipe` content shipped. The
measured gaps, an `api` tag on Meshy cards and a `<walk>` on a PNG, are fixed in taskmaster 0.54.0
and task-runner 0.50.2, per the admission law in `.claude/skills/authoring-skills/SKILL.md`.

## Kill-trigger

Move a kind into the catalog when its recipe cannot fit the owning SKILL.md budget, or when,
after its `## Kind recipe` ships, 2 of 3 headless runs still yield code-shaped cards.

## Open

A hands-off `Credits:` budget is deferred to its own spec. Since taskmaster 0.54.0 Goal mode
asks a paid call's cost confirmation instead of auto-taking it (`ultra/SKILL.md` § Goal mode),
but a card with no ask bypasses that: in 1 post-change run headless grill pre-granted the spend
as an ASSUMED default, so the card submitted with no ask. Agent-graded; the G2 spec owns the fix.
