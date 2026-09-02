---
name: component-libraries
description: Use when building or reviewing UI on any React component library — headless (Base UI, Radix, React Aria, Ark UI, Headless UI, Ariakit), styled (Mantine, Chakra, Ant Design, HeroUI, daisyUI, Untitled UI, Reshaped), or one without a sibling skill here. Library-agnostic rules — detect from the manifest, build in the one the project has, tokens through the library's own theme, keep its accessibility contract — plus a map to the sibling skill or docs URL per library.
---

# Component libraries — the library-agnostic floor

The UI layer is not one library. A project may run shadcn/ui, a registry, MUI,
Astryx, vanilla Tailwind, Mantine, Chakra, Ant Design or a headless primitive
set, and the marketplace does not get to pick. Sibling skills in this plugin
carry the idioms of the libraries they name; this skill carries what is true
across all of them, and says where to go for the rest.

## 1. Detect, then build in what the project has

- Read `package.json` and the lockfile before touching markup. The library is a
  dependency name, a registry file (`components.json`), or a `components/ui/`
  tree of owned code — see `references/library-map.md` for the signals.
- Build in the library the project has. Adding a second one because a
  component "is easier" there is the top defect this skill exists to stop: two
  token vocabularies, two focus-ring styles, two a11y models on one surface.
- No library and no design system? Say so and build with Tailwind or plain CSS
  under the project's tokens — do not install one unasked. A decided
  `Stack:`/`Locks:` line in the dispatch outranks this rule.

## 2. Owned code versus a dependency

Two ownership models, and the rules differ:

| Model | Examples | You may | You must not |
|---|---|---|---|
| **Copy-in / registry** | shadcn/ui, ReUI, Aceternity, Untitled UI, Kibo, 21st.dev blocks | edit the component file, restyle to the project's tokens | re-fetch over local edits; reinstall to "fix" a diff |
| **npm dependency** | MUI, Mantine, Chakra, Ant Design, HeroUI, Astryx, the headless sets | configure the theme, override at the usage site, wrap | patch `node_modules`, fork a component to change one colour, reach into private classnames |

The registry model pins nothing in `package.json`: the version is whatever was
fetched. Record the source and date in the file header or the project's docs,
because nothing else does.

## 3. Tokens through the library's own mechanism

- Every library has one theme channel: CSS variables (shadcn, daisyUI, Base UI
  consumers), `createTheme` (MUI, Mantine, Chakra's system), ConfigProvider
  tokens (Ant Design), `Theme` (Astryx), Tailwind `@theme` (HeroUI, Untitled UI).
  Put the project's `design-tokens` values THERE — once — and consume them.
- A hardcoded hex, pixel radius or font-size on a component is a token fork.
  Fix at the theme, not at the instance.
- Dark mode is the library's switch, not a second stylesheet. Verify both
  schemes on every touched screen; most libraries ship symmetric tokens and
  most brand overrides break the symmetry.

## 4. Keep the accessibility contract intact

- A headless or well-built library ships roles, keyboard handling, focus
  management and `aria-*` wiring. Composition undoes it: a `div onClick`
  wrapped around a trigger, a custom close button outside the dialog's focus
  trap, `asChild`/`render` misuse that drops the semantic element.
- Prefer the library's polymorphic escape (`asChild`, `render`, `as`,
  `component`) over nesting two interactive elements.
- Never re-implement a primitive the library ships (menu, dialog, combobox,
  tooltip, tabs). Hand-rolled twins are where the WCAG failures live;
  `a11y-audit` (this plugin) is the checklist.

## 5. Composition over configuration

- Compound components (`Dialog.Root`/`.Trigger`/`.Content`, `Select.*`) are
  the library's public API; a wrapper that flattens them into twelve boolean
  props recreates the prop explosion headless libraries were built to escape.
- One wrapper per project-level concept (`AppDialog`, `FormField`) is fine when
  it encodes the project's tokens and defaults; wrap for consistency, not to
  hide the library.
- Variants: use the library's variant API (`variants` in the theme, `cva` for
  Tailwind sets, `data-*` attributes for headless) rather than className
  ternaries per call site.

## 6. Docs, registry and MCP — not memory

- Resolve the installed major and read that major's docs. Headless libraries
  in particular renamed APIs between 0.x and 1.0 (Base UI's `render` prop, Ark's
  `.Root` split, React Aria Components vs the hooks package).
- When design-lab's registry-source MCP (`registry_search`/`registry_get`) or a
  library's own MCP/JSON manifest is available, query it before writing a
  component. Unavailable → say so and cite the docs URL from
  `references/library-map.md`.

## Routing: which sibling owns what

| Library | Go to |
|---|---|
| shadcn/ui (Radix or Base UI build), its registries | `shadcn-best-practices`, `shadcn-theming` |
| ReUI, Aceternity UI | `reui-best-practices`, `aceternity-best-practices` |
| Astryx | `astryx-best-practices` |
| Material UI, MUI X | `mui-best-practices` |
| Tailwind utility work, daisyUI classes | `tailwind-best-practices` |
| Everything else in `references/library-map.md` | this skill + the docs URL there |

## Review checklist

- Library identified from the manifest; nothing built beside it.
- Ownership model named (copy-in vs dependency) and the edits match it.
- Tokens flow through the library's theme channel; no instance-level hex or px.
- Both colour schemes rendered on touched screens.
- No hand-rolled primitive the library ships; polymorphic escape used correctly.
- Installed major resolved; docs/registry/MCP consulted for names and props.

## Defer rule

- Scale VALUES (spacing, type, radius) → `design-tokens`; palette generation → `/ui-ux:theme`.
- WCAG audit → `/ui-ux:audit`; React logic → web-dev's `frontend-reviewer`.
- Motion → `motion-best-practices`; dense data surfaces → craft-layer `information-design`.

## Anti-patterns

- **Second library for one component** — the date picker from Mantine dropped
  into a shadcn app.
- **Instance-level tokens** — `style={{ color: '#4f46e5' }}` on a themed button.
- **Wrapper explosion** — `<Modal isDanger isLarge hideClose noPadding …>`.
- **Primitive twins** — a bespoke dropdown beside the library's Menu.
- **Registry re-fetch over edits** — overwriting a restyled copy-in component.
- **Memory over docs** — a 0.x API recited on a 1.x install.

Standing: **agent-graded** — nothing in this marketplace detects a second
library being installed or an instance-level token; the reviewer and the
`/ui-ux:review` inventory are the only readers.
