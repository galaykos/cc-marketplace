# UI/UX/DX/AX landscape — 50 GitHub repos, 2026-10-26

**Question:** which recent GitHub skills and plugins make agent work faster, cheaper, better or calmer? What should this marketplace take from them? Run under `/overseer:start` (program `marketplace-ux-dx-ax`, milestone m1), branch `overseer/m1-improvement-plan`, base `master` at `5b79d05e`, CLI 2.1.310. The plan built from it: `rationale/improvement-plan-2026-10-26.md`.

**Standing: `recorded`.** Nothing reads this file back.

## How the 50 were chosen

1. `gh search repos` over five topics and 12 keyword queries gave 660 unique repos; 409 were pushed since 2026-09-01. Topics: `claude-code-plugin`, `claude-code-plugins`, `claude-skills`, `agent-skills`, `claude-code` (created after 2025-10-01). Keywords included agent experience, SKILL.md, ui ux skill, frontend design skill, subagents orchestration, context engineering, token efficient claude code.
2. Repos already reviewed in `rationale/` were left out (anthropics/skills, affaan-m/ECC, jarrodwatts/claude-hud, Leonxlnx/taste-skill, DietrichGebert/ponytail, JuliusBrussee/caveman, thedotmack/claude-mem, wshobson/agents, obra/superpowers, anthropics/claude-plugins-official, heygen-com/hyperframes and others).
3. 52 were picked across four areas: agent work (AX), developer workflow (DX), interface design (UI/UX), and reader load and language. Four researcher agents read each README, plus one to three files showing how it works where such files exist; a few were read from the README alone. Two of the 52 are listed at the end; they offered nothing the 50 do not.
4. Stars, pushed date and licence come from the GitHub API on 2026-10-26. None of the 52 is archived.

**How to read the numbers.** Almost every figure below is the repo's own claim. Where a repo ran its own test, it says "author-run". No repo had an independent measurement. Treat a number as a lead, not a result.

**Verdicts.** ADOPT = build our own version of the pattern. ROUTE = point users at the tool; we copy no code or text. SKIP = do not recommend it; we copy no code or text. Every row's "idea it shows" column is the lesson, whatever the verdict; the plan may borrow an idea from a ROUTE or SKIP row.

| | ADOPT | ROUTE | SKIP |
| --- | --- | --- | --- |
| Agent work (12) | 6 | 3 | 3 |
| Developer workflow (12) | 7 | 4 | 1 |
| Interface design (13) | 9 | 2 | 2 |
| Reader load and language (13) | 7 | 3 | 3 |
| **Total (50)** | **29** | **12** | **9** |

## Agent work — planning, running and tracking agent tasks

| repo | stars | pushed | licence | what it is | idea it shows | verdict | improves |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [paperclipai/paperclip](https://github.com/paperclipai/paperclip) | 107,505 | 10-26 | MIT | a control plane that runs a "company" of agents | one owner per task, taken atomically ("409 → pick another"); wake on events, never poll | SKIP — a hosted runtime | task-runner |
| [stablyai/orca](https://github.com/stablyai/orca) | 106,577 | 10-26 | MIT | desktop app, many CLI agents, one worktree each | a stub skill that loads the full guide only when used; notify when an agent needs you | ROUTE | session-hud |
| [code-yeongyu/oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) | 70,349 | 10-26 | SUL-1.0 (not open source) | a standalone coding agent | a cheap side model that flags repeated mistakes | SKIP — licence forbids copying | — |
| [herdrdev/herdr](https://github.com/herdrdev/herdr) | 45,947 | 10-23 | Apache-2.0 | terminal multiplexer agents live in | wait for a state (done, blocked), never poll; "unknown" is never proof of done | ROUTE | task-runner, session-hud |
| [Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | 40,282 | 10-26 | MIT | team pipeline with hooks on 10 events | "one loop in charge per session"; a short handoff file at each stage | SKIP — the high-ceremony shape we are leaving | overseer |
| [gastownhall/beads](https://github.com/gastownhall/beads) | 28,219 | 10-26 | MIT | dependency-graph issue tracker for agents | a "what is ready now" query and an atomic claim | ROUTE | task-runner |
| [OthmanAdi/planning-with-files](https://github.com/OthmanAdi/planning-with-files) | 27,662 | 10-24 | MIT | plan kept in three files, re-injected by hooks | a Stop gate with a block cap **and** stall detection (no progress since the last block → let it stop); "skip for simple work" | ADOPT | candor |
| [getpaseo/paseo](https://github.com/getpaseo/paseo) | 22,090 | 10-26 | Apache-2.0 (README) | run many agents from desktop or phone | a handoff brief that includes "what was tried and why it failed"; two planners for hard calls | ADOPT | overseer, approaches |
| [google/elephant-goldfish-model](https://github.com/google/elephant-goldfish-model) | 1,435 | 10-25 | Apache-2.0 | specs written with context, audited by agents with none | review only in a fresh context; every finding resolved as "contest" or "fix" | ADOPT | code-review |
| [gmickel/flow-next](https://github.com/gmickel/flow-next) | 713 | 10-25 | MIT | one command picks the smallest route from idea to PR | **one front door**; `--explain` dry run; every stage prints ran / skipped (why) / failed (why) | ADOPT | code-architecture, taskmaster |
| [shinpr/claude-code-workflows](https://github.com/shinpr/claude-code-workflows) | 704 | 10-22 | MIT | design → plan → build recipes with specialists | size the route by how many decisions a change has, not by file count; re-run only the reviewer whose finding was fixed | ADOPT | taskmaster, task-runner |
| [boshu2/agentops](https://github.com/boshu2/agentops) | 450 | 10-26 | Apache-2.0 | plan/build/validate skills on a task graph | the whole plan is one short block; NOT_PROVEN as a verdict beside PASS and FAIL | ADOPT | code-architecture, candor |

## Developer workflow — context, cost, review, safety

| repo | stars | pushed | licence | what it is | idea it shows | verdict | improves |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) | 135,787 | 10-23 | Apache-2.0 | a queryable knowledge graph of a codebase | mark each map entry as read from code or inferred; rebuild on commit | ADOPT | brain |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | 110,667 | 10-13 | MIT | 25 lifecycle skills, 4 reviewer personas | a "excuses and red flags" table in each skill; approve the plan once, then run | ADOPT | taskmaster, task-runner |
| [rtk-ai/rtk](https://github.com/rtk-ai/rtk) | 84,604 | 10-26 | Apache-2.0 (engine BUSL-1.1) | rewrites shell commands so their output is filtered | swap a noisy command for a compact one, fail open, per-command opt-out | ROUTE | stack-scan |
| [headroomlabs-ai/headroom](https://github.com/headroomlabs-ai/headroom) | 77,884 | 10-24 | Apache-2.0 | compresses what the agent reads | reversible compression (original on disk, one retrieve call); never touch the cached prefix | ROUTE | — |
| [alibaba/open-code-review](https://github.com/alibaba/open-code-review) | 48,327 | 10-22 | Apache-2.0 | AI code review CLI | a script picks and bundles files; each bundle gets a small isolated reviewer; precision over recall | ADOPT | code-review |
| [DeusData/codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) | 47,526 | 10-26 | MIT | local code graph over MCP | outline and snippet calls instead of whole-file reads; refuse a stale index | ROUTE | brain |
| [tirth8205/code-review-graph](https://github.com/tirth8205/code-review-graph) | 32,395 | 10-16 | MIT | blast-radius graph for review | review a change's callers and tests, not only its lines; its honest "limits" section | ADOPT | code-review |
| [mksglu/context-mode](https://github.com/mksglu/context-mode) | 32,368 | 10-26 | ELv2 (README) | keeps raw tool output out of context | log small events before compaction, re-inject only what is relevant after | ROUTE | session-hud |
| [rohitg00/pro-workflow](https://github.com/rohitg00/pro-workflow) | 2,929 | 09-29 | MIT (badge) | memory plus 33 hook scripts on 22 events | `touch STOP` to halt a loop | SKIP — the hook-heavy shape we are leaving | — |
| [kenryu42/cc-safety-net](https://github.com/kenryu42/cc-safety-net) | 1,792 | 10-26 | MIT | blocks destructive commands across 16 CLIs | presets (standard / strict / paranoid); a corpus of recorded verdicts so a rule change shows its diff | ADOPT | command-guard |
| [openqodex/openqodex](https://github.com/openqodex/openqodex) | 819 | 10-26 | Apache-2.0 | pre-push review by a separate agent | a script checks every line the reviewer quotes; an unfinished review is "incomplete", never "clean" | ADOPT | code-review, candor |
| [coldteadotai/abide](https://github.com/coldteadotai/abide) | 610 | 10-10 | MIT | checks each edit against your CLAUDE.md rules | sort every rule by who can enforce it (linter, judge, nobody) and report the unchecked ones — our "Standing" tiers, applied to a user's own rules. Its checker is a hosted model that sees your diffs: privacy review before any ROUTE | ADOPT | hindsight, candor, ask-ledger |

## Interface design — UI and UX skills

| repo | stars | pushed | licence | what it is | idea it shows | verdict | improves |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | 140,682 | 10-26 | MIT | design catalogs plus a design-system generator | ship catalogs as data with a tiny search script, so only the matching rows enter context | ADOPT | ui-ux, craft-layer |
| [nexu-io/open-design](https://github.com/nexu-io/open-design) | 104,082 | 10-26 | Apache-2.0 | a local design workspace app | one DESIGN.md brand file every design skill reads | SKIP — an app; idea also in impeccable | design-kit |
| [tt-a1i/archify](https://github.com/tt-a1i/archify) | 89,577 | 10-26 | Apache-2.0 | validated interactive diagrams | the model writes structured data, one `finalize` command validates it and names the exact defect; one repair round | ADOPT | design-kit |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | 88,524 | 10-26 | Apache-2.0 | a design skill plus a no-model "AI look" detector | a small router skill; the anti-generic list enforced by a script on each edit, not by prose | ADOPT | craft-layer, ui-ux |
| [Egonex-AI/Understand-Anything](https://github.com/Egonex-AI/Understand-Anything) | 88,355 | 10-26 | MIT | interactive knowledge graph of a codebase | parser for structure, model only for meaning. **Its README hides a comment addressed to AI agents asking them to edit PR descriptions — a prompt injection.** | SKIP — do not recommend while the README carries it | brain |
| [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) | 61,239 | 10-26 | MIT | 45 diagram types as one HTML file | a size budget (9 nodes, 12 arrows) and a self-check script before output; "if a table says it, use the table" | ADOPT | design-kit |
| [alchaincyf/huashu-design](https://github.com/alchaincyf/huashu-design) | 26,514 | 10-23 | MIT | prototypes, decks and motion from one sentence | a ledger of recent looks so a project stops repeating itself; never guess brand colours | ADOPT | design-kit, craft-layer |
| [Manavarya09/design-extract](https://github.com/Manavarya09/design-extract) | 4,379 | 10-23 | MIT | extracts a live site's design tokens | real tokens from computed styles, not model guesses | ROUTE | design-kit, ui-ux |
| [plugin87/ux-ui-agent-skills](https://github.com/plugin87/ux-ui-agent-skills) | 3,021 | 10-26 | MIT | design rules with 52 automated checks | a Stop gate that blocks when an edited page was not rendered and checked since the edit | ADOPT | ui-ux, candor |
| [kwakseongjae/oh-my-design](https://github.com/kwakseongjae/oh-my-design) | 549 | 10-26 | MIT | 500+ DESIGN.md files and 32 skills | label each finding as defect, quality or taste; never invent a score out of 100 | ADOPT | ui-ux, craft-layer |
| [squirrelscan/squirrelscan](https://github.com/squirrelscan/squirrelscan) | 297 | 10-26 | MIT | website QA CLI (SEO, speed, security, a11y) | audit → fix → re-audit on a compact report; telemetry is on by default | ROUTE | testing, web-dev, security |
| [Krishna-Modi12/frontend-design-pro](https://github.com/Krishna-Modi12/frontend-design-pro) | 11 | 10-20 | MIT | a router sending each request to one of 19 skills | a token budget per request with a stated drop order; an explicit tie-break order | ADOPT | skill-router |
| [uxfront-com/open-components](https://github.com/uxfront-com/open-components) | 11 | 10-23 | MIT / CC-BY-4.0 | component rules as YAML contracts | review output as one row per rule: rule, level, result, evidence | ADOPT | code-review, ui-ux |

## Reader load and language — output a person can act on

| repo | stars | pushed | licence | what it is | idea it shows | verdict | improves |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [blader/humanizer](https://github.com/blader/humanizer) | 60,860 | 10-16 | MIT | rewrites AI-sounding prose | a short checklist of AI-prose habits plus a "no new facts" check — as an authoring aid for our own text; a checklist shipped to the model matches a shape that measured zero (`measured-zero-shapes.md` § 2) | ADOPT (authoring aid only) | repo authoring skill (not a plugin) |
| [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) | 58,808 | 10-19 | MIT | an output style that leads with the next action | first line is the action; restate "step 3 of 5"; one next step; lists of five or fewer | ADOPT | candor |
| [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) | 28,512 | 10-26 | GPL-3.0+ (parts BSL) | macOS terminal for parallel agents | a desktop notification when an agent needs you (OSC 9/99/777) | ROUTE | session-hud |
| [NVIDIA/SkillSpector](https://github.com/NVIDIA/SkillSpector) | 21,777 | 10-23 | Apache-2.0 | security scanner for agent skills | scan a third-party skill before installing it | ROUTE | stack-scan |
| [microsoft/SkillOpt](https://github.com/microsoft/SkillOpt) | 18,693 | 10-25 | MIT | optimises one skill against scored runs | keep a skill edit only if a held-out check improves; stage edits for review | ADOPT | hindsight |
| [tigerless-labs/autoharness](https://github.com/tigerless-labs/autoharness) | 10,787 | 10-23 | MIT | learns and prunes skills from transcripts | one agent proposes, another writes; archive, never delete; a hard size cap | ADOPT | hindsight |
| [QingYunA/answer-me-with-html](https://github.com/QingYunA/answer-me-with-html) | 4,482 | 10-26 | MIT | answers hard questions as one HTML page | the model writes content, a script lays it out; the reply is 2-3 lines plus a link (author-run: ~1/8 the tokens) | ADOPT | design-kit |
| [kharmanskyi/open-steps](https://github.com/kharmanskyi/open-steps) | 1,233 | 10-05 | MIT | plain-language skills for non-coders | a ~10-line "done or not" report: one row per claim, each "yes" names its proof or says "not checked" | ADOPT | candor, task-runner |
| [agent-sh/agnix](https://github.com/agent-sh/agnix) | 458 | 10-26 | MIT OR Apache-2.0 (README; API: Apache-2.0) | linter for CLAUDE.md, SKILL.md, hooks | every check has an ID and an `explain` command; safe fixes apply, unsafe ones preview | ROUTE | stack-scan (to recommend); repo gates (the ID idea) |
| [kunchenguid/gh-axi](https://github.com/kunchenguid/gh-axi) | 347 | 10-25 | MIT | `gh` wrapper built for agents | AXI output rules: truncate with a pointer to the full log, definite empty states, next-step hints, structured errors (author-run: 100% vs 86% success) | ADOPT | every hook |
| [Necmttn/ax](https://github.com/Necmttn/ax) | 121 | 10-07 | AGPL-3.0 | session-log review loop | judge a fix again after 3, 10 and 30 sessions | SKIP — hindsight covers it; AGPL | hindsight |
| [microsoft/scope](https://github.com/microsoft/scope) | 56 | 10-23 | MIT | agent evaluation platform | same task with and without the plugin, ordered gates, tokens and time beside the verdict | SKIP — `claude plugin eval --ablation` covers it | repo evals (not a plugin) |
| [saadshahd/moo.md](https://github.com/saadshahd/moo.md) | 38 | 10-22 | MIT | "never delegate a decision" skills | record unknown outside state as an open gap, never a guess | SKIP — more ceremony by design | taskmaster |

## What many of them do

1. **The smallest route that fits.** flow-next, shinpr, agentops and planning-with-files each state when to skip a step. Process scales with risk.
2. **One entry point.** flow-next routes everything through one command with a dry run.
3. **Short reply, detail elsewhere.** answer-me-with-html, open-steps, gh-axi and i-have-adhd put the answer first and park detail in a file or page.
4. **A script decides first; the model only decides what a script cannot.** rtk, cc-safety-net, impeccable's detector, archify's `finalize`, openqodex's quote check, plugin87's gates.
5. **Load on demand.** impeccable, frontend-design-pro, ui-ux-pro-max, orca and gh-axi keep the always-loaded part small and fetch the rest when used.
6. **Fresh-context review.** elephant-goldfish, open-code-review, openqodex and paseo never let the author's context review its own work.
7. **State in files, so a new session can resume.** planning-with-files, beads, paseo, flow-next.
8. **Every gate has a way out.** planning-with-files caps blocks and lets a stalled loop stop; "accidental blocking infuriates users" is its README's own line.

## Ideas none of them ship

- **One "what is happening, what do I owe" line** for the whole task arc: running and blocked agents, and the one decision waiting on the person.
- **Print the cost of the process next to the result**: extra agent calls, tokens and waiting time a run spent on ceremony.
- **A five-line human resume** generated from state files: where we are, what changed, what is next.
- **A savings ledger per plugin**: tokens a plugin kept out of context against tokens it added.
- **A "who is reading" setting** (expert, newcomer, on call) that sets reply length, jargon and list size for every plugin at once.
- **Measure our own output rules** with a with/without run: does "next action first" cut re-asks or turns?

## Also read (not in the 50)

| repo | stars | licence | why left out |
| --- | --- | --- | --- |
| [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) | 68,138 | MIT | a reading list; its tips (short CLAUDE.md, rules on demand, subagents to isolate output) are already ours |
| [mvschwarz/openrig](https://github.com/mvschwarz/openrig) | 8,207 | Apache-2.0 | needs a daemon, tmux and global config writes; one idea kept in the plan — report each resumed step as resumed / fresh / needs a decision / failed |

## Not verified

Not opened by the researchers:

- humanizer issue #229 (its blind test)
- SkillOpt's paper and LICENSE text
- SkillSpector's LICENSE and cited paper
- autoharness hook source
- moo.md skill files
- cmux hook source
- Necmttn/ax source
- agnix rules file
- context-mode routing source and BENCHMARK.md
- graphify BENCHMARKS.md
- codebase-memory-mcp preprint
- headroom proxy source
- code-review-graph hook source
- pro-workflow scripts
- cc-safety-net parser
- squirrelscan's audit skill (404)
- open-design daemon
- Understand-Anything hook
- plugin87 RESULTS.md
- oh-my-openagent and openrig mechanism files
- beads Claude integration doc (404)

Licences for paseo, cmux, context-mode and oh-my-openagent: the GitHub API reports NOASSERTION; the column gives the README's statement. agnix: the README says MIT OR Apache-2.0, the API says Apache-2.0.

Per-repo notes as returned by the researchers (machine-local): `.claude/overseer/milestones/m1/returns/0{1,2,3,4}-research-*.md`.
