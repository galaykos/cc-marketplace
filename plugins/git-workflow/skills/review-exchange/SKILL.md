---
name: review-exchange
description: Use when requesting a code review or acting on one received — evidence discipline on both sides: self-review plus a context-rich, readable-size request; comment-as-claim verification, evidence-backed pushback, full-suite re-run when receiving.
---

## Review is an exchange of claims

A review request claims "this change does X and I verified it"; review
feedback claims "this code has problem Y". Neither claim is self-certifying.
The discipline on both sides is the same: back your own claims with evidence,
and verify everyone else's before acting on them.

## Requesting: self-review first

Read the entire diff — `git diff "$BASE...HEAD"`, hunk by hunk — before anyone
else does. Self-review reliably catches the embarrassing third of findings:
debug prints, commented-out blocks, leftover TODOs, an accidentally committed
fixture, a rename half-applied. Every one of those a reviewer finds instead
costs a round-trip and spends credibility that real design questions need.
If the diff surprises its own author anywhere, fix that before requesting.

## What the request contains

Three things, none optional:

1. **What the change does** — behavior and intent, not a file list. The diff
   already shows the files.
2. **What you are unsure about** — the design tradeoff, the edge case, the
   locking assumption. Naming doubts is not weakness; it aims the review where
   it pays. A request with no stated uncertainty invites a shallow pass.
3. **How it was verified** — the exact commands run and their results, not
   "tests pass". The reviewer should be able to distinguish tested from
   hoped-for.

## Small diffs get real reviews

Review quality falls off a cliff with size: a 200-line diff gets read, a
2000-line dump gets skimmed and stamped. Large change → split into reviewable
stages (refactor first, behavior second is the classic cut). If it truly
cannot be split, say which files carry the substance and which are mechanical
churn, so attention lands where it matters.

## Point at the risk

Risk concentrates — the auth boundary, the migration, the concurrency-touched
handler, the money math. Name those hot spots in the request. A reviewer's
attention is a budget; the requester knows better than anyone where it should
be spent, and silence spends it evenly across rename noise.

## Receiving: feedback is a claim, not a command

Each comment gets verified before it gets implemented:

- **Read the referenced code** — the actual lines, plus enough surroundings to
  know why they are the way they are. Reviewers work from the diff hunk; the
  context may already answer their point.
- **Check the suggestion works** — apply it mentally or literally, then
  compile and run the relevant tests. Suggested code that does not build is
  common and not malicious; reviewers type into text boxes.
- **Check the callers** — a signature change, a tightened type, a removed
  branch: grep every call site before agreeing the change is safe.

Verification has three outcomes: the comment is right (implement it), the
comment is wrong (push back), or it cannot be verified with what is at hand —
say so explicitly and ask, rather than guessing in either direction.

## Implement what survives, one at a time

Apply surviving items individually, testing after each, in this order:
blocking defects, then trivial fixes, then structural changes. Never sweep a
batch of suggestions into one commit in one pass — when the suite breaks, the
culprit is now any of nine edits, and untangling costs more than the sequence
would have. If any item in the batch is unclear, clarify before implementing
ANY of it; comments interlock, and partial understanding produces confident
wrong fixes.

## Pushing back

When verification fails, say so — respectfully, technically, specifically:
the file and line checked, the test that passes, the caller that would break,
the platform constraint that forces the current shape. "This suggestion breaks
the three call sites in src/billing/ that rely on the null return" is
pushback; "I think it's fine as is" is a shrug. And if later evidence proves
the pushback wrong, state the correction plainly and implement — no essay.

## Blocking defects vs preferences

Correctness, security, data loss, broken contracts: blocking — fix before
merge, no negotiation. Naming taste, structural style, "I would have used a
map here": preferences — worth considering, fine to decline with a reason.
Label which is which in both directions; treating preferences as blockers
stalls work, and treating defects as preferences ships them.

## After applying

Re-run the FULL suite, not just the tests near the touched lines. Review fixes
are edits made under social pressure with attention on the reviewer, not the
system — exactly the conditions that produce regressions two modules away.
The change that goes back for re-review is the verified one, and the reply
says what changed and how it was re-verified, not just "done".

## Anti-patterns

- Requesting review of a diff its author has not read end to end.
- "Tests pass" with no command and no output as the verification story.
- A 2000-line request with no map of where the substance lives.
- Blind-applying every comment in one sweep, then debugging the pile.
- Performative agreement — "you're absolutely right!" — instead of
  verification; agreement is an output of checking, not a greeting.
- Pushing back from memory or pride rather than from a file, a line, a test.
- Silently dropping a comment neither implemented nor answered.
- Re-running only the touched tests after applying feedback and calling the
  branch re-verified.
