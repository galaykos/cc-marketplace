# Plugin landscape comparison: all 42 plugins against outside peers, 2026-10-31

**Question:** for each plugin in this marketplace, what do the closest outside skills, plugins and
MCP servers do? Where is ours better, what is missing, and what should be improved? This was run
with the `skill-creator` review lens (triggering, progressive disclosure, explaining why, bundled
scripts, evals). Branch `review/plugin-landscape-comparison`, base `master` at `9d8c167f`, CLI 2.1.316.

**Standing: `recorded`.** Nothing reads this file back. No item below is built.

**How it differs from `landscape-ux-dx-ax-2026-10-26.md`.** That file went repo by repo and picked
50 repos for workflow ideas. This one goes plugin by plugin: each plugin is held against its own
nearest peers. Every item of `improvement-plan-2026-10-26.md` has shipped (commits
`3a922fa1..09c68d76`), and nothing here proposes it again.

## How it was done

- Seven researcher agents, one per cluster, each covering 4 to 9 plugins. Each read our plugin files
  first, then grepped `rationale/` for a prior verdict on each peer, then searched GitHub,
  skills.sh, vendor docs and `claude-plugins-official`. The returns hold about 220 peer rows.
  Peer files were read through `gh api` or shallow clones under `/tmp`, and no peer code was run.
- The per-cluster returns are machine-local and gitignored:
  `taskmaster-docs/plugin-landscape-2026-10-31/{A..G}-*.md` (about 3,500 lines) and `00-metrics.md`.
  Every cell below is condensed from those files, which hold the peer URLs, stars, licences and
  line citations.
- **Verdicts.** **ADMIT** means it clears the README bar (`README.md:8-12`): a rule the model gets
  wrong from memory, or a mechanism prose cannot replace. **SKIP-model-knows** means the base model
  already does it. **ROUTE** means point users at the tool and copy nothing.
- **Trust labels.** **(V)** means the main thread re-checked it this session, by reading the line or
  running our hook on a test input. Everything else was reported by a researcher. Each peer number is
  the author's claim.
- `gh search` hit its rate limit for several researchers, so some discovery fell back to web search.
  **No eval was run.** Every "the control would likely fail" is a prediction.

## What changed in the landscape

1. **Vendors now ship their own agent skills.** Epic (a Claude Code plugin in `claude-plugins-official`
   plus the UE 5.8 MCP), PixiJS (a marketplace plugin synced per release), Phaser (28 in-repo skills),
   Unity (an agent plugin plus a CLI; its MCP server is deprecated), MUI, shadcn, Laravel Boost,
   docker/skills, HashiCorp, Expo and Prisma. For those stacks our value is now the **delta over
   the vendor**: silent inversions the vendor docs leave implicit, plus offline checkers. Only an eval
   with a vendor arm can show that delta.
2. **Mechanism density is still our edge.** The most-starred peers (superpowers, mattpocock, ECC,
   addyosmani, wshobson) are mostly prose. flow-next is the one small peer with comparable mechanism.
   Most "Better here" cells below are a script, hook or gate a peer lacks.
3. **Host built-ins overlap plugins that never name them.** `/insights` (hindsight), the 30-day
   `cleanupPeriodDays` transcript deletion (hindsight), `/skill-doctor` (all-plugins), `/usage` and
   `/context` (session-hud), `/goal` (overseer, ask-ledger), and the skill `paths:` frontmatter
   (skill-router; already measured in `authoring-skills/references/activation-fields.md`: reach only). **(V)** No SKILL.md sets `paths:`, and hindsight mentions neither `/insights` nor
   `cleanupPeriodDays`.
4. **Our own shipped text has wrong facts and stale stamps** (next section). Most were caught by
   reading a peer or a vendor page that disagreed.
5. **Measurement is thin.** 9 of 42 plugins ship evals. Few cases have a control arm that fails, and
   several bought cases have never been run.

## Wrong or harmful today (fix first)

| # | where | what is wrong | evidence | fix · size · standing after |
|---|---|---|---|---|
| 1 | `git-workflow/commands/clean-gone.md:35,39-42` | `git branch -D` on any `[gone]` branch. A remote branch deleted unmerged (a closed PR, a bot sweep), or a local commit made after the last push, is lost | (V) line read. Trail of Bits `git-cleanup` merge-evidence: "[gone] … says nothing about whether the commits landed" (CC-BY-SA, take ideas only) | classify each branch as `--merged`, content-merged (`git cherry`) or "work not found → review", as `scripts/gone-branches.sh` with fixtures · S-M · gate |
| 2 | `candor/hooks/gate.sh:686-689` | clause 3 ("done with nothing run") counts only Edit/Write as edits and treats every Bash call as execution. So code written by heredoc, `sed -i` or `python3 - <<EOF` never arms the clause, though `skill-router/README.md:31` measured 233 of 238 writes going through Bash | (V) line read | reuse the shared Bash-write blocks 8 hooks already source; harness cases; name the residual in the README · M · gate |
| 3 | `secret-scanning/hooks/patterns.tsv` | (V) the hook, run on test Write payloads, **allows** `const key = "sk-ant-api03…"`, `Authorization: "Bearer sk-ant-api03…"`, `GH_PAT=github_pat_…` and `const t = "github_pat_…"`. It **denies** `apiKey: "sk-ant…"` and `ANTHROPIC_API_KEY=…` (key-named field rows). The researcher also reports `sk-proj`, `glpat-`, `hf_`, AWS `ASIA`, `rk_live_` and `SG.` allowed. Redaction and the sweep read the same file, so they miss the same values | (V) hook run; gitleaks rules (MIT) | provider-prefix rows adapted from gitleaks, in the TSV's dialect; `scan-hook` plus parity harness cases · S-M · gate |
| 4 | `command-guard/hooks/destructive-guard.sh` | (V) allowed: `ls \| xargs rm -rf`, `find … -exec rm -rf {} +` (while `find -delete` asks), `git push origin :feature`, `gh api -X DELETE repos/o/r`. Also reported: per-file `checkout --`/`restore` on modified files, `reset --merge`, `switch -f`, `worktree remove --force`, `gsutil rm -r`, `.drop()`, `DROP COLUMN`, `UPDATE` with no `WHERE`, `firestore:delete --all-collections` | (V) hook run on 4; cc-safety-net rule IDs; dcg pack docs (dcg's licence bars copying) | one row and one harness case each · S each · gate |
| 5 | `command-guard/hooks/config-guard.sh:152-157` vs `lane.tsv:14` | the lane claims test and CI config coverage. The list omits `phpunit.xml`, jest/vitest configs, `.github/workflows/*`, pre-commit/lefthook/husky and `.git/hooks/*` | researcher, Edit payloads in a scratch repo | extend the list, or drop "CI" from the lane · S · gate |
| 6 | `web-dev/skills/nextjs-best-practices/SKILL.md:48-50` | the example is `export const revalidate = 3600; export const dynamic = 'force-static'`. From Next 16.4 (2026-10-06), `create-next-app` turns `cacheComponents` on, and segment configs then fail the build | (V) line read; nextjs.org "Migrating to Cache Components" (fetched by the researcher) | Cache Components branch (`'use cache'`, `cacheLife`/`cacheTag`), restamp 16.4, new eval · S-M · agent-graded |
| 7 | `database/hooks/guard.sh:325,409` | the lock-hazard remedy says "Use … CREATE INDEX CONCURRENTLY" on any non-SQLite project. That is Postgres-only syntax, and InnoDB already builds secondary indexes online. The plugin's flagship dialect is MariaDB | (V) lines read | engine-aware message (`ALGORITHM=INPLACE, LOCK=NONE`; Galera note) plus fixture · S · gate |
| 8 | `api-design/skills/api-design/SKILL.md:93` | "The same key with a different payload is a 409". IETF `draft-ietf-httpapi-idempotency-key-header-08` (an active Internet-Draft dated 2026-10-22, not an RFC; corrected from "-07, expired" when the fix was built) says 422; 409 is for a duplicate still in flight, and 400 for a missing key | (V) line read; draft fetched by the researcher | fix, cite the draft by revision, add the atomic-claim rule, seed an eval · S · agent-graded |
| 9 | `toolchain-experts/agents/php-expert.md:36-37`; `scripts/detect-analyzers.sh:36,114` | phpstan level reach is wrong: argument types are level 5, not 2. `.eslintcache` is reported as eslint's baseline, but it is a cache; the baseline is `eslint-suppressions.json`. `level: max` is unread | (V) lines read; phpstan and eslint docs fetched by the researcher | correct each, plus harness cases · S each · gate for the script |
| 10 | `unity/skills/unity-best-practices` (stamped 6000.3) | Unity recommends 6000.6.7f1. Since 6000.3: 6.4 removes URP Compatibility Mode (render graph only), 6.5 replaces `InstanceID` with `EntityId`, 6.6 auto-upgrades Cinemachine 2 to 3, removes UXML Factory/Traits, and makes `[SerializeField] Dictionary` serialize. `references/render-camera.md:34-39` still advises 2.x/3.x typing and running the Upgrader by hand | (V) line read; Unity 6.4/6.5/6.6 upgrade guides fetched by the researcher | `references/upgrades-6.4-6.6.md` routed on `m_EditorVersion`, plus one line on the 7000 alpha · M · recorded |
| 11 | `laravel` | missing Laravel 11 inversions: `->change()` drops every modifier not restated ("High" in the upgrade guide), Carbon 3 `diffIn*` returns signed floats, and the `mariadb` driver creates native UUIDs. `inertia-best-practices/SKILL.md:24` says "the `data-page` attribute", which is v1/v2 only; v3 uses `<script type="application/json">` | (V) grep finds no `->change()` or `diffIn`; line 24 read | add to `leverage-map.md` and mark 11 EOL; fix line 24; eval on `->change()` · S · recorded |
| 12 | `resilience/evals/timeout-and-retry/case.yaml:51-52` (also `breadth-review:67`) | the grader says "Laravel's default is no timeout". `PendingRequest` defaults to 30 s, with 10 s to connect, so the grader can reward a false claim | (V) line read; framework source read by the researcher | rewrite the grader text · S · agent-graded |
| 13 | `security/hooks/write-scan.sh:446-449` | the doc-file exclusion applies only when an extension group is passed, so five rows fire on `.md`, `.txt` and `.json`. The researcher hit it live while writing its return | researcher, live | apply the exclusion to all rows; add a `.md` silent case · S · gate |
| 14 | `task-runner/skills/task-execution/SKILL.md:169` vs `commands/run.md` | the skill says drift-review runs at close; `run.md` never calls it | (V) grep `drift` in `run.md`: 0 hits | invoke it and add a marker, or drop the claim · S · gate if a marker is counted |
| 15 | `task-runner/scripts/register-run.sh:81`; `code-architecture/commands/work.md:67` | `find ~/.claude/plugins/cache … \| sort -V \| tail -1` can pick an older copy or another marketplace's copy. `delegation-contracts` itself warns against this pattern, and in an installed plugin it is the path always taken | (V) lines read | one resolver (overseer's `skill-path.sh` logic) plus a two-marketplace fixture · S · gate |
| 16 | `ui-ux/skills/shadcn-theming/SKILL.md:101` | "the only script checker is craft-layer's `/craft-layer:audit`", but ui-ux ships `scripts/contrast.mjs` and `/ui-ux:theme` runs it | (V) line read | one-line fix · S · recorded |
| 17 | `design-kit/skills/system/references/tokens-format.md:3` (also README, `system/SKILL.md:128`) | calls DTCG 2025.10 a draft with "do not implement". The 2025.10 report is a Final Community Group Report (2025-10-28). ui-ux's own reference already says "first stable" | (V) line read; designtokens.org fetched by the researcher | relabel, then optionally `--dtcg-strict` emit · S · recorded |
| 18 | `stack-scan/skills/plugin-scout/references/official-complements.md` | the Boost row lists the app-info MCP tool, removed in Boost v2.10.4 on 2026-10-29. Missing rows: `expo@claude-plugins-official`, the HashiCorp Terraform skills plus the official MCP, Prisma 7 and Apollo | Boost CHANGELOG and the official `marketplace.json`, read by the researcher | refresh; add a snapshot test of official names · S-M · recorded (gate if snapshot) |
| 19 | `craft-layer/skills/ultra-craft/SKILL.md:105` | cites `.claude/skills/authoring-skills/SKILL.md (in the marketplace repository)`, a path installers do not have | (V) line read | drop or inline the one-line law · S · recorded |

## Per plugin: better here, missing, do next

"Missing" lists only ADMIT items. Sizes are S, M or L. Standing is what the change would have once
built. Item ids (T1, GW-1, cl2 …) point into the cluster files.

### Task pipeline (cluster A)

| plugin | better than peers | missing (ADMIT) | do next |
|---|---|---|---|
| taskmaster | A spec cannot be written while the ledger holds an UNKNOWN row (script). Cards linted with exit codes. A blind opus spec adversary. A hands-off floor that never auto-takes security, auth or data holes. No peer (spec-kit, superpowers, BMAD, Kiro) has these | Cross-card Consumes/Produces check before dispatch (superpowers preflight). Placeholder and vague-criterion lint (spec-kit `analyze`). A write guard while the spec is being shaped; superpowers' release notes report prose leaking 24/24 → 3/24 | **T2** shape-phase write guard on the phase sentinel; today `brainstorm.md:43` calls the rule `unenforceable` (V) · M · gate + lane row. **T1** `card-set-lint.sh` · M · gate. **T3** placeholder lint · S · gate. **T5** first eval (contradicted statement) |
| task-runner | Per-card negative control. A behavioral gate that refuses an empty suite. The executor has no Agent tool, so it cannot spawn reviewers. A scope tripwire that sees Bash writes | Post-run spec convergence: missing / partial / contradicts (spec-kit `converge`, flow-next). Scoped re-review of only the fixed finding (superpowers fix-loop) | **R1** `coverage-close.sh`: name the criteria whose cards parked · S-M · gate. **R3** path resolver (wrong-today #15). **R5** drift-review claim (#14). **R7** the description's "a todo list" registers a run, an overtrigger with side effects · S. **R4** `plan-levels.sh` · M · gate |
| overseer | Acceptance is a script with a Read ledger. Dispatch prompts are gated. Divergent branches are refused at close. The only plugin in the cluster with a measured delta (+1 on both cases, one run each) | Hands-off continuation held by the host's `/goal`, which addresses "stopped after m1 of 3" (`CHANGELOG.md:256`). A token budget stop | **O1** print the `/goal …` line on `--hands-off` · S. **O2** `--budget-tokens` checked in `dispatch check` · M · gate. **O3** re-run evals at `runs: 3`; fix `tests-as-acceptance`, whose with-arm never loaded the body |
| code-architecture | The evidence rule has teeth where candor is installed. drift-review hands its reviewer a diff with blame. `/work` triage. A designed control case (`solid-control`) | A deterministic trigger and collision corpus in CI (addyosmani tier 2) | **C1** run `solid-control` (`--runs 5`); it decides whether the ten checklist skills earn their place · S. **C2** trigger corpus + collision check · M · gate. **C3** drift-review reuses `review-diff.sh` · S. **C4** the quick-fix cases likely pass in the control; add one trap case |
| approaches | Blind lenses by contract. One deliberation per task, with a marker and a compaction hook. A kill-trigger is required. Briefs are linted for leaning | A cross-family second opinion behind consent. Three peers converge on it (ECC council-multi-model, PAL consensus, flow-next), and `/advisor` cannot provide it | **A1** measure consult against a plain session · M. **A2** opt-in `consult-external.sh` (codex/gemini CLI, per-consult consent, "same family" label) · M-L · gate on refusals. **A3** pattern-selection decoy eval. **A4** marker writer script · S · gate |

### Review and quality (cluster B)

| plugin | better than peers | missing (ADMIT) | do next |
|---|---|---|---|
| code-review | Quote check with an exit code; `incomplete` beats "clean". The false-positive taxonomy keeps a linter-class finding when CI does not run the linter (the official command drops it). Write-time comment denies, measured at 0 false positives on about 16.6k files. Debt ratchet | Refutation in a fresh context, one validator per finding (official `code-review` step 5). Running a mutant instead of grepping tests (addyosmani). Nested CLAUDE.md scoping | **CR-1** `comment-discipline` body is 197 lines / 13,959 B (V), so one more line fails the gate; move the enforcement wall to `references/` · S. **CR-2** ablate the Fowler smell pass every review walks (shape 2) · M. **CR-3** fresh validator · M. **CR-4** mutant via `negative-control.sh` when task-runner is present · M. **CR-6** eval |
| debugging | A stuck-loop hook and a fail-twice mod. Honest outage handling ("label the symptom fix"). The investigation is dispatched to an agent | Error, log and trace text is untrusted data; an embedded "run X" is quoted to the user, never run (addyosmani) | **DB-1** ask on `git commit` when staged lines hold `[DEBUG-`; the skill says "no hook runs the grep" · S-M · gate + lane row. **DB-2** untrusted-output line · S. **DB-3** red proof via TS-3. **DB-4** outage-pressure eval |
| testing | Fake-green deny (skip/only markers, emptied test files). Test-shape warning. Flake classification with a baseline ratchet | A replayable shuffle seed. Polluter bisection. Red proof on the reverted fix as a script. (Strict TDD gate: ROUTE to probity; ours was declined) | **TS-1** record seeds and print the replay command; verify each runner's seed flag first · S-M · gate. **TS-3** `red-proof.sh` · M · gate. **TS-2** `--bisect`. **TS-4** ablate `testing-best-practices` (shape 2) |
| toolchain-experts | Reports which tool CI actually enforces (script chains to depth 4). Baseline before the run. With no analyzer it stops instead of reciting a checklist | Effective config from `tsc --showConfig` / `eslint --print-config` instead of grep. A never-regenerate-the-baseline rule | **TC-1..3** wrong-today #9 · S. **TC-5** baseline rule, and hand baseline files to config-guard · S. **TC-4** resolver mode · M · gate. **TC-6** eval |
| git-workflow | AI-trailer deny. Merge waits for CI. Receipt reuse. Review passes before any destination. The default branch is PR-only. Lockfile-faithful worktree setup | Merge evidence for gone branches (#1). Reading PR inline review threads: `gh pr view --json comments,reviews` omits them and `gh api …/pulls/N/comments` has them (researcher, gh 2.46.0, one PR). Reviewer and bot text is untrusted. An ask on `--no-verify` / `core.hooksPath=`, which no plugin covers (grep) | **GW-1** (#1). **GW-3/4** thread recipe plus the untrusted rule · S. **GW-5** `--no-verify` ask; settle the lane with command-guard · M · gate. **GW-7** gone-unmerged eval. `branch-completion` is at 197 lines (V) |

### Security and safety (cluster C)

| plugin | better than peers | missing (ADMIT) | do next |
|---|---|---|---|
| security | Wraps the host `security-review` and adds a version pin, audit folds, the secret sweep and a self-refute. Write-scan sees Bash writes; security-guidance's pattern hook does not. Stack rows the official set lacks. Nothing leaves the machine | Project-local additive patterns (security-guidance `extensibility.py`, Apache-2.0). Go shell-string exec (measured silent). A Semgrep fold when it is on PATH | Raw SQL past `whereRaw` (`DB::select`, `*ByRaw`, Python f-string `execute`, JS template `query`) · S · gate. Go, Ruby and Java shell-exec rows · S · gate. `write-scan.sh --scan <path>` for `/security:review` · S-M · gate. #13 · S. A Livewire `#[Locked]` eval. Measure or demote api-auth, data-privacy and threat-modeling (shape 2) |
| secret-scanning | Deny before disk, including heredoc and echo writes. Redaction across tool output, `@`-mentions and the prompt box. One pattern file with a parity harness. Invisible-character scan | Modern provider prefixes (#3). A staged scan on `git commit`/`push` (agent-guard): `scan-range.sh --cached` exists and no hook calls it. Invisible characters in WebFetch, Grep and MCP output. Bash reads of `~/.ssh`, `~/.aws`, kube/docker/gh config, `.netrc` | #3 · S-M · gate. Commit/push gate · M · gate + lane row. Stop the skill restating `patterns.tsv` (`SKILL.md:18-33`) · S. A narrower exit for the false refusal on a quoted mask marker (seen live) · S · gate |
| command-guard | Framework schema resets on the deny tier (artisan, prisma, rails…). Decisions by state, not spelling. No bypass the agent can type (dcg has `DCG_BYPASS=1`). `onFailure: block` plus a 12 s ask. MCP shell and SQL tools matched | #4 and #5. Script bodies one level deep (`npm run x`, `composer x`, `make t`, `bash x.sh`), the plugin's main `unenforceable` row (dcg extractors) | Rows for #4 · S each · gate. #5 · S · gate. Resolve script bodies one level · M-L · gate. Ask on `--no-verify` here or in git-workflow (one lane) |
| resilience | Vendor-agnostic in-code rubric routed by concern. Findings labelled measured or suspected. The only replicated ablation in the repo (30 runs). An inverted liveness rule with a case written to fail the control | Verifying that a signal actually emits: `observability-engineer` has no operating procedure section at all | Run `liveness-probe-dependency` (5 runs per arm, about $3.40) · S. #12 · S. Give `observability-engineer` its procedure through `.chassis.json` · S. Handoff to laravel: the queue `retry_after` must exceed the job `$timeout` (0 hits in `plugins/`) |

### Backend, infra and stack (cluster D)

| plugin | better than peers | missing (ADMIT) | do next |
|---|---|---|---|
| api-design | One RFC 9457 error shape. 404 when existence is the secret. A spec-first scaffold with a FormRequest↔schema round-trip diff. api-docs-first returns a blocking finding instead of guessing | #8. Breaking-change detection as an exit code: ROUTE `oasdiff breaking --fail-on ERR` and `buf breaking` | #8 plus an `idempotency-mismatch` eval · S. oasdiff route in `/api-design:review` · S (gate if wrapped). Name Next's bundled `node_modules/next/dist/docs/` and Boost's `search-docs` in api-docs-first · S |
| database | A real write-time guard: DROP/TRUNCATE, ten ORM DSLs, NoSQL empty filters, lock hazards, `down()` exempt. MariaDB divergences and Galera vocabulary no peer has | #7. Migration-linter routes (squawk for Postgres, strong_migrations for Rails) | #7 · S · gate. Route squawk/strong_migrations from the review path · S. Add no Postgres or RLS content (measured zero); route vendors through stack-scan |
| devops | Two deny-class workflow shapes blocked at edit time. `plan-audit.sh` exits 2 on a stateful destroy and reads `prevent_destroy` from source. compose-init derives every service from evidence | A YAML-aware Actions analyzer: ROUTE zizmor (MIT, about 40 audits), which covers the residuals `workflow-audit.sh:19-22` admits. `COPY --link` with a numeric `--chown`; distroless healthcheck sidecar (docker/skills) | zizmor route in `/devops:review` · S (M as gate). Two docker lines, measured first · S. Leave Kubernetes alone |
| laravel | Inertia SSR silent fallback with a curl proof. The v2→v3 break table. Starter-kit facts. Live version pins through stack-scan; Boost renders at install time | #11. Boost now installs project skills named `laravel-best-practices` and `testing-best-practices`, which load beside ours under the same names | #11 · S. A Boost-aware README; ablate our generic sections (N+1, FormRequest, policies) and keep the version gates · M. Move the v2→v3 table to `references/` (`inertia-best-practices` is at 193 lines (V)) · S |
| web-dev | The 14→15 caching inversion (a peer still teaches the 14 model). Server-action and `redirect()`-in-try traps. Expo inversions only. A reviewer that names frameworks it has no vocabulary for | #6. Stale RN/Expo: SDK 58 is current, 0.84 removed legacy-architecture components, 0.87 floors, the Hermes V1 regression pin, Android 16 KB alignment (`zipalign -c -P 16`). Vite 8 key renames | #6 plus `cache-components-isr` eval · S-M. RN/Expo refresh · S. Retire `evals/astro-removed-apis` (control 5/5, a stack web-dev does not ship) · S |
| stack-scan | Live per-load version pins that say "newer than" as well as "older than". A licence lane by distribution mode with an exit-3 "unresolvable". Explicit-pick third-party installs with a SkillSpector vet | #18. Detection of dependencies that ship their own `SKILL.md` in `node_modules` (`npx skills experimental_sync`: print it, never run it) | #18 · S-M. Vendor-skill detection in `scan.sh` · M · gate. `plugin-scout` is at 196 lines / 13,398 B (V); move the tier-1 table to `references/signals.md` · S |

### UI and design (cluster E)

| plugin | better than peers | missing (ADMIT) | do next |
|---|---|---|---|
| ui-ux | A Stop check for UI changed and not seen in a browser. `contrast.mjs` with exit codes and an honest "not measured". Silent Tailwind v3→v4 renames. A shadcn base check backed by a corpus figure. WCAG criteria default builds miss (marquee case: control 3/5, with plugin 5/5) | Read project facts from `npx shadcn@latest info --json` instead of inferring from the style prefix, and name the official shadcn skill that co-fires on every `components.json`. An axe run for a ui-ux-only install. `color-scheme` on the root for native controls in dark mode | **ui3** run the two bought cases (`design-tokens-control`, `a11y-older-criteria`, about $3 each). **ui5** CLI first · S. **ui6** axe twin · M · gate. **ui4** `contrast.mjs` reads HSL and hex · M · gate. #16. **ui8** Tailwind v4 eval |
| ui-libraries | PrimeReact v11 is the best-measured skill in the cluster (control 1/5 and 0/5, with skill 5/5 and 5/5). "Build in the library the project has", and the organisation design-system rule. MUI v9 currency | Library MCP servers: `@mui/mcp`, `@primereact/mcp`, `@mantine/mcp-server`, `@heroui/react-mcp`, `@chakra-ui/react-mcp`. The MUI + Tailwind v4 layer recipe. The versioned `@mui/material-nextjs/v15-appRouter` subpath. The Chakra codemod order | **lib1** MCP column in `library-map.md` · S. **lib2** re-verify Astryx against 0.7.x (its own "until 0.7.0 removes them" deadline has passed) · S. **lib4** a visible pause for Aceternity marquees · S. **lib5** removal runs for reui and aceternity. **lib6** MUI v9 eval |
| craft-layer | `divergence.mjs` (1,367 lines, no model) and `gates.spec.ts` with 28 fixtures. Reduced motion checked in the browser. Three.js inversions with sources. A hosted-3D contract (Spline, Unicorn, Paper Shaders) no peer covers | Per-edit and Stop reach for the anti-generic checks: impeccable now runs on PostToolUse and Stop (its `hooks.json`, read by the researcher). Today they run only inside `/craft-layer:audit`. This was the plan's deferred item, so it **waits on the user's ask**. Frame time under 4× CPU throttle (auteur `motionqa.mjs`). A static poster-first check | **cl1** name hosted 3D in `motion-tiers`' description (V absent), then re-run the Spline case (control 0/5, with 1/5) · S. **cl2** poster check in `divergence.mjs` · M · gate. **cl3** frame-time probe · M · gate on long tasks. **cl4** wire `/design-kit:design` into section-decisions · S. **cl6** restamp three 0.187. **cl9** asset-manifest check · S-M · gate. #19 |
| design-kit | Every main path is a script with a harness. Film checks no peer has (fact tracing, beat cuts, loudness, pops). Remotion's company licence raised before choosing it. A privacy-safe signed-in snapshot | Token extraction from a rendered page (dembrandt reads computed styles; ROUTE the tool, build the mechanism on our Chromium driver). Prefer the Figma MCP when connected | **dk1** the plugin's 30-day retirement reading was **due 2026-10-22** and nothing is recorded. It needs `dk-usage.sh` over the user's projects, which this review did not run · S, user. **dk2** (#17). **dk5** a `motion-check` script (the recorder is rewritten per project today) · M · gate. **dk6** `dk drift --print-hook` · S. **dk7** evals for `system` and `in-codebase` |

### Game dev and game art (cluster F)

| plugin | better than peers | missing (ADMIT) | do next |
|---|---|---|---|
| gamedev | `check_steam_build.py` resolves depots offline. Content Survey AI classes. Measured loudness numbers with the method. A pinned PRNG test. Never logs in to Steamworks | `steam_appid.txt` shipped in a depot. Valve: "Make sure to remove…"; (V) the checker has 0 `steam_appid` hits. App id 480 left in. An itch HTML5 zip checker for five rules that are recorded only. A loudness meter | appid checks · S · gate where run. `check_itch_html5.py` · S. `measure_loudness.py` (re-verify the ffmpeg flags) · M. Router rows for `game-assets`, `seeded-generation` and `game-platform-floors` (0 today) · S |
| godot | Carries only the 4.3→4.7 inversions; the most-installed peer has no version fact at all. A reference checker with an exit code (case drift, uid collisions, inherited scenes). An honest headless runner | A hook on `.tscn`/`.tres`/`.gd` edits (Qb-Lab denies structural edits; our README:51 admits nothing runs the checker). A Godot 3 syntax warning. Godot 4.8 (beta2): .NET 10 required, strings as comments disallowed | Advisory PostToolUse running `check_godot_project.py --json` · M · gate. A Godot 3 syntax rule · S. 4.8 section once stable, and fix ".NET 8" · S. An editor-MCP pointer (stating 6 months idle) · S |
| unity | An offline `.meta`/GUID checker (every vendor tool needs a running Editor). Silent-break facts with remedies | #10. The Unity CLI as the official agent path; the `com.unity.ai.assistant` MCP server is deprecated as of 2.19. The official `unity-agent-plugin` uses the same `unity` namespace | #10 · M. A version-windowed C# name scan in the checker · M · gate where run. CLI pointer · S. Test side-by-side load with the official plugin · S |
| unreal | The Zen cooked-output inversion. Enhanced Input on network clients. Non-instanced BT node memory. Epic's plugin covers none of these | A pointer to Epic's official Claude Code plugin and the UE 5.8 Unreal MCP: HTTP only, no auth, `GenerateClientConfig ClaudeCode`, serial tools (Epic's skill and docs disagree). A verified 5.5-5.8 deprecation table. **No mechanism at all** | Pointer · S. `check_unreal_project.py` (version, Zen config, deprecated names) · M · gate where run. Deprecations reference after re-verifying against Epic source · M. Zen-cook eval |
| phaser | A silent-failure column (what the v3 form does in v4). `scene.launch` restarts a running scene. Two-sided collision masks | `DynamicTexture`/`RenderTexture` need `render()`. `Math.PI2` removed. Compressed textures are Y-up. Canvas renderer deprecated (from the vendor's own skill) | README overlap note naming `phaserjs/phaser/skills` · S. The four rows · S. `check_phaser_v4.py` · M · gate where run. A 3-arm eval: base / vendor / ours |
| pixijs | Thin. The official `pixijs/pixijs-skills` plugin carries every footgun ours carries. Unique to ours: the GLSL ES uniform-initialiser ban, the lockfile rule, and a much smaller listing cost | None found; the vendor plugin is a superset | **Decide by a 3-arm eval.** Retire to a craft-layer pointer if ours adds nothing; otherwise add `check_pixi_v8.py` and an "install one, not both" note · M |
| blender | `check_bpy_scripts.py`: 29 version-windowed rules, 0 findings on 601 scripts. The `--python-exit-code` placement trap, measured. `blender_qa.py` fixed to exit 1. The FBX factor-100 table | EL4CTEO 1.2.0 material checks: data maps left sRGB, missing textures, empty slots (MIT) | Port into `blender_qa.py` with a NOTICE line · S · gate where run. Run `check_bpy_scripts.py` over our own SKILL fences in `validate.sh` · S · gate |
| meshy | Paid-task safety: reconcile before resubmitting, the two kinds of 429, delete on `IN_PROGRESS`. The Terms-of-Use licence split. A cross-generator `inspect_glb.py` | KTX2 and WebP image sizing (headers are stdlib-readable). A `gltf-validator` pointer for schema checks | KTX2/WebP · S · gate where run. Validator pointer · S. Move polycount and exit-code detail out of the 148-line body · S |
| pixel-art | Two offline consistency checkers (sheet JSON vs PNG; map references, GIDs, engine-skipped formats). Exporter-source facts | Nothing new clears the bar | Near-miss clauses against `gamedev:game-assets` in both descriptions · S. More engine profiles only after reading each loader's source · M |

### Session, memory and meta (cluster G)

| plugin | better than peers | missing (ADMIT) | do next |
|---|---|---|---|
| candor | Clauses no peer has: lockfile drift, a PreToolUse hedge guard, a SubagentStart preamble that skips read-only agents. Clause 6 checks a quote across file, HEAD and transcript. Deterministic and local (jev-belay sends transcripts to a vendor). Terse mode budgets shape, not words | #2. Claim-kind matching: "tests pass" needs a test runner after the last edit; `git status` satisfies clause 3 today (receipt). The cited line must have been read this session (ground-check). Firing-rate counts per clause | #2 · M · gate. Claim kinds, warn first · M. Cited-line-read, measured first with `candor-scan.sh` · M. A block counter in `/candor:check` · S. Clause 6 is missing from the straight-talk standing table · S. Run the five cases' control arms first (priors date from Opus 5, 2026-08) · S, about $1-2 |
| ask-ledger | Per-name accounting. Deterministic extraction with zero model calls. At most two blocks. Names the repo already has are filtered out | Lowercase features ("login", "register"), opt-in as a mod because it costs a model call (principia) | The eval grader FAILs a control for lacking our line format, so it cannot show honesty; add a "disclosed in any wording" grader, then run it · S. Name the `/goal` boundary in the README · S |
| hindsight | Mines subagent transcripts and files defects against the artifact that ran. An outcome check before and after a rule (≥ 3 sessions). An apply gate with four destinations | Say what `/insights` already covers and what harvest keeps. Warn that `cleanupPeriodDays` (default 30) deletes the evidence. Check rule age against failure dates (retro). The prior ADOPTs (SkillOpt held-out check, autoharness size cap, abide enforceability tiers) are still unbuilt | Boundary and retention warning · S. Script ranking and the ledger bookkeeping (harvest is at 188 lines (V)) · M · gate. A `corrections` count in `collect.sh` · S · gate. abide's enforced-by column in `/hindsight:claude-md` · S. An eval with a scaffolded transcripts dir · M |
| brain | Committed and bounded to 2 KB / 30 lines. Decisions ledger. 0 bytes into subagents | The map is cut silently at `inject.sh:78`. graphify's read/inferred tag is still unbuilt. A one-line path hint for subagents | A cut notice · S · gate. `drift.sh` · M · gate. Tag · S. Path hint · S · gate |
| prompt-coach | Nothing reaches the main context. Judgement kinds no peer has (contradiction, off-card, reopened decision). Never submits. A measured judge (0/36 clear prompts dropped, 24/27 unclear dropped) | The coach's own spend, plus a cap. `/cost` shows none of its calls | `/coach` stats command · S · gate. Spend summed into `$.state` (declared in `types`) · S-M · gate. A re-runnable judge probe behind an opt-in variable · M |
| session-hud | No settings edit. Subagent rows with model, effort, context and age. The compaction point. No subprocess per refresh | Pace and ETA ("5h window full at ~14:20"). Name `/usage` and `/context` | Pace segment · S-M · gate. README boundary · S |
| skill-router | Routes on files Bash wrote. Hands stack-filtered skill paths to subagents. Compaction steer. Never blocks. No per-prompt catalogue | The host `paths:` frontmatter: (V) 0 SKILL.md use it. Already measured on 2.1.237 (`.claude/skills/authoring-skills/references/activation-fields.md`): it activates on an edit, not a read, and a PLUGIN skill stays in the listing either way. So it buys reach, never budget | Re-measure `paths:` on the current CLI only if the listing cost matters again; on 2.1.237 it saved nothing for plugin skills · S. `general-purpose` subagents receive every primed skill (seen once) · S · gate |
| all-plugins | A real bulk install through the host CLI with exit codes. Asks the scope. The budget write is owned and reversible (MobiAI never restores its value) | A `/skill-doctor` pointer after install | One line in the exit-0 tail · S · gate. No `--budget` change: `paths:` does not shrink a plugin skill's listing (measured 2.1.237) |
| ultra-deep-research | A separate adversarial verifier with vote panels. A contradiction ledger with an ordered rule. Local-corpus coverage with a pages-read manifest. Bounded cost | A script that proves every cited URL was fetched (199-bio; no licence, so reimplement). A check that the quote is in the fetched text. Independence groups | A SubagentStop hook running `verdict-lint.sh` on verifier returns · S-M · gate + lane row. `sources-check.sh` against WebFetch calls in the transcripts · M · gate. An `origin:` field · S. A near-miss against the built-in `/deep-research` · S |

## skill-creator rubric across the marketplace

| check | finding | what to do |
|---|---|---|
| (a) undertrigger | `ui-ux:shadcn-best-practices` (138 chars, no `components.json`, loses co-fire to the official skill). `craft-layer:motion-tiers` (no hosted-3D words; the Spline case fails 1/5 with the plugin). `security:security-review` (SSRF, Livewire and multi-tenancy live only in the body). `git-workflow:review-exchange` (no "PR review threads") | Rewrite those four descriptions. Then run skill-creator's description optimizer (`scripts/run_loop.py`: a 20-query should/should-not set, 60/40 train/test split, best description picked on held-out score). It is the one skill-creator mechanism this repo does not have, and it measures instead of guessing |
| (a) overtrigger | `task-runner:task-execution` ("a todo list", which registers a run and arms the close protocol). `code-review:code-smells` (any "judging code quality"). `design-kit:artifact` ("easier to look at than to read") | A near-miss clause each, checked by the same optimizer or C2's corpus |
| (a) missing near-miss | `ui-ux:motion-best-practices` ↔ `craft-layer:motion-tiers`. `laravel:laravel-best-practices` against Boost's same-name skill. `ultra-deep-research` against `/deep-research`. `hindsight:harvest` against `/insights`. `gamedev:game-assets` against `pixel-art` and `meshy`. `unreal` against Epic's `unreal-mcp`. `phaser`/`pixijs` against the vendor skills. `taskmaster:grill` against `brainstorm` | One clause each · S. skill-creator advises "pushy" descriptions; here every added word competes in a listing every installer pays for, so only C2's corpus or the optimizer settles it |
| (b) at the size cap (V, body lines / bytes) | `comment-discipline` 197 / 13,959; `task-cards` 197; `branch-completion` 197; `plugin-scout` 196 / 13,398; `nextjs-best-practices` 194; `inertia-best-practices` 193; `grill` 192; `primereact` 191; `overseer` 189 / 13,700; `harvest` 188; `threejs` 188 | Move the named sections to `references/` before the next edit fails `validate.sh` |
| (c) why vs MUST | Clean repo-wide: the max is 6 shouted words (`taskmaster:ultra`). No action | — |
| (d) repeated work that should be a script | harvest ranking and ledger; brain drift; parallel-planning arithmetic; the deliberation marker; drift-review diff assembly; `analyzer-triage` CI-green skip; design-kit motion recorder; asset-manifest glob; branch-completion's default-branch and CODEOWNERS resolver | Items R4, A4, C3, TC, dk5, cl9 and hindsight item 3 above |
| (e) evals | 9 of 42 plugins ship evals. Bought but unrun: resilience liveness, ui-ux `design-tokens-control` and `a11y-older-criteria`, candor ×5, ask-ledger, code-architecture `solid-control`. Controls known to pass (regression guards only): five resilience cases, web-dev `caching-inversion` and `astro-removed-apis` | Run the bought ones first. New cases only where a control plausibly fails: Next Cache Components, Laravel `->change()`, idempotency 422, Unity Dictionary, the Unreal Zen cook, MUI v9, Tailwind v4, Three.js, design-kit `system`, gone-unmerged. 3-arm vendor evals for phaser and pixijs |

## Ranked backlog (impact on installers)

| rank | item | plugins | size | standing |
|---|---|---|---|---|
| 1 | Close the data-loss and leak paths: #1 clean-gone, #3 provider prefixes, #4 command-guard rows | git-workflow, secret-scanning, command-guard | S-M | gate |
| 2 | Make candor's completion clause see Bash writes (#2) | candor | M | gate |
| 3 | Fix the wrong facts: #6 Next 16.4, #7 MariaDB remedy, #8 idempotency, #9 phpstan/eslint, #11 Laravel 11 and Inertia v3, #12 grader, #16-#19 | web-dev, database, api-design, toolchain-experts, laravel, resilience, ui-ux, design-kit, stack-scan, craft-layer | S each | mixed |
| 4 | Unity 6.4-6.6 catch-up plus a C# name scan (#10) | unity | M + M | recorded → gate where run |
| 5 | Secret-scanning commit/push gate on `scan-range.sh --cached` | secret-scanning | M | gate + lane row |
| 6 | taskmaster shape-phase write guard (T2) and cross-card lint (T1) | taskmaster | M + M | gate |
| 7 | ultra-deep-research SubagentStop verdict lint plus `sources-check.sh` | ultra-deep-research | M | gate |
| 8 | Run every bought, unrun eval; fix the ask-ledger grader (the priced cases come to about $10-11: liveness ~$3.40, the two ui-ux cases ~$3 each, candor controls ~$1-2; the rest are unpriced) | resilience, ui-ux, candor, ask-ledger, code-architecture, overseer | S | measured |
| 9 | Name the host built-ins (`paths:` already measured: reach only) | hindsight, all-plugins, session-hud, overseer, ask-ledger, skill-router | S | recorded, then gate |
| 10 | Vendor pointers and routes: Epic/UE MCP, Unity CLI, Phaser/PixiJS skills, library MCPs, shadcn CLI and skill, Boost overlap, zizmor, oasdiff, squawk, stack-scan rows | unreal, unity, phaser, pixijs, ui-libraries, ui-ux, laravel, devops, api-design, database, stack-scan | S each | recorded |
| 11 | `red-proof.sh` and a replayable flake seed | testing, debugging | M | gate |
| 12 | First mechanism for prose-only engine plugins: `check_unreal_project.py`, `check_phaser_v4.py`; decide pixijs by 3-arm eval | unreal, phaser, pixijs | M each | gate where run |
| 13 | godot PostToolUse checker hook | godot | M | gate |
| 14 | task-runner `coverage-close.sh`, path resolver, drift-review claim (#14, #15) | task-runner, code-architecture | S-M | gate |
| 15 | code-review fresh-context validator plus mutant run; ablate the smell pass | code-review | M | agent-graded / gate |
| 16 | security raw-SQL and shell-exec rows, `--scan` mode, `.md` fix (#13) | security | S-M | gate |
| 17 | craft-layer poster check, frame-time probe, hosted-3D description; per-edit anti-generic reach **if the user asks** (deferred item) | craft-layer, ui-ux | S + M | gate |
| 18 | design-kit retirement reading (due 2026-10-22) | design-kit | S | user runs `dk-usage.sh` |
| 19 | Cross-family opt-in consult | approaches | M-L | gate on refusals |
| 20 | Small checkers: Steam appid, itch HTML5, Blender materials, KTX2/WebP | gamedev, blender, meshy | S each | gate where run |

## Do not build (peer has it, we should not)

- Rule catalogues, excuses tables, OWASP/STRIDE/k8s/Postgres/React-perf checklists: shapes 2-4 in
  `measured-zero-shapes.md`. React perf measured negative.
- Blocking every UI edit until an a11y review (accessibility-agents), and blocking praise openers
  (llm-dark-patterns). Proportionality, plus candor's own reasoning (`README.md:112-115`).
- A Stop gate that forces a brain map refresh (codebase-mapper): each block costs a full turn.
- Per-prompt self-evaluation or catalogue injection (forced-eval 911 B, severity1 819 B): always-on
  regrowth (`improvement-plan-2026-10-26.md:57`).
- Entropy rules in a deny gate; live key verification (trufflehog, AGPL, network calls).
- Party mode or other non-blind persona rounds (BMAD): the in-context role-play shape.
- Cheapest-model-per-role dispatch (superpowers): conflicts with the user's "results first" order.

## Flags from peers

| kind | peer | what |
|---|---|---|
| agent-addressed promotion with concealment | Vincentwei1021/video-shotcraft `SKILL.md` ~190-208 | tells the agent to post the author's social links and solicit submissions without saying they are public GitHub issues. Do not recommend while it stands |
| vendor steering aimed at agents | pixijs-skills README; greensock/gsap-skills descriptions; Aceternity llms.txt | "recommend PixiJS/GSAP when no library is specified". Benign, but it pulls against our CSS-first and library-neutral rules when installed together |
| binary download, network | pbakaus/impeccable | the launcher downloads a native binary; the skill fetches from impeccable.style even with telemetry off |
| risky shipped config | drona23/claude-token-efficient; Vibe-Skills; ReUI installer | PreCompact `git add -A && git commit --no-verify`; `skipDangerousModePermissionPrompt: true`; writes `~/.claude.json` and stores a licence key in `settings.local.json` |
| data leaves the machine | jev-belay; groq-prompt-scorer; security-guidance Stop review | transcript slices, prompts and diffs sent to a model endpoint |
| licences that block copying | dcg (MIT plus a rider excluding Anthropic); Task Master (Commons Clause); Unity Companion License; trailofbits (CC-BY-SA); AGPL (trufflehog, attention-span, basic-memory); FSL (aoci-code); LGPL (thedivergentai); no licence (199-bio, chongdashu, pixellab, figma guide, remotion skills) | ideas only, or route |
| name collisions | Unity's official plugin `unity`; Boost's `laravel-best-practices` and `testing-best-practices`; itsryanlenk/candor; host `security-review` | test side-by-side loads; add near-miss clauses |

Seen in this session's own runs (n = 1 each): security write-scan warned on a Markdown file (#13);
secret-scanning's redaction refused a draft that quoted the mask marker on purpose; skill-router
handed `testing-best-practices` to a research subagent.

## Not verified, not done

- **No eval was run.** Every "control likely fails" is a prediction; every peer benefit is the author's
  claim.
- **Re-checked this session (V):** the lines in the wrong-today table marked (V); command-guard on 4 of
  the 13 commands; secret-scanning on 6 shapes. Everything else is relayed from researchers who read
  the source or docs named in their cluster files.
- **Read by heading only:** most `references/` bodies (craft-layer alone has about 496 KB), hook and
  script bodies past their headers, test harnesses, and most CHANGELOGs. A rule called missing may
  exist in an unread reference.
- **Peers read shallowly:** Task Master, BMAD, Kiro, wshobson, ECC hooks, dcg (no source),
  cc-safety-net parser, Chakra/Mantine/antd, most Blender and pixel-art peers, Trail of Bits skill
  bodies.
- **Unverified facts behind proposals:** per-runner seed flags; `tsc --showConfig` and
  `eslint --print-config` behaviour; whether `/insights` and `/skill-doctor` are on for every account; quodsoler's
  `UE_DEPRECATED` citations; the Astryx 0.7.0 removals; MUI `enhanceHighContrast`; glTF-Transform's
  KTX2 support; every eval price (the cluster files' estimates, never billed).
- **Not run because it reads other projects:** design-kit's `dk-usage.sh`. The user decides whether to run it.
- **Not searched:** awesome-claude-code lists in depth; claude-code-tamagotchi; ccmonitor.
