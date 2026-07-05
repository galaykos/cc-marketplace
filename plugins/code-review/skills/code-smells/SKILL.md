---
name: code-smells
description: Use when reviewing, refactoring, or judging code quality — a catalog of code smells (bloaters, couplers, change-preventers, dispensables) with detection cues, concrete fixes, and the when-it-is-NOT-a-smell judgment that separates review signal from dogma.
---

A smell is a surface symptom that correlates with deeper trouble — not a bug,
not a verdict. Every smell here carries three parts: the cue that detects it,
the risk it predicts, and the fix that removes it. A smell without a concrete
fix is an opinion; do not report opinions.

## Detection discipline

- Judge changed code against its own neighborhood, not against an ideal
  codebase. A 40-line function in a file of 40-line functions is convention,
  not a finding.
- One smell, one line: `path:line — minor — <smell>: <evidence> — <fix>`.
  Smells are minor severity unless they hide a correctness risk.
- Count before flagging: "long" means measured (lines, parameters, branches),
  never vibes. State the number in the evidence.
- Smells outside the diff under review get one summary sentence at most.

## Bloaters — things that grew past comprehension

- Long function. Cue: does not fit on one screen, or needs section comments
  to navigate. Risk: untestable paths, hidden state. Fix: extract the
  commented sections into named functions; the comments become the names.
- Large class / god object. Cue: unrelated field clusters, methods that use
  disjoint halves of the state. Risk: every change touches it. Fix: split
  along the field clusters — each cluster is a class trying to get out.
- Long parameter list. Cue: four-plus parameters, callers passing them in
  fixed bundles. Risk: argument-order bugs. Fix: introduce a parameter
  object for the bundle that travels together.
- Primitive obsession. Cue: the same string/int pair validated in many
  places (money, ranges, ids). Risk: one missed validation. Fix: a small
  value type that validates once at construction.

## Couplers — things that know too much about each other

- Feature envy. Cue: a method reads three-plus fields of another object and
  none of its own. Risk: logic drifts away from the data it governs. Fix:
  move the method to the object it envies.
- Inappropriate intimacy. Cue: reaching into another module's internals,
  bypassing its public surface. Risk: refactors break strangers. Fix: widen
  the public API deliberately or move the code inside.
- Message chain. Cue: `a.b().c().d()` spanning three-plus objects. Risk:
  every link is a coupling to reshape later. Fix: have the first object
  answer the question itself (tell, don't ask).
- Middle man. Cue: a class whose methods only forward to one delegate.
  Risk: indirection tax with no abstraction gain. Fix: call the delegate
  directly and delete the shell.

## Change-preventers — things that make edits expensive

- Shotgun surgery. Cue: one logical change requires edits in many files
  (trace a recent change to count). Risk: a missed site ships a half-change.
  Fix: gather the scattered knowledge behind one function or module.
- Divergent change. Cue: one file edited for many unrelated reasons (its
  git log alternates topics). Risk: merge conflicts, fear of touching it.
  Fix: split by reason-to-change.
- Parallel inheritance / parallel structures. Cue: adding X here always
  forces adding X-prime elsewhere. Risk: the pair drifts. Fix: collapse the
  pairing into one structure or generate one side from the other.

## Dispensables — things whose absence improves the code

- Dead code. Cue: unreferenced symbols, branches no input reaches, flags
  always false. Risk: readers maintain fiction. Fix: delete; version control
  remembers.
- Duplicated knowledge. Cue: the same rule or constant encoded in two-plus
  places — not the same characters, the same decision. Risk: they diverge.
  Fix: extract once — but only after the rule of three; see below.
- Speculative generality. Cue: interfaces with one implementation, config
  nobody sets, hooks nobody calls. Risk: cognitive tax on every reader.
  Fix: inline to the concrete case (the yagni-check skill in
  code-architecture owns the deep version of this call).
- Comment as deodorant. Cue: a comment explaining WHAT confusing code does.
  Risk: comment rots, confusion stays. Fix: rename and extract until the
  comment is redundant; keep only constraint-comments (the WHY).

## When it is NOT a smell

- Duplication before the third occurrence. Two similar blocks may be
  coincidence; premature merging couples strangers. Apply the rule of three
  (simplicity-principles skill in code-architecture owns this judgment).
- Long-but-linear. A sequential setup script or migration with no branching
  reads fine at 80 lines; extraction would scatter a straight story.
- Data clumps blessed by the domain. An address is five fields everywhere —
  that is the domain shape, not primitive obsession, once it lives in one
  value type.
- Framework-imposed shapes. Controllers, resolvers, and fixtures follow
  their framework's layout even when it trips generic heuristics; judge
  against the framework convention, not the catalog.
- Test verbosity. Explicit, repetitive arrange-act-assert beats clever
  shared setup that hides what a failing test actually exercised.

## Review protocol

1. Scope to the change: catalog passes over changed hunks only.
2. Measure the cue (lines, fields, links, sites) and quote the number.
3. Name the fix concretely — which extraction, which move, which deletion.
4. Severity honesty: a smell is minor unless it conceals a correctness
   risk; never inflate to force attention.
5. Defer the neighbor's specialty: structure and YAGNI depth to
   code-architecture skills; security-relevant smells (secrets in code,
   homemade crypto) to the security plugin; framework idioms to the
   per-stack review command when installed.
