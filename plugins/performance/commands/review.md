---
description: Review code or a change for performance hotspots and cache correctness against performance-tuning
argument-hint: [path-diff-or-endpoint]
---

Review the target for performance hotspots and cache-correctness gaps.

1. Determine scope from $ARGUMENTS — a file or directory path, a diff/branch
   reference, or a named endpoint/flow. If empty, default to recent changes
   (`git diff` against the merge base, falling back to the latest commits).

2. Invoke the `performance-tuning` skill from this plugin and apply its checklist
   across the scope: backend hotspots (N+1 queries, missing indexes, chatty I/O,
   payload/over-fetch), frontend hotspots (bundle size and splitting,
   render-blocking resources, images, Core Web Vitals), cache correctness (missing
   invalidation, stampede/dogpile, eviction assumptions, staleness bounds, key
   design), and load-shape concerns (percentiles over averages).

3. This is a static review — you are reading for likely costs, not measuring. Flag
   each finding as **measured** only if a real number backs it; otherwise mark it
   **suspected** and name the measurement that would confirm it. Never assert a win
   without a before/after number.

4. Output findings one line each, in the form:
   path:line — severity — problem — measurement-that-confirms — fix
   Order by severity: critical, high, medium, low. No praise, no padding.

5. Defer, do not duplicate: SQL statement/index idioms → `/sql:review`;
   framework-idiom perf → `/react:review` or `/laravel:review`.

6. When findings exist, offer the next step as a selectable choice
   (AskUserQuestion): "Apply the fixes now (Recommended)" / "Measure first, then
   decide" / "Report only". On "Apply", hand the fix-list to the shared
   `task-executor`. In headless or non-interactive runs, report only.
