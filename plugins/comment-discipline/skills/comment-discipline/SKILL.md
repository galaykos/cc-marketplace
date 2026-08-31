---
name: comment-discipline
description: Use when writing or reviewing code and deciding whether a comment should exist — route each fact to the artifact that cannot lie about it; keep only why-comments, external constraints, intentional-silence markers, and contract facts a signature cannot state.
---

## Core rule

Over-commenting is not a comment problem. It is an information-routing problem.
Every comment is a fact someone thought a future reader would need, filed in the
one place nothing checks. Names are read at every call site, types are checked by
a compiler, tests fail when they lie — a comment drifts in silence and is still
there, confidently wrong, three refactors later.

So the rule is not "write fewer comments". It is: **put each fact where it cannot
lie, and comment only what has nowhere else to live.** Done properly this gives a
future reader — human or AI — more reliable context, not less. The information
does not disappear; it moves somewhere that is verified.

Before writing a comment, ask: what fact am I recording, and does the code already
have a slot for it?

## The routing table

| Information | Belongs in | Comment? |
|---|---|---|
| What the code does | the function or variable name | no |
| Shape of data | types, signatures | no |
| Expected behavior, edge cases | tests | no |
| Sequence of steps | extracted, named functions | no |
| Why this way and not the obvious way | comment | **yes** |
| External constraint, upstream bug, perf measurement | comment + link or ticket | **yes** |
| Deliberate no-op — empty catch, fallthrough, unused-but-required param | comment | **yes** |
| Units, ownership, lifetime, thrown conditions the signature cannot express | docblock | **yes** |
| Architecture, specs, decisions | ADRs and project docs | no |

The left column is what people usually comment; the right column is why most of
those comments should not exist — the fact was already recordable somewhere better.

## Kill-cases

**Restatement.** A comment whose content is derivable from the line under it.
Cue: reading the comment then the code teaches you nothing twice.

    // increment the counter
    counter++;

**Section banners.** `// ===== HELPERS =====` inside a file. Cue: the banner is
doing a job a file split or a class should be doing. If a file needs internal
signposting to navigate, the file is the problem.

**Commented-out code.** Cue: a comment body that would parse as a statement.
Git remembers it; the file should not. Dead code that reads as live code is worse
than dead code that reads as dead.

**Bare TODO / FIXME / XXX.** Cue: no ticket ID, no URL, no owner. A TODO with no
tracker entry is a wish with a timestamp — nobody will ever grep for it on the day
it matters.

**Docblock tags that restate the signature.** `@param $id The id`, `@return void`
with nothing else, `:param x: x`. Cue: deleting the tag loses nothing.

**Changelog and change-narration comments.** `// modified by A. 2024-03-11`,
`// now correctly handles null`, `// updated to use the new API`, `// fix per review`.
Cue: the comment describes the edit — author, correctness, the review that asked — not
the code: the diff addressing its reviewer, stale the moment it merges. Version control
owns history. A constraint that survives the edit is stated as a standing fact
("setTimeout, not rAF: rAF throttles in background tabs"), never as a change event.

**Comments compensating for a name.** `// list of users who have not paid yet`
above `const list = ...`. Cue: the comment is a better name than the name.

## Keep-cases

These are the comments worth defending in review. The list is closed — anything
outside it should first be tried as a rename, a type, a test, or an extraction.

- **Why this and not the obvious thing.** The alternative you rejected and the
  reason. This is the one fact that is genuinely unrecoverable from code: the
  code shows what you did, never what you decided against.
- **External constraint or upstream bug**, with a link or ticket. Vendor quirk,
  spec oddity, browser bug, a measured performance result. The link is not
  optional — it is what lets a future reader check whether the constraint still
  holds and delete the workaround.
- **Intentional-silence markers.** An empty catch, a deliberate fallthrough, an
  unused-but-required parameter. Here the *absence* of code is the decision, and
  absence cannot be named or typed. Say why ignoring is safe.
- **TODO carrying a ticket ID.** `// TODO(BILL-412): drop once v2 rollout completes`.
- **Contract facts a signature cannot express.** Units (`milliseconds`, `minor
  currency units`), ownership and lifetime ("caller must close"), which conditions
  throw, and array or object shapes the type system cannot state.

## A comment that asserts behavior is a claim

The keep-cases license prose about why, and prose is where an unimplemented
intention hides most comfortably. "Settles in either direction", "the server
renders this fully", "never blocks": each states an invariant the next reader
now trusts instead of checking.

Before such a comment ships, either the code plainly implements it or a test does —
sounding sure waives neither. A comment describing behavior the code lacks is worse
than none: it stops the one reader who would have noticed.

## Refactor instead of commenting

Most comments are a refactor someone did not have time for. The move is usually
mechanical:

| The comment you were about to write | Do this instead |
|---|---|
| explains what a block does | extract it into a named function |
| explains what a variable holds | rename the variable |
| explains the shape of a value | give it a type |
| explains what happens on an edge case | write the test |
| explains a clever one-liner | write the boring version |
| labels a region of a file | split the file |

Two guards on this. First, do not rename into a paragraph: `getUsersWhoHaveNotPaidYetAndAreActive`
is a comment wearing a name's clothes — split the concept rather than lengthening it.
Second, an extraction that exists only to host a comment, called once and never
reused, may be worse than the comment; extract to name a coherent step, not to
launder prose.

## Docblocks

One rule, every language: **a docblock earns its place only for what the signature
cannot express.** Types beat doc-comment lies — a typed parameter is checked, an
`@param` is not, and when they disagree the comment is what people believe.

    /** @param int $userId The user id. @return void */   // delete: the signature says this
    /** Timeout in milliseconds. Throws on a closed pool; caller owns the handle. */  // keep

The same test applies to a TSDoc block, a Python docstring, a godoc line, a
`///` in Rust: strip everything the signature already states, and keep whatever
survives — usually units, ownership, throw conditions, or an example for a
genuinely non-obvious call. Often nothing survives; a fine outcome, not a gap.

Public-API docs generated for external consumers are a product surface with its
own audience, not a comment; that is a docs decision, not this rule's.

## Boundaries

Standing: recorded — owns comment volume and placement. The one-bullet version is
`code-review`'s code-smells; doc/comment staleness is api-docs-first's
`docs-upkeep`; naming and extraction are `code-architecture`, the destination a
comment's content moves to.

## What is enforced, and what is advice

Not all seven kill-cases carry the same standing. This plugin ships hooks:

- **gate** — a comment restating the next line, and commented-out code, are
  **denied before the write** by the `PreToolUse` lane of `hooks/scan.sh`. Bounded:
  one deny per file per session, so a false positive costs one turn and never
  wedges a run.
- **agent-graded** — the other five (banners, bare TODOs, signature-repeating
  docblock tags, change-narration, missing why-comments) are `PostToolUse` warnings.
  They are house-style calls a reviewer judges; a TODO can be a legitimate mid-task
  marker.
- **recorded** — everything else here. Nothing reads it back.

`hooks/density.sh` separately warns when a file's comment ratio is far from its
neighbours'. That is **not** in tension with the anti-pattern below: measuring a
ratio to find a file worth reading is not deleting comments to hit one.

## Anti-patterns

- Deleting comments to hit a ratio — the keep-cases are where the real value is.
  (Measuring the ratio is fine, and `hooks/density.sh` does; acting on the number
  instead of the comments is the anti-pattern.)
- Asking "should this be commented?" before "can it be named, typed, or tested instead?"
- A constraint comment with no link, so nobody can ever prove it obsolete.
