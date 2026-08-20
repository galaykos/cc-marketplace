# Distillation strategy — 2026-08-20

What to cut, merge, and make enforceable across this marketplace, and — more
importantly — **how to know whether any of it helped**. Every number here was
measured on branch `distill-2026-08-20`; every external claim carries a URL.

Placed in `rationale/` rather than `taskmaster-docs/` for the reason
`rationale/README.md` gives: a strategy written into a gitignored directory is
deleted on clone, and `rationale/distillation-review-2026-08-17.md` §3 already
recorded that failure once.

---

## 1. The verdict, in one paragraph

The marketplace's own always-on meter is **wrong by 1.54×**, and the number it
is wrong about is **~10× over the budget the host actually enforces**. Anthropic
budgets the skill listing at **1% of the context window** and, on overflow,
**drops descriptions starting with the least-invoked skills** — names survive,
trigger keywords do not. Measured with the official meter, the 61 leaf plugins
cost **19,667 always-on tokens**; `scripts/context-budget.sh` reports 12,789 for
the same set. On a 200k-token session the listing budget is **2,000 tokens**.
So the distillation question is not "which prose is flabby" — it is **which
artifacts deserve to survive a budget that is already silently evicting the
tail**, and the repo has been steering by an instrument that under-reads by half.

---

## 2. Corrections to our own instruments

| Instrument | What it says | What is true | Standing |
| --- | --- | --- | --- |
| `scripts/context-budget.sh` | `everything` = 12,789 always-on tokens | `claude plugin details` summed over the 61 leaves = **19,667** | gate, measuring low by 1.54× |
| Same | Method: description bytes ÷ 4 (`:226`) | Host charges a per-component floor (~60–130 tok even for a one-line description) plus counts commands as skills | — |
| Same, second independent under-read | SessionStart hooks measured in a sandbox with empty `HOME` and no env (`:66-79`) | It meters the **OFF state**. `terse/hooks/activate.sh` emits **4,171 B ≈ 1,043 tok** when a level is set (re-verified this session) and 0 in the sandbox; `brain/hooks/inject.sh` emits ~2,104 B with an `INDEX.md` present, baseline 89; `terse/hooks/mode.sh` adds ~174 tok per prompt, dynamic baseline 0. **≈1,569 always-on + 174/prompt invisible in the config a user runs** | gate, blind to its own subject |
| CLAUDE.md, "Every enforcement surface" | four scripts + 20 smoke harnesses | Accurate, but **no official check runs**: `claude plugin validate --strict`, `claude plugin details`, `claude plugin eval` appear in zero scripts and zero CI steps (`grep -rn 'plugin details\|plugin validate\|plugin eval' scripts/ .github/`) | gap |
| `claude plugin validate --strict`, measured before recommending it | would catch schema drift | **All 71 plugins pass today**, so adopting it finds nothing now — it is a regression guard, not a discovery. And it is weaker than the docs imply: pointed at a skills dir it accepted a SKILL.md whose frontmatter carried an invented `bogusfield:` key. It validates manifests, not skill-frontmatter typos, in this build | worth adopting, worth not over-claiming |
| `rationale/distillation-review-2026-08-17.md` §7 | control/treatment runs are expensive and hand-rolled | **`claude plugin eval --ablation with-without` ships in the installed CLI today** and runs the with/without arm automatically | superseded |

Per-plugin spread between the two meters (official / ours): craft-layer 1655/1025,
taskmaster 1464/931, terse 1233/886, ui-ux 1058/586, approaches 937/611, sql 142/87.
The gap is not uniform — it scales with component COUNT, which is exactly the
thing a distillation is supposed to reduce.

**One thing our script does better, and it should keep doing it:**
`claude plugin details <bundle>` reports only the bundle's OWN components —
`everything` reads **~98 tok**, `taskmaster-suite` ~110, because a bundle ships
one uninstall skill and a dependency list. It does not sum the closure.
`context-budget.sh` does sum members, which is the number a user actually pays.
The correct combination is our summation over the host's per-leaf figures:
**19,667 tokens for the 61-leaf closure.**

**Recount, do not copy:**

```bash
for p in $(ls plugins | grep -v -- '-suite$' | grep -v '^everything$'); do
  claude plugin details "$p" 2>/dev/null | grep 'Always-on:'; done
claude plugin validate ./plugins/<name> --strict
```

---

## 3. What the host actually charges (sourced)

| Fact | Source |
| --- | --- |
| Skill listing budget = **1% of the model's context window**; on overflow Claude Code "drops descriptions starting with the skills you invoke least" — names always survive | https://code.claude.com/docs/en/skills |
| Per-entry `description` + `when_to_use` truncated at **1,536 chars** | same |
| `disable-model-invocation: true` "removes the skill from Claude's context entirely" — zero always-on cost, user-invocable only | same |
| An invoked body "enters the conversation as a single message and stays there for the rest of the session"; compaction re-attaches only the **first 5,000 tokens per skill, 25,000 combined** | same |
| Commands and skills are **one mechanism** — "Custom commands have been merged into skills"; a command's description is always-on exactly like a skill's | same |
| Only `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart` stdout reaches the model on exit 0; every other event's stdout goes to the debug log | https://code.claude.com/docs/en/hooks.md |
| A hook shipped by N plugins **runs N times** — only settings-file duplicates dedupe | same |
| Hook output strings capped at **10,000 characters** | same |
| Subagent frontmatter supports `model` (incl. `fable`) and `effort` (`low`…`max`); `.claude/agents/*.md` hot-reload mid-session | https://code.claude.com/docs/en/sub-agents.md |
| Skill frontmatter supports `paths` (glob-gated activation), `allowed-tools`, `model`, `effort`, `context: fork` | https://code.claude.com/docs/en/skills |
| "The description is critical for skill selection: Claude uses it to choose the right Skill from potentially 100+ available Skills" | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices |
| Official body budget is **500 lines** (ours is 150 — stricter, fine) | same |
| "One of the most common failure modes we see is bloated tool sets… If a human engineer can't definitively say which tool should be used in a given situation, an AI agent can't be expected to do better" | https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents (2025-09-29) |
| "Create evaluations BEFORE writing extensive documentation" | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices |

### What the evidence does NOT say

Cutting is not free and "shorter is better" is not supported:

- **Instruction Stacking Collapse** (arXiv 2608.02639, 2026-07-31) measured a
  prompt-compiler merge at **+11.0pp on GPT-5-mini, +3.3pp Gemini 2.5 Flash,
  −1.2pp (not significant) on Claude Sonnet 4.6**. On a strong model, merging
  overlapping instructions bought ~nothing in compliance. It still bought budget.
- **GPT-4.1 prompting guide**: ADDING three explicit reminders "increased our
  internal SWE-bench Verified score by close to 20%".
- **IFScale** (arXiv 2507.11538): compliance decays with instruction count, and
  the failure mode is **omission, not modification** — rules are silently skipped,
  which is invisible without an eval.
- **Chroma context rot** (2025-07-14) and **NoLiMa** (arXiv 2502.05167) measure
  degradation in tokens *actually in the window*. Lazily-loaded skill bodies are
  not context rot until loaded. Our always-on listing is the measured-risk surface;
  our 41.6k lines of bodies mostly are not.
- No study measured skill-DESCRIPTION overhead on selection accuracy. The
  tool-count results (RAG-MCP 13.62% → 43.13%; arXiv 2605.24660: K=2.2 beats K=5,
  93.1% vs 87.1% on Claude Sonnet 4.6) are about TOOLS. Applying them to skills
  is inference, and this document labels it as such.

---

## 4. Strategy — six workstreams, ranked by leverage ÷ risk

Each names its standing and what it does **not** fix.

### W1 — Put an eval loop under the doctrine (highest leverage, lowest risk)

> **STATUS 2026-08-20: started, and it already returned a result.** Four suites
> are authored (`plugins/{php,nextjs,i18n,resilience}/evals/`) and the first
> ablation is recorded in `rationale/eval-ablation-2026-08-20.md`:
> **zero delta, control 3/3 vs treatment 3/3, on both php and nextjs, across two
> fixture designs** — including the manifest-on-disk case that
> `stack-skill-baselines.md:50-53` admits was never exercised. Every control run
> opened `composer.json` unprompted and respected `config.platform`. One caveat
> that matters more than the result: the scorer's first version manufactured a
> treatment win and was corrected. Also: `claude plugin eval` is **early-access
> gated** on this account, so the runs were done with blind subagents and the
> four suites are unverified against the official runner.


The repo's entire retirement/measurement doctrine (`rationale/measured-zero-shapes.md`,
`scripts/retirement-queue.sh`, `authoring-skills`' "baseline a NEW behavioral skill")
is `recorded`: nothing runs it. Meanwhile `claude plugin eval --ablation with-without`
exists in the installed CLI, resolves a plugin by name or path, adds a no-plugin
baseline arm, scores with graders, and writes JSON.

- **Do:** add `evals/<case>/case.yaml` (or `prompt.md` + `graders/*.md`) to the
  five plugins whose value is most contested — `php`, `nextjs`, `database`,
  `taskmaster`, `craft-layer` — starting with fixtures that contain a real
  `composer.json`/`package.json` pinned below the advice floor, the one variable
  the eight prior hand-run baselines never had (`rationale/stack-skill-baselines.md:50-53`).
- **Standing:** `gate` once wired as a CI step on changed plugins; `recorded` until then.
- **Does NOT fix:** grader reliability. LLM-judge verbosity bias (MT-Bench,
  arXiv 2306.05685) favours longer output — adversarial to grading a distillation.
  Use deterministic graders where possible and state the bias where not.
- **Sample size:** no universal N. Anthropic's own guidance is "20-50 simple
  tasks drawn from real failures"; τ-bench shows n=1 is worthless (pass^8 <25%).
  Do not read a 1-run delta, which is the mistake §6 of the 2026-08-17 review
  already recorded.

### W2 — Fix the meter, then set the target against the real budget

> **STATUS 2026-08-20: done.** Three fixes landed, each demonstrated: (1) a third
> **activated** channel measures the always-on surface with the state its hooks
> wait for — `everything` reads 13,996 against 12,789, +1,217 tokens no baseline
> saw, and the gate was neutered and watched fail (+30 tok caught at tolerance 2
> while the always-on column stayed flat, which is precisely what the old meter
> could not see); (2) `--reconcile` / `--update-official` compare against
> `claude plugin details`, recording the **1.54x** gap in
> `scripts/context-budget-official.json` — local and WARN-only, because `details`
> resolves by installed name and CI has nothing installed; (3) the README bundle
> table now carries the activated column AND states the budget it is measured
> against — 1% of the context window, with the eviction consequence named.
> **Not done, deliberately:** no per-bundle ceiling was introduced. Four bundles
> already exceed 1% of a 200k window, so a gate set there would be a red build
> with no fix available, and inventing a threshold to avoid saying that is the
> habit `rationale/distillation-review-2026-08-17.md` §3 records as not sticking.


- **Do:** teach `scripts/context-budget.sh` to reconcile against
  `claude plugin details` (either replace the bytes÷4 estimate or add a second
  column and fail on divergence >15%). Re-baseline both channels afterwards.
- **Then:** set the always-on target from the host's rule, not taste. At 1% of a
  200k window the listing budget is 2,000 tokens; the leaf set costs 19,667.
  Nothing gets that to 2k, and pretending otherwise is theatre. The honest target
  is **bundle-scoped**: no curated bundle above ~2k always-on, `everything`
  documented as over-budget by design with the eviction consequence stated.
- **Standing:** `gate` (the script already blocks).
- **Does NOT fix:** which descriptions get evicted. That is per-user invocation
  history, not something a repo can control.

### W3 — Cut artifacts, not prose (the only cut that touches always-on cost)

Compressing a body saves on-invoke tokens; only removing or merging an ARTIFACT
removes its description from the listing. Ranked candidates with measured evidence:

| Action | Evidence | Always-on saved |
| --- | --- | --- |
| Resolve 4 skill/command NAME COLLISIONS (`approaches:build-vs-buy`, `fresh-take:consult`, `hindsight:harvest`, `taskmaster:brainstorm` each exist as both) — the host lists both entries | `claude plugin details approaches` shows `build-vs-buy` twice | ~4 × 60–130 tok |
| ~~`disable-model-invocation: true` on craft-layer's 8 flow-only skills~~ — **withdrawn, see §8d**: their triggers are prompt-shaped, and the description is the only channel a prompt-shaped trigger has | 1,876 description chars ≈ 469 tok | 0 — the proposal was wrong, not the lever |
| Merge `database-design` into `sql-best-practices` | 7 ideas duplicated across sql/database/mysql/mariadb/postgresql, incl. "index every FK" in **6** places; a migration file in a MySQL project loads 4,333 tokens of bodies at once | ~120 tok always-on, ~1,120 on-invoke per co-fire |
| Merge `approach-deliberation` + `opinion-round` | `plugins/approaches/lane.tsv:12-16` already blesses them as ONE territory; `opinion-round:107` concedes "approach-deliberation's output shape, so downstream handling is identical" | ~100 tok always-on, ~3k on-invoke |
| Fold `code-architecture:task-orchestration` into `plan-before-code` | its parallel-safety rule is stated in 4 places; 0 router rows, 0 lane rows, 0 invocations | ~90 tok always-on, ~1.5k on-invoke |

- **Standing:** `agent-graded` — no script decides a merge.
- **Does NOT fix:** install granularity. A merged plugin cannot be installed
  alone; that is the cost being spent, and it is the reason the 17 script-free
  single-skill stack plugins (php, vue3, mysql, …) are **not** on this list.

### W4 — Replace the line ceiling with a metric that still measures

The 150-line body ceiling has stopped constraining content. Measured:
`task-runner/skills/task-execution/SKILL.md` sat at exactly **154 lines across 20
commits** while its bytes went **9,288 → 12,193 (+31%)** and its lines over 110
chars went **2 → 29**; today 29 of 149 body lines carry 46% of the file's
content. `task-cards/SKILL.md` went 105 lines/4,550 chars → 154/9,318 — lines
+47%, bytes **+105%**. One line in it (`:123`) is 1,542 chars ≈ 386 tokens.
26 skills sit at exactly 154 lines. `plugin-checks.sh:11-13` already records that
a removed 100-line FLOOR manufactured edge-pinning; this is the same tell in the
other direction.

- **Do:** add a byte ceiling alongside the line ceiling, and a max-line-length
  lint. The distribution is measured, so the number does not have to be guessed —
  across all 130 bodies: **median 6,678 B, mean 6,816 B, p90 8,560 B, max 11,777 B**
  (≈1,670 / 2,140 / 2,944 tokens). A ceiling at **10,000 B** fails exactly one
  skill today (`task-execution` at 11,777) and at 9,500 B fails four; today's
  median would fail 65, which is why "cap at the median" is the wrong instinct.
  Pair it with a **max-line-length lint at 300 chars** — four files exceed it, and
  the worst is `taskmaster/skills/task-cards/SKILL.md` with a **1,526-char single
  line** (≈380 tokens carrying four separate rules). 8 skills have ≥5 lines over
  110 chars; 157 such lines exist repo-wide.

  ```bash
  # recount before setting any threshold
  python3 - <<'EOF'
  import glob,statistics
  b=[len(open(p).read().split('---',2)[2]) for p in glob.glob('plugins/*/skills/*/SKILL.md')]
  print(len(b), statistics.median(b), sorted(b)[int(.9*len(b))], max(b))
  EOF
  ```
- **Standing:** `gate` (extends `pc_skill_budget`, which has a harness).
- **Does NOT fix:** dense-but-useless content. A byte cap measures volume, not value.

### W5 — Use the host's own levers before building more of our own

Measured: **all 130 skills use exactly two frontmatter keys — `name` and
`description`.** Zero use `paths`, `disable-model-invocation`, `user-invocable`,
`allowed-tools`, `model`, or `effort`. (The 32 agents already use `model` and
`effort`; 100 commands use `description` + `argument-hint`.) Meanwhile this
marketplace ships `skill-router` — 268 lines of `route-prompt.sh` plus
`route.sh`, costing **2,408 dynamic tokens per work-shaped prompt** — to do
path-triggered skill activation, which the host documents as a frontmatter field:

> `paths`: "Glob patterns that limit when this skill is activated."
> — https://code.claude.com/docs/en/skills

- **Do, in this order:** (1) empirically test whether `paths:` fires in the
  installed build — `claude plugin validate --strict` is NOT evidence, it
  accepted an invented `bogusfield:` key in the same position; (2) if it works,
  move the 67 `rules.tsv` rows that are pure path globs onto the skills
  themselves and measure what remains of skill-router's dynamic cost;
  (3) set `disable-model-invocation: true` on skills only ever reached by a
  command that names them — **but not on craft-layer's 8 flow-only skills, which
  is where this document first pointed it.** The design audit (§8d) killed that
  target: `plugins/skill-router/rules.tsv:91-95` records that those skills
  "deliberately reach sessions via `/craft-layer:craft` and the catalog channel,
  not per-file rules — their triggers are prompt-shaped, not file-shaped", and
  the flag deletes the description, which IS the prompt-shaped channel. The lever
  is real; find a target whose only caller is a command.
- **Standing:** `recorded` until tested; the test is one install and one prompt.
- **Does NOT fix:** the marketplace's own routing intelligence — `route-prompt.sh`
  also does prompt-text matching and rank arbitration, which `paths:` does not do.
  Expect a partial replacement, not a deletion, and measure before claiming either.

### W6 — Close the five live defects found while measuring

Listed in §5. Four are one-line fixes; one is a router bug that silently disables
a whole plugin.

---

## 5. Live defects found during this audit

**All ten are FIXED on this branch** (see the commit that follows this document).
Two carry new enforcement so they cannot recur silently: `pc_bundle_readme_members`
in `scripts/lib/plugin-checks.sh` (D8) and a case-matching regression case in
`scripts/smoke/route-marker-tests.sh` (D1), each demonstrated failing against the
unfixed artifact before it was kept. D6 has **no** gate — the proposed
`pc_dangling_prose` catches 5 of its 11 shapes and the other 6 need a grammar
model, so claiming a gate there would be the tier over-claim this repo forbids.


| # | Location | Defect | Impact |
| --- | --- | --- | --- |
| D1 | `plugins/skill-router/hooks/route.sh:68-73` + `rules.tsv:127` | `match_glob` compares with `case "/$file_path" in *"/$mid/"*` — **case-sensitive**. `**/resources/js/Pages/**` is inertia's ONLY routing row | On a project scaffolded with lowercase `resources/js/pages/` (Laravel's current starter kits), the inertia plugin routes **nothing**; its 2,134-token skill never loads. `rules.tsv:125` `**/Livewire/**` has the same exposure, mitigated by a second row |
| D2 | `plugins/mariadb/skills/mariadb-best-practices/SKILL.md:6` | Stamp says 2026-08-02; commit `f19e084` (2026-08-12) rewrote the 10.6 EOL fact at `:33-34` without bumping it | `check-doc-staleness.sh` reads a stamp that no longer describes the file |
| D3 | `plugins/react/skills/react-server-state/SKILL.md:32,72-73` | Version claims ("TanStack Start is v1 RC", "v5: import `keepPreviousData`") with **no stamp**; passes the version-leverage gate only because a sibling skill carries one | The gate is plugin-scoped; the decay is file-scoped |
| D4 | `plugins/web-dev/agents/frontend-reviewer.md:7,21,25` | Names 8 skills, three times in 19 lines, and omits `react-data-grid` although `react` and `web-dev` ship in the same bundle | A TanStack Table file reviewed by this agent gets zero data-grid rubric, including the index-keyed `rowSelection` bug that silently bulk-deletes the wrong rows |
| D5 | `opinion-round:32-37` / `grill:118-120` / `brainstorm:94` | The double-deliberation guard reads `.claude/approaches/deliberated.json`, but neither taskmaster path that runs a round WRITES it | The guard is unarmed on the two paths that most often run a round |

| D6 | 11 sites in 9 files, listed in §8d | Commit `3c8e6d7` ("prose strip — net -76 lines, **no capability removed**") deleted wrapped continuation lines and **severed sentences that ship today** — e.g. `scroll-orchestration/SKILL.md:8-9`, `webgl-effects/SKILL.md:8-9`, `information-design/SKILL.md` ending mid-sentence at "Cite the" | The clause naming what a skill decides is gone from five skills; no gate in this repo can distinguish deleting a redundant line from deleting half a sentence |
| D7 | `plugins/craft-layer/template/craft-gates/contrast.mjs` | 183 lines with **zero runnable invocation sites**, while `template/craft-gates/gates.spec.ts:143-151` disables axe's `color-contrast` rule and names `contrast.mjs` "the gate of record" | Contrast is checked by nothing on any path. Same inverted-tier shape as the `utility-palette` finding in the 2026-08-17 review |

| D8 | `plugins/everything/README.md:17`, `plugins/quality-suite/README.md`, `plugins/process-suite/README.md`, `plugins/taskmaster-suite/README.md` | Bundle READMEs do not list their own members: **`candor` missing from 2, `lean` missing from all 4** (word-boundary verified), and `everything/README.md:17` claims "(59 today)" against **61** dependencies | `lean` ships in three bundles and is documented in none of them. `remove-plugin.sh:144` maintains that `(N today)` string only on REMOVAL — nothing updates it when a plugin is ADDED, which is how it went stale |
| D9 | `scripts/context-budget.sh:104` | The dynamic channel probes UserPromptSubmit with **one fixed string** — "refactor the auth module, add tests and review the diff". `api-docs-first/hooks/remind.sh` matches on `(sdk\|endpoint\|integrat\w*\|webhook\|oauth\|graphql)`, none of which appear in it, so it is baselined at **0** while emitting **206 B ≈ 52 tok** on a real prompt | Any hook whose trigger vocabulary misses that one sentence is scored zero forever and its growth is unmetered. Fix: a small probe corpus scored on max, or an explicit `unmetered:` line naming every UserPromptSubmit hook that measured 0 — the honesty pattern the script already uses for remote MCP |
| D10 | `plugins/skill-router/hooks/summary.sh:56` → `scripts/retirement-queue.sh:106` | `summary.sh` writes `pending_low` after dropping the `flushed` flag `route-prompt.sh:53` sets; `retirement-queue.sh` then reads `fired` and `pending_low` as one stream | The retirement ledger cannot distinguish "accumulated but never shown to the model" from "surfaced". Across 17 local sessions, `security-review` (14), `error-handling-design` (12), `concurrency-safety` (11), `observability-design` (10) appear only in `pending_low` — so "never surfaced" is unproven for exactly the skills a retirement queue would rank first |

Plus one contradiction worth a clause: `opinion-round:41-45` says the round steps
back when "a grill ledger is open", and `grill:46-52` writes exactly that ledger
before invoking the round at `grill:117-124`. Standing: agent-graded, currently
self-contradictory.

---

## 6. Hypotheses this audit KILLED

Recorded because a distillation that only reports confirmations is not measuring.

| Tempting move | Why it is wrong | Evidence |
| --- | --- | --- |
| "Delete dead reference files" | There are none | 0 of the reference `.md` files repo-wide are unnamed by any doc |
| "Cut duplicated prose across skills" | Literal duplication is 0.14% | 14 shared long lines out of 10,244 across all 130 SKILL bodies |
| "Merge the 6 motion-family craft skills — they all repeat `prefers-reduced-motion`" | Each names a DIFFERENT pattern-specific failure (rAF pointer loop, rotation `setInterval`, `startViewTransition` wrapper, physics runner, Lenis start, `uTime` uniform) and all delegate the shared mechanism to one reference. That is the doctrine working | read all six |
| "Merge `mysql` + `mariadb`" | `mariadb:8-22` is *inverted* advice against the MySQL answer ("No `utf8mb4_0900_*` collations", "JSON is an alias for LONGTEXT"). Merging puts the answer and its negation in one body | quoted both |
| "The domain plugins overlap (security/secret-scanning, devops/dev-env, observability/performance/resilience)" | Each ships an explicit `Defer rule` / `Boundaries` section and honours it | read the boundary sections |
| "Compress the 33 near-identical `commands/review.md` files" | They are chassis output from one template, gated byte-identical by `generate.sh --check`, and commands cost only their description | `diff plugins/vue3/commands/review.md plugins/nuxt/commands/review.md` = 3 lines of 54 |
| "`claude plugin eval` doesn't exist" (the web research concluded this from docs) | It exists in the installed CLI with `--ablation with-without`, `--judge-model`, `--json`. The docs the researcher read do not list it | `claude plugin eval --help` |
| "10 bundles is too much shelf — merge the contained ones" | A bundle's own marginal always-on cost is **−10 to 0 tokens**; it costs exactly its members. Merging `quality-principles-suite` into its 100%-container costs a target user **+5,396 tokens** | measured per bundle, §8e |
| "The single-skill plugins are shells" | 6 of them ship a real mechanism (a deny hook, a scanner script, an MCP server, dispatched agents), and the bundle mechanism already delivers packaging at zero token cost — merging only spends install granularity | §8e |
| "`remove-plugin.sh` leaves the bundle table drifting, ungated" — **CLAUDE.md's own claim** | Refuted by running it: `validate.sh` exits 1 with five hard FAILs (2 dangling bundle deps, a dangling `rules.tsv` row, 2 dangling command refs) and `context-budget.sh` blocks on `−124`. The table is gated by inheritance. CLAUDE.md should be corrected, or someone will build a redundant check | simulation in a full copy |
| "craft-layer is 13 skills sliced from one capability" | 7 of the 8 motion skills are ordered first-fit decision procedures on *different axes* — `measured-zero-shapes.md:87-91`'s not-zero shape. The merge yields the measured-zero shape at ~800 lines against a 150 ceiling | §8d |
| "The 150-line ceiling is a growth attractor everywhere" | True in workflow (+31% bytes at a frozen 154), **false in craft-layer** (worst +4.7%) and **false in infra** (bytes-per-line flat in all six pinned skills). The craft failure mode is the opposite — deletion | §8d, §8e |

---

## 7. What this run did NOT cover

- **Nothing was changed in `plugins/`.** This run measured and recorded; every
  proposal above is still a proposal. The two spawn failures that delayed the
  design and infra audits are recorded in
  `taskmaster-docs/distill-2026-08-20-retry-queue.md` (cause: a per-session agent
  pane budget, not a system limit — stopping finished agents freed the slots).
- **Whether any skill has ever helped a real user.** `retirement-queue.sh` reports
  **127 of 130 skills** with zero surfaced and zero invoked in the local ledgers,
  and 92 of 130 have no `rules.tsv` row at all — so "never surfaced" mostly
  measures router coverage, exactly as that script says. W1 is the fix.
- **Remote MCP surface** — `registry-source:reui` is counted 0 by our meter and
  is not measurable offline.

---

## 8. Cluster findings

Five Fable-xhigh audits, one per cluster, each read-only and each required to
report the proposals it KILLED. Condensed here; the numbers are theirs, spot-checked
by re-running the load-bearing ones.

### 8a. Meta / session-shaping (claude-authoring, skill-router, plugin-scout, vercel-skills-scout, registry-source, brain, hindsight, terse, candor, lean, fresh-take, orchestration)

**The meter reads the OFF state.** `context-budget.sh:66-79` runs SessionStart
hooks in a sandbox with an empty `HOME` and no env, so state-gated hooks emit
nothing and score ~0. Re-measured in the ON state:

| Hook | Gate reads | ON state | Verified |
| --- | --- | --- | --- |
| `plugins/terse/hooks/activate.sh` | 0 (886 tok of descriptions only) | **4,171 B ≈ 1,043 tok** with `CC_TERSE=ultra` and `CLAUDE_PLUGIN_ROOT` set | re-ran it — 4,171 |
| `plugins/terse/hooks/mode.sh:176` | 0 dynamic | **697 B ≈ 174 tok per prompt** (its own header claims "~120 tokens… measured: 476 chars", +46% stale) | agent-measured |
| `plugins/brain/hooks/inject.sh:63-66` | 89 | **2,104 B ≈ 526 tok** with a 60-line `brain/INDEX.md` (clamped by `head -c 2048`) | agent-measured |

**≈1,569 always-on tokens plus 174/prompt are invisible to the gate in exactly
the configuration a user runs.** This is the second independent reason our meter
under-reads, on top of the per-component floor in §2.

Other findings: `plugin-scout/scripts/pick.sh` and `vercel-skills-scout/scripts/pick.sh`
are **byte-identical** (44 lines, `diff` = 0) and their reference prose differs by
2 lines — the prose merges, the scripts must not (independent installs).
`orchestration/skills/ultra-assess/SKILL.md:51-75` claims to quote the hook
"verbatim"; the hook injects 1,092 chars, the block is 1,740 and they diverge
after 90. `plugins/brain/ROADMAP.md` ships 93 lines of maintainer planning to
installers, including a literal `/taskmaster:task` prompt and a pointer into
gitignored `taskmaster-docs/`. `prime.sh:35-41` **under-claims** its own standing
("the comment is the only thing holding them together, a `recorded` tier") —
false since `pc_prime_coverage` landed, and an under-claim erodes the has-teeth
convention exactly as fast as an over-claim.

### 8b. Workflow / process (taskmaster, task-runner, code-architecture, approaches, testing, code-review, git-workflow, comment-discipline, command-guard, debugging)

**The 150-line ceiling stopped measuring.** Verified independently:
`task-runner/skills/task-execution/SKILL.md` sat at **exactly 154 lines across 20
commits (2026-07-17 → 08-02)** while bytes went **9,288 → 12,193 (+31%)** and lines
over 110 chars went **2 → 29**. `task-cards/SKILL.md`: 105 lines/4,550 B →
154/9,318 — lines +47%, bytes **+105%**, with one line (`:123`) at **1,526 chars
≈ 380 tokens** carrying four separate rules. Content accretes until the gate bites,
then goes onto an existing line.

**What one medium feature costs**: `/taskmaster:task` on a medium feature loads
21 mandatory artifacts ≈ **37.3k tokens**, plus ~13.8k for the conditional set a
medium feature actually trips — **~51k tokens of instruction text**, on top of the
always-on listing. Hook stdout is NOT the cost problem here: on a synthetic `Edit`
all seven PostToolUse hooks in the cluster emitted 0 bytes; `taskmaster/hooks/remind.sh`
emits 199 chars on a work-shaped prompt.

Merge candidates with the plugin's own words as evidence: `approach-deliberation`
+ `opinion-round` (`plugins/approaches/lane.tsv:12-16` already declares them ONE
territory; `opinion-round:107` concedes the output shapes are identical) ≈ 3k
on-invoke; `code-architecture:task-orchestration` → `plan-before-code` (its
parallel-safety rule is stated in **four** places; 0 router rows, 0 lane rows).
`taskmaster/commands/task.md:14-31` is an 18-line boost preamble byte-duplicated
into three sibling commands and gated for parity by `validate.sh:569-610` —
72 lines / ~1,600 tokens shipped for one rule that `skills/ultra/SKILL.md:17-36`
already owns.

### 8c. Stack / language (18 plugins)

**The strongest untested claim in the marketplace, found inside our own records.**
`rationale/stack-skill-baselines.md:39-44` kept every stack plugin on the theory
that they "encode version leverage maps and lockfile-pinning behavior, not
idioms" — and `rationale/measured-zero-shapes.md:23-34` records that per-version
idiom maps **measured 0 delta twice and were deleted**, with the blind control
finding defects the treatment missed. The half that saved them is the half that
scored zero; the surviving justification (manifest/lockfile reading) was never
exercised because "fixtures had no manifests".

Leverage ratio by line, four skills classified rule by rule:
`nextjs` **69%** (13 version-pinned rules, and they are *inversions* — "Since
Next.js 15, `fetch` defaults to `no-store`… the Next 14 cached-by-default mental
model is inverted"), `vue3` 57%, `sql` 56%, `php` **27%** (100 of 141 body lines
are language idiom).

Duplication is concentrated in the DB family: "index every foreign key" appears
in **6** places, "read the plan before optimizing" in 5, "batch backfills" in 5.
A migration file in a MySQL project co-fires `sql` + `database-design` + `mysql`
= **4,333 tokens** of bodies at once, and `database-design:16-20` states the seam
it then breaks twice in the same file. **Merge `database-design` into
`sql-best-practices`; keep `plugins/database` for its PreToolUse destructive-SQL
guard and its agent** — a mechanism is the one thing that has never measured zero.

**Rejected on evidence:** merging `mysql` + `mariadb`, despite 5 duplicated
ideas. `mariadb:8-22` is *inverted* advice against the MySQL answer ("No
`utf8mb4_0900_*` collations", "JSON is an alias for LONGTEXT"). Merging puts the
answer and its negation in one body.

19 compressions were identified totalling **181 lines / 2,771 tokens**, of which
a **zero-argument subset — 44 lines / 668 tokens** — is second recaps in files
that already ship one, plus closing summaries that `authoring-skills:84` already
forbids ("no closing summary").

### 8d. Design / UI / craft (craft-layer, ui-ux, shadcn-studio, design-preview, a11y, i18n)

**A previous distillation silently corrupted shipped prose, and it is still
shipping.** Commit `3c8e6d7` (2026-07-27), message *"craft-layer prose strip —
net -76 lines, no capability removed"*, deleted wrapped **continuation** lines,
severing sentences. **11 corruption sites in 9 files are on `HEAD` today.**
Verified three by hand:

- `scroll-orchestration/SKILL.md:8-9` now reads "…needs orchestrated scroll motion
  and WHICH / ScrollTrigger API:" — the deleted line was "engine drives it — then
  pins the contract and the budget. It does not re-teach the", i.e. the clause
  naming what the skill decides. `git show 3c8e6d7^:…` shows it intact. The
  commit message's "no capability removed" is false.
- `webgl-effects/SKILL.md:8-9`: "…earns the GPU cost and / Three.js: the renderer…"
- `information-design/SKILL.md` **ends mid-sentence**: "Cite the"

The gate that would catch it does not exist, and the proposed byte ceiling and
300-char lint in W4 would fire on **zero** craft-layer skills while these 11 ship.
The audit proposes `pc_dangling_prose` — column-0 prose line ending in a comma or
a function word, followed by a blank line — measured at **5 hits, 5 true
positives, 0 false positives** repo-wide, and states its own residual honestly:
**6 of the 11 sites are mid-paragraph and uncatchable by that regex.**

**`contrast.mjs` is invoked by nothing** — 183 lines, 3 test fixtures, and zero
runnable call sites (verified: every hit is prose or its own header), while
`gates.spec.ts:143-148` **disables axe's `color-contrast` rule** and cites
`contrast.mjs` as "the gate of record". An automated check switched off in favour
of a stronger one that never runs. One line in `commands/audit.md:80` closes it.
Correction to `rationale/distillation-review-2026-08-17.md:109-111`: `divergence.mjs`
is invoked from **one** site, not two — `commands/craft.md:180-182` explicitly
forbids running the audit's gates from the craft step.

**craft-layer is not 13 skills sliced from one capability**, and the merge was
tested rather than assumed: 7 of the 8 motion-family skills open with an ordered
`Decide: does X earn its cost?` procedure keyed on a *different axis*, each
terminating in "don't" — `measured-zero-shapes.md:87-91`'s not-zero shape ("the
order is the content"). Merging them yields either a 7-branch router or an
unordered catalogue, which is the measured-zero shape, at ~800 lines against a
150 ceiling. **Killed.** The distillation there is horizontal: 41 of 45
`## References` bibliography entries re-gloss a file the body already cites at a
decision point — **89 lines / ~1,552 tokens**, and cutting them returns ~7 lines
of headroom per skill, which is the pressure that produced the truncations.

**This audit also killed a proposal from §4 of this document.** W5 suggested
`disable-model-invocation: true` on craft-layer's 8 flow-only skills (~470
always-on tokens). `plugins/skill-router/rules.tsv:91-95` gives the reason it is
wrong: those skills "deliberately reach sessions via `/craft-layer:craft` and the
catalog channel, not per-file rules — **their triggers are prompt-shaped, not
file-shaped**". The flag deletes the description, which IS the prompt-shaped
channel. All 8 descriptions were checked for one a bare prompt could not express;
none. **W5's third bullet is withdrawn for those 8** — the lever stands, the
target was wrong.

Two more gate candidates, both measured: a **sibling-as-child reference path**
check (`references/X.md` cited from inside `references/`, resolving to
`references/references/X.md`) — **7 repo-wide, 0 possible false positives**; and
one genuinely dead reference, `scroll-orchestration/references/lenis-substrate.md`
(73 lines), whose five rules are already in the body — with the honest catch that
its `> Last verified:` stamp must move into the body first or
`check-doc-staleness.sh` loses its only lenis input.

### 8e. Infra / quality domains + all 10 bundles

**This audit's most useful output is what it refused to cut.** It proposed
**zero skill/command/agent/reference deletions and zero merges**, and each
refusal carries a measurement.

**Bundles: keep all 10, and the containment numbers argue FOR the split.**
A bundle's own marginal always-on cost measured between **−10 and 0 tokens** —
it costs exactly its members. So merging `quality-principles-suite` (9 members,
100% contained in taskmaster-suite) into its container would force anyone who
wanted those 9 to take 31: a **+5,396 always-on token regression** for that user.
Deleting `product-suite` (277 tok, 100% contained in `everything`) saves **zero
tokens from anyone** and removes a curated install path. The negative deltas
scale as ~n/6 and are floor-rounding, not a real dedupe.

**Four boundary-overlap hypotheses tested and killed, with reciprocal quotes.**
security/secret-scanning (measured: on a 32-char `VITE_API_SECRET` secret-scanning
**denies at PreToolUse** so security's PostToolUse never runs — no double report;
on the short form secret-scanning correctly allows and security's detector fires
alone), devops/dev-env, observability/performance/resilience
(`observability-design:146-148` — "it owns whether the catch should EXIST, this
owns what a kept one EMITS. One finding, one owner", reciprocated at
`error-handling-design:142-144`), system-design/api-design. **The boundaries hold.**

**A CLAUDE.md claim is stale and should be corrected.** CLAUDE.md says of
`scripts/remove-plugin.sh`: *"those suites' member counts get a WARN, not an edit
— so the bundle table at README.md drifts on exactly the removal the script is
for. Nothing gates that table."* Refuted by simulation (`remove-plugin.sh packages
--apply` in a full copy): `validate.sh` exits 1 with **five hard FAILs** — two
dangling bundle dependencies caught by the all-bundle gate at `validate.sh:449-462`
(verified present), a dangling `rules.tsv` skill row, and two dangling command
references — and `context-budget.sh` blocks on `taskmaster-suite −124`. The table
is gated, by inheritance. The two residuals worth recording instead: (1) the table
is not *self*-gating — immediately post-removal it shows stale counts while
`generate.sh --check` reports no drift, because it is consistent with a manifest
`validate.sh` has already condemned; (2) `remove-plugin.sh:131-134` hand-`sed`s
the generated `everything` row whose own header says "do not edit these rows by
hand" — two writers, one region.

**All four cluster hooks use a channel the model actually receives** — the two
PreToolUse denies emit `permissionDecision` JSON (415 B / 744 B measured on hit,
0 B clean), `security/hooks/write-scan.sh` correctly uses
`hookSpecificOutput.additionalContext` rather than PostToolUse stdout (which the
model never sees), and `api-docs-first/hooks/remind.sh` uses UserPromptSubmit
stdout, which does reach the model. **No defect.** Under `everything`,
**16 Pre/PostToolUse hook invocations fire on every Write/Edit** across 13 plugins.

The ceiling growth-attractor signature from §8b **does not reproduce here**:
bytes-per-line is flat across every commit of all six ceiling-pinned cluster
skills, and lines over 110 chars is 1 in every file at every revision.

At stake but deliberately not cut: **23 `## Anti-patterns` sections, 248 lines /
~3,145 on-invoke tokens.** Hand-checking `observability-design` found 5 of 6
bullets restating the body — and the sixth carrying the ownership split with
`resilience` that exists nowhere else. `measured-zero-shapes.md:46-52` records a
checklist *narrowing* a review (treatment findings a strict subset of control).
That is the risk, and it makes one control/treatment run on a single stripped
section the cheapest decisive experiment in the cluster.
