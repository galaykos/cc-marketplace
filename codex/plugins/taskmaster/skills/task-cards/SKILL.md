---
name: task-cards
description: "Use after requirements are clarified to produce independently verifiable task cards and a dependency-ordered index for Codex execution."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

# Produce executable cards

Read the approved specification and current files before splitting work. A fresh Codex session with only the card must know the expected behavior, exact scope, relevant conventions, and verification. Each card is the smallest independently verifiable change; split substantial multi-concern work, but keep a mechanical sweep together when its single behavior is testable.

Use this template:

```markdown
# NN — Imperative title
**Why:** relationship to the spec goal.
**Context:** current behavior; target behavior; actual files and line references; interface signatures/data shapes; relevant conventions.
**Change:** file-level edits.
**Acceptance criteria:** binary observable behavior.
**Verify:** exact command → named assertion that fails without the behavior.
**Out of scope:** likely adjacent work to avoid.
**Depends on:** card IDs or none.
**Skills to apply:** available catalog names and resolvable SKILL.md paths, or none detected.
**Agent:** capability tag, generic when no specialist applies.
```

Respect the spec's chosen approach, data model and visual contracts; a changed requirement must be resolved before encoding a different implementation. Discover framework guidance from the available skill catalog and actual manifests. Record only skills that are available; missing useful guidance is a limitation, not an invented dependency. Agent tags describe needed expertise, not built-in Codex agent types or model pins.

Write cards under `taskmaster-docs/tasks/YYYY-MM-DD-<slug>/` with `00-INDEX.md`. The index records the spec path and card/title/dependencies/capability/parallel-group/status. Cards remain immutable during execution; status and deviations belong in the index. Order dependencies topologically. Parallel groups require disjoint files and no shared work-in-progress state. For large runs group cards into independently useful milestones with integration checks; do not interleave milestones unless an explicit dependency analysis supports it.

Cross-check every spec success criterion against cards, and every card against the spec; resolve gaps and orphan scope. Verify lines must test behavior rather than existence, compilation alone, or an always-successful shell expression. Use the available coverage-check and verify-teeth skills/scripts when applicable, resolving paths from the installed plugin; otherwise perform and record those checks inline. A task card can be pasted into a fresh Codex session. Creating separate user-owned tasks requires an explicit user request; normal execution can remain inline or use permitted subagents.
