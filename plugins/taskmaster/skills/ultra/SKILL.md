---
name: ultra
description: Use when a taskmaster run is triggered with "ultra-task"/"ultratask" (in a prompt or as the leading `ultra` command flag) — the Extreme Boost contract that escalates reachable subagents to opus, makes red-team and coverage mandatory, runs bounded Workflow fan-outs, prints the activation banner, and carries the boost into execution through a card-index marker.
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
- an execution run reads a `00-INDEX.md` that carries the `Ultra: true` marker.

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
\033[2m   opus subagents · always red-team + coverage · bounded fan-out · effort=max (Workflow)\033[0m
```

The banner is main-thread output, never hook output — so it renders regardless
of hook ordering. Print it once per run, not once per phase.

## The escalation contract (`ULTRA-TASK ACTIVE`)

This is the verbatim block the hook and command flags inject. Honor every line:

```
ULTRA-TASK ACTIVE — Extreme Boost for this taskmaster run.
- Reachable reasoning subagents dispatched model:opus. On the Workflow agent() path
  also effort:max. Inline Agent dispatch escalates model only (no effort param).
- grill: extra clarifying-question rounds; no early ledger exit on first CLEAR sweep.
- spec-redteam: run ALWAYS; N=3 blind adversary panel when Workflow is available.
- coverage-check: run ALWAYS before handoff; loop-until-dry, cap 3 rounds or first dry.
- recon: 3 parallel lenses (by-file, by-pattern, by-constraint) via Workflow opus/max,
  else a single inline opus scout.
- card-verify: 1 fan-out pass per card when Workflow is available.
- task-cards: write `Ultra: true` into the generated 00-INDEX.md.
- Exclude opinion-lens from opus escalation.
- Fan-out only when the Workflow tool is present; else run the inline fallback.
```

## Model and effort rules

- The `model: opus` override lands on both inline `Agent` dispatch and `Workflow`
  `agent()` calls.
- `effort: max` is settable ONLY on the `Workflow` `agent()` path — the plain
  Agent tool has no `effort` parameter, so inline dispatch escalates the model
  only and leaves effort at the agent's frontmatter default.
- Never edit an agent's `model:`/`effort:` frontmatter to achieve this. The boost
  is a dispatch-time override; the frontmatter stays as shipped.

## Bounded fan-out recipes

Fan-outs run through the `Workflow` tool only when it is present in this
session's toolset. Each has a hard bound — mirroring the execution plugin's
three-cycle ceiling — so ultra never opens an unbounded loop:

- **Recon** — 3 parallel scouts, one lens each (by-file, by-pattern,
  by-constraint), opus/max, results merged and deduped. Fallback: a single inline
  `context-scout` dispatched `model: opus`.
- **Red-team** — an N=3 blind adversary panel on the frozen spec; dedupe the
  holes across the three. Fallback: a single inline `spec-adversary` (already
  opus).
- **Coverage** — loop-until-dry: repeat the coverage sweep until a round finds no
  new gap/orphan/drift, capped at 3 rounds or the first dry round, whichever
  comes first. Fallback: one inline coverage pass.
- **Card verification** — one verification pass per card, checking each card
  against the spec criteria it claims. Fallback: inline spot-check.

## Exclusions

`opinion-lens` is a breadth agent (four parallel persona takes, low effort by
design); escalating it to opus multiplies cost for little depth. It is never
given an opus override. Agents that live in plugins ultra does not edit —
`system-architect` (system-design) and the plan-before-code architecture agents
(code-architecture) — are outside the reachable set and stay at their native
tier; reaching them would require editing those plugins, which is out of scope.

## Carrying the boost into execution

The spec and card phases run in the main thread, but execution happens later —
often in a fresh session with no memory of this run. To survive that handoff,
`task-cards` writes an `Ultra: true` marker into the generated `00-INDEX.md`.
The `task-runner` task-execution skill reads that marker and dispatches the
worker agents it spawns with `model: opus` (excluding `opinion-lens`). The marker
is a durable property of the generated artifact, not session state — so ultra
reaches execution even across a session boundary.

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
