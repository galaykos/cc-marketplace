# Marketplace necessity review — 2026-11-12

Branch `plugin-necessity-review`. §1's verdict was executed on this branch as hindsight 0.13.0
(user pick, 2026-11-12); every row in §2 is still a proposal.

Two questions: did `hindsight` solve anything, and which of the 42 plugins should be kept,
shrunk, merged or retired. The bar is `README.md`'s opening paragraph: a rule the model gets
wrong from memory, or a mechanism prose cannot replace.

## Evidence and its bounds

| Source | What it holds | Bound |
| --- | --- | --- |
| `~/.claude/hindsight/*/skills.jsonl` | 674 Skill-tool invocations, 50 projects, 2026-10-04 … 11-12 | Skill tool only. A skill loaded by `Read` from a command, hook or agent leaves no row |
| `~/.claude/hindsight/*/ledger.jsonl` | 1,377 rows in 53 ledgers: 182 session, 1,195 agent (with `agent_type`) | SessionEnd only; a killed session writes nothing |
| `bash scripts/turn-cost.sh --skills` | per skill: router `surfaced`, Skill `invoked`, transcript attribution | 71% of requests carry attribution; joins on the BARE skill name (finding 9) |
| `~/.claude/plugins/installed_plugins.json` | install count per plugin | names and counts only |
| `rationale/marketplace-taskforce-review-2026-10-11.md`, `plugin-landscape-comparison-2026-10-31.md`, `session-retro-2026-11-05.md` | prior verdicts and measured friction | relayed, not re-run here |

Only counts of skill and agent NAMES were read from other projects' ledgers; no transcript
and no other project's files were opened. No eval was run. Zero use proves nobody used it in
this sample on this machine; non-zero proves it fired, never that it helped. A plugin whose
value is a hook (command-guard, secret-scanning, skill-router, session-hud) is invisible to
every source above.

## 1. hindsight

**It solved something, in one project, by a path the plugin does not describe.**

What it produced:

| Output | Evidence |
| --- | --- |
| Three session retros, 878 lines | `rationale/session-retro-2026-10-13.md`, `-10-21.md`, `-11-05.md` |
| 80 `hindsight:transcript-miner` dispatches | agent rows in the ledgers (4th most-used agent type) |
| Six `feedback` memory rules, applied 2026-10-22 | `applied.jsonl`; six of the eight entries in this project's `MEMORY.md` |
| Plugin fixes traced to the 11-05 retro | PR #251: `7debdfce` code-review, `c210a1dd` skill-router, `83070de1` task-runner, `65a8dfe6` ask-ledger, `6fbf4fec` and `952ac998` candor, `c1125aee` overseer |

No other artifact in the repo produced a defect list against shipped plugins from real
sessions. That is the capability worth keeping.

What did not work:

| Part | Finding |
| --- | --- |
| Ledger ranking and `mined` bookkeeping | 14 of 1,377 rows were marked mined, all in this repository and all but one dated 10-08 … 10-18: the 10-21 harvest marked what it read, the 11-05 retro (46 sessions) marked at most one. The step is prose and ran once in two harvests. (This row first said 0: the count grepped for `"mined":true` and the hand-written rows have a space after the colon. Corrected the same day with `jq`.) |
| "Current project only" boundary (`harvest/SKILL.md` Boundaries, recorded) | the 11-05 retro read every project under `~/.claude/projects`. The useful run broke the skill's own rule |
| `scripts/outcome.sh` | prints six identical rows, `15.88 → 28.44` friction, all `worsened`: six rules share one timestamp, so the script cannot tell them apart, and the after-window is overseer-heavy. Its one live output argues for retracting rules that are plainly in use |
| Reach | `hindsight:harvest` logged in 1 project of 50; 11 installs |
| `/hindsight:claude-md` | 0 logged uses. Its own README says the host's `/doctor prompt-audit` covers more surfaces |
| `hooks/skill-use.sh` | read by `scripts/turn-cost.sh` only, a maintainer path. For an installer it is a process per Skill call with no reader |
| `collect.sh` session rows | 35 session rows for 28 distinct session ids in this project: a resumed session is counted again |

**Verdict: keep, cut to what ran.** Keep `transcript-miner`, `collect.sh` and a `harvest`
rewritten around the path that produced the retros (a date window, a script that ranks and
marks, defects filed against the artifact that ran). Retire `outcome.sh` with `applied.jsonl`,
and `/hindsight:claude-md` with `claude-md-check.sh`. Decide `skill-use.sh` on its own: it is
this repository's only usage instrument and no installer's.

The alternative is honest too: the plugin's measured value is to a marketplace maintainer, so
it could become a project skill under `.claude/skills/`. It stays a plugin only if a rule
about someone else's repo is expected from it; the sample holds none.

## 2. All 42 plugins

`inv` = Skill invocations (all projects). `agents` = agent rows. `inst` = installs.

### Keep as is — used, and each ships a mechanism

| Plugin | inv | agents | inst | Note |
| --- | ---: | ---: | ---: | --- |
| taskmaster | 151 | 54 | 13 | spine |
| code-review | 110 | 321 | 13 | most-dispatched agent in the sample |
| task-runner | 59 | 182 | 13 | |
| code-architecture | 42 | 24 | 11 | skill-level fold open (§3) |
| git-workflow | 34 | 0 | 12 | |
| secret-scanning | 17 | 0 | 12 | hook |
| overseer | 10 | 0 | 13 | slow per the 11-05 retro §1; a defect list, not a necessity question |
| stack-scan | 8 | 0 | 5 | |
| design-kit | 8 | 0 | 10 | |
| testing | 7 | 5 | 12 | `testing-best-practices` attributed 921 times |
| laravel | 3 | 49 | 11 | `backend-engineer` 49 rows |
| web-dev | 0 | 52 | 10 | both agents used; skills path-loaded |
| ui-ux | 4 | 34 | 10 | |
| security | 1 | 14 | 10 | |
| devops | 0 | 12 | 10 | |
| debugging | 4 | 4 | 13 | |
| database | 0 | 2 | 10 | write guard hook |
| candor, command-guard, skill-router, session-hud | n/a | n/a | 11, 7, 11, 3 | hook or mod plugins; no source here measures them |
| blender, unity-traps, gamedev, meshy, pixel-art | 0–4 | 0 | 2–3 | transcript attribution 336, 256, 381, 22, 111; each ships a checker |
| godot, unreal, phaser | 0 | 0 | 0, 0, 1 | no project of that engine in the sample; opt-in, so zero is not evidence |
| ui-libraries | 0 | 0 | 10 | the one measured positive eval delta (PrimeReact, control 1/5 vs 5/5) |

### Retire — candidates

| Plugin | Evidence | What an installer loses |
| --- | --- | --- |
| **pixijs** | A 2,122 B pointer skill. Its own manifest says the v7→v8 table was retired 2026-11-09 after four control-armed cases showed no lift. No rule, no mechanism: it fails the bar on its own description | a link to the vendor's skills; move one line to `stack-scan`'s official-complements table |
| **brain** | 13 installs, 0 `brain:indexer` rows among 1,195 agent rows, and this repository has no map (the SessionStart hook said so today). The maintainer does not build one where the plugin is developed. A typed `/brain` leaves no row, so reads of an existing map are unmeasured | a committed codebase map. Removal needs a sweep: hindsight's brain destination, `taskmaster:context-scout`, overseer, git-workflow and task-runner name it |
| **ultra-deep-research** | 11 installs, 0 invocations, 0 attribution, 3 `researcher` rows in 40 days. The host ships a deep-research command | the separate verifier and contradiction ledger. Rare use is expected of a research tool; retire only if no run is remembered where it beat the host's |

### Merge — candidates

| From → into | Evidence | Cost |
| --- | --- | --- |
| **all-plugins → stack-scan** (`/stack-scan:suggest --everything`) | two commands and one script; `suggest --full` already installs "everything stack-relevant", and all-plugins' README sends the deciding to stack-scan | S–M; all-plugins is installed at user scope, so keep the command name as an alias for one release |
| **ask-ledger → candor** (one more clause) | both are Stop gates on the same failure, work that quietly does less than asked. ask-ledger's README gives one reason to stand alone, "so it can be disabled on its own"; a `/config` option does that. The 11-05 retro logged 21 false-positive rows in 11 sessions for it and 31 for candor: two gates, two chances at an extra turn | M; lane rows, harnesses, the `named-things-accounted` eval |
| **asset-forge → blender** | both need Blender and a Blender user wants both. asset-forge: six skills, 0 invocations, `pipeline` attributed 22 times, first shipped 2026-11-08 | M; young plugin, so merge before installs accumulate |
| **toolchain-experts → code-review** (one `analyzer-expert`) | 8 agent rows against 321 for `code-reviewer`; 0 invocations of `analyzer-triage`; dispatched only from `code-review` and `ui-ux` prose. Five agents with one skeleton is open action 7 of the 10-11 review | M |
| **approaches → code-architecture** | all five skills read zero in all three sources; `opinion-lens` has 36 rows, dispatched by taskmaster. Shape-then-file-plan already describes the pair. Ten plugins name `approaches:` | L; lowest priority, a rename sweep for one fewer plugin |

### Shrink — the plugin stays, entries go

| Plugin | Evidence | Action |
| --- | --- | --- |
| **resilience** | no hook; 6 invocations; 0 rows for either worker agent; every eval case's control arm passes (`CLAUDE.md` "Evals"), so nothing can show it helping. The router surfaced its skills 176 times | fold `concurrency-safety`, `error-handling-design`, `event-driven` into `resilience-design/references/`; drop the two agents or name a dispatch that used one |
| **craft-layer** | 627,892 B under `skills/`; 9 of 14 skills read zero in every source | fold the four motion skills and `webgl-effects` into references (open action 13) |
| **api-design** | 10 installs; all four skills read zero invocations and zero attribution; router surfaced `api-design` twice | keep `api-docs-first` and the reminder hook, the one behaviour rule; fold `graphql-grpc` and `docs-upkeep` to references |
| code-architecture, security, ui-ux | `solid-principles`, `yagni-check`, `domain-modeling`, `api-auth`, `data-privacy`, `design-tokens` are still listed entries | open action 12 of the 10-11 review, still unexecuted |

## 3. Findings

1. `plugins/pixijs/.claude-plugin/plugin.json` — the description records its own content as retired → the plugin ships a link.
2. `plugins/hindsight/skills/harvest/SKILL.md` "Mark mined" — 14 of 1,377 rows marked, none from the 11-05 retro's 46 sessions → the ranking re-offers sessions already mined.
3. `plugins/hindsight/scripts/outcome.sh` — one timestamp for six rules gives six identical rows → the loop the README calls closed cannot grade anything.
4. `plugins/hindsight/skills/harvest/SKILL.md` "Boundaries" — the retro that produced fixes read all projects → the rule and the useful behaviour disagree; one of them is wrong.
5. `rationale/marketplace-taskforce-review-2026-10-11.md` actions 7, 12, 13 — recounted today against `plugins/*/skills/` and `plugins/toolchain-experts/agents/`: none executed → 13 listing entries and 4 agents the review already judged surplus.
6. `plugins/resilience/agents/` — 0 dispatches of either worker in 1,195 agent rows.
7. `plugins/brain` — 13 installs, 0 indexer runs.
8. 63 of 134 shipped skills show no recorded use in any source (`turn-cost.sh --skills`; a floor, see bounds).
9. `scripts/turn-cost.sh --skills` — reports `review | asset-forge | invoked 98 | transcript 1980`; 98 is exactly `code-review:review`'s count → the join is on the bare name and mis-credits a plugin. Fix before the next retirement read.

## 4. Defects from the first 0.13.0 harvest

`select.sh --top 3 --since 14` on this repository, 2026-11-12; two distinct conversations
after the fork fold. Each row is one transcript quote relayed by a miner that sampled its
file. **None was re-checked against current source**, so a row may already be fixed.

| Artifact | What happened | Quote | Session |
| --- | --- | --- | --- |
| `plugins/candor/hooks/gate.sh`, completion clause | blocked a docs-only edit turn because no command ran after the edit | "[candor] This turn says the work is done, but no command ran after the last edit." | `18499add` |
| `plugins/candor/hooks/gate.sh`, citation clause | blocked a turn citing a file the assistant had read in a sandbox outside the repo | "02-build-signup-form.md:69 — no file named 02-build-signup-form.md found under …/cc-marketplace" | `06f88e46` |
| `plugins/ask-ledger/hooks/ledger.sh` | the prompt was the app button text "Turn on Auto-fix"; "Auto-fix pull requests" became a named deliverable and Stop was blocked | "ask-ledger: your final reply does not say what happened to Auto-fix pull requests, which the request named." | `18499add` |
| `plugins/secret-scanning` write guard | blocked the code-review findings file twice; reviewer output quoting a URL read as a credential in a URL | "secret-scanning: blocked a write containing a credential embedded in a URL … (file: …/.claude/code-review/rv/findings-92daeb35.txt)" | `18499add` |

Three of the four are Stop-gate or guard false positives in candor and ask-ledger, the pair
§2 proposes to merge.

## 5. Not done

- No eval, no control arm: every verdict is usage plus prior review, not a measured delta.
- Hook value is unmeasured for every hook-only plugin; no block or deny counter exists.
- `references/` bodies, hook scripts and harnesses were not read for the 41 plugins other than hindsight; descriptions, skill lists and the prior reviews were.
- Whether the host's `/insights` covers harvest was not checked.
- Outside hindsight nothing was removed, merged or bumped. Each row in §2 awaits a pick.
- `hooks/skill-use.sh` was kept on by default; only its false claim about a reader was fixed.
