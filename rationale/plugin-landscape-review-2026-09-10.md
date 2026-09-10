# Plugin landscape review — 2026-09-10

**Question asked:** what the marketplace has, where plugins fail to reinforce each
other, what is missing, and what a plugin could do that none does today.

**Standing of this document: `recorded`.** Nothing reads it back. Every number
carries a recount command; every proposal names what a blind control would miss,
per `measured-zero-shapes.md`, because the last three ideas that skipped that step
scored zero.

**Method.** Full-tree inventory, the lane graph plus prose cross-references between
all 36 leaves, every hook's event and tier, the five prior reviews in this
directory checked recommendation-by-recommendation against the tree, and the
installed CLI (2.1.267) grepped for hook events the tree never names. Three
read-only survey agents fanned out; their raw outputs are not preserved, the
verified claims are.

---

## 1. Snapshot

| measure | value | recount |
|---|---|---|
| plugin dirs | 44 = 36 leaves + 8 suites | `ls -d plugins/*/ \| wc -l` |
| skills / commands / agents | 110 / 77 / 38 | `ls plugins/*/skills/*/SKILL.md \| wc -l` etc. |
| hook events used | 6 of at least 12 the CLI knows | §5 |
| leaves with `lane.tsv` | 30 of 36 | `ls plugins/*/lane.tsv \| grep -vc suite` |
| leaves with CHANGELOG | 15 | `ls plugins/*/CHANGELOG.md \| wc -l` |
| leaves with `evals/` | 2 | `ls -d plugins/*/evals \| wc -l` |
| skills unrouted by skill-router | 81 of 110 | CLAUDE.md's one-liner |
| leaves in no bundle | 6 | §3.4 |

**Prior-review debt is small.** Of the ~45 recommendations in the five reviews from
2026-08-02 to 2026-09-03, all but nine are DONE. The open nine are all explicitly
deferred (commands → `disable-model-invocation` skills, WARN→gate for commands and
skills, routing every skill, `license:` fields, a DMI-aware budget, the description
discrimination linter, MCP as an authoring extension point, time/timezone and
multi-tenancy coverage, `rationale/skill-evals.jsonl`). One deliverable was lost
rather than deferred: `references/pgvector.md` went out with the `postgresql` cut
and nothing carries it now (`grep -rl pgvector plugins` → empty).

---

## 2. Claims that drift from the tree

Cheap to fix, and each one is the has-teeth convention's own failure mode.

1. **`README.md` says "35 leaf plugins"; there are 36.** The count went stale when
   `theme-design` landed (0.1.0, yesterday). The bundle-table paragraph two screens
   lower already says 36. Same file, two numbers.
2. **`theme-design/README.md:67` tiers its hook row `gate`** and in the same row admits
   it is exercised "only by inspection". A gate with no executing harness is
   `recorded` by this repo's own table.
3. **`design-lab/README.md:58` argues "prose cannot fire there"** and ships no hook.
   Commands and an MCP server only. The argument is right; the plugin does not act
   on it.
4. **`craft-layer/README.md` describes an audit with gates** (`divergence.mjs`,
   `utility-palette`); `plugins/craft-layer/hooks/` holds one boost injector. Every
   craft gate is command-invoked. `ui-ux/hooks/palette-default.sh` documents the
   consequence: a plain "build me an app" turn runs neither, measured at 23 indigo
   utilities across 5 Blade views.
5. **`api-design`'s SessionStart matcher is `startup` only** and so is every plugin's
   except `approaches`. Not a claim drift, but the backlog's item #6 ("compaction
   behaviour is unverified, and two shipped mechanisms rest on it") is still open
   and now has a host lever aimed at it — §5.1.

---

## 3. Synergy gaps

The lane graph and prose cross-references were walked in both directions. No plugin
is a true island because `plugin-scout`'s catalog names all 36, so "isolated" below
means "nothing but the catalog".

### 3.1 Inbound orphans — nobody hands off TO them

| plugin | outbound | inbound | what the reverse edge would say |
|---|---|---|---|
| **candor** | lane edges to code-architecture, terse | 0 | `code-architecture`'s evidence gate and `terse:check` both have a `yields_to` FROM candor and never mention it. A reader of either cannot learn candor exists. |
| **theme-design** | ui-ux, design-lab | 0 | `ui-ux/README.md:91-95` and `design-lab/README.md` list their neighbours; neither lists the plugin that most overlaps them (§3.3). Also absent from `craft-suite`, which is the design bundle. |
| **brain** | 0 | 3 | Consumed by taskmaster's context-scout, orchestration, git-workflow (the first count of four included theme-design, whose only "brain" is a metaphor in its README); consumes nothing, and its README has no pairs-with section at all. §6.3 makes it a consumer. |
| **hindsight** | 0 declarative | 0 declarative | Four incidental mentions in other plugins' hook comments. No `yields_to`, no prose edge either way. |
| **command-guard** | 0 | 2 | No `lane.tsv`. `taskmaster/hooks/clarify-gate.sh:15` reads its marker and nothing declares that. |
| **ultra-deep-research** | 2 weak | 4 | craft-layer's creative-director and code-architecture's coding-entry both invoke it; its README names neither. |

### 3.2 One-directional edges where the reverse is natural

- **craft-layer → resilience** (`README:227`, lane `craft-reviewer yields_to
  resilience:performance-review`). `resilience/README.md:60-65` lists four partners,
  not craft-layer, though `craft-suite/README.md:70` says "motion and WebGL work is
  exactly where frame budgets die". resilience's performance skill has no
  frame-budget or rAF/compositor material; the handoff lands on a skill that does
  not know the domain.
- **craft-layer → taskmaster** (12 refs; "section-decisions consumes a spec, never
  re-interrogates it"). taskmaster owns the spec and has zero refs to craft-layer.
  The only nudge toward craft lives in `skill-router`.
- **llm-app → security / secret-scanning** (`SKILL.md:63,131`). Neither security
  plugin knows llm-app exists; §6.5 is the mechanism half.
- **code-architecture → ui-ux, devops** via coding-entry's routing table; neither
  points back.
- **terse → code-architecture, orchestration, task-runner** (lane + agent prose);
  only code-review points back.
- **approaches → orchestration**; `orchestration/README.md:64-69` omits approaches
  though both own "decide the shape".

### 3.3 Overlap candidates — two or three owners for one job

1. **Theming, three owners.** `/theme-design:init` (browser canvas → `tokens.css`,
   light+dark, contrast-checked), `/ui-ux:theme` (candidates → CSS variables,
   light+dark, contrast checks, live preview), `ui-ux:theming-system` (roles only).
   craft-layer arbitrates craft-vs-ui-ux as DIRECTION vs VALUES
   (`craft-layer/README.md:214`). theme-design sits outside that arbitration and
   emits the same artifact `/ui-ux:theme` emits. Its own README:82 draws the line
   as "colour-only theming with candidates → `/ui-ux:theme`", which is a line one
   side drew.
2. **Live preview server, four claimants.** design-lab (real components),
   `/ui-ux:theme` (`PREVIEW_PORT:-8123`), taskmaster visual-decisions (shell
   mockups), theme-design (own canvas + bridge). The declared fallback chain is
   design-lab → taskmaster mockup; theme-design is not in it. `ui-ux` and
   `taskmaster` ship byte-identical `preview-guard.sh` twins, admitted in source
   (`ui-ux/hooks/preview-guard.sh:46`).
3. **Session persistence, three mechanisms.** brain (committed map, SessionStart
   injection), hindsight (SessionEnd ledger, harvest → CLAUDE.md), taskmaster's
   context-scout (per-interrogation scan). Only `brain/README.md:117` acknowledges
   hindsight, as a future graph node.
4. **Output-shape discipline, three owners.** terse (message shape), candor
   (no over-claim), lean (how much output). candor already yields to terse on
   `check`; lean and code-review's comment-discipline both price comments.
5. **Manifest scanning, three implementations.** stack-scan's installed-versions,
   plugin-scout's `stack-relevance.md` signal table, vercel-skills-scout ("same
   rules as plugin-scout"). The lane declares precedence; each still re-detects.

None of these is a merge proposal. The 09-03 review killed the craft/frontend-design
merge on evidence and the same evidence applies to 1: two design doctrines
contradict on defaults. The ask is an arbitration paragraph in the plugin that
lacks one, and the reverse edges in §3.1.

### 3.4 Structural gaps

- **Six leaves in no bundle:** database, devops, llm-app, payments, system-design,
  theme-design. The first five are correctly install-by-name (09-03 rejected
  `backend-suite`). theme-design is the exception: `craft-suite` is the design
  bundle and holds design-lab, whose overlap with theme-design is the tightest in
  the tree.
- **Six leaves with no `lane.tsv`:** command-guard, design-lab, lean,
  secret-scanning, stack-scan, vercel-skills-scout. Four of them ship hooks
  (command-guard, lean, secret-scanning) or an MCP server (design-lab). They are
  absent from the precedence graph the territory gate reads, so a future collision
  with any of them is undetectable by construction.
- **Eight plugins share one PostToolUse Edit|Write advisory channel** (code-review
  ×3, lean, security, testing, ui-ux, task-runner ×2, skill-router). Each is small;
  together they inject up to ten advisories on one edit. The dynamic budget
  channel measures the MAX across a prompt corpus, not the sum across installed
  plugins on one edit. Nothing here has measured the stack.
- **Hand-copied mechanisms.** Three boost injectors (`craft-layer/hooks/ultra-craft.sh`,
  `orchestration/hooks/ultra-assess.sh`, `taskmaster/hooks/ultra.sh`) differ by one
  token. Six plugins hand-write the same "read `tool_input` → regex →
  `permissionDecision`" PreToolUse write guard (secret-scanning, database, devops,
  code-review, git-workflow, taskmaster). The five `remind.sh` copies are fine —
  they are chassis output — which is the point: the guard and the injector are the
  same shape and are not.

---

## 4. Coverage gaps, filtered

Filtered against `measured-zero-shapes.md` and the explicit rejections in the
09-03 and 08-26 reviews. What survives the filter is short.

| gap | status | why it survives / dies |
|---|---|---|
| `pgvector` reference | **lost**, restore | Was a delivered P2 item; RAG is llm-app's domain and llm-app has no vector-store material. A reference file, not a leaf. |
| time / timezone | **open since 08-02**, no owner | Footgun class, not a checklist: storing local time, DST arithmetic, `now()` in tests, MariaDB `TIMESTAMP` vs `DATETIME` tz semantics. Homes exist: database references, testing (clock injection), security data-privacy (retention windows). |
| multi-tenancy | **open since 08-02**, no owner | Tenant scoping is IDOR at scale; security-review's authz section is the home, one reference file. |
| monorepo (Turborepo / Nx) | **measured zero, killed** (same day) | Three Turborepo 2.x cases (`tasks` vs `pipeline` + own-build `dependsOn`; `$TURBO_DEFAULT$` on narrowed `inputs`; `env` + `envMode: strict` for cache keys), Sonnet, n=3 per arm, regex scorer over fenced JSON: control 9/9, treatment 9/9. The base model already carries the version inversion. Protocol and numbers in the proposals document, P10. |
| LLM prompt-injection sinks | covered in prose only | llm-app names the rule; no hook fires. §6.5. |
| SEO / Open Graph for landing pages | **dies** | Only web-dev's nextjs skill mentions it. Shape 2 (canonical-doctrine checklist); the model knows OG sizes. Not proposed. |
| framework major upgrades | **dies** | Shape 1 (per-version idiom map), measured zero twice. package-hygiene's upgrade lanes are the surviving half. |
| runbooks / on-call | **dies** | Shape 2. resilience-design is the surviving half. |
| Python / Go / Rust / Terraform | **rejected**, stays rejected | Every leaf is a permanent always-on raise; scout routes to vercel-skills-scout by design. |

---

## 5. Host levers nobody pulls

The installed CLI 2.1.267 binary was grepped for hook-event names. Present in the
binary, absent from every `hooks.json` and from every document in this repository:

| event | in CLI | in tree | what it would let a plugin do |
|---|---|---|---|
| `PreCompact` | yes | 0 | Write a state capsule BEFORE the summary is produced, so the summary carries it. |
| `PostCompact` | yes | 0 | Re-inject after compaction without racing SessionStart's matcher. |
| `SubagentStart` / `SubagentStop` | yes | 0 | See and gate what a subagent returns; meter subagent spans. |
| `PermissionRequest` | yes | 0 | Decide a permission prompt in a script instead of a PreToolUse deny. |
| `Notification` | yes | 0 | React when the session is waiting on a human. |

The 09-03 review scoped these out as "capability, not conformance". That was a
scoping ruling for a conformance review, not a merit rejection, and this review's
question is capability. Two of them close residuals that three shipped plugins
already admit — one via the SessionStart twin, see 5.1.

### 5.1 Compaction survival — SessionStart `compact`, not PreCompact

**Correction, same day.** The first draft of this section called `PreCompact` "the
stronger lever". It is not, and this repository already knew:
`approaches/hooks/compact-recovery.sh` states in its header that Claude Code writes
PreCompact stdout to the debug log and never adds it to the model's context. The
hooks reference confirms it: only `UserPromptSubmit`, `UserPromptExpansion`,
`SessionStart` and `PostModelSwitch` inject exit-0 stdout. PreCompact and
PostCompact stay in the table above as unused events; neither is a channel to the
model, so neither is proposed.

The lever that works is the one approaches already pulls: `SessionStart` with
matcher `compact`, which fires exactly once per compaction and injects. Backlog #6
stands: the router's rank-marker key and the phase sentinel both assume
`session_id` survives compaction and nothing establishes it. One plugin re-asserts
its own ledger after compaction; the phase file, the registered task-runner run and
the taskmaster ledgers have no recovery path. A blind control misses this by
construction: the base model cannot recall a phase that was never in the summary.

### 5.2 Subagent evidence gate (SubagentStop)

`candor`'s Stop gate catches fabricated `file:line` citations and unevidenced
reversals in the main thread. `orchestration:delegation-contracts` asks for
"compressed evidence-backed reports" from subagents in prose, and its own lint
"checks presence, not quality". `turn-cost.sh` names subagent turns as its blind
spot: invisible and billed. A `SubagentStop` hook is the same script candor already
ships, pointed at the subagent's final message, plus a one-line span record for the
cost tool. Three residuals, one event.

### 5.3 The other three, briefly

`PermissionRequest` would let command-guard answer the permission prompt itself
where it currently denies at PreToolUse; the behaviour is the same, the UX differs
and the safe direction is unclear, so it is a probe, not a proposal. `Notification`
is a mechanism with no rule behind it. Neither is proposed.

---

## 6. Proposals, ranked

Each names the plugin it improves, the rule or mechanism it carries, what a blind
control would miss, and what it does NOT do. Sized S/M/L by the estimation skill's
classes.

### 6.1 Compaction capsule — `skill-router` (or `taskmaster`), M

- **Carries:** a `SessionStart` matcher-`compact` hook that emits every open ledger
  the installed plugins keep, in one block — the phase sentinel, the registered
  task-runner run, the taskmaster ledgers. Not PreCompact: see 5.1.
- **Control misses:** the phase and the active card, by construction.
- **Does not:** prove any hook honours the re-asserted phase (agent-graded, same as
  `pc_phase_guard`'s behaviour half).
- **Home:** skill-router already owns the SessionStart catalog and the phase
  sentinel; taskmaster owns the phase file. One of them, not a new leaf.
- **Prerequisite:** measure whether `session_id` survives compaction. Same probe
  that has been open since 2026-08-16.

### 6.2 Subagent evidence gate — `candor`, M

- **Carries:** `SubagentStop` wired to the existing gate script; a span record
  (`agent type, start, stop`) appended where `turn-cost.sh --skills` can read it.
- **Control misses:** a fabricated citation in a subagent report that the main
  thread then quotes as fact.
- **Does not:** judge report quality. Same two shapes candor already limits itself
  to.

### 6.3 Make `brain` a consumer — `brain`, M

- **Carries:** `git-workflow:finish` already offers `/brain index`. Add two
  writers: approaches' `deliberated.json` picks land as a `brain/decisions.md`
  area (the ADR nobody keeps), and hindsight's harvest proposals that the user
  approves land as brain notes, not only CLAUDE.md rules.
- **Control misses:** a decision made three sessions ago, in a session that was
  compacted. Overlaps 6.1 on purpose: 6.1 is intra-session, this is cross-session.
- **Does not:** a fourth persistence mechanism. It is the sink for two that exist.

### 6.4 Guard-hook chassis type — `templates/`, M

- **Carries:** one `write-guard.sh.tmpl` rendering the six hand-copied PreToolUse
  regex→decision guards and the three boost injectors from `.chassis.json` keys.
- **What it catches that nothing else does:** drift between twins. The
  `preview-guard.sh` twin is admitted in source; the other eight are not.
- **Does not:** change behaviour. Byte-match is the acceptance test; `generate.sh
  --check` becomes the gate.
- **Note:** 09-03 declined a fifth chassis type for `prime.sh` because nothing else
  asked for it. Nine files ask for this one. Also run
  `scripts/smoke/chassis-template-tests.sh`; CLAUDE.md records why.

### 6.5 LLM-sink patterns in the security write scan — `security`, S

- **Carries:** three regex shapes in `hooks/write-scan.sh`: user input interpolated
  into a `system:`/`role: "system"` string, a tool-result concatenated into a
  prompt without a delimiter, a model output passed to `eval`/`exec`/shell. Warn,
  not deny, matching security's stated tier.
- **Control misses:** the write-time nudge. llm-app's prose says the rule; nothing
  fires when the line is written. This is the "mechanism half" the 09-03 port
  pass gave every other prose rule that had a sink shape.
- **Does not:** detect injection in data. Same limit as every regex guard here.

### 6.6 Reverse edges and arbitration paragraphs, S each

Doc-only, version-bump exempt where they touch README only:

- `code-architecture`, `terse`: name candor as the gate that yields to them.
- `ui-ux`, `design-lab`: name theme-design and state the line (session-driven
  design vs candidate-driven theming vs real-component variants). Add theme-design
  to the design-lab fallback chain, or say why not.
- `craft-suite`: add theme-design, or record why the design bundle excludes the
  browser design session.
- `resilience`: name craft-layer as a consumer and either add frame-budget material
  to performance-tuning's references or send the handoff to ui-ux's
  motion-best-practices instead, which does know rAF and compositor cost.
- `taskmaster`: one line that a spec headed for a landing page or marketing surface
  is craft-layer's input.
- `brain`, `ultra-deep-research`, `orchestration`, `hindsight`: a pairs-with
  section naming their actual consumers.
- `README.md`: 35 → 36, and the sentence should carry the recount command instead.
- `theme-design/README.md:67`: `gate` → `recorded` until a harness exercises it.

### 6.7 Lanes for the six lane-less leaves, S

command-guard, secret-scanning and lean ship hooks that fire on every turn; they
belong in the territory graph more than most declared artifacts do. `any` phase is
the honest claim for all three.

### 6.8 References, not leaves, S each

- `database/skills/sql-best-practices/references/pgvector.md` — restore the lost
  deliverable; cite it from llm-app's RAG section.
- `database/.../references/time.md` — tz storage, DST, `TIMESTAMP` semantics.
- `testing/.../references/clock.md` — injected clocks, frozen time in tests.
- `security/skills/security-review/references/multi-tenancy.md` — tenant scoping
  as authz.

Each is inside a skill the router already fires on `.sql` / `*.test.*` / auth
paths, so it costs no always-on tokens.

### 6.9 Measure the advisory stack, S

One fixture: install the eight PostToolUse Edit|Write advisers, edit one `.tsx`,
count the injected bytes. If the sum is under the dynamic ceiling nothing changes;
if over, the finding is the case for a shared "one advisory block per edit"
aggregator in skill-router, which already owns that event.

### 6.10 Monorepo candidate — `stack-scan` reference first, L if it graduates

Run the control-arm test the 08-20 ablation defined: three Turborepo task-graph
prompts, base model vs a draft reference. Non-zero delta earns a reference under
stack-scan's package-hygiene; zero kills it for good, which is a result too.

---

## 7. Not proposed, on purpose

Re-listed so the next review does not re-derive them:

- New language or platform leaves (python, django, terraform, go, rust): every leaf
  is a permanent always-on raise; measured zero on idiom maps twice.
- `backend-suite` or any new bundle other than one membership fix (§6.6).
- Merging theme-design into ui-ux or design-lab; merging brain and hindsight;
  merging terse, candor and lean. Adjacent, arbitrated, not the same job.
- A second eval harness, a scorer-rubric run, an eval CI job. `claude plugin eval`
  is early-access gated on this account; the runner is the blocker, not the
  fixtures.
- Collapsing commands into skills (deferred 09-04, still deferred).
- CHANGELOG backfill.
- SEO, runbook, upgrade-guide, HTML-email, PII-inventory skills — all shape 1 or 2
  in `measured-zero-shapes.md`.

---

## 8. Recount before quoting

```bash
ls -d plugins/*/ | wc -l                                    # 44
ls plugins/*/lane.tsv | grep -vc suite                      # 30
ls -d plugins/*/evals | wc -l                               # 2
grep -rl pgvector plugins | wc -l                           # 0 = still lost
grep -rl '"PreCompact"\|"SubagentStop"' plugins/*/hooks/hooks.json | wc -l   # 0 = §5 still open
python3 -c "import glob,os;s={os.path.basename(os.path.dirname(p)) for p in glob.glob('plugins/*/skills/*/SKILL.md')};r=open('plugins/skill-router/rules.tsv').read();print(sum(1 for x in s if f'\t{x}\t' not in r),'of',len(s),'unrouted')"
```
