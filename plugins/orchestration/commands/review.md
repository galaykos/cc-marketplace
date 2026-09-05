---
description: Audit a planned fan-out or drafted subagent prompts — contract gaps, missing verify stages, tier mismatches; report-only
argument-hint: [plan-or-prompts]
---

Invoke the delegation-contracts and verification-panels skills from this plugin
first.

Audit $ARGUMENTS: a described fan-out plan, a file of drafted agent prompts, or a
task-card index with parallel groups. If no argument, look for the most recent
`taskmaster-docs/tasks/*/00-INDEX.md`; if none exists, ask what to review.

Check each prompt/stage for:

1. Prompt-contract completeness — paths, scope lock, constraints, required return
   shape, data-not-prose closing instruction. For any prompt available as text,
   run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/dispatch-lint.sh <file>` (or pipe via
   stdin) and fold its output in: the lint settles PRESENCE of the four
   string-checkable elements mechanically; your judgment covers whether the scope
   lock locks the right scope and the constraints are the repo's real ones.
2. Compressed-return format specified, with a length cap.
3. Evidence requirement present — verify commands travel in the prompt.
4. Verify stage exists for accuracy-critical output, and is cost-gated (no panel
   theater on trivia).
5. Barrier-vs-pipeline sanity — barriers only where a stage needs ALL prior
   results (dedup/merge/early-exit); otherwise pipeline.
6. Model/effort tier fits the stage (mechanical = low, verify/judge = high).
7. Parallel writers have disjoint file sets or isolation.
8. Fan-out WIDTH — how many agents each stage spawns, and whether N is sized to
   blast radius rather than filled to a quota. Flag: a flat per-item ×N panel, a
   fan-out with no stated ceiling, and a loop with no round cap. Sizing authority
   is this plugin's own `verification-panels` § Panel width (2 small / 3 medium /
   3 large) — those counts are ceilings, not quotas. (Proportionality law: `.claude/skills/authoring-skills/SKILL.md` (in the marketplace repository) "The four laws".)

Report one line per gap: `stage/prompt — gap — fix`, ordered by impact (accuracy
risks before efficiency nits). Say "no gaps" when clean.

Report-only: change nothing unasked. End with a handoff offer (AskUserQuestion
when available): "Fix the prompts now (Recommended)" / "Skip — report only".

On the apply pick, the sink depends on where the prompt lives, and the two cases
are genuinely different — do not collapse them:

- **Prompt is in flight** (a fan-out you are about to dispatch this turn): rewrite
  it inline and dispatch. There is no file to edit, so a file-editing worker is
  the wrong tool; routing here would be ceremony.
- **Prompt lives on disk** (a `commands/*.md`, `agents/*.md` or SKILL.md body):
  dispatch the fix list down `task-runner:task-executor if installed → inline`,
  the same chain every other review command in this marketplace uses. A prompt
  file is a file.

Headless: print the fixed prompt fragments inline.
