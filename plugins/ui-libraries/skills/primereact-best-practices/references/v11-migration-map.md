# PrimeReact v10 → v11: prop-level migration map

> Last verified: 2026-09-26 — https://primereact.dev/docs/primitive/guides/migration/updating-to-v11 — npm:primereact@11.1

`primereact-best-practices` reads this file on demand. It covers the per-prop mappings a migration
needs and the SKILL.md body has no room for. Every row comes from the official "Updating to v11"
guide as it stood on the stamp date. Props for a part that is not listed here come from that
part's docs page, never from this file.

Standing: **recorded**. No script compares a codebase against these tables.

## DataTable

`<Column>` never rendered anything. In v10, DataTable read `column.props` off its direct
children, which is why a column could not be extracted into its own component. In v11 a column
is markup: `THeadCell` is a `<th>` and `Cell` is a `<td>`.

| v10 `<Column>` prop | v11 |
|---|---|
| `field`, `header` | `<DataTable.THeadCell>` + `<DataTable.THeadTitle>` |
| `body` | children of `<DataTable.Cell>` |
| `footer` | `<DataTable.TFootCell>` |
| `sortable` | `<DataTable.Sort field>` + `<DataTable.SortIndicator match="asc\|desc">` |
| `filter` and related props | `<DataTable.Filter>` |
| `selectionMode` | `<DataTable.Selection>` |
| `expander` | `<DataTable.RowToggle>` |
| `rowEditor` / `editor` | `<DataTable.RowEditor>` / `<DataTable.CellEditor>` |
| `rowReorder` / `reorderable` / `resizeable` | `<DataTable.RowReorder>` / `<DataTable.ColumnReorder>` / `<DataTable.ColumnResizer>` |
| `colSpan`, `rowSpan` | native attributes on the cell |

| v10 table prop | v11 |
|---|---|
| `value` | `data` |
| `selection` | `selectionKeys` |
| `first` | `page` |
| `expandedRows` / `editingRows` | `expandedKeys` / `editingKeys` |
| `groupRowsBy` | `groupField` |
| `onPage` / `onSort` / `onRowToggle` | `onPageChange` / `onSortChange` / `onExpandedChange` |

These props keep their v10 names: `dataKey`, `loading`, `lazy`, `totalRecords`, `scrollable`,
`scrollHeight`, `sortField`, `sortOrder`, `removableSort`, `selectionMode`, `metaKeySelection`, `rows`,
`paginator`, `reorderableColumns`, `resizableColumns`, `editMode`, `filters`, `globalFilter`,
`rowHover`, `size`, `stripedRows`, `showGridlines`.

- **Pagination UI.** Render `<DataTable.Pagination>` inside `Root`. Its render prop exposes `page`,
  `pageCount`, `rows`, `totalRecords`, `first`, `canPrev`, `canNext`, `onPageChange` and `onRowsChange`.
- **Imperative methods.** `exportCSV()` became `<DataTable.Export>`, backed by `useDataTableExport`.
  `reset()`, `filter()`, `closeEditingCell()`, `saveState()` and `restoreState()` have no direct
  replacement. Use controlled state or the feature hooks under
  `@primereact/headless/datatable/features`.
- **Dropped:**
  - `stateKey` / `stateStorage`: persisting table state is now application code.
  - `responsiveLayout` and `breakpoint`.
  - `virtualScrollerOptions`.
  - Cell selection and `selectAll`.
  - `currentPageReportTemplate` and every `*Icon` prop.
- **Tree mode.** A tree table is `treeMode` on `Root`, with `{ key, data, children? }` nodes and
  `expandedKeys` plus `onExpandedChange`. Put `<DataTable.RowToggle>` in the first cell.
  `propagateSelectionUp`/`Down` and `frozenWidth` are gone.

## Select (was Dropdown / MultiSelect)

- **Parts:** Root, Trigger, Value, Indicator, Clear, Arrow, Portal, Positioner, Popup, Header,
  Filter, List, Option, OptionIndicator, Empty, Footer.
- **Props that stay on Root, unchanged:** `options`, `optionLabel`, `optionValue`,
  `optionDisabled`, `optionGroupLabel`, `optionGroupChildren`, `disabled`, `invalid`, `variant`.
- **Renamed:** `onChange` → `onValueChange`; `onShow`/`onHide` → `onOpenChange`; `dataKey` → `optionKey`.
- **Moved to parts:**
  - `placeholder` → `<Select.Value placeholder>`.
  - `valueTemplate` → children of `Value`.
  - `itemTemplate` → children of `<Select.Option>`.
  - `dropdownIcon` → `<Select.Indicator>` with the icon as a child.
  - `showClear` → `<Select.Clear>`.
  - `emptyMessage` → `<Select.Empty>`.
  - `panelFooterTemplate` → `<Select.Footer>`.
  - `panelClassName` → `className` on `<Select.Popup>`.
  - `appendTo` → `<Select.Portal>`.
  - `scrollHeight` → a `max-height` on `<Select.List>`.
- **Filtering.** `filter`, `filterBy`, `filterMatchMode` and `filterDelay` are gone. Add
  `<Select.Header><Select.Filter/>` and filter `options` in app code; `useFilter` provides the
  matching logic.
- **`editable`** has no counterpart. A Select that accepts free text is `AutoComplete`.
- **Dropped:** `loading`, `loadingIcon`, `maxLength`, `resetFilterOnHide`, `useOptionAsValue`, `showFilterClear`.
- **MultiSelect** becomes `<Select.Root multiple>`. `display`, `maxSelectedLabels` and
  `selectedItemsLabel` are gone; compute the trigger label as children of `Value`. Check marks use
  `<Select.OptionIndicator>`. Select-all is a control you place in `Header`.

## Menus

| v10 `model` key | v11 |
|---|---|
| `label` | children of `<Menu.Item>` |
| `icon` | an icon element |
| `command` | `onClick` |
| `items` | a nested `<Menu.Submenu>` with `SubmenuTrigger`, `Portal`, `Positioner`, `Popup`, `List` |
| `separator` | `<Menu.Separator>` |
| `template` | ordinary markup |

`popup` + `ref.current.toggle()` becomes `<Menu.Trigger as={Button}>` inside `Menu.Root`.

## Other folds

| v10 | v11 |
|---|---|
| `Column`, `ColumnGroup`, `Row` | DataTable cell and row parts |
| `TabPanel` / `AccordionTab` / `StepperPanel` | `Tabs.Panel` / `Accordion.Panel` / `Stepper.Panel` |
| `Steps` | `Stepper` in steps-only mode |
| `Messages` | an array rendered as `Message` |
| `SplitButton` | `ButtonGroup` + `Menu` |
| `Image` | `Gallery` with a single item |
| `CascadeSelect` | `Select` + `Menu` |
| `ScrollTop` | `useScrollTop` |
| `Sidebar` (`visible`, `onHide`, mask) | `Drawer` (`open`, `onOpenChange`, `Drawer.Backdrop`); `fullScreen` → a class on `Drawer.Popup` |
| component `badge` prop | `OverlayBadge` |

## Removed components, and what to compose instead

| v10 | Build it with |
|---|---|
| `ConfirmPopup` | `Popover` with its `Header`, `Title`, `Description`, `Footer` and `Close` parts |
| `BlockUI` | a modal `Dialog` with `Dialog.Backdrop`, or a `ProgressSpinner` over the region |
| `PanelMenu` | `Accordion` wrapping `Menu` |
| `TabMenu` | `Tabs`, with routing in application code |
| `DeferredContent` | `useIntersectionObserver` with conditional rendering, or `AnimateOnScroll` |
| `DataScroller` | `DataView` with `useScrollTop` or an intersection observer |
| `TriStateCheckbox`, `MultiStateCheckbox` | `Checkbox` with `indeterminate`, or `ToggleButtonGroup` |
| `SlideMenu`, `Mention`, `Dock`, `Ripple` | no equivalent |

## Provider (`PrimeReactProvider` from `@primereact/core`)

- **Carried over:** `locale`, `pt`, `ptOptions`, `unstyled` and `filterMatchModeOptions`.
- **`zIndex`:** kept, minus its `toast` key.
- **Renamed:** `nonce` → `csp.nonce`; `inputStyle` → `inputVariant`.
- **Dropped:**
  - `appendTo` (use the explicit `*.Portal` parts).
  - `cssTransition`, `autoZIndex` and `hideOverlaysOnDocumentScrolling`.
  - `nullSortOrder`, now a DataTable prop.
  - `styleContainer` (use `stylesheet`).
  - `changeTheme()` and `ripple`.
- **New:** `theme`, `license`, `stylesheet` (SSR), `locales` and `csp`. There is also `defaults`, which
  sets default props per component application-wide:
  `defaults={{ Button: { props: { size: 'small' } } }}`.

## Pass-through, types, hooks

- **`pt` keys name parts now.** v10 Dropdown's `panel`, `wrapper` and `itemLabel` become Select's
  `root`, `trigger`, `value`, `popup`, `list` and `option`. `ptOptions` (`mergeSections`,
  `mergeProps`) is unchanged.
- **Types:**
  - Types follow `<Component><Part>Props`, `<Component><Part><Action>Event` and
    `<Component><Part>Instance`, all imported from the component's module:
    `import { Select, type SelectRootProps, type SelectValueChangeEvent } from 'primereact/select'`.
  - `DropdownChangeEvent` became `SelectValueChangeEvent`.
  - `React.RefObject<Dropdown>` becomes an element ref or an instance type.
- **Hooks** moved from `primereact/hooks` to `@primereact/hooks`.
  - `useStorage` → `useLocalStorage`.
  - No longer provided: `useClickOutside`, `useCounter`, `useDebounce`, `useInterval`, `useTimeout`,
    `useMouse`, `useMove`, `useResizeListener`, `useFavicon`, `useGlobalOnEscapeKey` and
    `useDisplayOrder`.

## The v10-shape wrapper (the documented migration aid)

Assemble the parts once in your own component, then forward the Root props. Call sites keep their
v10 shape, and you can migrate screen by screen. The Tailwind variant's `select.tsx` is built this
way.

```tsx
import { Select as PRSelect, type SelectRootProps } from '@primereact/ui/select';

export function Select({ placeholder, ...props }: SelectRootProps & { placeholder?: string }) {
  return (
    <PRSelect.Root {...props}>
      <PRSelect.Trigger><PRSelect.Value placeholder={placeholder} /><PRSelect.Indicator><ChevronDown /></PRSelect.Indicator></PRSelect.Trigger>
      <PRSelect.Portal><PRSelect.Positioner><PRSelect.Popup><PRSelect.List /></PRSelect.Popup></PRSelect.Positioner></PRSelect.Portal>
    </PRSelect.Root>
  );
}
```

Call sites still change from `onChange` to `onValueChange`. The wrapper restores the markup shape,
not the v10 prop names.
