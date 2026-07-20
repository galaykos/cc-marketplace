---
name: astryx-best-practices
description: Use when building or reviewing UI with Astryx, Meta's open-source React design system (@astryxdesign/core, StyleX) — component selection, theming, dark mode, agent manifest/CLI usage. BETA — verify current APIs against astryx.atmeta.com before writing code.
---

# Astryx best practices

Astryx is Meta's open-source React design system (MIT, grown inside Meta across
13,000+ apps): 160+ accessible typed components, pre-compiled CSS on StyleX, ten
shipped themes, dark mode, templates, a CLI — and an explicitly **agent-ready**
surface: a JSON manifest describing every component, its props, and behaviors,
plus an MCP server, so coding agents consume the system the way humans do.

## Beta discipline: docs first, always

Astryx is in **beta** (0.x): APIs, props, and package layout can change between
minor releases. Before writing any Astryx code:

1. Resolve the installed version from `package.json` / the lockfile
   (`@astryxdesign/core`).
2. Check the current docs at `https://astryx.atmeta.com/components` (and the
   component's own page) for the props and patterns of THAT surface — never
   recite an Astryx API from memory or from an older project.
3. When the project exposes the Astryx MCP server or the JSON component
   manifest, prefer it over prose docs — it is the typed source of truth for
   props and variants.

## Installation and imports

- Package: `@astryxdesign/core` (npm). Pre-built CSS ships with it — no build
  plugin or StyleX compiler setup is required to consume components.
- Import per component, not from a barrel:
  `import { … } from '@astryxdesign/core/ComponentName';` — keeps bundles lean
  and matches the manifest's per-component addressing.
- The CLI scaffolds and manages the system (init, component listing); check
  `--help` on the installed version rather than assuming subcommands.

## Component selection

- Browse by category — Action, Chat, Container, Content, Data Input,
  Feedback & Status, Layout, Navigation, Overlay, Table & List, Utility — and
  pick the closest existing component before composing a custom one. 150+
  components exist; hand-rolling a dialog or menu next to the shipped one is
  the classic failure.
- Use the Playground's copy-ready examples for the exact variant/state needed;
  they encode the intended composition patterns.
- Utilities are part of the system: `VisuallyHidden`, `useFocusTrap`, `Theme`,
  `useTheme` — reach for these before writing bespoke a11y or theme plumbing.

## Theming and dark mode

- Ten shipped themes: default, neutral, daily, butter, chocolate, matcha,
  stone, gothic, brutalist, y2k. Apply via the `Theme` component / `useTheme`
  hook at the appropriate tree level; brand-level theming is supported —
  do not fork component styles to rebrand.
- Dark mode is built in; verify both schemes render for every screen you
  touch instead of assuming token symmetry.
- Style overrides are legitimate and lock-in-free: Astryx components accept
  overrides via Tailwind, CSS modules, or plain CSS. Override at the usage
  site; do not patch the library's compiled CSS.

## Working with the agent surface

- The JSON manifest is the contract: component names, props, behaviors, CLI
  commands. When generating code, validate prop names/variants against it —
  a prop hallucinated from another design system is the most common defect.
- Keep human and agent paths identical: the same imports, the same theming
  API. If a pattern is awkward to express from the manifest, that is a signal
  the usage is off-convention, not a reason to bypass the system.

## Coexistence with other systems

- One design system owns a surface. Mixing Astryx and shadcn/ui (or Bootstrap)
  in one view doubles token vocabularies and breaks visual consistency —
  choose per app or per clearly-bounded surface, and record the choice.
- Migrating an existing shadcn/Tailwind project: introduce Astryx per-route or
  per-feature behind its `Theme` boundary, not component-by-component inside a
  shared view.
- Accessibility floor still applies: Astryx defaults are accessible, but
  composition can undo them — run the a11y checks on composed screens (focus
  order, contrast on custom-themed surfaces, touch targets).

## Review checklist

- Version resolved from the lockfile; APIs checked against current docs or
  the manifest — no from-memory props.
- Existing component/utility used where one exists; custom compositions
  justified in the diff.
- Per-component imports; no deep private-path imports.
- Theme applied via `Theme`/`useTheme`; both light and dark verified.
- Overrides live at usage sites (Tailwind/CSS modules/plain CSS), never in
  patched library CSS.
- No second design system introduced on the same surface without a recorded
  decision.

## Defer rule

- General React correctness (state, effects, keys) → the react plugin.
- Tailwind/CSS mechanics of overrides → tailwind/css3 skills (this plugin).
- Full WCAG audit → the a11y plugin.
- shadcn/ReUI/Aceternity surfaces → their sibling skills (this plugin).

## Anti-patterns

- **Beta APIs from memory** — a 0.x system changes; uncheck docs and the diff
  ships yesterday's props.
- **Hand-rolled twins** — building a modal/menu/table beside the shipped one.
- **Compiled-CSS patching** — editing library output instead of overriding at
  the usage site.
- **Two design systems, one view** — Astryx + shadcn mixed without a boundary
  or a recorded decision.
- **Manifest-blind generation** — agent-written code that never validates
  props against the JSON manifest the system ships precisely for that.
