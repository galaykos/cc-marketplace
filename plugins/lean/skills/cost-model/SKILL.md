---
name: cost-model
description: Use when writing code, tests, or comments, when deciding how much to build, or when deciding how much process a task deserves — one bar per cost surface (code, tests, comments, files, actions), hold the minimum unless one of four named triggers buys more, and name the trigger at the excess.
---

## The rule

Every line of code, every test, every comment, every file, and every action is a
debit. It is paid once at write time and then again at every read, review, merge
and CI run for as long as it exists. The default is the smallest thing that clears
the bar. More is allowed and often right — but it must say why.

## Five surfaces, five bars

| Surface | The minimum that clears the bar |
|---|---|
| Code | the stated requirement works. Not it plus its plausible neighbours. |
| Tests | every behaviour that could break has a test that fails first; a second test for the same break earns its place only by catching it sooner or more precisely |
| Comments | a reader cannot recover this from the code, the name, the type, or the test |
| Files / artifacts | it carries a rule or behaviour nothing else carries |
| Actions — tool calls, subagent spawns, verify passes, ceremony stages | its result can change what happens next |

The action row is the one nothing else in this marketplace prices. A fan-out of four
agents where one would do buys four transcripts of the same answer, and the reader pays
to reconcile them. A re-read of a file you have already read **this turn and have not
edited since** is a debit with no credit — after a compaction, after any write, or when
another worker may have touched it, re-reading is the cheap option and guessing is not.

**The action bar never overrides a check you were given.** A gate, a hook, a card's
`Verify` command, a test suite, a review pass someone else's contract requires: those are
not yours to price. "Its result cannot change what happens next" applies to work you are
choosing to add, never to a check already asked for — the whole value of a gate is that
it runs when you are confident it will pass. Using this row to skip one is the single
worst misreading of this skill, and it converts a cost doctrine into an excuse.

## The four triggers that buy more

Closed list. Exactly these four:

1. **Blast radius** — auth, money, data migration, concurrency, PII, irreversible ops.
2. **An observed defect** — a real failure, a surviving mutation, a shipped incident.
3. **A stated criterion the minimum does not satisfy.**
4. **The user asked for it.**

## Not triggers

"To be safe." "While I'm here." Symmetry with the file next door. A number someone
wrote down. A category existing — an `integration/` directory is not a reason to add
an integration test, and a template section is not a reason to fill it. A coverage
percentage. Thoroughness as a virtue. The fact that a skill *lists* a technique — a
catalogue of options is not a checklist to exhaust. That is a rule about how to read a
menu of techniques, not a licence to skip a skill: when a card, a hook, or a command
tells you to read one, read it and apply what fits.

## The escalation record

Exceeding the minimum is not the failure. **Unnamed** excess is. Name the trigger in
one clause, at the point of the excess — in the comment, the test name, the commit
body, or the turn-final message:

- `// bounded retry: money path, a double charge is unrecoverable` — blast radius
- `test_expiry_boundary_off_by_one` "regression, shipped incident" — observed defect
- "Three reviewers because the spec names three independent criteria" — stated criterion

A reader must be able to see which of the four bought it without asking. If you
cannot write the clause, you do not have a trigger — cut back to the bar. And when
you hold the minimum against a temptation, say what you cut in one line; a reader
who cannot see the road not taken will ask for it again next turn.

## Safety clause — non-negotiable

**"Minimum" is defined by risk coverage, not by count.** A rule that produces
under-testing has failed, not succeeded. Never delete a test to hit a ratio. Protect
absolutely: a test that exists because a real defect or a surviving mutation proved
the suite missed it; a regression test for a shipped incident; the only proof of a
security boundary. A ratio is a prompt to look, never a licence to cut.

**Deleting a test is the owner's call, not yours.** Produce the list — what each test
proves and which other test already proves it — and let them decide. And the minimum is
floored by whatever already runs: a card's `Verify` must still name a real test or
asserted outcome, and a control that fails to discriminate is a gap to close, not fat to
trim. This doctrine argues about what to ADD. It never argues a gate DOWN.

## What this owns, and standing

Owns **how much**, across all five surfaces at once, and the cost of **actions**.
For the *what*, go to the surface owners: `comment-discipline:comment-discipline`,
`testing:testing-best-practices`, `code-architecture:yagni-check`,
`code-architecture:low-cognitive-load`.

Evidence — `testing:testing-best-practices` `references/proportionality.md` measured
a 30-card run at **3.44 : 1** test-to-code against the same repository's own
**0.78–1.31 : 1** (~3x), and **520 tests for an integration comparable to an existing
65-test one** (8x), every gate green.

Standing: agent-graded and recorded — a reviewer applies this, nothing reads it back.
The one mechanical delivery is this plugin's warn-only `PostToolUse` hook:
`additionalContext` does not block, it arrives after the write that triggered it, and
it cannot see a fan-out's aggregate. There is deliberately no blocking volume gate — a
line- or test-count threshold would fire on dense work and wave through a bloated diff
under the number. Proportionality and Admission are the laws applied:
`claude-authoring/skills/authoring-skills/SKILL.md`, "The four laws".
