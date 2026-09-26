# Astryx structure digest — packages, imports, CLI, themes, templates

> Last verified: 2026-09-26 — https://astryx.atmeta.com/docs/getting-started — npm:@astryxdesign/core@0.6

Read on demand from astryx-best-practices: structure only — packages, install,
CSS and theme wiring, the CLI, the theme and template inventories. Astryx is
**beta** (0.x, `0.6.3` on npm at the stamp above, `canary` publishing several
times a day; the 2026-09-26 re-read was the 0.6.1–0.6.3 changelog against this file,
which changed no package, CSS import, layer order, `defineTheme` key, CLI command or
peer — the full structure read is 2026-09-22's) — nothing here answers a props question, and a 0.x MINOR is where
this file goes stale: 0.3 → 0.5 split the package, renamed a category and added
the agent surface; 0.5 → 0.6 changed the CSS selector contract, added
`adaptations` to `defineTheme`, and shipped 7 more templates.

## Package layout and install

- Install set from the getting-started page:
  `npm install @astryxdesign/core @stylexjs/stylex @astryxdesign/theme-neutral @astryxdesign/cli`
  then `npx astryx init` (`--all` for extended guidance).
- Peers: React and ReactDOM **>= 19.0.0**, plus `@stylexjs/stylex` (`^0.19.0`
  per npm). React 18 cannot adopt Astryx without upgrading first.
- Packages: `@astryxdesign/core` (components, `theme` and `Layout` entrypoints),
  `@astryxdesign/cli`, one `@astryxdesign/theme-<name>` per shipped theme,
  `@stylexjs/stylex` for the `xstyle` channel. Pre-built CSS ships with `core`,
  so the published package needs NO StyleX compiler; one IS required for
  `swizzle`d source and your own `stylex.create()`, and without it the component
  renders unstyled with no build or runtime error. On Next.js App Router use an
  SWC-based StyleX transform — `@stylexjs/babel-plugin` disables SWC and breaks
  `next/font`.
- Three global CSS imports are required, in this order:

  ```css
  @import '@astryxdesign/core/reset.css';
  @import '@astryxdesign/core/astryx.css';
  @import '@astryxdesign/theme-neutral/theme.css'; /* or the theme you chose */
  ```

  and the documented cascade order for `globals.css` (`/docs/styling`) is
  `@layer reset, theme, base, astryx-base, astryx-theme, components, utilities;`.

## Import shape

Subpath imports, never a barrel: `import {Button} from
'@astryxdesign/core/Button';`, layout primitives under one entrypoint (`import
{VStack} from '@astryxdesign/core/Layout';`), `Theme` from `@astryxdesign/core`,
`defineTheme` / `useTheme` from `@astryxdesign/core/theme`. `astryx component
<Name>` prints the exact import for the installed version.

## Theming (`/docs/theme`)

- Wrap the tree: `<Theme theme={neutralTheme} mode="system">`; `mode` is
  `'system'` (default), `'light'` or `'dark'`. Dark mode is **[light, dark]
  tuples** inside the theme, switched through CSS custom properties and media
  queries — there is no `dark` class or `data-theme` attribute to toggle.
- Two delivery modes per theme package: runtime (`@astryxdesign/theme-neutral`,
  injected during hydration) and built (`…/built` + its `theme.css`, SSR-safe).
  Prefer built in production; runtime component overrides FLASH on hydration.
- Custom theme: `defineTheme({...})` from `@astryxdesign/core/theme`. Top-level
  keys: `name`, `extends`, `color`, `typography`, `radius`, `motion`, `tokens`,
  `localTokens`, `components`, `adaptations`, `icons`, `fonts`, `indicators`,
  `onDark`, `onLight`. `components` holds per-component overrides keyed `base`
  or `<prop>:<value>` (`variant:ghost`, `status:neutral`) / a state name — never
  raw CSS selectors. `adaptations` (0.6) carries ordered `rules` over named
  `widthBreakpoints`, pointer precision, contrast and motion preference;
  conditions in one `when` are ANDed, later matching rules win.
- Scaffold with `astryx theme add <slug>`, compile with `astryx theme build
  ./src/themes/<name>.ts` → `.css`, `.js`, `.d.ts` and an optional
  `.variants.d.ts` for theme-declared custom variants. A built theme carries
  `__built: true` and the runtime will NOT repair stale CSS from it: after a
  core upgrade that moves the selector contract, rebuild and redeploy every
  artifact together.
- Shipped theme packages (7): neutral, butter, chocolate, gothic, matcha,
  stone, y2k, plus a built-in default. Any other theme name is unverified.

## Styling overrides (`/docs/styling`)

Ordered as the docs recommend; all are usage-site, none touch library output:

1. `xstyle={overrides.x}` — `stylex.create()` objects only, merged last;
   `:hover` needs an `@media (hover: hover)` guard.
2. Tailwind (v4) utilities via the bridge `@import "@astryxdesign/core/tailwind-theme.css";`
   mapping tokens to classes (`text-primary`, `bg-surface`, `rounded-container`).
3. `className` (appended after the component's own classes) and `style`
   (consumer wins on conflict).
4. Plain CSS against the stable base class plus reflected data attributes:
   `.astryx-button[data-variant="primary"]`. **Data attributes are the preferred
   selector surface.** Bare prop/state classes (`.primary`, `.sm`, `.checked`)
   are DEPRECATED — still emitted through the 0.7.0 removal window, and
   `astryx upgrade --apply` rewrites qualified `.css` selectors into an
   `:is(.primary, [data-variant="primary"])` union. Semantic
   `defineTheme({components})` keys did not change.

The docs add one the SKILL does not: no `style={{}}` on a raw `<div>` wrapper.

## CLI (`@astryxdesign/cli`, `/docs/cli`)

Prefer `npx @astryxdesign/cli …` for first-run use: bare `astryx` resolves to an
UNRELATED npm package until the CLI is installed.

- `astryx init [--features agents|theme] [--agent claude|cursor|codex|muse]` —
  wires the project; writes `AGENTS.md`, or `.claude/CLAUDE.md` with `--agent claude`.
- `astryx build "<idea>"` — composition kit: closest templates, block patterns,
  components. Bare `build` prints the page-building playbook.
- `astryx component [Name] [--props|--source|--showcase|--blocks]` — typed
  props/examples, and the category list, for the INSTALLED version.
- `astryx template --list` / `<name> [--skeleton]` — page and block templates,
  injected into the project. `astryx search <query>` ranks across all domains.
- `astryx theme add|list|build|targets|template` — see Theming.
- `astryx upgrade [--list|--codemod <n>|--apply]` — codemods between versions;
  also refreshes a stale agent-docs block.
- `astryx swizzle <Component>` — copies a component's source in as owned code:
  the sanctioned "eject", not a patch.
- `astryx hook [name]` / `astryx docs [topic]` — hook inventory; reference docs
  (`astryx docs tokens` is the token table).
- `astryx doctor [integration <leaf>]` — read-only diagnosis, exits 1 only on a
  FAIL, so it works as a CI step. `astryx manifest --json` self-describes every
  command, flag and response type.

Also `layout`, `discover`, `integration`, `gap-report`, `blog`. Global flags:
`--json` (typed `{type, data}`; errors carry stable append-only codes such as
`ERR_UNKNOWN_COMPONENT` — branch on `code`, not the message), `--detail
brief|compact|full`, `--dense` (token-efficient, meant for agents), `--lang
<en|zh|dense>`. Programmatic: `import {component, docs, discover, template,
hook, search} from '@astryxdesign/cli/api'`.

## Agent surface (`/docs/working-with-ai`)

The SKILL carries the template → skeleton → component order and the
`upgrade --apply` refresh; what only lives here:

- The layout guide starts from `astryx build "<idea>"` instead of that order.
- Hosted MCP server `https://astryx.atmeta.com/mcp` exposes `search(query)` and
  `get(name)` — for the PUBLISHED docs. The CLI answers for the installed
  version; when they disagree the lockfile wins.
- The docs advise an npm script alias so agents do not guess the binary path:
  `node node_modules/@astryxdesign/cli/clients/cli/bin/astryx.mjs`.

## Components and templates (as fetched 2026-09-22)

Eleven categories, "over 170 components" per the home page: Action, Chat,
Container, Content, Feedback & Status, Form Controls (renamed from Data Input
in 0.5.2), Layout, Navigation, Overlay, Table & List, Utility. 47 page
templates under the templates page's own ten filters: Dashboard, Table, Form,
Settings, Login, Tools, Content, AI Chat, Gallery, Shell.

**Member names are deliberately not listed.** They churn faster than anything
else here (40 templates on 2026-09-09, 47 today — the whole Dashboard filter is
new since; Scrollable Area joined Layout in 0.6), and `astryx component --list`
/ `astryx template --list` print the installed set, the one that compiles.
Per-component pages: `https://astryx.atmeta.com/components/<Name>`.

## Other doc pages worth knowing exist

`/docs/tokens`, `/docs/color|spacing|typography|elevation|motion|shape`,
`/docs/icons`, `/docs/illustrations`, `/docs/layout` (outside-in layout guide),
`/docs/principles`, `/docs/styling-libraries`, `/docs/cli-integrations`,
`/docs/browser-support`, `/changelog`, canary docs at
https://astryx-canary.vercel.app/, and two that carry rules:
`/docs/migration` (cascade-layer safety, `astryx upgrade`) and
`/docs/internationalization` — English is the ONLY shipped catalog today, other
locales are roadmap and apps pass their own; RTL derives from the locale.

## Beta discipline

The SKILL's steps bind; the one rule worth repeating at the point of use is
that a 0.x minor moves APIs, package layout, category names AND the CSS
selector contract, so resolve the installed version from the lockfile before
trusting any line above it.
