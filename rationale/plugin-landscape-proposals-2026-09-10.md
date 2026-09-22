# Plugin landscape proposals — 2026-09-10

> **Superseded** — historical record only, read with its date in mind. Superseded by the 2026-09-14 consolidation; kept for its "not built, and why" records. Plugin names below may no longer exist; see `marketplace.json` for the live set. <!-- removed-ok -->

Detailed design for each proposal in `plugin-landscape-review-2026-09-10.md` §6.
Read that document for the evidence; this one says what gets built, where, how it
is gated, and what it leaves undone. **Standing: `recorded`.** Each section ends with
an execution record filled in as the work lands on the `plugin-landscape-review`
branch; a section with no record was not built, and says why.

Sizing uses the estimation skill's classes. Version bumps follow
`scripts/check-version-bumps.sh`: a plugin whose functional files change bumps
`plugin.json`; root README/CHANGELOG edits are exempt; a plugin with a CHANGELOG
carries an entry for the version it bumps to.

---

## P1 — Compaction capsule (SessionStart `compact`) — M

**Problem.** Every plugin that keeps per-task state keeps it on disk and relies on
the model remembering the file exists. After an auto-compaction the file is intact
and the memory is gone. `approaches/hooks/compact-recovery.sh` names this exactly
and fixes it for one ledger. The others — `.claude/cc-phase.json` (phase),
`.claude/task-runner/active-run.json` and `scope.json` (registered run and scope
lock), `.claude/taskmaster/ledger-*` and `goal-ledger-*` (ambiguity and goal
ledgers), the terse level file — have no recovery path. Backlog #6 records that
nothing establishes whether `session_id` survives compaction, and two shipped
mechanisms key on it.

**Design (corrected before build).** The first draft put this on `PreCompact` so
the capsule would ride inside the summary. That channel does not reach the model:
PreCompact stdout goes to the debug log, and the documented context-injecting
events are UserPromptSubmit, UserPromptExpansion, SessionStart and PostModelSwitch —
`approaches/hooks/compact-recovery.sh` had already recorded this. So the hook is
`SessionStart` with matcher `compact`, owned by `skill-router` because it already
owns the SessionStart catalog and the phase sentinel and sits in six of eight
bundles. It reads the ledger paths the installed plugins are known to keep and
prints one block — one line per ledger that exists, path plus the fields that
identify the decision — and exits 0. Silent on every other source and when no
ledger exists. It does not repeat approaches' marker; that plugin re-asserts its
own.

**What the control misses.** The base model cannot recall a phase or a card that was
never in the summary. Measurable: a headless run that fills context past the
threshold, forces compaction, then asks "what phase is this task in" — with and
without the hook.

**Gates.** `pc_hook_timeout`, `pc_phase_guard` (the hook names a phase file but its
lane phase is `any`, so the sentinel does not apply), `pc_lanes_*` (a new `hook` row
in skill-router's `lane.tsv`), `context-budget.sh` (the block is on a channel the
budget script does not meter: state the unmetered channel in the README). A fixture
under `plugins/skill-router/scripts/__tests__/` drives the real payload shape.

**Does not.** Prove any hook honours the re-asserted phase. Prove `session_id`
survives — that probe is P1's prerequisite and is recorded separately below.

**Residual.** Whether `session_id` survives compaction is still unmeasured. The hook
now records it: each firing appends whether the sentinel's session_id matched the
payload's to `.claude/skill-router/compact-log.jsonl` (recorded, unread), so the
answer accrues on real sessions.

---

## P2 — Subagent evidence gate (`SubagentStop`) — M

**Problem.** `candor/hooks/gate.sh` blocks a final message that cites a `file:line`
which does not resolve, or retracts under bare pushback with no tool call in
between. It runs on `Stop` only. A subagent's final report goes through neither
clause, and the main thread quotes it as fact. `orchestration:delegation-contracts`
asks for evidence-backed reports in prose; its lint "checks presence, not quality".
`scripts/turn-cost.sh` names subagent turns as invisible and billed.

**Design.** Add a `SubagentStop` entry to candor's `hooks.json` pointing at the same
`gate.sh`. Clause 1 (citation resolution) applies unchanged to the subagent's final
message. Clause 2 (reversal) has no user turn in a subagent transcript and disarms
itself. A one-line span record — event, agent type, timestamp — is appended to
`.claude/hindsight/subagents.jsonl` when `hindsight` is installed and the directory
exists, so `turn-cost.sh --skills` gains the denominator it says it lacks. The span
write is fail-open and skipped when the directory is absent.

**What the control misses.** A fabricated citation in a subagent report. Same fixture
as the existing 37-case harness, with the SubagentStop payload shape.

**Gates.** `pc_hook_timeout`; the existing `gate.test.sh` extended with the new
payload; a lane row `candor:subagent-gate hook any unresolved-assertion`.

**Does not.** Judge report quality. Meter tokens — the span carries time, not cost.

**Residual.** Depends on the SubagentStop payload carrying the subagent's
`transcript_path` and honouring exit 2 as a block. If it carries only an identifier,
the gate degrades to the span record alone.

---

## P3 — Make `brain` a consumer — M

**Problem.** Four plugins read `brain/INDEX.md`; brain reads nothing. The decisions
that most need to survive a session — the approach pick with its kill-trigger, the
harvested friction rule the user approved — live in `.claude/approaches/deliberated.json`
(local, gitignored) and in CLAUDE.md respectively. There is no committed decision
record, and no plugin here keeps an ADR.

**Design.** Two writers into a reserved `brain/decisions.md` area:

1. **Indexer.** When `/brain index` runs and `.claude/approaches/deliberated.json`
   exists, the indexer appends any pick not already recorded: date, task slug,
   chosen shape, one-line why, kill-trigger. The area line in `INDEX.md` reads
   `decisions — N recorded shape choices; latest <date>`.
2. **Harvest.** `hindsight:harvest`'s approval step gains a third destination
   beside CLAUDE.md and Claude memory: when `brain/INDEX.md` exists, a finding that
   describes the codebase (not the user's preference and not a rule) is offered as
   a brain note under the matching area.

`git-workflow:branch-completion` already offers `/brain index` at finish; no change.

**What the control misses.** A decision from a compacted session three finishes ago.

**Gates.** SKILL budgets for the hindsight harvest skill; brain's agent frontmatter
gates; `pc_lanes_*` for the new area if the indexer's lane `owns` needs widening.

**Does not.** Create a fourth persistence mechanism — it is a sink for two existing
ones. Write outside `brain/`.

---

## P4 — Boost-injector chassis type — M

**Problem.** `craft-layer/hooks/ultra-craft.sh`, `orchestration/hooks/ultra-assess.sh`
and `taskmaster/hooks/ultra.sh` share a 35-line skeleton (fail-open wrapper,
`CC_BOOST` off switch, fence scrub, 200-char head, negation and self-echo guards)
and differ in the env var name, the token regex and the injected message. The
skeleton has already had one bug ("ultra-assess X" in a pasted transcript
suppressed the boost the user typed) fixed three times. The six PreToolUse write
guards named in the review differ in logic, not data, and are NOT templated here — a
template that hides six different decision trees is a lie.

**Design.** `templates/boost-hook.sh.tmpl` plus a `boost-hook` chassis kind in
`generate.sh`. Manifest keys: `envVar`, `branches: [{regex, message}]` rendered as
an `if/elif` chain. `templates/samples/boost-hook.json` carries every key literally
for `scripts/smoke/chassis-template-tests.sh`. Acceptance is byte-identical
re-render of all three shipped hooks; the header line changes to the generated-from
marker, which is the one intended delta.

**What it catches that nothing else does.** Drift between the three skeletons.
`generate.sh --check` becomes the gate.

**Gates.** `generate.sh --check`, `chassis-template-tests.sh`, `hook-guard-tests.sh`
(asserts the injectors' behaviour), `validate.sh` chassis-header check.

**Does not.** Change behaviour. Template the write guards.

---

## P5 — LLM-sink patterns in `security/hooks/write-scan.sh` — S

**Problem.** `llm-app` states the prompt-injection rule; nothing fires when the
line is written. The 09-03 port pass gave every other prose rule with a sink shape
a write-time warn. These three have one:

| slug | shape | advice |
|---|---|---|
| `prompt-interpolation` | a `system`/`role: "system"` string built with `${…}`, f-string, `.format`, `%s`, or `.` / `+` concatenation of a variable | user input inside the system prompt — pass it as a user turn or a delimited data block, never into the instruction text |
| `llm-output-exec` | a completion / message / `choices[0]` value reaching `eval`, `exec`, `Function`, a shell exec, or `subprocess` | model output executed as code — validate against a schema or allow-list first |
| `tool-result-unfenced` | a tool result or retrieved chunk concatenated into a prompt with no delimiter | retrieved text is untrusted input — fence it and tell the model it is data |

Warn tier, JS/TS/Python/PHP gated, same one-per-finding dedup.

**What the control misses.** The nudge at write time.

**Gates.** `write-scan.test.sh` (a warn case and a silent case per slug); bump
security; add a `security ← llm-app` line to security's README pairs-with.

**Does not.** Detect injection in data. Regex over one line, like every sibling.

---

## P6 — Reverse edges and arbitration paragraphs — S

README-only where possible (bump-exempt). One edit per plugin:

| plugin | edit |
|---|---|
| `README.md` (root) | "35 leaf plugins" → "36", and the sentence carries the recount instead of a bare number |
| `theme-design` | hook row tier `gate` → `recorded`; add "pairs with" naming ui-ux and design-lab and stating the line |
| `ui-ux`, `design-lab` | name theme-design; design-lab's fallback chain gains "a running theme-design session owns the preview surface" |
| `craft-suite` | `plugin.json` gains theme-design (functional → bump, bundle table regenerates) |
| `code-architecture`, `terse` | name candor as the gate that yields to them |
| `resilience` | name craft-layer; route frame-budget work to ui-ux's motion-best-practices, which knows rAF and compositor cost |
| `taskmaster` | one line: a spec for a landing or marketing surface is craft-layer's input |
| `orchestration` | name approaches in pairs-with |
| `ultra-deep-research` | name craft-layer and code-architecture as consumers |
| `brain`, `hindsight` | pairs-with sections (folded into P3) |

---

## P7 — Lane rows for the six lane-less leaves — S

`command-guard`, `secret-scanning`, `lean` ship hooks that fire every turn and are
absent from the territory graph. `design-lab`, `stack-scan`, `vercel-skills-scout`
ship commands and skills. One `lane.tsv` each, `any` phase for the always-on guards,
`yields_to` where the README already states a deference (design-lab → taskmaster
mockup; vercel-skills-scout → plugin-scout; stack-scan's report → plugin-scout's
detection). Functional file → patch bump each; command-guard has a CHANGELOG.

**Does not.** Promote skill/command rows from WARN to gate (deferred 09-04).

---

## P8 — References, not leaves — S each

| file | carries | cited from |
|---|---|---|
| `database/skills/sql-best-practices/references/pgvector.md` | the lost deliverable: vector column types, HNSW vs IVFFlat and when each is wrong, distance operators and index/operator mismatch, the `lists`/`ef_search` footguns, filtering before vs after ANN | database SKILL "Indexing logic"; llm-app SKILL "RAG" |
| `database/skills/sql-best-practices/references/time.md` | store UTC, `TIMESTAMP` vs `DATETIME` semantics per engine, DST arithmetic on wall-clock columns, `now()` in migrations and defaults, range queries across a zone boundary | database SKILL "Schema design" |
| `testing/skills/testing-best-practices/references/clock.md` | clock injection, frozen time per test, DST and leap boundaries as fixtures, why `sleep` is never a synchronisation primitive | testing SKILL "Determinism" |
| `security/skills/security-review/references/multi-tenancy.md` | tenant scoping as authorization: global scopes vs per-query filters, the IDOR-at-scale shape, tenant id from the session not the request, cross-tenant joins, background jobs that lose the tenant | security SKILL "Authorization is not authentication" |

Each is under a skill the router already fires for `.sql`, migrations, test files and
auth paths. No always-on cost. Minor bump per plugin; testing has a CHANGELOG.

---

## P9 — Measure the advisory stack — S

One fixture: install the eight PostToolUse Edit|Write advisers, feed one `.tsx`
edit payload chosen to trip each guard, sum the injected bytes. If the sum is under
`DYNAMIC_CEILING` nothing changes; if over, the number is the case for a shared
one-block-per-edit aggregator in skill-router. Result recorded here, no script
shipped — a one-off measurement is not a gate.

---

## P10 — Monorepo control arm — L if it graduates

The 08-20 ablation method: three Turborepo/Nx task-graph prompts, base model versus
a drafted reference, judged on the claims a blind model gets wrong (`dependsOn:
["^build"]` semantics, cache `inputs`/`outputs`, remote-cache env leakage). Non-zero
delta earns a reference under stack-scan's package-hygiene; zero kills it. Needs a
drafted reference and six live runs; not started until P1–P9 land.

---

## Execution record

Filled in as work landed on `plugin-landscape-review`, 2026-09-10. Standing of each
line: what a script checks is named; the rest is recorded.

| # | status | what landed | gate evidence |
|---|---|---|---|
| P1 | **built** | `skill-router/hooks/compact-capsule.sh` on SessionStart matcher `compact`; lane row; README + CHANGELOG; 0.14.13 → 0.15.0 | `scripts/__tests__/compact-capsule.test.sh` 26/26; `hook-syntax`, `lanes`, `hook-budget`, `prime-map`, `marker-key` smoke green; always-on budget delta 0 (startup source stays silent) |
| P2 | **built** | `candor/hooks/gate.sh` wired to `SubagentStop`; judges `last_assistant_message`, falls back to `agent_transcript_path`; clause 2 disarmed for subagents; markers suffixed per hashed agent id; lane trigger widened; README + CHANGELOG; 0.1.3 → 0.2.0 | payload shape and `exit 2` blocking measured live on 2.1.267 (headless probe: SubagentStop carries `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`, `stop_hook_active`; a blocked subagent sees the reason and re-reports); `gate.test.sh` 44/44 (37 existing + 7 SubagentStop). Span ledger **dropped**: the host already writes one transcript per subagent under `<session>/subagents/`, so the cost denominator is a reader change to `scripts/turn-cost.sh`, not a new writer |
| P3 | **built, half-satisfiable** | brain indexer appends a `brain/decisions.md` entry per approaches marker (dedupe key: the marker's `at`), reserved `decisions` area line in INDEX.md, a `## Notes` section the indexer must carry over on re-index (closes a latent erase of harvest notes); hindsight harvest gains a third approval destination, a brain note, when `brain/INDEX.md` exists; both READMEs gain pairs-with sections; brain 0.4.0, hindsight 0.8.0 | `validate.sh` clean; budget delta brain −1, hindsight 0 (two description edits reverted because they broke the marketplace.json mirror gate). **Residual:** the approaches marker carries only `task`, `by`, `at` — no shape, why or kill-trigger — so those three slots land as literal fill-in placeholders until `approaches` widens its marker, which is that plugin's change, not made here. Dedupe and note carry-over are agent-graded |
| P4 | **built** | `templates/boost-hook.sh.tmpl`, `boost-hook` chassis kind in `generate.sh`, manifests for taskmaster / orchestration / craft-layer, hand lane rows moved into manifests, two sample fixtures; taskmaster 0.41.8, orchestration 0.16.9, craft-layer 0.49.3 (auto patch-bump) | `generate.sh --check` clean; `chassis-template-tests.sh` +18 asserts green; `hook-guard-tests.sh` 4 boost hooks × 7 cases green; old-vs-new hook output byte-identical for every invocation tested. Behaviour diff is two lines: the per-plugin off switch reads through `${!plugin_switch}` and the directive goes out via a quoted heredoc (manifest text is wire text). The six PreToolUse write guards were **not** templated — they differ in logic, not data |
| P5 | **built** | three warn-tier LLM-sink patterns in `security/hooks/write-scan.sh` (`prompt-interpolation`, `llm-output-exec`, `tool-result-unfenced`), JS/PY/PHP gated; README pattern list + llm-app pairs line; 0.8.0 → 0.9.0 | `write-scan.test.sh` 88/88 (48 → 88; 19 warn + 21 silent cases for the three slugs, fenced/delimited forms silent) |
| P6 | **built** | root README 35 → 36; theme-design hook tier `gate` → `recorded` + pairs section; ui-ux and design-lab name theme-design and its line; craft-suite gains theme-design (0.4.2 → 0.5.0, bundle table regenerated, baseline key hand-moved 2808 → 3002 for that one bundle only); candor named from code-architecture and terse; resilience names craft-layer and routes frame budgets to ui-ux motion-best-practices (verified: performance-tuning has no rAF/compositor material); taskmaster names craft-layer; orchestration names approaches; ultra-deep-research names its two consumers | `validate.sh` clean; `generate.sh --check` clean. The README sentence still carries a bare count rather than a recount command — left as the smaller change |
| P7 | **built** | `lane.tsv` for command-guard, secret-scanning, lean, design-lab, stack-scan, vercel-skills-scout; patch bumps; command-guard CHANGELOG | `pc_lanes_*`, `pc_phase_guard`, `pc_deference_edges` clean; `lanes-tests.sh` green; no cofire blessing needed — every `owns` unique except the intended command → skill dispatcher pairs |
| P8 | **built** | `database/.../references/pgvector.md` (131 lines), `time.md` (128), `testing/.../references/clock.md` (119), `security/.../references/multi-tenancy.md` (133); one citing line per SKILL section; llm-app RAG section names pgvector.md by prose; database 0.7.0, testing 0.9.0 (+CHANGELOG), llm-app 0.2.2, security (in P5's bump) | SKILL budgets: database 144 L / 7,767 B; testing 153 / 8,376; llm-app 140 / 7,660; security 155 / 8,826. Every reference opens with a `Last verified: not fetched — written from training knowledge` stamp: **no live re-read was done**; the `digest-refresh` skill is the path to a real date. Claims the author flagged least sure: pgvector's default opclass being L2 and its dimension ceilings; MariaDB 11.5 TIMESTAMP range; Postgres timestamp-vs-timestamptz cast index effect; Vitest fake-timer defaults |
| P9 | **measured, no change** | eleven PostToolUse Edit\|Write advisers across nine plugins (taskmaster's card-lint-observe was missed by the review's count of eight); five budget fixture shapes | worst single-shape stacked sum 1,628 additionalContext bytes ≈ 465 tokens against `DYNAMIC_CEILING` 2,900; second edit to the same file 0 bytes (every emitter is once-per-context); skill-router's route.sh is 70–81% of every non-CSS sum. An aggregator changes nothing; the only lever is route.sh's per-rule line length, a router-internal edit not taken here |
| P10 | **measured zero, killed** | draft reference (Turborepo 2.x / Nx footguns, 25 lines) and three cases in `taskmaster-docs/ablation-monorepo/` (gitignored working material) | protocol of `eval-ablation-2026-08-20.md`: fresh blind Sonnet subagent per run, n=3 per arm per case, regex scorer over fenced JSON. Case A (`tasks` not `pipeline`, test depends on own `build`): control 3/3, treatment 3/3. Case B (`$TURBO_DEFAULT$` when negating docs from `inputs`): 3/3, 3/3. Case C (`env` declares `NEXT_PUBLIC_API_URL`, `envMode: strict`): 3/3, 3/3. Mean answer length fell with treatment (1,343 → 1,120; 1,532 → 749; 803 → 745) — shorter, not more correct. Third zero for the per-version idiom-map shape; the reference is not shipped and the shape list in `measured-zero-shapes.md` stands |

**Gates run on the whole branch before commit:** `validate.sh`, `check-version-bumps.sh master` (after commit — it diffs committed changes only), `context-budget.sh` (alone), `generate.sh --check`, `official-validate.sh`, every `scripts/smoke/*.sh` except canary, every `plugins/*/scripts/__tests__/*.test.sh`. Results in the commit message.
