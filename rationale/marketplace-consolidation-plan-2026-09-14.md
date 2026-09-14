# Marketplace consolidation plan — 2026-09-14

**Question asked:** make the marketplace lean — merge what is mergeable, remove what
is redundant — while still tackling any software task, and say how it differs from
what the ecosystem ships.

**Standing of this document: `recorded`.** Nothing reads it back. Every number
carries a recount command. Waves 0–3 were executed on this branch on 2026-09-14
(records in §8; two of wave 2's six items and two of wave 3's four were declined on
measurement — §4.3, §4.4, §4.6 and §3.1's overseer row say why); wave 4 is not, and
§8 says what it measures.

**Method.** Six read-only reviews fanned out over the tree on branch
`feat/marketplace-consolidation-plan`: UI/UX, architecture, team lead, developer
(backend + frontend), QA, and a market scan of comparable collections. Their raw
outputs are not preserved; the claims below were checked against the tree before
being kept. Where two lenses disagreed, §7 records the disagreement and the pick.

---

## 1. Snapshot

| measure | value | recount |
|---|---|---|
| plugin dirs | 45 = 37 leaves + 8 suites | `ls -d plugins/*/ \| wc -l` |
| skills / commands / agents | 111 / 80 / 32 | `ls plugins/*/skills/*/SKILL.md \| wc -l` etc. |
| listing entries (skills + commands) | 183 ≈ 43,100 chars, 7.2× the 6,000-char floor | `bash scripts/context-budget.sh` (listing section) |
| bundles OVER the listing floor | 7 of 8 | same |
| always-on tokens, all leaves | ≈ 11,850 | `scripts/context-budget-baseline.json`, sum of non-suite keys |
| review-shaped commands | 23 of 80 | §5 |
| plugins with a hook file | 26 of 37 | `ls -d plugins/*/hooks \| wc -l` |
| plugins with `evals/` | 3; control-armed runs: overseer only | `ls -d plugins/*/evals` |
| prior consolidation | 52 → 36 leaves on 2026-09-02 | `rationale/2026-09-02-web-dev-merge.md` |

---

## 2. The finding that reframes the ask

**A plugin directory costs nothing. Skills and commands cost.** Both meters in this
repo — `plugin_desc_bytes` in `scripts/context-budget.sh` and `pc_listing_entry_cost`
in `scripts/lib/plugin-checks.sh` — charge `name + 4 + min(description, 1536)` per
skill and per command. A leaf merge that moves artifacts without deleting any saves
≈ 0 chars; the `plugin:` prefix is the only thing that changes length.

So "fewer plugins" is the wrong objective function. The lean levers, ranked by
measured effect:

1. **Fewer commands.** 80 commands are 72 listing entries ≈ 11,000 chars, 26% of the
   listing, for wrappers the house pattern defines as thin entry points over a skill.
2. **Fewer skill entries.** Fold per-library and per-concern satellites into one
   skill's `references/` (unmetered).
3. **Fewer hooks on the same channel.** 12 PostToolUse entries across 8 plugins fire
   on one `Edit`; 11 UserPromptSubmit hooks across 10 plugins fire on every prompt.
4. **Fewer leaves** — for maintenance (plugin.json, README, CHANGELOG, uninstall path,
   version churn, lane authority), not tokens. Still worth doing; do not sell it as a
   token win.

Bundles are near-free (`rationale/marketplace-necessity-review-2026-08-26.md` §8e)
and no comparable collection ships them (§6). They are a packaging bet, not a cost.

---

## 3. Target topology

**37 leaves → 26. 8 bundles → 4. 183 listing entries → ≈ 120 (estimate; recount after
each wave).**

### 3.1 Mapping, today → target

| today | target | what moves | what a user loses |
|---|---|---|---|
| `payments` | **removed** | its skill body was `measured-zero-shapes` shape 2 (first slide of every talk); `security` already owns webhook/secret handling | a name to install; one router row (rewrite to `security-review`) |
| `llm-app` | **removed** | defers provider facts to the host's built-in `claude-api`; the rest is eval/RAG checklist | same |
| `system-design` | → `code-architecture` | `system-design` + `domain-modeling` skills and the `system-architect` agent; `event-driven` → `resilience` | `/system-design:review` name |
| `orchestration` | → `task-runner` | `delegation-contracts` (already read by path from task-runner), `verification-panels`; `ultra-assess` body → reference; boost hook re-rendered from the `boost-hook` chassis type | nothing: it ships zero agents, its doctrine is read by path today |
| `overseer` | → `taskmaster` — **declined on measurement (wave 3)** | 1 skill, 3 commands, 2 hooks, the eval suite | standalone install; it already pins taskmaster ≥ 0.42.1 and task-runner ≥ 0.32.0 as hard prerequisites. Executed and reverted: with the overseer skill and its six references moved in, taskmaster's on-invoke prose corpus measured 209,652 B against the 160,000 B ratchet in `scripts/plugin-corpus-baseline.json` ("never raise it to make a build pass"); task-runner, the other candidate, is at 155 KB itself. Fitting it means cutting ~50 KB of taskmaster's or overseer's prose blind — a wave-4 ablation decision, not a packaging one. The merge attempt is recoverable from the branch's stash |
| `plugin-scout`, `vercel-skills-scout` | → `stack-scan` | one manifest pass, two suggestion modes; `catalog.md` generation step follows | vercel's deliberate absence of `--yes` becomes a mode flag, not a plugin boundary |
| `theme-design`, `design-lab` | → **`design-studio`** (new name) | both preview servers, the registry MCP, `pending-events.sh`, the serve harness | someone wanting only the registry MCP installs the 728-line Python bridge too |
| `terse` | → `candor` | `mode.sh` (UserPromptSubmit shape hook), `terse-output` skill, `/check`; drop `terse-crew`, `terse-compress`, `terse-commit` and all three terse agents (`terse-reviewer` collides with `code-review:code-reviewer` on the identical `owns`) | `/terse:commit` (host `commit-commands` covers it), `/terse:compress` |
| `lean` | **removed** | its PostToolUse fires on every edit with no path or content filter — the doctrine-injection shape that measured negative; `/simplify` is a host built-in | 73 always-on tokens of pricing doctrine |
| `fresh-take` | → `approaches` | consultant agent + stuck-loop UserPromptSubmit hook; both are `decide`-phase blind second opinions | standalone install |
| `resilience` | **kept**, 5 commands → 1 `/resilience:review [--concern]` | `event-driven` arrives from system-design | per-concern slash names |
| `approaches` | **kept**; trim → wave 4 (measure first) | drop `estimation`, `pattern-selection`, `rollout-planning`, `build-vs-buy` skills (checklists); keep `approach-deliberation` (marker mechanism) + `opinions` | four checklist skills |
| `code-architecture` | **kept**; skill fold → wave 4 (measure first); the gate move is done | drop `solid-principles`, `yagni-check`, `low-cognitive-load` as entries (fold to one reference); `evidence-gate.sh` clause moves to the unified Stop gate (§4.2) | three slash names |
| `ui-ux` | **kept**; 12 skills → 8 is wave 4 (measure first); `/ui-ux:review` removal is done | `tailwind-best-practices` removed; `reui` + `aceternity` + shadcn's two live paragraphs fold into `component-libraries`; `/ui-ux:review` removed as entry (fan-in loads the skill) | one loose router glob (`**/components/**`), which mostly fired as noise |
| `craft-layer` | **kept**; 14 skills → 9 is wave 4 (measure first) | `interaction-fx`, `physics-motion`, `kinetic-typography`, `page-transitions` → `motion-tiers/references/`; `webgl-effects` → `threejs-best-practices` | five entry names; bodies survive as references |
| `laravel`, `web-dev`, `database` | **kept**, `/…:review` removed as entries | the fan-in already loads their skills | a cheap single-rubric pass without the full fan-in |
| `testing`, `devops`, `api-design`, `security`, `debugging`, `git-workflow`, `code-review`, `stack-scan`, `command-guard`, `secret-scanning`, `skill-router`, `hindsight`, `brain`, `ultra-deep-research`, `taskmaster`, `task-runner` | **kept** | see §4 for the mechanism changes inside them | — |

### 3.2 The 26 leaves, by what earns them

- **Guards, 3:** `command-guard`, `secret-scanning`, `skill-router` (0 metered).
- **Session, 3:** `candor` (+terse: shape hook, honesty Stop gate), `hindsight`, `brain`.
- **Workflow, 5:** `taskmaster` (+overseer), `task-runner` (+orchestration),
  `approaches` (+fresh-take), `code-architecture` (+system-design), `git-workflow`.
- **Review and verify, 3:** `code-review` (the one review surface), `testing`, `debugging`.
- **Stack and domain, 8:** `laravel`, `web-dev`, `database`, `api-design`, `security`,
  `devops`, `resilience`, `stack-scan` (+plugin-scout +vercel-skills-scout).
- **Design, 3:** `ui-ux`, `craft-layer`, `design-studio`.
- **Research, 1:** `ultra-deep-research`.

Seven of the eight stack/domain leaves earn their place on a hook, script, agent, or
router row, not on a skill body — the developer lens classified 22 of their 34 skill
bodies as checklists the model already knows. They stay because the mechanism stays;
the bodies are the ablation queue (§8, wave 4).

### 3.3 Bundles, 8 → 4

| bundle | members | replaces |
|---|---|---|
| `core` | skill-router, command-guard, secret-scanning, candor, code-review, git-workflow, stack-scan | always-on-suite, quality-suite |
| `workflow` | core + taskmaster, task-runner, approaches, code-architecture, testing, debugging | process-suite, taskmaster-suite, quality-principles-suite |
| `frontend` | ui-ux, web-dev, code-review, skill-router | frontend-suite |
| `craft` | craft-layer, design-studio, ui-ux | craft-suite |

`php-suite` is dropped: its three members are the wrong three for a Laravel developer
(it omits `database`). Backend leaves stay install-by-name, as 09-03 decided.

---

## 4. Mechanism changes (the part that is not packaging)

### 4.1 Fix the review fan-in before removing any review command

`plugins/code-review/commands/review.md:36-41` names web-dev, ui-ux, laravel and
database skills. Five commands assert "the aggregator reaches this plugin's rubric":
`testing`, `devops`, `payments`, `llm-app`, `craft-layer` — and it does not. A mixed
diff with tests silently loses the test rubric today. `resilience` is a mutual-deferral
loop: the fan-in defers concern-axis findings to resilience as owner; resilience hands
the whole scope back. **Order matters:** extend the fan-in's load list first, then
delete the entry points. Recount: `grep -ln 'aggregator reaches' plugins/*/commands/*.md`.

### 4.2 One Stop gate, three clauses

`candor/hooks/gate.sh` (message: unresolvable `file:line`, retraction without a tool
call), `code-architecture/hooks/evidence-gate.sh` (tool sequence: claim after mutation
with nothing executed), `task-runner/hooks/completion-gate.sh` (on-disk run records).
Non-overlapping clauses; none uses `${CLAUDE_PLUGIN_ROOT}` internally; the two survivors
already special-case each other's `stop_hook_active`. Merge into `candor` (the only
plugin registering `SubagentStop`), one marker namespace keyed by claim-hash + HEAD +
agent suffix. The task-runner clause stays dormant outside a registered run, as today.
Three harnesses go red and are rewritten: `scripts/smoke/{evidence-gate,completion-gate}-hook-tests.sh`,
`plugins/candor/scripts/__tests__/gate.test.sh`.

### 4.3 One PostToolUse envelope per plugin, and one fewer plugin on the channel

`code-review` runs four PostToolUse scripts (`conventions`, `scan`, `density`,
`verbosity`) and runs `scan.sh`/`density.sh` twice per edit (`hooks.json:15` and `:42`).
Three of them end in the same sentence. Collapse to one script, one envelope. Remove
`lean/hooks/budget.sh`. A quality-suite first edit drops from 7 advisories to 3.
Measure with the §6.9 fixture from `plugin-landscape-review-2026-09-10.md` before and
after; that fixture is still unrun.

**Declined on measurement (wave 2, 2026-09-14).** The §6.9 fixture was run: a first
`Write` of a comment-heavy `.tsx` into a repo with `.editorconfig`, a CI workflow and
three sibling components, against every PostToolUse Edit|Write adviser in the tree.
code-review emitted **2** envelopes (conventions 532 B, scan 255 B; density and
verbosity silent), not 7; the whole eight-adviser stack emitted **3** (skill-router's
route added 635 B), 1.4 KB in all. The `scan`/`density` "twice per edit" is the
PreToolUse deny lane and the PostToolUse warn lane of one detector, not a duplicate.
A dispatcher would turn two envelopes into one with identical bytes, at the cost of a
new script, a hooks.json rewrite and harness churn across three smoke files. Not
done. `lean/hooks/budget.sh` went with lean in wave 1.

### 4.4 One UserPromptSubmit aggregator

Four `remind.sh` copies (api-design, approaches, debugging, fresh-take) are 205-line
chassis outputs differing only in regex and message; taskmaster's is 213. Move the
rule rows into `skill-router/hooks/route-prompt.sh`, which owns the event and costs 0
listing chars. A `workflow` install goes from 7 processes per prompt to 2.

**Declined on measurement (wave 2, 2026-09-14).** Ten runs each of the five reminder
hooks on one work-shaped prompt: 39–55 ms per hook, ~230 ms if run serially (the host
runs hooks concurrently, so less). `route-prompt.sh` itself took 533 ms per run — the
proposed home is the expensive process, not the ones it would absorb. What the move
would cost: every plugin installed without skill-router loses its nudge (the lane
doctrine in CLAUDE.md rejects privileging skill-router for exactly that reason), and
the arc rank, phase guard, extraGuard and self-echo logic the chassis template carries
would be re-implemented inside the router. The process count is not a cost a user
can see; the capability loss is. Not done. The chassis stays the mechanism, and
wave 2 used it once more: approaches now renders two reminder hooks from one
manifest (`file` key on the reminder-hook object).

### 4.5 Hand-copied hooks — corrected on execution

**Correction (wave 0, 2026-09-14).** The architecture lens claimed the three boost
injectors bypass the `boost-hook` chassis. They do not: all three carry the
`generated from templates/boost-hook.sh.tmpl` header and their `.chassis.json`
entries drive them (`plugins/craft-layer/.chassis.json`, `taskmaster`, `orchestration`).
The 8-line diff between them is the manifest payload. Nothing to do.

**Declined: `write-guard.sh.tmpl`.** The six PreToolUse write guards share a 15-line
prelude (read input, `jq` check, tool filter, text extraction) and a 4-line emit tail.
Everything between is bespoke — `database/hooks/guard.sh` has three detection stages
and a NoSQL branch, `devops/hooks/workflow-guard.sh` is an `awk` state machine. A
template would carry 40–350 lines of quoted bash per guard inside a JSON string, which
is less maintainable than six readable scripts sharing a convention. When a guard
moves plugins in wave 2, `${CLAUDE_PLUGIN_ROOT}` is not referenced inside any of them
(checked: `grep -l CLAUDE_PLUGIN_ROOT` over the six returns none), so the move is a
file move plus a `hooks.json` row. The byte-identical `preview-guard.sh` twins (ui-ux,
taskmaster) stay: their in-source argument (`ui-ux/hooks/preview-guard.sh:46-58`)
holds and was re-checked.

### 4.6 Worker agents, 10 → 7

Ten agents are byte-generated from `templates/worker-agent.md.tmpl` with identical
tools, model and effort. Collapse the four whose procedure is generic detect → read →
implement → verify (`web-developer`, `backend-engineer`, `database-engineer`,
`devops-engineer`) into one `implementer` worker with a stack parameter. Keep the five
with a real `domainChecklist` or refusal constraint (`security-engineer`,
`test-engineer`, `a11y-engineer`, `ui-ux-engineer`, `performance-engineer`) and
`observability-engineer`'s lane edge. Lost: per-domain PROACTIVE auto-dispatch text.

**Declined on inspection (wave 3, 2026-09-14).** The premise does not survive the
manifests. Two of the four carry a refusal constraint — `database-engineer` ("stop and
ask" before DROP/TRUNCATE/mass DELETE without a confirmed backup) and `devops-engineer`
("never store credentials … flag it, do not move it") — which is the section's own
keep-criterion, so the collapse is 10 → 9 at most (`web-developer`, `backend-engineer`),
and that leaves a Laravel install with no proactive worker unless it also installs
web-dev. The stack-parametrised implementer already exists: `task-runner:task-executor`
is the delegatable sink that reads a pinned skill by path. The saving: the four
descriptions total 854 B ≈ 212 always-on tokens, and only on an install that carries
all four leaves, which no bundle produces; a single `implementer` description would give
back ~60. Recount: `grep -m1 '^description:' plugins/{web-dev,laravel,database,devops}/agents/*.md | wc -c`.

### 4.7 Declare the phases that have no owner

Lane histogram: `plan` has zero rows repo-wide while `plan-before-code`,
`/code-architecture:plan` and `task-cards` all do plan work; `ship` is owned only by
suite uninstall commands while `git-workflow:finish` is undeclared; `task-runner:behavioral-gate`
and `code-architecture:work-verification` are undeclared in `verify`. Fix in the same
PR as each plugin's merge.

---

## 5. Review surface after the plan

One entry, `/code-review:review`, loading (not deferring to) every installed rubric.
Kept standalone because each carries procedure the fan-in does not: `/security:review`
(audit folding, threat-model disposition), `/ui-ux:audit` (WCAG procedure with a
re-audit loop), `/api-design:drift` and `:check`, `/testing:flake-hunt`, `/stack-scan:audit`,
`/resilience:review --concern` (a design doc with no diff). Reviewer agents 11 → 6:
`code-reviewer`, `frontend-reviewer` (opus floor), `architecture-reviewer`,
`devops-reviewer`, `craft-reviewer`, and the adversarial panel persona.
Removed as entries: `web-dev:review`, `database:review`, `laravel:review`,
`ui-ux:review`, `payments:review`, `llm-app:review`, `system-design:review`,
`orchestration:review`, four of five `resilience:*-review`, `terse:check` (→ candor).

---

## 6. How this differs from the ecosystem (scan of 2026-09-14)

| collection | size | unit | hooks | bundles |
|---|---|---|---|---|
| this repo | 37 leaves, 111 skills, 80 cmds, 32 agents | plugin + bundle | 26 of 37 leaves | 8 |
| `anthropics/claude-plugins-official` | 296 entries; 39 first-party dirs with 25 skills / 29 cmds / 32 agents total | narrow plugin, median 2 files | yes (security-guidance, hookify, ralph-loop) | **0** |
| `obra/superpowers` | 14 skills, 0 cmds, 0 agents, 1 hook | one plugin, skills only | 1 | 0 |
| `wshobson/agents` | 92 plugins, 202 agents, 183 skills, 105 cmds | small domain plugins | 2 plugins | 0 |
| `davila7/claude-code-templates` | 899 skills, 393 cmds, 155 hook files | per component | yes | 0 |
| `melodic-software/claude-code-plugins` | 77 plugins, 273 skills | plugin | 20 plugins | 0; hit the listing budget (163 skills, issue #3505) |
| Vercel skills.sh | one skill = one install; "packs" since 2026-08 | skill | no | packs (skills, not plugins) |

Sources: the six repositories' `.claude-plugin/marketplace.json` and trees as fetched
2026-09-14; `code.claude.com/docs/en/skills`; melodic-software issue #3505 and PR #3767.

What it means:

- **We are mid-size by plugin count and the densest by mechanism.** 3.0 skills per
  leaf against the official first-party 0.64; 26 of 37 leaves ship a hook against
  wshobson's 2 of 92. The differentiators the scan found nowhere else, packaged:
  `candor`'s citation-resolving Stop gate, `command-guard`'s classifier over Bash and
  MCP shell/SQL, `skill-router`'s file-aware routing, taskmaster's card-level
  `verify-teeth` and `coverage-check`, overseer's multi-session program loop with
  browser-proven acceptance, craft-layer's ordered motion-tier procedures, hindsight's
  recurrence-gated harvest. Every one is a mechanism. Every one survives this plan.
- **Prose-only leaves compete with larger, better-maintained prose.** The eleven with
  zero hook files (`design-lab`, `laravel`, `llm-app`, `payments`, `plugin-scout`,
  `resilience`, `stack-scan`, `system-design`, `ultra-deep-research`,
  `vercel-skills-scout`, `web-dev`) overlap wshobson's domain plugins near-completely.
  This plan removes or merges six of them and keeps five on an agent, a script, a model
  floor, or a router row.
- **Direct third-party equivalents, route instead of ship:** `vercel-skills-scout` →
  `find-skills` (the most-installed skill on skills.sh); `lean` → host `/simplify`;
  `hindsight:claude-md` → official `claude-md-management` (already ported once,
  now duplicated maintenance); `brain` → `serena` is stronger but not the same shape
  (committed map vs live LSP), so `brain` stays install-by-name.
- **Nobody else ships dependency bundles.** Keeping four is a deliberate departure,
  justified only by the measurement that a bundle's own marginal cost is ≈ 0 and that
  the alternative (users composing ten plugins by hand) is what melodic-software's
  listing overflow looks like.
- **The eval runner is no longer the blocker.** `claude plugin eval --ablation
  with-without` ran on this account on 2026-09-13 (`plugins/overseer/CHANGELOG.md:17`),
  n=1, haiku judge. CLAUDE.md still says "early-access gated"; that line is stale.

---

## 7. Where the lenses disagreed, and the pick

| question | positions | pick, and why |
|---|---|---|
| `theme-design` → `ui-ux` or → `design-lab`? | architecture: ui-ux; UI/UX: design-lab, renamed | **design-lab** — the overlap is the preview surface (four claimants), not the token pipeline; the write path is already single-owner (`/ui-ux:theme`) |
| merge terse + candor + lean? | team lead: one `session-hygiene` plugin; architecture: no (drags 848 tokens into bundles that refused it); market: lean → `/simplify` | **candor absorbs terse; lean removed.** The bundle-cost objection dissolves once the bundles are rebuilt (§3.3); lean's hook is the one shape measured negative |
| `overseer` → `taskmaster`? | team lead: yes (hard prerequisites both ways); market: keep, it is a differentiator | **merge, last** (wave 3). Differentiation is about the mechanism, which survives the move; a cross-plugin version pin is the merge argument |
| split `code-architecture` three ways? | team lead: yes; architecture: absorb system-design into it | **absorb, do not split.** Its ordered procedures (`plan-before-code`, `work-verification`, `drift-review`) are one discipline; only the Stop clause moves (§4.2) |
| `stack-scan` → `plugin-scout` or the reverse? | developer: keep stack-scan standalone (transitive licence scan, lockfile truth); team lead: stack-scan owns all three | **stack-scan owns**; the one recorded blocker (always-on-suite over the 6,000 floor) is already true today with the fraction escape declared |
| kill all bundles? | market: yes; architecture and necessity §8e: no, they are free | **4 bundles.** Free to ship, and the composition burden they remove is the documented failure mode elsewhere |
| remove `resilience`? | developer: all five bodies are checklists; QA: it owns the concern axis the fan-in hands it | **keep, 5 commands → 1, bodies to the ablation queue first.** Tier-2 by cost, Tier-3 by shape — the worst quadrant, and the first ablation target |

---

## 8. Execution order

Each wave is one or more PRs; each PR runs the four gates, the smoke set and
`official-validate.sh` per CLAUDE.md. Baselines are updated per plugin with
`--update-baseline`, never blanket.

**Wave 0 — no merge. Executed 2026-09-14 on this branch.** Fan-in load list and the
resilience deferral loop fixed in `plugins/code-review/commands/review.md`
(0.18.0, changelog entry). CLAUDE.md's eval-gating paragraph corrected. The two
chassis items were dropped on inspection — §4.5 says why.

**Wave 1 — independent, one PR each, zero hook movement.** `payments` removed ·
`llm-app` removed · `system-design` → `code-architecture` (+ `event-driven` →
`resilience`) · `vercel-skills-scout` + `plugin-scout` → `stack-scan` · `lean` removed
· `resilience` 5 → 1 command · four `/…:review` entries removed (after wave 0's fan-in
fix). Sequence the two `code-architecture`-touching PRs; do not parallelise them.

**Wave 1 — executed 2026-09-14 on this branch, six commits, every gate and harness
green at each.** What shipped, and where it deviated from the row above:

- `lean`, `payments`, `llm-app` removed (`3301c87`). `lean` is deliberately NOT in
  `pc_removed_refs`' list — the token is overseer's rigour tier and taskmaster's
  `goal-lean`; the residual is stated in the check's header.
- `system-design` → `code-architecture` 0.14.0, `event-driven` → `resilience` 0.5.0
  (`db97e51`). `architecture-reviewer` absorbs the read-only reviewer; the
  `system-architect` opus floor moves with it.
- `plugin-scout` + `vercel-skills-scout` → `stack-scan` 0.7.0 (`65f31f4`). Both skills
  keep their names behind one `/stack-scan:suggest`; `--skills [query]` is the
  third-party mode and refuses every plugin-mode flag, so the no-auto-install floor
  is a mode rule. `pc_pick_parity` retired — one picker copy, nothing to keep in step.
  `always-on-suite` 0.5.0 and `process-suite` 0.11.0 install stack-scan in the scouts'
  place. Net always-on for a set that had all three: −13 tokens.
- `resilience` 0.6.0: five commands → `/resilience:review [--concern
  failure|errors|concurrency|observability|performance|events|all]` (`0f7db15`).
  Six rubrics, not five — `event-driven` arrived in item C. Without the flag it loads
  `resilience-design` and adds each rubric whose surface the scope touches, naming
  the loaded set in its Checked line. −111 always-on, −78 on every dynamic channel.
- `/web-dev:review`, `/laravel:review`, `/database:review`, `/ui-ux:review` retired
  (`be81b86`). `web-dev` 0.7.0, `laravel` 0.8.0 and `database` 0.8.0 now ship no
  command at all — skills, workers, and database's guard — which the row above did
  not say out loud. The router's stack-relevance filter keeps working on the stack
  reviews that remain (devops, api-design); its harness moved to those.

Recount after wave 1 (the §10 commands): 39 plugin directories = 31 leaves + 8
bundles; 68 commands; 108 skills; 31 agents; always-on total 11,243 tokens
(`bash scripts/context-budget.sh | grep ^TOTAL`). Bundles are untouched until wave 3.

**Wave 2 — hooks move, go together.** `theme-design` + `design-lab` → `design-studio`
(one PR; both are craft-suite members) · `terse` → `candor` and the unified Stop gate
(§4.2) in one PR · `fresh-take` → `approaches` · `orchestration` → `task-runner` ·
the UserPromptSubmit aggregator (§4.4) · code-review PostToolUse collapse (§4.3).

**Wave 2 — executed 2026-09-14 on this branch, four commits, every gate and harness
green at each; the two hook collapses declined on measurement.** What shipped, and
where it deviated from the row above:

- `theme-design` + `design-lab` → **`design-studio`** 0.5.0 (`616b6e0`). A rename
  plus a merge: theme-design's tree is the base, design-lab's `real-preview` skill,
  `/preview` command, registry MCP servers and cleanup harness moved in. The session
  working directory is `.design-studio/` (an open `.theme-design/` session is not
  resumed — stated in the changelog). `lane.tsv` carries the edge both READMEs had
  stated for two releases and no lane held: the preview yields to a running session.
  craft-suite 0.6.0 has three members. Always-on 793 = 194 + 599, no saving; the
  win is one install and one name for three surfaces that decide how a thing looks.
- `terse` → **`candor`** 0.3.0 and the unified Stop gate (`b3e6b33`). `gate.sh` has
  four clauses: the two it had, plus code-architecture's evidence-at-claim (clause 3)
  and task-runner's registered-run gate (clause 4), byte-equivalent vocabularies,
  messages, env overrides and per-HEAD nudge; the two source scripts are deleted and
  their harnesses (30 + 70 cases) drive the one script. The three-script namespaced
  disarm protocol is gone — the record names the clause that blocked. terse's mode
  hook, SessionStart card, `terse-output` skill, `/candor:level`, `measure.sh` (behind
  `/candor:check --brevity`, automatic while a level is on), statusline and
  `shrink.mjs` moved; `terse-crew`, `terse-commit`, `terse-compress`, the three crew
  agents and `/terse:commit`/`/terse:compress` were dropped per §3.1. Consequence
  the row did not state: code-architecture 0.15.0 and task-runner 0.33.0 ship no Stop
  hook, so their done-time rules have teeth only with candor installed —
  taskmaster-suite 0.18.0 and process-suite 0.12.0 add candor for that reason, and
  always-on-suite 0.6.0 drops terse. quality-suite crossed the 6,000-char listing
  floor (6,742) and declares it. Always-on total 11,243 → 10,572.
- `fresh-take` → **`approaches`** 0.7.0 (`0c40598`). `/approaches:consult`, the
  consultant agent, `brief-lint.sh` and its harness moved unchanged; the
  irreversible-command reminder is a second chassis reminder hook
  (`hooks/consult-remind.sh`, phase `any`), which needed one renderer change — an
  optional `file` key on reminder-hook objects, mirroring boost-hook. process-suite
  0.13.0. Always-on 500 → 624 (−1 net).
- `orchestration` → **`task-runner`** 0.34.0 (`1ee03a4`). Both skills and every
  reference moved with their names; `ultra-assess` is a reference of
  verification-panels (the boost directive names the path, so a listing entry was a
  second trigger); the boost hook re-rendered as `task-runner:ultra-assess`;
  `/orchestration:review` retired (it reviewed prompts, and what it ran is the lint
  plus the skill's checklist, both of which ship). taskmaster-suite 0.19.0 (10
  members), process-suite 0.14.0. Always-on 379 → 533 (−97 net).
- §4.3 and §4.4 **not executed** — the measurements are recorded in those sections.

Recount after wave 2 (the §10 commands): 35 plugin directories = 27 leaves + 8
bundles; 64 commands; 104 skills; 28 agents; 21 hook dirs; 9 plugins on
UserPromptSubmit; always-on total 10,474 tokens. The §3.2 target of 26 leaves is one
away: `overseer` → `taskmaster` is wave 3's.

**Wave 3 — bundles and the big merge.** Rebuild the four bundles; regenerate the
README table and `catalog.md`; `overseer` → `taskmaster`; worker agents 10 → 7;
declare the `plan` / `ship` / `verify` lane rows.

**Wave 3 — executed 2026-09-14 on this branch, two of four items; every gate and
harness green at each commit.**

- **Lane rows** (`0b95bc6`): `plan` — `/code-architecture:plan` → `plan-before-code`
  (which yields to `approaches:approach-deliberation` on shape), `/task-runner:plan` →
  `parallel-planning`, `taskmaster:task-cards` (yields to `plan-before-code`);
  `verify` — `/code-architecture:verify` → `work-verification` (yields to `candor:gate`,
  which enforces it at Stop), `task-runner:behavioral-gate`; `ship` —
  `/git-workflow:finish` → `branch-completion`. Command → skill pairs share `owns` with
  the command yielding, the pattern design-studio and api-design already used.
  Histogram after: plan 5, ship 6 (four suite uninstalls gone with their bundles), verify 9.
- **Bundles 8 → 4.** `core-suite` (renamed from always-on-suite, `git mv` so its
  changelog rides along; + `code-review` from quality-suite) and `workflow-suite`
  (renamed from taskmaster-suite; + `code-review`, `git-workflow`, `hindsight`,
  `secret-scanning`, `debugging`); `frontend-suite` and `craft-suite` already matched
  §3.3; `php-suite`, `quality-suite`, `process-suite`, `quality-principles-suite`
  deleted. Three deviations from the §3.3 table, each because a recorded rule with a
  reason beat a table row without one: the `-suite` suffix stays (renaming
  frontend-suite and craft-suite would churn installs for no mechanism);
  `command-guard` is NOT in core — always-on-suite 0.2.0 removed it because its ask tier
  overrides the host's command classifier with a permission click on every repo, and
  the plugin ships `deny-only` for the by-hand global install; `hindsight` IS in core
  (its ledgers live under `~/.claude`); `ui-ux` and `security` ARE in workflow —
  taskmaster-suite's inclusion test ("a member stays when the pipeline hard-wires it":
  the closed agent-tag set routes visual cards to ui-ux's agents, cards dispatch into
  security) predates the table. Listing: core 6,881 chars (fraction 0.02 at 200k),
  workflow 23,875 (0.04 at 200k; 0.80× the 1M budget). Bundle table and `catalog.md`
  regenerated; `pc_removed_refs` fed; marketplace 0.102.0 with the installer's record
  in the root CHANGELOG.
- **`overseer` → `taskmaster`: declined on measurement** — §3.1's row carries the
  numbers (corpus ratchet 209,652 B vs 160,000 B).
- **Worker agents 10 → 7: declined on inspection** — §4.6 carries the numbers.

Recount after wave 3 (the §10 commands): 31 plugin directories = 27 leaves + 4
bundles; 60 commands; 104 skills; 28 agents; 21 hook dirs; 9 plugins on
UserPromptSubmit; always-on total 10,474 tokens; 164 listing entries ≈ 35,100 chars
(from 183 ≈ 43,100). The §3.2 target of 26 leaves stands at 27: overseer stays a leaf
until wave 4 measures what taskmaster's or its own bodies are worth.

**Wave 4 — measure, then cut bodies.** `claude plugin eval --ablation with-without`,
n ≥ 3, on: the five `resilience` bodies, the four `security` bodies, the six ui-ux
per-library skills, `approaches`, `code-architecture`, `taskmaster`, and craft-layer's
four motion bodies (§3.1's 14 → 9). The §3.1 rows marked "measure first" are this wave's
queue, not done work. A zero result is a
result: fold the body to a reference and keep only what the control arm missed.
Also run the §6.9 advisory-stack fixture before and after wave 2.

**What goes red, by wave** (from the QA register): `pc_removed_refs` on every removed
name (feed `moved=` in the same commit; ui-ux carries 163 doc references, resilience 41);
`scripts/smoke/prompt-route-tests.sh:339-356` asserts literal command names and a
> 30-row catalog floor; `scripts/smoke/lanes-tests.sh:261-263` freezes an 8-reviewer
roster; `scripts/smoke/preview-guard-tests.sh:42-43` asserts the `# TWIN:` pointers;
`scripts/validate.sh:157` hardcodes `plugins/taskmaster/*|plugins/task-runner/*` in the
jargon skip; `plugins/overseer/scripts/__tests__/program.test.sh` asserts literal
cross-plugin names; `.github/workflows/validate.yml:93-98` guards plugin harnesses with
`[ -f ]`, so a deleted plugin's harness leaves CI silently.

---

## 9. Honest limitation

Every fold and removal above is argued from shape (`rationale/measured-zero-shapes.md`)
and structure, not from a control-armed run. The one measured shape that argues for
removal — checklist doctrine, zero or negative delta — is the shape of most of what is
removed, and the shapes that have never measured zero (hooks, gates, ordered procedures)
all survive. That is the strongest claim this document can make. Wave 4 is where it
becomes a measurement, and the runner that makes it possible ran on this account
yesterday.

## 10. Recount before quoting

```bash
ls -d plugins/*/ | wc -l                                   # 45
ls plugins/*/skills/*/SKILL.md | wc -l                     # 111
ls plugins/*/commands/*.md | wc -l                         # 80
ls plugins/*/agents/*.md | wc -l                           # 32
ls -d plugins/*/hooks | wc -l                              # 26
grep -ln 'aggregator reaches' plugins/*/commands/*.md | wc -l   # 13 claims; 4 are true
grep -c '"UserPromptSubmit"' plugins/*/hooks/hooks.json | grep -vc ':0'   # 10
bash scripts/context-budget.sh | grep -i 'listing'         # entries, chars, OVER/NEAR per bundle
```
