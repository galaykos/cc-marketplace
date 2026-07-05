---
name: delegation-contracts
description: Use when dispatching or spawning subagents, writing an agent prompt, delegating work to a Task/Agent tool, planning a fan-out, or reading a subagent's report back — self-contained prompt contracts, compressed evidence-backed return formats, model/effort tiering per stage, scout-then-fanout, and isolation rules for parallel writers. Decomposing work into tasks is code-architecture:task-orchestration; the parallelize-or-inline verdict is task-runner:parallel-planning; the execution loop is task-runner:task-execution.
---

# Delegation Contracts

The orchestrator's context window is the scarcest resource in a
multi-agent run. Every dispatch spends it on a prompt; every return
spends it on a report. Both are contracts — write them like APIs.

## Prompt contract

A dispatched prompt executes in a fresh context. The subagent has not
seen the conversation, the plan, or the previous card — everything it
needs must travel inside the prompt itself:

- **Absolute paths.** The agent's working directory resets between
  calls; a relative path is a coin flip. Name every file in full.
- **The task boundary.** State what to touch AND what not to touch —
  the scope lock. "Fix the parser in src/parse.py; do not modify tests
  or any other file" beats "fix the parser" every time.
- **Constraints and conventions.** Line budgets, naming rules, voice,
  formats the repo enforces. If a validator will reject it, the prompt
  must say so — the agent cannot infer house rules it has never seen.
- **The required return shape.** Say exactly what the final message
  must contain: format, per-item structure, length cap.
- **The closing instruction.** The final message is data for the
  orchestrator, not prose for a human. Say so explicitly, or you get
  an essay.

The test: paste the prompt into a fresh session with zero history. If
it cannot be executed as-is, the contract is broken — fix the prompt,
not the agent. A prompt that needs the conversation to make sense is a
broken contract.

## Compressed returns

A subagent's report is consumed by an orchestrator deciding what to do
next, not a human enjoying narrative. Demand compression in the prompt:

- One line per finding — no paragraph per item.
- `file:line` pointers so every claim is jump-to-able.
- Verbatim quotes over paraphrase — a quote survives scrutiny; a
  paraphrase smuggles in interpretation.
- No prose introductions, no "I began by...", no summary of the
  summary.
- An explicit length cap, stated in the prompt, not hoped for.

In-repo exemplars to copy:

- **context-scout** — fixed 5-section report, under 60 lines total.
- **code-reviewer** — `path:line — severity — problem — fix`, one
  line per finding.
- **transcript-miner** — typed one-liners, each with a verbatim quote
  and a confidence tag.

## Evidence-required returns

No claim without evidence: command output for anything checkable, a
verbatim quote for anything read. "Tests pass" is an assertion; the
last ten lines of the test run is evidence.

Put the verify commands INSIDE the prompt. The agent runs them and
returns their raw output; the orchestrator re-runs only what it
doubts. An agent that reports "done" without evidence has not
finished — it has stopped. Send it back with the verify commands or
run them yourself, but never merge an evidence-free "done" into your
plan state.

## Model and effort tiering

Not every stage deserves the same brain:

- **Mechanical stages** — rename sweeps, format checks, inventory
  scans, grep-and-list — get low effort and cheaper models. The prompt
  defines the task; intelligence adds only cost and latency.
- **Verify and judge stages** — reviews, adversarial checks,
  acceptance judgments — get high effort. This is where cutting
  corners is expensive: a lazy judge approves broken work.
- **When unsure, inherit.** The session default exists for a reason;
  guessing a tier is worse than not setting one.

Tiering is per-stage, not per-run: one pipeline can dispatch a cheap
scout, mid-tier workers, and an expensive judge.

## Scout then fan out

Never fan out on a guessed work-list. A cheap read-only scout goes
first: it discovers the actual work-list — files, sites, targets —
and returns it as a list. That list defines the fan-out: one worker
per item, each worker's scope lock drawn from the scout's output, not
from the orchestrator's assumptions.

Blind fan-out fails in both directions: workers collide on files the
orchestrator did not know overlapped, and work is missed because
nobody was assigned the file the orchestrator did not know existed.
The scout costs one cheap dispatch and buys a correct partition.

## Parallel writers

Reads parallelize freely; writes need proof of disjointness.

- Parallel agents that WRITE must have mutually disjoint file sets —
  proven disjoint from the scout's work-list, not assumed.
- When disjointness cannot be proven, isolate: give each writer its
  own worktree and merge afterward. Feature-branch worktree lifecycle
  lives in git-workflow:worktree-isolation.
- Read-only agents never need isolation — spawn as many as the work
  supports.

The failure mode is silent: two writers touch one file, the second
write clobbers the first, and no error is raised anywhere.

## Anti-patterns

- **Context-dependent prompts.** "Fix the thing we discussed"
  dispatched to an agent that was not in the discussion — guaranteed
  garbage back.
- **Prose-essay returns.** Three paragraphs of narrative where five
  `file:line` lines would do; the orchestrator pays for every token.
- **Evidence-free "done".** A completion claim with no command output
  is a stopped agent, not a finished task.
- **Uniform model for every stage.** Paying judge-tier prices for a
  rename sweep, or trusting scout-tier effort with the final review.
- **Blind fan-out.** Dispatching N workers on a work-list nobody
  verified — collisions and gaps, discovered at merge time.
- **Two writers, one file.** The last write wins silently; the first
  writer's work vanishes without an error.
- **Re-doing delegated work yourself.** Dispatching a search and then
  running the same search inline — pay once, not twice.
