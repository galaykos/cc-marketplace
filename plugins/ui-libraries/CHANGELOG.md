# Changelog — ui-libraries

Consumer-facing changes only. Newest first.

## 0.5.0 — 2026-11-11

- **Single-purpose components in the library map**: Sonner (toasts), Vaul (bottom drawer), cmdk (command menu) and NumberFlow (animated numbers), each with its package, version, styling channel and docs URL. `component-libraries` now says these four jobs are not hand-built: use what the manifest has, else the one library the map names. Vaul's own README calls the repo unmaintained, so the row sends new Base UI work to the library's own Drawer.
- **Two registry rows**: Beautiful UI (AI-product surfaces such as streaming text and approval cards; a shadcn registry reached by URL, with its own `foundation` stylesheet) and RareUI (animated marketing effects; its own CLI).
- **A pointer to Emil Kowalski's `pick-ui-library` skill** for single jobs the map does not cover.

Standing: recorded — read from npm and each project's own pages on 2026-11-11. Not checked: an MCP server for any of the six, and Beautiful UI's licence beyond its site footer.

## 0.4.1 — 2026-11-11

- **ReUI: a legacy shadcn style gets Base UI items, and installs write to the theme.** `reui.md` said the registry's `{style}` value "must be a style ReUI publishes", which reads as a wrong style failing. It does not fail: `new-york` and `default` redirect to `base-nova`, so a Radix project receives `@base-ui/react` code. The reference now says so, with the `--dry-run` check and the `radix-*` styles to use. It also said missing extra tokens give off-brand components; items in fact ship `cssVars` the CLI writes into the theme, `--destructive-foreground` among them.
- **Mantine 9, Chakra UI 3, Ant Design 6 and Nuxt UI notes in the library map.** Mantine 9 needs React 19.2+ and renamed Grid `gutter` and `TypographyStylesProvider`. Chakra 3 replaced `extendTheme`, `colorScheme` and the `is*` boolean props. antd 6 needs `@ant-design/icons` 6 and renamed `destroyOnClose`. `@nuxt/ui-pro` is deprecated into `@nuxt/ui`. Each note links the library's own migration page.
- **Dead docs URLs replaced.** Ark UI (React and Vue), Reshaped and Skeleton in the library map; the two MUI migration index pages and the Joy UI landing page in `mui.md`. All answered 404; a dead URL is the fallback the skills send the model to when no MCP server is connected.
- **Astryx: the CLI is run as `npx @astryxdesign/cli`.** The skill's commands were written as bare `astryx …`; `npx astryx` fetches an unrelated npm package of that name. The warning was only in the reference.
- **Four skill descriptions match what the skills cover.** `aceternity-best-practices` names Magic UI and React Bits, which its body already governs. `component-libraries` names Svelte and no longer names PrimeReact, which has its own skill. `primereact-best-practices` no longer fires on `@primeuix/themes` alone, a package PrimeVue shares. `mui-best-practices` no longer claims Base UI, which its body hands to `component-libraries`.

Standing: recorded — read from npm and each vendor's pages on 2026-11-11; no script re-reads them. Not re-read: every library-map row not named above, and the Polaris row (`@shopify/polaris-types` is now 2.0.0 on npm; the row still describes 1.1.0).

## 0.4.0 — 2026-11-09

- **Astryx: the bare selector classes are gone, not deprecated.** `astryx-best-practices` said the bare prop/state classes (`.primary`, `.sm`, `.checked`) stayed "until 0.7.0 removes them". 0.7.0 (2026-10-13) removed them: components emit only target classes and reflected `data-*` selectors, 21 theme targets were renamed (`textarea` → `text-area`, `progressbar` → `progress-bar`, …) in `defineTheme({components})` and CSS alike, and the codemod is `astryx upgrade --from <0.6.x> --apply --path .`. 0.7.0 also took root `xstyle`/`className`/`style` off the field inputs (TextInput, Selector, Typeahead, the date and time inputs, …) in favour of `container*` / `control*` props; the skill and `references/astryx.md` now say both. Read 2026-11-09 from the core changelog (https://raw.githubusercontent.com/meta/astryx/main/packages/core/CHANGELOG.md, every 0.7.0–0.7.11 Breaking Changes entry; only 0.7.0 has any) and the npm registry (`latest` 0.7.11, peers unchanged). The rest was last read against 0.6, so both `Last verified` stamps keep 2026-09-26, the docs URL and `@0.6` (a stamp moves only on an end-to-end re-read) and the changelog is cited in the body; `check-doc-staleness.sh --live` reports the minor drift until that re-read. Standing: recorded.
- **A Library MCP column in `component-libraries/references/library-map.md`**, one cell per row: the vendor's own MCP server where one exists — an npm package (MUI, Chakra, Ark, HeroUI, Mantine, React Aria, Magic UI, PrimeReact, PrimeVue, Vuetify, Quasar, Primer, Flowbite, Atlassian's `@atlaskit/ads-mcp`, Shopify's Dev MCP), a CLI command (shadcn/ui, shadcn-vue, Ant Design's `antd mcp`), a hosted endpoint (Astryx, Nuxt UI, Untitled UI; ReUI and IBM Carbon behind a sign-in) or a paid one (daisyUI Blueprint) — each with its source, and "none found" for the rest. Read 2026-11-09: packages from the npm registry, hosted endpoints by an MCP `initialize` request, the rest from vendor docs. "None found" is not proof of absence, and community servers are not listed. The HeroUI row's note naming its MCP moved into the column. Standing: recorded.

## 0.3.1 — 2026-10-28

- **The `component-libraries` skill's description now reads in short, plain sentences.** It names the same libraries and design systems and keeps the words the model matches it on.
- **The `mui-best-practices` and `primereact-best-practices` descriptions read the same way.** Same packages, components and version notes.

## 0.3.0 — 2026-10-06

- **Magic UI and React Bits follow Aceternity's rules.** `aceternity-best-practices` no longer hands Magic UI to `ui-ux:motion-best-practices`: Magic UI (`@magicui/<name>`) and React Bits (`@react-bits/<Name>-<JS|TS>-<CSS|TW>`) are the same class of copy-in marketing effect, so placement, one hero effect per view, pausing off-screen, reduced motion, SSR randomness and theming apply to them, and their docs pages stand in for Aceternity's. One exception: an animated number (NumberTicker, CountUp) follows ui-ux's counter rule — final value in the markup, no count under reduced motion. Animate UI's app primitives and hand-written `motion/react` code stay with motion-best-practices. The skill's description is unchanged, so this plugin's always-on context does not move.
- **Two `component-libraries/references/library-map.md` rows**, read 2026-10-06 from the registry items, the licences and a `shadcn add --dry-run` on shadcn 4.21.2: Magic UI (`components/ui/<name>.tsx`; motion items import `motion/react`, CSS-only items add keyframes to the theme CSS; MIT) and React Bits (`components/<Name>.tsx`, or jsrepo; colours through props; deps per item, `ogl` for Aurora; MIT + Commons Clause — free inside a product, never sold or redistributed as components).
- **Standing:** agent-graded for the class rule — only a reader of a file's imports and origin can tell the classes apart; recorded for the map rows. Residuals: skill-router 0.24.0 sends the skill on a Magic UI or React Bits install command, but a later edit of an installed component file routes no Aceternity rules, and a quoted install argument routes shadcn's skill alone; the description still names only Aceternity.
- **Credit and effect.** Found while reviewing freshtechbro/claudedesignskills @1da73feb (MIT, © 2025 Claude Skills Project); rewritten here, not copied. Unmeasured: whether it changes what the model builds. No eval with a control arm covers it.

## 0.2.0 — 2026-10-05

- **An organisation's own service uses its official design system.** `component-libraries` §1 now says: when the project IS a GOV.UK service (one of the service manual's three domain forms, not every `*.gov.uk` site), a US federal `.gov` site, a Shopify app's embedded admin UI (App Home), an IBM product or an Atlassian app — said in the brief or evident in the repo — its official package is the required library, ranking above "do not install one unasked" because the system is the requirement. A repo already on another library makes it a migration to raise with the user, never a second library added silently, and a decided `Stack:`/`Locks:` line still outranks it. Never recreate its CSS by hand; never import its tokens and override most of them. A brief that wants only the look never installs a restricted system (GOV.UK, the USWDS banner, Polaris, Atlassian); another UK public-sector site may use GOV.UK's patterns, never its crown, GDS Transport or brand colours. Standing: agent-graded.
- **Five rows in `library-map.md`'s new Organisation design systems table**, read from npm and the official docs on 2026-10-05: GOV.UK Frontend (`govuk-frontend` 6.5.1), USWDS (`@uswds/uswds` 3.14.0), Shopify Polaris (web components from Shopify's CDN with `@shopify/polaris-types` 1.1.0; the React `@shopify/polaris` 13.9.5 is deprecated), IBM Carbon (`@carbon/react` 1.117.0, `@carbon/styles` 1.116.0, `@carbon/web-components` 2.64.0) and Atlassian (`@atlaskit/*` for Forge Custom UI and Connect — the Connect pairing not confirmed against Atlassian's docs, the two Forge facts checked — `@forge/react` for Forge UI Kit; `@atlaskit/pragmatic-drag-and-drop` is marked as not the design system). Each row carries its use restriction as the official source states it; Carbon has none. Standing: recorded — no script re-reads the restrictions, and the versions are as of the stamp.
- **`component-libraries`' description names the five systems**, so a brief for such a service reaches the skill before any import exists. Cost: this plugin's always-on context grows 37 tokens (408 → 445), measured by the marketplace repository's budget gate; that baseline moved for this plugin alone.
- **The README names what the router cannot see:** GOV.UK Frontend's Nunjucks templates, Sass entry points (`govuk-frontend`, USWDS's `uswds-core`) and Polaris's CDN script tag carry no quoted package import, so they reach the skill through its description alone. skill-router 0.23.1 routes the quoted imports.
- **Credit and effect.** The rule is adapted from [leonxlnx/taste-skill](https://github.com/leonxlnx/taste-skill) at ce26fc25 (MIT, © 2026 Leonxlnx), rewritten here rather than copied; the package names and restrictions were re-read from the official sources, not taken from upstream. Unmeasured: whether it changes what the model installs. No eval with a control arm covers it.

## 0.1.0 — 2026-09-26

- Split out of `ui-ux`, which had reached the 160,000-byte per-plugin prose cap
  (`pc_plugin_corpus`). Moved unchanged: `mui-best-practices`, `astryx-best-practices`,
  `reui-best-practices`, `aceternity-best-practices`, `component-libraries`. Skill names
  change from `ui-ux:<skill>` to `ui-libraries:<skill>`. Every suite that carries `ui-ux`
  now carries this plugin; a standalone `ui-ux` install needs this one added by name.
- New `primereact-best-practices`: PrimeReact 11 is a rewrite (GA 2026-07-15) — `@primereact/ui` vs the
  unstyled `primereact`, `@primeuix/themes@3` presets on `PrimeReactProvider`, compound parts, the renames,
  folded and Pro-only components, the Tailwind registry mode, and the PrimeUI licence key; v10 projects are
  left alone. A control-arm probe (`evals/primereact-v11-screen`, deterministic re-grade of the written files)
  measured the base model at 1/5 on v11 API and 0/5 on licence handling; with this skill, 5/5 and 5/5.
- MUI X per-major table (Data Grid / Pickers / Charts v8–v9), licence-key regeneration, Joy UI removal;
  `library-map.md` refreshed (HeroUI v3, PrimeVue v5 licence, Vuetify 4; Catalyst, Tremor, PrimeReact
  rows; base detection); ReUI and Aceternity keep only registry-specific lines and cite ui-ux's shared
  registries reference.
