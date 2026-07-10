---
description: Review code for internationalization gaps — hardcoded strings, bad plurals, locale formatting, RTL — against i18n
argument-hint: [path-or-diff]
---

Review the target for internationalization and localization gaps.

1. Determine scope from $ARGUMENTS — components/templates, catalogs, formatting code,
   or a diff. If empty, default to recent UI and string-bearing changes.

2. Invoke the `i18n` skill from this plugin and apply its checklist: no hardcoded
   user-facing strings (all via a catalog lookup); semantic namespaced keys (not source
   text); ICU `plural`/`select` instead of `n === 1` logic; dates/numbers/currency via
   `Intl`/framework locale formatters; logical CSS properties and a set `dir` for RTL;
   a fallback chain with a missing-key policy; tooling-driven extraction; and layouts
   that tolerate text expansion.

3. Output findings one line each:
   path:line — severity — problem — fix
   Order by severity. A hardcoded user-facing string on a localized surface and
   English-only plural logic are the high-frequency findings.

4. Defer, do not duplicate: RTL layout mechanics also touch `/ui-ux:review`; locale-aware
   storage (collation, timezone columns) → `/database:review`.

5. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Apply the fixes now (Recommended)" / "Report only". On apply, hand the finding list
   to the shared `task-executor`. In headless or non-interactive runs, report only.
