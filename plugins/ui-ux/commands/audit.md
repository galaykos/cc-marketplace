---
description: "Audit UI code against WCAG 2.2 AA — semantic structure, contrast, keyboard, focus, forms, ARIA — one line per violation with fix."
argument-hint: [files-or-diff]
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
2. **Run the project's own tools before judging.** When the `toolchain-experts`
   plugin is installed, dispatch its `ui-expert` agent on the same scope: it runs
   `detect-analyzers.sh` from its own plugin root (that path is not resolvable from
   here) and, where stylelint/pa11y/axe/lighthouse-ci are configured, runs them and
   reports which of their rules the project has switched off. Fold its findings into
   step 4 tagged `(tool)`, and carry its switched-off list into step 5. When the
   plugin is not installed, or its detector finds no configured tool, say so in one
   line — "tool pass not run" plus which — instead of letting silence read as a clean
   automated run. The tools are never the judgment pass: they see a minority of the
   checklist below, which is why step 3 runs regardless.
3. **Apply the checklist** from this plugin's `a11y-audit` skill: semantics first,
   the ARIA rules, keyboard operability, focus management, contrast (AA
   ratios and every interaction state), forms, media, and touch targets.
   Read the actual markup and styles — never infer from file names.
   **Contrast is measured when a token source exists.** If `src/index.css`,
   `src/app.css`, `app/globals.css`, `resources/css/app.css` or
   `assets/css/main.css` holds `oklch()` tokens under `:root`/`.dark`, run
   `node "${CLAUDE_PLUGIN_ROOT}/scripts/contrast.mjs"` from the project root
   (`CRAFT_TOKEN_SOURCE=<path>` for any other location) and report each FAIL line
   as an SC 1.4.3 / 1.4.11 violation in step 4. It exits 2 when it resolves no
   token — including every non-`oklch()` colour space — and that is not a clean
   run: say contrast was read, not measured, and leave it in step 5's manual list.
4. **Report one line per violation** in the format
   `path:line — severity — WCAG criterion — violation — fix`, sorted by
   severity (critical, high, medium, low) — critical means the surface is
   unusable for someone (keyboard traps, missing labels, contrast failures).
5. **End with what was NOT checkable statically** as a manual-test list:
   real screen-reader behavior (VoiceOver/NVDA), 200% zoom and reflow,
   live focus order in a running browser, reduced-motion rendering — so
   a human can finish the audit.
6. **When violations exist, offer the next step** as a selectable choice
   (AskUserQuestion): "Apply the fixes now (Recommended)" / "Blockers
   only" / "Stop here". On apply, dispatch the `a11y-engineer` worker with the
   violation list — it prefers the semantic fix over the ARIA patch and tags each
   change with the WCAG criterion it satisfies. Then re-audit the changed files
   against the same checklist items before reporting done — the worker's diff is
   not the evidence, the re-checked violation list is. In headless runs, report only.
