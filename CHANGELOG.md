# Changelog

All notable changes to this marketplace are documented here. The version below
is the marketplace `metadata.version`; individual plugins carry their own
version in their `plugin.json`.

## [0.52.0] - 2026-07-20

### Removed

- **automations-suite** bundle: pure meta-bundle deleted; its six member plugins
  (playwright, puppeteer, adspower, kameleo, camoufox, automation-builder) stay
  standalone and install individually. 7 bundles remain.
- Four single-skill plugins folded into thematic hosts (77 → 73 leaves):
  **data-privacy** → security, **api-auth** → security, **graphql-grpc** →
  api-design, **event-driven** → system-design. Skills keep their names under
  the host (`security:data-privacy`, `security:api-auth`,
  `api-design:graphql-grpc`, `system-design:event-driven`); each host's review
  command now applies the merged skill as a lens.
- **decision-records** removed (73 → 72 leaves): write-only in practice — zero
  ADRs recorded since the 0.45.0 retarget and twelve offers skipped in the
  wave2 run. ADR capture survives as plain-file offers (project ADR dir,
  docs/adr/ by convention) in taskmaster, approaches, build-vs-buy, rollout,
  and docs-upkeep; process-suite is now 13 plugins.

### Changed

- Always-on description surface cut ~12.7% (14,548 → ~12,700 est tokens):
  trimmed the ten heaviest plugins' description sets and brought all ten
  >500-char descriptions under the cap; enumerations/procedures live in skill
  bodies, trigger sentences stay.
- Five co-fire trigger overlaps split token-neutrally: reviewer trio
  (code-reviewer / frontend-reviewer / ui-ux-reviewer), approaches ↔
  code-architecture planning sequence, hindsight ↔ retrospective, concurrency ↔
  payments/event-driven idempotency, performance ↔ database ↔ sql slow-query
  lenses.
- **task-runner** 0.16.1 speed levers: mechanical BATCH/S-card dispatches carry
  an explicit down-tier override (model/effort) in the dispatch call; read-only
  reviewers run concurrently in the baseline pass (was `--crew`-only); reviewer
  dispatches demand compressed returns (one line per finding, capped);
  code-redteam milestone boundaries attack only the new milestone's diff.
- **taskmaster** 0.29.2: coverage-check dispatches its matrix build to a
  read-only subagent (fresh eyes, smaller main context); inline fallback kept.

### Added

- **brain** 0.2.2 produce→consume→refresh loop: taskmaster's context-scout and
  orchestration's delegation-contracts now use a committed `brain/INDEX.md` as
  an orientation prior (verify-then-trust-code, never a stale map over greps);
  git-workflow branch-finish offers `/brain index` when the map's `built:`
  stamp is behind the merged result; the session-start "no map yet" hint is
  size-gated to repos with ≥200 tracked files.
- **threejs** 0.1.x (new plugin, 72 → 73 leaves; added to frontend-suite):
  WebGPURenderer-first Three.js practices (WebGL2 fallback, TSL shaders),
  react-three-fiber/drei, glTF/Draco/KTX2 asset pipelines, disposal/GPU-leak
  discipline, draw-call performance; `/threejs:review`.
- **ui-ux** 0.7.10: 2026-currency pass over the stack skills — shadcn
  (Base UI default base since Jul 2026, Radix/React Aria selectable; oklch +
  `@theme` example), Tailwind (v4 CSS-first `@theme` as the primary pattern,
  `@custom-variant` dark mode), ReUI (Base UI-first foundations, paid-tier
  block warning), Motion (`animateView`, `motion-v` Vue, `spring()`→CSS
  export), Bootstrap (5.3 CSS-var runtime theming + v6 `@use` note),
  design-tokens v4 wiring — plus a GSAP depth reference
  (motion-best-practices/references/gsap.md: timelines, ScrollTrigger,
  SplitText 3.15).
- **ui-ux** 0.7.9: astryx-best-practices skill — Astryx, Meta's open-source
  agent-ready React design system (@astryxdesign/core, StyleX, 150+
  components, ten themes, JSON component manifest + MCP server). Beta-aware,
  docs-first navigator style.
- `scripts/remove-plugin.sh` — dry-run-by-default helper that removes or merges
  a plugin and updates every shared touchpoint (marketplace.json, everything
  deps, catalog regen, baseline, README counts) with a residual-reference
  report.
- Blocking per-leaf context-budget gate: `scripts/context-budget.sh` measures
  all 72 leaves + 7 bundles, prints a TOTAL line, exits 1 on growth over the
  committed baseline; enforced as a dedicated CI step.
- Description linter in `scripts/validate.sh`: fails any description over 500
  chars or carrying a literal "Trigger words:" list.

## [0.51.0] - 2026-07-17

### Added

- **playwright** 0.2.0: live-MCP-session auth guidance — new `## Auth in live
  MCP sessions` section in playwright-patterns (pre-authenticated storage state
  by default: `codegen --save-storage` / `storageState({path})` capture, loaded
  via `--storage-state`+`--isolated` or `--user-data-dir`; user-in-the-loop
  login as fallback; the state file is never read into the model's context),
  an MCP row in the playwright-docs link map, MCP trigger phrasing in the
  patterns description, and a README "Authenticated sessions" note.

## [0.50.0] - 2026-07-15

### Added

- **skill-router** 0.2.0: optional `stack_marker` 6th column in `rules.tsv` —
  `<manifest>~<ERE>` (`!` negates, `-`/empty none) sniffed from the session cwd so
  stack-exclusive pairs stop co-firing on one edit: vue2/vue3 on `*.vue`,
  php/laravel on `*.php`, react/react-native on `*.tsx`/`*.jsx`, livewire gated to
  `composer.json` containing `livewire/livewire`. Fail-open preserved: absent or
  unreadable manifest, malformed marker, or a bad regex (grep exit ≥ 2) fires the
  rule; reads are regular-file-only and capped at 64 KiB. Complementary
  same-pattern pairs (a11y alongside react on `*.tsx`, livewire alongside laravel
  on `*.blade.php`) declared via pairwise `# co-fire-ok:` directives. New coverage
  rows: `next.config.*`→nextjs, `nuxt.config.*`→nuxt, `vite.config.*`→vite,
  `*.graphql`/`*.proto`→graphql-grpc, `**/workflows/**`→devops-practices.
- **Overlap gate**: `pc_rules_overlap` in `scripts/lib/plugin-checks.sh`, wired
  into `scripts/validate.sh` — two high-confidence glob rows sharing a pattern
  must be marker-discriminated or `# co-fire-ok:`-allowlisted; markers route.sh
  would ignore don't count as discriminators. Fixture
  `scripts/smoke/validate-fixtures/rules-collision.tsv` +
  `scripts/smoke/rules-overlap-tests.sh` prove the gate fails on an unresolved
  collision.
- **Marker fallback chains**: `||`-separated marker alternatives, tried in
  order — the first decisive alternative wins; absent/unreadable manifests and
  malformed alternatives are skipped, and no decisive alternative fires. The
  vue rows check the installed `node_modules/vue/package.json` version first
  (authoritative), then the declared `package.json` range, so
  `workspace:*`/`latest` and loose ranges (`>=2.0.0` installed as 3.x) resolve
  to the actually-installed major. CRLF-terminated rules.tsv rows are
  tolerated (trailing `\r` stripped from the last field) in both route.sh and
  the overlap gate.
- **Route-marker smoke tests**: `scripts/smoke/route-marker-tests.sh` (20
  asserts: match/suppress/absent-manifest/negation/malformed-regex/5-column
  compatibility/fail-open), both new suites added to CI in
  `.github/workflows/validate.yml`.

## [0.49.1] - 2026-07-14

### Changed

- Preview-server doc sweep: ui-ux 0.7.5 (shadcn-theming now documents the
  serve.py-first chain with localhost-bound static fallbacks) and
  design-preview 0.1.2 (port registry names serve.py as the preferred first
  rung). taskmaster 0.24.1 clarifies dated-ledger-file → `current.html` copy in
  shell-authoring. plugin-scout 0.2.1 aligns the report-exclusion wording with
  the tier-2 rule (all bundles, not just two). `context-budget.sh` WARNs now go
  to stderr and the single-line description assumption is documented.

## [0.49.0] - 2026-07-14

### Added

- **taskmaster 0.24.0 — live mockups**: the shared static preview gains a real
  push lane — new `visual-decisions/assets/serve.py` (stdlib, threaded static
  server + SSE `/events`, localhost-only by default with `--lan` opt-in) sits
  first in the launch chain; the shell auto-reloads over SSE and degrades to
  the existing polling on any plain static server. Shell v2: per-variant state
  toggles (`data-state="populated|empty|loading|error"`, only provided states
  shown, v1 mockups render unchanged), per-frame focus/zoom, side-by-side
  compare unchanged (max 3 variants).
- **Example machinery**: 5 curated starter patterns (landing, dashboard,
  crud-form, onboarding-flow, settings — multi-state, realistic data,
  token-driven) under `visual-decisions/references/starters/`; a
  `shell-authoring.md` reference (variant markup, state matrix, realistic-data
  discipline); accepted picks are saved to a per-repo gallery
  (`taskmaster-docs/mockups/gallery/` + INDEX.md). Brainstorm gains an opt-in,
  post-divergence offer of up to 2 matching starters/gallery entries as
  reference material (anti-anchoring contract preserved).
- Fallback server rungs now bind localhost explicitly (`--bind 127.0.0.1` /
  `php -S 127.0.0.1:`) in visual-decisions and erd docs.

## [0.48.0] - 2026-07-14

### Changed

- **taskmaster-suite 0.10.0**: drops `ui-ux` (38→37 dependencies, ~9.3k→~8.5k
  always-on tokens) per the 2026-07-14 suite cost review — the bundle is now
  genuinely stack-agnostic and its "No framework- or dialect-specific plugins"
  claim holds. UI-tagged task cards fall back to the generic executor; the
  ui-ux reviewer pass is skipped unless ui-ux is installed (it remains a leaf
  plugin and a member of `everything` and `frontend-suite`).
  **Migration note**: existing taskmaster-suite installs keep ui-ux on disk —
  removing it from the dependency list does not uninstall it, and a later
  `--prune` will not remove it either; uninstall manually if unwanted.
- frontend-suite 0.4.3: README catches up with membership — `nextjs`/`nuxt`
  in the opening line and bullet list, stale "Vue 2/3" wording removed.
- process-suite 0.2.2 / quality-suite 0.2.2: descriptions now name their
  member plugins `intent-guard` / `secret-scanning`.

### Added

- **plugin-scout 0.2.0**: five new tier-1 detection signals (`nextjs`, `nuxt`,
  `node-backend` via express/fastify/@nestjs/core, `vite`, `javascript`) —
  these stop being suggested as "universal" in every project. Two new flags on
  `/plugin-scout:suggest`: `--yes` auto-installs tier-1 signal-backed picks
  only (install picker skipped; marketplace-add trust prompt preserved;
  ambiguous signals install nothing; tier-2 never auto-installs; note:
  auto-installed plugins may ship hooks). `--persist` writes the set installed
  this run into the project's committed `.claude/settings.json`
  (`enabledPlugins` + `extraKnownMarketplaces`, jq-merged, create-if-missing,
  abort on invalid JSON) and prints a notice that committing it auto-installs
  for anyone who clones and accepts the trust prompt. Full semantics:
  `plugins/plugin-scout/skills/plugin-scout/references/flags.md`.
- **Report-only context-budget gate**: `scripts/context-budget.sh` prints each
  bundle's always-on description-token surface (chars/4) versus the committed
  `scripts/context-budget-baseline.json` at the end of every `validate.sh`
  run, WARNing on growth without ever failing the build
  (`--update-baseline` refreshes). Baseline seeded from this release's
  post-change state, so this wave's own growth is recorded here rather than
  as WARNs.

## [0.47.1] - 2026-07-14

### Changed

- Install guidance reworked from a suite cost review: root README bundle lane
  now leads with per-use-case category suites, adds a per-bundle always-on
  context cost table (chars/4 estimates), positions `everything` as a
  zero-setup convenience (~14k tokens of always-on context per session), adds
  the previously missing `automations-suite` to the bundle lists, and states
  the recommended default (process-suite globally, category suites
  per-project, `/plugin-scout:suggest` when unsure). taskmaster-suite's "no
  framework/dialect plugins" claim qualified (it bundles ui-ux's per-stack UI
  skills).
- `everything` 0.17.4: README plugin count fixed (74 → 77 with stale-resistant
  phrasing); themed list gains the missing `nextjs`, `nuxt`, `node-backend`.

## [0.47.0] - 2026-07-14

### Added

- New stack plugins: `nextjs` (App Router/RSC/caching, version-aware 14-16),
  `nuxt` (Nuxt 4.x idioms, Nitro, data fetching), `node-backend` (Express 5 /
  NestJS 11 / Fastify 5, one skill, worker override to web-dev). All three in
  `everything`; nextjs+nuxt join `frontend-suite`.
- `ui-ux` gains `motion-best-practices` (Motion, GSAP, CSS/scroll-driven
  animations, View Transitions, hard prefers-reduced-motion rule) wired into
  `/ui-ux:review` detection and both ui-ux agents.
- Worker-agent chassis: optional operatingProcedure/domainChecklist/deferRule
  slots; 8 hand-written engineer agents migrated onto the template (web-dev,
  laravel, database, security, testing, devops, performance, ui-ux) with
  domain content preserved; validate.sh now gates declared agentFile headers.
- Reviewer skill-wiring: frontend-reviewer and ui-ux-reviewer declare
  `bestpractices-skill` lists with the worker priming contract.

### Changed

- Content refresh across 16 stack skills verified against July-2026 stables:
  MySQL 9.7 LTS / 8.0 EOL, MariaDB 11.8 LTS / 12.x rolling, Laravel 13,
  Livewire 4, Inertia v3, React Compiler 1.0, RN New-Arch-only since 0.82,
  ES2025/ES2026 corrections, TS 5.9-7.0 timeline, Vite 8 Rolldown default,
  Node 22/24 baselines; vue2 EOL badge confirmed untouched.
- ui-ux-engineer viewport claim reworded to markup-level responsive checks
  (W2 finding 15).
- Marketplace descriptions refreshed in parity: laravel (10/11/12/13),
  livewire (3/4), inertia (v1/v2/v3), mysql (8.4 + 9.7 LTS).

## [0.46.0] - 2026-07-14

### Added

- README.md for all 31 plugins that shipped without one (a11y, api-docs-first,
  approaches, automations-suite, build-vs-buy, claude-authoring, code-review,
  concurrency, database, db-suite, decision-records, design-patterns, devops,
  docs-upkeep, error-handling, estimation, everything, frontend-suite,
  observability, orchestration, packages, performance, php-suite, process-suite,
  quality-suite, resilience, retrospective, rollout, system-design,
  taskmaster-suite, web-dev) — every command/skill/agent/hook claim grounded in
  the plugin's actual files; bundle READMEs list their dependencies and
  uninstall command.

### Changed

- validate.sh README-presence gate flipped from warn-only to hard-fail: a
  plugin without a README.md now fails CI.
- vue2 marked EOL in both description surfaces (legacy-maintenance only) and
  dropped from frontend-suite's bundle (vue3 stays; vue2 remains installable
  standalone). plugin-scout catalog regenerated.
- CHANGELOG 0.44.0 entry now credits the two plugins that landed in its window
  (reuse-guard, compaction-advisor); compaction-advisor reset.sh comment updated
  to the remind.sh name; visual-decisions SKILL compressed to 146/150 lines for
  headroom.

## [0.45.0] - 2026-07-14

Marketplace hardening wave 2. Description/dependency/version rot is now CI-impossible,
the opt-out review payload reaches 6 more reviews, the navigator family is stamped as
the 5th chassis, a machine-readable keywords taxonomy covers all 82 plugins, and the
preview surface is unified behind one wired port convention.

### Added

- **governance gates** (hard-fail unless noted): description-parity (every plugin's
  marketplace.json `.description` == its plugin.json), rules.tsv skill-token
  resolution, all-bundle dependency resolution across the 8 bundles, strict
  semver-increase on version bumps, CHANGELOG-parity (CHANGELOG top entry ==
  marketplace `metadata.version`), README-presence (warn-only), and a new
  `scripts/smoke/hook-syntax-tests.sh` (`bash -n` over `plugins/*/hooks/*.sh`,
  `scripts/*.sh`, `scripts/smoke/*.sh`, `scripts/lib/*.sh`). CHANGELOG 0.37.0–0.43.0
  skeletons backfilled; a manual `git tag v<version> && git push --tags` release step
  documented; `canary.sh`/`guard-tests.sh` disposition recorded.
- **navigator chassis** (5th chassis): `templates/navigator-check.md.tmpl` plus
  `docs-unreachable` and `proceed-closer` blocks, a `render_navigator()` arm in
  `scripts/generate.sh`, and a `navigator.json` smoke case. The 5 navigator plugins
  (adspower, camoufox, kameleo, playwright, puppeteer) now stamp `commands/check.md`
  from their `.chassis.json`; the header gate covers `commands/check.md` and the
  hand-authored check.md owners carry optout coverage.
- **keywords[] taxonomy**: a controlled vocab in `scripts/taxonomy.txt`, a validated
  `keywords` array on all 82 plugin.json (hard gate: present, non-empty, ⊆ vocab), and
  a generated plugin-scout catalog (`references/catalog.md`) replacing the
  hand-maintained universal-set enumeration.
- **shadcn-studio Node floor**: `engines: {"node": ">=20.19"}` in the template's
  `package.json` — the real Vite 8 floor, now mechanically verifiable.

### Changed

- **6 opt-out reviews** (code-review, performance, api-design, ui-ux, security,
  system-design) adopt the triage gate + coverage closer in each command's native
  vocab, with apply-lane options reworded per command; orchestration stays a permanent
  opt-out. Paired reviewer agents untouched.
- **preview unification**: every shared static-mockup server command is wired to
  `python3 -m http.server "${PREVIEW_PORT:-8123}" -d taskmaster-docs/mockups` with a
  normalized php/npx fallback chain; shadcn-studio's Vite port becomes
  `Number(process.env.PREVIEW_PORT) || 8124`; all four `:8123` mockup producers plus
  their consumers move to `taskmaster-docs/mockups/`; the design-preview README carries
  the full consumer registry. shadcn-studio's Node-floor prose corrected from 18 to
  20.19.
- **navigator regeneration** normalizes the docs-unreachable wording and proceed verb;
  the `anti-?detect` alternation is dropped from the 3 product navigators' reminder
  regexes (automation-builder keeps the generic term) and their `remind.sh` hooks are
  regenerated.
- **scope-lock** (`scope.sh`) now emits loud stderr warnings — still exit 0 — on
  missing `jq` and malformed `scope.json`; all other exit-0 paths stay silent.

### Fixed

- **skill-router phantom skill**: the non-existent `ui-ux-stack` target removed from
  rules.tsv / prime.sh / route.sh, locked by the resolution gate.
- **discovery & prose drift**: intent-guard and compaction-advisor marketplace
  descriptions reconciled to their plugin.json; laravel drops the stale "sql" claim
  from both surfaces; opinion-lens prose aligned to its sonnet pin; ui-ux-engineer's
  visual-verification claim reworded to code inspection.
- **ADR path retarget**: all eight `taskmaster-docs/adr` references across
  decision-records retargeted to `docs/adr`.
- **hooks & guards**: compaction-advisor `nudge.sh` renamed to `remind.sh` (bespoke
  turn-counter, optout-marked); reuse-guard `scan.sh` early-exits on files > 200 KB;
  the database guard gains lock-hazard detection for non-`CONCURRENTLY` index creation
  and rewrite-ALTERs.

## [0.44.0] - 2026-07-13

Fable review engine + deterministic chassis generators. Per-plugin `.chassis.json`
manifests + `templates/` + `scripts/generate.sh` stamp full standalone copies of the
templated review/uninstall/reminder cohort, and a CI regenerate-and-diff `--check` gate
makes chassis drift impossible — a hand-edit of any generated file now fails CI.

### Added

- **chassis system**: `scripts/generate.sh` (bash+jq template stamper) + `templates/`
  (review-command, suite-uninstall, reminder-hook, worker-agent) + per-plugin
  `.chassis.json` manifests. `--write` stamps and patch-bumps each changed plugin once;
  `--check` byte-diffs regenerated output against the tree and exits non-zero on any
  drift (content or hook mode bit), and validates that every stamped dispatch chain
  resolves to a real worker agent. Wired into CI as an **enforcing** gate (was
  report-only) alongside new `scripts/smoke/template-engine-tests.sh`,
  `chassis-template-tests.sh`, and `hook-guard-tests.sh`. `scripts/validate.sh` gains a
  generated-header gate: every chassis-shaped file (`commands/review.md`,
  `commands/uninstall.md`, `hooks/remind.sh`) must carry the stamp or declare an
  `optout` manifest entry.

- **reuse-guard plugin** (new, landed in the 0.44.0 window, `cdc371f`): warn-only
  two-tier reuse-hygiene guard — a PostToolUse hook flags edits that build on
  deprecated/dead symbols.
- **compaction-advisor plugin** (new, landed in the 0.44.0 window, `b82efeb`):
  advice-only /compact nudge — a UserPromptSubmit turn-counter prints one line
  every 50 turns; never runs /compact itself.

### Changed

- **30 stamped review commands** now carry the unified Fable payload — four blocks: a
  **triage** gate (trivial/single-file/mechanical → one-line verdict; risky → deep
  pass), **evidence tiers** (`CONFIRMED`/`PLAUSIBLE`, format `locator — severity —
  [tier] problem — fix`, severity-sorted), a **coverage closer** (`Checked: … / Not
  checked: … (why)`) with one adversarial **self-refute** pass per critical finding,
  and an **apply-lane** offering **Apply all / Apply critical+high only / Report only**
  that dispatches the finding list down a static stamped chain
  (`<worker> → task-runner:task-executor if installed → inline`). Headless runs report
  only and print the apply command. postgresql/sql/mysql/mariadb keep their
  engine-version preambles; sql keeps its engine-handoff extra apply option; dev-env
  keeps its audit-only safety option.
- **api-docs-first**: reminder regex narrowed to
  `\b(sdk|endpoint|integrat\w*|webhook|oauth|graphql)\b` — the bare `api` and `restful`
  triggers are dropped, eliminating false reminders on unrelated prompts.
- **approaches**, **build-vs-buy**: keyword-reminder hook renamed `nudge.sh` →
  `remind.sh` and normalized to the shared reminder-hook shape (shebang line 1,
  generated header line 2, slash+empty+jq fail-open guards, one keyword-matched
  message). compaction-advisor's turn-counter `nudge.sh` is a different shape and stays
  untouched.
- **11 reminder hooks** (adspower, api-docs-first, automation-builder, camoufox,
  kameleo, meta-api, playwright, puppeteer, taskmaster, approaches, build-vs-buy) are
  stamped from one template with messages normalized to the template shape; taskmaster
  keeps its thin-prompt guard via `extraGuard`.
- **8 suite uninstalls** stamped identical modulo the bundle parameter; the
  taskmaster-suite divergence is gone.
- **observability** (observability-engineer), **a11y** (a11y-engineer): the two worker
  agents are regenerated with skill-pointer bodies (the restated checklist replaced by
  a pointer to the best-practice skill) plus a three-strikes kill-trigger; exact
  name/filename/tools/model/bestpractices-skill preserved so the routing/crew sync gates
  stay green.
- **laravel** 0.3.2: backend-engineer's "route their fixes to" claim corrected — the
  php and laravel review commands route fixes to backend-engineer; sql routes to
  database-engineer.

## [0.43.0] - 2026-07-11

### Added

- **ultra-deep-research**: new deep-research harness plugin; **intent-guard**:
  mid-run intent-vs-action attestation plugin; Phase 6 enforcement hooks
  (secret-scanning, destructive-SQL guard, scope-lock, build-vs-buy); Phase 7
  domain plugins (event-driven, payments, api-auth, data-privacy) with a
  threat-modeling skill. (Backfilled skeleton — see git log around this bump.)

## [0.42.0] - 2026-07-09

### Changed

- Richer serves/trades/breaks option rationale in the visual-decisions passes
  (Piece 5/5). (Backfilled skeleton.)

## [0.41.0] - 2026-07-09

### Changed

- **taskmaster**: the durable visual contract is carried into the spec and cards
  (Piece 4/5). (Backfilled skeleton.)

## [0.40.0] - 2026-07-09

### Changed

- **shadcn-studio**: staging lanes, depth matrix, and dataviz (Piece 3/5).
  (Backfilled skeleton.)

## [0.39.0] - 2026-07-09

### Changed

- **taskmaster**: always-on staging area in brainstorm (Piece 2/5). (Backfilled
  skeleton.)

## [0.38.0] - 2026-07-09

### Added

- **shadcn-studio**: new greenfield interactive shadcn staging plugin
  (Piece 1/5). (Backfilled skeleton.)

## [0.37.0] - 2026-07-07

### Added

- **brain**: new codebase-map plugin (Phase 1a tracer). (Backfilled
  skeleton.)

## [0.36.0] - 2026-07-07

### Changed

- **taskmaster** 0.17.0: grill now enforces convergence instead of relying on the user to call "enough". It stops adding rounds at a soft cap (~4, scaled to blast radius) or the first round that closes no new UNKNOWN, then converts remaining UNKNOWN rows to ASSUMED with named defaults and routes them into the existing Stopping assumption-list gate (accept/veto) — the interactive analogue of the headless fallback. A runaway interrogation that keeps spawning UNKNOWNs now terminates on its own; the user still sees and can veto every parked assumption (Track E3)

## [0.35.0] - 2026-07-07

### Added

- **taskmaster** 0.16.0: new `spec-redteam` skill + `spec-adversary` agent + `/taskmaster:redteam` command — a blast-radius-gated adversarial review of a frozen spec, between spec-freeze and task-cards. When the spec warrants it (≥3 success criteria, crosses modules, touches a security/auth/data/external surface, or carries unconfirmed ASSUMED rows), a single **blind** `spec-adversary` agent (opus, read-only) is dispatched with only the spec path — never the grill conversation — and attacks it across four lenses: missing edge cases, unstated assumptions (verified against the codebase via grep), conflicting or underspecified requirements, and failure/security gaps. Each returned hole is resolved through a blocking gate (amend the spec / accept as a known risk / dismiss as a non-issue) before cards are cut; minor-only findings are waved through. Wired into grill's handoff and `task.md` before the plan-check. Closes the gap where nothing attacked the spec's own soundness — opinion-round argues the approach, coverage-check trusts the criteria, grill asks the user; the fresh-context adversary finds what neither the user nor the model thought to ask (Track D)

## [0.34.0] - 2026-07-07

### Changed

- **taskmaster** 0.15.0: grill now persists its ambiguity ledger to a gitignored `.claude/taskmaster/ledger-<slug>.md` after each round (a `Task:` header plus the table), and at grill start offers Resume / Start fresh when an unfinished ledger is found — so an interruption mid-interrogation (context loss, crash, session end) resumes from the ledger with the context-scout findings and every answered row intact, instead of re-scouting and re-asking from scratch. The working file is deleted when the spec is written. Closes the pipeline's only ephemeral pre-execution state — execution already resumes from `00-INDEX.md`, but grill's ledger previously lived only in the conversation (Track E1)

## [0.33.0] - 2026-07-07

### Added

- **taskmaster** 0.14.0: new `coverage-check` skill + `/taskmaster:coverage` command — a spec↔card traceability gate. At the tail of task-cards (after the index is written, before the execution handoff) it cross-checks the spec's `## Success criteria` against every card's `**Acceptance criteria:**` in both directions: a criterion no card satisfies is a GAP (dropped scope), a card that serves no criterion is an ORPHAN, a card asserting behavior in no criterion or decision is DRIFT (added scope). It blocks the handoff until each finding is resolved (add a card — deferred to task-cards — / fold / reclassify as non-goal / accept-with-reason for gaps; tie / add-criterion / drop for orphans) or explicitly accepted, and persists a `## Coverage` matrix into `00-INDEX.md`. Closes the pipeline's worst silent failure: a card set that quietly misses a requirement or drifts from the spec, shipped straight into execution. An independent verifier — it checks documents against documents, distinct from work-verification / task-runner which check delivered code

## [0.32.0] - 2026-07-07

### Added

- **claude-authoring** 0.3.0: new `project-skill-suggester` skill — proactive, task-content-driven suggestion of a repository-specific project skill or agent. At the task-cards stage it clusters the freshly split cards and, when three or more lean on the same not-yet-captured repo knowledge (a house convention, an internal API/helper, one subsystem's rules) that no existing skill covers, offers once to scaffold it — deferring the artifact-type choice to `routine-detector`'s shape table and the scaffolding to `/claude-authoring:new-skill`|`new-agent`, and honoring the same consent etiquette (explicit yes, one suggestion per run, a decline is final). Fills the whitespace the three post-hoc detectors leave: routine-detector needs three occurrences over time, hindsight needs two sessions, retrospective runs after a milestone — none inspect a single in-flight task

### Changed

- **taskmaster** 0.13.0: `task-cards` skill wires the new suggester in — after the index is written and before the task-runner handoff, it invokes `project-skill-suggester` on the finished card set when claude-authoring is installed (silent otherwise); mirrors the estimation/approaches/ADR installed-guarded handoff pattern

## [0.31.0] - 2026-07-07

### Added

- **skill-router** 0.1.0: new plugin — file-aware skill auto-routing. A `PostToolUse` hook (`Edit|Write|MultiEdit`) matches the edited file against a declarative `rules.tsv` and injects a directive to load the relevant best-practice skill: high-confidence path/extension signals (sql, ui-ux, a11y, testing, dev-env, packages) fire inline once per signal per session; low-confidence content signals (concurrency, error-handling, security, resilience) accumulate into a `SessionEnd` digest instead of interrupting. A `SessionStart` hook primes a repo-tailored skill index sniffed directly from manifests — stack-scan is a conversational skill with no hook-readable output, so the primer does its own detection. Fail-open throughout (any error or missing `jq` exits silently, never blocks an edit); rules filtered to installed plugins via a sibling-directory check; per-session dedup state at `.claude/skill-router/` (gitignored). Closes the gap where ~50 suite skills fired only when the model happened to notice their description trigger. Design + spec + task cards under `taskmaster-docs/` (Track A of a taskmaster-suite improvement brainstorm)

### Changed

- **taskmaster-suite** 0.8.0, **everything** 0.10.0: skill-router added to bundle dependencies

## [0.30.0] - 2026-07-06

### Changed

- **taskmaster-suite** 0.7.0: error-handling, concurrency, observability, and plugin-scout added to bundle dependencies — closing a drift gap. The suite bundles "every stack-agnostic capability" and already carried 10 of 13 quality-suite plugins; the first three (all 0.1.0, added after taskmaster-suite last bumped at 0.5.0) were backfilled into everything 0.7.0 and quality-suite but missed here — application-level and language-agnostic, matching the suite's stack-agnostic scope. plugin-scout (stack-agnostic marketplace scout, already in process-suite) joins alongside its sibling stack-scan
- **frontend-suite** 0.3.0: design-preview added to bundle dependencies — Vite+React real-component visual decisions, a frontend-category plugin previously reachable only via everything

### Fixed

- **laravel** 0.2.1, **javascript** 0.1.1, **vite** 0.1.1: skill bodies brought within the 100-150 line validator budget by unwrapping hard-wrapped prose to one line per paragraph (matching the php/js house style) — laravel 203→150 (also merged the redundant tail of Common mistakes), javascript and vite 151→150. No technical content removed; `scripts/validate.sh` now passes clean

## [0.29.0] - 2026-07-06

### Added

- **javascript** 0.1.0: new plugin — vanilla (non-TypeScript) JavaScript best practices: version-aware ES feature floors (ES2020–ES2024) resolved from engines/browserslist/lockfile, strict equality and coercion traps, ESM vs CommonJS interop, async correctness and the event loop, this-binding and closures/leaks, immutability, error handling, boundary validation, number precision/BigInt, prototype-pollution safety. Includes /javascript:review
- **vite** 0.1.0: new plugin — Vite best practices: VITE_-prefix env security (secrets never shipped to client bundles), dep pre-bundling, code splitting and manualChunks, base for sub-path deploys, dev server.proxy, define stringify pitfalls, import.meta.glob, asset handling, build.target alignment, SSR, library mode, plugin order, HMR guards; version-pinned to the locked vite version and vite.config. Includes /vite:review
- **README.md** for 11 stack plugins that lacked one (php, laravel, react, react-native, vue2, vue3, livewire, sql, mysql, mariadb, postgresql) — install / commands / example / pairs-well-with, mirroring the typescript/inertia template

### Changed

- **laravel** 0.2.0: skill gains a version-awareness pair of sections (know-the-version + a doc-verified per-version leverage map for Laravel 10/11/12) and a mass-assignment security section ($fillable vs $guarded, the $request->all() OWASP trap, casts()/API-Resource notes); two new Common-mistakes bullets; plugin.json and marketplace descriptions synced
- **frontend-suite** 0.2.0: javascript and vite added to bundle dependencies
- **php-suite** 0.2.0: vite added to bundle dependencies (Laravel's default asset bundler)
- **everything** 0.9.0: javascript and vite added to bundle dependencies

## [0.28.0] - 2026-07-06

### Added

- **automations-suite** 0.1.0: new plugin suite for browser automation and anti-detect browsing — five per-tool navigator plugins, a cross-tool planner, and a shared worker agent, bundled by the `automations-suite` meta-bundle
- **playwright** 0.1.0: new plugin — Playwright navigator: current API from live docs (playwright.dev), link map (locators, auto-wait, network interception, storageState auth, test runner, trace, connectOverCDP), robust-automation patterns, and driving an anti-detect browser over CDP. Includes /playwright:check
- **puppeteer** 0.1.0: new plugin — Puppeteer navigator: current API from live docs (pptr.dev), waits, request interception, puppeteer-extra stealth, and attaching to an anti-detect browser via browserWSEndpoint. Includes /puppeteer:check
- **adspower** 0.1.0: new plugin — AdsPower Local API navigator: profile lifecycle, start/stop browser, the CDP/WebSocket handoff to a driver, rate limits and status codes. Includes /adspower:check
- **kameleo** 0.1.0: new plugin — Kameleo Local API/SDK navigator: fingerprint → profile → start flow, connecting a driver over CDP, fingerprint configuration. Includes /kameleo:check
- **camoufox** 0.1.0: new plugin — Camoufox navigator: current Python usage (camoufox.com), launch options (humanize, geoip, os, proxy, config), and the Playwright-Firefox integration it exposes. Includes /camoufox:check
- **automation-builder** 0.1.0: new plugin — browser-automation planner and worker: a think-process skill (tool choice → sequenced plan) plus a browser-automation-engineer agent that scaffolds and runs automations. Includes /automation-builder:build

### Changed

- **everything** 0.8.0: playwright, puppeteer, adspower, kameleo, camoufox, automation-builder added to bundle dependencies (six new leaf plugins)

## [0.27.0] - 2026-07-06

### Added

- **taskmaster** 0.11.0: new `erd` skill — spec-time data-model diagrams (mermaid erDiagram in the spec's Data Model section, inline-SVG approval preview via the shared diagram.html slot); pointer hooks in grill, visual-decisions, and task-cards; Data Model section is a binding contract for implementation cards. README row synced

## [0.26.0] - 2026-07-06

### Changed

- **approaches** 0.2.0: new opinion-round skill — three parallel blind opinion-lens subagents (Standards Purist, Quality-over-Speed, Skeptic-Investigator) argue refactor-shaped tasks independently; inline synthesis converges to one pick + kill-trigger in a single round, auto-proceeding unless the split is structural; UserPromptSubmit nudge hook (fail-open, non-blocking) and /approaches:opinions manual command

## [0.25.0] - 2026-07-06

### Changed

- **taskmaster** 0.10.0: pipeline wires companions in — code-architecture plan check on the spec before card-splitting and a decision-records ADR offer, both installed-guarded (grill handoff mirrors the offer); task cards carry a "Skills to apply" field stamped from the stack-scan inventory and are sized via the estimation plugin when installed
- **task-runner** 0.5.0: conditional reviewer pass after each task's verify passes (code-reviewer always; ui-ux/architecture/security reviewers by task content) — blocker/major findings re-enter the bounded fix loop under the same 3-cycle cap; docs-upkeep drift check joins the completion gate
- validator: hard trigger-surface gates — skill descriptions must carry "Use when/before/after/during" phrasing, agent descriptions need PROACTIVELY or an explicit sub-dispatch marker ("Spawned by")

## [0.24.0] - 2026-07-05

### Added

- **observability** 0.1.0: new plugin — application observability with judgment: structured JSON logs with correlation IDs, log-level semantics, log hygiene (no secrets/PII, bounded payloads), RED/USE metrics without cardinality bombs, trace-context propagation, symptom-based alerting, liveness-vs-readiness health checks. Includes /observability:review
- **error-handling** 0.1.0: new plugin — language-agnostic error-handling discipline: fail fast on programmer errors, handle operational errors where you can act, no swallowed exceptions, wrap-and-rethrow with cause chains, typed errors over message-string matching, one report per failure, operator-grade messages, user-facing vs internal split. Includes /error-handling:review
- **concurrency** 0.1.0: new plugin — application-level concurrency safety: check-then-act races, optimistic vs pessimistic locking, idempotency keys for retried operations, queue-consumer dedup under at-least-once delivery, distributed locks with TTL + fencing, async parallel-write pitfalls, transaction limits. Includes /concurrency:review
- **frontend-suite**, **php-suite**, **db-suite**, **quality-suite**, **process-suite** 0.1.0: five category bundles — schema-native one-command install per README category, each with its own /`<bundle>`:uninstall prune command. A plugin may appear in several bundles; bundles never contain other bundles
- **code-architecture** 0.6.0: new solid-principles skill (SOLID applied with judgment — detection cue, fix, and when-NOT counterweight per principle) and /code-architecture:solid review command

### Changed

- **everything** 0.7.0: design-preview, observability, error-handling, concurrency added to bundle dependencies (now 51 — every non-bundle plugin)
- Boundary sharpening — overlap-cluster descriptions now name their deferrals in both directions: **dev-env** 0.3.2 ↔ **devops** 0.1.1 (local dev environments vs CI/CD + production), **api-design** 0.3.2 ↔ **api-docs-first** 0.2.1 ↔ **meta-api** 0.2.1 (own APIs vs third-party docs vs Meta platform), **code-architecture** ↔ system-design (code-level structure vs system topology), code-review → framework review plugins (already stated; README row synced)

## [0.23.0] - 2026-07-05

### Added

- **design-preview** 0.1.0: new plugin — real-component visual decisions for Vite + React: candidate variants rendered with the project's own components on its dev server via a scratch HTML entry, strict consent + verified cleanup; falls back to taskmaster's shell mockups. Includes /design-preview:preview

### Changed

- **taskmaster** 0.9.0: theme-aware mockup shell with content primitives, motion decision passes, live-preview infra unified on one server with per-purpose files
- **api-design** 0.3.1, **code-architecture** 0.5.2, **dev-env** 0.3.1: live-preview integration mentions (contract-preview artifact, current-vs-target diagrams, topology diagram before YAML)

## [0.22.0] - 2026-07-05

### Added

- **orchestration** 0.1.0: new plugin — subagent orchestration discipline. delegation-contracts skill (self-contained prompt contracts with scope locks, compressed evidence-backed return formats, model/effort tiering per stage, scout-then-fanout, isolation rules for parallel writers) and verification-panels skill (cost-gated refuter voting, judge panels over independent attempts, loop-until-dry discovery, completeness-critic passes). Both auto-trigger from context. Includes /orchestration:review (report-only audit of fan-out plans and drafted agent prompts)

### Changed

- **everything** 0.6.0, **taskmaster-suite** 0.5.0: orchestration added to bundle dependencies
- **task-runner** 0.4.1, **code-architecture** 0.5.1, **taskmaster** 0.5.1, **git-workflow** 0.1.1: one-line delegation pointers to the orchestration plugin (parallel-planning, task-execution, task-orchestration, task-cards, worktree-isolation skills)

## [0.21.0] - 2026-07-05

### Added

- **packages** 0.1.0: new plugin — composer/npm dependency hygiene: semver constraint strategy (caret default, exact-pin cases, composer ~ vs npm ~ trap), lockfile discipline (commit always, npm ci/composer install in CI, regenerate on conflict), security-audit triage with fix lanes, and patch/minor/major upgrade lanes. Includes /packages:audit (report-only)

### Changed

- **everything** 0.5.0, **taskmaster-suite** 0.4.0: packages added to bundle dependencies

## [0.20.0] - 2026-07-05

### Changed

- **everything** 0.4.0: dependencies now include plugin-scout — added to the marketplace in 0.16.0 but never picked up by the bundle, leaving "installs every plugin" one plugin short

## [0.19.0] - 2026-07-05

### Added

- **hindsight** 0.1.0: new plugin — cross-session self-improvement loop. A SessionEnd hook appends per-session friction stats (turns, errors, best-effort friction events) to a gitignored project-local ledger (`.claude/hindsight/ledger.jsonl`); `/hindsight:harvest` ranks unmined sessions by friction score (fallback: direct transcript listing covers pre-install history), fans out a transcript-miner agent per session, applies a ≥2-session recurrence gate, and proposes CLAUDE.md rules, skill/plugin ideas, and failed-approach warnings — applied only on explicit approval; each report is also saved to `.claude/hindsight/reports/`

### Changed

- **everything** 0.3.0, **taskmaster-suite** 0.3.0: hindsight added to bundle dependencies

## [0.18.0] - 2026-07-05

### Changed

- **task-runner** 0.4.0: dropped the live run-board HTML — a status table duplicates what the task index and the conversation already show and goes stale when regeneration is forgotten. New rule in the task-execution skill ("No status theater"): HTML/localhost artifacts are reserved for content that earns the medium — mockups, interactive walkthroughs, behavior-proving demos, brainstorm canvases; command, README, and marketplace description updated to match

## [0.17.0] - 2026-07-05

### Changed

- Model-tier convention for agents — model now matches the cost of a wrong answer: **code-architecture** 0.5.0 (architecture-reviewer), **code-review** 0.2.0 (code-reviewer), and **system-design** 0.2.0 (system-architect) switch judgment-heavy agents from `model: sonnet` to `model: opus`; **taskmaster** 0.5.0 drops context-scout from `effort: xhigh` to `effort: high` (mechanical recon); **claude-authoring** 0.2.0 documents the tier table (opus/sonnet/haiku by wrong-answer cost), the orthogonal effort knob, and the per-invocation dispatch override in the authoring-agents skill

## [0.16.0] - 2026-07-05

### Added

- **plugin-scout** 0.1.0: new plugin — scans the current project's manifests (composer.json, package.json, tsconfig.json, .env, docker files) and suggests marketplace plugins in two tiers: stack-matched with per-row evidence, and the universal always-useful set; marks already-installed plugins via `claude plugin list`, reuses stack-scan's inventory when installed, and installs picked plugins via `claude plugin install <name>@cc-plugins-marketplace` after an AskUserQuestion confirm (headless: prints the commands). Includes /plugin-scout:suggest

## [0.15.0] - 2026-07-05

### Changed

- **everything** 0.2.0, **taskmaster-suite** 0.2.0: self-cleaning uninstall — each bundle ships /everything:uninstall and /taskmaster-suite:uninstall, which confirm via a selectable choice, then run `claude plugin uninstall <bundle> --prune -y` so the bundle and its auto-installed dependencies go in one step (the /plugin menu's uninstall does not prune); bundle descriptions now say so
- README: bundle uninstall instructions — --prune flag, standalone `claude plugin prune`, and the /plugin-menu-does-not-prune gotcha

## [0.14.0] - 2026-07-05

### Added

- **web-dev** 0.1.0: web-developer worker agent — generalist web implementation (routing, REST/API integration, forms and validation, state management, SSR/CSR trade-offs, accessibility baseline); stack-agnostic, defers to per-framework review plugins
- **system-design** 0.1.0: system-architect worker agent — service boundaries, data modeling, scaling paths, caching layers, sync vs async decisions with documented trade-offs; complements code-architecture's code-level scope
- **devops** 0.1.0: devops-engineer worker agent — CI/CD pipeline design, Dockerfile/compose, Kubernetes manifests, deploy strategies with stated rollback paths, observability, secrets discipline
- **database** 0.1.0: database-engineer worker agent — schema design, additive migrations, indexing strategy, query optimization, connection pooling; defers dialect review to sql/mysql/mariadb/postgresql
- **performance** 0.1.0: performance-engineer worker agent — measure-first profiling, bundle size, caching, Core Web Vitals, N+1 elimination, load testing; before/after evidence required
- **claude-authoring** 0.1.0: authoring guides for skills, agents, hooks, and plugins; routine-detector skill that proposes capturing repetitive work as a project skill; /claude-authoring:new-skill, /claude-authoring:new-agent, /claude-authoring:new-hook, /claude-authoring:new-plugin scaffold commands
- **code-review** 0.1.0: stack-agnostic review — /code-review:review command, proactive code-reviewer agent, code-smells skill (bloaters/couplers/change-preventers/dispensables + when-not-a-smell judgment); defers structure to code-architecture, depth to security, idioms to per-stack plugins
- **approaches** 0.1.0: approach-deliberation skill (2-3 structurally different candidates, honest trade-off table, pick with kill-trigger — kills first-idea anchoring), strategy-catalog skill (tracer bullet, walking skeleton, spike, strangler fig, inversion, Polya, simplest-thing, top-down/bottom-up, explain-first — each mapped to the risk it beats), /approaches:compare command
- **decision-records** 0.1.0: ADR skill with template, status lifecycle (proposed/accepted/superseded), immutable-history rule, and reading discipline (standing ADRs bind, revisit-when reopens); /decision-records:new
- **retrospective** 0.1.0: evidence-first retro protocol with three sinks (CLAUDE.md candidates proposed never silently written, skill suggestions via routine-detector, process tweaks); /retrospective:run
- **build-vs-buy** 0.1.0: gate-zero check for generic capability — shelf order (stdlib → installed deps → registry), candidate health table, take/wrap/write verdict, never-hand-roll list, wrap-thinness discipline; /build-vs-buy:check
- **rollout** 0.1.0: per-feature rollout planning — flag discipline with removal dates, backward-compat windows, expand-migrate-contract sequencing, staged exposure with gate metrics, rollback path stated before ship; /rollout:plan
- **resilience** 0.1.0: failure-mode design at every integration point — explicit timeouts with budget propagation, idempotency-first retries with backoff+jitter, circuit breaking, graceful degradation, bounded queues, delivery semantics; /resilience:review
- **docs-upkeep** 0.1.0: documentation drift prevention — drift catalog (README, changelog, API docs, config, ADR links), same-change rule, one-place-per-fact placement ladder, freshness signals; /docs-upkeep:check
- **estimation** 0.1.0: S/M/L/XL sizing with reference-class anchors, uncertainty multipliers, split triggers, size-to-done rule, estimate-vs-actual retro loop; weights align with task-runner parallel-planning; /estimation:size
- **a11y** 0.1.0: WCAG 2.1 AA audit — semantics-first, ARIA first-rule, keyboard operability, focus management, contrast ratios, forms, media, touch targets; /a11y:audit
- **everything** 0.1.0: meta-bundle — one install auto-installs all 43 plugins via the dependencies field
- **taskmaster-suite** 0.1.0: meta-bundle — taskmaster workflow plus the 30 stack-agnostic plugins (task pipeline, approach deliberation, decision records, retrospectives, build-vs-buy, rollout, resilience, docs upkeep, estimation, a11y, engineering discipline, UI/UX, code review, worker agents); excludes framework/dialect plugins

### Changed

- Suite-wide handoff-offer audit (43 findings across 3 review passes, all fixed): every command or skill that ends with a logical next step — apply the review fixes, run the engine-specific review, implement the approved plan/contract, record the ADR, finish the branch, run the retro — now offers it as a selectable choice (AskUserQuestion) instead of leaving a command to type; bare commands remain only for headless runs. Minor bumps: react 0.2.0, react-native 0.2.0, vue2 0.2.0, vue3 0.2.0, php 0.2.0, laravel 0.2.0, livewire 0.2.0, sql 0.2.0, mysql 0.2.0, mariadb 0.2.0, postgresql 0.2.0, typescript 0.2.0, inertia 0.3.0, code-architecture 0.4.0, design-patterns 0.2.0, api-docs-first 0.2.0, meta-api 0.2.0, stack-scan 0.2.0, api-design 0.3.0, dev-env 0.3.0
- **decision-records** (within 0.1.0): ADRs live at taskmaster-docs/adr/ — all suite output (specs, tasks, ADRs) under the one taskmaster-docs/ root
- **taskmaster** 0.4.0: pipeline outputs move from docs/ to taskmaster-docs/ (specs and task cards) — no collision with a project's own docs/ or superpowers' docs/plans; brainstorm skill now offers the grill continuation instead of auto-running it
- **claude-authoring** (within 0.1.0): authoring-skills guide gains the handoff-offer convention — completed skills/commands offer the logical next command as a selectable choice (AskUserQuestion), never homework to type; bare commands only when headless. Applied across task-runner:plan, approaches:compare, build-vs-buy:check, retrospective:run, rollout:plan, resilience:review, estimation:size, a11y:audit
- **task-runner** 0.3.0: parallel-planning skill + /task-runner:plan — computes the subagents-vs-inline decision from the task list itself (dependency levels, disjoint-file groups, critical path, ≥1.5x adjusted-speedup gate, ≤6-agent cap, replan rules); recommendation is optional, user picks the mode
- **ui-ux** 0.4.0: ui-ux-engineer worker agent — implements layouts, responsive breakpoints, spacing/color systems, element placement alongside the existing ui-ux-reviewer
- **testing** 0.3.0: test-engineer worker agent — authors and runs unit/integration/e2e tests, coverage-gap analysis, fixtures and boundary-only mocking
- **security** 0.2.0: security-engineer worker agent — implements defensive fixes: auth flows, OWASP remediations, headers/CSP, dependency-audit remediation

## [0.13.0] - 2026-07-05

### Added

- **code-architecture** 0.3.0: surgical-coding skill — always-on discipline for everyday edits outside the pipeline, adapted from Andrej Karpathy's LLM-coding guidelines (multica-ai/andrej-karpathy-skills, MIT): surface assumptions and competing interpretations before coding, every changed line traces to the request, the orphan rule (delete your own orphans incl. tests, flag pre-existing dead code instead), simplicity floor, vague-ask → verifiable-goal transformation with step→verify plans

## [0.12.0] - 2026-07-05

Superpowers parity batch — ports the remaining high-value workflows from obra/superpowers (MIT) into the suite, rewritten in house voice, so the marketplace stands alone without it.

### Added

- **taskmaster** 0.3.0: brainstorm skill + `/taskmaster:brainstorm` — fuzzy idea → approved design doc (one question at a time, decomposition of oversized ideas, 2–3 explored approaches, sectional approval, spec self-review, user gate), then approval-gated handoff into the grill pipeline with the design pre-seeding the ledger
- **debugging** plugin: systematic-debugging skill + `/debugging:debug` — root cause before any fix; reproduce → first error → what changed → one falsifiable hypothesis → smallest experiment; bisection; three-failed-fixes stop rule mirroring task-runner's park rule
- **git-workflow** plugin: worktree-isolation, branch-completion (full-suite gate → evidence → merge/PR/keep/discard with cleanup), and review-exchange (self-review before requesting; verify feedback technically before implementing) + `/git-workflow:finish`
- **testing** 0.2.0: tdd skill — red-green-refactor with fail-for-the-right-reason verification, red-green regression proof for bug fixes (revert-fail-restore), test-list burn-down, taskmaster acceptance criteria as the test list

### Covered without porting

writing-plans/executing-plans (taskmaster cards + task-runner), verification-before-completion (task-runner evidence discipline), dispatching-parallel-agents/subagent-driven-development (task-runner parallel groups + re-verification)

## [0.11.0] - 2026-07-05

### Added

Interactive artifacts across the suite — closing "how it works" vs "how it should work" gaps with things you can look at and click:

- **code-architecture** 0.2.0: structural plans render a current-vs-target architecture diagram (two SVG panels, current drawn from code evidence with file citations) on the live preview URL; target approved before the task sequence
- **task-runner** 0.2.0: live run board — auto-reloading HTML view of the task index (statuses, current task, evidence tails, backlog), regenerated at every status flip; the index stays the single source of truth
- **dev-env** 0.2.0: topology diagram before YAML — proposed services, connections, ports, and volumes as SVG alongside the service-plan table
- **api-design** 0.2.0: contract preview artifact — proposed endpoints with real example payloads and problem+json error bodies as a live page, approved before implementation

## [0.10.1] - 2026-07-05

### Changed

- **taskmaster** 0.2.1: pipeline no longer ends by printing a command — when task-runner is installed it asks "Start execution now?" and on approval invokes the task-execution skill on the fresh `00-INDEX.md` directly; manual `/task-runner:run` remains the fallback (decline, headless, or task-runner absent)

## [0.10.0] - 2026-07-05

### Added

- **taskmaster** 0.2.0: scales to whole experiences — new experience-walkthrough skill assembles accepted visual picks into one interactive clickable demo (screens, state toggles, failure exits) on the live preview URL and walks the user through it with a task script before the spec freezes; grill gains big-task slicing (decompose into screens/flows, per-slice grilling, cross-slice contract rows); task-cards gains milestone grouping (independently shippable checkpoints with their own full-suite verify)

## [0.9.0] - 2026-07-05

### Added

- **ui-ux** 0.3.0: ReUI (reui.io) and Aceternity UI (ui.aceternity.com) skills — registry install discipline, owned-code rules, token/theme alignment, motion dependency and performance budgets, reduced-motion accessibility; both docs-first (no npm version to pin — the live docs page is the source of truth). `/ui-ux:review` now detects and reviews both.

## [0.8.0] - 2026-07-05

### Added

- **meta-api** plugin: Meta (Facebook) developer platform navigator — always-current Graph API version from the changelog, predefined doc-link map per product (Graph, Pages, Instagram, WhatsApp, Messenger, Marketing), platform conventions (tokens, fields, cursor pagination, error codes, webhooks), required-permissions answers with Standard/Advanced access and App Review awareness (`/meta-api:check` + reminder hook)

## [0.7.1] - 2026-07-05

### Changed

- **inertia** 0.2.0: adapter-aware — advice now pins to the installed adapter (`@inertiajs/vue3`, `@inertiajs/react`, or `@inertiajs/svelte`) and matches its idiom instead of assuming Vue

## [0.7.0] - 2026-07-05

### Added

- **ui-ux** 0.2.0: shadcn-theming skill and `/ui-ux:theme` command — design a shadcn/ui token set (light + dark, contrast-checked) and iterate on one always-live preview URL showing swatches and real component mockups; applies to `globals.css` only after a confirmed diff
- ui-ux plugin README

## [0.6.0] - 2026-07-05

### Added

- **testing** plugin: test pyramid, Pest/PHPUnit and Vitest/Jest idioms, Playwright/Dusk e2e discipline, mocking boundaries, flaky-test causes (`/testing:review`)
- **security** plugin: OWASP-aligned defensive review mapped to PHP/Laravel and JS/Vue (`/security:review`)
- **typescript** plugin: strict-mode discipline, narrowing over assertions, runtime validation at boundaries (`/typescript:review`)
- **inertia** plugin: Inertia.js best practices for Laravel + Vue (`/inertia:review`)
- **api-design** plugin: REST resource naming, status codes, pagination, versioning, RFC 9457 errors (`/api-design:review`)
- **dev-env** plugin: scan dependencies and generate a matching docker-compose.yml + Dockerfile (`/dev-env:init`), audit existing docker files (`/dev-env:review`)
- `/taskmaster` shorthand command (alias of `/taskmaster:task`)
- MIT LICENSE
- GitHub Actions workflow running `scripts/validate.sh` on push and PR
- Cross-reference check in `scripts/validate.sh`: `/plugin:command` mentions must resolve to a listed plugin
- Per-plugin READMEs with usage examples (taskmaster, task-runner, stack-scan, and all six new plugins); root README slimmed to summaries + links
- This changelog

### Changed

- taskmaster pipeline runs stack-scan inventory first when installed; final output names `/task-runner:run` when available

## [0.5.0] - 2026-07-04

### Added

- Database plugins: sql, mysql, mariadb, postgresql
- task-runner plugin: disciplined task execution with bounded verify-fix loops
- stack-scan plugin: required-vs-installed version inventory

### Changed

- Renamed grill-me plugin to taskmaster; documented the taskmaster workflow suite (stack-scan + taskmaster + task-runner + code-architecture)
- README install instructions point at github.com/galaykos/cc-marketplace

## [0.4.0] and earlier

- Initial plugins: ui-ux, react, react-native, vue2, vue3, php, laravel, livewire, code-architecture, design-patterns, api-docs-first, grill-me
