# Does skill-listing eviction actually stop a skill from firing?

**Measured 2026-09-15, CLI 2.1.272. Answer: no — 47/55 vs 47/55, zero delta.**

## Why this was measured

Four bundle READMEs, `scripts/context-budget.sh`'s listing channel, `pc_listing_declaration`,
and a six-agent audit of "can all 31 plugins be installed globally" all rest on one claim:

> Over budget the CLI reduces entries to name-only and buys descriptions back in priority
> order — no error, no log; **skills silently stop being reachable.**

The arithmetic behind it is sound and independently reproduced: all 31 installed costs about
6.4x the default 200k budget, and the name-only floor alone is ~75% of it. What nobody had
checked is the second half of the sentence — whether a name-only entry actually stops firing.
That is a behavioural claim, and this repository's own eval doctrine says a grader passing
proves nothing about a skill unless a control arm shows the base model failing the same
prompt. The claim had no control arm. It has one now.

## Method

A skill's listing entry is built from its frontmatter `description`. The faithful simulation
of an evicted entry is therefore a SKILL.md with the `description` key absent: same name, same
body, no description text reaching the model. Two arms per condition, identical but for that
key. The skill body instructs the model to reply with a unique token as its first line, so
firing is detected exactly rather than judged.

Scratch project skills under `.claude/skills/`, run headless with
`claude -p "<prompt>" --permission-mode bypassPermissions`. In the two large conditions the
scratch project sets `skillListingBudgetFraction: 0.2` so the CLI's OWN eviction cannot
confound the arms — the only manipulated variable is the target's description.

Target skill: `reuse-hygiene`, a real shipped skill name, deliberately one whose name does not
spell out its trigger. Prompt: *"There is an existing formatPrice() helper in src/utils. I am
going to call it from the new checkout page I am writing."*

## Results

| # | condition | with-desc | name-only |
|---|---|---|---|
| 1 | 1 skill, self-describing name (`redact-invoice-pdf`) | 5/5 | 5/5 |
| 2 | 1 skill, opaque name (`reuse-hygiene`) | 5/5 | 5/5 |
| 3 | 13 skills — 12 described decoys | 20/20 | 19/20 |
| 4 | 226 skills — 225 described decoys | 10/10 | 10/10 |
| 5 | 205 skills — 8 rivals contesting the SAME territory | 7/10 | **8/10** |
| | **total** | **47/55** | **47/55** |

Negative control: the target fired 0/3 on "What is the capital of Portugal?", so the harness
discriminates rather than always-fires.

In condition 5 the name-only arm scored HIGHER than the control. That is noise, and it is the
clearest available evidence that the delta is zero rather than merely small.

## What this does and does not establish

**Established:** removing a skill's description from what the model sees does not measurably
reduce how often it fires — not at 1 skill, not at 226, and not against rivals contesting its
exact territory. The "silently stop being reachable" half of the claim is not supported.

**Also established, and more useful:** condition 5 is the only one where firing dropped, and it
dropped in BOTH arms — 100% to ~75% — when eight semantically adjacent skills competed. What
costs a marketplace is OVERLAP, not bytes. This independently prices what the audit found by
reading: twelve review-phase agents whose triggers match one `.tsx` diff, eleven skills
claiming "animate this". The case for consolidating `craft-layer`'s 18 entries, `ui-ux`'s 15
and `taskmaster`'s 15 is real — but the reason is disambiguation, and the byte framing would
have led someone to trim DESCRIPTIONS, which this measures as useless.

**Not established.** One model, one target skill, one prompt shape per condition, n=55 total.
It measures TRIGGERING only — not whether the work that followed was as good, which is the
thing descriptions might plausibly help with and which this does not touch. The target's name
stayed meaningful in every arm, so this is evidence that a good NAME carries the trigger, not
that names are free. A skill named `sk-0042` would very likely behave differently.

**Deliberately not acted on.** Nothing was ripped out on the strength of n=55. The bundle
READMEs still recommend `skillListingBudgetFraction`, and `pc_listing_declaration` still gates
that a bundle over the floor says so. That advice is now known to rest on a weaker premise than
it claims, and the honest response to one measurement contradicting doctrine is to record it
and re-check, not to delete the gate — this repository has already withdrawn one NEGATIVE
delta that three runs agreed on and three more runs a day later did not
(`rationale/marketplace-endgame-review-2026-09-14.md` §8 wave D).

## Reproducing

`bash scripts/smoke/listing-eviction-probe.sh` — deliberately NOT a CI step, for the same
reason `scripts/smoke/canary.sh` is not: it needs a live model and costs real tokens. It builds
all five conditions, runs both arms, and prints the table above.
