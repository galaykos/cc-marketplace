# A destination picked ahead: `--to`

`/git-workflow:finish --to pr|merge|keep` carries a destination the user already
picked; task-runner's run handoff passes it after its one end-of-run question. It
answers the destination question and nothing else.

- **Every check still runs**: the scratch check, the suite (a fresh receipt may
  stand in), the review passes, the post-merge suite, and both halts in "The
  default branch is PR-only".
- **A red suite stops** before any destination, as without `--to`.
- **A finding stops the `--to` path**: an unresolved `critical` review finding, or
  a **confirmed** `/secret-scanning:scan` hit (the scan labels hits confirmed or
  suspected, never critical). Show it and ask the destination question, where the
  waiver rule applies.
- **A fix after the gate suite runs the suite again.** A review's or
  drift-review's fix changes the tree: run the suite again, receipt check first,
  before acting on the destination.
- **A pick the protocol does not offer falls back to asking**: `merge` when the
  base is the default branch, or any value but `pr`, `merge` or `keep`. Say so in
  the report.
- **Discard is never pre-chosen.** `--to discard` falls back to asking, and
  discard keeps its type-the-branch-name step.
- **Headless ignores it**: report and touch nothing, as without `--to`.

Standing: agent-graded — no script reads the flag.
