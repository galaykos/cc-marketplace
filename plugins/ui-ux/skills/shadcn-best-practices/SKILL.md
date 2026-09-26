---
name: shadcn-best-practices
description: Use when building or reviewing shadcn/ui components — CLI installs, composition over config, CSS-variable theming, accessibility defaults.
---

> Last verified: 2026-09-26 — https://ui.shadcn.com/docs/components/data-table — npm:@tanstack/react-table@9

## You own the code, it isn't a dependency

shadcn/ui components are copied into your repo via the CLI (`npx shadcn add button`), not
installed as an npm package. Once generated, that file is yours: no upstream version to bump,
no changelog to track, and no excuse for leaving generated cruft unread. Treat `components/ui/*`
as first-party source, review it in PRs like any other code, and expect to edit it directly.

- Good: run the CLI, then open the generated file and adapt it to the project's needs.
- Bad: `npm install shadcn-ui` style thinking — waiting for "updates" or refusing to touch the
  file because "it's a library component."

## Customize the component source, not wrapper hacks

When a component needs different behavior or styling, edit the copied source in
`components/ui/`. Do not wrap it in another component that fights its defaults with extra props,
`!important`, or DOM overrides — that adds an indirection layer with no benefit since you already
own the original file.

```tsx
// Good: edit components/ui/button.tsx directly to add a new variant
const buttonVariants = cva(base, {
  variants: { variant: { ..., brand: "bg-brand text-white hover:bg-brand/90" } },
});

// Bad: leave button.tsx untouched and wrap it
function BrandButton(props) {
  return <Button {...props} className="!bg-brand !text-white hover:!bg-brand/90" />;
}
```

## Theme via CSS variables, not per-component overrides

shadcn/ui components read color, radius, and spacing from CSS custom properties defined in your
global stylesheet (`--background`, `--primary`, `--radius`, etc.). Change the theme by editing
those variables in one place, not by hardcoding colors into individual component files.

```css
/* Good: app/globals.css — Tailwind v4 default: oklch tokens mapped via @theme inline */
:root { --primary: oklch(0.21 0.04 265); --radius: 0.5rem; }
.dark { --primary: oklch(0.93 0.02 255); }
/* v3-era projects use HSL triplets — match the installed stack (see shadcn-theming) */
```

```tsx
// Bad: hardcoded hex values inside a single component
<Button className="bg-[#1a2b3c] rounded-[3px]">Save</Button>
```

## Name the primitive base, then keep its accessibility intact

Interactive shadcn/ui components (Dialog, Dropdown, Select, Popover) wrap a headless primitive
base that manages focus trapping, `aria-*` attributes, and keyboard navigation. Three bases
ship. **Base UI** has been the `init` default since July 2026, and **Radix** and **React Aria**
are the alternatives. Their APIs differ in ways that compile and then silently do nothing.

- **Name the base before editing.** In `components.json`, a `style` prefix of `base-`, `radix-`
  or `aria-` names it, and a legacy `new-york` or `default` style means Radix.
- **Base UI rejects Radix habits.** `asChild` becomes `render` (plus `nativeButton={false}` for
  a non-button element), `data-[state=open]:` becomes `data-open:`, and the primitive parts
  `Content` / `Overlay` become `Popup` / `Backdrop`.
- **The plumbing moved on every base.** `cn` now comes from the `cn` package,
  `shadcn/tailwind.css` and `tw-animate-css` are imported in the stylesheet, and the base
  decides the Drawer (vaul is gone on Base UI) and the Toast (Toast vs sonner).

All of that, with the migrate commands, is in `references/bases.md`. Read it before editing a
Base UI project or a mixed one. It matters: in a 2026-09-25 scan of 428 likely-shadcn live
sites, 60 ran Base UI only and 67 ran both bases, so a Radix answer from memory is wrong for
about one project in three. Standing: recorded. No gate reads the base.

Whatever the base, preserve its structural parts (`Root`, `Trigger`, `Portal`, and the popup
part) and pass through `...props` so consumers can still set `aria-label`,
`aria-describedby`, etc.

- Good: `<DialogContent aria-describedby={descId}>{children}</DialogContent>`
- Bad: replacing `DialogContent` with a plain `<div>` because "it's simpler," losing focus trap
  and `Escape`-to-close behavior.

## Compose primitives, don't reconfigure through props explosion

shadcn/ui favors composition (`Card`, `CardHeader`, `CardContent`, `CardFooter`) over a single
component with a dozen boolean props. When a component needs a new arrangement, compose the
existing pieces in new markup rather than adding `showHeader`, `hideFooter`, `variant2` flags.

```tsx
// Good
<Card>
  <CardHeader><CardTitle>Plan</CardTitle></CardHeader>
  <CardContent>{body}</CardContent>
</Card>

// Bad
<Card showHeader hideFooter title="Plan" body={body} />
```

## Don't fork the design language per component

Every component pulls from the same design tokens (spacing scale, radius, color roles). If one
screen needs a different look, change the tokens or add a documented variant in `cva()` — don't
let a single feature quietly introduce a one-off border radius or shadow that only exists in that
file. Inconsistent one-offs are how design systems rot.

- Good: add a `variant: "compact"` to the shared `cva` config, used wherever needed.
- Bad: `className="rounded-[2px] shadow-[0_1px_2px_rgba(0,0,0,0.4)]"` inline in one form.

## Install only what you use, and re-run the CLI for updates deliberately

The CLI adds one component (and whatever primitive its configured base needs — Base UI,
Radix or React Aria; see above) at a time. Don't bulk-copy the entire
registry "just in case." To pull in upstream fixes later, look before you overwrite: run
`npx shadcn view <item>`, then `add <item> --dry-run` or `--diff <path>`, and only then
`--overwrite`. Never silently overwrite local customizations.

Third-party registries have their own hazards. That covers any `@namespace/item`, a
`components.json` `registries` entry, or a registry URL. `references/registries.md` covers them:
the CLI's built-in directory and its health status, the auth object form, `{style}`, the
last-write-wins file dedupe, duplicate packages, and the registries that break the generic
rule. Read it before the first third-party `add`. Standing: recorded.

## Product screens start from the official recipes

App shells and dashboards check https://ui.shadcn.com/blocks before hand-building. These are
free copy-paste scaffolds; `dashboard-01` ships a sidebar, charts and a data table. Each recipe
is a starting file you own, so the owned-code and CSS-variable rules above still apply. Both
recipes below were checked against the live docs on the stamp date (recharts 3.10 and
@tanstack/react-table 9.2 on npm). Standing: recorded. No gate reads the installed major, so
read the lockfile first.

**Charts** (https://ui.shadcn.com/docs/components/chart) are Recharts v3 composed inside
`ChartContainer`. shadcn does not wrap Recharts.

- Series colours live in a `ChartConfig` object (`satisfies ChartConfig`) as
  `var(--chart-1)` … `var(--chart-5)`. Never write `hsl(var(--chart-1))`: that older form is
  invalid once the token already holds a full `oklch()` or `hsl()` colour.
- `ChartContainer` needs a height, a `min-h-*` or an `aspect-*`. Without one,
  `ResponsiveContainer` measures zero on first render.
- `accessibilityLayer` (keyboard and screen-reader support) is ON by default in v3. Never pass
  `accessibilityLayer={false}` to get rid of a focus ring.
- Recharts 2 props that no longer exist:
  - `activeIndex` on Bar, Pie and Scatter. Use `ChartTooltip`'s `defaultIndex` for the initial
    tooltip only, and keep persistent active shapes in your own state.
  - chart state passed to `<Customized>`. It no longer receives any.
  - `layout` on `<Bar>` when `<BarChart>` already sets it.

**Data tables** (https://ui.shadcn.com/docs/components/data-table) use TanStack Table v9, which
is stable.

- Build the table with `useTable({ features, data, columns })`, where `features =
  tableFeatures({ rowSortingFeature, sortedRowModel: createSortedRowModel(), sortFns: {…} })`.
  v8's `useReactTable({ getCoreRowModel: getCoreRowModel() })` is gone: the core row model is
  automatic, and every other row model is a `create*RowModel()` registered on `features`.
- Register what you use. Unregistered features are tree-shaken away. A string
  `filterFn`/`sortFn` key, including `'auto'`, resolves only against the functions registered
  in `filterFns`/`sortFns`, so an unregistered one gives a sort that silently does nothing.
- Call row, cell and column methods on the instance (`row.getValue("x")`). Destructuring them
  loses `this` in v9.
- On a v8 lockfile, `useLegacyTable` from `@tanstack/react-table/legacy` is a deprecated bridge
  for migrating, not a place to stop.

## Common mistakes

Names only — every rule is stated once above, in the section that owns it. These three
are NOT stated above and live here:

- Deleting the primitive base's `Portal`/`Root` wrappers — breaks focus management and
  z-index stacking, not just semantics.
- Exempting `components/ui` from the project's lint/format rules because "it's generated
  code." You own it; it is first-party source.
- Hand-rolling a base-primitive wrapper instead of running `npx shadcn add` for it.

## Component APIs from the registry, never from memory

shadcn ships its own MCP server — `npx shadcn@latest mcp init --client claude` wires it into this
project. When its tools are connected, read a component's actual
props/variants/dependencies from them BEFORE writing usage code: a component API
written from recall is the failure that server exists to stop. Without it, the fallback
is the current docs at https://ui.shadcn.com — CLI flags, registry structure and props
change between releases, and memory does not.
