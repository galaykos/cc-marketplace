# Marketplace trend audit — 2026-09-16

**Question asked:** inventory every plugin, skill, agent, command and hook; research what
Claude Code skills, automations, conventions and quality practice look like today (official
and community); compare, and name every inconsistency, dead surface and quality risk with a
fix. Run under `/overseer:start` on branch `Ivan-WG/marketplace-trend-audit`, base `master`
at `89ab2efc`, CLI **2.1.273**.

**Standing of this document: `recorded`.** Nothing reads it back. Every number carries a
recount command. Every finding was verified against the tree by the overseer after an agent
reported it — the ones marked PLAUSIBLE were not.

**Method.** One inventory worker (sonnet; `taskmaster-docs/audit-2026-09-16/inventory.py`,
gitignored, regenerates `inventory.json` and `--check`s itself), three research shards
(sonnet; official surface, community conventions, quality measurement), two read-only
auditors (opus; contradictions since the 2026-09-14 endgame review, and per-plugin trend
gaps), and the overseer's own probes: one `claude plugin eval` run on a throwaway fixture
($0.02), one fetch of the official skills doc. Raw returns:
`.claude/overseer/milestones/*/returns/` (machine-local, not tracked).
`rationale/marketplace-endgame-review-2026-09-14.md` is cited, not restated; nothing it
records in §5/§7 is repeated here unless it is still open or its recorded root cause is wrong.

---

## 1. Snapshot

| measure | value | recount |
|---|---|---|
| plugin dirs / manifest entries | 33 / 32 — the extra is an ignored ghost (§3 E1) | `ls -d plugins/*/ \| wc -l`; `jq '.plugins\|length' .claude-plugin/marketplace.json` |
| skills / commands / agents | 103 / 57 / 33 | `ls plugins/*/skills/*/SKILL.md \| wc -l` etc. |
| hook registrations / plugins with hooks | 51 / 20, all `type: command`, all with `timeout` | `for f in plugins/*/hooks/hooks.json; do jq '[.hooks[][].hooks[]]\|length' $f; done \| paste -sd+ - \| bc` |
| hook events in use | 7 of ~28 documented (SessionStart, UserPromptSubmit, Pre/PostToolUse, Stop, SubagentStop, SessionEnd) | `jq -r '.hooks\|keys[]' plugins/*/hooks/hooks.json \| sort -u` |
| skills unrouted by skill-router | 73 of 103 | CLAUDE.md's one-liner |
| `disable-model-invocation` on a shipped skill or command | 0 of 160 | `grep -l 'disable-model-invocation' plugins/*/skills/*/SKILL.md plugins/*/commands/*.md \| wc -l` |
| skill frontmatter keys in use | `name`, `description` only | `for f in plugins/*/skills/*/SKILL.md; do awk '/^---$/{c++;next} c==1{print $1}' $f; done \| sort \| uniq -c` |
| agent frontmatter keys | name, description, tools, model, effort (33) + repo-only `bestpractices-skill` (12), `floor`/`floor-reason` (5); 0 use `omitClaudeMd`, `permissionMode`, `memory`, `isolation` | same, over `agents/*.md` |
| CHANGELOGs / eval suites | 18 / 3 (top entry = plugin.json in 18/18) | `ls plugins/*/CHANGELOG.md \| wc -l` |
| local `validate.sh` on a clean master | **exit 1** (§3 E1); CI green | `bash scripts/validate.sh; echo $?` |
| listing budget | four bundles OVER at 200k (1.1×–4.0×), under at 1M | `bash scripts/context-budget.sh \| grep OVER` |

## 2. What the host does today that this tree was written before (tier-1, fetched or run)

| # | claim | source | verified how |
|---|---|---|---|
| T1 | "Custom commands have been merged into skills … both create `/deploy` and work the same way." | code.claude.com/docs/en/skills | overseer fetch 2026-09-16 |
| T2 | `disable-model-invocation: true` → "Description not in context, full skill loads when you invoke"; the doc's examples are `/commit`, `/deploy`, `/send-slack-message` | same | fetch |
| T3 | listing truncates `description` + `when_to_use` at 1,536 chars; `when_to_use` is a frontmatter field; API max description 1,024 | same; platform best-practices | fetch (1,536); researcher (1,024) |
| T4 | "Keep SKILL.md body under 500 lines"; "Only add context Claude doesn't already have"; baseline without the skill first; ≥3 evals, tested on three models before sharing | platform best-practices | researcher, tier 1 |
| T5 | a case is "a prompt.md, a case.yaml, or both"; graders/*.md carry `type:` frontmatter; `--ablation with-without` default; CI should pin `--model`/`--judge-model`/`--threshold`/`--max-cost-usd` | plugin-evals doc; `claude plugin eval --help` | **run**: `prompt.md` + `graders/says-hello.md` (`type: regex`) loaded and scored 1.00 on 2.1.273 |
| T6 | `/skill-doctor` (≥2.1.252): per-skill context cost and use count, "flags skills … never invoked" | skills doc | fetch |
| T7 | agent frontmatter: `permissionMode`, `memory`, `omitClaudeMd` (2.1.273), `isolation: worktree`; hook types `command`/`http`/`mcp_tool`/`prompt`/`agent`; ~28 hook events | sub-agents, hooks docs; changelog | researcher, tier 1 |

Community (tier 2–3, context only, no finding rests on it): context bloat is the dominant
complaint (two blog measurements, ~2k tokens/plugin, a "4–6 plugins" heuristic whose source
returned 403); claude.ai/Cowork skills are injected into every CLI session with no opt-out
(anthropics/claude-code#39686, closed not-planned) — a source `context-budget.sh` cannot
see; skills.sh / `npx skills add` is the community install path; "precise verbatim trigger
phrasing" is the converged description advice, which is this repo's own top rule.

## 3. Findings

Severity: **major** = a gate or doctrine says something false, or a user hits it on install;
**minor** = drift a maintainer hits. Standing names what enforces the fix once made.

### A. A wrong root cause, encoded three times

| # | sev | where | what | fix | standing after fix |
|---|---|---|---|---|---|
| A1 | major | `scripts/eval-cases.sh:51-53`, CI step `validate.yml` | FAILS the build on any `prompt.md` or `graders/` under `evals/` as "the DEAD shape … the runner rejects". The shape is valid on 2.1.273 (T5, run). The 2026-09-14 rejection was a grader with **no `type:` frontmatter** (`git show 4878150702^:plugins/resilience/evals/timeout-and-retry/graders/retry-idempotency.md` — prose only). | accept the shape; require `type:` in every `graders/*.md`; rewrite the header | gate |
| A2 | major | `CLAUDE.md:22-28` | "measured DEAD … both suites using it loaded zero cases" — true on 2.1.270 for those files, false as a statement about the shape | one sentence: the shape works; the graders were malformed; name the CLI version | recorded |
| A3 | minor | `rationale/marketplace-endgame-review-2026-09-14.md` wave D | same claim; leave the record, add an amendment pointing here | amendment | recorded |

### B. Doctrine the tree already contradicts

| # | sev | where | what | fix |
|---|---|---|---|---|
| B1 | major | `.claude/skills/authoring-commands/SKILL.md:8,27-28` | "A command is the one artifact the user starts deliberately, by name … Add no other keys." T1 says a command IS a skill: model-invocable by default, description always in context, accepting `disable-model-invocation`, `allowed-tools`, `context: fork`, `when_to_use`. `plugins/git-workflow/commands/clean-gone.md:4` already ships `allowed-tools:`; `validate.sh:87-99` has no key whitelist, so the rule is recorded-only and wrong | rewrite the frontmatter section: shared skill fields, and WHEN a command carries the flag (§3 D1) |
| B2 | major | `.claude/skills/authoring-hooks/SKILL.md:56-57` | "Prompt and session events take no matcher" vs `plugins/approaches/hooks/hooks.json:21` and `plugins/skill-router/hooks/hooks.json:14` (`"matcher": "compact"` on SessionStart); `:40-52` lists five events while the tree ships SessionEnd (hindsight, skill-router) and SubagentStop (candor) | add the SessionStart matcher vocabulary and the two events |
| B3 | minor | `.claude/skills/authoring-agents/SKILL.md:32-37` | documents `floor`/`floor-reason` as validator rules without saying the host ignores them; `bestpractices-skill` (12 agents, `templates/worker-agent.md.tmpl:8`) is not mentioned at all. Readers: `validate.sh:284-295`, `:912-937` only | one sentence naming all three as repo-only keys |
| B4 | minor | `plugins/task-runner/README.md:83` | "`scope.sh` enforces a card's declared file list" — `hooks/scope.sh:4` "warns (non-blocking)" | "warns, once per edit outside the set" |
| B5 | minor | `.claude/agents/conflict-auditor.md:8` | "a 71-plugin Claude Code marketplace" — 32 | recount or drop |

### C. Host built-ins this tree collides with and does not say so

| # | sev | where | what | fix |
|---|---|---|---|---|
| C1 | major | `plugins/ultra-deep-research/README.md:20`, `skills/ultra-deep-research/SKILL.md:3` | the trigger phrase is literally "deep research"; the host ships `/deep-research`. No boundary section, no eval with a control arm (endgame §3 said "measure"; nothing has) | a Boundary section (the refutation ledger and the `--ultra` loop are what the built-in lacks) + one eval case |
| C2 | major | `scripts/lib/plugin-checks.sh:769-772` (`pc_host_overlap`) | "SKILLS ONLY. Commands are namespaced" — under T1 a command competes on its description exactly as a skill does. `task-runner:run` (host `/run`), `devops:init` (host `/init`), `code-architecture:verify` (host `/verify`) are invisible to the gate | extend the walk to `commands/*.md`; bless the three with `<!-- host-ok -->` and a README line each |
| C3 | minor | `plugins/task-runner/README.md`, `plugins/devops/README.md`, `plugins/code-architecture/README.md`, `plugins/taskmaster/README.md` | silent on host `/run`, `/batch`, `/init`, `/simplify`, `/verify`, `/goal` respectively (code-review and security did this already) | one boundary sentence each |

### D. Host levers the doctrine names and nothing uses

| # | sev | where | what | fix |
|---|---|---|---|---|
| D1 | major | 14 command/skill entries, 2,762 description chars | `authoring-skills/references/activation-fields.md:28-40` prescribes `disable-model-invocation: true` for "a command's implementation with no natural-language trigger" — measured, 2026-08-21. Zero adoption. The four suite `uninstall` commands (`templates/suite-uninstall.md.tmpl:2`, 1,101 chars), `all-plugins:install/uninstall`, `overseer:start/resume/status`, `candor:level/check`, `taskmaster:taskmaster` (a 31-char alias), `verify-teeth`, `behavioral-gate` are side-effect or pipeline-internal entries nothing invokes by description. T2's stated reason is not budget but timing: "You don't want Claude deciding to deploy". NOT flag-safe: `track-orchestration` (`commands/run.md:12` loads it by name) | flag them; regenerate the template; run `scripts/smoke/chassis-template-tests.sh` |
| D2 | major | `scripts/context-budget.sh:70-82`, `scripts/lib/plugin-checks.sh:2147-2156` | both channels charge a flagged entry's description unconditionally, so D1's saving is invisible to the gate that exists to measure it (`:839` admits the host meter does the same) | skip flagged entries in both walks; `--update-baseline` per touched key |
| D3 | minor | `scripts/validate.sh:113`, `context-budget.sh:70-82` | `when_to_use` (T3) has 0 hits repo-wide; a skill adding it is uncapped and unmetered while the CLI truncates the COMBINED text at 1,536 | cap and meter `description + when_to_use` together; name the 1,536 and 1,024 caps beside the house 500 at `validate.sh:103` |
| D4 | minor | 19 reviewer-class agents | none carries `omitClaudeMd` (2.1.273) or `isolation: worktree`; read-only reviewers inherit every CLAUDE.md — a cost, not a defect | measure one reviewer with and without before adopting; record |
| D5 | minor | pipeline-internal skills with prompt-shaped descriptions | `task-runner:code-redteam` ("the diff must be red-teamed"), `taskmaster:erd` ("two-plus entities … before any migration"), `taskmaster:experience-walkthrough` ("multiple screens … cross-screen flow") can fire on an ordinary prompt; each is loaded by name inside its pipeline | lead each description with the gating clause |

### E. Hygiene

| # | sev | where | what | fix |
|---|---|---|---|---|
| E1 | major | `plugins/design-studio/` (ignored) | a ghost dir holding only `.claude/comment-discipline/verbosity-*` scratch (three nested copies) left by `plugins/code-review/hooks/verbosity.sh:89`, which writes under the payload `cwd`. `validate.sh` exits 1 on it; CI is green because it checks out clean. The inverse of the failure CLAUDE.md warns about | delete the dir; `validate.sh`: a `plugins/<x>/` with no tracked file is "stray, delete it", not three FAILs about a plugin that does not exist |
| E2 | minor | `scripts/context-budget.sh:14-15,:165` | header numbers stale: candor "4,171 B" (now 4,969), brain "clamped at 2048 B by :65" (clamp is `inject.sh:77`) | recount or drop — the rule CLAUDE.md applies to itself |
| E3 | WARN | 20 matcher groups in 12 `hooks.json` name `MultiEdit`; 2 name `Task` | neither tool is in the 2.1.273 roster (first-hand observation, no doc found); harmless alternation | leave; one comment per file |
| E4 | minor | `plugins/devops/agents/devops-reviewer.md:3-4`; `ultra-deep-research/agents/{researcher,verifier}.md:4` | "read-only" twice with `Bash` granted and no Standing line; WebSearch/WebFetch granted with no reason in the body (authoring-agents:113-115 requires one) | one sentence each |

### F. What using the overseer on this repo showed about the overseer

| # | sev | what | fix |
|---|---|---|---|
| F1 | major | `program.sh accept` requires nine evidence kinds, eight of them browser screenshots. A program with no UI cannot reach `done`; every milestone here closed as `parked --reason`. `kinds.tsv` has no research/audit row; `next` then reports "none" because parked milestones block their dependants even when the deliverable shipped | a `research`/`audit` kind with a file-based evidence vocabulary (`report`, `sources`, `review`); or an evidence profile per kind |
| F2 | minor | `scripts/capability-scan.sh:69` reads `git branch --show-current` as the CI base; on a feature branch every workflow is flagged "does not trigger on base" | read `base_branch` from `program.json` when present |
| F3 | minor | `skill-path.sh` prints its whole header comment to stderr on every call | print usage only on error |

### G. Contradictions since 2026-09-14 (conflict auditor, opus; majors re-verified by the overseer)

The auditor found every §7 item of the endgame review FIXED at HEAD, and the following new
ones. "Both sides" are quoted in the raw return; here, the two locations and who wins.

| # | sev | A | B | who wins · fix |
|---|---|---|---|---|
| G1 | major | `plugins/taskmaster/hooks/ultra.sh:50,54` (from `.chassis.json:24,26`): "Fan-out only when the Workflow tool is present; else inline fallback" | `task-runner/skills/verification-panels/SKILL.md:43`, `taskmaster/skills/ultra/SKILL.md:152`: fallback only with "no `Workflow` tool AND no Agent tool" — the wording `craft-layer/hooks/ultra-craft.sh:50` and `task-runner/hooks/ultra-assess.sh:50` already carry | the owner rule (0.111.0, `94d5b07d`, which did not re-render taskmaster's hook) · fix the chassis message, `generate.sh --write`, bump |
| G2 | major | `scripts/generate.sh:489` → `README.md:87`: "0.04 for workflow-suite" | `plugins/workflow-suite/README.md:46,53`: 0.05, with the measurement (24,165 chars > 0.04's 24,000) | the bundle README · fix the generator string; `--check` is green today because both copies of the wrong number agree |
| G3 | major | `plugins/frontend-suite/.claude-plugin/plugin.json:4` (= `marketplace.json`): "prunes its auto-installed plugins" | `commands/uninstall.md:51-52`: provenance unknown → KEEP, not pre-selected | the command (0.110.0) · end the description as the other three bundles do; paired manifest edit; bump |
| G4 | major | `.github/workflows/validate.yml:119`, `scripts/official-validate.sh:27`: `PIN="2.1.259"`, "pinned to the CLI this repo was measured against" | every measurement since 09-14 ran on 2.1.270–2.1.273; `bash scripts/official-validate.sh` on this machine: FAIL unless `OFFICIAL_VALIDATE_ANY_VERSION=1`, so CLAUDE.md's pre-push list cannot pass as written | judgment: bump the pin to 2.1.273 and re-run 32/32 (done in m4 if green), else name the env var in CLAUDE.md |
| G5 | major | `README.md:442` (all-plugins catalogue row): "the skill listing overflows, so some skills lose autonomous dispatch until you name them"; `:490-492` same | `README.md:78,474`, `plugins/all-plugins/README.md:3-4`: the 2026-09-15 probe found the overflow changes nothing detectable, and the script raises the fraction | 78/474 · rewrite 442; soften 490-492 to the historical reason |
| G6 | major | `plugins/taskmaster/skills/ultra/SKILL.md:73,77,78`, `spec-redteam/SKILL.md:51`: per-phase bullets and the panel heading keyed on Workflow alone | `:152` / `:63` in the same files: the owner rule | `:152`/`:63` · "via either dispatch mechanism" |
| G7 | minor | `CHANGELOG.md:163`: bundle READMEs "re-tiered to say what is measured and what is assumed" | the four bundle READMEs still carry the flat "skills stop being reachable" claim | the probe · add the hedge `pc_listing_declaration`'s header carries |
| G8 | minor | `README.md:208`: database guard fires before a statement "reaches the shell" | `plugins/database/hooks/guard.sh:32-33`: Write/Edit only; shell is command-guard's | the plugin · reword |
| G9 | minor | `scripts/validate.sh:726,729,730`: lane-coverage strings say "agents and prompt/Stop hooks" | `plugin-checks.sh:1224-1226`, CLAUDE.md: deny-capable Pre/PostToolUse joined the gate tier 09-15 | the header · update three strings (no harness asserts them) |
| G10 | minor | `README.md:525`: "~20 smoke harnesses" | 28 CI steps, 27 scripts; CLAUDE.md forbids the count | recount command |
| G11 | minor | `README.md:161-165`: nine leaves in no suite | eleven — `toolchain-experts`, `all-plugins` missing | the tree |
| G12 | minor | `plugins/task-runner/lane.tsv:17`: "20/40/80 by tier" | `hooks/spawn-cap.sh:6`: 20 then each doubling, per session, no tiers | the hook |
| G13 | minor | `plugins/skill-router/hooks/route.sh:16-18`: header limitation (2) names a per-session dedup hole | `:34-39`: closed 2026-08-16 (context key) | delete the limitation |
| G14 | minor | `.claude/agents/conflict-auditor.md:9,53-57`, `branch-reviewer.md:48` (local, untracked): "71-plugin", four "not yet fixed" items, "four gates" | 32 plugins; three fixed 2026-08-24; five gates | local files — fixed on this machine, not on the branch |

Still open from the endgame review: §5.6 (`ultra-deep-research/README.md:67,73` tiers
`verdict-lint.sh` as "one mechanical gate" while only prose invokes it — agent-graded).
Gaps, not contradictions: `--tracks` states no behaviour when the `Workflow` tool is absent;
CLAUDE.md's escape-hatch table lists 8 markers and `plugin-checks.sh` honours 4 more
(`# co-fire-ok:`, `<!-- false-standing-ok: -->`, `# prime-ok:`, `<!-- scout-name-ok: -->`);
`.claude/settings.json`'s two hooks carry no `timeout` while `pc_hook_timeout` scans `plugins/`
only. Declared consistent (skip next time): CHANGELOG 18/18; `rules.tsv` 64 rows resolve; every
lane `yields_to` resolves; every README-named hook/env pair is registered/read; the caps
200/14,000/300/500/700 agree everywhere; bundle listing figures match the meter; harness counts
in READMEs match live output.

## 4. Where this tree leads, lags, and contradicts the trend

- **Leads:** control-armed evals with the `tool_used: Skill` exclusion understood (T5) before the
  runner shipped; a 200-line body cap under the official 500 (T4, Proportionality); every hook
  with a `timeout`; a description gate that already bans the anti-pattern the community
  converged on; per-plugin `lane.tsv` territory; a token meter with three channels.
- **Lags:** zero use of `disable-model-invocation` (D1), `when_to_use` (D3), `omitClaudeMd`
  (D4); no CI eval invocation with pinned models (T5 recommends one; `eval-cases.sh` checks
  loading only); no README names `/skill-doctor` (T6) beside `turn-cost.sh --skills`.
- **Contradicts:** three doctrine files (B1, B2, `eval-cases.sh` A1) state rules the host or the
  tree itself falsifies. The pattern is the one CLAUDE.md already names — a fact copied from a
  measurement outlives the measurement — and each of the three carries a date that would have
  said so if read.

## 5. Fix list for m4, ranked

Each names the plugin or gate it improves and the harness to run. Executed as four
scope-locked workers on disjoint file sets (decision recorded in the program).

1. A1+A2 — `scripts/eval-cases.sh` accepts both shapes, requires `type:` in `graders/*.md`;
   CLAUDE.md sentence corrected; G9 strings; E1 stray-dir message in `validate.sh`; C2
   `pc_host_overlap` walks commands; D2 both meters skip flagged entries; E2 header numbers.
   Harness: `scripts/smoke/*.sh`, `scripts/smoke/validate-fixtures/*.sh`, `context-budget.sh` alone.
2. G1, G2, G3, D1 (template) — chassis: `taskmaster/.chassis.json` message, `generate.sh:489`,
   `templates/suite-uninstall.md.tmpl` flag, then `generate.sh --write`;
   `frontend-suite` manifest pair. Harness: `chassis-template-tests.sh`, `generate.sh --check`.
3. B1/C8, B2, B3 — the three doctrine files. Gate: `validate.sh` project-skill budget.
4. G6, G12, B4, D1 (hand-written flags), D5, C3 READMEs, C1 boundary, E4, G8, G5, G10, G11,
   G13 — per-plugin edits with bumps and CHANGELOG entries where one exists; root README rows.
5. G4 — bump the pin to 2.1.273 only if `claude plugin validate --strict` passes 32/32 on it;
   else name the env var in CLAUDE.md.
6. Not attempted here: F1 (overseer design), D4 (unmeasured), C1's eval case (a control-armed
   eval is its own PR), G7 (four READMEs' hedge — one sentence each, deferred with the K7 posture),
   G14 (local files). Each is a `suggestions.md` row.

## 6. Honest limitation

Research shards were sonnet; every finding that rests on them was re-fetched or re-run by the
overseer (T1, T2, T3-1,536, T5, T6) or is marked tier-1 by a quoted doc sentence the overseer
did not re-open (T4, T7, T3-1,024). The community numbers are tertiary and one source was
unreachable; no finding rests on them. The eval probe ran once, on one case, with `--ablation
none`; it proves the shape LOADS and a typed regex grader scores — nothing about Δ. D4's cost
is unmeasured. E3's tool-roster claim is one live session, not a document. The `is_suite`
column of `inventory.json` over-matches and was not used. The 2026-09-14 review's §7
consistency list was trusted, not re-walked. §8's majors (G1–G6) were re-verified by grep; its minors and CLEAN list were not.

## 7. Recount before quoting

```bash
claude --version                                                                  # 2.1.273
ls -d plugins/*/ | wc -l; jq '.plugins|length' .claude-plugin/marketplace.json     # 33 / 32
grep -l 'disable-model-invocation' plugins/*/skills/*/SKILL.md plugins/*/commands/*.md | wc -l   # 0
grep -rn 'prompt.md + graders' scripts/eval-cases.sh | head -1                    # A1 until fixed
grep -n '"matcher": *"compact"' plugins/*/hooks/hooks.json | wc -l                 # 2 (B2)
grep -c 'deep-research\|built-in' plugins/ultra-deep-research/README.md            # self-references only (C1)
bash scripts/validate.sh >/dev/null 2>&1; echo $?                                  # 1 until E1
for f in plugins/*/hooks/hooks.json; do jq -r '.hooks|to_entries[]|.value[]|.matcher//empty' $f; done | grep -c 'MultiEdit\|\bTask\b'   # E3
```
