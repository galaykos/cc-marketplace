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
JS class is deliberately WIDER than that table (`vue` and `svelte` earn no row in
SKILL.md's tier-1 table; `tailwindcss` earns a signals.md row for `ui-ux`, not for this
class; `vite` needs no `vite.config.*` here): suggesting needs one strong signal,
excluding needs the absence of every frontend signal. **A fired signals.md row always
wins:** a leaf whose own signal fired (`@react-three/fiber` → craft-layer,
`components.json` → design-lab) installs under `--full` whatever its class says, so
`--full` can never install less than `--yes`. The
token column names STACKS a user can type, not plugins: the `removed-ok` markers on
those rows exist because three tokens share a name with plugins removed on
2026-08-26, and the removal is the reason they are tokens now.

| Class | Plugin | Manifest evidence that satisfies it | `--stack` tokens that satisfy it |
|---|---|---|---|
| PHP / Laravel | `laravel` | composer.json require `laravel/framework` or `inertiajs/inertia-laravel`, or package.json dep `@inertiajs/*` — the SKILL.md tier-1 keys. Bare composer.json never earns it: a Symfony or WordPress repo must not install laravel | `php`, `laravel`, `inertia` <!-- removed-ok --> |
| JS / web frontend | `web-dev`, `craft-layer`, `design-lab` | package.json (scan root, or a workspace member one level deep under SKILL.md's Detection precondition — root `workspaces`, `pnpm-workspace.yaml` or `turbo.json`) declaring an exact dep among `react`, `react-dom`, `vue`, `svelte`, `@angular/core`, `next`, `nuxt`, `react-native`, `vite`, `@inertiajs/*`, `@react-three/fiber`, `tailwindcss`, `three`; or a `components.json` at the scan root. Bare package.json never earns it: a Go repo with prettier must not install web-dev | `react`, `vue`, `next`, `nuxt`, `react-native`, `vite`, `node`, `inertia` <!-- removed-ok --> |
| Payments domain | `payments` | the `references/signals.md` payments row fires (`STRIPE_`/`PADDLE_`/`BRAINTREE_` env key, or dep `stripe`, `@stripe/stripe-js`, `braintree`, `@paddle/*`, or composer `stripe/stripe-php`, `laravel/cashier`) | `stripe`, `paddle`, `braintree`, `payments` |
| LLM domain | `llm-app` | the `references/signals.md` LLM row fires (env `ANTHROPIC_API_KEY`/`OPENAI_API_KEY`, or dep `langchain*`, `llamaindex`, `@anthropic-ai/*`) | `llm`, `anthropic`, `openai` |

## Everything else

Every leaf not named above is **any stack** and is always in the plan — 29 of the
35 eligible leaves (36 minus `plugin-scout`) at the time of writing; recount from
`references/catalog.md`, never from this number. That includes `ui-ux`: its a11y-audit, design-tokens and
theming-system skills are stack-agnostic, so a server-rendered app with no
JavaScript framework still gets it. The eight `*-suite` bundles and `plugin-scout`
itself are excluded by construction and never listed one by one. Already-installed
leaves are skipped and counted in the plan's `Already installed (K)` line.

## The domain-bound rule

A leaf is **domain-bound** when its usefulness depends on a domain no manifest can
rule OUT — payments and LLM work exist in a repo before any SDK or key lands in it.
Exactly two leaves qualify: `payments` and `llm-app`. They install under `--full`
only when their signals.md row fires or a `--stack` token in their class is typed.

Every signal-earned leaf NOT named in the table above — devops, api-design,
security, resilience, database, claude-authoring, vercel-skills-scout, and
stack-scan — installs under `--full` whether or not its signal fired. That list is
illustrative of "any stack", not a fifth class: a missing CI file does not make CI
discipline irrelevant, it makes it absent. `stack-scan` is the honest edge:
`references/any-core.md` keeps it OUT of the stack-agnostic core because its rubric
is Composer/npm-specific, and `--full` installs it anyway for the same reason it
installs candor and lean — the user asked for everything.

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
  `references/signals.md` routes them to `vercel-skills-scout`.
- Form, casing and the abort on an unknown token: `references/flags.md` `--stack`.

## Worked examples

**Laravel + Inertia + React** — composer.json requires `laravel/framework`,
package.json declares `@inertiajs/react` and `vite`, no Stripe or LLM signal:

- Excluded: `payments` — Payments domain signal absent; `--stack stripe` includes.
  `llm-app` — LLM domain signal absent; `--stack llm` includes.
- Excluded by construction: the eight bundles, `plugin-scout`.
- **No stack-mismatched leaf.** Both stack classes are satisfied, so 33 of the 35
  eligible leaves install.
- `web-dev` brings the Next.js and React Native skill descriptions into the
  model's skill listing regardless — no level of this marketplace skips them for a
  React app, and the plan should not read as if it did.

**Next.js app** — package.json declares `next`, no composer.json:

- Excluded: `laravel` — PHP / Laravel evidence absent (no `laravel/framework`, no
  `@inertiajs/*`); `--stack laravel` includes. Plus the two domain leaves when
  unsignalled.

## Standing

**Agent-graded.** No script checks that the exclusion was applied, that the
evidence keys were matched exactly rather than by substring, that a domain leaf
was held back, or that the typed-token line printed. Gated: plugin names in the
table above (`pc_scout_names`, which reads this file by name) and catalog
freshness (`generate.sh --check`). Residual worth naming: a wrong evidence key in
this table silently installs or skips a plugin on every `--full` run — only a human
reading the plan block before the confirm catches it, which is why `--full` prints
every exclusion with its reason.
