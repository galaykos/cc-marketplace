# Tree-wide gates — the property that was checked where it could not fail

A scope lock is the core of a parallel dispatch: each writer gets a disjoint file set, so
two agents never clobber one file. The lock does its job. What nobody notices is that the
lock **also scopes every verify command the agent runs** — and for a property that spans
the whole tree, a scoped check is not a weaker check. It is a check that cannot fail.

Two failure modes come out of this, they look nothing alike, and one gate fixes both.

## Failure mode 1 — N green reports for a property verified nowhere

A cross-cutting property is one no single file can satisfy: a banned register or
vocabulary, "no gradient fills anywhere", a token discipline, an import ban, a required
licence header, a naming convention, "no `console.log` in shipped source".

Dispatch five writers under a scope lock, put the rule in all five prompts, and ask each to
verify it. Each greps its own files, gets zero hits, and reports the check green —
honestly. The orchestrator collects five green reports and concludes the property holds.
Nobody checked the tree. The files written before the rule landed, the files whose author
read the rule differently, and every file nobody was assigned are all unexamined, and the
report format gives the orchestrator no way to see it.

The tell is a count that reads clean because it is empty: **zero findings over zero files
checked is not a clean result, it is an unchecked one.** A green scoped check is evidence
about a subset the reader cannot see the boundary of.

Observed shape: one agent ran a banned-register grep over its own files, reported green,
and then flagged in PROSE that it had no idea about the rest of the tree because siblings
had written most of it. That prose flag is the only reason the tree was ever checked. The
warning was prudent; the mechanism was not — the next agent will not write the paragraph.

## Failure mode 2 — a tree-wide command is not evidence about your own diff

The mirror image. `tsc -b`, a build, a full test run, a lint over `src/` are inherently
tree-wide: they read files the running agent does not own and did not write.

Run one WHILE siblings are writing and the result is about the tree's momentary state, not
about the runner's diff. Observed: one agent's typecheck failed on a sibling's transient
mid-save file (`'project' is declared but its value is never read`) and cleared on retry.
The scope lock held perfectly — the file sets were disjoint — but the verify command was
never scoped, so it reported on somebody else's half-written work.

Both directions are wrong and both are silent:

- A **red** result may belong to a sibling's transient state. Retrying until green trains
  an agent to treat real failures as noise.
- A **green** result may be luck of timing, and it says nothing about a sibling's diff
  that had not landed yet.

## The rule

**One tree-wide gate, run by the orchestrator, after fan-in.** Not N scoped greps, not a
tree-wide command run mid-fan-out.

1. **In each worker's prompt**, state the cross-cutting rule as a constraint to obey. Let
   the agent check its own files if it wants — that is a useful early signal.
2. **Never accept a scoped check as verification of a cross-cutting property.** If a
   worker's verify command was scope-limited, its green means "my files are clean", and it
   must be reported in those words. Require the scope in the report: *"clean over the 6
   files I wrote"*, never *"clean"*.
3. **After every writer has returned**, the orchestrator runs the property's check ONCE,
   over the whole tree, and reports two numbers: what was checked and what was found.
4. **Re-run the inherently tree-wide commands after fan-in too** — typecheck, build, full
   test suite, lint. A mid-fan-out run is a smoke signal, never the evidence. The
   post-fan-in run is the one that counts, and it is the orchestrator's job, not a
   worker's, because only the orchestrator knows when the last writer finished.
5. **A failure at this gate routes to an owner.** A tree-wide finding usually names a file
   outside the reporting agent's scope, so it needs a follow-up dispatch scoped to the
   files the gate cited — never a broadcast to everyone.

The gate's cost is one command. The defect it catches is a property every report called
green that was never true.

## Where the input comes from

A tree-wide gate needs a **checkable input**, not an intention. "Keep the register
consistent" cannot be greped; a list of literal terms can. So the property has to be
recorded, before fan-out, in a form a command can consume — the list, the pattern, the
banned import path, the required header string.

Worked example — craft-layer's banned vocabulary. Its concept step records what the build
may not be as a `Banned vocabulary: <term>, <term>, …` line: literal strings, never a
description. That line is copied onto the build task so every builder receives it, and the
audit greps the **whole shipped tree** for its terms once, after the build finishes. Both
halves are needed. Without the line there is nothing to grep; without the single
post-fan-in run there are only N scoped greps, which is where this file started.

**A checkable input owes MATCH SEMANTICS, defined once.** A list of terms is not yet a gate:
"grep for these" leaves open whether a hit is a substring, a word, or a whole phrase, and two
readers of the same list will answer differently. craft-layer states its semantics in exactly
one place — `craft-layer/skills/creative-direction/references/concept-deck.md`, word-bounded
and case-insensitive, with short terms given as quoted phrases — and its command, its reviewer
agent and this file all CITE that paragraph rather than each carrying a copy. Restating it is
how the orchestrator's gate and a worker's gate come to mean different things while both
report green.

The failure it was written from: a concept step ruled out a prior build's visual genus, the
ruling went into prose, no dispatch and no command carried it, every gate reported green,
and the build shipped that exact genus. A human found it by opening a screenshot.

## Anti-patterns

- **Summing scoped greens.** Five agents report clean over their own files; the
  orchestrator writes "verified". Nothing verified the union.
- **A report that omits its scope.** "Grep clean" with no file count and no boundary. The
  orchestrator cannot tell a tree-wide result from a two-file one.
- **Retry-until-green during a fan-out.** A tree-wide command that fails, is retried, and
  passes has told you about timing, not about correctness — and the habit hides real
  breakage.
- **Declaring the property in prose only.** A rule with no literal terms, pattern, or
  command behind it cannot be a gate at any scope; it is a hope shared with five agents.
- **Broadcasting the fix.** A tree-wide finding sent to all N writers gets fixed N times or
  zero. Scope the follow-up to the cited files.
- **Running the gate before the last writer returns.** Then it is failure mode 2 wearing
  the gate's clothes.
