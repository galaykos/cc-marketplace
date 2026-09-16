---
name: astryx-best-practices
description: Use when building or reviewing UI with Astryx, Meta's open-source React design system — a project importing from `@astryxdesign/*` (core, cli, theme-* packages, StyleX xstyle) or running `astryx init|template|theme|component`. BETA 0.x: pin the installed version before advising.
---

# Astryx best practices

Astryx is Meta's open-source React design system (MIT, grown inside Meta over
eight years, 13,000+ apps): 170+ accessible typed components on StyleX with
pre-compiled CSS, seven shipped theme packages plus a built-in default, dark
mode through light/dark token tuples, 40 page templates, and a CLI whose
`--json` / `--dense` output, `astryx manifest`, generated `AGENTS.md` /
`CLAUDE.md`, and hosted MCP server exist so coding agents consume the system
the same way humans do. Requires **React 19+**.

## Beta discipline: lockfile, then CLI, then docs

Astryx is **0.x**: a minor release has already split the package, renamed a
component category and added the agent surface. For structure — packages,
CSS wiring, import shape, the CLI, category and template names — read
`references/astryx.md` first; no fetch needed. Props are never answered from
the digest. Before writing any Astryx code:

1. Resolve the installed version from `package.json` / the lockfile
   (`@astryxdesign/core`). If React is below 19, stop and say so: the peer
   range is `>= 19.0.0`.
2. Read props and examples for THAT version with `astryx component <Name>`
   (`--props`, `--json`), or the component's page under
   `https://astryx.atmeta.com/components/<Name>` for the published one. Never
   recite an Astryx API from memory or from an older project.
3. Prefer the typed sources — CLI `--json`, `astryx manifest`, or the MCP
   server at `https://astryx.atmeta.com/mcp` — over prose docs. When the
   docs and the CLI disagree, the installed version wins.

## Installation and imports

- Install set: `@astryxdesign/core @stylexjs/stylex @astryxdesign/theme-<name> @astryxdesign/cli`,
  then `npx astryx init`. Three global CSS imports are mandatory (`reset.css`,
  `astryx.css`, the theme's `theme.css`) in the documented `@layer` order — a
  screen that "renders unstyled" is nearly always a missing import.
- Subpath imports, never a barrel: `@astryxdesign/core/Button`,
  `@astryxdesign/core/Layout` for the stack/grid primitives,
  `@astryxdesign/core/theme` for `Theme` / `defineTheme`. The CLI prints the
  exact import for the installed version.
- `astryx doctor` before debugging a setup by hand; `astryx upgrade --list`
  before a version bump — codemods exist for the breaking changes.

## Component and template selection

- Before composing, run the docs' own order: `astryx template --list` →
  `astryx template <name> --skeleton` → `astryx component <Name>`. A template
  (`login-split`, `settings-sidebar`, `ai-chat`, `shell-side-nav`, …) is an
  owned-code starting layout; pick the closest one before laying out a page
  from primitives.
- Browse the eleven categories (Action, Chat, Container, Content, Feedback &
  Status, Form Controls, Layout, Navigation, Overlay, Table & List, Utility)
  and pick the closest component before composing a custom one. Hand-rolling
  a dialog, menu, bottom sheet or table next to the shipped one is the
  classic failure.
- Utilities and hooks are part of the system (`VisuallyHidden`, the focus
  and theme hooks listed by `astryx hook`) — reach for them before writing
  bespoke a11y or theme plumbing.
- Deep customisation goes through `astryx swizzle <Component>`, which copies
  the source into the project as owned code. That is the sanctioned eject;
  editing `node_modules` is not.

## Theming and dark mode

- One `<Theme theme={…} mode="system|light|dark">` at the app root; nested
  `Theme` boundaries only for a genuinely different surface. Themes come from
  `@astryxdesign/theme-<name>` (runtime) or `…/built` + its `theme.css`
  (SSR-safe, no hydration flash — use built in production).
- A brand theme is `defineTheme({name, color, typography, tokens, components})`
  in a file the project owns, scaffolded by `astryx theme add` and compiled
  by `astryx theme build`. Dark mode lives in **[light, dark] tuples** on
  each token — never a `dark` class, `data-theme` attribute or a second
  stylesheet, and never a `palette.mode`-style branch in components.
- Verify both modes render for every screen touched; token symmetry is not
  guaranteed for custom tuples.
- `/ui-ux:theme` and `shadcn-theming` write CSS-variable themes; on an
  Astryx project the preview may still decide the colours, but the write
  target is the `defineTheme()` file, not `globals.css`.

## Overriding styles

At the usage site, in the docs' order: `xstyle` with `stylex.create()`
(merged last; `:hover` behind `@media (hover: hover)`), Tailwind utilities via
the `tailwind-theme.css` bridge, `className` / `style`, then plain CSS against
the stable `.astryx-*` classes and `data-*` attributes. No hardcoded colours or
spacing, no `!important`, no wrapper `div` for margin — and never a patch to
the library's compiled CSS.

## Working with the agent surface

- `astryx init --features agents --agent claude` writes the component index
  and behavioural rules into `.claude/CLAUDE.md`; re-run with `--apply` after
  a dependency bump so the block is not stale. Add the documented npm script
  alias so agents call one CLI path.
- Validate every prop name and variant against `astryx component <Name>
  --json` — a prop hallucinated from another design system is the most common
  defect. If a pattern is awkward to express from the CLI's output, the usage
  is off-convention, not the CLI.

## Coexistence with other systems

- One design system owns a surface. Mixing Astryx with shadcn/ui, MUI or
  Bootstrap in one view doubles token vocabularies; choose per app or per
  clearly-bounded surface, record the choice, and put a `Theme` boundary at
  the seam.
- Migrating an existing shadcn/Tailwind project: introduce Astryx per-route
  or per-feature behind its `Theme` boundary, keep the `@layer` order from the
  getting-started page so the two stylesheets do not fight, and use the
  Tailwind bridge rather than two token vocabularies.
- The accessibility floor still applies: defaults are accessible, composition
  can undo them — run `/ui-ux:audit` on composed screens.

## Review checklist

- React ≥ 19 and the installed `@astryxdesign/core` version stated; props
  checked against the CLI or docs for that version — no from-memory props.
- Three global CSS imports present, `@layer` order intact.
- Existing component, hook or template used where one exists; custom
  compositions justified in the diff; swizzled copies named as such.
- Subpath imports; no barrel, no deep private-path imports.
- One root `Theme`; dark mode via token tuples, both modes verified.
- Overrides at usage sites in the documented order; nothing patched in
  library output; no `!important`, no hardcoded values.
- No second design system on the same surface without a recorded decision.

## Defer rule

- General React correctness (state, effects, keys) → web-dev's `frontend-reviewer`.
- Tailwind mechanics of overrides → the tailwind skill (this plugin); plain CSS is baseline.
- Colour derivation for a brand theme → `theming-system`; the VALUES land in `defineTheme()`, not CSS variables.
- Full WCAG audit → `/ui-ux:audit`.
- shadcn/ReUI/Aceternity/MUI surfaces → their sibling skills (this plugin).

## Anti-patterns

- **Beta APIs from memory** — 0.3 knowledge on a 0.5 install ships yesterday's
  package layout and category names.
- **React 18 adoption** — the peer range is 19+; there is no compat build.
- **Missing CSS trio** — components render unstyled, then get "fixed" with
  hardcoded values.
- **Hand-rolled twins** — a modal, menu, table or wizard beside the shipped
  component or template.
- **Class-toggled dark mode** — a `dark` class or `data-theme` attribute on
  a system that switches by token tuples.
- **Compiled-CSS patching** — editing library output instead of `xstyle`,
  the bridge, `className`, or `swizzle`.
- **Two design systems, one view** — Astryx + shadcn mixed without a boundary
  or a recorded decision.
