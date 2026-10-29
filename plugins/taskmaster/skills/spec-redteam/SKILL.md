---
name: spec-redteam
description: Use after grill writes a spec and before task-cards, when blast radius warrants — blind adversaries hunt the frozen spec's edge cases, unstated assumptions, conflicts, failure/security gaps; each resolved before cards.
---

## Where this sits

Standing: recorded — between spec-freeze and `task-cards`. `grill` removes the
ambiguity the user could answer; this attacks the frozen spec itself for what neither
user nor model thought to ask. Distinct from its neighbours: `plan-before-code`
(code-architecture) checks the file-level plan assuming the requirements are right, so
run this BEFORE it; `coverage-check` checks cards against the spec's criteria assuming
those criteria are correct — exactly what this questions; `approach-deliberation`
argues the approach, and a spec hole is a hole whichever way the spec is built.

## The blast-radius gate

A red-team is not free — run it only when the spec warrants it, **except under a boost, where it runs unconditionally** (see the Otherwise clause). Run when ANY holds:

- the spec has **three or more success criteria**, or
- it **touches more than one module or directory**, or
- it mentions a **security, auth, data, or external surface**, or
- it carries any **ASSUMED (unconfirmed) row**.

Otherwise the spec is trivial for this purpose — note "spec trivial for red-team —
skipped" in one line and let the handoff proceed: a one-file, two-criterion spec does
not earn a subagent. (Proportionality law: `.claude/skills/authoring-skills/SKILL.md` (in the marketplace repository) "The four laws".)

**Exception — a boosted run never skips.** Under `ULTRA-TASK ACTIVE` **or** `ULTRA-GOAL ACTIVE` the red-team runs regardless of the bullets (`ultra/SKILL.md`: "spec-redteam:
runs ALWAYS" in § The boost contract, "spec-redteam always runs under goal" in § Goal audit trail). Both directives count — goal injects `ULTRA-GOAL ACTIVE`, not the ultra-task string, and goal is hands-off, so no user is
present to catch a wrong skip. Zero bullets under a boost still runs; § The panel sizes N.
`ULTRA-GOAL ACTIVE (boost=off)` (goal-lean) is hands-off WITHOUT the boost: the bullets
decide as on a standard run, and a skip is written to the goal ledger, not only inline.

## Dispatch the adversary — blind

When the gate is met, dispatch the `spec-adversary` agent with **only the spec file
path** (a re-dispatch adds the prior holes list, § After amendments). Do not pass it the grill conversation, the design doc, or your own summary —
its value is that it reads the requirements cold and finds what the dialogue missed.

**Role-tier floor — boosted or not.** `spec-adversary` carries a row in
`task-runner:delegation-contracts` `references/role-floors.md`, so dispatch it at
`max(marker tier if present ELSE the session model, opus)`. Never omit `model:` in a
session above opus: an adversary weaker than the model that wrote the spec is a weak
gate on exactly the specs that most need one. Registry unresolved → omit `model:` and
note `role-floors.md unresolved — floors not applied`.

## The panel — ultra only

Under `ULTRA-TASK ACTIVE`, via either dispatch mechanism (the Workflow tool or the Agent
tool), this is a **blind panel**, not a single adversary — the width `ultra/SKILL.md` and
`/taskmaster:redteam` already promise. Unboosted runs keep the single adversary above;
nothing here changes a standard run.

Size N by the gate conditions already computed above. Panel width is owned by
`task-runner:verification-panels` § Panel width; `ultra/references/dispatch-tiers.md`
§ Fan-out sizing maps taskmaster's blast-radius rows onto it, but keys off *files the
change touches*, which does not exist yet at
spec-freeze. The four gate bullets are the radius proxy at this step. Apply in order,
first match wins:

1. **No dispatch mechanism (no `Workflow` tool AND no Agent tool) → 1 inline adversary.**
   Tested FIRST so it wins over every branch below — including a zero-bullet boosted run,
   which would otherwise fall into a fan-out section that does not apply to it. The Agent
   tool is a real dispatch path: with it present the adversaries spawn as separate agents.
   `task-runner:verification-panels` owns this rule; cite it, never restate it narrower.
2. The **security/auth/data/external-surface** bullet fires, **or two or more** bullets
   fire → **3 adversaries**.
3. Exactly one non-security bullet fires → **2 adversaries**.
4. Zero bullets fire but a boost forces the run (§ the gate's Exception) → **2 adversaries**.

Count the four bullets as four; the security bullet is ONE disjunction counted once, not
once per surface named in it. These counts are ceilings, not quotas. Panel MECHANICS —
blindness, dedupe, the no-`Workflow` label — are `task-runner:verification-panels`; do
not re-derive them.

The agent returns a structured holes list grouped by lens, each hole tagged
`blocker | major | minor` with a section, the hole, and a suggested fix.

## Present and resolve — blocking

Standing: **agent-graded** — no script gates the spec→cards boundary on red-team
resolution. `spec-ledger-lint.sh` checks only open UNKNOWN rows, and task-runner's
completion gate is execution-side.

Present the holes grouped by lens, each with its recommended resolution (one of the
three below) and a one-line why. Before marking one Recommended, grep the tests and
config for what it would change and name any conflict beside it ("breaks
`tests/Feature/ProxyTest.php`") — a hidden one costs a worker halt and a card rewrite.

- **Amend the spec** — the hole is real; edit the spec file to close it (add the
  missing edge case, state the assumption, resolve the conflict, specify the failure
  or security behavior). The amendment lands in the spec, not just the conversation.
- **Accept as a known risk** — the hole is real but out of scope this round; record
  it in the spec (a one-line note under the relevant section or non-goals) with the
  reason, so it is a decision, not an omission.
- **Dismiss as a non-issue** — the adversary was wrong (a false positive, or a case
  the spec already covers elsewhere). Say why in one line and move on.

Then ask ONE AskUserQuestion batch (bare options when headless); the handoff waits:

- **Own question**: each `blocker`, each failure & security lens hole, any hole
  touching auth or stored data (loss, corruption, schema or migration, personal data)
  whatever its lens, each statement-fidelity hole — the three resolutions, the
  recommended one first, marked (Recommended).
- **One shared question** for the rest: "Apply the recommended resolution for these N
  holes?" → "Apply all (Recommended)" / "Walk through each" (each then asked as above).
- At most four questions per batch; overflow goes into a second batch.

Loop until every hole is amended, accepted, or dismissed. Then continue to
task-cards on the hardened spec.

The conflicts lens carries a **statement-fidelity sub-check** — active only when the
spec header holds the labeled `**Raw prompt:**` / `**Upgraded statement:**` pair — that
attacks the upgrade for scope the raw ask never carried (added, dropped, or swapped).
A fidelity hole always takes its own question; under goal (hands-off) mode it is never
auto-accepted: no user is present to ratify a wrong sharpening, so amend the spec —
or halt with evidence if unamendable (the ultra-goal contract's never-auto-accept
rule; dismiss remains reserved for demonstrated false positives).

## Minor holes

Minor holes ride the shared question unless a rule above gives one its own — a pile of
nitpicks must not block the handoff, or the gate becomes noise the user learns to skip.
A minor-only return (none own-question) asks nothing: record each in the spec as
Accept as a known risk, amend nothing unasked, say so in one line and proceed.

## After amendments

Amendments change the spec, so re-confirm they hold — but scale the re-check to the
change. A blocker closed by adding an idempotency requirement needs a quick re-read
of that section, not a fresh subagent. Re-dispatch the adversary only when the
amendments were broad enough to plausibly open new holes — a reworked data model, a
new external dependency, a criterion rewritten wholesale. Otherwise, confirm the
edits actually landed in the spec file and continue to task-cards.

A re-dispatch gets the spec path plus the prior holes list with each one's resolution
(never the conversation), and reports only prior holes the amendments left open and new
holes in the amended sections. A blind second pass re-attacks the whole spec and
measures its size, not whether the fixes held.

## Worked example

A payments-webhook spec with four criteria and an external provider fires the gate.
Holes: a **blocker** (idempotency unstated, though delivery is at-least-once), a
**major** (no behavior on a bad signature — auth) and a **minor** ("handles load", no
number). The first two get their own questions, recommending Amend (an idempotency
key; a 401); the minor rides the shared question as Accept. Then cards.

## Anti-patterns

- **Running on a trivial spec — unboosted.** Under a boost it runs regardless (§ the gate's Exception).
- **Passing the grill conversation to the agent.** Blindness is the mechanism; feed
  it only the spec path.
- **Treating a dismiss as a failure.** The adversary produces judgment; a wrong hole
  dismissed with a reason is the system working, not a miss.
- **Blocking on minor-only holes.** They are recorded, not gated.
- **Batching an own-question hole.** A blocker, security, data or fidelity hole in
  "Apply all" is accepted unread.
- **Amending only in the conversation.** Cards are cut from the spec file.
- **Letting the adversary propose the approach or write code.** It surfaces holes;
  the pipeline decides everything else.
