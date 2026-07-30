---
name: terse-crew
description: Use when deciding whether to delegate to a compressed-output subagent — "spawn an investigator", "use the crew", "save context", "delegate this lookup", or when a long session is running out of context and each delegation's return is the thing eating it. Routes between terse-investigator, terse-builder, terse-reviewer and this marketplace's deeper agents.
---

## Why a compressed twin exists at all

A subagent's final message lands in the orchestrator's context verbatim. A prose
exploration returning 2k tokens spends 2k tokens of the caller's budget every
time; the same finding as a `path:line` table costs a fraction. Across twenty
delegations in one session that is the difference between finishing and
compacting. The doctrine behind this — prompt contracts, evidence-backed
compressed returns, model tiering — belongs to
`orchestration:delegation-contracts`; read it there. This skill is only the
routing table.

## Route

| Situation | Send it to |
| --- | --- |
| Where is X defined, what calls Y, every use of Z, map this dir | `terse-investigator` |
| Same, but you also want architecture commentary or suggestions | `Explore` |
| Edit of ≤2 files, change already decided | `terse-builder` |
| A fix list to apply, 3+ files, anything needing verification loops | `task-runner:task-executor` |
| Fast one-line-per-finding pass on a diff | `terse-reviewer` |
| The review IS the deliverable — rationale, severity argument, alternatives | `code-review:code-reviewer` |
| You already know the answer | Nobody. Answer it |

Rule of thumb: delegate to a terse agent when you want the *finding*; delegate to
the deeper agent when you want the *reasoning*. Compressing reasoning produces a
confident-sounding claim with its support removed, which is worse than either.

## What the caller can rely on

- `terse-investigator` — `path:line — \`symbol\` — note` rows, greppable with
  `path:\d+`, or the single token `No match.`
- `terse-builder` — a receipt: changed paths with line numbers, the verify command
  and its result, and an explicit "left" line naming what it did not do
- `terse-reviewer` — `path:line: severity: problem. fix.`, sorted bug → risk → nit → q

A return that does not match its shape is a defect worth reporting, not something
to paper over by re-asking.

## Do not compress the prompt

Compression is for what comes back. The prompt going out still needs absolute
paths, the scope lock, the conventions, and the required return shape spelled out
— a subagent has none of this conversation. Terse mode never applies to the
instructions you write for another agent, and this is the most common way a
brevity mode quietly degrades work quality.

## Cost honesty

The compression claim is about the return, not the task: a terse agent does the
same searching and reading as its verbose twin, and costs about the same to run.
What it saves is the caller's context. If the caller has plenty of room and wants
the prose, the deeper agent is simply better. Standing: **unenforceable** — no gate
measures return size; `/terse:check` measures the main thread's messages only.
