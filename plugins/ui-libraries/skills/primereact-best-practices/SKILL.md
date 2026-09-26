---
name: primereact-best-practices
description: Use when building, reviewing or migrating UI on PrimeReact — imports from `primereact`, `@primereact/ui`, `@primereact/core` or `@primeuix/themes`, a DataTable, Select or PrimeReactProvider, a v10 → v11 migration, or PrimeReact's Tailwind registry. v11 is a rewrite under a keyed PrimeUI licence; read the installed version before advising.
---

> Last verified: 2026-09-26 — https://primereact.dev/docs/primitive/guides/migration/updating-to-v11 — npm:primereact@11.1

# PrimeReact best practices

PrimeReact 11 (GA 2026-07-15; `11.1.0` on the stamp date) is a rewrite. Components are composed from parts,
themes are token presets instead of CSS files, and the licence is commercial and needs a key. A v10 memory
gets the imports, theming, table API and licence wrong all at once. This skill carries only those inversions.
primereact.org now 301s to https://primereact.dev, so old deep links land on v11 pages. The v10 docs live at
https://v10.primereact.org.

## 1. Version first

- Read the RESOLVED `primereact` version from the lockfile, not the `package.json` range. On `10.x`, follow
  § 9 only. On `11.x`, or with `@primereact/ui` present, follow the rest.
- v11 needs `react >=19`; v10 accepted 17–19. On React 18, say that v11 is not an option.
- `@primeuix/themes` has its own major. v11 pairs with `@primeuix/themes@3`, which shares `@primeuix/styled@1`
  with `@primereact/core@11`. Themes 1.x and 2.x belong to the PrimeVue-4-era line on `@primeuix/styled@0.x`, so a
  `^1` or `^2` pin beside `primereact@11` resolves a second styling runtime. Flag it and bump the pin to `^3`.
- Take a part's props from its page, never from memory: `https://primereact.dev/docs/styled/components/<name>.md`.
  The index is https://primereact.dev/llms.txt.

## 2. Licence: never call v11 MIT

- v10 (`10.9.9`, npm tag `v10-stable`) is MIT. Every v11 package, `@primeuix/themes@3` included, declares
  `SEE LICENSE IN LICENSE.md`: the **PrimeUI Licence**.
- **Community (free)** applies only while ALL of these hold: under $1M revenue, fewer than 5 developers,
  fewer than 10 employees, and under $3M outside funding. Individuals, students, non-profits and
  non-commercial open source also qualify. It renews annually. Everyone else needs **Commercial**, paid per
  developer.
- **Every tier needs a key**, passed as `<PrimeReactProvider license="…">`. Verification happens offline.
  A missing, invalid or expired key "may cause the software to display a license notice".
- In code, read the key from an env var (`import.meta.env.VITE_PRIMEUI_LICENSE`). In the final message, tell
  the user that a PrimeUI key is required (primeui.dev). Choosing v11 is a licence decision, so raise it
  before `npm install`, not after.
- Publishing a component library or dev tool built on v11, for third parties to develop with, needs a
  separate OEM licence.

## 3. Packages and imports

| Package | Holds |
|---|---|
| `@primereact/ui` | Themed components, the v10 equivalent: `import { Select } from '@primereact/ui/select'` |
| `primereact` | The same components UNSTYLED. `@primereact/ui` depends on it, so never uninstall it |
| `@primereact/headless` | Behaviour hooks with no markup (`useSelect`) |
| `@primereact/core` | `PrimeReactProvider`, `PrimeReactStyleSheet`, config and the theming runtime |
| `@primereact/hooks` | `useMask`, `useKeyFilter`, `useFilter`, `useScrollTop` (was `primereact/hooks`) |
| `@primeuix/themes` | The Aura, Material, Lara and Nora presets, plus `definePreset` and `updatePreset` |
| `@primeicons/react` | Optional icons: `import { Check } from '@primeicons/react/check'` |

- Install with `npm install @primereact/ui @primeuix/themes`. Also declare `@primereact/core` directly,
  because the provider is imported from it.
- v11 ships no icons. `icon="pi pi-check"`, `primeicons/primeicons.css` and `PrimeIcons` are gone. Pass an
  icon from any library as a child: `<Button><Check /> Save</Button>`.

## 4. Theming

`primereact/resources/themes/*/theme.css`, `primereact/resources/primereact.min.css`, `primeflex/primeflex.css`
and `changeTheme()` do not exist in v11. A theme is a preset passed to the provider:

```tsx
import { PrimeReactProvider } from '@primereact/core';
import { definePreset } from '@primeuix/themes';
import Aura from '@primeuix/themes/aura';

const Brand = definePreset(Aura, { semantic: { primary: { 50: '{indigo.50}', /* … */ 950: '{indigo.950}' } } });

<PrimeReactProvider license={import.meta.env.VITE_PRIMEUI_LICENSE}
  theme={{ preset: Brand, options: { darkModeSelector: '.app-dark' } }}>
  <App />
</PrimeReactProvider>
```

- **Dark mode.** `darkModeSelector` defaults to `'system'` (`prefers-color-scheme`). For a user toggle, set a
  class selector and toggle the class on `<html>`. For always-dark, put the class on `<html>` from the start.
  `false` turns dark mode off. One token can hold both schemes: `'light-dark({surface.300}, {surface.700})'`.
- **Token tiers.** Primitive (`blue.500`), then semantic (`primary.color`), then component
  (`button.root.borderRadius`). Change the semantic tier first. Use component tokens only for one component type.
- **One instance.** The `dt` prop takes that component's token sections, the same shape as
  `definePreset(Aura, { components: { toggleswitch: {…} } })`.
- **Runtime changes.** Switch themes by passing a different preset, or call `updatePreset`,
  `updatePrimaryPalette` or `updateSurfacePalette` (there is no stylesheet to swap).
- **Fallback.** `p-*` class overrides still work. A selector reaches one component; a token reaches every
  component that uses it.
- **Next.js App Router.** The provider is a `'use client'` component. It passes a `PrimeReactStyleSheet` as
  `stylesheet` and flushes it in `useServerInsertedHTML`. Copy it from
  https://primereact.dev/docs/styled/guides/installation/nextjs.

## 5. API: compound parts, not props

- Data and behaviour props stay on `.Root`. Everything visual becomes a part or children: `placeholder`,
  `*Template`, `panelClassName`, `header`, `icon`, `appendTo`.
- State props follow one pattern: `value`/`defaultValue`/`onValueChange`,
  `checked`/`defaultChecked`/`onCheckedChange`, and `open`/`defaultOpen`/`onOpenChange` (which replaces
  `visible` + `onHide`). Handlers still receive `e.value`.
- There is no imperative ref API. `toast.current.show()` and `dt.current.exportCSV()` are gone; use state,
  hooks or `<DataTable.Export>`. No menu takes a `model` array: a menu is `Menu.Item onClick`,
  `Menu.Submenu` and `Menu.Separator` markup.

```tsx
<Select.Root value={country} options={countries} optionLabel="name" onValueChange={(e) => setCountry(e.value)}>
  <Select.Trigger><Select.Value placeholder="Country" /><Select.Indicator><ChevronDown /></Select.Indicator></Select.Trigger>
  <Select.Portal><Select.Positioner><Select.Popup><Select.List /></Select.Popup></Select.Positioner></Select.Portal>
</Select.Root>

<DataTable.Root data={customers} dataKey="id" paginator rows={10} removableSort>
  <DataTable.TableContainer><DataTable.Table>
    <DataTable.THead><DataTable.THeadRow>
      <DataTable.THeadCell><DataTable.Sort field="name">Name<DataTable.SortIndicator match="asc">▲</DataTable.SortIndicator><DataTable.SortIndicator match="desc">▼</DataTable.SortIndicator></DataTable.Sort></DataTable.THeadCell>
    </DataTable.THeadRow></DataTable.THead>
    <DataTable.TBody>{({ item }) => <DataTable.Row key={item.id}><DataTable.Cell>{item.name}</DataTable.Cell></DataTable.Row>}</DataTable.TBody>
  </DataTable.Table></DataTable.TableContainer>
  <DataTable.Pagination>{({ page, pageCount, canPrev, canNext, onPageChange }) => null /* your pager UI */}</DataTable.Pagination>
</DataTable.Root>
```

- **DataTable.** `<Column>` is gone and `value` is now `data`. A column is markup, and each cell is a real `<td>`.
- **Select.** Filtering is explicit: add `<Select.Header><Select.Filter/>` and filter `options` in app code.
- **Parts.** `as` changes what a part renders (`<Dialog.Trigger as={Button}>`). `match="…"` renders a slot
  only in the state it names.
- **Config.** `pt` keys now name parts. The `primereact/api` global is gone; provider props replace it
  (`inputVariant`, `csp`, `defaults`).
- **Large codebases.** The documented migration path is a thin wrapper that restores the v10 call shape. For
  prop-level maps, read `references/v11-migration-map.md`.

## 6. Renames

`Dropdown`→`Select` · `Calendar`→`DatePicker` · `OverlayPanel`→`Popover` · `Sidebar`→`Drawer` ·
`InputSwitch`→`ToggleSwitch` · `TabView`+`TabPanel`→`Tabs` · `InputTextarea`→`Textarea` · `Password`→`InputPassword` ·
`Chips`→`InputTags` · `ColorPicker`→`InputColor` · `Galleria`→`Gallery` · `ScrollPanel`→`ScrollArea` ·
`SelectButton`→`ToggleButtonGroup`.

v11 also has a component named `Sidebar`, but it is an app navigation shell. v10's Sidebar is v11's `Drawer`.

## 7. Folded, hooks, paid, missing

- **Folded:** `MultiSelect` → `Select multiple` · `TreeTable` → `DataTable treeMode` · `TreeSelect` → `Select` with
  tree options · `TieredMenu` → `Menu` with submenus · `MegaMenu`/`Menubar` → `NavigationMenu` · `ConfirmDialog` → `Dialog`.
- **Hooks:** `InputMask` → `useMask`, `KeyFilter` → `useKeyFilter`, `OrderList` → `useOrderList`,
  `PickList` → `usePickList`.
- **Paid PrimeUI Pro:** `Chart` (`@primeuipro/chart`), `Editor` (`@primeuipro/texteditor`) and the new
  Scheduler. On the free tier, a project that needs one of these needs another library or a Pro budget. Say
  which before writing code.
- **Removed:** twelve components. The reference names what to compose in place of each.
- **VirtualScroller is not implemented.** `virtualScrollerOptions` on DataTable, Listbox, Select and Tree has
  no equivalent until the `useVirtualizer` hook ships. For a large table, paginate (`paginator` + `rows`) or
  load server-side (`lazy` + `totalRecords` + `onPageChange`). If one view must scroll through thousands of
  rows continuously, that is a reason to stay on v10. Say so before migrating.

## 8. Tailwind mode (owned code)

- It is a shadcn-compatible registry, not a theme, and it needs Tailwind v4.
  1. `npx shadcn@latest init -t next https://primereact.dev/r/theme.json` writes `components.json`, a `cn`
     helper, the `--p-primary-*`/`--p-surface-*` tokens and the `tailwindcss-primeui` import.
  2. Then run `npx shadcn@latest add https://primereact.dev/r/<component>.json` for each component, and
     `…/r/primary-<colour>.json` or `…/r/surface-<tone>.json` for palettes.
- The copied files wrap the unstyled `primereact` package, not `@primereact/ui`. The manual install is
  `primereact @primeicons/react tailwindcss-primeui tailwind-merge`. Use one layer per surface.
- It still needs `PrimeReactProvider` for the licence key. Set `darkModeSelector: '.dark'` to match
  `@custom-variant dark (&:where(.dark, .dark *))`.
- Its `components.json` is not shadcn/ui. Theme it through the `--p-*` tokens, not `--primary`
  (`ui-ux:shadcn-theming`). Generic registry mechanics: `ui-ux:shadcn-best-practices` → `references/registries.md`.

## 9. v10 projects: no accidental upgrade

- A lockfile on `10.x` stays on v10 unless the user asks to migrate. On v10, `primereact/dropdown`, `<Column>`
  and `primereact/resources/themes/…` are correct.
- `npm install primereact` now resolves to `11.x`: a new licence and a rewrite. Pin `primereact@^10`, or
  install `primereact@v10-stable`. Adding `@primereact/ui` or `@primeuix/themes@3` is the same migration by
  another route.
- A migration is its own task. Settle the licence first, then migrate screen by screen with the reference open.

## Defer rule

- React correctness → web-dev's `frontend-reviewer`. Colour values → `/ui-ux:theme`. WCAG → `/ui-ux:audit`.
- Table-vs-chart form → `craft-layer:information-design`. PrimeVue, or any other library → `component-libraries`.

## Anti-patterns

- **v10 from memory on v11:** `primereact/dropdown`, `<Column>`, a theme CSS import, `primeflex`, `changeTheme`,
  `icon="pi pi-…"`, `model={items}`, `ref.current.show()`.
- **"PrimeReact is MIT" on v11**, or a provider with no `license`.
- **A silent major bump:** `primereact@latest` in a v10 app.
- **`@primeuix/themes@^1` beside `primereact@11`**, which installs two styling runtimes.
- **Assumed virtualization:** `virtualScrollerOptions` carried into v11.
- **shadcn's `--primary` on the PrimeReact registry**, whose tokens are `--p-*`.

Standing: every rule is **recorded** — read from the docs and npm on the stamp date; no script checks a lockfile
against them. They are **agent-graded** where `ui-ux:ui-ux-reviewer` and `/code-review:review` apply them, and
§§ 2–5 by `evals/primereact-v11-screen` (run by hand, not in CI). Only the route that loads this skill is
a **gate** (`skill-router`'s `route.test.sh`).
