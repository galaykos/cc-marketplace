# Marketplace review — 2026-08-02: coverage breadth

Companion to `rationale/marketplace-review-2026-07-28.md`, which audited
**enforcement and mechanism**. This one audits the other axis: **is this a
credible one-stop shop for every type of task?**

Method: 10 blind domain lenses + 2 synergy audits → synthesis → 3 adversarial
refuters (baseline-redundancy / existing-coverage / cost-and-scope) →
completeness critic. 17 agents, 611 tool calls, ~2.03M subagent tokens.
Numbers below marked **measured** were re-run by hand in the main thread after
the fan-out returned.

Standing labels per CLAUDE.md: `gate` / `agent-graded` / `recorded` /
`unenforceable`.

---

## 1. Verdict

**The framing in the request is the finding.** This is not a thin marketplace
with holes to fill. It is a dense, well-bounded software-engineering toolkit —
58 leaves, 126 skills, 32 agents — whose weakest property is that almost
nothing verifies its own claims, and whose second-weakest is that its cost
model measures the wrong channel.

1. **The always-on cost is ~14.1k tokens, not the ~10.6k the README advertises
   in three places.** Measured: `plugins/skill-router/hooks/route-prompt.sh`
   emits **9,461 bytes (~2,365 tokens)** on any work-shaped prompt — a second
   copy of every installed command's description, on top of what the harness
   already loaded. `plugins/terse/hooks/mode.sh` adds 697 bytes
   unconditionally; taskmaster's `ultra.sh` 774 and `remind.sh` 136 on trigger;
   `registry-source`'s MCP `tools/list` 1,936 bytes with a metered baseline of
   **0**. `scripts/context-budget.sh:11` states verbatim that this channel is
   "NOT metered". The gated baseline (11,523) and the advertised number
   (~10.6k) are both below the truth, and the gate cannot see the difference.

2. **Nothing records that a plugin was ever used, and the one file that knew is
   deleted on purpose.** `plugins/skill-router/hooks/route.sh` writes
   `.claude/skill-router/fired-<sid>.json` holding `.fired[]` and
   `.pending_low[]` — the only artifact in the marketplace that knows which
   skills a session loaded — and `summary.sh:26` prints one digest line and
   `rm -f`s it. Every cut this marketplace has ever made was argued from token
   counts and trigger overlap because the denominator does not exist.

3. **The marketplace was never audited against its host.** Measured mentions
   anywhere under `plugins/`: `dataviz` 13 files, `claude-api` 4 files, and
   **zero** for `skill-creator`, `artifact-design`, `artifact-capabilities`,
   `update-config`, `claude-in-chrome`, `simplify`, `/run`, `/review`,
   `/security-review`, `/init`. Concrete collisions: `security` ships a skill
   literally named `security-review`, the same name as a host command, and
   `rules.tsv:58` routes to the marketplace one with no disambiguation; the
   host `simplify` covers "reuse, simplification, efficiency… then apply the
   fixes", which is `code-review`'s two skills plus the apply lane §3 W4 says
   `code-review` is missing; `claude-in-chrome` overlaps `design-preview`'s
   entire reason to exist. `scripts/lib/plugin-checks.sh:128-131` enforces
   exactly one host boundary and only in the inverse direction.

4. **102 of 126 skills route from nothing** (confirmed exactly: 126 skill
   directories, `rules.tsv` column 3 yields 24 distinct skill tokens), and one
   routing rule has never been able to fire. Measured: `rules.tsv:39`
   `**/routes/api.php` is tested by `route.sh:42-53` against the *basename*
   `api.php`, because `match_glob` special-cases only the `**/x/**` form —
   `api-design` has never been routed by file pattern. Three existing smoke
   harnesses cannot see this: they test collisions and marker semantics, not
   firability.

5. **The catalog is wrong right now and `validate.sh` exits 0 on it.**
   `README.md:47` reads `| everything | 57 | ~10.6k tokens |` against 58 actual
   dependencies (measured) and a baseline of 11,523. `validate.sh:188-192`
   gates the leaf count via `grep -oE 'all [0-9]+ (leaf )?plugins' | head -1`,
   which matches the *correct* prose at `:10` and never reaches the wrong row
   three lines below. The genuinely wrong field is the token number, and it is
   wrong in three places (`:10`, `:47`, `:70`).

6. **Coverage breadth is real where it matters and absent where it should
   stay absent.** Of 40 domains graded in §2: 12 strong, 13 partial, 8 thin,
   7 absent-or-out-of-scope. The four absences that actually cost this
   audience something are **polyglot version truth**, **project coding
   conventions**, **supply-chain / licence**, and **codebase archaeology at
   scale** — and three of the four are answerable with a `references/` file or
   a script at **zero metered tokens**.

7. **The honest conclusion, restated for this axis:** the marketplace does not
   need more domains. It needs to be able to tell whether the domains it has
   do anything. 20 of the 29 synthesized proposals cost zero *metered* tokens;
   the refuters killed or reshaped 11 of them, and every survivor that carries
   a script beats every survivor that carries prose.

---

## 2. The domain taxonomy, graded

The request's list — "design, content, writing, code, architecture, framework,
coding language, syntax, coding standards and more" — expanded to the 40
domains a one-stop-shop claim actually implies, each graded against what
ships today.

| Domain | Grade | State |
|---|---|---|
| Code review & quality | strong | code-review + code-smells + reuse-hygiene + 32 chassis review commands with a shared apply lane; the flagship fan-in command's apply pick names no dispatch target |
| Software architecture & system design | strong | code-architecture (7 skills), system-design, approaches (7 decision skills) — dense, explicitly deferring to each other |
| Web frameworks & runtimes | strong | nextjs/nuxt/vue3/vite/react/react-native/node-backend/laravel/livewire/inertia carry real version-leverage maps; Astro/SvelteKit/Angular missing; node-backend states Node-server rules as universal where serverless/edge makes them wrong |
| Programming languages & syntax | thin | php is the only true language plugin; stack-scan's version-source procedure enumerates PHP and JS/TS only, so a Python/Go/Rust/JVM/.NET repo gets a PHP-shaped answer |
| Coding standards & project conventions | thin | code-review claims convention drift at review time with no procedure for FINDING the conventions — zero repo-wide hits for `editorconfig`; the only linter-aware artifact in 58 plugins is a regex in comment-discipline/hooks/scan.sh:150 |
| Testing | partial | testing-best-practices + tdd are strong prose with a flaky-test taxonomy; the plugin runs nothing — execution lives in task-runner, a different install |
| Debugging & incident response | partial | systematic-debugging is excellent; its debugger agent is orphaned (§3 W3); no incident lane, and the no-fix-before-root-cause law is wrong for a live outage |
| Relational databases & SQL | strong | sql + 3 dialects + database-design + the only destructive-statement PreToolUse guard here; dimensional/warehouse modeling absent |
| NoSQL, vector & analytical stores | absent | zero document/key-value/wide-column modeling, zero vector index coverage; the 4-SQL/0-NoSQL split reflects the author's stack |
| Data engineering & analytics | absent | no pipeline, orchestration, dbt or data-quality coverage; coverage stops the moment work becomes scheduled and batch |
| AI/LLM application engineering | partial | llm-app names every right discipline and ships 5 files — no template, no script, no reference; its "regression-gate" section has no artifact behind it |
| Application security | strong | security (4 skills) + secret-scanning's PreToolUse deny; scoped to web app code by declaration and honest about it |
| Supply chain & CI trust boundary | thin | packages covers the registry axis; zero coverage of workflow trigger safety, token scoping, action pinning, dependency licences |
| Compliance, legal & obligation | thin | data-privacy is good regulatory prose whose own data-inventory requirement nothing checks; a11y teaches WCAG while naming no regime that binds it |
| DevOps & CI/CD | partial | dense on pipeline ordering, k8s, deploy strategy, with a worker/reviewer pair; says nothing about writing shell correctly |
| Infrastructure as code & cloud | absent | zero occurrences of terraform/pulumi/cloudformation anywhere in plugins/; the plan-review gate is the cheapest testable gate not built |
| SRE, observability & reliability policy | partial | observability-design covers in-code telemetry well; `SLO` appears exactly once in the whole tree, so two plugins demand a number nothing teaches anyone to derive |
| Performance | partial | owns the measure loop and application-cache correctness; the HTTP/CDN layer (Cache-Control, Vary, s-maxage, SWR, surrogate purge) is uncovered in a Next/Nuxt-shaped audience |
| Resilience & error handling | strong | timeouts, retries, idempotency, circuit breaking, degradation, backpressure, with explicit boundaries |
| UI/UX & design systems | strong | a three-stage token pipeline (scales → roles → values) with light/dark duality; component API design and token-adherence enforcement are the holes |
| Visual craft & creative direction | strong | 13 skills plus three real script gates — the best-enforced surface here; every positive gate is marketing-page-shaped |
| Accessibility | strong | WCAG 2.2 AA including the 2.2-specific criteria a generic model omits — but routes on `*.tsx` only, so Vue/Blade/HTML projects never get it at edit time |
| Non-web design deliverables | thin | HTML email is the largest uncovered deliverable and the one where the agent's own preview lies to it; print/decks/logo correctly out of scope |
| Content, marketing copy & claim hygiene | partial | craft-layer's fabrication taxonomy is the strongest writing doctrine in the repo and fires only inside `/craft-layer:craft` — never on a README, release note or security page |
| Technical writing & documentation | partial | api-docs-first owns doc drift and placement and disclaims authoring in its own words; the freshness-stamp mechanism this repo runs internally is withheld from the plugin's users |
| Prose voice & written-artifact style | absent | terse explicitly excludes files on disk; nobody owns register or padding in a README, docs page or PR body |
| Product management | absent | `product-suite` is named for this and ships payments + i18n + llm-app — three engineering domains. PRD/personas/prioritization correctly rejected as baseline-redundant |
| Business, pricing & entitlements | thin | payments covers everything downstream of the charge and nothing upstream — no plan model, no versioning, no grandfathering, no entitlement matrix |
| Engineering process & task lifecycle | strong | taskmaster → task-runner → git-workflow is the deepest pipeline here, multiply gated |
| Codebase archaeology, debt & at-scale change | thin | the forward pipeline is excellent, the backward one has almost no mechanism: nothing measures codemod completeness, nothing ratchets debt, no file in plugins/ contains `git blame` |
| Dependency & version truth | partial | packages is composer+npm by its own title; stack-scan declares itself the version input every plugin pins against and has no rule for a pnpm `catalog:` alias, a Go toolchain directive, or a rust-toolchain override |
| Research & document analysis | partial | domain-neutral and full for web research; its engine is corroboration over URLs, so a single authoritative local document has no coverage engine |
| Tabular data analysis | absent | no profiler, no coercion-trap list, no reconciliation discipline — the one non-code territory that still has a file and a claim that can be wrong |
| Diagramming | thin | the marketplace can draw exactly one thing: a mermaid ERD, only during taskmaster spec writing |
| Agent, skill & plugin authoring | strong | 7 skills, 5 scaffolds, the chassis generator, the four laws; its behavioral-testing method is prose at standing `recorded`, run by hand exactly once |
| Marketplace mechanics & discovery | partial | install UX and the generated catalog are carefully built; the bundle table is wrong today, 102/126 skills route from nothing, one rule has never fired, nothing records usage |
| Native mobile, desktop & game dev | out-of-scope | Swift/Kotlin/Dart/Unity compose with no worker, reviewer, router row or suite; Expo inside the existing react-native plugin is the only defensible mobile investment |
| Legal drafting & contract review | out-of-scope | a generated policy reads authoritative, gets published verbatim, has no verification path — the honest-limitation law forbids it |
| Personal productivity & non-repo comms | out-of-scope | no file, no diff, so none of the four mechanism shapes has a surface to attach to |
| Brand identity, illustration, image & video | out-of-scope | not agent-executable; asset-sourcing already routes brand-defining marks to COMMISSION, which is the correct answer already written down |

---

## 3. The adjudicated backlog

Post-refutation. Every item states its **standing** and whether it adds a
**metered description**. The measured average shipped skill description is
**239 bytes ≈ 60 tokens** (across all 126), not the ~40 the fan-out assumed.

### P0 — measurement and honesty (all zero metered tokens)

> **Landed 2026-08-02.** All six. Verified green: the four gate scripts plus 16
> smoke harnesses, `parity-check`, `role-floors-check` and 8 plugin author-time
> lints — 29/29. What the measurement actually found, now that it runs:
>
> | | before | after |
> |---|---|---|
> | `everything` always-on | 11,523 (advertised ~10.6k) | **11,998** |
> | leaf total always-on | 11,531 | **12,006** |
> | `registry-source` | 0 | **475** (its local MCP `tools/list` was never counted) |
> | dynamic channel | unmeasured | **2,399** (`skill-router` 2,365 + `taskmaster` 34) |
> | real first-work-prompt floor | — | **~14.4k** |
>
> New artifacts: `scripts/context-budget-dynamic-baseline.json`,
> `plugins/hindsight/hooks/skill-use.sh`. New gate functions:
> `pc_rules_reachable`, `pc_host_overlap` (8 new smoke fixtures in
> `rules-overlap-tests.sh`). `plugins/skill-router/rules.tsv:39` fixed —
> `api-design` can route by file pattern for the first time. Two plugin versions
> bumped (`skill-router` 0.6.0→0.7.0, `hindsight` 0.3.1→0.4.0).
>
> Not done in that pass, and deliberately: `pc_host_overlap` found **zero**
> current violations, so it is preventive only — the substantive host overlaps
> §1.3 names (`security-review` vs the host command, `simplify` vs code-review,
> `claude-in-chrome` vs design-preview) are *deferral prose* still unwritten, and
> no gate can write them.

| # | Item | Standing | Why first |
|---|---|---|---|
| M1 | **Meter the three unmetered channels, then fix the advertised number.** Sibling functions to `plugin_sessionstart_bytes()` in `context-budget.sh`: feed a synthetic UserPromptSubmit/PostToolUse payload and count stdout; run `tools/list` against each `.mcp.json`. Then make whatever generates the README bundle table also own the prose numbers at `:10` and `:70`. | gate | 20 proposals claim "zero always-on tokens" against a meter pointed away from the spend. ~40 lines against an existing working shape. |
| M2 | **Usage telemetry.** Before `summary.sh:26`'s `rm -f`, append the session's `fired[]`/`pending_low[]` to `$HOME/.claude/skill-router/surfaced.jsonl`; add a ~25-line PostToolUse hook in the existing hindsight plugin (matcher `Skill`) appending `{v,ts,skill,session_id}`. Read on demand by `/hindsight:harvest`. Nothing reads it automatically — deliberate. | recorded | The only artifact that ever produces a denominator. "This skill fired zero times in 200 sessions and costs 60 always-on tokens" is currently an unwriteable sentence, and it is the only sentence that can shrink this marketplace. Two edits to existing fail-open hooks. |
| M3 | **Widen the CI author-time lint glob.** `.github/workflows/validate.yml:66` → `plugins/*/scripts/__tests__/*.test.sh`. One line. | gate | Every script-bearing proposal below arrives with fixtures CI silently will not run. Note the corrected premise: today this catches **zero** additional tests (only task-runner and taskmaster have `__tests__`) — its value is entirely prospective, as the difference between a plugin script gate being enforced and being recorded-masquerading-as-gate. |
| M4 | **rules.tsv reachability gate + the one-character fix.** `pc_rules_reachable` in `plugin-checks.sh`: every glob row must match at least one corpus path using route.sh's own `match_glob`; every content row's regex must match at least one corpus file. Fix `:39` `**/routes/api.php` → `api.php`. | gate | Catches a row dead for months and makes future routing rows falsifiable — the precondition for ever deleting one. **Effort is M, not S:** the corpus at `scripts/smoke/router-corpus` holds 5 files covering ~5 of ~30 glob rows, and expanding it re-runs `pc_rules_cofire`'s O(n²) pairing. |
| M5 | **README catalog-integrity gate.** `render_bundle_table()` in `generate.sh` beside `render_catalog()`, emitting between preserve markers from `plugin.json .dependencies\|length` + `context-budget-baseline.json`; ~15 lines in `validate.sh` failing a `###` heading followed by a header+separator with zero data rows (`README.md:170` has been empty since 2026-07-06); tighten the plugin-listing gate at `:471-478`. Same commit: add the missing `plugin install plugin-scout` line at `:9` and the missing quality-principles-suite line at `:75-80`. | gate | Lane 1 — the officially recommended path — tells a new user to run a command from a plugin the README never installs. **Corrected scope:** exactly one *count* cell is wrong (57 vs 58); the other 8 rows match. The token column is the field that is actually wrong, and it must be generated *and capped*, not generated and free to grow. |
| M6 | **Host-skill overlap audit + a deferral gate in the direction that matters.** `pc_host_overlap` beside `pc_removed_refs`: a denylist of host skill names (dataviz, skill-creator, artifact-design, artifact-capabilities, claude-api, claude-in-chrome, simplify, run, init, review, security-review) failing any `plugins/` `.md` that introduces a skill or command matching one, unless the line is a deferral — reusing the existing `built-in\|external\|harness-provided` rescue idiom at `plugin-checks.sh:129`. | gate | The dataviz precedent is held together by prose alone (`information-design/SKILL.md:100`, `:147`). Zero tokens, one function, same sweep. Produced the single hard kill in this review (§4). |

### P1 — wiring that multiplies what already ships (zero new descriptions)

> **Landed 2026-08-02.** All seven, zero new skill or command descriptions.
> Verified green: 4 gate scripts, 16 smoke harnesses, `parity-check`,
> `role-floors-check`, 8 plugin author-time lints.
>
> - **W1** `pc_handoff_refs` — ~90 bare `plugin:agent` edges across 37 targets,
>   none previously checked. All resolve today; a typo in a LIVE name is now
>   caught, which is the class `pc_removed_refs` structurally cannot see. Two
>   structural guards instead of an exclusion list: LHS must be a real plugin dir,
>   and a token preceded by `<` is markup (Blade/Livewire tags share the syntax).
> - **W2** `stack-scan/.../references/ecosystems.md` — the five authority
>   conflicts only (Go toolchain, `rust-toolchain.toml`, `global.json`
>   rollForward, `uv.lock`'s own `requires-python`, JVM toolchain) plus pnpm
>   `catalog:` alias resolution. Per-version feature lists deliberately cut — that
>   is the shape that measured 0 delta twice.
> - **W3** `debugging:debugger` un-orphaned in its own command; task-execution
>   makes ONE bounded dispatch to it before the three-cycle halt.
> - **W4** apply-lane parity for all **three** commands that named no target
>   (`code-review`, `api-design`, and `orchestration` — the last with an explicit
>   in-flight-vs-on-disk split rather than a pretend dispatch). `a11y:a11y-audit`
>   added to the frontend/ui-ux rows and `resilience:resilience-design` to the
>   backend/api rows of the reviewer Resolution map.
> - **W5** `check-doc-staleness.sh` widened to `skills/*/SKILL.md`, so the ~15
>   stack plugins' inline version claims are visible to it for the first time.
>   The blocking half is **not** shipped: `pc_version_stamp` reports the 9
>   claimants with no stamp as a WARN. Promoting it to a gate would force a
>   fabricated provenance record onto nine plugins; the printed list is the work
>   queue for the real verification pass.
> - **W6** SvelteKit/Astro/Angular/Django/Rails/Flutter/Go/Rust/Workers/Deno/
>   Terraform rows in vercel-skills-scout, ordered BEFORE the `vite` row — a
>   SvelteKit repo used to match `vite` and get Vite skills back. Plus
>   `plugin-scout/.../references/signals.md` for the repos its 14 manifest signals
>   cannot see.
> - **W7** `/git-workflow:finish` runs `/code-review:review`,
>   `code-architecture:drift-review` and `/secret-scanning:scan` before offering a
>   destination; a critical finding drops merge and PR until resolved or waived on
>   the record. `review-exchange` gained the reciprocal reference it had never
>   carried.
>
> Regression found and fixed in the same pass: the first `pc_handoff_refs` spawned
> three processes per LINE and took `validate.sh` from 30s to 110s (and
> `role-floors-check`, which runs it nine times, to 445s). Rewritten single-pass:
> 33s and 145s. A gate slow enough to discourage running locally only ever fires
> in CI.

| # | Item | Standing |
|---|---|---|
| W1 | **Cross-plugin reference gate, modes 1+2.** One extractor in `plugin-checks.sh`: (1) every bare `<plugin>:<name>` where `plugins/<plugin>/` exists must resolve to an agent, skill or command file; (2) each resolved reference must carry a declared dependency, a degradation clause within 2 lines, or `<!-- handoff-ok: reason -->`. Today `pc_removed_refs` knows only a hardcoded list of 8 removed names, so `ui-ux:ui-ux-enginer` passes every gate. **Mode 3 (bundle closure) is cut — see §4.** Needs a second extractor keyed on host skill names, or it gates ~200 in-repo edges and zero external ones. | gate |
| W2 | **stack-scan authority-conflict reference.** `references/ecosystems.md` — narrowed to the five places two local files disagree and the non-obvious one wins: `uv.lock`'s own stricter `requires-python`; `global.json` `rollForward` selecting a different SDK than `dotnet --version` prints; the Go `toolchain` directive + `GOTOOLCHAIN` silently fetching a compiler that is not the shell binary; `rust-toolchain.toml` overriding rustup per-directory; pnpm's `catalog:` being an alias resolved through `pnpm-workspace.yaml`. Per-version feature lists cut — those are the shape that measured 0 delta twice. | recorded |
| W3 | **Un-orphan the orphaned agents.** `/debugging:debug` never names `debugging:debugger`; the string `debugging:debugger` appears **nowhere in the repository**. Route the proven fix down `task-runner:task-executor if installed → inline`, and let task-execution's three-cycle halt make ONE bounded dispatch to it before halting. **Corrected scope:** four more agents have zero external referrers — `craft-layer:creative-director`, `terse:terse-builder`, `terse:terse-investigator`, `terse:terse-reviewer`. | agent-graded |
| W4 | **Apply-lane parity for the THREE commands missing a dispatch target.** Not one. `code-review/commands/review.md:72-74`, `api-design/commands/review.md:33-36`, `orchestration/commands/review.md:34-35` all offer an apply pick that names no target; the other 29 carry the `task-runner:task-executor` chain. Plus `a11y:a11y-audit` on the ui-ux/frontend rows and `resilience:resilience-design` on the backend/api rows of `reviewer-routing.md` — LHS keys unchanged so the vocab-sync gate stays green. | gate (RHS half: `validate.sh:234-237` resolution-checks the Resolution map) |
> **W5's blocking half landed 2026-08-02, after the verification pass it was
> waiting on.** Nine claimants, each checked against upstream, each stamped with
> the URL actually consulted:
>
> | Plugin | Claim checked | Verdict |
> |---|---|---|
> | laravel | "Laravel 13 current, March 2026, PHP 8.3+" | accurate (13.7.0, 2026-04-28) |
> | nextjs | "16 current stable; 16.2 as of 2026-07" | accurate (16.2.12, 2026-07-25) |
> | mysql | "8.0 EOL April 2026; 8.4 LTS" | accurate (extended support ended 2026-04-30) |
> | mariadb | "10.11 / 11.4 / 11.8 / 12.3 LTS; x.3 is the LTS from 12.x" | accurate (12.3.2 LTS, May 2026) |
> | php | "floor range 8.1–8.5; 8.5 current" | accurate (8.5.8, 2026-07-02) |
> | vite | "Vite 7 and 8 require Node 20.19+/22.12+" | accurate (Vite 8 stable 2026-03-12) |
> | threejs | "WebGPU Baseline since Jan 2026" | accurate (Chrome/Edge/Firefox/Safari 26+) |
> | dev-env | example image tags | **STALE — `node:24.13-alpine` fixed to 24.16** |
> | postgresql | — | already stamped via `references/pgvector.md` |
>
> Eight of nine were accurate; the ninth had drifted three patch releases and
> nothing could see it, which is the case the gate exists for. `packages` was
> DROPPED as a claimant: the detector matched the word `lockfile` in a description
> about lockfile DISCIPLINE — semver semantics, which do not drift — and a
> detector that manufactures debt teaches people to ignore it. Narrowing it also
> surfaced `mariadb`, which the old pattern had missed entirely.
>
> The WARN is now an `err`, with a negative control run: removing one stamp fails
> the build with the plugin named. Standing moves `recorded` → **gate**.

| W5 | **Make the version-leverage stamp gate reach the plugins whose exemption depends on it.** `check-doc-staleness.sh:92` scans `*/references/*.md`; all 15 stack plugins have **zero** files under any `references/` directory, so all 10 stamped files in the repo sit in ui-ux/craft-layer and the check has never seen a single version claim any stack plugin makes. Widen to `plugins/*/skills/*/SKILL.md`; a plugin whose own description claims version leverage MUST carry a stamp (hard existence gate, no network, no model). Freshness stays warn-only. | gate (existence) + recorded (freshness) |
| W6 | **Teach the scouts the stacks this marketplace does not cover.** Narrowed: the Astro/Django framing is wrong — `vercel-skills-scout/SKILL.md:47-51` already recovers interactively on zero signals. The surviving leg is **SvelteKit**, which matches the `vite` devDependency row, never reaches the ask-the-user branch, and returns Vite skills for a SvelteKit question. Plus `plugin-scout/references/signals.md` for repos its 14 manifest signals cannot see — four of the eight families are already encoded verbatim as `rules.tsv` rows (`:45-47`, `:40-41`, `:53-54`, `:55`) and should be lifted, not re-derived. | agent-graded |
| W7 | **`/git-workflow:finish` review fan-out.** `finish.md:11-26` goes suite-green → destination offer with nothing between; `review-exchange` — the skill scoped to "requesting a code review or acting on one received" — contains zero references of any kind. Insert `/code-review:review`, `drift-review`, `/secret-scanning:scan`, each if installed. **Sequenced after M2:** this makes every branch-finish permanently more expensive, forever, with nothing verifying the added spend bought a finding. | agent-graded |

### P2 — mechanisms, prose cut

> **Partially landed 2026-08-02** — first tranche, three items, **zero new skill
> or command descriptions** as the lane requires.
>
> | Item | Shipped | Standing |
> |---|---|---|
> | NoSQL (database) | `hooks/guard.sh` gains the empty-filter `deleteMany`/`updateMany`/`remove`, `.drop*()`, and request-path `Scan` branches — same fail-open ask lane. **The skill stayed cut.** 18 fixtures, both directions | gate (ask) |
> | CI supply-chain (devops) | `scripts/workflow-audit.sh` (6 rules, exit 2 on critical) + `hooks/workflow-guard.sh` PreToolUse **deny on exactly 2 classes**. **No SKILL.md** — 12 lines added to the existing `devops-practices` validation table instead. 14 fixtures | gate (deny + exit code) |
> | Debt ratchet (code-review) | `scripts/debt-scan.sh` — 5 categories, committed baseline, `--check` exits 2 on growth, `--update-baseline` accepts it, `--age` resolves first-seen dates by git pickaxe. **No new skill and no new command** — a `--debt` lane on the existing `/code-review:review`. 14 fixtures | gate |
>
> **M3 paid off immediately and measurably.** Before the CI glob widened, exactly
> two plugins had a `scripts/__tests__/` directory. These three items add three
> more, and all 46 of their fixtures run in CI on the first push — the "entirely
> prospective" value became actual within one lane.
>
> **The audit found a real defect in this repository on its first run**, and then
> a defect in itself. `.github/workflows/validate.yml` had no top-level
> `permissions:` block, so every step inherited the repo default token scope —
> fixed here. And the first draft of rule 2 flagged
> `${{ github.event.pull_request.base.sha }}` as critical: a 40-char SHA GitHub
> generates and no PR author can influence. Matching by prefix
> (`github.event.pull_request.*`) was the wrong unit; it now matches by LEAF, and
> a fixture locks that specific false positive. A gate that cries wolf on ordinary
> CI is a gate that gets switched off, taking the two real classes with it.
>
> **Tranche 2, landed 2026-08-02** — four more items.
>
> | Item | Shipped | Standing |
> |---|---|---|
> | Sweep migration (task-runner) | `scripts/sweep-residual.sh` — freeze the target set + tree hash, re-measure after each batch, exit 2 residual / 4 target-set-moved / 5 cannot-measure; allowlist entries require a written reason. `--sweep` lane on the existing `/task-runner:run`, **no new skill**. 13 fixtures | gate |
> | Flake-hunt (testing) | `scripts/flake-hunt.sh` — N runs × 2 axes, set-diffed into order-dependent / non-deterministic / **broken**, each with its fix lane; baseline ratchet for known flakes. `/testing:flake-hunt` command. 13 fixtures | gate |
> | Project conventions (code-review) | `hooks/conventions.sh` PostToolUse, one-shot per session, emitting config **paths** and the CI lint invocation. **The skill stayed cut, and so did the digest** — an earlier design emitted "the three settings most often violated", the exact narrowing shape the doctrine measured as making review worse. A fixture asserts no setting VALUE appears in the output. 12 fixtures | advisory hook |
>
> **The dynamic meter earned itself in this tranche.** Adding one command
> description (`/testing:flake-hunt`) cost **+42 always-on** — expected — and
> **+14 dynamic**, because `skill-router`'s UserPromptSubmit hook rebuilds the
> command catalogue at runtime and re-injects it on every work-shaped prompt. That
> second-order cost was invisible to every gate in this repo before M1 landed
> earlier today. Both baselines re-seeded deliberately; `everything` is now
> 12,048 always-on + 2,413 dynamic.
>
> **Tranche 3, landed 2026-08-02** — three more.
>
> | Item | Shipped | Standing |
> |---|---|---|
> | Licence (packages) | `scripts/licence-scan.sh` — lockfile-driven, distribution-mode aware, exit 2 denied / 3 unresolvable, `--init` writes a policy. **Not inert by default**: `--distribution saas` alone is a complete run, which is what the cost refuter's kill hinged on. A licence lane on the existing `/packages:audit`, **no new skill**. 23 fixtures | gate |
> | pgvector (postgresql) | `references/pgvector.md` — opclass/metric mismatch silently disabling the index, post-filtered ANN returning fewer and worse rows as the filter tightens, `ef_search`, the 2000-dim ceiling, model change = backfill. Pointed at from the index-arsenal section | agent-graded |
> | Expo (react-native) | `references/expo.md` — only the four facts whose standard remediation INVERTED. Plus `app.config.*` and `eas.json` `rules.tsv` rows guarded on `package.json~"expo"`, and a `.chassis.json` preamble so `/react-native:review` reads it | agent-graded |
>
> **The licence scanner's evidence is a measurement inside this repo, so the
> measurement is also the test.** `plugins/shadcn-studio/template/package-lock.json`
> has 170 entries, twelve MPL-2.0 (lightningcss and its eleven platform binaries,
> pulled in transitively by Tailwind v4), **none in `package.json`**. A fixture
> asserts all twelve are found AND that the premise still holds — if MPL ever
> appears in the manifest, the fixture fails rather than silently proving nothing.
> The same lockfile is clean for `saas` and denied for `distributed-binary`, which
> is the distribution-mode conditional demonstrated on live data rather than
> asserted.
>
> **One item could not be done as specified, and forcing it would have been
> worse.** `react-native`'s SKILL.md body sits at exactly the 150-line ceiling.
> Adding a four-line pointer to the Expo reference needs four lines back, and
> repacking every prose paragraph outside its code fences yielded **zero** — the
> body is genuinely dense. The available trades were deleting content on my own
> judgment (the "Common mistakes" recap is the only redundancy, and it is the
> review command's checklist) or over-running the gate. Neither happened. The
> reference is reachable from `/react-native:review` via the chassis preamble and
> from `plugins/react-native/README.md`, and NOT from the skill body — stated in
> that README as a limitation rather than left for a reader to discover.
>
> An earlier attempt at the same repack **reflowed a fenced `jsx` example into
> prose** before the word-multiset check caught it. Any future line-reclaiming
> pass must be fence-aware; the working version is in this commit's history.
>
> **Tranche 4, landed 2026-08-02 — P2 COMPLETE, 11 of 11.**
>
> | Item | Shipped | Standing |
> |---|---|---|
> | design-preview beyond React | Vue/Nuxt branch (the extra-HTML-entry trick transfers unchanged; only the mount call differs) and a Laravel branch that says plainly the trick does **NOT** transfer — PHP owns routing, so it is a scratch Blade view plus one marked route block. Consent prompt names the route file, and cleanup verifies with `php artisan route:list`, because a leftover ROUTE is reachable in a way a leftover HTML file is not | agent-graded |
> | Local-corpus analysis (ultra-deep-research) | `references/local-corpus.md` + a pointer in the SKILL body. **No new skill description** — the refuter's narrowing kept the coverage manifest and dropped the rest. Reuses the shipped verifier agent and contradiction ledger, pointed inward at internal contradictions | agent-graded |
>
> The earlier note that these two "need a funding deletion you approve" was wrong
> and is corrected here: both host skills had real headroom (114 and 116 lines
> against 150). The ceiling pressure was specific to `react-native`, `task-runner`
> and `plugin-scout`, and generalising it was an error.
>
> `design-preview`'s description grew +7 tokens (React-only → Vite React/Vue plus
> Laravel). The gate caught it, the baseline was re-seeded deliberately, and the
> README bundle table regenerated itself: `everything` is now ~12.1k always-on.

Every item here survived on its script or hook and lost its SKILL.md. That is
the pattern: **ship the teeth, skip the description.** Applying it across P2
avoids ~11 new metered descriptions (~660 tokens at the measured average).

| Item | What ships | What was cut |
|---|---|---|
| CI supply-chain (devops) | `workflow-audit.sh` (exit non-zero on `pull_request_target` + ref checkout, `${{ github.event.* }}` in a `run:` block, mutable-tag `uses:`, no top-level `permissions:`) + a PreToolUse deny on `.github/workflows/` modelled on secret-scanning's hook | the 150-line SKILL.md — GitHub's hardening docs are canonical training data; the delta is that *nobody asks*, which a hook fixes and prose does not |
| Debt ratchet (code-review) | `debt-scan.sh` + `.claude/debt-baseline.json`, five categories (suppressions, skipped tests, TODO age via `git log -S --reverse`, deprecated-symbol references, flags past the removal date `rollout-planning:39` already tells authors to write and nothing reads back), `--check` non-zero on growth, `--update-baseline` to accept — the exact shape of `context-budget.sh` | the new skill AND the new command (`context-budget.sh:24-34` meters command descriptions in the same channel); ship a lane on the existing `/code-review:review` |
| Sweep migration (task-runner) | `sweep-residual.sh` + a `--sweep` lane on `/task-runner:run`: freeze the target set and its tree hash, enumerate in four passes (direct / aliased / dynamic / non-code carriers), committed batches, residual must strictly decrease and end at 0 or allowlisted-with-reason | the skill description — `approaches:opinion-round` already auto-fires on the word "migrate" and both plugins ship in four common bundles |
| Project conventions (code-review) | a PostToolUse hook emitting the resolved **paths** of `.editorconfig` / formatter / linter / pre-commit configs and the CI lint invocation | the skill, and critically the "three settings most often violated" digest — a distilled checklist injected before the model reads the source is the react shape that measured *negative*. Emit paths, say nothing about contents. Keep two rules only, as a reference: CI-invoked config is authoritative, and never add a second linter to a repo that has one |
| NoSQL (database) | the `guard.sh` branch: `deleteMany({})` / `updateMany({})` / `.drop()` with empty filter / `Scan` in non-script code → `permissionDecision: ask`, same file, same fail-open contract | the whole skill — access-pattern-before-key-schema is the most-recited material in the domain and the proposal conceded it was a prediction, not a measurement |
| Licence (packages) | `licence-scan.sh` + the `.licence-policy.json` schema + a lane on `/packages:audit`. Its one genuinely non-baseline fact is a **measurement**: `plugins/shadcn-studio/template/package-lock.json` has 170 entries, 12 of them MPL-2.0, **none in package.json** | the SKILL.md, and the claimed vocabulary reuse — craft-layer's licence token set is six asset classes with **no copyleft class at all**. **Standing must be `recorded`, not `gate`**: exit-2 fires only against a policy file nobody writes, so the reachable path for most users is exit-3 |
| Flake-hunt (testing) | `/testing:flake-hunt` + `flake-hunt.sh`: N runs across fixed and randomized order with varied seeds, set-diff to **classify** (order-dependence vs time/network vs leakage), quarantine list with first-seen commit, `--baseline` mode | nothing — `testing-best-practices:101-109` already lists the root causes and their fixes; the plugin just cannot produce the evidence that selects between them |
| pgvector (postgresql) | `references/pgvector.md`: opclass must match the embedding metric (an HNSW index built `vector_l2_ops` is silently unused by a `<=>` query), `hnsw.ef_search`, pre- vs post-filter recall collapse on tenant-scoped ANN, halfvec vs the 2000-dim ceiling, model change = backfill | — |
| Expo (react-native) | `references/expo.md` + `app.json`/`eas.json` `rules.tsv` rows guarded on `package.json~"expo"`. Narrowed to the two version-leverage facts: from SDK 55 New Architecture is always on so `newArchEnabled: false` — the standard 2024/25 remediation a model still emits — is a **no-op**; and CNG/prebuild overwriting hand edits | the skill (react-native is 58 tokens, the second-cheapest leaf; a description would double it) |
| design-preview beyond React | Vue/Nuxt branch (the extra-HTML-entry trick transfers unchanged) + a Laravel Blade branch (it does **not** transfer — PHP owns routing, so it is a scratch route + `@vite` on a scratch Blade view). `craft-layer/README.md:3-5` advertises Vue/Nuxt/Laravel and routes option-drawing to two React-only tools | — |
| Document analysis (ultra-deep-research) | the **coverage manifest** only — sections/pages read, sections NOT read, why; page-anchored citations; a "this document does not say" list kept separate from "says the opposite" | the truncation claim (the Read tool states its own 20-page cap in every turn's schema) and the over-claiming-discipline rules (`SKILL.md:60-62` already encodes them for web sources) |

### New items no lens owned (from the completeness critic)

| Item | Evidence | Tier |
|---|---|---|
> **Landed 2026-08-02.** Three of the critic's items, plus the host-overlap
> deferrals P1's gate could not write:
>
> - **`everything` token ceiling** — `ALWAYS_ON_CEILING=12600` and
>   `DYNAMIC_CEILING=2600` in `context-budget.sh`, failing the build when the
>   aggregate is exceeded. `--update-baseline` does NOT move them, which is the
>   whole point: the per-plugin ratchet is a convenience, this is a budget, and
>   raising it is an edit someone reviews. Negative control run. This is the only
>   version of "new surfaces name their funding deletion" with teeth.
> - **Release contract** — `check-version-bumps.sh` now checks changelog coverage,
>   `gate` for plugins that have a `CHANGELOG.md` and `WARN` for those that do not.
>   Split for the same reason the version stamp was: hard-for-everyone today means
>   ~58 backfilled changelogs describing releases nobody recorded. `code-review` and
>   `devops` ship worked examples; a stale entry fails, verified by control.
> - **Host-overlap deferrals** — the substantive half `pc_host_overlap` cannot
>   reach, since it only catches NAME collisions and there are none.
>   `security:security-review` now states its boundary with the host
>   `/security-review` command; `code-smells` with the host `simplify`;
>   `real-preview` with `claude-in-chrome`; and `claude-authoring`'s README with
>   `skill-creator`, including the row that matters most — the host ships a working
>   control/treatment eval loop with a blind comparator, so **do not build a second
>   one**. This marketplace's contribution is the doctrine and the ledger, not the
>   runner.

| **Release contract for consumers** | 0 git tags; 0 of 58 leaves ship a `CHANGELOG.md` although `validate.sh:131` allows it and `check-version-bumps.sh:38` already excludes it from forcing a bump; every leaf is 0.x; the bump gate runs only on `pull_request`, so master pushes are exempt. A user upgrading `laravel` 0.3.1 → 0.4.0 has no artifact naming what changed. Cheapest teeth: extend `check-version-bumps.sh` to require a matching CHANGELOG entry whenever it demands a bump | P1 |
| **Disclose the third-party MCP server inside `everything`** | `registry-source/.mcp.json` declares `reui` as an HTTP server at `https://mcp.reui.io` alongside the local node server. `registry-source` is a dependency of `everything`, which `README.md:10` recommends for "zero-setup convenience", with a metered baseline of **0** and no column for network egress. This is the marketplace's only outbound third-party runtime dependency and no lens — including the supply-chain one — opened a `.mcp.json` | P1 |
| **README strategy honesty** | `README.md:3` claims coverage "from React and Vue to Laravel and beyond". The evidence says "and beyond" is false: `rules.tsv` is PHP/Blade/Laravel/Livewire/Inertia/React-shaped, the one backend worker ships from `laravel`, neither scout detects a non-JS/PHP manifest, 4 SQL plugins and 0 NoSQL. One edited sentence; the cheapest honesty fix in the repo and the one the four laws most directly demand | P1 |
| **An `everything` token ceiling** | `context-budget.sh:127-131` says of itself: "It does NOT bound aggregate drift… the ratchet is per-plugin". Bundle tolerance is 2× member count, so `everything` may drift 116 tokens per run silently, and `--update-baseline` rewrites the baseline on demand. ~5 lines: a declared ceiling that fails the build, so every new leaf must be paid for by a deletion instead of by a baseline update. This is the only version of the funding-deletion rule that has teeth | P1 |
> **Audited 2026-08-02 — `rationale/web-dev-brain-audit-2026-08-02.md`. Both
> nominations fail, and one inverts.**
>
> `web-dev` has **12 inbound references from 10 plugins**: it is the resolved
> worker for the `frontend` and `api` tags in task-runner's routing map, the
> verify-side reviewer for `frontend`, and the apply-chain head in nine chassis
> review commands. `generate.sh` hard-errors when a stamped worker has no agent
> file, so deleting it does not degrade those chains — it breaks the generator.
> Zero skills is the CORRECT shape for a plugin whose whole job is to be a
> dispatch target; a description would only compete for a trigger it does not want.
>
> `brain` is genuinely low-connectivity (2 references, neither a real caller) but
> costs 89 always-on tokens — fourth-cheapest leaf — and its SessionStart hook
> emits 0 bytes in a sandbox, ~60 in a repo with no map. It is not redundant with
> the host `init` (which writes `CLAUDE.md`, instructions) or with `hindsight`.
> Keep; the residual is that nothing routes to it, which is a routing fix.
>
> **The instrument was wrong, and that is the finding.** The nomination came from
> a skill-count heuristic applied without checking the graph, and for `web-dev` it
> inverted the truth. The same blind spot hid all three skill-less plugins
> (`web-dev`, `brain`, `registry-source`) from this review's own 40-domain
> taxonomy. The deletion question is therefore still open: `terse` (886),
> `craft-layer` (1,025), `taskmaster` (931) and `approaches` (581) hold 3,423
> tokens between them and none has been through the baseline loop. That is where
> a cut argument can be made from evidence — `scripts/retirement-queue.sh` and the
> two ledgers now exist for exactly that.

| **Audit `web-dev` and `brain`** | The two plugins with zero skills, therefore invisible to every skill-shaped lens and absent from all 40 taxonomy rows. `web-dev`: 2 agents, 0 skills, 0 commands, a name claiming the whole territory. `brain`: 1 agent, 1 command, a SessionStart hook, 0 skills, overlapping the host `init` and hindsight with no deferral in any direction. These are the two concrete answers to "the backlog contains no deletions" | P2 |
| **MCP as claude-authoring's missing fifth extension point** | `authoring-plugins/SKILL.md:13-16` enumerates four (skills, agents, commands, hooks); the only "MCP" string in the plugin is `authoring-agents/SKILL.md:101` telling you not to give agents MCP tools — while this repo ships one | P2 |
| **Time/timezone and multi-tenancy** | `grep -rIlE 'timezone\|DST\|UTC offset' plugins/` = 0 files; `grep -rIl 'multi-?tenan' plugins/` = 0 files. Both schema- and code-anchored, both top-tier production bug sources, neither named in any taxonomy row or the rejected list | P2 |
> **Landed 2026-08-02** — the two remaining critic items that could be built
> without a deletion decision:
>
> - **`rationale/measured-zero-shapes.md`** — the four SHAPES that measured zero
>   (per-version idiom maps, canonical-doctrine checklists, style-rule catalogues,
>   framework restatement), with the numbers, plus what has NOT measured zero so
>   the file does not read as "never write anything". `pc_removed_refs` gates the
>   removed NAMES and structurally cannot see a new proposal wearing the same
>   shape — which is exactly how `python-best-practices` and `nosql-data-modeling`
>   reached this review's own synthesis before the refuter killed them. Cited from
>   `/claude-authoring:new-skill` step 6 and from `authoring-skills`, i.e. at the
>   moment a skill is proposed. Standing: recorded, and deliberately so — gating on
>   four fuzzy prose shapes is the false-positive class that gets a gate disabled.
> - **`scripts/retirement-queue.sh`** — ranks shipped skills against the two
>   ledgers M2 started writing. Always exits 0 and never proposes a deletion, and
>   the header says why in three parts: zero invocations proves nobody used it
>   HERE, non-zero proves it fired rather than that it helped, and "never surfaced"
>   mostly measures the ROUTER's coverage, since 102 of 126 skills have no
>   `rules.tsv` row. It answers where a control/treatment run is worth spending —
>   the question that has gone unanswered since the doctrine's only eight removals
>   in July 2026.
>
> Two bugs found by running it, both the subshell class that has now appeared
> three times today: `grep -c` printing `0` AND exiting 1, so `|| echo 0` produced
> `"0\n0"` and every later arithmetic test aborted; and a counter incremented
> inside a `while` piped to `sort`, which never survives the subshell — the same
> trap that made the dynamic context meter read zero this morning.

| **A retirement lane** | The doctrine's method has produced 8 removals total, all on 2026-07-27, none since, while 126 skills / 42 plugin-shipped scripts / 16 hook-bearing plugins have never been tested against it. Keyed on M2's telemetry: any skill with zero `fired[]` events across N sessions enters the control/treatment queue automatically. Without it the evidence base freezes at eight rows while the surface it governs keeps growing | P2 |
| **A "measured-zero shapes" list** | `pc_removed_refs` blocks the removed *names* (typescript, vue2, react-best-practices…) but an author proposing `python-best-practices` or `nosql-data-modeling` trips nothing — which is exactly what happened at two ranks of this very backlog. A list of shapes that measured zero (per-version idiom maps, canonical-doctrine checklists, framework restatement, style catalogs) beside the ledger, cited from `/claude-authoring:new-skill`, would have pre-empted both without an eval run | P2 |
| **A discrimination dimension in the description linter** | `context-budget.sh` meters what a description costs; `validate.sh`'s linter checks length and forbids "Trigger words:". Neither checks the property that predicted every removal — whether the trigger clause discriminates. The prior review's §2 axis L sampled 10 skills, found 4 non-discriminating, produced two folds, and the axis was never mechanized | P2 |

---

## 4. Killed, with the refutation

| Proposal | Refutation |
|---|---|
| **A `python` plugin** | Killed by two independent refuters. Two of its three seedable deltas are baseline (a 2026 model writes timezone-aware datetimes; a model that sees `uv.lock` uses uv — asserting otherwise is a forgetting claim). The third — "advise at or below `requires-python`" — is delivered verbatim by W2 at zero tokens. The per-version leverage section is the exact idiom-map shape that measured **0 delta twice** (typescript 5/5, javascript 7/7, control finding EXTRAS both times, both plugins removed whole). Price: `validate.sh:169-181` makes every leaf a **mandatory** permanent raise of the always-on floor for every `everything` user, ~120 tokens at the measured average. |
| **A house eval harness (`scripts/skill-eval.sh` + fixtures)** | The host `skill-creator` skill already ships it as working code — **verified on this machine**: `scripts/run_eval.py`, `aggregate_benchmark.py`, `improve_description.py`, `quick_validate.py`, `package_skill.py`, plus `agents/comparator.md` ("Compare two outputs WITHOUT knowing which skill produced them"). The proposal's own argument was "a blind model asked for an eval harness builds a new framework" — and then it built one. This marketplace has an explicit twice-instantiated rule against exactly this (`information-design/SKILL.md:97-100`, `:147`; `deep-staging/references/dataviz-cheatsheet.md:3-5`; llm-app deferring to `claude-api`). **What survives, at effort S:** a `validate.sh` check that any `plugins/*/skills/<name>/` directory absent at the base ref must have a parseable row in `rationale/skill-evals.jsonl` — and the operator loop it gates reads "run the host skill-creator eval loop and record the verdict", not "run ours". It must gate on the **verdict**, not on the row existing: a gate that passes a row recording delta=0 is paperwork, and under the doctrine delta=0 means the skill must not ship. |
| **Bundle-closure assertion (mode 3 of W1)** | Both remedies are bad. Declaring the dependency is a direct unbounded raise of metered cost on precisely the bundles that exist to be cheap (process-suite +225, frontend-suite +131). Writing "if installed" is satisfied by a comment and fixes nothing — process-suite's actual defect (every done card exempted `no-reviewer-installed`, because `reviewer-routing.md:13` makes `code-review:code-reviewer` the unconditional ALWAYS reviewer) survives a degradation clause untouched. And the incentive is backwards: `everything` satisfies closure trivially, so the gate's only bite lands on the small curated bundles the README recommends. **The underlying defect is real and needs a targeted fix, not a graph gate.** |
| **An eval-harness skill in llm-app** | The genuine finding is a **deletion**, not an addition: `llm-app` ships exactly 5 files while its `SKILL.md:24` promises "Regression-gate — run the eval set on every prompt/model change" with no artifact behind it. That is a straight honest-limitation violation. Fix: delete the claim, or ship `template/` alone with no new description. |
| **HTML-email skill + `email-lint.mjs`** | The premise is probably false and is stated as fact — the table-layout + inline-CSS convention *is* the dominant pattern in the email corpus, so a control asked for a transactional email likely emits it, and a lint that runs green forever is theater. Cost: ui-ux is 586 tokens and sits in three bundles. **What survives:** a `references/` file under ui-ux carrying the three non-baseline facts — the Gmail ~102KB clip threshold, the `[data-ogsc]` dark-mode fork, and the structural point that the agent's own browser preview cannot render the Word engine. |
| **PII data-inventory scanner** | The scanner is *strictly worse* than a blind model at the detection half, and its own honesty section proves it: the declared blind spots (JSONB, free text, hashed columns, **domain-language names**) are exactly where a model wins by reading semantics. A model catches `applicant_notes`; a regex catches `email`, which the model also catches. **What survives:** the `data-inventory.yml` schema plus a CI ratchet against `data-privacy/SKILL.md:15-18`'s currently unenforced requirement. |

**Rejections the refuters overturned** — do not treat these as closed:

- *"Every review command dies in chat"* was rejected as premise-false. It is directionally right: **three** apply picks name no dispatch target, not one (§3 W4).
- *A monorepo (Turborepo/Nx) plugin* was rejected on the grounds that W2 covers it. W2 answers *which version is installed*; the proposal is about task-graph correctness, `outputs` misdeclaration silently poisoning a remote cache, and `nx affected --base` against a wrong base ref. Repo-wide grep for `turborepo|turbo.json|nx.json` returns **zero** functional hits. Reopen on its own merits; the refutation does not cover the claim.

---

## 5. The decision this blocks

> **Decided 2026-08-02 by the marketplace owner:**
> 1. **First lane: P0 measurement and honesty** (M1–M6).
> 2. **Strategy: sharpness for leaves, breadth for reference files.** No new
>    language or platform plugins; `README.md:3`'s "and beyond" gets rewritten.
> 3. **Consumer-side script gates: accepted.** The supply-chain, licence, debt
>    and flake items may ship a script whose exit code protects the user's repo.
>    M3 stays a hard prerequisite so their fixtures actually run in CI.

**Breadth vs sharpness, with its real prices.**

- **Sharpness:** rewrite `README.md:3` to say what the repo already is — a deep
  toolkit for PHP/Laravel + JS/TS web + relational data + the engineering
  process around them — and treat W6 as the permanent answer to everything
  else. Price: the one-stop-shop framing dies; a user arriving with a Python
  service or a data pipeline is told "not here, try skills.sh". Benefit: the
  floor stops growing, every gate covers a smaller surface, the claims become
  true.
- **Breadth:** build the language and platform leaves. Price: `validate.sh:169-181`
  makes each one a mandatory permanent addition to `everything`; the
  gates-to-skills ratio worsens with every leaf; and the audience evidence is
  unambiguously against it.
- **The honest middle, and the recommendation: sharpness for new leaves,
  breadth for reference files and existing-plugin skills.** W2, W6 and the P2
  reference files give Python, Go, Rust, JVM, .NET, SvelteKit and pgvector
  partial coverage at **zero metered tokens**. That is breadth without
  dilution, and it is available now.

Four further decisions only the owner can make:

1. **Where does written-artifact prose live?** A new `prose` leaf (~200 tokens
   plus a mandatory `everything` entry) or a second skill inside
   `comment-discipline` (107 tokens, already owns `hooks/verbosity.sh` and
   therefore already owns the over-writing problem)? `terse`'s own contract
   explicitly excludes file content, so amending terse weakens the one
   guarantee it exists to give — that host is ruled out.
2. **Will the marketplace accept script gates that run in the *user's* CI?**
   The supply-chain, licence, debt and flake items all ship a script whose exit
   code protects the consumer's repo, not this one. Yes multiplies enforcement
   mass; no demotes four of the strongest proposals to prose.
3. **How much is the tier-1 exemption worth defending?**
   `stack-skill-baselines.md:40-44` keeps ~20 leaves untested on a promise
   that `:50-53` admits was never exercised. W5 makes staleness visible but
   freshness is not the claim under dispute. The cheapest real defense is three
   manifest-bearing fixtures — one Laravel/PHP, one Next.js, one SQL dialect —
   through the host eval loop with a lockfile pinning an off-default version.
   One afternoon, and it appears at no tier in the original backlog.
4. **Is the owner willing to pay for new surfaces by deleting old ones?**
   Four never-tested plugins hold 3,423 tokens — 30% of the leaf floor:
   `terse` (886; 12 metered leaves for a capability that changes no file on
   disk by its own contract), `craft-layer` (1,025), `taskmaster` (931),
   `approaches` (581). Plus `web-dev` and `brain` (§3). A backlog that never
   names a candidate for removal is a wishlist.

---

## 6. Method, and what it did not do

- 17 agents: 10 domain lenses (blind, one cluster each), 2 synergy audits
  (composition, discovery), 1 synthesis, 3 blind refuters with distinct lenses,
  1 completeness critic. Fan-out counts were ceilings sized to blast radius.
- Every lens was given the same house doctrine — `stack-skill-baselines.md`,
  the context-budget gate, the has-teeth convention, the prior review. **That
  shared framing is a bias**: the doctrine pushes hard toward "do not build",
  which is enforced against additions and not at all against what already
  ships.
- **Nothing was executed by the fan-out.** Thirteen agents read the repository
  and none ran it. The four numbers that most change the conclusions — the
  9,461-byte router injection, the 1,936-byte MCP tool surface, the 697-byte
  unconditional terse injection, the host `skill-creator` scripts — took four
  bash calls in the main thread afterward, and they invalidated the cost model
  20 proposals were priced against. A "run the artifacts" lens should be
  standard in any future pass.
- **Closed-world framing.** Every lens compared `plugins/` to `plugins/`. The
  host skill roster sat in each lens's own context the whole time and was never
  enumerated; `~/.claude/plugins/cache/` was never opened. This machine has 6
  marketplaces cached, so every collision and token argument here assumes an
  install profile that is not the author's own.
- **The shared inventory summary was itself unaudited**, and it was
  skill-shaped: the two plugins with zero skills (`web-dev`, `brain`) and the
  one with zero skills and zero commands (`registry-source`) fell through every
  lens's field of view. All three are in `everything`.
- No user was consulted, no usage data existed, and no plugin was behaviorally
  tested. Every "what a blind control would miss" in §3 is a **prediction**,
  not a measurement — which is precisely why M2 and the surviving admission
  gate are ranked where they are.
