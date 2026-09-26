# Official complements — what to install from `claude-plugins-official`

> Last verified: 2026-09-02 — https://github.com/anthropics/claude-plugins-official

This marketplace does not cover everything a development session needs, and
several of the gaps are already filled by Anthropic's own directory,
`anthropics/claude-plugins-official`. The scout says so and points there instead
of reimplementing a prose copy: a plugin earns existence by carrying a mechanism
nothing else carries, and every row below is one this marketplace does not ship.
Full gap review with the per-plugin verdicts:
`rationale/official-plugins-gap-review-2026-09-02.md` (marketplace repo only).

Filter applied: **vendor-agnostic**. A row must be usable without an account at
a specific SaaS vendor. Language servers, open-source MCP servers, and
Claude-Code-native mechanisms pass; hosted integrations (Datadog, Linear,
Stripe, cloud providers, ...) are out of scope here and left to the official
directory's own catalog. One hosted row is kept and flagged as such because
nothing local replaces it (`context7`).

## How the scout uses this file

- Print the block **after** tier 3, titled `Beyond this marketplace`, once per
  run. A row prints when its Signal column fires (same evidence rule as tier 1:
  the file plus the key) or when the Signal is `core`.
- Installs are **printed, never run** — this scout installs
  `cc-plugins-marketplace` plugins only, and `--yes` never touches this block.
  The form is `claude plugin install <name>@claude-plugins-official`, the
  directory Claude Code registers by default; if `claude plugin marketplace list`
  does not show it, print `claude plugin marketplace add anthropics/claude-plugins-official` first.
- Every row names its overlap with a plugin here. Print the overlap sentence
  next to the row so the user does not double-install two doctrines for one job.
- Already-installed rows carry `✓` like any other; detect them from the same
  installed set (they resolve as `<name>@claude-plugins-official`).

## Rows

| Official plugin | Signal | What it carries that nothing here does | Overlap here |
|---|---|---|---|
| `security-guidance` | core | Stop-hook LLM review of the accumulated diff and a commit-time cross-file reviewer on `git commit`/`git push`, both running in the background and re-waking the session with findings | `security`'s write-scan hook carries this plugin's edit-time pattern set already, so expect two warnings on the same line; what only this plugin has is the Stop-time and commit-time LLM review. `secret-scanning` blocks secrets pre-write, which this does not |
| `hookify` | core | Hooks authored as markdown rule files in `.claude/hookify.*.local.md` (regex or field conditions, warn or block, live-reloaded), plus a transcript analyzer that proposes rules from corrections you already made | none — nothing in this marketplace has a rule-file engine |
| `commit-commands` | core | `/commit` that stages and commits with git state preloaded into the prompt; `/clean_gone` deletes branches whose upstream is gone and removes their worktrees | `git-workflow:clean-gone` is the `/clean_gone` sweep with a confirm step. What only this plugin has is a `/commit` that runs the commit. `/commit-push-pr` needs `gh` |
| `claude-code-setup` | core | Read-only repo scan that recommends hooks, MCP servers, subagents and skills with install snippets | this scout recommends marketplace plugins only; nothing here proposes hooks or MCP servers from a scan |
| `claude-md-management` | a `CLAUDE.md` exists | Scores every CLAUDE.md against a six-criterion rubric before proposing diffs; a `/revise-claude-md` that mines the current session | `hindsight:claude-md` carries the six-criterion audit plus a stale-reference script; what only this plugin has is `/revise-claude-md` mining the CURRENT session. Skip unless you want that |
| `pr-review-toolkit` | core | `silent-failure-hunter` (swallowed errors, five fixed rules) and `type-design-analyzer` (1-10 ratings on encapsulation, invariants, usefulness, enforcement) | `silent-failure-hunter`'s fallback rules are folded into `resilience`'s error-handling-design, so only `type-design-analyzer` is unique; `code-reviewer` and `comment-analyzer` duplicate `code-review`; `code-simplifier` is the row below |
| `code-simplifier` | `package.json` or `tsconfig.json` | An agent that rewrites the code touched this session for clarity with behaviour held fixed | none as an agent; `code-architecture:low-cognitive-load` is doctrine only. Its baked-in style rules are JS/TS-shaped, which is why the signal is a JS manifest |
| `typescript-lsp` <!-- removed-ok --> | `tsconfig.json` or `package.json` dep `typescript` | Language-server code intelligence (definitions, references, diagnostics) via an `lspServers` entry; needs `npm i -g typescript-language-server typescript` | none |
| `php-lsp` | `composer.json` | Same, via Intelephense; needs `npm i -g intelephense` | none |
| `pyright-lsp`, `gopls-lsp`, `rust-analyzer-lsp`, `jdtls-lsp`, `kotlin-lsp`, `ruby-lsp`, `swift-lsp`, `clangd-lsp`, `csharp-lsp`, `lua-lsp` | `pyproject.toml` / `go.mod` / `Cargo.toml` / `build.gradle*` or `pom.xml` / `*.kt` / `Gemfile` / `Package.swift` / `CMakeLists.txt` / `*.csproj` / `*.lua` | The same mechanism for a stack this marketplace does not cover; print only the one the manifest earned | none — pairs with the `stack-scan` row in `signals.md` |
| `playwright` | dep `@playwright/test` or `playwright`, or `playwright.config.*` | Microsoft's open-source browser MCP: navigate, click, fill, screenshot, so e2e and visual checks run from the session | `testing` carries Playwright doctrine only; the real-component rung of `taskmaster:visual-decisions` stands variants up and defers screenshots to the host browser |
| `serena` | more than ~500 source files, or an LSP row above fired | Open-source LSP-backed MCP for symbol-level navigation and refactoring; needs `uvx` | `brain` is a committed markdown map built by grep, complementary rather than duplicate |
| `context7` (hosted, Upstash) | any `package.json` or `composer.json` | Version-pinned library docs over a remote MCP; the only row here that calls a third-party service, kept because nothing local supplies live docs | `api-design:api-docs-first` mandates verifying docs against the locked version but ships no source; this is the source it asks for |
| `ralph-loop` | opt-in, never by signal | A Stop-hook loop that re-feeds one prompt until a literal completion promise appears, with a max-iteration cap | `task-runner` bounds its inner loop by design; installing both is a doctrine conflict the user must choose deliberately |
| `claude-security` | opt-in, never by signal | Deep scan where every candidate finding must survive independent verifiers, with SARIF output and patches generated in a scratch clone | `security:review` self-refutes only `critical` findings and reports inline; this is the heavier pass for a release or audit |
| `mcp-server-dev`, `agent-sdk-dev` | dep `@modelcontextprotocol/sdk` / dep `@anthropic-ai/claude-agent-sdk` or `claude-agent-sdk` | Build guidance for MCP servers (transport choice, auth, MCPB) and a scaffolder plus verifier agents for Agent SDK apps | none — nothing here covers the SDK surface |
| `session-report` | opt-in, never by signal | An HTML report of token, cache and subagent spend from local transcripts | none user-facing; the marketplace's `scripts/turn-cost.sh` is a maintainer instrument |

## Framework-native tooling

> Last verified: 2026-09-26 — https://laravel.com/docs/13.x/boost

Some framework vendors now ship their own version-matched agent layer. It is not a
`claude-plugins-official` plugin, and the vendor-agnostic filter above does not apply: the
vendor is the framework the repo already depends on. A row prints in the same `Beyond this
marketplace` block under the same evidence rule, with its overlap sentence. Every command
is **printed, never run**: the Boost row runs a package manager, which Detection forbids.
The two hosted rows are flagged, as `context7` is.

| Tooling | Signal | What it carries that nothing here does | Overlap here |
|---|---|---|---|
| Laravel Boost: `composer require laravel/boost --dev`, then `php artisan boost:install` | composer require `laravel/framework` | Version-matched guidelines (Laravel 10–13, Livewire 2–4, Inertia 1–3, Tailwind 3–4) and on-demand skills picked from `composer.json`: `livewire-development`, `fluxui-development`, `inertia-{react,vue,svelte}-development`, and Filament's own `filament-development` when `filament/filament` is present. An MCP server (`php artisan boost:mcp`): app info, schema, logs, and a docs search that also covers Filament 2–5 | `inertia-*-development` co-fires with `laravel:inertia-best-practices`, `tailwindcss-development` with `ui-ux:tailwind-best-practices`, `pest-testing` with `testing:testing-best-practices`; expect two doctrines on those files. Boost writes `CLAUDE.md`/`AGENTS.md` guideline files loaded every session, an always-on cost this marketplace's budget gate does not meter |
| Next.js bundled docs, `node_modules/next/dist/docs/` | dep `next` | Docs matching the installed version, read locally. On ≥16.3 `next dev` writes the `nextjs-agent-rules` block into `AGENTS.md` and `CLAUDE.md` when it detects an agent (`grep nextjs-agent-rules AGENTS.md` hits → `✓`); on 16.2 add that `AGENTS.md` line by hand; on ≤16.1 `npx @next/codemod@canary agents-md` downloads a copy | `web-dev:nextjs-best-practices` keeps house judgment and the inversions; the bundled docs are the version truth, so read them first on ≥16.2 |
| Astro Docs MCP (hosted, kapa.ai index): `claude mcp add --transport http astro-docs https://mcp.docs.astro.build/mcp` | dep `astro` | Current Astro docs over a remote MCP | none, no plugin here covers Astro |
| Nuxt MCP (hosted): `claude mcp add --transport http nuxt https://nuxt.com/mcp` | dep `nuxt` | Nuxt docs over a remote MCP | none, the Nuxt one here was removed 2026-08-26 |

Livewire, Flux and Filament have no row of their own: Boost is their vendor layer, and
`references/signals.md` routes their keys here. React Router framework mode and the
headless CMS SDKs have no vendor row verified; `signals.md` routes them to
`api-design:api-docs-first`.

## Deliberate exclusions — official plugins that overlap what is installed here

Print these only when the user asks what else the official directory has; never
as a suggestion, because installing both loads two doctrines for one job.

- `feature-dev` — one command over explore, design, implement, review with
  parallel explorer and architect agents. Same arc as `taskmaster` + `task-runner`
  + `code-architecture`; choose one pipeline.
- `frontend-design` — a 71-line anti-generic-aesthetic prompt. `craft-layer`
  carries the same intent with ordered decision procedures; two design doctrines
  in one session contradict each other on layout defaults.
- `code-review` (official directory plugin) — GitHub-only: reviews a PR through
  `gh` with five parallel lenses and 0-100 confidence scoring. `code-review:review`
  here reviews the local diff and fans in every installed per-stack review. Both
  can coexist; `/code-review` vs `/code-review:review` collide at the slash-command
  surface.
- `code-review` (host built-in skill, Claude Code 2.1.259) — nothing to install:
  reviews the current diff, or a PR number, branch, or path target, at a chosen
  effort level, with `--fix` and `--comment` modes and an `ultra` cloud tier. It
  performs the generic pass only; the per-stack fan-in stays with
  `code-review:review`, which delegates its generic pass to this built-in when
  the session has it and runs it inline otherwise.
- `plugin-dev` — seven authoring skills plus a validator agent. This marketplace
  keeps its authoring doctrine as project skills of its own repository, not as a
  plugin, so `plugin-dev` is the one to install for plugin authoring elsewhere.
- `skill-creator` — Claude Code now ships this as a built-in skill; nothing to install.
- `playground` — single-file HTML control panels; the real-component rung of `taskmaster:visual-decisions` and
  `taskmaster:visual-decisions` render against the project's own components.
- `explanatory-output-style`, `learning-output-style` — SessionStart persona
  injections; orthogonal to candor's terse reply mode, not a gap, and each costs tokens every turn.
- `code-modernization` — a full legacy-migration pipeline; nothing here competes,
  but it is a project shape, not a development floor, so it is a search away
  rather than a row.

## Standing

**Recorded, curated by hand.** No script verifies that a name in the Rows table
still exists in the official marketplace, that its mechanism is still what the
third column says, or that the Signal fired. `pc_scout_names` deliberately does
not read this file: it checks names against THIS marketplace, and every name here
is foreign to it by construction. Recount rather than trust the row count, and
re-verify names against the live directory when this file is touched:

```bash
curl -s https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json \
  | python3 -c "import json,sys;print('\n'.join(sorted(p['name'] for p in json.load(sys.stdin)['plugins'])))"
```

Verified against that file on 2026-09-02; the host built-in `code-review` entry was
verified against the Claude Code 2.1.259 skill listing on 2026-09-03, not the directory.
The Framework-native rows were verified on 2026-09-26 against the vendors' own pages,
which no script re-reads: laravel.com/docs/13.x/boost, filamentphp.com/docs/5.x/introduction/ai,
nextjs.org/docs/app/guides/ai-agents, docs.astro.build/en/guides/build-with-ai,
nuxt.com/docs/4.x/guide/ai/mcp.
