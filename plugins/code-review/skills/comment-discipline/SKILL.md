---
name: comment-discipline
description: Use when writing or reviewing code and deciding whether a comment or docblock should exist — the default is none; the code carries the meaning through names, types, tests and extraction. Keep only why-comments, linked external constraints, intentional-silence markers, and one-line docblock facts a signature cannot state. A project house style in CLAUDE.md overrides the default; nothing else does.
---

## Core rule

**The default is no comment.** Code speaks for itself: a name says what, a type says
the shape, a test says the edge case, an extracted function says the step. A comment
is a fact filed in the one place nothing checks — names are read at every call site,
types are checked by a compiler, tests fail when they lie, and a comment drifts in
silence and is still there, confidently wrong, three refactors later.

So before writing one, ask: what fact am I recording, and does the code already have a
slot for it? Almost always it does. Route the fact there and write nothing. A comment
survives only when it carries a fact with nowhere else to live, and then it is one
line, not a paragraph.

**"Unless specified."** A project that states a heavier house style in its `CLAUDE.md`
(docblocks on every public method, a documented public API) gets that style. Absent
such a statement, minimal is the rule, and "the surrounding file has many comments"
is not a specification — it is the drift this rule exists to stop.

## The routing table

| Information | Belongs in | Comment? |
|---|---|---|
| What the code does | the function or variable name | no |
| Shape of data | types, signatures | no |
| Expected behavior, edge cases | tests | no |
| Sequence of steps | extracted, named functions | no |
| Architecture, specs, decisions | ADRs and project docs | no |
| Why this way and not the obvious way | one-line comment | **yes** |
| External constraint, upstream bug, perf measurement | one-line comment + link or ticket | **yes** |
| Deliberate no-op — empty catch, fallthrough, unused-but-required param | one-line comment | **yes** |
| Units, ownership, lifetime, thrown conditions the signature cannot express | one-line docblock | **yes** |

The left column is what people usually comment; the right column is why most of
those comments should not exist — the fact was already recordable somewhere better.

## Kill-cases

**Restatement.** A comment whose content is derivable from the line under it.
Cue: reading the comment then the code teaches you nothing twice.

    // increment the counter
    counter++;

**Docblocks that restate the signature.** `@param $id The id`, `@return void`,
`:param x: x`, a summary line that repeats the method name (`/** Get the user. */`
above `getUser()`). Cue: deleting the block loses nothing. This is the shape most
over-commenting takes in generated code: a full block per method, every tag filled in.

**Section banners.** `// ===== HELPERS =====` inside a file. Cue: the banner is
doing a job a file split or a class should be doing.

**Commented-out code.** Cue: a comment body that would parse as a statement.
Git remembers it; the file should not.

**Bare TODO / FIXME / XXX.** Cue: no ticket ID, no URL, no owner. A TODO with no
tracker entry is a wish with a timestamp.

**Changelog and change-narration comments.** `// modified by A. 2024-03-11`,
`// now correctly handles null`, `// fix per review`. Cue: the comment describes the
edit, not the code — the diff addressing its reviewer, stale the moment it merges.
A constraint that survives the edit is stated as a standing fact, never as a change event.

**Comments compensating for a name.** `// list of users who have not paid yet`
above `const list = ...`. Cue: the comment is a better name than the name.

**Reasoning narration.** Three lines above a method explaining the design decision at
length. Cue: it reads like the pull request description. One line for the why; the
rest belongs in the PR, the ADR, or nowhere.

## Keep-cases

These are the comments worth defending in review. The list is closed — anything
outside it is first tried as a rename, a type, a test, or an extraction.

- **Why this and not the obvious thing.** The alternative you rejected and the
  reason. This is the one fact genuinely unrecoverable from code.
- **External constraint or upstream bug**, with a link or ticket. The link is what
  lets a future reader check whether the constraint still holds and delete the workaround.
- **Intentional-silence markers.** An empty catch, a deliberate fallthrough, an
  unused-but-required parameter. Absence cannot be named or typed; say why it is safe.
- **TODO carrying a ticket ID.** `// TODO(BILL-412): drop once v2 rollout completes`.
- **Contract facts a signature cannot express.** Units (`milliseconds`), ownership
  and lifetime ("caller must close"), which conditions throw, shapes the type system
  cannot state. One line, in the docblock form the language uses.

## A comment that asserts behavior is a claim

"Settles in either direction", "never blocks": each states an invariant the next reader
now trusts instead of checking. Before such a comment ships, either the code plainly
implements it or a test does. A comment describing behavior the code lacks is worse
than none: it stops the one reader who would have noticed.

## Refactor instead of commenting

| The comment you were about to write | Do this instead |
|---|---|
| explains what a block does | extract it into a named function |
| explains what a variable holds | rename the variable |
| explains the shape of a value | give it a type |
| explains what happens on an edge case | write the test |
| explains a clever one-liner | write the boring version |
| labels a region of a file | split the file |

Two guards. Do not rename into a paragraph: `getUsersWhoHaveNotPaidYetAndAreActive`
is a comment wearing a name's clothes — split the concept. And an extraction that
exists only to host a comment, called once, may be worse than the comment; extract to
name a coherent step, not to launder prose.

## Docblocks

One rule, every language: **a docblock exists only for what the signature cannot
express, and it is one line.** Types beat doc-comment lies — a typed parameter is
checked, an `@param` is not, and when they disagree the comment is what people believe.

    /** @param int $userId The user id. @return void */   // delete: the signature says this
    /** Timeout in milliseconds. Throws on a closed pool; caller owns the handle. */  // keep

Same test for TSDoc, a Python docstring, godoc, a `///` in Rust: strip everything the
signature already states, keep whatever survives — usually units, ownership, throw
conditions, or an example for a genuinely non-obvious call. Usually nothing survives,
and no docblock is the correct outcome. Public-API docs generated for external
consumers are a product surface with their own audience; that is a docs decision the
project states in its `CLAUDE.md`, not this rule's.

## Boundaries

Standing: recorded for the rule itself. The one-bullet version is `code-review`'s
code-smells; doc/comment staleness is api-design's `docs-upkeep`; naming and
extraction are `code-architecture`, the destination a comment's content moves to.
Every worker agent in this marketplace carries the same default in its "Code shape"
section, so a fan-out cannot re-import the surrounding file's habits.

## What is enforced, and what is advice

- **gate** — three kill-cases are **denied before the write** by the `PreToolUse`
  lane of `hooks/scan.sh`: a comment restating the next line, commented-out code, and
  a docblock tag repeating the signature. And `hooks/density.sh` denies a whole
  `Write` whose comment-to-code ratio is over the ceiling (0.4:1 by default). Both
  are bounded: one deny per file per session, so a false positive costs one turn and
  never wedges a run.
- **agent-graded** — banners, bare TODOs, change-narration and missing why-comments
  are `PostToolUse` warnings. Whether a kept why-comment was necessary is a reviewer's
  judgment; the `code-reviewer` agent makes it.
- **recorded** — everything else here. Nothing reads it back.

`hooks/density.sh` also warns after any edit when the file is over
min(2x its committed siblings' median, the ceiling), and judges a file with no
committed siblings against the ceiling alone. A project that specifies a heavier
style sets `COMMENT_DISCIPLINE_CEILING_TENTHS` in its settings `env` (10 for 1:1;
0 keeps only the sibling test). That is the "unless specified" escape hatch, and it
is per project on purpose.

## Anti-patterns

- Treating the ceiling as a target. It is a tripwire that names a file worth reading;
  the keep-cases decide which comments survive, and a linked constraint is never cut
  to hit a number.
- Asking "should this be commented?" before "can it be named, typed, or tested instead?"
- A constraint comment with no link, so nobody can ever prove it obsolete.
- Matching a heavily commented neighbour. The neighbour is the drift, not the spec.
