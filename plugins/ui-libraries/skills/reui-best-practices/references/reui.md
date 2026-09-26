# ReUI registry specifics — the stable layer under a churning catalog

> Last verified: 2026-09-26 — https://reui.io/docs/get-started

Read on demand from reui-best-practices. Only what is SPECIFIC to ReUI lives
here: what it is, its namespace and style, its item types and paywall, its
licence header, its extra tokens, its catalog groups. Per-component names,
props, and exact install commands are deliberately absent — fetch the
component's page under https://reui.io/docs for those; the pages ARE the
version, no npm to pin.

Generic shadcn registry mechanics — the `registries` string and object forms,
the `{style}`/`{name}` placeholders, `${ENV}` headers, the CLI's built-in
directory, `aliases`, `view`/`add --dry-run`/`--diff` before `--overwrite` — are
stated once in `ui-ux:shadcn-best-practices`, `references/registries.md`. Read
them there; nothing below restates them.

## What ReUI is

- A shadcn registry serving primitives the core registry lacks, a large free
  example catalog, premium blocks, icons, and downloadable templates; an MCP
  server for agents runs at mcp.reui.io.
- Built on the shadcn/ui foundations: React 19, Tailwind CSS v4,
  CSS-variable theming. Primitive-agnostic — every registry entry ships a Base UI
  version and a Radix UI version; pick the one the project already uses.
- Ladder of abstraction: free primitives at the bottom, free open-source
  examples above them, paid blocks, icons and templates on top.

## ReUI-specific install facts

1. Start from a working shadcn/ui project (React 19, Tailwind v4) — ReUI
   does not bootstrap that layer.
2. The namespace is `@reui` → `https://reui.io/r/{style}/{name}.json`. It is
   also in the shadcn CLI's built-in directory. ReUI's own docs set `style`
   to `base-nova`; the value must be a style ReUI publishes, because it fills
   the `{style}` segment of that URL.
3. Items install as `npx shadcn@latest add @reui/<name>`. Stock shadcn
   components are NOT ReUI items and keep their bare name (`add button`).
   Templates are not registry items at all: download each from its page.

   **`c-*` marks an example, not a free component.** The registry's own server
   distinguishes four types: `component` (plain names — `alert`, `badge`,
   `data-grid`), `example` (`c-badge-22`, `c-alert-3`), `block`, and `icon`.
   Components and examples are free; blocks and icons are premium. So `c-*`
   marks an EXAMPLE, free or not, and a plain name marks a component — neither
   is a paywall prefix. Some free `c-*` installs pull shared `@reui/*`
   primitives as dependencies; those stay public so the free flow needs no
   licence.

   The gate is per-type and it composes: **an example is only as free as the
   component under it.** A `badge` example search returns free `c-badge-*`
   results; a `chart` example search returns nothing on the free tier, because
   `chart` is not one of the free components and nothing built on it is free
   either. Plan a section around "free examples" without checking its component
   and the gap surfaces after the section exists.

   Never state a count or a catalogue for this registry from a static file —
   including this one. Ask the registry: ReUI ships its own MCP server
   (`mcp.reui.io` — add it with `claude mcp add --transport http reui
   https://mcp.reui.io`, then unlock it with the one-time browser sign-in under
   `/mcp`; a free ReUI account, with a daily request allowance), and
   `list_components` / `search` / `get_component` answer with the type named
   beside every number.
4. Premium items: the key is `REUI_LICENSE_KEY` in `.env.local`, sent as
   `Authorization: Bearer ${REUI_LICENSE_KEY}` from the `@reui` entry's object
   form — one namespace serves free and paid alike. Pro adds the blocks;
   Ultimate adds icons and templates on top.

## Tokens ReUI adds

ReUI layers extra semantic tokens onto the shadcn variable set —
`--info`, `--success`, `--warning` and `--invert`, each with a `-foreground`
pair. A theme that never defines them yields off-brand components, not errors.

## Catalog groups (top-level, as fetched at the stamp date)

Primitives, component examples, Pro blocks (Application, Data Grid, Solutions,
eCommerce, Marketing, AI & Agents), icons, templates. Members of every group
churn — never cite one without fetching its page first.

## Pairing guidance

- Reach for ReUI when the project already speaks shadcn and needs more
  than the base set; it drags the whole shadcn stack with it — never bolt
  it onto Bootstrap or plain-CSS projects as a shortcut.
- One primitive layer per repo: choose the Base UI or Radix variant that
  matches the existing shadcn install — mixing both duplicates foundations.

Standing: **recorded** — no script checks a project's `components.json` or
lockfile against these facts; the reviewer applying `reui-best-practices` is
the only reader (agent-graded).
