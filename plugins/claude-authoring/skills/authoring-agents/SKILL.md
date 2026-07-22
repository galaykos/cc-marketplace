---
name: authoring-agents
description: Use when writing or editing a subagent .md — frontmatter (name, description, tools, model, effort), PROACTIVELY phrasing, tool scoping, worker vs reviewer.
---

## Anatomy

One agent is one markdown file:

    plugins/<plugin>/agents/<agent-name>.md

Frontmatter delimited by dash-fence lines, then a body that becomes the
agent's entire system prompt:

    ---
    name: <agent-name>
    description: Use PROACTIVELY when <situation> — <what it returns>.
    tools: Read, Grep, Glob
    model: inherit
    effort: xhigh
    ---
    You are a <role> …

This marketplace's validator (scripts/validate.sh) rejects any agent file
missing one of the four required keys:

- `name:` — the agent's identifier.
- `description:` — the dispatch trigger (see below).
- `model:` — required here; workers default to `inherit` (the session model), pins are deliberate.
- `effort:` — required here even though agents default to xhigh.

`tools:` is optional — but omitting it grants ALL tools. Always list tools
explicitly; an unscoped agent is a standing permission grant nobody
reviewed.

## Model and effort tiers

Match `model:` to the cost of a wrong answer, not to prestige:

- `opus` — judgment-heavy and wrong-answer-expensive: review verdicts
  (architecture, code), system-design trade-offs, adversarial
  verification, security exploitability calls.
- `sonnet` — a deliberate pin for cheap checklist/breadth work (workers
  default to `inherit`, not a sonnet pin).
- `haiku` — mechanical locate/grep/report with no judgment in the output.

`effort:` is orthogonal and tunes reasoning depth on the same model:
sonnet + xhigh buys deep reasoning at worker prices; opus + medium is not
equivalent — opus has the better raw judgment, sonnet xhigh the better
cost-per-token. Drop scouts and locators to `high` or below; xhigh on a
grep-shaped agent only slows the pipeline.

Frontmatter is the static default; the dispatcher can override per
invocation (the Agent tool's model parameter). Set frontmatter for the
agent's typical difficulty and let the caller escalate the hard cases.

Assignments in this marketplace: architecture-reviewer, code-reviewer,
spec-adversary, system-architect, and system-design-reviewer pin opus/xhigh;
breadth/mechanical fan-out agents pin sonnet (opinion-lens, brain's indexer,
transcript-miner, the ultra-deep-research shards); every other agent ships
`model: inherit` and runs at the session model (context-scout at effort high).

## Description as dispatch trigger

The main thread decides whether to delegate from the description alone; the
body is never consulted at dispatch time.

- Use "Use PROACTIVELY when/for/after …" phrasing to mark agents the main
  thread should reach for without being asked.
- Describe the situations that warrant dispatch — file types, events, task
  shapes — not the agent's virtues. "Expert in X" matches nothing; "Use
  PROACTIVELY after structural changes or new modules" matches a moment in
  the workflow.
- Say what comes back — findings list, diff, file:line table — so the
  caller knows what to do with the result.

## Tool scoping

Grant the minimum the role needs:

- Reviewers get `Read, Grep, Glob` — they inspect and report; they must not
  be able to "helpfully" fix what they find.
- Workers add `Write, Edit, Bash` — they change files and must be able to
  run verification commands.
- Anything beyond those six needs a stated reason in the body. Web access,
  subagent spawning, and MCP tools are almost never needed and only widen
  the blast radius.

## Body pattern

The agent wakes with zero conversation context; the body must stand alone.
Structure it as:

1. Role line: "You are a <role> for <domain>." One sentence.
2. Numbered operating procedure — the steps in order, so the agent does not
   improvise a workflow.
3. Domain checklist — the specific things to look for or produce.
4. Defer rules to sibling plugins: if another plugin owns a rule set, name
   it and defer instead of copying the rules — duplicated rules drift.
5. Output-format rule — the exact shape of the final message, stated last
   so it is freshest when the agent writes its report.

## Worker vs reviewer

Keep the split hard; hybrid agents do both jobs badly.

- Reviewers emit findings, one per line:

      path:line — severity — problem — fix

  No praise, no rewrites, no scope creep into fixing what they found.
- Workers implement, then MUST show verification evidence: the command they
  ran and its output. "Done" without output is not done.
- If a task needs both, dispatch two agents in sequence — worker then
  reviewer — not one agent with two personalities.

## Common failures

- Trigger overlap. A new agent whose description matches the same moments
  as an existing agent makes dispatch a coin flip. Diff your description
  against every installed agent's before adding one.
- Kitchen-sink agents. One agent covering three domains has a description
  too broad to dispatch precisely and a body too long to obey. One domain
  per agent; compose via sequential dispatch instead.
- Missing `model:` or `effort:` keys — the two most commonly forgotten,
  because upstream Claude Code treats both as optional defaults. This
  marketplace's validator does not.
- Unscoped tools. An omitted `tools:` line reads like a default but is
  actually a grant of everything, including write and shell access for an
  agent that only needed to read.
- Bodies that assume context. Every path, convention, and constraint the
  agent needs must be in the body or the dispatch prompt — it cannot see
  the conversation that spawned it.
