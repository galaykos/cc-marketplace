# CSS, styles and markup: what the analyzer run must report

Read by `code-review`'s `analyzer-expert` when the diff holds stylesheets, templates and component markup. Tools: stylelint, pa11y, lighthouse-ci, axe.
The step order is `analyzer-triage`'s; this file adds what is specific to these tools.

## Steps, as they apply here

1. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-analyzers.sh" .` — exit 1, or no UI
   analyzer record, means the automatable pass does not exist here: report that and
   route the whole review to `/ui-ux:audit`.
2. Read the `ci` records: enforced, or advisory?
3. Run the printed invocation, unless CI already passed it on this HEAD (the skill's step 4). `pa11y-ci`, `lhci` and `axe` need a built or running
   target — if there is none, report that as the blocker rather than guessing a result.
4. Triage into new defect / suppressed / config gap.

## What only this run can report

- **Which accessibility rules are disabled.** An axe or pa11y config with `ignore`
  entries, or a stylelint config with rules off, is a decision the reader cannot see
  from a passing build. Name each and the failure class it hides.
- **Whether anything runs at all.** A repo with an accessibility dependency installed
  and no CI step invoking it has the appearance of coverage and none of the substance.
- **Which pages the tooling visits.** `pa11y-ci` and `lhci` check a URL list; a
  component not reachable from a listed URL was never tested. Compare the list against
  the changed components.
- **The automation ceiling itself.** State it once in every report: passing these tools
  is not conformance. Contrast, focus order, keyboard traps, meaningful alt text and
  reading order need the judgment pass.
- **Formatter-owned findings.** Indentation, quote style and property order are the
  formatter's; report the config path, not the diffs.

## Defer rules

- The WCAG 2.2 AA judgment pass → `/ui-ux:audit`.
- Design-system, token and component-library correctness → `ui-ux`'s ui-ux-reviewer.
- Applying accessibility fixes → `ui-ux`'s a11y-engineer.
- Component and view logic → `web-dev`'s frontend-reviewer.
- Motion and animation review → `ui-ux`'s motion skill via `/code-review:review`.

## Before finishing

- [ ] The detector ran; an absent UI analyzer routed the review onward.
- [ ] Tools needing a live target either had one or the blocker was reported.
- [ ] Every disabled or ignored rule is named with the failure class it hides.
- [ ] The automation ceiling is stated.
- [ ] Nothing was edited.

Output: findings one line each — `path:line — severity — rule-id — problem — fix` —
severity-ordered, then a `Config gaps` block, then one line naming the tools run,
their exit codes, and what remains for the judgment pass.
