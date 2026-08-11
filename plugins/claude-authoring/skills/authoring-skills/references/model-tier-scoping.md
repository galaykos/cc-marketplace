# Model-tier scoping — floor vs compensation

Procedure text does two different jobs, and marking which is which keeps a
skill honest across model tiers.

**The evidence this rests on.** Anthropic removed over 80% of Claude Code's
system prompt for Claude 5-generation models (Opus 5 / Fable 5) with no
measurable loss on coding evals, and named the removed rules for what they
were: compensation for weaker-model judgment, kept only because older models
needed them ("the-new-rules-of-context-engineering-for-claude-5-generation-
models", claude.com blog, 2026-07-24). The complement also holds: scaffolding
demonstrably lifts weaker models when — and only when — it targets a
diagnosed failure mode (verified loops beat unverified self-critique;
undirected scaffolding does not reliably improve agent output). So the same
procedure paragraph can be load-bearing for a Sonnet-class worker and pure
over-constraint for a Fable-class session.

## The two markers

Mark a section of a procedure skill when the difference matters:

- **All models** — judgment content that no tier should skip: boundaries
  ("what to split is task-orchestration"), repo facts, thresholds, when-NOT
  tables, safety rules. This is the floor; it is most of most skills.
- **Compensation (worker-tier)** — step-by-step procedure that exists so a
  weaker or worker-pinned model executes reliably: numbered protocols,
  fixed output skeletons, checklist expansions of judgment calls. A
  frontier-class session honoring the skill may compress or skip these when
  the skill's skip-clause condition holds; a chassis worker agent
  (model-pinned in its frontmatter) follows them in full.

## Skip-clauses

Every procedure skill states when NOT to run its ceremony, in its body, near
the trigger. The canonical shape is Anthropic's own planning rule: "If you
could describe the diff in one sentence, skip the plan." In-repo worked
shapes already exist — approach-deliberation's "Skip it — the first
reasonable approach is correct — when:" list and opinion-round's "Skip
silently" gate. A skill whose ceremony can never be skipped should say WHY
(proportionality law: size ceremony to blast radius).

## Relation to role-floors

Role floors (orchestration `delegation-contracts`,
`references/role-floors.md`) set the MINIMUM model tier an agent role may
run on — who executes. Model-tier scoping sets which PROSE binds per tier —
what they execute. Floors stop a too-small judge; scoping stops a too-big
checklist. Use both: pin the worker's model in agent frontmatter, and let
the skill say which of its sections exist for that worker's benefit.

## Worked example

`code-architecture/skills/plan-before-code/SKILL.md` carries the markers:
its file-map protocol is Compensation (worker-tier); its ownership
boundaries and skip-clause are All models.

## Standing

**Recorded** — no script checks markers or skip-clauses; adopted
incrementally as skills are touched, never in a sweep (the same adoption
pattern as the `Standing:` markers in CLAUDE.md's has-teeth convention).
