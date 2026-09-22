# Specialist panel — 2026-09-22

**Question asked (as improved before execution).** The user's prompt: "the greatest of
minds sit in a closed room, all look into this marketplace, and each in their own
specialization names what is missing — functionality, flexibility, issues, improvements
— then exits after a massive brainstorm." Six specializations were named: Ops, Software
Development, Web Development, Designers, UI/UX, Architects. The prompt was rewritten
into a brief before any agent ran (`taskmaster-docs/panel-2026-09-22/brief.md`,
gitignored; reproduced in §0) so that every finding would be anchored to a `path:line`
or a command, ranked, tiered by standing, sized, and checked against the three prior
reviews and `rationale/measured-zero-shapes.md` so nothing already settled or already
killed would be re-proposed.

**Standing of this document: `recorded`.** Nothing reads it back. Every finding
carries the anchor the specialist gave; findings the specialist could not execute are
marked PLAUSIBLE. The overseer of this run (the main session) did not re-verify every
anchor against the tree; §7 says what was and was not checked.

**Method.** Six read-only agents, same day, on CLI 2.1.278, branch
`brainstorm/specialist-panel-2026-09-22` off `master` at `7e5f3446`. One brief, six
lenses. Each ran real hooks with synthetic payloads, real gates, and where possible the
host's eval loader with a zero-cost ceiling. Raw returns are in
`taskmaster-docs/panel-2026-09-22/` (gitignored). Every specialist reported that
`bash scripts/validate.sh` exits 0 and `context-budget.sh` shows zero delta on
`master`: **nothing below is a red gate today**. That is the point — these are the
defects the gates do not see.

---

## 0. The improved prompt

The original ask was a scenario. What made it runnable:

1. **A bar.** README ¶1 — a rule the model gets wrong from memory, or a mechanism prose
   cannot replace — and `measured-zero-shapes.md` read first, so a "skill that explains X"
   must name what a blind control gets wrong.
2. **A read of the last three reviews**, so an open item is reported as "still open
   since", not as a discovery.
3. **Anchors or PLAUSIBLE.** Every claim carries `path:line` or a command and its
   output; unverified claims rank below verified ones.
4. **The installer's seat, not the maintainer's.** Repo polish counts only when it
   protects a shipped plugin.
5. **A fixed output contract** (ranked ≤12, checked-and-clean, one deletion), so six
   reports could be merged without re-reading.
6. **Read-only**, with the mutating flags named so an agent could not "fix" what it found.

---

## 1. Where the six converged

Themes two or more specialists reached independently, from different lanes. These are
the highest-confidence items in the document.

| theme | who | the shape |
|---|---|---|
| **Language monoculture in the mechanisms.** The gates that have teeth read py/js/go, or PHP/JS, and are silent — not failing, silent — on everything else. | Software 1, 4, 7, 9; Ops 8, 9; Web 1, 2, 9 | `behavioral-gate.sh` cannot close a run on PHP/Rust/Java/Ruby; `test-shape.sh` globs Python/Go/Ruby files and detects zero blocks in all three; `database/hooks/guard.sh` misses Rails, Django, GORM, `deleteMany()`; `verify-teeth-lint.sh` passes `./gradlew test`; `detect-analyzers.sh` sends SvelteKit to plain `tsc`; `write-scan.sh` knows one public env prefix. |
| **Silence is the output of both "clean" and "broken".** Fail-open by doctrine, with no installer-facing instrument to tell the two apart. | Ops 6; UI/UX 1, 9; Architect 9 | `/skill-doctor` and `/skills` in zero shipped docs; 30 `CC_*` switches, none in the README; Stop gates hide their own off-switch while PreToolUse guards name theirs; "which skill fired" is written to `.claude/skill-router/` and read by nothing an installer receives. |
| **The router and the lanes disagree about what triggers a skill.** | Web 3, 5, 6, 8; UI/UX 3, 7; Design 11 | No `*.html`/`.erb`/`.twig` row; no stylesheet row; Next.js server files unrouted while `lane.tsv` says "an edit under app/"; `prime.sh` omits the Next and Vite skills its own map declares; absent-manifest markers fire instead of suppress; the one unmarked stack row nudges Tailwind on Go. |
| **Claims of teeth over agent-graded prose.** | Design 1; Ops 7; Architect 2, 11 | "sameness-fingerprint gates" reads 12% of its registry; nine `(teeth)` headings over prose; the fail-open shebang rule asserted in six headers, violated in eleven hooks, checked by nothing; the phase sentinel has four prose writers and no script writer. |
| **The eval surface cannot yet measure anything, and nothing runs it.** | Software 11, 12; Architect 3; Web 10; Ops 5; UI/UX 4 | Graders that cannot pass under the documented invocation; scaffolded cases run against an empty sandbox; four cases at `runs: 1`; every resilience case at the control ceiling; ten checklist skills (~68 KB) with no mechanism, no `Standing:`, no eval. |
| **Stale-cwd and stale-state hooks.** | Architect 1, 4, 5, 11; Software 2 | Eight hooks `mkdir -p` on an unvalidated payload `cwd` (still open since the trend audit's H6); one one-shot mirrors an absolute path into `$TMPDIR` with no sweep; `deliberated.json` has no TTL and no deleter; nothing greets a cold session that has a live task-runner run. |
| **The design studio cannot see.** | Design 2, 4, 5; UI/UX 2, 5 | The gate suite cannot be invoked the way its command says (no `playwright.config`); `/ui-ux:audit` never runs axe/pa11y though `ui-expert` exists to run them; `/ui-ux:theme` says "contrast-checked" and cannot reach the only contrast script; no literal-colour drift check, no before/after screenshot. |

---

## 2. Consolidated ranked list

Ordered by blast radius for an installer, then by size. `Standing` is what the fix would
have. `Src` is the specialist and their rank. Full evidence is in §3.

| # | kind | claim | plugin | standing | size | src |
|---|---|---|---|---|---|---|
| 1 | BROKEN | `/task-runner:run` cannot close on PHP/Rust/Java/Ruby: `behavioral-gate.sh:117-123` classifies only py/js/go, no `--runner` flag, candor Stop gate then blocks every exit | task-runner | gate | M | SW 1 |
| 2 | BROKEN | Eight hooks `mkdir -p` on an unvalidated payload `cwd`, recreating deleted project dirs; `overseer/hooks/track-read.sh:30-31` is the correct shape | code-review, skill-router, task-runner, testing, ui-ux, candor | gate | M | AR 1 |
| 3 | BROKEN | No SessionStart greets a cold session with a live run; fresh session + stale `active-run.json` → Stop blocked, escape is deleting a live run's sentinel | task-runner | gate | S | SW 2 |
| 4 | BROKEN | Headless (`claude -p`) turns every `ask` into a silent deny; command-guard README describes a prompt and frames `deny-only` as noise, not the automation profile; database README says ask "stalls" | command-guard, database | recorded | S | OPS 2 |
| 5 | MISSING | Root README documents 0 of 30 `CC_*` off-switches; Stop gates omit their own var from the blocking message while PreToolUse guards name theirs | root, candor, ask-ledger | gate + recorded | M | UX 1 |
| 6 | BROKEN | Sameness-fingerprint "gate" reads 1,683 of 13,951 chars of its registry; nine registry entries verbatim pass clean; README:143 sells four gates, one is scripted | craft-layer | gate + recorded | M | DS 1 |
| 7 | BROKEN | `test-shape.sh` globs `*_test.py/_test.go/_spec.rb` and detects zero blocks in all three; `protect-tests.sh` lets RSpec `xit`/`pending`/bare `skip` through | testing | gate | M | SW 4 |
| 8 | BROKEN | `database/hooks/guard.sh` silent on Rails `drop_table :users`, Django `DeleteModel`/`RemoveField`, GORM `DropTable`, Prisma `deleteMany()` while its header claims "every other migration DSL" | database | gate | S | SW 7 |
| 9 | BROKEN | Composite actions (`.github/actions/*/action.yml`) neither denied nor audited; identical injection in `workflows/` is denied | devops | gate | S | OPS 1 |
| 10 | MISSING | Lane vocabulary is 1:1 with claimed nouns (133 = 133); `pc_lanes_territory` cannot see two plugins owning one territory under two names; the probe measured overlap costing firing 100% → ~75% | scripts | gate | L | AR 2 |
| 11 | BROKEN | `detect-analyzers.sh` sends SvelteKit/Astro to `npx tsc --noEmit` (parses none of their components), never reports `svelte-check`/`astro check` | toolchain-experts | gate | S | WEB 1 |
| 12 | MISSING | `write-scan.sh` knows only `VITE_`; `NEXT_PUBLIC_`/`EXPO_PUBLIC_`/`NUXT_PUBLIC_`/`PUBLIC_` secrets silent; `{@html}`/`set:html` silent | security | gate | S | WEB 2 |
| 13 | MISSING | No URL-embedded-credential pattern: `postgres://admin:Sup3rS3cret@…` in `.env` → allow; tfvars, compose, Helm passwords, Slack webhooks → allow | secret-scanning | gate | S | OPS 4 |
| 14 | BROKEN | `/ui-ux:audit` judges from prose; `ui-expert` (runs axe/pa11y/lhci/stylelint) is dispatched by nothing; review fan-in omits CSS/a11y analyzers | ui-ux, code-review | agent-graded + gate | S | UX 2 |
| 15 | BROKEN | Eval suites: graders that cannot pass under the documented command (candor, ask-ledger); scaffolded cases run against empty sandbox (5 of 14); 4 cases at `runs: 1`; `eval-cases.sh` gates frontmatter only | scripts, candor, ask-ledger, overseer, web-dev | gate | S | SW 11, AR 3, WEB 10 |
| 16 | BROKEN | craft-gates cannot be run the way `audit.md:83` says: no `playwright.config`, spec header says copy, command says never copy; screenshots then never captured | craft-layer | gate | S | DS 2 |
| 17 | BROKEN | Next.js server files (`app/api/**/route.ts`, actions, `middleware.ts`, `proxy.ts`) unrouted while `lane.tsv` claims "an edit under app/" and the skill carries the server-actions-are-public rule | skill-router | gate | S | WEB 3 |
| 18 | BROKEN | No `*.html`/`.erb`/`.twig` router row: WCAG never loads for Rails/Django/Twig/Angular/static HTML; palette nag does fire on `.html` | skill-router, ui-ux | gate | S | UX 3 |
| 19 | BROKEN | Absent-manifest markers fire instead of suppress (`route.sh:106-113`): `.tsx` with no `package.json` → shadcn + react-native + nextjs in one envelope | skill-router | gate | M | WEB 5 |
| 20 | BROKEN | `prime.sh` omits the Next and Vite skills `skill-map.md:25-26` declares; `pc_prime_coverage` checks one direction only | skill-router | gate | S | WEB 6 |
| 21 | BROKEN | Version-pinning promise has no live signal: five web/laravel stamps lack an `npm:` tail; live next 16.3.5 vs skill ceiling 16.2, react-native 0.87 vs 0.82 | web-dev, laravel | gate + warn | S/M | WEB 4 |
| 22 | BROKEN | `run.md:105` pre-creates `rv/ rt/ bg/ reductions/` but not `nc/`; a run that skips its first negative control disarms the whole check | task-runner | gate | S | SW 5 |
| 23 | BROKEN | `verify-teeth-lint.sh` blocks `pytest`/`npm test`/`go test`/`cargo test` and passes `./gradlew test`, `mvn test`, `dotnet test` | taskmaster | gate | S | SW 9 |
| 24 | MISSING | Scope-lock tripwire reads only `scope.json`; delegated/tracked cards write `scope-<cardId>.json` — the sold path is scope-locked by prose | task-runner | gate | M | SW 8 |
| 25 | BROKEN | `write-scan.sh` mirrors the absolute transcript path into `$TMPDIR` (7 nested dirs/session), no sweep | security | gate | S | AR 4 |
| 26 | BROKEN | `unread-pick.sh` is the only `set -euo pipefail` hook: python3 off PATH → rc 127 every prompt; hand-rolled sentinel read with no TTL muted by a dead session's file | design-kit | gate | S | AR 5 |
| 27 | BROKEN | Deny reason names `plugins/devops/scripts/workflow-audit.sh`, a path absent on an installer's disk; same class in `code-redteam/SKILL.md:33` | devops, task-runner | gate | S | OPS 3 |
| 28 | MISSING | `/ui-ux:theme` claims "contrast-checked"; the only checker is `craft-layer/template/craft-gates/contrast.mjs`, unreachable from ui-ux/frontend-suite/workflow-suite | ui-ux | gate | M | UX 5 |
| 29 | RIGID | ask-ledger ledgers existing identifiers ("Fix the N+1 in OrderController…" → six entries, Stop blocked) | ask-ledger | gate | S | SW 3 |
| 30 | BROKEN | `/ui-ux:theme` writes `taskmaster-docs/mockups/` with no `.gitignore`; only taskmaster's grill drops one; craft-suite lacks taskmaster | ui-ux, git-workflow | recorded + gate | S | DS 7 |
| 31 | BROKEN | Corpus freshness in `divergence.mjs:68` is file mtime: printed 2026-09-16 for a corpus stamped 2026-07-26; fresh clone = clone date | craft-layer | gate | S | DS 3 |
| 32 | BROKEN | Chassis sample drift live again: `divergencePreamble` injected by `generate.sh:270`, in 0 of 10 frozen samples, hidden by `{{#if}}` | templates | gate | S | AR 10 |
| 33 | BROKEN | "Upgraded statement" written only on boosted runs, read unconditionally; spec path advertised with 0 readers; `## Coverage` no reader outside taskmaster | taskmaster, task-runner | agent-graded | S | SW 10 |
| 34 | MISSING | Zero hits for PR template / CODEOWNERS / commitlint; `conventions.sh:80` scans `.github/workflows` only (GitLab repo → no "CI runs:" line) | git-workflow, code-review | agent-graded + gate | M | SW 6 |
| 35 | MISSING | a11y-audit covers all six new 2.2 AA criteria and misses older AA: 1.3.5 `autocomplete` (0 hits repo-wide), 4.1.3 status messages, 1.4.13, 1.4.12, `lang` | ui-ux | recorded, measurable | S/M | UX 4 |
| 36 | MISSING | `component-libraries` (the floor for every library without a sibling skill) and the three token skills have no router row; no stylesheet row | skill-router | gate | S | UX 7, DS 11 |
| 37 | MISSING | Two PreToolUse hooks return `ask` and `deny` on one command; precedence documented nowhere (still open since endgame residual 1) | command-guard | recorded | S | AR 6 |
| 38 | IMPROVE | `route-prompt.sh` re-injects a 60-row, 5,071-char catalog the host already lists; the protocol is 1,713 chars | skill-router | gate | S | AR 7 |
| 39 | IMPROVE | Bundle READMEs teach `skillListingBudgetFraction`, which the probe measured as not helping; the host's own remedy `/skills` and `/skill-doctor` appear in zero docs; everything installed = 1.32× the 1M cap | root, bundles | gate | S | AR 9, UX 6 |
| 40 | MISSING | No literal-colour drift check on components (still open since design-kit ideas §7); no before/after screenshot (§8) | design-kit | gate | M / L | DS 4, 5 |
| 41 | MISSING | design-kit unknown to craft-layer and ui-ux (0 hits each), in no bundle; "one permission rule" overstated — five direct calls remain | craft-suite, design-kit | gate + recorded | S | DS 6 |
| 42 | MISSING | resilience observability/performance: 0 eval cases; one seedable control failure named (liveness probe that pings Postgres) | resilience | gate for loading | M | OPS 5 |
| 43 | MISSING | No IaC lane; the mechanism-bearing slice is a `terraform show -json` plan reader exiting 2 on stateful deletes, NOT a terraform skill (shape 4) | devops | gate | L | OPS 9 |
| 44 | MISSING | `/stack-scan:audit` stops on an infra-only repo; no image-tag/EOL axis; `scan.sh:52` framework loop lacks svelte/astro/remix/hono/prisma/drizzle; Astro-only repo satisfies no class | stack-scan | agent-graded | M | OPS 8, WEB 12 |
| 45 | RIGID | Phase sentinel has four prose writers, no script writer, seven readers; `deliberated.json` no TTL, no deleter (still open since endgame residual 3) | taskmaster, approaches | gate on write | M | AR 11 |
| 46 | IMPROVE | Fail-open shebang doctrine asserted in six headers, violated in 11/53 hooks (two decision-capable), no check | scripts | gate | S | OPS 7 |
| 47 | RIGID | Eight craft-layer terms (spine, archetype, draw, move, genus, concept deck, register gate) undefined in README; `genus` defined nowhere | craft-layer | recorded | S | DS 8 |
| 48 | IMPROVE | Undecodable AskUserQuestion labels: overseer's bare "merge / PR / keep"; stack-scan's "Tier 1"/"Core 1/2"/"scope S"; ui-ux's four sites are the house standard | overseer, stack-scan, git-workflow, design-kit | recorded | S | UX 8 |
| 49 | IMPROVE | Three commands read `$ARGUMENTS` with no `argument-hint` (`api-design:drift`, `task-runner:plan`, `ui-ux:audit`); doctrine says expected, no gate | api-design, task-runner, ui-ux | gate | S | UX 11, SW clean |
| 50 | MISSING | `api-docs-first` has no branch for a subagent with no WebFetch and no user; context7 named as "the source it asks for" in stack-scan, never in api-design | api-design | recorded | S | WEB 7 |
| 51 | MISSING | api-design routes on `api.php` + `openapi*`; no 2026 server-route shape (`app/api/**`, `+server.ts`, `server/api/`) reaches it; lane declares 2 of 4 skills | skill-router, api-design | gate / WARN | S | WEB 8 |
| 52 | RIGID | `frontend-reviewer` claims "any JS/TS framework", has vocabulary for React and Vue only | web-dev | agent-graded | S | WEB 9 |
| 53 | MISSING | web-developer verifies by tests/lint/build; nothing loads the route in a browser or says it did not | web-dev | agent-graded | S | WEB 11 |
| 54 | MISSING | Brand voice/copy is a slot name not a capability; `brief-templates.md:96-98` is the only operational copy craft | craft-layer | agent-graded + gate | M | DS 9 |
| 55 | RIGID | The static type contract (`type-system.md`: clamp, `text-wrap`, WOFF2, metric overrides, licence trap) is reachable only via "Use when animating type" | craft-layer, ui-ux | recorded | S | DS 10 |
| 56 | MISSING | No RTL/logical-property rule in ui-ux; tailwind skill never mentions `ms-`/`me-`/`ps-`/`pe-` | ui-ux | recorded, measurable | S | UX 10 |
| 57 | MISSING | Nothing persists a rollback path; `rollout-planning` produces it in-session and discards it | approaches | recorded | M | OPS 10 |
| 58 | MISSING | No installer self-check; `turn-cost.sh` and `context-budget.sh` exist on disk unnamed | root | recorded | S | OPS 6 |
| 59 | MISSING | Nothing re-reads the host binary; `1536` literal in three files incl. shipped `all-plugins.sh:220`; `SLASH_COMMAND_TOOL_CHAR_BUDGET` unmodelled; pin 2.1.273 vs live 2.1.278 | scripts, all-plugins | gate / WARN | M | AR 8 |
| 60 | IMPROVE | Lane rows missing: devops-practices (headline skill), all six resilience skills, secret-scanning `unicode-scan` hook; resilience has no CHANGELOG while review fan-in pulls its six skills | devops, resilience, secret-scanning | WARN / gate | S | OPS 11, 12 |
| 61 | IMPROVE | Ten checklist skills (~68 KB) with no mechanism, no `Standing:`, no eval — shape 2 shipped; one control-armed `case.yaml` against `solid-principles` settles the shape for all ten | code-architecture, approaches, testing | recorded → decision | M | SW 12 |
| 62 | IMPROVE | `library-map.md` Radix row misleads Radix Themes; no Svelte section though `.svelte` is routed; Park UI, Flowbite absent | ui-ux | recorded | S | UX 12 |
| 63 | IMPROVE | DTCG-shaped `tokens.json` is a Figma path (Tokens Studio, Style Dictionary) and the README says "Figma: not in this release" | design-kit | recorded | S | DS 12 |
| 64 | RIGID | review-command chassis renders one file and carries nine opt-outs (12 KB of opt-out prose vs a 24-line template) | templates | gate | M | AR 12 |

Recount the source lists rather than trusting the table:
`ls taskmaster-docs/panel-2026-09-22/*.md` (local only).

---

## 3. Per-specialist reports (condensed)

Each specialist's thesis, then the anchors that did not fit the table. The full
return, with every command and output, is in the gitignored working area.

### 3.1 Ops

> The guards are unusually well-built and honestly tiered, but every one assumes an
> interactive human at a keyboard on a POSIX box editing `.github/workflows/`.

Anchors beyond the table: composite-action bypass reproduced with the same
`${{ github.event.pull_request.title }}` body at two paths; the headless auto-deny
string read from the 2.1.278 binary; DSN probe list (`.env`, `terraform.tfvars`,
compose, Helm `values.yaml`, Slack webhook) all `allow`, while k8s `stringData`, GH
Actions `env` tokens, AKIA and private-key blocks all `deny`; 35 destructive ops
commands probed against `destructive-guard.sh`, every data-loss shape correct,
availability-only commands silent by declared doctrine.

**Clean:** 57/57 hook entries carry a timeout (trend audit §3G fixed); fail-open on
missing `jq` confirmed for every deny-capable hook; no bash-4 features anywhere; the
repo's own CI passes its own `workflow-audit.sh`; `destructive-guard.sh --check` works
as documented; stack-scan licence lane on pnpm/yarn/bun (endgame §5.9) fixed;
resilience six-rubric fan-in (endgame §5.2) fixed; `/devops:init` Docker-unavailable
path present; `unicode-scan` 0.047s wall.

**Delete:** `plugins/resilience/evals/idempotency-only-ts/` — a replicate whose stated
question ("is the effect stack-dependent") cannot be answered at the control ceiling.

### 3.2 Software development

> The pipeline chains on paper and on disk, but its two strongest mechanisms are built
> for py/js/go and for one continuous session.

Anchors beyond the table: four fixtures (PHP/Rust/Java/Ruby) each with a green suite,
`behavioral-gate.sh` EXIT=2 on all four; the cold-session repro (`[candor]
completion-gate: … is a registered run with no behavioral-gate pass … EXIT=2`) on a
README typo fix; `claude plugin eval … --max-cost-usd 0` output naming the ungranted
tools per suite; per-skill scan of the ten checklist skills (bytes, refs, standing,
mechanism all zero).

**Clean:** command-guard denies all ten DB-destroying shell commands;
`protect-tests.sh` denies pytest/go/rust/java skips; `conventions.sh` polyglot
detection correct and its paths-not-digest design is right; ask-ledger `gate.sh` fd
handling correct; taskmaster→task-runner index path contract clean; 28/29 commands
carry `argument-hint`; `flake-hunt.sh` runner-neutral; git-workflow hooks portable.

**Delete:** `plugins/approaches/skills/estimation/` + `/approaches:size` — shape 2
verbatim, its ledger has exactly one reader (the instruction to write it), all three
downstream citations are conditional.

### 3.3 Web development

> Three genuinely good version-inversion skills (Next.js, Expo, Inertia), then lost:
> nothing routes the server-side files they discuss, nothing keeps them current.

Anchors beyond the table: `route.sh` probed on a `next@^15.4.0` fixture per file
shape; `prime.sh` on Next+Vite+Tailwind prints three skills and omits both stack skills;
`npm view` for next/react-native/expo against the skill ceilings;
`check-doc-staleness.sh --live` printed nothing for the lane.

**Clean:** api-design REST rubric correct and framework-neutral; inertia skill is real
inverted advice (`lazy`→`optional` rename vs `defer`); glob engine case-insensitive;
endgame §5.11 Blade fixed; Symfony `composer.json` yields zero Laravel nudges;
`signals.md` honestly routes Python/Go/Rust/.NET/JVM to `--skills`;
`CC_REMIND=off` works; `remind.sh` word-boundary fix live; `detect-analyzers.sh`
premise sound.

**Delete:** `skill-router/rules.tsv:100` — `**/components/** → tailwind-best-practices`,
the only stack row with no marker; fires on a Go module. Replace with a
`package.json~"tailwindcss"`-marked row.

### 3.4 Design

> This marketplace can DECIDE a design and RECORD a design system but cannot SEE one.

Anchors beyond the table: the 1,683/13,951 extractor measurement re-verified by hand;
`stat -f %Sm` on both corpora matching the gate's printed dates; `grep -rn design-kit`
in craft-layer and ui-ux both zero; the five direct `python3 …` calls that undercut the
"one permission rule" sentence.

**Clean (and executed, not read):** design-kit preview server (200/200/404/`--stop`),
decision channel (header → 200, no header → 403, `dk decision --latest`, `dk status`),
`dk board` + `dk export --png` rendered correctly — a non-coding designer gets a real
picture with no project; `unread-pick.sh` exit 0 all paths; `palette-default.sh` fires
and one-shots; `divergence.mjs` utility-palette and `contrast.mjs` ("NOT MEASURED IS A
FAILURE HERE") honest; craft-suite README budget matches `context-budget.sh`; design-kit
shells avoid the accent they critique; nothing scratch ships; `dataviz` correctly cited
as host-bundled.

**Delete:** `plugins/craft-layer/template/craft-gates/fixture-*.html` — 12 files, 64K,
shipped to every installer, read only by the repo's own test harness, inside the one
directory the audit says never to copy. Move to `scripts/__tests__/fixtures/`.

### 3.5 UI/UX

> The UI plugin's knowledge is unusually good and its mechanisms unusually absent.

Anchors beyond the table: the 30-var count and the five that break the `CC_`
convention (`CLAUDE_DESTRUCTIVE_GUARD`, `CLAUDE_AI_TRAILER`, `CRAFT_BOOST`,
`ORCHESTRATION_BOOST`, `TASKMASTER_BOOST` in a task-runner hook) and the seven-way
value vocabulary; `context-budget.sh` listing statuses (craft-suite OVER, core-suite
OVER, workflow-suite OVER, frontend-suite NEAR 103%) against README:93's two-bundle
parenthetical and README:168-173's no-suite list omitting design-kit.

**Clean:** ui-ux's four AskUserQuestion sites are the house standard;
`preview-guard.sh` correctly tiered ("gate, with a human in it"; endgame §7 C2 fixed)
and names its off-switch in both reasons; `palette-default.sh` honest;
tailwind skill is the strongest in the lane; command-guard's message surface is the
model (why + safer alternative + overrides); dark mode covered non-obviously; all six
new 2.2 AA criteria present; `done-gate.sh` is repo-internal only; ~10 `.claude/<plugin>/`
dirs self-ignore.

**Delete:** `plugins/ui-ux/skills/design-tokens/SKILL.md` — `stack-skill-baselines.md:23`
records the control arm producing a token scale + `color-mix` derivation unaided.
Conditions: fold the two paragraphs the control did not produce into `theming-system`,
and measure once before removal.

### 3.6 Architecture

> Every mechanism is built with care; every defect lives in the seams, because the
> repo gates artifacts individually and has almost no gate on the contracts they share.

Anchors beyond the table: live repro of the resurrected directory; the 133 = 133
vocabulary count; the `$TMPDIR/cc-security-scan/Users/me/…/1825687969_92` path;
the dead-session sentinel muting `unread-pick` while `remind.sh` spoke and deleted the
file; the `ask` + `deny` collision on one constructed command; the 6,784 / 5,071 / 1,713
char split of `route-prompt.sh`; live 2.1.278 constants (`0.01`, `4`, `200000`, `1536`)
matching the repo's model; `divergencePreamble` in 0 of 10 samples.

**Clean:** UserPromptSubmit fan (13 hooks) 0.82s sequential, PostToolUse (15) 0.57s,
≈0.48s parallel — the listing budget is the scaling wall, not hook time; 57
registrations, none without timeout; portability (no bash-4isms, `sed -i.bak`,
guarded `sort -V`, portable `timeout` wrapper); bundles have no cycles and
workflow-suite ⊃ core-suite is documented both ways; three `yields_to` cycles all
cross-territory and coherent; dual-event hooks branch correctly; the
candor↔task-runner coupling is the best-defended cross-plugin contract in the tree
(`gate.sh:171-182`, `:242-250`, `:164`); two Stop hooks both self-bounded; all 14
escape markers honoured in code; listing cost model verified against the binary;
51 docs carry installed/absent clauses; the marketplace clone contains `rationale/`,
`scripts/`, `templates/` so repo-path references resolve for an installer.

**Delete:** the 60-row command catalog inside `skill-router/hooks/route-prompt.sh` —
not the hook, not its protocol — a truncated copy of the host's own listing that grows
linearly with plugin count.

---

## 4. Deletion candidates, and where they conflict

Six proposals. Two need a decision before either lands:

- **UI/UX proposes deleting `ui-ux/skills/design-tokens`** on a neighbouring
  control-arm measurement; **Design proposes pointing `design-tokens` at
  `type-system.md`** so the static type contract is reachable. Both agree the file's
  scale content is shape 2. The reconciled path is Design's fold plus UI/UX's
  condition: move the type-system pointer and the two non-control paragraphs into
  `theming-system`, measure once, then remove. Neither specialist saw the other's
  proposal.
- **Software's single eval run** (finding 61) could target `solid-principles` or
  `estimation`; Software itself says the latter is cheaper to retire if the delta is
  zero. Pick one; do not run both.

The other four (`idempotency-only-ts`, `rules.tsv:100`, `fixture-*.html`, the
route-prompt catalog) do not conflict with anything and each has a stated residual.

---

## 5. Still open since a prior review

Items a specialist found that an earlier document already recorded. They are listed
so the next reviewer does not re-discover them a third time.

| item | first recorded | found again by |
|---|---|---|
| Unvalidated `cwd` `mkdir` in hooks | trend audit 2026-09-16 H6 | Architect 1 |
| `write-scan.sh` matcher `Write\|Edit\|MultiEdit` only, IDE-MCP bypass | endgame 2026-09-14 §5.7 | Web 2 |
| Cross-hook precedence undocumented | endgame residual 1 | Architect 6 |
| Phase sentinel prose-only writers | endgame residual 3 | Architect 11 |
| Four of seven ui-ux skills unrouted | endgame §5.11 / B9 | Design 11, UI/UX 7 |
| `/skill-doctor` in no README | trend audit §4 "Lags", T6 | Ops 6, UI/UX 9, Architect 9 |
| Literal-colour drift check, before/after screenshots | design-kit ideas 2026-09-22 §7, §8 | Design 4, 5 |

---

## 6. What the panel did not propose, on purpose

Every specialist read `measured-zero-shapes.md` and refused at least one obvious ask:

- No `terraform-best-practices`, `python-best-practices`, `svelte-best-practices`,
  `angular` or `incident-response` skill. Each is a named shape. Where a lane was
  missing, the proposal is a mechanism (a plan reader with an exit code; a persisted
  rollout file; a runner branch in an existing gate) or an honest hand-off.
- No CHANGELOG backfill for resilience — start at the current version.
- No widening of secret-scanning's generic `{24,}` rule — the under-flag posture is
  correct; the DSN pattern is shape-only.
- No new `doctor` command — three README lines naming the instruments already on disk.

---

## 7. What was and was not verified

- Each specialist ran the hooks and gates it cites; the "Checked and clean" lists are
  executed results, not readings. Design executed the preview server, decision channel,
  board build and PNG export.
- **PLAUSIBLE, not executed:** that `npx playwright test` resolves no tests from the
  plugin dir (no playwright binary on this machine); that the terraform plan reader
  would clear the eval bar; that a persisted rollout file changes an incident outcome;
  the `/stack-scan:audit` behaviour (read from the command text, not driven with a
  model).
- The main session did not independently re-run every anchor. Three specialists
  corrected their own citations mid-run (a bare `lane.tsv`, a bare `audit.md`, a bare
  `gate.sh` each resolved to the wrong plugin); the corrected paths are what appears
  here. A reader acting on a finding should open the cited line first.
- Nothing was edited. `git status --porcelain` was empty after every agent finished.
