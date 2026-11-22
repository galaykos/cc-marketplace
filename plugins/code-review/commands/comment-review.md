---
description: Audit comments — restatement, section banners, commented-out code, bare TODOs, docblock tags repeating the signature, change-narration, missing why-comments — one line per finding.
argument-hint: [path-or-diff]
---

Review the target in $ARGUMENTS against this plugin's rubric — audit it, do not rewrite it.

1. Determine scope from $ARGUMENTS — a file, directory, diff/branch reference, or
   design document. If empty, default to recent changes (`git diff` against the merge
   base, falling back to the latest commits).

2. Run a triage pass before the deep read. The short lane is a conjunction: a change that
   is single-file AND purely mechanical (a rename, a move, a format, a constant swap) AND
   under the thresholds below earns a one-line verdict — state it and stop. A path target
   is not a change, so it takes the deep pass; so does any doubt on any clause. Treat the
   change as risky and take the deep pass when it touches auth, data, migrations, or
   concurrency, OR spans more than 5 files, OR exceeds 300 changed lines (a NEW file counts
   its full length as changed).

   **Hand up when the ask is wider than comments.** When the request also asks for a bug,
   smell or convention review of the scope, hand the WHOLE scope to `/code-review:review`
   and stop; on that hand-up it judges every comment in scope (its item 4a). It is the
   fan-in for overlapping review surfaces and loads every matching stack skill in one pass;
   running the per-stack commands separately is what produces the duplicate findings the
   fan-in exists to prevent, and leaves the stacks nobody happened to invoke unreviewed.
   Deferring is not a smaller answer — the aggregator reaches this plugin's rubric too.

3. Invoke the `comment-discipline` skill from this plugin and apply its checklist across the
   scope — cite the skill's rubric, do not restate it here.

4. Report findings one line each, sorted by severity (critical, high, medium, low):
   `locator — severity — [CONFIRMED|PLAUSIBLE] problem — fix` — the
   locator is `path:line`, or the section/heading for a design-doc review. Mark a
   finding `CONFIRMED` only with a traced call path, an executed check, or a
   reproduction; absent the ability to execute, findings stay `PLAUSIBLE` — that is
   acceptable, not a failure. No finding without evidence and a concrete fix; no praise,
   no padding.

5. Close with a coverage inventory and a self-refute pass. State `Checked: …` and
   `Not checked: … (why)` so it is explicit what was covered, what was clean, and what
   was skipped — not only what broke. Then run one adversarial self-refute pass over
   every critical finding. Drop or downgrade one only on a cited line or command output that
   contradicts it, named in the note; a doubt with no citation keeps it, as `PLAUSIBLE`.
   Same-model second thoughts with no outside signal flip true findings too (Huang et al.,
   ICLR 2024).

6. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   Apply all / Apply critical+high only / Report only. On an apply
   pick, dispatch the finding list down the static chain task-runner:task-executor if installed → inline — never leave
   the user to retype findings as instructions. In a headless or non-interactive run,
   report only and print the apply command instead of dispatching.

When task-runner is installed, you may close by recommending an ultra-assess re-run (the
word "ultra-assess" in a prompt arms it) when the change was large or high-risk —
recommend it only, never self-execute it.
