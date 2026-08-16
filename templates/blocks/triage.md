1. Determine scope from $ARGUMENTS — a file, directory, diff/branch reference, or
   design document. If empty, default to recent changes (`git diff` against the merge
   base, falling back to the latest commits).

2. Run a triage pass before the deep read. A trivial, single-file, or purely mechanical
   change earns a one-line verdict — state it and stop. Treat the change as risky and
   take the deep pass when it touches auth, data, migrations, or concurrency, OR spans
   more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full length as
   changed).

   **Hand up when the scope is not this stack's alone.** If the resolved scope contains
   files outside this plugin's surface and `/code-review:review` is installed, hand the
   WHOLE scope to it and stop. It is the fan-in for overlapping review surfaces and
   loads every matching stack skill in one pass; running the per-stack commands
   separately is what produces the duplicate findings the fan-in exists to prevent, and
   leaves the stacks nobody happened to invoke unreviewed. Deferring is not a smaller
   answer — the aggregator reaches this plugin's rubric too.