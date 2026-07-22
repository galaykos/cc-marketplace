---
name: ultra
description: Use when a taskmaster run EXPLICITLY triggers Extreme Boost — "ultra-task"/"ultratask" anywhere in a taskmaster prompt (may cross a command boundary), or a bare `ultra` as FIRST token of a taskmaster command's own args (`/taskmaster:<cmd> ultra …`). A bare `ultra` owned by ANOTHER command — e.g. `caveman ultra` before `/taskmaster:task …`, where `ultra` is caveman's flag, not taskmaster's first arg — does NOT trigger; never auto-fire. Escalates subagents; mandates red-team+coverage.
---

# Ultra — Extreme Boost for a taskmaster run

Ultra is a per-run intensity mode for the taskmaster pipeline. It is the
canonical owner of the `ULTRA-TASK ACTIVE` directive, the activation banner, and
the bounded fan-out recipes. The trigger hook and the command flags inject the
directive defined here; the pipeline skills read it and escalate.

## When ultra is active

Ultra is active for THIS run when any of these holds this turn:

- the `hooks/ultra.sh` `UserPromptSubmit` hook matched `ultra-task`/`ultratask`
  in the prompt and injected the directive, or
- a taskmaster command (`task`, `taskmaster`, `redteam`, `brainstorm`,
  `coverage`) was invoked with the explicit `ultra-task`/`ultratask` token, or
  with a bare `ultra` as the **first token of that command's own arguments**
  (`/taskmaster:<cmd> ultra …`), or
- an execution run reads a `00-INDEX.md` that carries the `Ultra: true` marker (a lone `Goal: true` marker also escalates workers — goal implies the boost).

The trigger is deliberately narrow so a bare `ultra` cannot leak in from another
command. `ultra` is a shared word — other plugins use it as their own intensity
flag (e.g. `caveman ultra` sets the caveman verbosity level). Only two things
count as a taskmaster trigger: the explicit `ultra-task`/`ultratask` token
(which no other plugin claims, so it may cross a command boundary), or a bare
`ultra` that is the FIRST token of a taskmaster command's own argument string. A
bare `ultra` that belongs to another command — including a chained prompt where
`caveman ultra` precedes a `/taskmaster:brainstorm <description>`, so `ultra` is
caveman's flag and the taskmaster args begin with the task description — is NOT a
taskmaster trigger and never boosts the run.

Outside those, the directive is inert — a stray mention of the phrase in
unrelated chat changes nothing. Ultra is single-run and stateless: there is no
persistent flag file and no `stop ultra` command. It lasts for the pipeline run
that triggered it and no longer.

## Announce it — the banner

When ultra engages, print this exact banner ONCE, as the first visible line of
your response, before anything else:

```
\033[1;93m⚡ EXTREME BOOST — ultra-task active\033[0m
\033[2m   <model> subagents · always red-team + coverage · bounded fan-out · effort=<effort> (Workflow)\033[0m
```

Substitute `<model>`/`<effort>` with the RESOLVED tier (see Variants; defaults
auto/xhigh — print auto's resolution, e.g. `fable`, never the word `auto`). The banner
is main-thread output, never hook output. Print it once per run, not once per phase; if `ultra-goal` is also active it owns one merged banner (see the ultra-goal skill).

## The escalation contract (`ULTRA-TASK ACTIVE`)

This is the verbatim block the hook and command flags inject. Honor every line:

```
ULTRA-TASK ACTIVE (model=<model>, effort=<effort>) — Extreme Boost for this taskmaster run.
- Reachable reasoning subagents dispatched model:<model> (default auto = session model or opus, whichever is higher on haiku<sonnet<opus<fable — escalate, never downgrade). On the Workflow
  agent() path also effort:<effort> (default xhigh). Inline Agent dispatch escalates model only — the Agent tool has no effort knob, so an inline subagent keeps its own frontmatter effort.
- grill: extra clarifying-question rounds; no early ledger exit on first CLEAR sweep.
- spec-redteam: run ALWAYS; N=3 blind adversary panel when Workflow is available.
- coverage-check: run ALWAYS before handoff; loop-until-dry, cap 3 rounds or first dry.
- recon: 3 parallel lenses (by-file, by-pattern, by-constraint) via Workflow at the
  selected model/effort, else a single inline scout at the selected model.
- card-verify: 1 fan-out pass per card when Workflow is available.
- task-cards: write `Ultra: true (model=<model>, effort=<effort>)` verbatim into 00-INDEX.md.
- Exclude opinion-lens from model escalation.
- Fan-out only when the Workflow tool is present; else run the inline fallback.
```

## Variants — model & effort suffix

The trigger token carries an optional suffix that picks the tier:

```
ultra-task[-<model>][-<effort>]      free-text prompt (hooks/ultra.sh)
ultra[-<model>][-<effort>]           leading flag of a taskmaster command's args
model  = auto | opus | sonnet | haiku | fable   default auto
effort = low | medium | high | xhigh | max      default xhigh
```

`auto` (the default) resolves at dispatch time to the session model or opus, whichever
is higher on the ladder haiku<sonnet<opus<fable — escalate, never downgrade; an explicit
model suffix pins absolutely. `ultra-task`→auto/xhigh; `ultra-task-sonnet`→sonnet/xhigh; a lone
suffix resolves by set membership (`ultra-task-max`→auto/max); unknown suffixes keep the defaults. The hook injects `(model=…, effort=…)` into the directive; the rules below read it.

## Model and effort rules

- The RESOLVED `model:` override lands on both inline `Agent` dispatch and `Workflow`
  `agent()` calls — pass the resolution (e.g. `fable`), never the literal `auto`.
- `effort: <effort>` is settable ONLY on the `Workflow` `agent()` path — the plain
  Agent tool has no `effort` parameter, so inline dispatch escalates the model
  only and leaves effort at the agent's frontmatter default.
- Never edit an agent's `model:`/`effort:` frontmatter to achieve this. The boost
  is a dispatch-time override; the frontmatter stays as shipped.

## Bounded fan-out recipes

Fan-outs run through the `Workflow` tool only when present. Each has a hard bound
— mirroring the execution plugin's three-cycle ceiling — so no unbounded loop:

- **Recon** — 3 parallel scouts, one lens each (by-file, by-pattern,
  by-constraint), at the selected model/effort, merged and deduped. Fallback: one
  inline `context-scout` at the selected model.
- **Red-team** — N=3 blind adversary panel on the frozen spec; dedupe holes across
  the three. Fallback: one inline `spec-adversary` (already opus).
- **Coverage** — loop-until-dry: repeat the coverage sweep until a round finds no
  new gap/orphan/drift, capped at 3 rounds or the first dry round, whichever
  comes first. Fallback: one inline coverage pass.
- **Card verification** — one verification pass per card, checking each card
  against the spec criteria it claims. Fallback: inline spot-check.

## Exclusions

`opinion-lens` is a breadth agent (four parallel persona takes, low effort by
design); escalating its model multiplies cost for little depth. It is never
given a model override. Agents that live in plugins ultra does not edit —
`system-architect` (system-design) and the plan-before-code architecture agents
(code-architecture) — are outside the reachable set and stay at their native
tier; reaching them would require editing those plugins, which is out of scope.

## Carrying the boost into execution

The spec and card phases run in the main thread, but execution happens later —
often in a fresh session with no memory of this run. To survive that handoff,
`task-cards` writes an `Ultra: true (model=<model>, effort=<effort>)` marker into
the generated `00-INDEX.md`, tier VERBATIM — `auto` stays `auto`, so task-execution
re-resolves it against the EXECUTING session's model (never below opus; an older runner
parses `auto` as malformed and falls back to the opus/xhigh legacy default — the floor
holds). It dispatches workers at that tier (excluding `opinion-lens`), AND runs the
**code-redteam** pass at milestone boundaries + completion; the marker is the durable trigger.

## Graceful degradation

Ultra never hard-fails a run. If the `Workflow` tool is unavailable — a headless
or cron context, or the opt-in gate cannot be satisfied — every fan-out phase
falls back to its inline single-agent form, still escalated on model. The run
completes with strictly less parallelism, never with an error. If Workflow
orchestration proves flaky or too heavy in practice, drop to pure inline
escalation: the model tier plus mandatory red-team and coverage still deliver a
real boost over a normal run.

## What ultra does NOT do

- It does not change the user's main-thread session model — that is set by the
  user and no plugin can override it.
- It does not persist across runs, write a session-state file, or expose an
  "off" command; re-type the phrase to boost the next run.
- It does not boost mechanical or breadth agents, or agents dispatched by
  unedited plugins.
- It does not animate the terminal; the single colored banner is the whole cue.
