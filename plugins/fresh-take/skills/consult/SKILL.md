---
name: consult
description: Use when a session is stuck after repeated failed fix attempts, or before an irreversible action (destructive command, schema drop, force-push, history rewrite) — composes a facts-only consult brief and dispatches a blind stronger-model consultant for an independent take, risks, and one alternative. Advice only — never blocks.
---

## What this is

A "fresh take" at a key moment: an independent, stronger-model second opinion
pulled into the session exactly when the session's own judgment is least
trustworthy — deep in a failed-fix loop, or one keystroke from something
irreversible. The consultant forms its opinion blind from the code, not from
the thread's current hypothesis, which is the entire value: an opinion anchored
to the session's leaning is the session's leaning, restated slower.

## The two moments

- **Stuck debugging** (`stuck-debug`): the same class of fix has failed two or
  more times, or the session is circling one hypothesis without new
  information. The consult question is "what would someone who has not seen my
  attempts try first?"
- **Irreversible decision** (`irreversible`): a destructive or one-way action
  is imminent — dropping a table or column, force-pushing or rewriting shared
  history, bulk deletion, an API contract about to freeze. The consult question
  is "what does this action foreclose, and is there a reversible route?"

Anything else — style debates, approach picks before code exists, routine
review — belongs to other tools (approaches, code-review), not a consult.

## The brief contract (command → consultant)

The consult brief carries exactly four fields:

1. **Moment type** — `stuck-debug` or `irreversible`.
2. **Problem statement** — the observable state: the failing output for
   `stuck-debug`; the target and what currently depends on it for
   `irreversible`.
3. **History / plan** — for `stuck-debug`: what was tried and what each attempt
   produced; for `irreversible`: the exact action about to run, and why now.
4. **Relevant paths** — repo-relative files the consultant should start from.

Facts only. Quote real output; name real files. The consultant has read-only
repo access and will verify every claim in the code — a brief the code
contradicts wastes the consult.

## The blind rule

The brief MUST NOT contain the session's preferred answer, current hypothesis,
leading framing ("I think it's the cache — check the cache"), or ranked
options. Attempts already made are facts and belong in the brief; the
conclusion drawn from them does not. This is the same blind-dispatch
discipline the marketplace uses everywhere a second opinion has value
(spec-adversary, opinion-round): anchoring is removed at composition time,
because it cannot be removed after.

## Dispatch

Spawn the `consultant` agent from this plugin with the brief as its prompt.
One consultant per consult — never a panel, never a retry-for-a-better-answer.
The house cost rule applies (orchestration verification-panels: the default for
any output is ONE reviewer); a user who wants adversarial voting composes
verification-panels deliberately, paying that cost on purpose.

The consultant ships `model: inherit` / `effort: high`, and the caller RESOLVES its tier
at dispatch: **the session model or opus, whichever is higher on
`haiku<sonnet<opus<fable` — escalate, never downgrade.** A static pin cannot deliver the
"stronger model" promise: from a fable session opus is strictly weaker. The floor is
relative to the session, so never dispatch it BELOW the session model to save tokens — a
cheap fresh take is the session's own take with extra steps.

## Presenting the return

The consultant returns exactly three labeled sections — `Take`, `Risks`,
`Alternative`. Relay them verbatim: no paraphrase, no softening, no merging
into the session's own narrative. After the three sections, print one closing
line: "advice only — your call." The session and the user then decide freely;
disagreeing with the consultant is a legitimate outcome and needs no defense.

## Degraded path

If the consultant returns empty, malformed, or errors out (model unavailable,
dispatch failure), print the one-line notice "no advice returned" and continue
normally. Never dead-end the session on a failed consult, never loop retries,
never fabricate a take on the consultant's behalf.

## When the nudge fired

The passive reminder hook matches key-moment phrases and prints one advisory
line naming the command. The nudge is a suggestion with no memory — it may
repeat on later matching prompts, and ignoring it is always legitimate. A nudge
is never a reason to consult by itself; the moment is.

## What a consult is not

- **Not a gate.** Nothing waits on the consultant; no action is blocked
  pending its answer. The passive nudge only suggests the command.
- **Not an executor.** The consultant writes no code, edits no files, runs
  nothing. Its output is three sections of text.
- **Not an escalation of the run.** One consult escalates one opinion; session
  model tiers and pipeline boosts (ultra-*) are unrelated machinery.

## Anti-patterns

- **Leaning in the brief.** "We believe X, confirm" produces confirmation, not
  consultation. Strip conclusions; keep evidence.
- **Panelizing.** Three consultants voting is verification-panels' job, with
  its cost gate — not this skill's default.
- **Consult-as-procrastination.** A consult before any attempt exists has
  nothing to be fresh against; try first, consult when stuck.
- **Treating advice as verdict.** The consultant is an input to judgment, not
  a substitute for it. "The consultant said so" is not evidence; the reasons
  in its `Take` are.
- **Re-consulting the same question** hoping for a different answer — that is
  the anchoring problem wearing a new hat.
