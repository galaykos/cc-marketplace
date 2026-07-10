---
name: reui-best-practices
description: Use when building or reviewing UI with ReUI (reui.io) components or blocks — shadcn-compatible registry installs, owned-code discipline, token/theme alignment with the project's shadcn CSS variables, block adaptation, and latest-docs verification before asserting any component API.
---

## What ReUI is and when to reach for it

ReUI (https://reui.io) is a shadcn-ecosystem library: copy-paste React
components and larger blocks built on the same foundations as shadcn/ui —
Radix primitives, Tailwind, CSS-variable theming, `cn()` composition. Reach
for it when the project already speaks shadcn and needs components or
composed blocks beyond the shadcn base set; do NOT bolt it onto a Bootstrap
or plain-CSS project as a shortcut — it drags the whole shadcn stack with it.

## Latest docs before any assertion

The registry churns: components get added, renamed, and their props change
without a package version to pin (there is no `reui` npm dependency to read).
Before asserting a component's name, props, or install command, fetch its page
under https://reui.io/docs — never write ReUI API details from memory. If the
docs are unreachable, say so and ask; a guessed prop on a copy-paste component
fails silently at runtime, not at install.

## Install through the registry, not by hand-copying

- Install via the shadcn CLI pointed at ReUI's registry — the exact command and
  registry URL are on each component's docs page; verify there rather than
  assuming a pattern, and check the project's `components.json` aliases match
  where the files should land.
- The CLI resolves dependency components and npm packages the snippet needs;
  hand-pasting from the docs page skips those and produces half-installed
  components that break on the first missing util.
- Pin the moment: note in the PR which component version/date was pulled —
  registries have no lockfile, the PR description is the only provenance.

## Owned code, same as shadcn

Installed files land in your `components/ui/*` (or configured alias) and are
first-party source from that moment:

- Read the generated file before using it; adapt it to the project instead of
  wrapping it in prop-fighting decorators.
- Re-running the CLI add OVERWRITES local edits — diff before accepting any
  re-add, exactly like the shadcn rule.
- Review generated code in PRs like any other code; "it came from ReUI" is not
  a review waiver.

## Theme through the project's tokens

ReUI components are built for shadcn CSS variables — which means the project's
existing theme (see the shadcn-theming skill) should style them for free:

- A freshly added component that looks off-brand signals a token mismatch, not
  a need for inline overrides — check which variables it consumes vs which the
  project defines before patching colors locally.
- Flag any hardcoded palette values inside an installed component as a finding;
  replace them with the token equivalents so `the `cmd-ui-ux-theme` skill` changes keep
  reaching it.
- Radius, spacing, and dark mode ride the same variables — a component that
  breaks in dark mode is consuming a color pair the theme never defined.

## Blocks are starting points, not pages

ReUI ships composed blocks (dashboards, settings panels, forms). Discipline:

- A block is scaffolding: strip the parts the feature does not need at
  install time; dead sections of a pasted block are the fastest-growing dead
  code in a registry codebase.
- Blocks arrive with demo data and demo state — replace both with the
  project's real data layer before review; a block wired to its demo array is
  not "done".
- Keep the block's accessibility structure (headings order, landmarks, focus
  handling) when carving it up — that structure is most of the block's value.

## Shared foundations must stay aligned

ReUI components ride the same Radix and Tailwind the shadcn base uses. When
both registries feed one repo, keep the foundations single-versioned: one
Radix package set, one `cn()` util, one `tailwind-merge` — a second copy of
any of them (because an install pulled its own) is a finding. Check the
lockfile after every registry add; the CLI is happy to duplicate.

## Don't run two primitive sets

One source of truth per primitive: if the project already has a shadcn
`button.tsx`, do not install a ReUI button beside it — pick one and migrate.
Two Button implementations with different variants is how design systems rot.
ReUI earns its place for components the base set lacks (data-heavy widgets,
composed patterns), not for re-solving solved primitives.

## Performance and accessibility gates

- Data-heavy components (tables, grids, long lists): check what the installed
  code actually does with 10k rows before shipping — copy-paste components
  demo with 20 rows; virtualization is your problem, not the registry's.
- Radix underneath means keyboard/ARIA behavior comes mostly free — but only
  for the parts left intact; stripping a Radix wrapper while carving a block
  removes the a11y with it.
- Respect `prefers-reduced-motion` for any animated variant; the CSS is one
  media query and its absence is a review finding.

## Anti-patterns

- Asserting ReUI component names or props from memory instead of the fetched
  docs page — the library has no npm version to pin advice against.
- Hand-copying snippets when the registry install exists.
- Wrapping installed components to fight their defaults instead of editing
  the owned source.
- Inline color patches on a component instead of fixing the token mismatch.
- Installing a second implementation of a primitive the project already owns.
- Shipping a block with its demo data or its unused sections still inside.
