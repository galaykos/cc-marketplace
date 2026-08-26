# Per-leaf context cost — measured 2026-08-25

Generated from `scripts/context-budget-baseline.json` and
`scripts/context-budget-dynamic-baseline.json`. **Recount rather than copy** —
both files move whenever a description changes:

```bash
bash scripts/context-budget.sh
```

`always-on` is the bytes/4 estimate every session pays for having the plugin
installed. The host's own meter (`claude plugin details`) reads about **1.54x**
higher, because it charges a per-component floor. `dynamic` is stdout injected
per work-shaped prompt and per tool call — it is NOT paid unless the hook fires,
and it is the column the always-on figure most understates.

Total across 61 leaves: **12468 tokens** always-on.

| plugin | always-on | dynamic | in bundles (excl. everything) |
|---|---:|---:|---:|
| `craft-layer` | 1025 | — | 1 |
| `terse` | 889 | — | 0 |
| `taskmaster` | 875 | 50 | 1 |
| `ui-ux` | 586 | — | 3 |
| `code-architecture` | 501 | — | 2 |
| `approaches` | 500 | — | 3 |
| `registry-source` | 475 | — | 1 |
| `claude-authoring` | 425 | — | 1 |
| `task-runner` | 379 | — | 2 |
| `system-design` | 311 | — | 1 |
| `security` | 299 | — | 2 |
| `resilience` | 297 | — | 2 |
| `orchestration` | 251 | — | 2 |
| `ultra-deep-research` | 223 | — | 0 |
| `code-review` | 220 | — | 2 |
| `testing` | 211 | — | 2 |
| `dev-env` | 187 | — | 1 |
| `react` | 186 | — | 1 |
| `git-workflow` | 185 | — | 2 |
| `devops` | 176 | — | 1 |
| `api-design` | 173 | — | 1 |
| `api-docs-first` | 163 | 52 | 2 |
| `observability` | 160 | — | 2 |
| `a11y` | 153 | — | 4 |
| `shadcn-studio` | 152 | — | 1 |
| `command-guard` | 151 | — | 1 |
| `vercel-skills-scout` | 147 | — | 0 |
| `debugging` | 144 | — | 2 |
| `laravel` | 137 | — | 1 |
| `performance` | 131 | — | 2 |
| `fresh-take` | 125 | — | 0 |
| `sql` | 125 | — | 2 |
| `packages` | 124 | — | 2 |
| `plugin-scout` | 123 | — | 2 |
| `hindsight` | 121 | — | 2 |
| `web-dev` | 115 | — | 3 |
| `comment-discipline` | 111 | — | 1 |
| `design-preview` | 111 | — | 1 |
| `candor` | 107 | — | 1 |
| `node-backend` | 99 | — | 0 |
| `vite` | 99 | — | 2 |
| `postgresql` | 96 | — | 1 |
| `payments` | 95 | — | 1 |
| `i18n` | 92 | — | 1 |
| `llm-app` | 90 | — | 1 |
| `nuxt` | 90 | — | 1 |
| `brain` | 89 | — | 1 |
| `stack-scan` | 85 | — | 2 |
| `mysql` | 83 | — | 1 |
| `php` | 83 | — | 1 |
| `secret-scanning` | 81 | — | 1 |
| `mariadb` | 80 | — | 1 |
| `threejs` | 78 | — | 1 |
| `nextjs` | 77 | — | 1 |
| `inertia` | 76 | — | 2 |
| `lean` | 73 | 85 | 3 |
| `livewire` | 60 | — | 2 |
| `react-native` | 58 | — | 1 |
| `database` | 56 | — | 2 |
| `vue3` | 54 | — | 1 |
| `skill-router` | 0 | 2349 | 4 |

## What the distribution says

- **The top 10 leaves are 48% of the always-on bill** (5966 of 12468).
  Any material reduction comes from here or nowhere.
- **The bottom 30 are 21%** (2631 tokens). Cutting all thirty removes
  roughly half the marketplace's surface area to save ~2k tokens. That is the
  trade to reject first, and the reason "too many plugins" and "too expensive" are
  different problems.
- **`skill-router` is 0 always-on and 2349 dynamic.** The always-on column
  understates it more than any other row; a per-session cost does not appear here at all.

## What this table does NOT answer

Cost, not value. Nothing here says whether a leaf earns its tokens — that needs a
control/treatment run per skill, and the eval surface is `recorded`, not verified:
4 of 71 plugins ship an eval, none defines a control arm, and `claude plugin eval`
is early-access gated. The one real datapoint is
`rationale/eval-ablation-2026-08-20.md`, where `php-best-practices` scored **zero
delta in every arm** — one skill, one task shape, not the cluster.

Two cut strategies already measured and refuted, in
`rationale/distillation-2026-08-23.md`:

- **Trimming descriptions.** Cost is artifact-COUNT-driven; capping every description
  at 300 characters saves ~2.8%.
- **Consolidating bundles.** `process-suite` and `quality-principles-suite` are strict
  subsets of `taskmaster-suite`, and both keep — but NOT on cost grounds. The
  "+5,411 tok" framing this file first carried was withdrawn by its own source
  (`distillation-2026-08-23.md`, the `consolidate the 10 bundles` row): it prices a
  migration nobody is forced to make, and a bundle row is roughly the sum of its
  members, so installing those leaves directly costs the same. The real reason is
  **availability** — a suite's uninstall command must exist iff that suite is
  installed.
