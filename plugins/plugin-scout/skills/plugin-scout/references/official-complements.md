# Official complements — what to install from `claude-plugins-official`

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
| `security-guidance` | core | Stop-hook LLM review of the accumulated diff and a commit-time cross-file reviewer on `git commit`/`git push`, both running in the background and re-waking the session with findings | `security` 0.7.0's write-scan hook carries this plugin's edit-time pattern set already, so expect two warnings on the same line; what only this plugin has is the Stop-time and commit-time LLM review. `secret-scanning` blocks secrets pre-write, which this does not |
| `hookify` | core | Hooks authored as markdown rule files in `.claude/hookify.*.local.md` (regex or field conditions, warn or block, live-reloaded), plus a transcript analyzer that proposes rules from corrections you already made | none — `claude-authoring:new-hook` scaffolds a script per hook; it has no rule-file engine |
| `commit-commands` | core | `/commit` that stages and commits with git state preloaded into the prompt; `/clean_gone` deletes branches whose upstream is gone and removes their worktrees | `terse:commit` 0.5.0 preloads the same git context but only drafts the message; `git-workflow:clean-gone` 0.5.0 is the `/clean_gone` sweep with a confirm step. What only this plugin has is a `/commit` that runs the commit. `/commit-push-pr` needs `gh` |
| `claude-code-setup` | core | Read-only repo scan that recommends hooks, MCP servers, subagents and skills with install snippets | this scout recommends marketplace plugins only; `claude-authoring`'s routine-detector proposes skills from repetition, not from a scan |
| `claude-md-management` | a `CLAUDE.md` exists | Scores every CLAUDE.md against a six-criterion rubric before proposing diffs; a `/revise-claude-md` that mines the current session | `hindsight:claude-md` 0.7.0 carries the six-criterion audit plus a stale-reference script; what only this plugin has is `/revise-claude-md` mining the CURRENT session. Skip unless you want that |
| `pr-review-toolkit` | core | `silent-failure-hunter` (swallowed errors, five fixed rules) and `type-design-analyzer` (1-10 ratings on encapsulation, invariants, usefulness, enforcement) | `silent-failure-hunter`'s fallback rules are folded into `resilience` 0.4.0's error-handling-design, so only `type-design-analyzer` is unique now; `code-reviewer` and `comment-analyzer` duplicate `code-review`; `code-simplifier` is the row below |
| `code-simplifier` | `package.json` or `tsconfig.json` | An agent that rewrites the code touched this session for clarity with behaviour held fixed | none as an agent; `code-architecture:low-cognitive-load` is doctrine only. Its baked-in style rules are JS/TS-shaped, which is why the signal is a JS manifest |
| `typescript-lsp` <!-- removed-ok --> | `tsconfig.json` or `package.json` dep `typescript` | Language-server code intelligence (definitions, references, diagnostics) via an `lspServers` entry; needs `npm i -g typescript-language-server typescript` | none |
| `php-lsp` | `composer.json` | Same, via Intelephense; needs `npm i -g intelephense` | none |
| `pyright-lsp`, `gopls-lsp`, `rust-analyzer-lsp`, `jdtls-lsp`, `kotlin-lsp`, `ruby-lsp`, `swift-lsp`, `clangd-lsp`, `csharp-lsp`, `lua-lsp` | `pyproject.toml` / `go.mod` / `Cargo.toml` / `build.gradle*` or `pom.xml` / `*.kt` / `Gemfile` / `Package.swift` / `CMakeLists.txt` / `*.csproj` / `*.lua` | The same mechanism for a stack this marketplace does not cover; print only the one the manifest earned | none — pairs with the `stack-scan` row in `signals.md` |
| `playwright` | dep `@playwright/test` or `playwright`, or `playwright.config.*` | Microsoft's open-source browser MCP: navigate, click, fill, screenshot, so e2e and visual checks run from the session | `testing` carries Playwright doctrine only; `design-lab` defers screenshots to the host browser |
| `serena` | more than ~500 source files, or an LSP row above fired | Open-source LSP-backed MCP for symbol-level navigation and refactoring; needs `uvx` | `brain` is a committed markdown map built by grep, complementary rather than duplicate |
| `context7` (hosted, Upstash) | any `package.json` or `composer.json` | Version-pinned library docs over a remote MCP; the only row here that calls a third-party service, kept because nothing local supplies live docs | `api-design:api-docs-first` mandates verifying docs against the locked version but ships no source; this is the source it asks for |
| `ralph-loop` | opt-in, never by signal | A Stop-hook loop that re-feeds one prompt until a literal completion promise appears, with a max-iteration cap | `task-runner` bounds its inner loop by design; installing both is a doctrine conflict the user must choose deliberately |
| `claude-security` | opt-in, never by signal | Deep scan where every candidate finding must survive independent verifiers, with SARIF output and patches generated in a scratch clone | `security:review` self-refutes only `critical` findings and reports inline; this is the heavier pass for a release or audit |
| `mcp-server-dev`, `agent-sdk-dev` | dep `@modelcontextprotocol/sdk` / dep `@anthropic-ai/claude-agent-sdk` or `claude-agent-sdk` | Build guidance for MCP servers (transport choice, auth, MCPB) and a scaffolder plus verifier agents for Agent SDK apps | none — `llm-app` is provider-agnostic application discipline, not the SDK surface |
| `session-report` | opt-in, never by signal | An HTML report of token, cache and subagent spend from local transcripts | none user-facing; the marketplace's `scripts/turn-cost.sh` is a maintainer instrument |

## Deliberate exclusions — official plugins that overlap what is installed here

Print these only when the user asks what else the official directory has; never
as a suggestion, because installing both loads two doctrines for one job.

- `feature-dev` — one command over explore, design, implement, review with
  parallel explorer and architect agents. Same arc as `taskmaster` + `task-runner`
  + `code-architecture`; choose one pipeline.
- `frontend-design` — a 71-line anti-generic-aesthetic prompt. `craft-layer`
  carries the same intent with ordered decision procedures; two design doctrines
  in one session contradict each other on layout defaults.
- `code-review` (official) — GitHub-only: reviews a PR through `gh` with five
  parallel lenses and 0-100 confidence scoring. `code-review` here reviews the
  local diff. Both can coexist, but the names collide in the skill listing.
- `plugin-dev` — seven authoring skills plus a validator agent; `claude-authoring`
  covers the same surface. Pick one.
- `skill-creator` — Claude Code now ships this as a built-in skill; nothing to install.
- `playground` — single-file HTML control panels; `design-lab:preview` and
  `taskmaster:visual-decisions` render against the project's own components.
- `explanatory-output-style`, `learning-output-style` — SessionStart persona
  injections; orthogonal to `terse`, not a gap, and each costs tokens every turn.
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

Verified against that file on 2026-09-02.
