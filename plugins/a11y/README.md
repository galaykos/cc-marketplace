# a11y

Dedicated accessibility: a WCAG 2.2 AA audit for markup, contrast, keyboard
navigation, focus management, forms, media, and ARIA — one line per violation
with the concrete fix — plus an `a11y-engineer` worker that applies the fix
list, preferring native semantics over ARIA patches and tagging each change
with the WCAG criterion it satisfies.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install a11y@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/a11y:audit [files-or-diff]` | Audit UI code against WCAG 2.2 AA — semantic structure, contrast, keyboard, focus, forms, ARIA — one line per violation with fix |

The report sorts blockers (keyboard traps, missing labels, contrast failures)
before minors, ends with a manual-test list of what static review cannot
verify (real screen readers, 200% zoom, live focus order, reduced motion),
and when violations exist offers to dispatch the `a11y-engineer` worker to
apply the fixes — all, blockers only, or none.

## Example

```bash
/a11y:audit resources/js/components/Modal.vue
/a11y:audit         # audits recent UI changes from the diff
```

The checklist itself ships as the `a11y-audit` skill, so accessibility rules
also apply when writing or reviewing UI markup outside the command.

## Pairs well with

- **ui-ux** — build and restyle components that the a11y audit then verifies
- **design-preview** — render the fixed component in a live preview to check focus order by hand
- **i18n** — locale-aware text handling alongside accessible markup
- **code-review** — general correctness review to run beside the accessibility pass
