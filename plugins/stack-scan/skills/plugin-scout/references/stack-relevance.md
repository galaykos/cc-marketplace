# Stack relevance — what `--full` excludes, and why

The ONLY stack→plugin exclusion source in this marketplace. `--full`
(`references/flags.md`) reads it to decide which leaves are bound to a stack the
repo does not have; the default three-tier report never reads it — a
stack-mismatched leaf still appears there as a tier-3 "no signal detected" row.
Plugin names in the `Plugin` column are gated by `pc_scout_names`
(`scripts/lib/plugin-checks.sh`, marketplace repo only): a name that leaves
`marketplace.json` fails the build here instead of becoming a leaf `--full`
silently skips — or, worse, a ghost it tries to install.

## The table

"dep X" is an **exact key** in `dependencies` or `devDependencies`, the same rule
as the tier-1 table in `SKILL.md` — `react-native-web` is not `react-native`. The
JS class is deliberately WIDER than that table (`vue`, `svelte` and `astro` earn no row in
SKILL.md's tier-1 table; `tailwindcss`'s own signals.md row targets `ui-ux`, which is not in
this class — it still counts as class evidence here; `vite` needs no `vite.config.*` here): suggesting needs one strong signal,
excluding needs the absence of every frontend signal. **A fired signals.md row always
wins:** a leaf whose own signal fired installs under `--full` whatever its class
says, so `--full` can never install less than `--yes`. That rule carries one row
alone: `gsap`/`lenis` earn `craft-layer` in signals.md without being class evidence
here, so a package.json with GSAP and no framework dep installs `craft-layer`, not `web-dev`. Every other
signals.md key for the JS-class leaves (`@react-three/fiber`, `components.json`,
`tailwindcss`) is already class evidence above. The
token column names STACKS a user can type, not plugins: the `removed-ok` markers on
those rows exist because three tokens share a name with plugins removed on
2026-08-26, and the removal is the reason they are tokens now.

| Class | Plugin | Manifest evidence that satisfies it | `--stack` tokens that satisfy it |
|---|---|---|---|
| PHP / Laravel | `laravel` | composer.json require `laravel/framework` or `inertiajs/inertia-laravel`, or package.json dep `@inertiajs/*` — the SKILL.md tier-1 keys. Bare composer.json never earns it: a Symfony or WordPress repo must not install laravel | `php`, `laravel`, `inertia` <!-- removed-ok --> |
| JS / web frontend | `web-dev`, `craft-layer` | package.json (scan root, or a workspace member one level deep under SKILL.md's Detection precondition — root `workspaces`, `pnpm-workspace.yaml` or `turbo.json`) declaring an exact dep among `react`, `react-dom`, `vue`, `svelte`, `@sveltejs/kit`, `astro`, `@angular/core`, `next`, `nuxt`, `react-native`, `vite`, `@inertiajs/*`, `@react-three/fiber`, `tailwindcss`, `three`; or a `components.json` at the scan root. Bare package.json never earns it: a Go repo with prettier must not install web-dev | `react`, `vue`, `svelte`, `astro`, `angular`, `next`, `nuxt`, `react-native`, `vite`, `node`, `inertia` <!-- removed-ok --> |

## Everything else

Every leaf not named above is **any stack** and is always in the plan — every eligible
leaf except the three in the table above. Count them from `references/catalog.md` at run
time (leaves, minus `stack-scan` and `all-plugins`) — never from a number written down.
That includes `ui-ux`: its a11y-audit, design-tokens and
theming-system skills are stack-agnostic, so a server-rendered app with no
JavaScript framework still gets it — and `ui-libraries` with it, so the companions of
`craft-layer` (`references/signals.md` Companions) always install when it does.
`stack-scan` itself and `all-plugins` are excluded by construction and never listed one by one —
`all-plugins` because an installer of everything inside a curated plan defeats the
plan; a user who wants everything is pointed at `/all-plugins:install` instead. Already-installed
leaves are skipped and counted in the plan's `Already installed (K)` line.

## The domain-bound rule

No leaf is **domain-bound** any more. The two that were — payments and LLM work exist
in a repo before any SDK or key lands in it — were removed on 2026-09-14; their
signals.md rows now route onward instead of to a plugin.

Every signal-earned leaf NOT named in the table above — devops, api-design,
security, resilience, database and toolchain-experts — installs under `--full` whether or not its signal fired. That list is
illustrative of "any stack", not a fifth class: a missing CI file does not make CI
discipline irrelevant, it makes it absent. `stack-scan` is the honest edge, and it is
settled by construction rather than by class: this scout ships inside it, so it is
already installed on every run and never appears in a plan, an exclusion line or a
count of what `--full` will install.

## Typed tokens

- A token restores its class ONLY when that class's manifest evidence is absent.
  The plan then prints one line per restored class:
  `JS / web frontend: included on --stack react, no manifest evidence`.
- When the manifest already satisfies the class, the token changes nothing.
  Manifest wins; there is no contradiction notice — `react` and `vue` are one class, <!-- removed-ok -->
  so "typed react, `@inertiajs/vue3` installed" is not a detectable conflict.
- A token never changes a leaf's tier in the default flow: `--yes --stack laravel`
  installs exactly what `--yes` installs.
- Stacks this marketplace does not cover — Django, Rails, Go, Rust — need no
  token: absent evidence already excludes both stack classes, and
  `references/signals.md` routes them to `--skills` (the `vercel-skills-scout` skill).
- Form, casing and the abort on an unknown token: `references/flags.md` `--stack`.

## Worked examples

**Laravel + Inertia + React** — composer.json requires `laravel/framework`,
package.json declares `@inertiajs/react` and `vite`, no Stripe or LLM signal:

- Excluded by construction: `stack-scan`, `all-plugins`.
- **No stack-mismatched leaf.** Both stack classes are satisfied, so every
  eligible leaf installs.
- `web-dev` brings the Next.js and React Native skill descriptions into the
  model's skill listing regardless — no level of this marketplace skips them for a
  React app, and the plan should not read as if it did.

**Next.js app** — package.json declares `next`, no composer.json:

- Excluded: `laravel` — PHP / Laravel evidence absent (no `laravel/framework`, no
  `@inertiajs/*`); `--stack laravel` includes.

## Standing

**Agent-graded.** No script checks that the exclusion was applied, that the
evidence keys were matched exactly rather than by substring, that a domain leaf
was held back, or that the typed-token line printed. Gated: plugin names in the
table above (`pc_scout_names`, which reads this file by name) and catalog
freshness (`generate.sh --check`). Residual worth naming: a wrong evidence key in
this table silently installs or skips a plugin on every `--full` run — only a human
reading the plan block before the confirm catches it, which is why `--full` prints
every exclusion with its reason.
