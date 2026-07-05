# cc-plgun — Self-Hosted Claude Code Plugin Marketplace

**Date:** 2026-07-05
**Status:** Approved

## Purpose

A self-hosted Claude Code plugin marketplace (single git monorepo) providing opinionated
best-practice plugins for frontend stacks, backend frameworks, and engineering process.
Users add the marketplace by git URL or local path and install only the plugins their
project needs.

## Installation model

```
/plugin marketplace add <git-url-or-local-path>   # e.g. this repo
/plugin install ui-ux@cc-plgun
```

Works with GitHub, GitLab, any self-hosted git remote, or a local/network path.
No web server required.

## Repository layout

```
cc-plgun/
├── .claude-plugin/
│   └── marketplace.json          # marketplace manifest: name, owner, plugin list
├── README.md                     # install + usage + contribution docs
├── docs/superpowers/specs/       # design docs (this file)
├── scripts/
│   └── validate.sh               # structure lint, CI-able
└── plugins/
    ├── ui-ux/
    ├── react/
    ├── react-native/
    ├── vue2/
    ├── vue3/
    ├── laravel/
    ├── livewire/
    ├── code-architecture/
    ├── design-patterns/
    └── api-docs-first/
```

Every plugin directory contains:

```
<plugin>/
├── .claude-plugin/plugin.json    # name, version 0.1.0, description, author
├── skills/<skill-name>/SKILL.md  # auto-triggering guideline skills
├── commands/<cmd>.md             # manual slash commands (namespaced /<plugin>:<cmd>)
├── agents/<agent>.md             # only where listed below
└── hooks/hooks.json              # only where listed below
```

## Plugin roster

| Plugin | Skills | Commands | Agents | Hooks |
|---|---|---|---|---|
| ui-ux | shadcn-best-practices, tailwind-best-practices, css3-best-practices, bootstrap-best-practices, css-grid-best-practices, flexbox-best-practices | review | ui-ux-reviewer | — |
| react | react-best-practices (hooks rules, render/memo perf, state management, component patterns) | review | — | — |
| react-native | react-native-best-practices (list perf, navigation, platform-specific code, animations) | review | — | — |
| vue2 | vue2-best-practices (Vue 2.7 Composition API backport, defineProperty reactivity caveats, migration-readiness) | review | — | — |
| vue3 | vue3-best-practices (script setup, composables, ref/reactive pitfalls, Pinia) | review | — | — |
| laravel | laravel-best-practices (Eloquent N+1, form requests, service layer, queues, policies) | review | — | — |
| livewire | livewire-best-practices (Livewire 3 conventions, wire:model modifiers, performance, Alpine interop) | review | — | — |
| code-architecture | plan-before-code, yagni-check, task-orchestration, work-verification, low-cognitive-load | plan, verify, yagni | architecture-reviewer | — |
| design-patterns | pattern-selection (which pattern where, and when NOT to use one) | suggest | — | — |
| api-docs-first | api-docs-first (verify current API docs before writing integration code; if none visible, ask user for a URL or file) | check | — | UserPromptSubmit: keyword detection (API/SDK/integrate/endpoint) injects a docs-check reminder |

Design decisions:

- **Hybrid granularity.** UI/UX is one plugin with per-stack skills because the stacks are
  often mixed in one project (Tailwind + shadcn + flexbox). Frameworks are separate plugins
  because projects rarely mix React and Laravel frontends arbitrarily — install only what
  the project uses.
- **Reviewer agents only where review is cross-cutting** (ui-ux, code-architecture).
  Framework plugins expose review as a command instead. Per-framework agents can be added
  later without breaking changes (YAGNI).
- **One hook total** (api-docs-first). Hooks run shell commands on every matching event;
  keeping them minimal avoids noise. The hook greps the user prompt for integration-related
  keywords and, on match, injects a reminder to verify current docs first.

## Skill content approach — hybrid

Each SKILL.md contains:

1. **Frontmatter:** `name` + trigger-rich `description` so the skill auto-triggers on
   relevant work, and can also be invoked manually via the Skill tool.
2. **Distilled practices** (~100–150 lines): timeless, opinionated guidance with short
   code examples. Not documentation mirrors.
3. **"Verify against current docs" section:** official documentation URLs and an explicit
   instruction to check current docs for version-sensitive APIs before relying on memory.

Rejected alternatives: curated-only (goes stale silently), docs-pointer-only (no distilled
judgment, slow at runtime).

## Manifest formats

`.claude-plugin/marketplace.json`:

```json
{
  "name": "cc-plgun",
  "owner": { "name": "Ivan-WG", "email": "dev@intername.media" },
  "plugins": [
    { "name": "ui-ux", "source": "./plugins/ui-ux", "description": "..." }
  ]
}
```

`plugins/<name>/.claude-plugin/plugin.json`:

```json
{
  "name": "ui-ux",
  "version": "0.1.0",
  "description": "...",
  "author": { "name": "Ivan-WG" }
}
```

## Error handling

- validate.sh exits non-zero with a per-file message on: unparseable JSON, marketplace
  entry with no matching directory, plugin directory missing plugin.json, SKILL.md missing
  or with malformed frontmatter, hooks.json unparseable.
- The api-docs-first hook must fail open: if the hook script errors, it prints nothing and
  exits 0 so it never blocks a prompt.

## Verification / success criteria

1. `scripts/validate.sh` passes over the whole repo.
2. `claude plugin validate` (if available in installed CLI) passes for the marketplace.
3. Smoke test: `/plugin marketplace add <local-path>` resolves and lists all 10 plugins.
4. All content committed to git on main.

## Out of scope

- Web UI for browsing the marketplace.
- Automated content-freshness checks against live docs.
- Per-framework reviewer agents (future addition).
