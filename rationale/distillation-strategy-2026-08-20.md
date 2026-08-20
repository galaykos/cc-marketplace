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
| `disable-model-invocation: true` on skills that only ever fire because a command names them explicitly — e.g. craft-layer's 8 flow-only skills (webgl-effects, section-decisions, scroll-orchestration, physics-motion, page-transitions, motion-tiers, kinetic-typography, interaction-fx), which no other plugin names and no `rules.tsv` row routes | 1,876 description chars ≈ 469 tok by our meter, more by the host's | up to ~470 tok, at the cost of direct-invocation discovery |
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
  command that names them (craft-layer's 8 flow-only skills are the clear set),
  which removes their descriptions from the listing entirely.
- **Standing:** `recorded` until tested; the test is one install and one prompt.
- **Does NOT fix:** the marketplace's own routing intelligence — `route-prompt.sh`
  also does prompt-text matching and rank arbitration, which `paths:` does not do.
  Expect a partial replacement, not a deletion, and measure before claiming either.

### W6 — Close the five live defects found while measuring

Listed in §5. Four are one-line fixes; one is a router bug that silently disables
a whole plugin.

---

## 5. Live defects found during this audit

| # | Location | Defect | Impact |
| --- | --- | --- | --- |
| D1 | `plugins/skill-router/hooks/route.sh:68-73` + `rules.tsv:127` | `match_glob` compares with `case "/$file_path" in *"/$mid/"*` — **case-sensitive**. `**/resources/js/Pages/**` is inertia's ONLY routing row | On a project scaffolded with lowercase `resources/js/pages/` (Laravel's current starter kits), the inertia plugin routes **nothing**; its 2,134-token skill never loads. `rules.tsv:125` `**/Livewire/**` has the same exposure, mitigated by a second row |
| D2 | `plugins/mariadb/skills/mariadb-best-practices/SKILL.md:6` | Stamp says 2026-08-02; commit `f19e084` (2026-08-12) rewrote the 10.6 EOL fact at `:33-34` without bumping it | `check-doc-staleness.sh` reads a stamp that no longer describes the file |
| D3 | `plugins/react/skills/react-server-state/SKILL.md:32,72-73` | Version claims ("TanStack Start is v1 RC", "v5: import `keepPreviousData`") with **no stamp**; passes the version-leverage gate only because a sibling skill carries one | The gate is plugin-scoped; the decay is file-scoped |
| D4 | `plugins/web-dev/agents/frontend-reviewer.md:7,21,25` | Names 8 skills, three times in 19 lines, and omits `react-data-grid` although `react` and `web-dev` ship in the same bundle | A TanStack Table file reviewed by this agent gets zero data-grid rubric, including the index-keyed `rowSelection` bug that silently bulk-deletes the wrong rows |
| D5 | `opinion-round:32-37` / `grill:118-120` / `brainstorm:94` | The double-deliberation guard reads `.claude/approaches/deliberated.json`, but neither taskmaster path that runs a round WRITES it | The guard is unarmed on the two paths that most often run a round |

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

---

## 7. What this run did NOT cover

- **Design/UI and infra/bundle clusters**: their audits are appended in §8 when
  they return; see `taskmaster-docs/distill-2026-08-20-retry-queue.md` for the
  spawn failures that delayed them.
- **Whether any skill has ever helped a real user.** `retirement-queue.sh` reports
  **127 of 130 skills** with zero surfaced and zero invoked in the local ledgers,
  and 92 of 130 have no `rules.tsv` row at all — so "never surfaced" mostly
  measures router coverage, exactly as that script says. W1 is the fix.
- **Remote MCP surface** — `registry-source:reui` is counted 0 by our meter and
  is not measurable offline.

---

## 8. Cluster findings

Appended per cluster as each audit lands.
