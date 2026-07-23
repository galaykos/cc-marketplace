---
name: spec-redteam
description: Use after grill writes a spec and before task-cards, when blast radius warrants — dispatches blind adversaries against the frozen spec (edge cases, unstated assumptions, conflicts, underspecified requirements, failure/security gaps, visual coherence) and resolves each before cards.
---

## Where this sits

Between spec-freeze and task-cards. grill removes ambiguity by asking the user
questions — but the user and the model share blind spots, so a requirement neither
questioned reaches the spec unchallenged. This pass attacks the frozen spec itself,
with fresh eyes, before it hardens into cards. It is distinct from coverage-check
(which checks cards against the spec's criteria, assuming those criteria are right)
and from opinion-round (which argues the approach, not the requirements).

## How this differs from its neighbors

Several passes cluster around spec-freeze; keep them distinct:

- **plan-before-code** (code-architecture) checks the file-level plan — which files
  change, unit ownership, interfaces. It assumes the requirements are right. Run the
  red-team BEFORE it: attack the requirements, then plan the files that satisfy them.
- **coverage-check** (later, at the tail of task-cards) checks that the cards cover
  the spec's success criteria. It assumes those criteria are themselves correct and
  complete — which is exactly what this pass questions.
- **opinion-round** argues which approach to take. This pass is indifferent to
  approach; a spec hole is a hole whichever way the spec is built.
- **grill** surfaced ambiguity the user could answer. This surfaces what neither the
  user nor the model thought to ask.

## The blast-radius gate

A red-team is not free — run it only when the spec warrants it. Run when ANY holds:

- the spec has **three or more success criteria**, or
- it **touches more than one module or directory**, or
- it mentions a **security, auth, data, or external surface**, or
- it carries any **ASSUMED (unconfirmed) row**.

Otherwise the spec is trivial for this purpose — note "spec trivial for red-team —
skipped" in one line and let the handoff proceed. Matches grill's own scale-to-
blast-radius doctrine; a one-file, two-criterion spec does not earn a subagent.

## Dispatch the adversary — blind

When the gate is met, dispatch the `spec-adversary` agent with **only the spec file
path**. Do not pass it the grill conversation, the design doc, or your own summary —
its value is that it reads the requirements cold and finds what the dialogue missed.
Passing it the conversation re-imports the blind spots you are trying to escape.

**Role-tier floor — boosted or not.** `spec-adversary` carries a row in
`orchestration:delegation-contracts` `references/role-floors.md`, so dispatch it at
`max(marker tier if present ELSE the session model, opus)`. Never omit `model:` in a
session above opus: an adversary weaker than the model that wrote the spec is a weak
gate on exactly the specs that most need one. Registry unresolved → omit `model:` and
note `role-floors.md unresolved — floors not applied`.

## The panel — ultra only

Under `ULTRA-TASK ACTIVE` and when the `Workflow` tool is present, this is a **blind
panel**, not a single adversary — the width `ultra/SKILL.md` and `/taskmaster:redteam`
already promise. Unboosted runs keep the single adversary above; nothing here changes a
standard run.

Size N by the gate conditions already computed above — `dispatch-tiers.md` § Fan-out
sizing owns panel N, but keys off *files the change touches*, which does not exist yet at
spec-freeze. The four gate bullets are the radius proxy at this step. Apply in order,
first match wins:

1. The **security/auth/data/external-surface** bullet fires, **or two or more** bullets
   fire → **3 adversaries**.
2. Exactly one non-security bullet fires → **2 adversaries**.
3. Zero bullets fire but ultra forces the run (`run ALWAYS`) → **2 adversaries**.
4. No `Workflow` tool → **1** inline adversary. Today's path, unchanged.

Count the four bullets as four; the security bullet is ONE disjunction counted once, not
once per surface named in it. Every panel member is blind and independent — each gets only
the spec path, never another member's findings — then dedupe holes across the panel before
presenting. These counts are ceilings, not quotas.

The agent returns a structured holes list grouped by lens, each hole tagged
`blocker | major | minor` with a section, the hole, and a suggested fix.

## Present and resolve — blocking

Present the holes grouped by lens. Then resolve each before task-cards runs; the
handoff waits. Per hole, offer a choice (AskUserQuestion; bare options when
headless):

- **Amend the spec** — the hole is real; edit the spec file to close it (add the
  missing edge case, state the assumption, resolve the conflict, specify the failure
  or security behavior). The amendment lands in the spec, not just the conversation.
- **Accept as a known risk** — the hole is real but out of scope this round; record
  it in the spec (a one-line note under the relevant section or non-goals) with the
  reason, so it is a decision, not an omission.
- **Dismiss as a non-issue** — the adversary was wrong (a false positive, or a case
  the spec already covers elsewhere). Say why in one line and move on.

Loop until every hole is amended, accepted, or dismissed. Then continue to
task-cards on the hardened spec.

The conflicts lens carries a **statement-fidelity sub-check** — active only when the
spec header holds the labeled `**Raw prompt:**` / `**Upgraded statement:**` pair — that
attacks the upgrade for scope the raw ask never carried (added, dropped, or swapped).
Route a fidelity hole like any conflict, except under goal (hands-off) mode it is never
auto-accepted: no user is present to ratify a wrong sharpening, so amend the spec —
or halt with evidence if unamendable (the ultra-goal contract's never-auto-accept
rule; dismiss remains reserved for demonstrated false positives).

## Minor holes

Blocker and major holes always go through the resolution loop. Minor holes may be
presented together and waved through with a single acknowledgement — do not block
the handoff on a pile of nitpicks, or the gate becomes noise the user learns to
skip. If the agent returns only minor holes, summarize them and proceed.

## After amendments

Amendments change the spec, so re-confirm they hold — but scale the re-check to the
change. A blocker closed by adding an idempotency requirement needs a quick re-read
of that section, not a fresh subagent. Re-dispatch the adversary only when the
amendments were broad enough to plausibly open new holes — a reworked data model, a
new external dependency, a criterion rewritten wholesale. Otherwise, confirm the
edits actually landed in the spec file and continue to task-cards.

## Worked example

A spec for a payments webhook handler has four success criteria and mentions an
external provider — the gate fires. The adversary returns: a **blocker** (unstated
assumption — the spec never says the webhook is idempotent, but at-least-once
delivery is the provider's contract), a **major** (missing edge case — no behavior
for a signature-verification failure), and a **minor** (a criterion that says
"handles load" without a number). Resolve: amend the spec to require an idempotency
key and to reject bad signatures with a 401; note the load criterion as needing a
figure. Then cards.

## Anti-patterns

- **Running on a trivial spec.** The gate exists so the red-team fires where it pays
  off, not on every two-line change.
- **Passing the grill conversation to the agent.** Blindness is the mechanism; feed
  it only the spec path.
- **Treating a dismiss as a failure.** The adversary produces judgment; a wrong hole
  dismissed with a reason is the system working, not a miss.
- **Blocking on minor-only holes.** Nitpicks are noted and waved through, not gated.
- **Amending only in the conversation.** A resolution that does not change the spec
  file is lost the moment cards are cut from the unamended spec.
- **Letting the adversary propose the approach or write code.** It surfaces holes;
  the pipeline decides everything else.
