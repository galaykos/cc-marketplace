---
name: verification-panels
description: Use when deciding whether agent findings can be trusted, verifying subagent output, planning a review fan-out, judging competing solutions, or when discovery may stop too early — cost-gated refuter voting, judge panels over independent attempts, loop-until-dry discovery, completeness-critic passes.
---

# Verification Panels

Single-agent review accepts plausible-but-wrong, because plausible is what
generated output is optimized to be. A panel of independent agents buys
accuracy with tokens — spend those tokens only where wrongness is expensive.

## The cost gate

This section comes first deliberately: the default verification for any
output is still ONE reviewer. A panel is an escalation, and it must be
paid for. Convene one only when the output clears at least one bar:

- **High blast radius.** The output drives an irreversible action, a
  security finding someone will act on, an architecture pick that locks
  in months of work, a production data change.
- **Prone to plausible-but-wrong.** The output class is one where a
  confident wrong answer reads identically to a right one: subtle bug
  reports, root-cause claims, "this code is unused" assertions,
  performance attributions.

Everything else — typo fixes, formatting, mechanical renames, output you
will immediately verify by running it — gets one reviewer or none. A
five-agent panel voting on a typo fix is theater: it costs real tokens,
delays the change, and teaches everyone to ignore panel verdicts.

## Refuter voting

For a single finding whose truth matters: spawn N independent skeptics,
each prompted to REFUTE it, never to confirm it. The prompt shape is
adversarial by construction — "here is a claim and its evidence; try to
disprove it; when uncertain, default to refuted." Majority-refute kills
the finding.

Two design rules carry the whole mechanism:

- **Diverse lenses, not clones.** Give each refuter a different attack
  angle — one checks correctness of the reasoning, one checks security
  implications, one tries to actually reproduce the claim. N identical
  refuters share the same blind spots and fail in unison; diversity
  catches the failure modes N copies of one skeptic cannot.
- **Independence is the point.** Each refuter gets the finding and the
  raw evidence — never another panelist's verdict. The moment refuter
  two sees refuter one's "confirmed", you have one opinion echoed N
  times, and the vote measures anchoring, not truth.

## Judge panels

Refuters test a claim that already exists. When the solution space is
wide open — "design this API", "pick the migration strategy", "name this
abstraction" — there is no single claim to attack. Use a judge panel:

1. Spawn N attempts from deliberately different angles: MVP-first,
   risk-first, user-first. The angle assignment forces the attempts
   apart; N unconstrained attempts converge on the same median answer.
2. Spawn parallel judges that score every attempt against the stated
   criteria. Judges see all attempts; attempts never see each other.
3. Synthesize from the winning attempt, grafting in the runner-up ideas
   the judges scored stronger than the winner's equivalent part.

This beats one-attempt-then-iterate exactly when the SHAPE of the answer
is genuinely open. Iteration refines a shape; it rarely escapes one.

## Loop until dry

Discovery tasks — find the bugs, find the violations, find the edge
cases — have unknown size. A fixed quota ("find 10 issues") stops at 10
whether the codebase holds 6 or 60; the tail is where the worst findings
live. Loop instead:

1. Spawn a round of finders. Collect findings.
2. Dedup the round against everything SEEN so far — every finding from
   every prior round, including the ones a judge or refuter rejected.
3. If two consecutive rounds produce nothing new, the well is dry; stop.
   Stop at **3 rounds** regardless — a capped-at-3-rounds ceiling, whichever comes
   first. Two-dry is the quality exit; the cap is the bound that keeps a diff which
   keeps surfacing findings from looping forever. Consumers that already state a cap
   (`taskmaster:ultra`, `orchestration:ultra-assess`) match this; consumers that
   re-derive their own loop do not inherit it.

The dedup rule is load-bearing. Dedup against confirmed findings only,
and every judge-rejected finding is "new" again next round: finders keep
resurfacing it, no round ever comes up empty, and the loop never
converges. SEEN means seen, not accepted.

## Completeness critic

Refuters and judges evaluate what was produced; nobody above asks what
was never produced. Close with one final agent whose only question is
"what is missing?" — an angle nobody searched, a claim asserted but
never verified, a file everyone reasoned about but nobody read, an
input class no attempt handled.

Its output is a work-list, not a verdict. Each gap it names becomes the
next round's tasking: a new finder angle, a new refuter target, a file
to actually read. A critic that answers "looks complete" on the first
pass has not completed a check — it is a rubber stamp wearing a critic's
prompt, and it means the question was framed to invite approval.

## Anti-patterns

- **Panel theater.** Five agents voting on a typo fix — the cost gate
  exists so panels stay credible where they matter.
- **Confirmation-prompted "refuters".** "Please verify this finding is
  correct" produces agreeable validators; a refuter must be told to
  disprove, with refuted as the tie-break default.
- **Identical-refuter redundancy.** N copies of the same prompt share
  the same blind spots; you paid N times for one opinion.
- **Sharing verdicts between panelists.** One anchored opinion echoed N
  times; independence is the entire mechanism.
- **Dedup against confirmed only.** Rejected findings resurface every
  round and the discovery loop never converges — dedup against SEEN.
- **Critic as rubber stamp.** A completeness pass that returns "all
  good" without naming a single unchecked angle checked nothing.
