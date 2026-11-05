# Range verification — `Verify: range` in the index

Read this when `00-INDEX.md` carries a `Verify: range` line. Overseer writes it into every
milestone brief, taskmaster's task-cards copies it into the index, and task-runner's
`task-execution` skill states the rule in one paragraph; this page is the procedure. A plain
run never has the line. Scripts named here are task-runner's (`<task-runner root>/scripts/`).

## Why

Under the per-card model one unchanged tree was verified six to seven times per milestone
(worker verify, runner re-verify, negative control, per-card reviewers and their re-verify,
range review, behavioral gate, overseer's accept suite, `git-workflow:finish`), and none of
the repeats changed an outcome. Per-card reviewers also passed cards "merge-ready" that the
range review then found critical (`rationale/session-retro-2026-11-05.md`, § 1).

## Per card

1. The worker runs the card's verify through the receipt recorder, never bare:
   `bash <task-runner root>/scripts/check-receipt.sh run --name card-<id> -- <verify command>`.
   Put that line in the worker prompt with the plugin root resolved to an absolute path.
2. The runner's re-verify is `check-receipt.sh check --name card-<id> --cmd "<verify command>"`.
   `fresh:` is the evidence; `stale:` (the tree moved, the command differs, the log is not
   `exit 0`) means re-run it yourself, as on a plain run.
3. No negative control and no reviewer pass for the card. Write nothing to `nc/` or `rv/`
   for it: candor's clause 4 reads the marker and owes neither per card.
4. Scope lock, the three-cycle ceiling and halt-with-evidence are unchanged.

## At close (once per run)

1. The whole-range review, exactly as on a plain run: `/code-review:review <start>..HEAD`
   with `RV-RANGE: <head>`. Critical/high findings go back through the fix loop (three cycles).
2. ONE code-redteam round over the range with the does-the-test-have-teeth lens always
   included; its prompt opens `RT-LENS: teeth-<head 12 chars>`. That lens replaces the
   per-card negative controls. Add the correctness and security lenses when the index is
   boosted (`Ultra:`/`Goal:` without `boost=off`); then the full panel rules apply.
3. The full suite ONCE at HEAD through the recorder: `check-receipt.sh run --name suite -- <suite>`.
   Overseer's accept and `git-workflow:finish` reuse that receipt while it is fresh.
4. `behavioral-gate.sh` as candor's clause 4 asks.

Standing: the marker read and the teeth-lens record are **gate** (candor `hooks/gate.sh`,
clause 4, when candor is installed); running the receipt instead of a bare verify is
**agent-graded**; that the receipt was not written by hand is **unenforceable**
(`check-receipt.sh` names that miss).
