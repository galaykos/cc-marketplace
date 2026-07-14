# web-dev

Generalist web development pair: a **web-developer** worker for routing,
REST/API integration, forms, state management, and SSR/CSR decisions, plus a
**frontend-reviewer** that audits React/Vue/Inertia/Livewire/TypeScript (and
react-native/vite) code against the matching per-framework skill.
Stack-agnostic — stack idioms are deferred to the per-framework plugins.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install web-dev@cc-plugins-marketplace
```

## How it works

This plugin ships two agents and no commands; they are used proactively when
the work matches:

- **web-developer** (worker, can edit) — implements general web work end to
  end when no single framework plugin owns the task: detects the stack from
  manifests and entry files, plans the smallest file-level change, implements
  it, and verifies with the project's own tests/linter/build. Applies a
  cross-cutting checklist: routing, REST error/timeout handling, form
  validation + CSRF, server-vs-client state, SSR/CSR trade-off, and an
  accessibility baseline.
- **frontend-reviewer** (read-only) — after component or view code changes,
  detects the framework, loads the matching best-practice skill, and checks
  state/effects, list keys, data fetching, TS types, and vite config.
  Returns severity-ranked `path:line` findings; never edits.

Both defer stack-specific depth: the worker recommends the matching review
command after implementing (e.g. `/react:review`, `/typescript:review`), and
the reviewer hands accessibility to `/a11y:audit` and design-system concerns
to `/ui-ux:review`.

## Pairs well with

- **react** / **vue3** — per-framework idioms both agents load and defer to
- **typescript** — type-level review the pair recommends for TS-heavy diffs
- **ui-ux** — visual and design-system review the frontend-reviewer defers to
- **a11y** — full WCAG audit; the agents only enforce a semantic baseline
