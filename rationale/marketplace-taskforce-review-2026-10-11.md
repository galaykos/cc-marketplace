# Marketplace task-force review — 2026-10-11

**Standing: `recorded`.** A dated record; nothing reads it back. Three reviewers (one
commander, two assistants) read the tree on branch `review/taskforce-2026-10-11` at
`ad091dcc` (CI's CLI pin was 2.1.291 that day — recount: `grep -m1 '^PIN=' scripts/official-validate.sh`),
read-only. No file but this one was created or edited; no baseline was updated.

The ask, verbatim: "make this plugin marketplace better! review the consistency of the
plugins, suggest cleaning house of redundant stuff, review things that may just 'take usage
without any result'." Three axes: **A** consistency, **B** redundancy, **C** usage without
result. Every load-bearing claim below was re-run by the commander against the current tree
and is marked **CONFIRMED** (reproduced or grepped today), **PLAUSIBLE** (argued from code,
not executed) or **REFUTED**. Claims carried from an assistant without a re-run say so.

Prior reviews this one stands on and does not repeat: `marketplace-endgame-review-2026-09-14.md`,
`marketplace-consolidation-plan-2026-09-14.md`, `marketplace-trend-audit-2026-09-16.md`,
`specialist-panel-2026-09-22.md`, `2026-08-31-token-cost-review.md`, `measured-zero-shapes.md`,
`2026-09-15-listing-eviction-probe.md`. Decisions recorded there stay decided (§6).

---

## 1. Verdict

The marketplace is structurally sound and already well-pruned — the consolidation waves of
September did the big cuts, and nothing proposed here re-opens them. What this pass found is
different in kind: **four shipped defects that cost a turn or a tool call on every session or
edit with nothing to show for it** (a sibling path that cannot resolve in the versioned cache,
a brain map that orders its own refresh every session after it is committed, a ledger that
turns any quoted phrase into a deliverable and blocks Stop on it, and an installer that writes
a listing-budget setting the repo's own probe measured as buying nothing), **one unmetered
per-edit cost** (two 8 KB skill bodies nudged for a Read on every `.ts`/`.js`/`.py`/`.go`/`.rb`
edit), and **a retirement instrument that reads zero by construction** for every skill loaded
by path. Those are the fixes worth a release. The checklist-skill fold the September plan
queued behind an eval is a packaging decision, not a measurement, and should be taken as one.
Consistency gaps are real but cheap: companion rows, changelogs at the current version, one
README skeleton, one README-inventory check.

## 2. Top actions, ranked

Rank is "what an installer hits first × how cheap the fix is". Standing is what the fix would
have. Bump = `plugin.json` bump required (functional file changes).

| # | plugin(s) | action | evidence | verdict | standing after | effort | bump |
|---|---|---|---|---|---|---|---|
| 1 | task-runner, git-workflow, code-architecture (+ taskmaster owns the script) | **fix** — one phase-sentinel resolver (newest `taskmaster/<ver>/scripts/phase-sentinel.sh` by `sort -V`), byte-locked shared block, at every site | `plugins/task-runner/commands/run.md:100`, `git-workflow/commands/finish.md:13`, `code-architecture/commands/coding-task.md:34` all say `${CLAUDE_PLUGIN_ROOT}/../taskmaster/scripts/phase-sentinel.sh`; executed today: `~/.claude/plugins/cache/cc-plugins-marketplace/task-runner/0.46.0/../taskmaster/scripts/phase-sentinel.sh` → "No such file"; the fallback `find ~/.claude/plugins/cache -name phase-sentinel.sh` returns taskmaster 0.46.0, 0.47.0, 0.48.0 unordered | CONFIRMED | gate (a harness drives the resolver against a versioned fixture) | S | y ×3 |
| 2 | brain | **fix** — exclude `brain/` from the drift diff (`git diff --name-only "$built"..HEAD -- . ':(exclude)brain'`) and add one harness case; no harness references `inject.sh` today | `plugins/brain/hooks/inject.sh:78`; reproduced: build map at HEAD, commit it, next SessionStart prints "brain map is behind HEAD (built …, 1 files changed) — Claude: run the incremental /brain index refresh now … no need to ask" | CONFIRMED | gate | S | y |
| 3 | ask-ledger | **fix** — a quoted span is a name only when short (≤3 words) or capitalised; keep the documented `"digimon"` / `'checkout total'` cases | `plugins/ask-ledger/hooks/ledger.sh:113` `grep -oE '"[^"]{2,40}"…'`; reproduced with the mission prompt: entry `take usage without any result`, Stop gate then demands an accounting line | CONFIRMED | gate (`named-things-accounted` case + harness) | S | y |
| 4 | all-plugins | **fix** — make the `skillListingBudgetFraction` write opt-in (`--budget`), default leave-alone; `context-budget.sh` cites the probe beside its "to fit WITHOUT eviction" remedy line | `plugins/all-plugins/scripts/all-plugins.sh:55` `BUDGET=1`; `rationale/2026-09-15-listing-eviction-probe.md:3` "47/50 vs 47/50, zero delta"; the gate's own output: "cost of doing so: about 12762 system-prompt tokens" every turn | CONFIRMED | gate (all-plugins harness) | S | y |
| 5 | skill-router, code-architecture | **fix** — demote `solid-principles` and `low-cognitive-load` rows from `high` (full-body Read nudge) to `low` (one-line digest) on `*.ts *.js *.py *.go *.rb`; or buy the `solid-control` eval first (§7) and let it decide | `plugins/skill-router/rules.tsv:120-128`; `hooks/route.sh:377` appends `— Read <root>/skills/<s>/SKILL.md`; reproduced on a one-line `.ts` edit: two nudges, 16,157 B of bodies (`wc -c` on the two SKILL.md); repeats per subagent context; unmetered by every channel | CONFIRMED | gate (`route.test.sh`) | S | y ×2 |
| 6 | task-runner, code-architecture, stack-scan, root README | **fix** — companion rows `task-runner → candor`, `code-architecture → candor` in README "Companions" and `plugin-scout/references/signals.md`; a one-line callout atop each README | `plugins/task-runner/README.md:143-144` "install candor or the run can end by narration"; `code-architecture/README.md:87-88` "has teeth only with candor installed"; root `README.md` Companions table lists only craft-layer/ui-ux/ui-libraries; `grep -c candor plugins/stack-scan/skills/plugin-scout/references/signals.md` → 0 | CONFIRMED | recorded (README) + the scout's install line | S | stack-scan y |
| 7 | toolchain-experts | **merge** — five agents → one `analyzer-expert`; per-language "What only you can report" lists become `analyzer-triage/references/<lang>.md`; add `rules.tsv` rows for `phpstan.neon*`, `eslint.config.*`, `tsconfig*.json`, `biome.json`, `.stylelintrc*` → `analyzer-triage` so something other than prose reaches it | five agents, 67–71 lines each, identical H2 skeleton (Procedure / What only you can report / Defer rules / Checklist), all five bind the one skill + `detect-analyzers.sh`; `grep -c 'analyzer-triage\|toolchain' plugins/skill-router/rules.tsv` → 0; dispatch exists only as prose in `code-review/commands/review.md:57` and `ui-ux/commands/audit.md:17`; 649 always-on tokens (5th of 33) | CONFIRMED (structure, routing); the always-on saving (~460 tokens) is the assistant's estimate | gate (lanes, route tests) | M | y |
| 8 | candor | **fix** — `SubagentStart` matcher that skips read-only agent types, or buy `first-edit-discipline` (§7) and apply its own kill criterion | `plugins/candor/hooks/hooks.json` SubagentStart has no matcher (grepped); the assistant measured 966 B delivered to Explore / code-reviewer / task-executor alike; `fable-distillation-2026-09-17.md` §6: "if the with-arm does not pass ≥2/3 the hook is decoration" — never run | PLAUSIBLE (bytes measured by assistant; value unmeasured) | gate | S | y |
| 9 | code-review (+ `scripts/smoke/`) | **fix** — `env HOME="$WS/home"` in `check()` so the first harness section stops writing to the real ledger; then evaluate the clean ledger and retire `verbosity.sh` if real sessions never warn | `scripts/smoke/verbosity-hook-tests.sh:40` pipes into the hook with no HOME redirect (lines 100-104 and 129-134 do redirect); `~/.claude/comment-discipline/verbosity-ledger.jsonl`: sessions `s1`–`s5` = 240 of 574 rows; `verbosity.sh:47` "WRITE-ONLY by design"; matcher `*` = every tool call | CONFIRMED | gate | S | n (harness) / y if retired |
| 10 | hindsight, `scripts/turn-cost.sh` | **fix** — count `Read` tool_use on `*/skills/*/SKILL.md` from the transcripts it already parses; delete the claim at `hindsight/hooks/skill-use.sh:30` that `/hindsight:harvest` reports the ledger (harvest never mentions it) | `turn-cost.sh:257` counts `attributionSkill` (Skill-tool loads) + the hindsight Skill ledger + the router's surfaced file; a skill loaded by `Read` from `route.sh:377`, `task-runner/commands/run.md:59-60` or any command leaves no record → the retirement queue reads zero **by construction** for path-loaded skills (today 67 of 107 read zero) | CONFIRMED (by construction; the Read-count shape is untested) | maintainer path | S | hindsight y |
| 11 | `scripts/context-budget.sh` | **fix** — relabel the dynamic total "first work prompt of a session + per Edit" (or add a second-prompt column); accept the three negative deltas in a reviewed `--update-baseline` commit | `:226` "A FRESH session id and a FRESH TMPDIR per measurement" vs `:751` "per work-shaped prompt"; 893 of 1,234 dynamic tokens are candor's preamble + skill-router's protocol, both once per session (assistant measurement); design-kit −258, taskmaster −57, testing −11 unaccepted → ratchet slack | CONFIRMED | gate | S | n |
| 12 | code-architecture, security, approaches, ui-ux, resilience | **fold** (packaging, see §3) — `solid-principles` + `yagni-check` → `low-cognitive-load/references/`; `domain-modeling` → `system-design/references/`; `api-auth` + `data-privacy` → `security-review/references/`; `pattern-selection` → `approach-deliberation/references/`; `design-tokens` → `theming-system/references/scales.md`; `concurrency-safety` + `error-handling-design` + `event-driven` → `resilience-design/references/`. Commands and worker agents keep loading by path; drop the matching `rules.tsv` rows | the September plan queued these behind an ablation that cannot run (CLAUDE.md: a case whose control arm passes cannot measure the skill); every body is `measured-zero-shapes` shape 2; loaded by name from `security/commands/review.md:9-11`, `resilience/commands/review.md:14-18`, `system-architect.md:18-19` (assistant greps, not re-run) | PLAUSIBLE | recorded | M | y ×5 |
| 13 | craft-layer | **fold** — `interaction-fx`, `kinetic-typography`, `page-transitions`, `physics-motion` → `motion-tiers/references/`; `webgl-effects` → `threejs-best-practices/references/`; pipeline loads switch to paths; four nouns join motion-tiers' description | all five already loaded by name from `/craft-layer:craft`, `:audit`, `craft-reviewer` (assistant); the eviction probe priced same-territory rivals, not bytes, at 100% → ~75% firing (n=10/arm) | PLAUSIBLE | recorded | M | y |
| 14 | taskmaster, git-workflow, security, debugging | **fix** — open a `CHANGELOG.md` at the current version, no backfill | 11 plugins ship none (recount: `ls plugins/*/CHANGELOG.md \| wc -l` vs `ls -d plugins/*/ \| wc -l`); taskmaster ships three blocking hooks and (assistant count) 25 bumps in 30 days with the behaviour changes recorded nowhere | CONFIRMED (absence); churn figure not re-counted | gate once present (`check-version-bumps.sh`) | S | n |
| 15 | `scripts/validate.sh`, every README | **fix** — a WARN that every skill/command/agent name appears in its plugin's README; adopt the skeleton in §5 as plugins are touched | the endgame review fixed README inventories by hand (its §5.4); the assistant found the drift back in taskmaster (3 of 5 commands listed), task-runner, approaches, security, testing, git-workflow — nothing reads README against the tree | CONFIRMED (sampled: `grep -c` on taskmaster's README) | gate (WARN → gate) | M | n |

Not in the top 15 but worth a line each, all **PLAUSIBLE** unless marked: prompt-coach records
each flag's button (`Use rewrite` / `Send anyway` / `Mute`) to a machine-local row so the
send-anyway rate becomes the false-positive rate at zero model cost (`README.md:300` "Judge
quality is unmeasured"); prompt-coach mascot defaults to the status line and stops reopening a
pane the user closed; the six command closers ("Checked / Not checked") that lost their shared
block when `templates/blocks/closer.md` was deleted are either re-locked or recorded as free to
diverge; `task-executor` gains `yields_to` edges to the four domain workers and drops "the
single delegatable sink"; `/approaches:opinions` becomes `/approaches:compare --panel`;
`stack-scan:suggest` and `git-workflow:clean-gone` carry `disable-model-invocation: true`
(they install plugins and delete branches); the root README gets a one-paragraph glossary for
the `ultra` / `goal` / `boost` token family (candor's `ultra` is a brevity level, taskmaster's
is more effort); `ORCHESTRATION_BOOST` gains a `TASK_RUNNER_BOOST` alias (the plugin it is
named after was retired 2026-09-14).

## 3. Clean house — retire or fold, and what an installer loses

| what | kind | loses | keeps |
|---|---|---|---|
| toolchain-experts: `php-expert`, `react-expert`, `ts-expert`, `ui-expert`, `vue-expert` → one `analyzer-expert` | agents | four PROACTIVELY descriptions that woke three experts on one `.tsx` edit | the mechanism (`detect-analyzers.sh` exit 1 when nothing is configured), the per-language lists as references, the leaf |
| `solid-principles`, `yagni-check`, `domain-modeling`, `api-auth`, `data-privacy`, `pattern-selection`, `design-tokens` | skill entries | seven names in the listing (~1,700 listing chars — recount with `pc_listing_entry_cost` after the fold); `/solid` and `/yagni` keep working by path | every body, as a sibling's `references/` file, reachable by path at zero metered cost |
| resilience: `concurrency-safety`, `error-handling-design`, `event-driven` | skill entries | three `--concern` names resolve to references instead of entries | `observability-design` and `performance-tuning` (worker agents bind to them) |
| craft-layer: `interaction-fx`, `kinetic-typography`, `page-transitions`, `physics-motion`, `webgl-effects` | skill entries | five names; a user who typed them | the bodies under `motion-tiers/references/` and `threejs-best-practices/references/` |
| `code-review/hooks/verbosity.sh` | PostToolUse on every tool call | nothing an installer ever saw: 0 of 18 real sessions on this machine warned; both "warned" sessions were harness fixtures | conditional — decide after the clean-ledger read in action 9 |
| `web-dev/evals/astro-removed-apis` | eval case | nothing: control 5/5, and no Astro skill was ever built (assistant) | — |
| `craft-layer/evals/<spline case>` | eval case | a case whose with-arm scored 1/5 because its reference never loads (assistant) — fix the load or drop it | — |
| the claim at `hindsight/hooks/skill-use.sh:30` | one sentence | a false promise that `/hindsight:harvest` reports the Skill ledger | the ledger, now read by `turn-cost.sh` only, and said so |

Not retired, on purpose (§6 says why): brain, ask-ledger, prompt-coach, session-hud, overseer,
ultra-deep-research, every chassis reminder hook, both secret scanners, the six `suggest.ts`
mods, the resilience eval suite.

## 4. Usage without result

Every surface that spends tokens, turns or processes with no record that it changed an
outcome. Cost × frequency is what was measured today or by an assistant with a synthetic
payload; "outcome evidence" is what, if anything, shows the surface changed a decision.

| surface | cost × frequency | outcome evidence | cheapest instrument that would produce some |
|---|---|---|---|
| `skill-router/hooks/route.sh` high-tier Read nudges (two 8 KB code-architecture bodies) | ~16 KB of body per `.ts/.js/.py/.go/.rb` edit, per context (every subagent again); unmetered by all three budget channels | none; `turn-cost` cannot see a Read | the never-run `code-architecture/evals/solid-control` (5 runs × 2 arms) — the one case written to settle this |
| brain `inject.sh` refresh order | one unasked turn (plus an indexer dispatch) per session once the map is committed | it is a defect, not a nudge — action 2 | the harness case action 2 adds |
| ask-ledger false names | ~464 B per prompt + one blocked Stop (a full extra model turn) per quoted phrase | panel #29's identifier case was fixed in 0.4.0; the quoted-span case is new | `ask-ledger/evals/named-things-accounted` (control recorded failing 6/6 — the one case with headroom) |
| all-plugins `skillListingBudgetFraction` write | the gate's own figure: ~12,762 system-prompt tokens per turn, roughly doubling the always-on prefix | the repo's probe measured zero delta from eviction | already measured — action 4 |
| candor `preamble.sh` on every SubagentStart | ~966 B per subagent incl. read-only reviewers and 4× opinion-lens fan-outs (assistant) | five candor cases shipped, never run | `first-edit-discipline` 3 × 2 arms, with the §6 kill criterion in `fable-distillation-2026-09-17.md` |
| candor terse mode (`CC_TERSE=full`) | 736 B every prompt (assistant), on top of ~5 KB at SessionStart; `derivations/plugin-candor.md` still says ~150 tokens | the 08-31 break-even (~8,200 output tokens/session) was never measured | output chars per response with vs without, from transcripts `turn-cost.sh` already reads |
| `code-review/hooks/verbosity.sh` | one process per tool call (~6 ms); a write-only ledger 42% polluted by its own harness | 0 real warns on this machine | action 9, then read the clean ledger |
| `hindsight/hooks/skill-use.sh` | one process per Skill call; ledger read by `turn-cost.sh` only | none for an installer | none needed — say what reads it (action 10) |
| prompt-coach judge | one haiku call per eligible prompt (420–2,111 input tokens, ~587 ms median), off `/cost` (its own probe) | none: three buttons capture the verdict and discard it | a one-row-per-flag local ledger; send-anyway rate = false-positive rate |
| six `suggest.ts` mods | 0 context tokens (ghost text); one kit function in `cc-kit.ts` | nothing records an accepted suggestion | an in-memory accepted counter under `$.state` (contract-declared) |
| the two Stop gates (candor 41–53 ms, ask-ledger 6 ms per Stop) | each block = a full extra turn (median $0.267/request at 322k context — assistant) | no block counter anywhere | `turn-cost.sh` counts "Stop hook feedback" lines per gate prefix (format inferred, not verified) |
| 23 eval cases in 9 plugins | maintenance only; CI runs the schema, never a case | five cases have a failing control and have never been run (§7) | buy the six decision cases once |
| the five chassis reminder hooks | 200–301 B and 14–22 ms per work prompt; 2–3 of them on multi-eligible prompts (assistant, 3/3) | none, and cheap enough that none is owed | quote the multi-voice rate in place of "one voice" |

What the per-prompt bill actually looks like (assistant measurement, everything installed, a
scratch cwd): a bare prompt injects 0 B of classic-hook text (~25 ms wall); the first work
prompt of a session ~3 KB (candor preamble + skill-router protocol + one reminder); later work
prompts 250–1,450 B. The expensive channel is per-edit, not per-prompt: ~24 processes and
0–2.1 KB per `Write`, plus the unmetered Read nudges above.

## 5. Consistency

**The skeleton** (adopt as plugins are touched, never in a sweep; `validate.sh` gates the
README inventory from action 15, nothing gates the order):

```
# <plugin>
<one paragraph: the rule the model gets wrong from memory, or the mechanism prose cannot replace>
> Needs <companion> — only for a hard pairing; mirrored in the root Companions table and signals.md
## Boundary with Claude Code's built-in /<x>      (only when a host command collides)
## Install
## What it ships                                   (every skill, command, agent, hook named — gated)
## What has teeth                                  (Standing per rule; the off-switch beside each)
## Example · ## Pairs well with · ## Evals          (optional; Evals names the run count)
```

Deviations worth keeping: guard plugins (command-guard, secret-scanning, devops, candor) put
"What has teeth" first; craft-layer keeps "Vocabulary" first; hook- or mod-only plugins
(ask-ledger, session-hud, prompt-coach, skill-router) merge Install and What it ships;
all-plugins keeps "Three ways to run it". Recount the openings rather than trusting a number:
`for f in plugins/*/README.md; do grep -m1 '^## ' "$f"; done | sort | uniq -c | sort -rn`.

**Fixes, each one line:** companion rows for candor (action 6); CHANGELOGs at the current
version (action 14); `Standing:` lines in the four plugins with none (all-plugins, ask-ledger,
session-hud, toolchain-experts — ask-ledger has a "Standing, said plainly" heading the recount
grep misses); "Spawned by" instead of "Use PROACTIVELY" on the four pipeline-spawned agents
(`researcher`, `verifier`, `context-scout`, `craft-reviewer`); the three reviewers left at
`inherit` in `role-floors.md` either floored or given a reason; `ultra-deep-research/README.md`
drops its "Suite membership" section (suites retired 2026-09-26); design-kit's plugin.json
description under 700 chars; `yields_to` edges for the two lane clusters where one artifact
carries a safety rule the other lacks (`web-developer → backend-engineer` on `*.blade.php`;
`backend-engineer → database-engineer` on `**/migrations/**` and `*.sql`, because only
database-engineer carries the DROP/TRUNCATE stop-and-ask); `# lane-cofire-ok:` for the
sql/mariadb and a11y-audit/a11y-engineer pairs that are the same owner on purpose. The lane
sweep stays deliberately undone (`collective-taskforce-backlog.md` item 7).

## 6. Refuted, and things to KEEP — so nobody re-proposes them

- **"Merge the per-prompt reminders into skill-router."** Still declined. The premise moved —
  `route-prompt.sh` now prints a fixed 1,769 B protocol once per session in 16–20 ms, not the
  533 ms catalog of September — but the decline rested on capability loss (a plugin installed
  without skill-router loses its nudge), and that holds.
- **"taskmaster's clarifying directive never wins the reminder lottery."** REFUTED. Its
  `arcRank` has been 25 since `9be26a8c` (2026-09-14); the assistant's drive won it 9/9 on
  plain work prompts; `taskmaster/README.md:61-69` and `skill-router/lane.tsv:8-10` are correct.
- **"Six `suggest.ts` are six copies of one mechanism."** REFUTED on mechanism — all six call
  `registerSuggestion` from the byte-locked `cc-kit.ts` (`pc_mod_kit`); each is 25–78 lines of
  plugin-specific trigger. Confirmed only on evidence: nothing records acceptance.
- **"secret-scanning and security scan the same writes twice."** REFUTED. `scan.sh` denies
  secret VALUES at PreToolUse; `write-scan.sh:222-264` warns on SINKS and public-bundle NAMES at
  PostToolUse. Disjoint detectors, one convention; a merge saves ~25 ms per edit and was declined
  in September (§4.5).
- **"Unrouted means unreachable."** REFUTED. 62 of the 66 skills with no `rules.tsv` row are
  loaded by name from a command, hook, agent or sibling skill; the eviction probe measured
  47/50 vs 47/50 for description vs name-only. Only `straight-talk`, `tdd`, `review-exchange`,
  `worktree-isolation` rely on their description alone, and each name describes its trigger.
- **"The first-clause rule for descriptions."** REFUTED — the renderer that split on
  ` — `/`. `/`: ` was deleted with the catalog in `b894b8a0` (2026-09-22). Drop it from the
  authoring doctrine when next touched.
- **"toolchain-experts fails the admission bar."** PARTLY REFUTED. It clears the bar on
  mechanism (`detect-analyzers.sh` exits 1 when no analyzer is configured, harness-gated) and
  the fan-in does dispatch it in prose. The defect is five agents for one procedure and zero
  router rows — action 7, not retirement.
- **"The evals run at `runs: 1` with untyped graders."** REFUTED — minimum 3, every grader
  typed (assistant). The real state: six decision cases with headroom have never been run.
- **Keep, unchanged:** the `preview-guard.sh` twins; the Stop gate's home in candor; the
  chassis reminders (cheap, one winner most of the time); `overseer` as a leaf (corpus ratchet);
  the ten worker agents (§4.6 of the plan — the assistant's new `yields_to` argument is a lane
  edge, not a collapse); no CHANGELOG backfill; no new stack best-practices pack; no new
  `doctor` command; design-kit untouched (user decision 2026-10-05); the resilience eval suite
  as a regression guard (the only replicated one); `ui-libraries/evals/primereact` (the one
  measured positive delta, control 1/5 vs 5/5); `web-dev/evals/caching-inversion` and
  `ui-ux/evals/marquee` as regression guards.
- **Commander's own hypotheses that fell:** the per-prompt bill is not "two plugins" — it is
  first-prompt-of-session for both of them (C-12), and the real unmetered cost is per edit;
  brain and ask-ledger are not whole-plugin "usage without result" — each has one defect
  (actions 2 and 3) and a reason to exist behind it.

## 7. Paid measurements — worth buying, and not

Prices are extrapolated from the one replicated run on record (30 agent runs, $10.13, CLI
2.1.272 — `marketplace-endgame-review-2026-09-14.md`, amendment): about $0.34 per run. Treat
every figure here as ±50%.

**Buy, once, in this order** (~76 runs ≈ $25, n = 3 per arm minimum, state the vote spread):

1. `code-architecture/evals/solid-control` — decides action 5 and the shape-2 fold of action
   12 for ten skills at once. The single highest-leverage $3 in the repo.
2. `ask-ledger/evals/named-things-accounted` — control recorded failing 6/6; the only case
   that can show a Stop gate helping.
3. `candor/evals/first-edit-discipline` (then the other four candor cases) — the preamble
   reaches every subagent; `fable-distillation-2026-09-17.md` §6 already wrote the kill rule.
4. `ui-ux/evals/design-tokens-control`, `ui-ux/evals/a11y-older-criteria`,
   `resilience/evals/liveness-probe-dependency` — each has a named failing control.
5. `overseer`'s two cases at n = 3 (they ran once per arm).

**Do not buy:** an `ultra-deep-research` vs `/deep-research` case or a `task-runner --tracks`
vs `/batch` case — neither exists, both would be written for a body nobody intends to delete,
and the endgame amendment already said that order is backwards; re-running the five resilience
cases (replicated, at ceiling); any case whose control arm passes 3/3 on the first attempt —
stop and rewrite rather than spend the other arm.

## 8. Could not measure

- Whether any reminder, preamble, nudge or suggestion ever changed a decision — no instrument
  records it; §4's right-hand column is the list of what would.
- Mod-injected bytes in a live CLI (`context-budget.sh` says they are unmetered by nature);
  `stack-scan/hooks/pins.ts`'s line; contention between `$.prompt.suggest` and the host's own
  suggestion slot.
- Subagent turns (`turn-cost.sh` prints the blind spot every run) — which is exactly where the
  candor preamble and the route.sh Read nudges are billed.
- Real Stop-block counts per clause; prompt-coach flag and false-positive rates; whether the
  model obeys a `— Read …` nudge (the bytes are a ceiling, not a bill).
- The always-on saving of action 7 (~460 tokens is bytes/4, the assistant's estimate); the
  listing-chars savings of actions 12–13 (recount with `pc_listing_entry_cost` after the fold).
- Whether reviewer agents should carry `omitClaudeMd` / `isolation: worktree` (trend audit
  D4, still unmeasured); whether folding a body into `references/` changes its firing rate
  beyond the one n=10 probe.
- The churn counts in action 14 and the README-drift sample in action 15 were taken by an
  assistant from `git log`; recount before quoting:
  `git log --since=2026-09-11 --format=%s -- plugins/taskmaster/.claude-plugin/plugin.json | wc -l`.

## 9. Recount before quoting

```bash
ls -d plugins/*/ | wc -l                                              # 33 today
ls plugins/*/skills/*/SKILL.md | wc -l                                # 107
ls plugins/*/commands/*.md | wc -l                                    # 52
ls plugins/*/agents/*.md | wc -l                                      # 33
ls plugins/*/CHANGELOG.md | wc -l                                     # 22
ls -d plugins/*/evals/*/ | wc -l                                      # 23
grep -c 'analyzer-triage\|toolchain' plugins/skill-router/rules.tsv   # 0 until action 7
bash scripts/turn-cost.sh --skills | grep 'of .* shipped skills'      # 67 of 107 until action 10
bash scripts/context-budget.sh | grep -E '^TOTAL|cost of doing so'    # 10511; ~12762
ls ~/.claude/plugins/cache/cc-plugins-marketplace/taskmaster/         # the versioned layout action 1 must resolve
```
