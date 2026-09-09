# Astryx structure digest — packages, imports, CLI, themes, templates

> Last verified: 2026-09-09 — https://astryx.atmeta.com/docs/getting-started — npm:@astryxdesign/core@0.5

Read on demand from astryx-best-practices. Structure-stable material only:
package layout, install shape, the CSS and theme wiring, the CLI surface, the
component category inventory, the shipped theme and template lists. Astryx is
**beta** (0.x, `0.5.4` on npm at the stamp above, with a `canary` dist-tag
publishing several times a day) — nothing in this file answers a props
question, and a 0.x MINOR is where this file goes stale: 0.3 → 0.5 split the
package, renamed a category and added the CLI agent surface below.

## Package layout and install

- Install set from the getting-started page:
  `npm install @astryxdesign/core @stylexjs/stylex @astryxdesign/theme-neutral @astryxdesign/cli`
  then `npx astryx init` (`--all` for extended guidance).
- Peer dependencies: React and ReactDOM **>= 19.0.0**. An app on React
  18 cannot adopt Astryx without upgrading first — say so before any code.
- Packages: `@astryxdesign/core` (components, `theme` and `Layout` entrypoints),
  `@astryxdesign/cli`, one `@astryxdesign/theme-<name>` package per shipped
  theme, `@stylexjs/stylex` for the `xstyle` override channel. Pre-built CSS
  ships with `core`; a StyleX compiler is needed only for your OWN
  `stylex.create()` overrides.
- Three global CSS imports are required, in this order:

  ```css
  @import '@astryxdesign/core/reset.css';
  @import '@astryxdesign/core/astryx.css';
  @import '@astryxdesign/theme-neutral/theme.css'; /* or the theme you chose */
  ```

  and the documented cascade order for `globals.css` is
  `@layer reset, theme, base, astryx-base, astryx-theme, components, utilities;`.

## Import shape

- Subpath imports, never a barrel. Most components are their own subpath
  (`import {Button} from '@astryxdesign/core/Button';`); layout primitives sit
  under one entrypoint (`import {VStack} from '@astryxdesign/core/Layout';`);
  theming under `@astryxdesign/core/theme`. `astryx component <Name>` prints
  the exact import for the installed version — use it rather than guessing
  which of the two shapes a component has.

## Theming (`/docs/theme`)

- Wrap the tree: `<Theme theme={neutralTheme} mode="system">` from
  `@astryxdesign/core` with the theme object from its package. `mode` is
  `'system'` (default), `'light'` or `'dark'`. Dark mode is **[light, dark]
  tuples** inside the theme, switched through CSS custom properties and media
  queries — there is no `dark` class or `data-theme` attribute to toggle.
- Two delivery modes per theme package: runtime (`@astryxdesign/theme-neutral`,
  styles injected during hydration) and built
  (`@astryxdesign/theme-neutral/built` + its `theme.css`, no hydration flash,
  SSR-safe). Prefer built for production.
- Custom theme: `defineTheme({ name, color, typography, tokens, components })`
  from `@astryxdesign/core/theme`; `components` holds per-component overrides
  keyed `base` / `'variant:<name>'`. Scaffold with `astryx theme add <name>`,
  compile with `astryx theme build ./src/themes/<name>.ts` → `.css`, `.js`,
  `.d.ts`. `astryx theme list` names the shipped ones.
- Shipped theme packages (7): neutral, butter, chocolate, gothic, matcha,
  stone, y2k. The themes page also names a built-in default. Any other theme
  name the model remembers is unverified.

## Styling overrides (`/docs/styling`)

Ordered as the docs recommend; all are usage-site, none touch library output:

1. `xstyle={overrides.x}` — `stylex.create()` objects only, merged last;
   `:hover` needs an `@media (hover: hover)` guard.
2. Tailwind utilities via the bridge `@import "@astryxdesign/core/tailwind-theme.css";`
   which maps tokens to classes (`text-primary`, `bg-surface`, `rounded-container`).
3. `className` (appended after the component's own classes) and `style`
   (consumer wins on conflict).
4. Plain CSS against stable classes + data attributes:
   `.astryx-button[data-variant="primary"]`.

The docs' own "don't" list: hardcoded colours or spacing, `!important`, and
wrapping a component in a `div` for margin — use `xstyle` instead.

## CLI (`@astryxdesign/cli`, `/docs/cli`)

| Command | What it answers |
|---|---|
| `astryx init [--features agents] [--agent claude\|cursor\|codex]` | wires the project; writes `AGENTS.md`, or `.claude/CLAUDE.md` with `--agent claude`; `--apply` refreshes stale blocks after upgrades |
| `astryx search <query>` | one ranked list across components, hooks, docs, templates |
| `astryx component [Name] [--props\|--source\|--showcase]` | the typed props/examples for the INSTALLED version |
| `astryx hook [name]` | the hook inventory (focus trap, theme, and the rest) |
| `astryx docs [topic]` | reference docs; `astryx docs tokens` is the token table |
| `astryx template --list` / `astryx template <name> [--skeleton]` | page and block templates, injected into the project |
| `astryx theme add\|list\|build` | see Theming |
| `astryx upgrade [--list\|--codemod <n>\|--apply]` | codemods between versions |
| `astryx swizzle <Component>` | copies a component's source into the project for deep customisation — the sanctioned "eject", not a patch |
| `astryx doctor` | read-only setup diagnosis |
| `astryx manifest --json` | self-describing capability manifest: every command, flag, response type |

Global flags: `--json` (typed `{type, data}` envelope; errors carry stable
codes such as `ERR_UNKNOWN_COMPONENT`, `ERR_CORE_NOT_FOUND`), `--detail
brief|compact|full`, `--dense` (token-efficient output meant for agents).
Programmatic: `import {component, docs, search} from '@astryxdesign/cli/api'`.

## Agent surface (`/docs/working-with-ai`)

- The docs' recommended order before writing UI: `astryx template --list` →
  `astryx template <name> --skeleton` → `astryx component <Name>`.
- Hosted MCP server: `https://astryx.atmeta.com/mcp` exposing `search(query)`
  and `get(name)`. It answers for the PUBLISHED docs; the CLI answers for the
  installed version — when they disagree the lockfile wins.
- The docs advise an npm script alias for the CLI so agents do not invoke a
  wrong path.

## Component category inventory (as fetched 2026-09-09)

Eleven categories, "over 170 components" per the home page; the 0.5.2 release
renamed **Data Input → Form Controls**. Glosses are representative:

- **Action** — Button, Button Group, Icon Button, Toggle Button (+ Group),
  Dropdown Menu, More Menu, Segmented Control, Toolbar, Link.
- **Chat** — Chat Composer, Layout, Message, Message Metadata, System
  Message, Tool Calls.
- **Container** — Card, Clickable Card, Selectable Card, Carousel, Collapsible.
- **Content** — Avatar (+ Group), Blockquote, Citation, Code, Code Block,
  Empty State, Heading, Text, Icon, Kbd, Markdown, Thumbnail, Timestamp, Token.
- **Feedback & Status** — Badge, Banner, Progress Bar, Skeleton, Spinner,
  Status Dot.
- **Form Controls** — Text/Number/Date/Date Range/Date Time/Time/File Input,
  Text Area, Field, Checkbox Input, Radio List, Switch, Slider, Selector,
  Multi Selector, Complex Selector, Typeahead (+ Item), Tokenizer, Calendar,
  Power Search.
- **Layout** — App Shell, Layout, Stack, Grid, Section, Divider, Form Layout,
  Aspect Ratio, Resize Handle.
- **Navigation** — Breadcrumbs, Pagination, Outline, Side Nav, Stepper, Tab
  List, Top Nav (+ Menu, Mega Menu, Mega Menu Featured Card).
- **Overlay** — Dialog, Popover, Tooltip, Toast, Hover Card, Lightbox,
  Overlay, Command Palette, Bottom Sheet (+ Switcher; 0.5).
- **Table & List** — Table, List, Tree List, Overflow List, Metadata List.
- **Utility** — VisuallyHidden.

Per-component pages: `https://astryx.atmeta.com/components/<Name>`.

## Templates (`/templates`, 40 as fetched 2026-09-09)

Installed with `npx @astryxdesign/cli template <name>`; families, each name
verbatim from the page:

- **Tables** — `table-filter`, `table-grouped`, `table-inbox`, `table-page`.
- **Forms** — `contact-form`, `payment-form`, `form-two-column`,
  `form-wizard`, `form-wizard-dialog`, `form-wizard-inline`,
  `form-wizard-vertical`, `checkout-wizard`.
- **Settings** — `settings`, `settings-dialog`, `settings-sidebar`.
- **Auth** — `login-card`, `login-split`, `login-sso`.
- **Workspaces** — `file-explorer`, `ide`, `kanban-board`, `editor`, `library`.
- **Docs** — `documentation`, `documentation-design`, `documentation-technical`.
- **Detail** — `detail-page`, `product-detail`, `work-item-detail`.
- **AI** — `ai-chat`, `ai-chat-landing`.
- **Marketing / galleries** — `centered-hero`, `gallery-hero`, `side-gallery`,
  `classic-gallery`, `mixed-gallery`, `product-gallery`.
- **Shells** — `shell-nav`, `shell-side-nav`, `shell-top-nav`.

A template is a starting layout, not a finished screen: it is injected as
owned code, so the review rules for copied components apply to it.

## Other doc pages worth knowing exist

`/docs/tokens` (all tokens), `/docs/color|spacing|typography|elevation|motion|shape`,
`/docs/icons`, `/docs/internationalization` (30 locales in 0.5),
`/docs/migration` (cascade-layer safety and `astryx upgrade`),
`/docs/styling-libraries` (interop), `/docs/browser-support`, `/changelog`,
and the canary docs at https://astryx-canary.vercel.app/ for unreleased APIs.

## Beta discipline (summary — the SKILL's steps stay binding)

1. Resolve the installed version from the lockfile FIRST; a 0.x minor changes
   APIs, package layout and category names.
2. Props, variants, defaults and event signatures are NEVER answered from this
   digest or from memory — run `astryx component <Name>` for the installed
   version, or open the component's page for the published one.
3. Prefer the CLI (`--json`) or the MCP server over prose docs when either is
   reachable; they are the typed sources.
