# ReUI registry mechanics — the stable layer under a churning catalog

> Last verified: 2026-07-22 — https://reui.io/docs

Read on demand from reui-best-practices. Only STABLE registry mechanics
live here: what ReUI is, the install flow, `components.json` expectations,
top-level catalog groups. Per-component names, props, and exact install
commands are deliberately absent — fetch the component's page under
https://reui.io/docs for those; the pages ARE the version, no npm to pin.

## What ReUI is

- A shadcn registry serving components, a large free example catalog,
  premium blocks, icons, and multi-page templates through the shadcn CLI;
  an MCP server for agents runs at mcp.reui.io.
- Built on the shadcn/ui foundations: React 19, Tailwind CSS v4,
  CSS-variable theming. Primitive-agnostic — registry entries ship in both
  Base UI and Radix UI versions; pick the one the project already uses.
- Ladder of abstraction: free primitives at the bottom, 1,000+ free
  open-source examples above them, paid blocks and templates on top.

## Install flow (shadcn CLI against ReUI's registry)

1. Start from a working shadcn/ui project (React 19, Tailwind v4) — ReUI
   does not bootstrap that layer.
2. Declare the namespace in `components.json`:
   `"registries": { "@reui": "https://reui.io/r/{style}/{name}.json" }` —
   the CLI fills `{style}` from the project's `style` field and `{name}`
   from the item being added.
3. Add items via the shadcn CLI: `npx shadcn@latest add @reui/<name>`.
   Free components use `c-*` names and need no authentication.
4. Premium items: put `REUI_LICENSE_KEY=...` in `.env.local`, switch the
   registry entry to the object form with an `Authorization: Bearer
   ${REUI_LICENSE_KEY}` header — one namespace serves free and paid alike.

## components.json expectations

- `registries.@reui` as above — without it, every `@reui/...` add fails.
- `style` must be a style ReUI publishes (e.g. `base-nova` at the stamp
  date); it feeds the `{style}` URL placeholder.
- The standard shadcn `aliases` decide where installed files land — check
  they match the project layout BEFORE adding.
- ReUI layers extra semantic tokens onto the shadcn variable set (info /
  success / warning families and invert variants) — a theme that never
  defines them yields off-brand components, not errors.

## Catalog groups (top-level, as fetched at the stamp date)

Docs sections: Introduction, Get Started, License Setup, Styling, Registry,
MCP Server, Agent Skills, Changelog. Library groups: Base components,
Application blocks, Solutions, eCommerce, Data Grid, Marketing. Members of
every group churn — never cite one without fetching its page first.

## Pairing guidance

- Reach for ReUI when the project already speaks shadcn and needs more
  than the base set; it drags the whole shadcn stack with it — never bolt
  it onto Bootstrap or plain-CSS projects as a shortcut.
- One primitive layer per repo: choose the Base UI or Radix variant that
  matches the existing shadcn install — mixing both duplicates foundations.
