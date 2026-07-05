---
description: Audit error handling — empty or over-broad catches, swallowed exceptions, message-string branching, missing cause chains, internals leaking to users — one line per finding.
argument-hint: [path-diff-or-design-doc]
---

Review the target for error-handling defects at every catch site, error
boundary, and failure path.

1. Determine scope from $ARGUMENTS — a file or directory path, a diff/branch
   reference, or a design document. If empty, default to recent changes
   (`git diff` against the merge base, falling back to the latest commits).

2. Invoke the error-handling-design skill from this plugin and apply its
   checklist to every catch/rescue/except block, error boundary, and
   top-level handler found in scope. For each one check: empty or
   over-broad catches (catch-all around whole methods, bugs handled as
   events), swallowed errors (no rethrow, no record with context),
   log-and-rethrow duplication (the same failure reported at multiple
   layers), branching on message strings instead of error types, missing
   cause chains on wrap-and-rethrow, internals leaking into user-facing
   responses (stack traces, SQL, paths), and errors handled at layers
   that cannot act on them (no retry, fallback, translation, or
   completion available — should propagate instead).

3. Output findings one line each, in the form:
   path:line — severity — problem — fix
   (for design docs, use section/heading in place of path:line). Order by
   severity: critical, high, medium, low. No praise, no padding.

4. End with the handler inventory: every catch site, error boundary, and
   top-level handler that was checked, one per line, with a pass/finding
   status — so it is explicit what was covered and what was clean, not
   just what was broken.

5. When findings exist, offer the next step as a selectable choice
   (AskUserQuestion): "Apply the fixes now (Recommended)" / "Critical and
   high only" / "Stop here". Never leave the user to retype findings as
   instructions. In headless or non-interactive runs, skip the offer and
   report only.
