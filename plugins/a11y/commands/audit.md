---
description: "Audit UI code against WCAG 2.2 AA — semantic structure, contrast, keyboard, focus, forms, ARIA — one line per violation with fix."
---

# Accessibility Audit

0. **Triviality triage.** A tiny, logic-only diff (< ~20 lines, single file, no
   markup/ARIA/focus/contrast surface touched) gets a one-line verdict — "no
   accessibility surface in this change" — not a full WCAG pass. Run the full
   audit only when markup, styles, focus order, or interactive semantics changed,
   or the user asked for a full audit explicitly.

1. **Determine scope** from `$ARGUMENTS`: a component, a page, or a diff.
   With no arguments, default to recent UI changes (`git diff` against the
   default branch, filtered to markup, style, and component files).
2. **Apply the checklist** from the `a11y-audit` skill: semantics first,
   the ARIA rules, keyboard operability, focus management, contrast (AA
   ratios and every interaction state), forms, media, and touch targets.
   Read the actual markup and styles — never infer from file names.
3. **Report one line per violation** in the format
   `path:line — WCAG criterion — violation — fix`.
   Sort blockers first (keyboard traps, missing labels, contrast
   failures), then minors.
4. **End with what was NOT checkable statically** as a manual-test list:
   real screen-reader behavior (VoiceOver/NVDA), 200% zoom and reflow,
   live focus order in a running browser, reduced-motion rendering — so
   a human can finish the audit.
5. **When violations exist, offer the next step** as a selectable choice
   (AskUserQuestion): "Apply the fixes now (Recommended)" / "Blockers
   only" / "Stop here". On apply, dispatch the `a11y-engineer` worker with the
   violation list — it prefers the semantic fix over the ARIA patch and tags each
   change with the WCAG criterion it satisfies. In headless runs, report only.
