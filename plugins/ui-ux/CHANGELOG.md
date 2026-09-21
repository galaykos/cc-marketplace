# Changelog — ui-ux

Consumer-facing changes only. Newest first. Started at 0.18.0, the release that
added this plugin's first PostToolUse hook; earlier versions have no entries
rather than invented ones.

## 0.24.3 — 2026-09-22

### Fixed
- `references/mui.md`'s `Last verified` stamp put the npm tail before a parenthetical, so
  `check-doc-staleness.sh` reported it malformed on every run and `--live` never saw
  MUI. Tail moved last; the regex the same 2026-09-09 commit added now parses it.

## 0.24.2

### Fixed
- README promised `CC_REMIND=off` silences "every advisory in this marketplace"; it silences every reminder hook, and task-runner's scope tripwire is an advisory that deliberately reads no switch. Reworded to the promise that is true.

## 0.24.1

### Changed
- **`tailwind-best-practices` is now the v3/v4 inversion skill it should always have
  been.** Its body was a style-rule catalogue — class ordering, `@apply` vs components,
  mobile-first, `dark:`, `@layer components` — the shape `rationale/measured-zero-shapes.md`
  §3 measured at 0 or worse for the four ui-ux style-rule skills it got removed (named
  there, not here), and that this skill was never tested against. Replaced with
  the facts a v3-shaped memory gets WRONG on a v4 project, each re-read from
  tailwindcss.com on 2026-09-15 rather than recalled: `@import "tailwindcss"` for the
  `@tailwind` directives; the config file no longer auto-detected (`@config` opts back
  in), so `theme.extend`, `darkMode: 'class'`, `content:`, `safelist`, `corePlugins` and
  `separator` advice lands nowhere; `@custom-variant dark (&:where(.dark, .dark *))`;
  `@source` / `@source inline()`; `@tailwindcss/postcss` and `@tailwindcss/vite`;
  `@apply` in a `<style>` block or CSS module silently producing nothing without
  `@reference`; and the quiet one — `shadow-sm`, `rounded`, `blur`, `drop-shadow`,
  `backdrop-blur` and `ring` all renamed a step, so a v3 class string still compiles and
  renders a DIFFERENT value. The description now carries `tailwind.config.js`, `@theme`,
  `@custom-variant`, `@source` and the renamed utilities as trigger vocabulary; it used
  to say only "utility ordering, components vs @apply, responsive/dark variants, config
  tokens", which matched no phrasing a v4 problem is reported in. Body: 109 → 96 lines.
- **`/ui-ux:theme` and `shadcn-theming` now say Astryx.** Both handle it as a target
  with a structurally different write (`defineTheme()` tuples, not CSS variables) and
  neither description named it, so an Astryx project asking for a theme matched nothing.
  The README's two stack lists were at five targets for the same reason.
- **Descriptions cut where they recapped work instead of naming a trigger**
  (`component-libraries`, `astryx-`, `mui-best-practices`) — the always-on channel pays
  for every one, and the dispatcher only ever matches the trigger half. Net effect of
  every description change in this release: +3 chars.

### Fixed
- **`palette-default`'s header claimed "ui-ux ships in 10 bundles to craft-layer's 4".**
  The marketplace has four bundles in total, so the number was never reachable; the true
  counts are three and one. Replaced with the asymmetry that cannot drift — craft-layer
  DEPENDS on ui-ux — plus the recount command. The same sentence was in this file's
  0.22.x entry and is corrected there too.
- **Two `theming-system` references cited `shadcn-theming` by LINE RANGE, and all four
  citations were wrong** (`:74-82` for a section that starts at 80; `:24-25` and
  `:25-26`, in the same file, for one bullet at 26). They now cite the section and token
  row by name, which cannot go stale when the file above them grows.
- **`shadcn-best-practices` named Base UI the default base, then called the CLI's
  per-component dependency "its Radix dependency" 38 lines later.** The install rule is
  now base-agnostic.
- **The body measure had two different bounds in one plugin** — `design-tokens` said
  60–75 characters, `ui-ux-engineer`'s checklist said 45–75. `design-tokens` is now the
  single source at 45–75 and the agent cites it.
- **The `component-libraries` lane row triggered on React only** while the skill, its
  description and its `library-map.md` all cover Vue.
- **The test-case count in this file said 10; the harness has 11.**

### Removed
- Restated blocks, for corpus headroom against the 160,000 B per-plugin ratchet:
  `design-tokens`' "Reviewing a token system" checklist (a third statement of rules its
  scales section and anti-patterns already carry), and the restated halves of
  `shadcn-best-practices`' and `a11y-audit`' anti-pattern lists. ui-ux' on-invoke prose
  corpus: 159,890 → 159,816 B, so this release adds the Tailwind v4 content and still
  leaves more headroom than it started with.

## 0.23.1

### Fixed
- **`preview-guard` now has an off-switch**, `CC_PREVIEW_GUARD=off` — it previously had none, and with taskmaster also installed it asks twice on a strong signal.
- **The twin is now gated.** This file and taskmaster's copy are one guard shipped twice, and their correctness as a pair depends on byte-identity (both hash the same session id to the same marker, which is what leaves exactly one asker). A new `pc_twin_files` check fails the build if they drift.

## 0.23.0

### Changed
- **Registry lookups route to the registries' own MCP servers.** The stack skills used
  to name design-studio's bundled `registry-source` server; that plugin is gone, so <!-- removed-ok -->
  `shadcn-best-practices`, `component-libraries`, `reui`, `aceternity` and `/ui-ux:build`
  now name shadcn's own server (`npx shadcn@latest mcp init`), ReUI's hosted
  `mcp.reui.io` with its `claude mcp add` line, and Aceternity's raw
  `registry.json` — it publishes no server. The rule is unchanged and is the point:
  component APIs come from a registry, never from memory. What a user loses is one
  install delivering the servers; what they gain is a server its own maintainers ship.
  <!-- removed-ok -->
- **The real-component preview landed in taskmaster, not here.** design-studio's <!-- removed-ok -->
  `real-preview` was headed for this plugin; ui-ux's on-invoke prose corpus measured <!-- removed-ok -->
  159,517 B against a 160,000 B ratchet, so absorbing a 17 KB skill would have meant
  cutting 17 KB of skills people use to fund one measured at a single invocation.
  It is now the real-component rung of `taskmaster:visual-decisions`, the skill that
  already owns the mockup fidelity ladder. What a ui-ux-only install loses: the
  escalation above a shell mockup. `/ui-ux:build` names where it went.
- **The two hooks are tiered apart in the README.** It said "Both advisory";
  `preview-guard` returns `permissionDecision: "ask"`, which stops the tool call until
  a human answers — this repo's own vocabulary calls that a gate with a human in it.
  `palette-default` is the advisory one. Neither script changed; the sentence
  describing them did.

## 0.22.3

### Changed
- **`.claude/ui-ux/` ignores itself.** The directory now writes a self-ignoring `.gitignore` (`*`) the first time a hook creates it. Plugin state under the user's `.claude/` showed up as untracked in `git status` in every repo without a hand-written ignore line — observed live, and named by overseer's acceptance protocol as "other plugins' scratch" — one `git add -A` away from being committed. One harness assertion per plugin. (`hooks/palette-default.sh`.)

## 0.22.2

### Changed
- Every hand-off to the real-component preview and the registry MCP names
  `design-studio` — theme-design and design-lab were merged into it (2026-09-14 <!-- removed-ok -->
  consolidation plan). the real-component rung of `taskmaster:visual-decisions`, `/design-studio:init`; the <!-- removed-ok -->
  registry tools are unchanged. No behaviour change.

## 0.22.1

### Removed
- `/ui-ux:review`. The code-review fan-in already loads the matching ui-ux stack skill <!-- removed-ok -->
  and `a11y-audit` for any diff touching markup or utility classes, so the entry was a
  second name for the same pass (2026-09-14 consolidation plan). `ui-ux-reviewer`,
  `/ui-ux:audit`, `/ui-ux:build` and `/ui-ux:theme` are unchanged; `/ui-ux:build` now
  offers `/code-review:review` as its post-build step.

## 0.21.0

### Changed
- **`astryx-best-practices` rewritten against Astryx 0.5.4** (was a 0.3-era digest,
  last verified 2026-07-22). What changed upstream and now in the skill: the install
  set is four packages (`core`, `@stylexjs/stylex`, a `theme-<name>` package, `cli`),
  React 19+ is the peer range, three global CSS imports and a documented `@layer`
  order are mandatory, themes are `<Theme theme mode>` + `defineTheme()` with
  light/dark token tuples (no `dark` class), overrides go `xstyle` → Tailwind bridge
  → `className`/`style` → stable classes, `astryx swizzle` is the sanctioned eject,
  the Data Input category is now Form Controls, 40 CLI-installed page templates
  exist, and the agent surface is the CLI's `--json`/`--dense`/`manifest`, the
  generated `AGENTS.md`/`.claude/CLAUDE.md`, and a hosted MCP server.
  `references/astryx.md` carries the package/CSS/CLI/theme/template inventory
  (last verified 2026-09-09, stamped `npm:@astryxdesign/core@0.5` so
  `check-doc-staleness.sh --live` flags the next 0.x minor).
- `lane.tsv` declares `astryx-best-practices` (build, `astryx-idioms`), the same
  standing `mui-best-practices` already had.
- `/ui-ux:theme`, `shadcn-theming` and its `token-vocabularies.md` detect an Astryx
  project and route the theme WRITE to the `defineTheme()` file instead of
  `globals.css`; the colour preview is unchanged.
- `component-libraries/references/library-map.md` Astryx row names the theme
  channel and React 19 requirement correctly.

## 0.20.3

### Changed
- Citations of the four-laws / has-teeth doctrine now point at
  `.claude/skills/authoring-skills/SKILL.md` in the marketplace repository — the
  authoring plugin was demoted to a tracked project skill on 2026-09-03. Prose only;
  no behaviour change.

## 0.20.2

### Changed
- `lane.tsv` rows for this plugin's chassis-generated artifacts are now rendered by
  `scripts/generate.sh` from `lane` keys on its `.chassis.json` objects (a
  `# generated:start` … `# generated:end` block) instead of being typed by hand —
  same territory, trigger and yields_to; `generate.sh --check` fails if the two drift.
  No behaviour change for a user of the plugin.

## 0.20.1

### Changed
- `component-libraries` is framework-agnostic in name as well as rule: description
  and intro say React or Vue, and `references/library-map.md` gains a Vue 3 section
  (Reka UI, shadcn-vue, Headless UI and Ark UI Vue builds, PrimeVue, Vuetify, Element
  Plus, Naive UI, Quasar, Nuxt UI) plus the Inertia adapters as a non-library row.

## 0.20.0

### Added
- **`mui-best-practices`** — Material UI (`@mui/material`, `@mui/x-*`): lockfile-first
  version discipline (v7 and v9 removed APIs a v5 memory still recites; v8 was
  skipped), one-level imports, `createTheme` with `cssVariables`/`colorSchemes`,
  `theme.vars` + `applyStyles` over `palette.mode` branches, `useColorScheme` and
  `InitColorSchemeScript`, `slotProps` over class-selector reach-ins, Emotion default
  vs alpha Pigment CSS, Base UI as the headless sibling. `references/mui.md` carries
  the package family, theme API and per-major removals (last verified 2026-09-02).
- **`component-libraries`** — the library-agnostic floor for any React component
  library without a sibling skill: detect from the manifest and build in what the
  project has, copy-in vs npm-dependency ownership rules, tokens through the
  library's own theme channel, keep the a11y contract of headless primitives,
  composition over wrapper prop explosion, docs/registry/MCP over memory, and a
  routing table to the sibling skills. `references/library-map.md` maps Base UI,
  Radix, React Aria, Ark UI, Headless UI, Ariakit, Mantine, Chakra, Ant Design,
  HeroUI, Reshaped, Untitled UI, Kibo, daisyUI and more to signal, theme channel
  and docs URL, and records shadcn/ui's July 2026 Base UI default.

### Changed
- `/ui-ux:review` and `/ui-ux:build` detect MUI and route any other library to
  `component-libraries`; the review docs list gains https://mui.com/material-ui/.
- `ui-ux-engineer` / `ui-ux-reviewer` name the two new skills in their stack
  detection; `lane.tsv` declares both skills.

## 0.19.5

### Changed
- `/ui-ux:build` routes an undecided visual choice to `/design-lab:preview` only; <!-- removed-ok -->
  `/design-lab:stage` (the shadcn-only sandbox) was removed from design-lab 0.2.0
  because the UI layer is library-agnostic — shadcn, a registry, MUI, Astryx or
  vanilla Tailwind — and a sandbox that ships one library decides nothing about
  a project using another.

## 0.19.4

### Changed
- **Worker agents default to no comment.** The "Code shape" section no longer says
  "match the surrounding file's comment density". The default is no comment; a comment
  is one line for a fact the code cannot show, a docblock that repeats the signature is
  deleted, and only a house style stated in the project's CLAUDE.md overrides it. The
  matching hooks (deny lanes and the 0.4:1 ceiling) ship in code-review.

## 0.19.3

### Changed
- Registry and preview hand-offs name design-lab (`/design-lab:preview`, `/design-lab:stage`, <!-- removed-ok -->
  its `registry-source` MCP); design-preview, shadcn-studio and registry-source merged <!-- removed-ok -->
  into it on 2026-09-02.

## 0.19.2

### Changed
- `motion-best-practices` points Three.js work at craft-layer's `threejs-best-practices`;
  the threejs plugin merged into craft-layer on 2026-09-02. <!-- removed-ok -->

## 0.19.0

### Added
- **a11y merged in.** `/ui-ux:audit` (was `/a11y:audit`), the `a11y-audit` skill, and <!-- removed-ok -->
  the `a11y-engineer` worker ship here; `/ui-ux:review` keeps deferring the deep WCAG
  pass to the audit command, now one plugin over. Nothing in the audit's checklist or
  report format changed.

## 0.18.6

### Changed
- **Meta-prose compressed to a one-line standing tag.** Sections narrating this
  skill's relationship to its siblings — boundary tours, "what this is NOT" lists,
  and in places the repository's own drift history — are replaced by a `Standing:`
  line on the rule they qualify. No actionable rule changed, and every named
  cross-skill reference was preserved: those names are what make the skills they
  point at reachable, and a re-scan confirmed none was orphaned.

## 0.18.5

### Fixed
- **"Shipping any motion with no `prefers-reduced-motion` path" is back in
  `motion-best-practices` § Common mistakes**, deleted at `dfe8fcf`. The skill opens
  by arguing this is a hard accessibility rule because vestibular disorders make
  large motion physically harmful, and Common mistakes is the list a reviewer scans
  against a diff — the rule the skill opens with was absent from it. Six craft-layer
  skills cite this file as the owner of the reduced-motion mechanism.
- **Two double-loaded bullets split**: permanent `will-change` vs autoplaying loops,
  and View Transitions feature detection vs the GSAP Club-licence correction (free
  since 3.13). The licence item is a fact correction about the world, invisible
  appended to an unrelated bullet.
- **"(method names, options, version numbers)" restored** to the definition of a
  version-sensitive literal — the test deciding when the model must fetch live.

## 0.18.4

### Changed
- **Every hook entry now declares a `timeout`.** `palette-default.sh` 5s, `preview-guard.sh` 10s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.18.3

### Added
- **`/ui-ux:build` offers its reviewer twin** after returning changed files —
  "Run /ui-ux:review on the result now (Recommended)" / "Skip". A standalone
  build previously shipped self-graded even though the reviewer existed.

### Fixed
- **`shadcn-theming`'s "contrast gates are hard" claim names its standing**:
  agent-graded on the theme path — no script computes ratios there; the only
  mechanical checker is craft-layer's `contrast.mjs` under `/craft-layer:audit`.
- **Ghost-skill pointers removed** (css-grid/flexbox/css3 — removed 2026-08-20,
  still named by the generated engineer's procedure and astryx's defer rule);
  plain CSS is stated as baseline. astryx and shadcn skills no longer route to
  the removed react plugin's skills. <!-- removed-ok -->

## 0.18.1

### Fixed
- **`theming-system`'s opening sentence ended mid-clause** — "…or ship a theme.
  Those" followed by a blank line. Inherited from craft-layer's 2026-07-27 prose
  strip when the skill moved here, and shipped on every load since.
- **`hooks/palette-default.sh` recorded the wrong reach for the gate it stands in
  for.** It said `divergence.mjs` is "invoked only by `/craft-layer:craft` step 7
  and `/craft-layer:audit` step 4" — one call site described as two. The hook's
  own argument for existing is unchanged and still holds.

## 0.18.0

### Added
- **`hooks/palette-default.sh`** — a `PostToolUse` advisory that names the
  indigo/violet/purple category default when it reaches a UI file through Tailwind
  class strings (`bg-indigo-600`, `from-violet-500`) or a literal default swatch
  (`#6366f1`). One nudge per session, never per file.

  **Standing: advisory. It cannot block and will not.** A violet brand is a
  legitimate answer, and the only thing separating "chose it" from "reached for the
  default" is intent, which no script reads. craft-layer's stricter equivalent
  (`utility-palette`) can demand a written waiver because a craft run has a
  contract to record one in; a bare edit has nowhere to record consent, so blocking
  here would punish the legitimate case with no way to say so.

  **Why it exists:** craft-layer's gate runs only inside `/craft-layer:craft` step 7
  and `/craft-layer:audit` step 4. A plain "build me an app" turn runs neither. In a
  measured control/treatment run on 2026-08-17, a Laravel build shipped **23 indigo
  utilities across 5 Blade views** with every gate in this marketplace green,
  because none of them was on that path. craft-layer DEPENDS on ui-ux, so every
  craft-layer install already carries this hook while the reverse does not hold, and
  ui-ux additionally ships in bundles craft-layer is absent from — the reach half of a
  rule craft-layer owns the depth of. (This paragraph named "10 bundles to
  craft-layer's 4" until 2026-09-15; the marketplace has four bundles in total, so the
  number was never reachable. Recount, do not quote:
  `grep -l '"ui-ux"' plugins/*/.claude-plugin/plugin.json | grep -v '/ui-ux/'`.)

  Silence with `CC_PALETTE=off`, or `CC_REMIND=off` for every advisory nudge here.

  Known gaps, stated in the hook header: it counts a hue, never a composition
  (three equal cards, a ribbon on the middle one, a centred hero are the rest of
  the fingerprint and go undetected); it reads literal class strings only, so a
  palette behind `cn(...)` or a component prop is invisible; the hex list is the
  default swatches **by value**, because reading hue from hex is wrong at this band
  — sRGB puts `#6366f1` at 238.7°, far below the 275–315° those same swatches
  occupy in oklch; and its token cost is unmetered, because `context-budget.sh`
  probes the dynamic channel with a synthetic `Edit` that is not a UI file.

- **`scripts/__tests__/palette-default.test.sh`** — 11 cases. The first is the
  observed Blade regression verbatim: if it stops firing, the hook has lost the
  only failure it is known to catch. Four are silence cases, including hues just
  outside the band (`blue-500`, `fuchsia-500`) — without those the family list
  would be taste rather than a derivation from craft-layer's 275–315° band.
