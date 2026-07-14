---
description: Review code or a change for performance hotspots and cache correctness against performance-tuning
argument-hint: [path-diff-or-endpoint]
---

Review the target for performance hotspots and cache-correctness gaps.

1. Determine scope from $ARGUMENTS — a file or directory path, a diff/branch
   reference, or a named endpoint/flow. If empty, default to recent changes
   (`git diff` against the merge base, falling back to the latest commits).

2. Triage before the deep read: a trivial, single-file, or purely mechanical change
   earns a one-line verdict — state it and stop. Take the full pass below when the
   change touches hot paths, queries, caching, or the render path, OR spans more than
   5 files, OR exceeds 300 changed lines (a NEW file counts its full length as changed).

3. Invoke the `performance-tuning` skill from this plugin and apply its checklist
   across the scope: backend hotspots (N+1 queries, missing indexes, chatty I/O,
   payload/over-fetch), frontend hotspots (bundle size and splitting,
   render-blocking resources, images, Core Web Vitals), cache correctness (missing
   invalidation, stampede/dogpile, eviction assumptions, staleness bounds, key
   design), and load-shape concerns (percentiles over averages).

4. This is a static review — you are reading for likely costs, not measuring. Flag
   each finding as **measured** only if a real number backs it; otherwise mark it
   **suspected** and name the measurement that would confirm it. Never assert a win
   without a before/after number.

5. Output findings one line each, in the form:
   path:line — severity — problem — measurement-that-confirms — fix
   Order by severity: critical, high, medium, low. No praise, no padding.

6. Defer, do not duplicate: SQL statement/index idioms → `/sql:review`;
   framework-idiom perf → `/react:review` or `/laravel:review`.

7. Close with a coverage inventory and a self-refute pass: state `Checked: …` and
   `Not checked: … (why)` so it is explicit what was covered, what was clean, and what
   was skipped — not only what looked slow. Then run one adversarial self-refute pass
   over every `critical` finding; if a finding does not survive it, drop or downgrade
   it with a note.

8. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Apply now" / "Measure first, then decide" / "Report only". On an apply pick,
   dispatch the finding list down the static chain `performance:performance-engineer →
   task-runner:task-executor if installed → inline` — never leave the user to retype
   findings as instructions. In headless or non-interactive runs, report only.
