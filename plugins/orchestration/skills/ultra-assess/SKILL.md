---
name: ultra-assess
description: Use when an assessment run is triggered with "ultra-assess"/"ultraassess"/"ultra-assessment" in a prompt — the Extreme Boost contract for assessment-shaped work (inventory, audit, gap-analysis, survey, review-at-scale): escalated subagent models, reader fan-out, mandatory red-team + completeness-critic, activation banner; returns findings/backlog, not task cards.
---

# Ultra-assess — Extreme Boost for an assessment run

Ultra-assess is a per-run intensity mode for assessment-shaped work: inventory,
audit, gap-analysis, survey, or review-at-scale — anything whose output is
*findings*, not a build. It is the assessment sibling of taskmaster's `ultra`
(which boosts a build pipeline into spec + cards). This skill is the canonical
owner of the `ULTRA-ASSESS ACTIVE` directive, the banner, and the assessment
recipe; the trigger hook injects the directive and this skill drives the run.

## When ultra-assess is active

Ultra-assess is active for THIS run when the `hooks/ultra-assess.sh`
`UserPromptSubmit` hook matched `ultra-assess`/`ultraassess`/`ultra-assessment` in
the prompt and injected the directive.

A stray mention of the phrase in unrelated chat is inert — the directive changes
nothing unless the turn is an actual assessment. Ultra-assess is single-run and
stateless: no persistent flag, no `stop` command. It lasts for the assessment run
that triggered it and no longer. It never fires from a slash command — those own
their own flag path.

It is deliberately distinct from `ultra-task`: a build run and an audit run are
different shapes, so neither auto-triggers the other. Each already applies boosted
orchestration discipline within its own lane.

## Announce it — the banner

When ultra-assess engages, print this exact banner ONCE, as the first visible line
of your response, before anything else:

```
\033[1;93m⚡ EXTREME BOOST — ultra-assess active\033[0m
\033[2m   <model> subagents · fan-out → red-team → completeness-critic · effort=<effort> (Workflow)\033[0m
```

Substitute `<model>`/`<effort>` with the tier the trigger selected (see Variants;
defaults opus/xhigh). Print it once per run, not once per phase.

## Variants — model & effort suffix

The trigger token carries an optional suffix that picks the tier:

```
ultra-assess[-<model>][-<effort>]
model  = opus | sonnet | haiku | fable      default opus
effort = low | medium | high | xhigh | max  default xhigh
```

`ultra-assess`→opus/xhigh; `ultra-assess-sonnet`→sonnet/xhigh;
`ultra-assess-sonnet-max`→sonnet/max; a lone suffix resolves by set membership
(`ultra-assess-max`→opus/max); unknown suffixes keep the defaults. The hook
injects the resolved `(model=…, effort=…)`; every rule below reads those values.
This mirrors `ultra-task`'s grammar exactly.

## The escalation contract (`ULTRA-ASSESS ACTIVE`)

This is the verbatim block the hook injects. Honor every line:

```
ULTRA-ASSESS ACTIVE (model=<model>, effort=<effort>) — Extreme Boost for this assessment run.
- Reachable reasoning subagents dispatched model:<model> (default opus). On the Workflow
  agent() path also effort:<effort> (default xhigh). Inline Agent dispatch escalates model only — the Agent tool has no effort knob, so an inline subagent keeps its own frontmatter effort.
- Fan out readers over the assessment units (files, plugins, modules, endpoints),
  one lens each, per delegation-contracts; each returns a compressed structured record.
- Synthesize the records into findings plus a ranked backlog.
- Red-team ALWAYS: an N=3 blind panel attacks the synthesis for unsupported claims
  and missed gaps (verification-panels refuter voting). Dedupe holes.
- Completeness-critic ALWAYS: loop-until-dry — repeat until a round surfaces no new
  gap, capped at 3 rounds or the first dry round.
- Output findings/backlog. Do NOT write task cards or an execution marker.
- Exclude opinion-lens from model escalation.
- Fan-out only when the Workflow tool is present; else run the inline fallback.
```

## The recipe

The recipe composes two orchestration skills already in this plugin — read them:

- **delegation-contracts** — how to write each reader's dispatch prompt
  (self-contained, compressed evidence-backed return) and tier it by model/effort.
- **verification-panels** — the refuter-voting red-team, the completeness critic,
  and loop-until-dry discovery.

Phases, each bounded (mirroring the three-cycle ceiling used elsewhere so no
unbounded loop opens):

1. **Scout** — enumerate the assessment units (the fan-out work-list). Inline, cheap.
2. **Fan out readers** — one agent per unit at the selected model/effort, each
   returning a structured record. Filter failures.
3. **Synthesize** — merge records into findings + ranked backlog (barrier: needs all
   records to dedupe and rank).
4. **Red-team** — N=3 blind panel over the synthesis; drop unsupported findings.
5. **Completeness-critic** — loop-until-dry: ask "what unit / claim / angle was
   missed?" until a round is dry or the 3-round cap hits.

## Output shape

Ultra-assess returns **findings + a ranked backlog**, each item evidence-backed. It
never emits a spec, task cards, or an `Ultra: true` execution marker — there is
nothing to execute. If a finding warrants a build, hand the chosen item to
`ultra-task` as a separate run; ultra-assess does not cross into building.

## Graceful degradation

Ultra-assess never hard-fails. If the `Workflow` tool is unavailable — headless,
cron, or the opt-in gate cannot be satisfied — every fan-out phase falls back to a
single inline agent at the selected model: one inline scout+reader pass, one inline
red-team, one inline completeness sweep. The run completes with less parallelism,
never an error.

## What ultra-assess does NOT do

- It does not change the user's main-thread session model — the user sets that.
- It does not persist across runs or expose an "off" command; re-type the phrase.
- It does not write build artifacts — no spec, no cards, no execution marker.
- It does not auto-trigger `ultra-task`, and `ultra-task` does not auto-trigger it.
