---
name: routine-detector
description: Use when a task smells repetitive — 'again', 'same as last time', 'like before', 'one more of', the third similar request in a project, or any multi-step chore that will clearly recur — to propose capturing the routine as a project skill, command, or agent so the next repetition is cheaper and more consistent.
---

## What this skill does

It watches for work that keeps happening and, AFTER delivering the requested
task, offers to capture the routine as a durable artifact — a project skill,
a command, an agent, or (rarely) a hook — so the next occurrence costs one
invocation instead of a re-explanation.

It never blocks work, never scaffolds on its own, and never nags.

## Detection signals

Two families of evidence. Either alone is a hint; together they are strong.

**User phrasing** — the user's own words admit repetition:

- "again", "same as last time", "like before", "as usual"
- "another one", "one more of these", "the usual format"
- "do the thing we did for X, but for Y"

**Structural signals** — the work itself rhymes with earlier work:

- The same file-pattern edits as a previous task (touch the same trio of
  files, in the same order, for the same kind of change).
- A checklist being re-derived from scratch that was already derived once.
- The same command sequence being re-explained or re-discovered.
- The same output format being described from memory instead of referenced.

**Threshold.** The second occurrence is a hint — note it silently. The third
occurrence is a trigger — surface the suggestion. A first occurrence is
never a routine; one-off work stays one-off.

## Protocol: finish first, then propose

The suggestion NEVER blocks, delays, or replaces the requested work.
Sequence is fixed:

1. Complete the task the user actually asked for, fully and normally.
2. Only then, append one short suggestion block containing exactly four
   things:
   - **Routine noticed** — one sentence naming the repetition.
   - **Artifact** — which kind would capture it (see selection below).
   - **Payoff** — one line: what the next repetition costs with vs without.
   - **Scaffold path** — the command or file path that creates it.
3. Offer it as a selectable choice (AskUserQuestion): "Scaffold it now
   (Recommended)" / "Skip — leave it manual". Never scaffold without the
   yes; bare scaffold command only when headless.

If the answer is yes, scaffold with /claude-authoring:new-skill or
/claude-authoring:new-agent and fill the body from what this session
already knows about the routine — format, sources, steps, tone.

## Artifact selection

Match the routine's shape to the artifact that natively fits it:

| Routine shape                                | Artifact       |
| -------------------------------------------- | -------------- |
| Repeatable knowledge, checklist, house style | project skill  |
| Explicit action the user invokes by name     | command        |
| Delegated persona with its own toolset       | agent          |
| Mechanical guarantee that must ALWAYS run    | hook           |

- **Project skill** — lives at `.claude/skills/<name>/SKILL.md`, fires from
  its description when the situation recurs. The default choice for "we keep
  re-explaining how we do X here."
- **Command** — for "the user will type this deliberately": a release step,
  a report generator, a scripted sequence with arguments.
- **Agent** — for work worth delegating wholesale: a reviewer persona, a
  scout with read-only tools, a builder with a narrow file scope.
- **Hook** — only for invariants that must hold even when nobody remembers
  them (formatting on save, a guard before every commit). Prefer the other
  three; hooks are the last resort, not the default.

Scaffold skills and agents with /claude-authoring:new-skill and
/claude-authoring:new-agent. For format rules, defer to the sibling
authoring skills: authoring-skills, authoring-agents, authoring-hooks,
and authoring-plugins.

## Suggestion etiquette

- **One suggestion per routine per session.** Once offered, the same routine
  is not raised again in this session, whatever the answer.
- **A declined suggestion is a decided suggestion.** If the user says no —
  in any phrasing — that routine is off the table. Respect the no; do not
  re-litigate it next session with a new angle.
- **Never scaffold without a yes.** No "I went ahead and created…". The
  artifact appears only after explicit agreement.
- **Keep the pitch small.** Four lines, appended after the delivered work.
  If the pitch needs a paragraph of justification, the routine is not clear
  enough to capture yet.

## Worked example

Third time this project, the user asks for a hand-written release-notes
summary: same sources (merged PRs since last tag), same sections, same
dry-informative tone. Deliver the summary first, exactly as asked. Then:

> **Routine noticed:** third hand-written release-notes summary, same
> sources and format each time.
> **Artifact:** a `release-notes` project skill capturing sources, section
> order, and tone.
> **Payoff:** next release, "write the release notes" produces this format
> in one pass instead of a fresh briefing.
> **Scaffold:** offered as a selectable choice — "Scaffold the release-notes
    skill now (Recommended)" / "Skip" (proceeds as /claude-authoring:new-skill
    would).

If the user says yes, scaffold it and fill the body from this session's
example. If no, drop it for good.

## Anti-patterns

- **Suggesting after every trivial task.** "You renamed two variables —
  want a renaming skill?" erodes trust in every future suggestion.
- **Scaffolding unprompted.** Creating files the user did not ask for is
  scope creep with a file system footprint.
- **Capturing one-off work as a routine.** A migration, an incident, a
  yearly report: happened once, will not recur in this shape. Let it go.
- **Skills scoped to trigger never or always.** A description so narrow it
  matches only last Tuesday's task will never fire; one so broad it matches
  everything fires constantly and gets ignored. Scope to the recurring
  situation, not the single instance and not the whole project.
- **Re-pitching a declined routine.** The no was the answer.
