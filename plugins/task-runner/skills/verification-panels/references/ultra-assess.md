# ultra-assess — the Extreme Boost contract for assessment-shaped runs

Read when the `hooks/ultra-assess.sh` `UserPromptSubmit` hook matched "ultra-assess" /
"ultraassess" / "ultra-assessment" in the prompt and injected the directive — a per-run
intensity mode for inventory, audit, gap-analysis, survey or review-at-scale work, whose
output is *findings*, not a build (taskmaster's `ultra` is the build sibling). This file owns
the `ULTRA-ASSESS ACTIVE` directive, the banner, and the assessment recipe.

## When ultra-assess is active

A stray mention in unrelated chat is inert — nothing changes unless the turn is an actual
assessment. Single-run and stateless: no persistent flag, no `stop` or "off" command (re-type
the phrase); it lasts for the run that triggered it. It never fires from a slash command.
Distinct from `ultra-task`: neither auto-triggers the other.

## Announce it — the banner

When ultra-assess engages, print this exact banner ONCE, as the first visible line
of your response, before anything else:

```
\033[1;93m⚡ EXTREME BOOST — ultra-assess active\033[0m
\033[2m   <model> reasoning subagents · fan-out → red-team → completeness-critic · effort=<effort> (Workflow)\033[0m
```

Substitute `<model>`/`<effort>` with the RESOLVED tier (print auto's resolution,
e.g. `fable`, never the word `auto`). Print it once per run, not once per phase.

## Fixed tier

`model=auto, effort=xhigh`, always — the bare `ultra-assess` token carries no tier
suffix (no `-<model>[-<effort>]` grammar, matching `ultra-task`).
The resolution rule is owned by `verification-panels` `references/dispatch-tier.md`,
in this plugin (§ Panel width owns N, not the tier); the hook injects
`(model=auto, effort=xhigh)` and every rule below reads those values.

## The escalation contract (`ULTRA-ASSESS ACTIVE`)

The hook injects a ONE-LINE directive naming this skill; the block below is the
contract that directive stands for, and is what you honor. It is not the hook's
text verbatim. Honor every line:

```
ULTRA-ASSESS ACTIVE (model=<model>, effort=<effort>) — Extreme Boost for this assessment run.
- Reachable reasoning subagents dispatched model:<model> (default auto = session model or opus, whichever is higher on haiku<sonnet<opus<fable — escalate, never downgrade). On the Workflow
  agent() path also effort:<effort> (default xhigh). Inline Agent dispatch escalates model only — the Agent tool has no effort knob, so an inline subagent keeps its own frontmatter effort.
- Fan out readers over the assessment units (files, plugins, modules, endpoints),
  one lens each, per delegation-contracts; each returns a compressed structured record.
  TIER each lens by its work (delegation-contracts rule): an enumerate/locate lens is
  mechanical → native tier; an analytical/judgment lens (does this reproduce? real?)
  is reasoning → model:<model>. Do not flat-escalate every reader.
- Synthesize the records into findings plus a ranked backlog.
- Red-team ALWAYS (reasoning, boosted): a blind panel attacks the synthesis for
  unsupported claims and missed gaps (verification-panels refuter voting), dedupe holes.
  Panel size is a CEILING sized to blast radius — 2 voters small, N=3 default/large — not
  a per-finding ×3 quota.
- Completeness-critic ALWAYS: loop-until-dry — repeat until TWO consecutive rounds
  surface no new gap (matching verification-panels' dry rule), capped at 3 rounds.
- Output findings/backlog. Do NOT write task cards or an execution marker.
- Tier by role, not per-run: readers per their lens (above), opinion-lens native; the
  boost is for the red-team + critic. Fan-out counts are ceilings sized to blast radius.
- Fan out on EITHER dispatch mechanism — `Workflow` `agent()` or the Agent tool; the inline
  fallback fires only when neither exists (§ Graceful degradation).
``` (Proportionality law: `.claude/skills/authoring-skills/SKILL.md` (in the marketplace repository) "The four laws".)

## The recipe

The recipe composes two skills of this plugin — read them:

- **delegation-contracts** — how to write each reader's dispatch prompt
  (self-contained, compressed evidence-backed return) and tier it by model/effort.
- **verification-panels** — the refuter-voting red-team, the completeness critic,
  and loop-until-dry discovery. The contract's "red-team ALWAYS" deliberately
  overrides that skill's one-reviewer default and cost gate — an ultra-assess
  run is explicit opt-in escalation, so the gate is pre-paid.

Phases, each bounded (mirroring the three-cycle ceiling used elsewhere, and — on the
Workflow path — additionally gated by `budget.remaining()`, so no unbounded loop opens):

1. **Scout** — enumerate the assessment units (the fan-out work-list). Inline, cheap.
2. **Fan out readers** — one agent per unit, tiered by its lens's work (mechanical
   enumerate = native; analytical judgment = boost), each returning a structured
   record. Filter failures. Reader count sized to blast radius, not padded.
3. **Synthesize** — merge records into findings + ranked backlog (barrier: needs all
   records to dedupe and rank).
4. **Red-team** — blind panel over the synthesis (2 voters small / N=3 default),
   drop unsupported findings. The panel is the boosted stage; do not ×3 every finding.
5. **Completeness-critic** — loop-until-dry: ask "what unit / claim / angle was
   missed?" until two consecutive rounds are dry or the 3-round cap hits.

## Output shape

Ultra-assess returns **findings + a ranked backlog**, each item evidence-backed. It
never emits a spec, task cards, or an `Ultra: true` execution marker — there is
nothing to execute. If a finding warrants a build, hand the chosen item to
`ultra-task` as a separate run; ultra-assess does not cross into building.

## Graceful degradation

Ultra-assess never hard-fails. The degradation trigger is **no dispatch mechanism at
all** — neither `Workflow` `agent()` nor the Agent tool (`verification-panels`
§ A panel verdict is a claim about process owns that condition). A missing `Workflow`
tool alone is NOT it: the Agent tool is a real dispatch path, so with it present every
phase still fans out for real — `model:` only, no `effort:` — and the words below stay
earned.

With neither mechanism — headless, cron, or a refused budget — every fan-out phase falls back to a
single inline agent at the selected model: one inline scout+reader pass, one inline
red-team, one inline completeness sweep. The run completes with less parallelism,
never an error. But the fallback surrenders independence — one model re-examining
itself (the correlated-opinion caveat approach-deliberation names) — so the words "panel",
"refuters", and "verified" are off-limits for it: every section the fallback produced
is headed **"inline heuristic pass — single model, uncorroborated"**, and the run
summary states which phases ran degraded. Verdict language must let the reader
distinguish a real fan-out from an inline walk without trusting tone.

The opt-in gate is the user's to satisfy, not this plugin's: `Workflow` runs on an
explicit opt-in (`ultracode`, or invoking a skill like this one that directs it), and
`effort` binds only there — so an unpaired boost escalates the model alone. Say it once
per run: `ultracode` supplies the fan-out half, `ultrathink` the orthogonal main-thread
half. Rules, including the workflow-size ceiling and the interactive-phase rule:
`verification-panels` `references/dispatch-tier.md` § Native harness interop.

## What ultra-assess does NOT do

Change the main-thread session model (the user sets that), or fan out an interactive phase
(a consent gate, a user pick — subagents have no user I/O, so it stays in the main thread).

## Residual: no cross-plugin activation guard

Standing: unenforceable — three independently-installed plugins share no writable
state, so two boost tokens inject two directives. The off switch (`CC_BOOST=off`, or
`ORCHESTRATION_BOOST=off`) is what IS implementable; full statement with the
trigger-narrowing limits: `task-runner:verification-panels`
`references/dispatch-tier.md`.
