# Taskmaster consistency review — 2026-11-14

Branch `review/taskmaster-consistency`. Sections 1 to 5 are the report as first committed, when no
plugin file had changed; section 6 records what was then fixed on the same branch. The question:
where do `taskmaster` and the plugins around it (`task-runner`, `overseer`, `ui-ux`,
`code-architecture`, `craft-layer`, `approaches`, `stack-scan`, `git-workflow`, `skill-router`)
contradict themselves or each other, and what would outside evidence change.

## Verdict

**The contracts that scripts parse agree. The prose around them has drifted, and one script
defect is reproduced (A1).** 54 findings: 27 that mis-run or leave a step undefined, 27 that only
misdescribe. Baseline is green and stays green, because no gate reads any of this:
`scripts/validate.sh` exit 0 and all 16 `plugins/taskmaster/scripts/__tests__/*.test.sh` pass.

What agrees, so nobody re-checks it: the card tags and the 12-tag agent vocabulary, the
`Ultra:` / `Goal:` / `Verify: range` line parsers, the `## Coverage` header, milestone
`Files:` / `Cards:` lines, the eight phase names and the 120-minute sentinel TTL, every path after
the `.cc-artifacts/` move (nothing still writes `taskmaster-docs/` or `.claude/taskmaster/`), every
`plugin:skill` and `/plugin:command` name in either direction, every userConfig default against its
code fallback, and every script flag, exit code, port and timeout the docs quote.

## How to read the standing column

| Label | Meaning |
| --- | --- |
| **ran** | reproduced by running the script this session |
| **read** | both sides read in this session's main thread |
| **relayed** | a subagent reported it; the quoted lines were re-read here and match. The stated consequence is the subagent's reasoning unless marked **ran** |
| **web** | from the research subagent; the source was not opened in the main thread |

Paths in §1 and §2 are relative to `plugins/taskmaster/` unless they start with another plugin's name.

## 1. Defects that change what a run does

| # | Where | What is wrong | Effect | Fix | Standing |
| --- | --- | --- | --- | --- | --- |
| A1 | `scripts/preview-cleanup.sh:15-16`; `skills/visual-decisions/references/real-components.md:96-97` | The cleanup greps the whole project for `__design-preview__`, and the reference tells the model to record the pick in the ledger "with `src/__design-preview__/main.tsx` as the source". The ledger lives in `.cc-artifacts/taskmaster/`, which the grep does not exclude. | Cleanup prints `artifacts REMAIN` and exits 1 on every run after a real-component pick, and the reference calls a non-zero exit "a failed run". | Exclude `.cc-artifacts/` and `taskmaster-docs/` from the content grep, add that fixture to `preview-cleanup.test.sh`. | **ran** (ledger row in a scratch dir, exit 1 twice) |
| A2 | `hooks/remind.sh:221,244`; `hooks/clarify-gate.sh:38` | The gate's only arming marker is written by `remind.sh`, which exits on any prompt starting with `/`. The gate also reads no path. | With `CC_CLARIFY_GATE=block`, a `/taskmaster:task` run is never gated. On a bare prompt the one deny lands on the first write of any file, which under grill is the ledger itself. | Arm from `phase-sentinel.sh write shape` as well, and skip paths under `.cc-artifacts/`. | relayed |
| A3 | `agents/spec-adversary.md:44-46`; `skills/spec-redteam/SKILL.md:8,37` | Lens 5 asks "Does every binding visual or creative decision have a card that will build it?". The adversary runs before cards exist and is given only the spec path. | The lens cannot be answered. It reports every staged decision as a hole, or guesses. | Cut the card clause from lens 5; coverage-check's second correspondence already owns it. | read |
| A4 | `skills/visual-decisions/assets/serve.py:58-60,655`; `skills/experience-walkthrough/SKILL.md:21` | The version list excludes `walkthrough.html` by exact name only. The walkthrough's dated copy, `YYYY-MM-DD-<slug>-walkthrough.html`, is in the same folder. | It is offered as a past pass of `current.html`; Restore copies it over the mockup, and the E6 change check can take it as the previous pass. | Exclude `*-walkthrough.html`, or write the dated copy to a subfolder. | relayed |
| A5 | `skills/ultra/SKILL.md:102-103`; `task-runner/commands/run.md:109-113`; `task-runner/skills/task-execution/references/boost-execution.md:23` | taskmaster's Goal contract lists negative-control as never suppressed. The runner, on 8 or more cards under a `Goal:` marker, takes range review "without asking", which drops the per-card negative control. | A hands-off run of any real size loses a check its own contract calls unsuppressable. | Decide which side is right, then say it in both. Either Goal keeps per-card review, or the never-suppress list names range review as the exception. | relayed |
| A6 | `skills/ultra/SKILL.md:123`; `task-runner/skills/task-execution/SKILL.md:92-95`; `task-runner/skills/code-redteam/SKILL.md:141` | `goal-lean` promises "no code red-team at execution". Range mode, taken automatically under any `Goal:` marker, closes with one `RT-LENS: teeth` red-team round. | A goal-lean run of 8 or more cards buys the round it declined. It overpays; it does not under-verify. | Exempt `Goal: true (boost=off)` from the range red-team, or say goal-lean keeps the teeth lens. | relayed, medium confidence |
| A7 | `skills/task-cards/SKILL.md:142-143,147`; `task-runner/skills/task-execution/SKILL.md:179`; `task-runner/skills/parallel-planning/SKILL.md:25` | task-cards promises a full-suite verify at each milestone close and no interleaving of milestones. The serial runner runs the suite once at the end and levels the whole card set. | No milestone is proven shippable on its own, which is the property milestones are sold on. | Add the milestone-close suite run to task-execution, or cut the promise. | relayed |
| A8 | `skills/ultra/SKILL.md:68,77`; `skills/ultra/references/dispatch-tiers.md:18,107`; `hooks/ultra.sh:50` | The boost contract mandates "card-verify: one fan-out pass per card". No skill says what the pass checks. In task-runner the same word means re-running a card's verify command. | An ultra run improvises the step or skips it. | Define it (§3 R4 is a candidate) or delete it from the contract and both hook directives. | read |
| A9 | `skills/ultra/SKILL.md:68`; `skills/ultra/references/dispatch-tiers.md:27-29,71-73`; `skills/coverage-check/SKILL.md` | "coverage gap-judgment" is listed as dispatched at the boosted tier, and the same file then says it "runs in the main thread at the session tier". The radius table caps the coverage loop at 2 or 3 rounds; coverage-check has no boost section and no round cap. | "Mandatory coverage under boost" changes nothing a standard run does not already do. | State that plainly, or give coverage-check a boosted judge. | read |
| A10 | `skills/spec-redteam/SKILL.md:50` against `:29-31`; `skills/ultra/SKILL.md:66-73` | The panel section opens "Under `ULTRA-TASK ACTIVE`". The same skill warns thirty lines up that goal injects `ULTRA-GOAL ACTIVE`, "not the ultra-task string". | Read literally, a boosted goal run gets one adversary, where the boost contract says a panel in both modes. | Key the panel on either directive without `boost=off`. `commands/brainstorm.md:66` and `dispatch-tiers.md:128` have the same single-string wording. | read |
| A11 | `skills/ultra/references/dispatch-tiers.md:63-66`; `commands/brainstorm.md:96-98` | Recon at N=2 scans sections 1–2 and 3–4. Section 6, Visual surface, joins only at N=3. Unboosted N=1 scans all six. | A boosted medium run on a UI task has no Visual surface or theme tokens, which brainstorm and visual-decisions key on. The boost scans less than the standard run. | N=2 on a UI task: 1–3 and 4+6. | read |
| A12 | `skills/task-cards/references/index-markers.md:17-27`; `skills/ultra/SKILL.md:142`; `hooks/ultra.sh:46`; `task-runner/skills/track-orchestration/SKILL.md:57` | One file says copy `model=auto` verbatim, then asks for a `Goal:` line "with the resolved tier" and `(model=<model>, effort=<effort>)` placeholders. It says a goal run writes both lines; the hook directive names only the `Goal:` line; the runner says "`ultra-goal` stamps no `Ultra:` line". | No runtime break, since every reader falls back from `Ultra:` to `Goal:`. What a goal index contains depends on which text the model followed. | One rule in index-markers, literal values, and the other three cite it. | read + relayed |
| A13 | `skills/verify-teeth/SKILL.md:3-4,36-50`; `skills/task-cards/SKILL.md:182-185`; `scripts/verify-teeth-lint.sh:62` | The skill is hidden (`disable-model-invocation: true`). task-cards runs the script directly and never gives the skill's path. The script prints only `verify-teeth: <reason>`. | The fix table for each reason is text no run loads. | Print the fix beside the reason in the script, or cite `../verify-teeth/SKILL.md` from task-cards' lint step. | read |
| A14 | `scripts/card-paths-lint.sh:27`; `hooks/card-lint-observe.sh:87-89,106`; `skills/coverage-check/SKILL.md:9` | `card-paths-lint` writes a run record. The observer checks three records and its warning names three linters. | A set that skipped the newest lint draws no warning. | Add the fourth record and linter name; fix "three" in coverage-check and the harness header. | read |
| A15 | `scripts/goal-ledger-check.sh:61`; `skills/ultra/SKILL.md:135-136` | The check requires a line starting `## ` or `- `. The skill lists the fields of an entry and no line format. | A ledger kept as a table halts the goal run at the `Goal: true` stamp with `no-entries`. | State the format in the skill; `--init` could write a header showing it. | relayed |
| A16 | `scripts/preview-feedback.sh:127-130`; `README.md:327-328` | Only notes are re-leased after 15 minutes. The README says a row handed to a waiter that died "loses nothing". | A pick printed to a dead waiter is gone; the user is asked again. | Re-lease picks too, or narrow the README sentence to notes. | relayed |
| A17 | `hooks/preview-guard.sh:79`; `skills/visual-decisions/SKILL.md:108` | The guard builds its URL from `${PREVIEW_PORT:-8123}`. The skill tells the model to rerun with `--port <next>` on exit 4. | After a port change the guard points at the wrong localhost URL. | Read the docroot's `.preview.url`, which the guard already locates. | relayed, low impact |
| A18 | `scripts/preview-cleanup.sh:8`; `skills/visual-decisions/references/real-components.md:152` | `--verify` is honoured only as the first argument. | `preview-cleanup.sh <root> --verify` deletes. | Accept it in either position, or exit 2 on an unknown trailing argument. | relayed, low impact |
| A19 | `skills/task-cards/SKILL.md:83,158`; `task-runner/skills/parallel-planning/SKILL.md:19` | "Size every card S/M/L/XL" has no element in the card and no column in the index. The runner sizes again on a different scale (minutes) to decide BATCH against INLINE. | The author's sizing is thrown away and the two scales can disagree. `README.md:64` and `commands/task.md:99` advertise the sizing. | Add a size column to the index and have the runner read it, or reword the rule as a split test and drop "sized" from the README. | read + relayed |
| A20 | `skills/task-cards/references/milestone-file-sets.md:4,10-13` | It collects "every `Files` path" and strips a trailing `:line`. Cards have used `<file path="…" line="…">` since 0.45.0. | The normalisation rules describe a shape task-cards no longer emits. | Rewrite against the `path` attribute. | read |
| A21 | `skills/task-cards/SKILL.md:188`; `skills/ultra/SKILL.md:94` | The tail step calls a `project-skill-suggester` skill. It exists only as this repository's own `.claude/skills/project-skill-suggester`; no plugin ships it. | The step is dead for every installer. It degrades silently by design. | Cut the step, or keep it and say it is a hook for a user's own skill. | relayed, low |
| A22 | `ui-ux/skills/shadcn-theming/SKILL.md:139-153`; `scripts/preview.sh:4` | ui-ux starts the shared server with `python3 -m http.server` and recovers with `lsof … \| xargs kill`. The launcher's header says a server it did not start "holds the port and gets exit 4, not reuse". | A theme run first leaves visual-decisions on a second port, with no pid file, no feedback and no check badge. The `kill` also ends a launcher-managed server. | ui-ux calls `preview.sh` when taskmaster is installed, and stops with `preview.sh --stop`. | relayed |
| A23 | `overseer/skills/overseer/references/dispatch-prompts.md:110`; `overseer/skills/overseer/SKILL.md:95`; `commands/task.md:121` | One overseer file sends "two-plus parallel groups" to `--tracks`; another says tracks are for track-eligible milestones. taskmaster's handoff command has no way to pass `--tracks`. | Under `goal` the handoff auto-runs serially whatever overseer intended. | Overseer picks one rule; the handoff passes the flag when the index has per-milestone `Files:` lines, or says it never does. | relayed |
| A24 | `ui-ux/commands/build.md:124-126` | Both branches test "taskmaster installed": the first routes to the real-component rung, the second to the shell. | The shell branch cannot run. Every undecided choice goes to the rung that writes into the user's source tree, which `real-components.md:6` reserves for when a shell "cannot carry the decision". | Route to `taskmaster:visual-decisions` and let its ladder choose. | relayed |
| A25 | `git-workflow/skills/branch-completion/references/marketplace-scratch.tsv:24`; `skills/grill/SKILL.md:63`; `README.md:57`; `CHANGELOG.md` 0.60.0 | git-workflow marks all of `.cc-artifacts/` scratch. grill says "ledgers are scratch, the specs beside them are not", and 0.60.0 narrowed the ledger `.gitignore` because "a project may track" specs. The README says "one folder to gitignore". | `scratch-ignore.sh --apply` ignores specs a project meant to track. taskmaster's own two statements disagree. | Decide whether specs are trackable. If yes, the tsv row excludes `specs/` and `tasks/` and the README says so. | relayed |
| A26 | `craft-layer/skills/section-decisions/references/section-ledger.md:15`; `craft-layer/commands/audit.md:70` | The ledger goes "in that task's directory, beside the spec". Specs are flat files in `specs/`; the audit looks only in `.cc-artifacts/taskmaster/craft/`. | A ledger written per the reference can be missed by the audit. | Name the one path in both. | relayed |
| A27 | `task-runner/skills/track-orchestration/references/algorithm.md:68-69`; `task-runner/hooks/status-core.ts:1`; `task-runner/skills/task-execution/references/routing.md:76` | Tracks mode writes status `merged`, which `STATUSES` does not contain. Negative control targets a card's "declared primary implementation file", which no card declares. | Runner-internal: the status tool, the board, `announce.sh` and `coverage-close.sh` treat `merged` four ways; the target is the orchestrator's guess. | Add `merged` to `STATUSES` or map it to `done`; add a `primary` attribute to `<file>` or drop "declared". | relayed, low |

## 2. Text that misdescribes, with no effect on a run

| # | Where | Says | Is | Standing |
| --- | --- | --- | --- | --- |
| D1 | `README.md:258` | "**Hooks**, five" | Six are registered; `shape-guard.sh` is missing from the list. | read |
| D2 | `README.md:270` | "every one has an off switch" | `shape-guard.sh` reads no switch and `plugin.json` has no option for it. Either add one or say it has none. | read |
| D3 | `README.md:262-267` | The script list | Omits `card-shape-lint.sh`, `card-paths-lint.sh`, `card-set-lint.sh`, `phase-sentinel.sh`. | read |
| D4 | `README.md:21-25` | The Commands table | Omits `/taskmaster:coverage` and `/taskmaster:redteam`. | read |
| D5 | `README.md:33-72` | The eight pipeline steps | Omit the approach decision, the spec red-team and the coverage check as steps. | read |
| D6 | `lane.tsv:13` | clarify-gate fires when "a Write/Edit lands before the task's ambiguity ledger is resolved" | The hook reads no ledger; `plugin.json:29` has the true trigger. | read |
| D7 | `lane.tsv:14` | preview-guard fires on "mockup-shaped content … while a live preview server is the declared route" | The hook reads the file path only and probes no server. | relayed |
| D8 | `skills/grill/SKILL.md:92` | `Detail:` is a "**gate**" | `spec-ledger-lint.sh:112` warns and exits 0 when it is missing; only a bad value blocks. | relayed |
| D9 | `skills/task-cards/references/card-shape.md:26` | "a framework card names a real skill — **gate**" | `skills-stamp-lint.sh:94` warns `unreachable-skill` and exits 0; only an empty or `none` stamp blocks. | relayed |
| D10 | `skills/visual-decisions/references/shell-authoring.md:321`; `assets/serve.py:685` | Restore is "the server's only write" | `POST /_feedback` has appended `.feedback.jsonl` since 0.58.0. | relayed |
| D11 | `.claude-plugin/plugin.json:4`; `approaches/skills/approach-deliberation/SKILL.md:57` | The approach is settled by "a blind four-persona round"; "grill and brainstorm run the panel" | `skills/grill/SKILL.md:166-167` uses the inline slate by default and the panel only for rework. `commands/brainstorm.md:135` always runs the panel, on new ideas, which approaches' own rule gives to the slate. | read |
| D12 | `commands/task.md:45` | "reminder hooks that own a later phase stand down" | `hooks/remind.sh:85` stands a hook down when the sentinel is past the hook's phase: earlier phases stand down. `git-workflow/commands/finish.md:28` has it right. | relayed |
| D13 | `README.md:234` | "`/craft-layer:craft` consumes the spec" | `craft-layer/commands/craft.md` never mentions a spec; only section-decisions reads one, and one-shot mode skips it. | relayed |
| D14 | `scripts/card-lint-record.sh:7`; `scripts/goal-ledger-check.sh:24`; `scripts/find-browser.sh:5` | — | `CC_CARDLINT_DIR`, `GOAL_LEDGER_DIR` and `PREVIEW_BROWSER` are read and named in no doc. The first two look like test seams. | relayed |
| D15 | `code-architecture/README.md:136` | "taskmaster — supplies the plan-before-code and work-verification gates" | code-architecture owns both skills. | relayed |
| D16 | `code-architecture/skills/coding-entry/SKILL.md:8,157` | "A taskmaster card carries `Skills to apply`" | The label has been `<skill name="…"/>` since 0.45.0. | relayed |
| D17 | `stack-scan/skills/plugin-scout/references/picker.md:127`; `flags.md:104` | taskmaster "overlaps" task-runner, so it is deprioritised when task-runner is installed | task-runner is the stage after it. | relayed |
| D18 | `overseer/skills/overseer/references/dispatch-prompts.md:102,118` | "grill treats the acceptance lines as CLEAR rows"; red-team runs "past three criteria or an ASSUMED row" | grill has no rule for a brief; the red-team gate has two more triggers. | relayed |
| D19 | `overseer/skills/overseer/references/capability-map.md:25` | "`approaches` (compare, size)" | `size` was removed 2026-09-22. | relayed |
| D20 | `overseer/commands/start.md:23,32`; `commands/task.md:72`; `code-architecture/skills/coding-entry/SKILL.md:64` | Several screens are a program; "When unsure, it is a program" | taskmaster treats three or more screens as one spec with a walkthrough. The same ask routes differently by entry point. | relayed, medium |
| D21 | `.chassis.json:5`; `code-architecture/skills/coding-entry/SKILL.md:79,158` | "ask your open questions in one batch … do a small change inline with /code-architecture:work" | `/work` sends any unresolved unknown to the full pipeline and forbids a question round. | relayed, medium |
| D22 | `skill-router/lane.tsv:8,10` | Cites "clarification outranks tool-fit (hooks/route-prompt.sh, rule 3)" and rank 25 "ahead of every other arc voice" | `route-prompt.sh` has no such text; ranks 10 and 20 sit ahead. | relayed |
| D23 | `ui-ux/commands/theme.md:40` | grill drops a `.gitignore` in the mockups folder | grill writes it in `.cc-artifacts/taskmaster/`, holding two ledger patterns. | relayed |
| D24 | `task-runner/skills/code-redteam/SKILL.md:63`; `track-orchestration/references/algorithm.md:26,59` | Tier resolution is "`task-execution/SKILL.md`'s rule" | The rule lives in `references/boost-execution.md`. | relayed |
| D25 | `rationale/README.md:5,26` | Working material goes to `taskmaster-docs/` | `CLAUDE.md` moved it to `.cc-artifacts/`. | read |
| D26 | `skills/task-cards/SKILL.md:76-79` | "Verify:" as a card field name, three times | The element is `<verify>`. | read |
| D27 | `plugins/taskmaster/` has no `evals/` | — | Every "agent-graded" row in this plugin is unmeasured. `CLAUDE.md` § Evals says what a measurement would need. | read |

## 3. Research: what outside evidence would change

All of this section is **web**: one research subagent, which re-opened most sources itself. The
main thread opened none of them. The "local gap" column is checked here by grep.

| # | Idea | Changes | Evidence as reported | Local gap | Cost | My read |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | When a card's facts disagree with the code, the worker follows the code and reports it; when the card's intent conflicts, it halts. | task-execution, one sentence | arXiv 2610.30571 (2026-10-22): agents followed a stale instruction file in 90.1% of choices; one sentence raised code-following from 4.2% to 91.4%. | No rule in task-cards or task-execution says which wins. Cards run sessions after they are written. | S | Do it. Cheapest item here, and it closes a hole A1-style path lints cannot. |
| R2 | Ask "why" as an open question when the request gives no reason, before the upgraded statement. | grill, brainstorm | superpowers v7.0.2 (2026-11-03): reason captured in 33 of 33 runs against 19 of 33, author-graded. | `prompt-upgrade.md` step 2 derives the reason and shows it for veto. | S | Do it, skipped when the prompt states the reason. |
| R3 | A brainstorm can end "don't build" or "not now", recorded with its reason. | brainstorm | Asana (2026-09): a detailed spec "made the project easy to continue, even when the starting idea was shaky". | `commands/brainstorm.md` has no such exit. | S | Do it. |
| R4 | A fresh, cheap subagent reads each card as its executor and lists what it would still have to ask. | task-cards tail | superpowers v7.0.0 (2026-10-10) "builder check". Unmeasured. | Nothing reads a card cold to test the fresh-session claim. | S–M | This is a definition for the undefined card-verify (A8). Under boost only, to start. |
| R5 | A row answered by the question dialog's idle timeout is ASSUMED, not CLEAR. | grill | Claude Code tools reference: on timeout the dialog "tells Claude you may be away … so Claude proceeds on its own judgment". Opt-in setting. | grill's headless fallback covers no dialog, not a timed-out one. | S | Do it. |
| R6 | At run close, append what was built differently to the spec, mark it implemented, move spec and cards to an archive. | grill, task-runner close | OpenSpec (Thoughtworks Radar, Trial, 2026-11-04); Asana moving specs to an archive. | No doc examined delta specs. A later context-scout reads an old spec as current. | M | Worth a design round; touches two plugins. |
| R7 | For changes to existing code, the spec lists behaviours that must not change, each tied to a named test, copied into `<verify>`. | grill, task-cards | Kiro bugfix specs; TDAD (arXiv 2603.17973): regressions 6.08% to 1.82% with targeted test context, two small models. | No "unchanged" or regression section anywhere in the pipeline. | S–M | Plausible. Weak evidence. |
| R8 | Asks touching two files or fewer, and fix, refactor and test asks, default to the quick lane unless a risk clause fires. | `/work` triage | Uvik benchmark (vendor, 50 tickets): 85% merge with and without a spec on 1–2 files; 80 against 50 on six or more. | The triage has no file-count or ticket-type threshold. | S | Hold. One vendor study with ±10 points of noise. |
| R9 | A total question budget of about five, ranked by impact × uncertainty, instead of rounds. | grill | Spec Kit's clarify template caps at five. No study tests a cap. | `skills/grill/SKILL.md:96,142` allow up to 16. | S | Hold. The 2026-10-26 plan already set a target of four; measure that first. |
| R10 | A shape lint for success criteria: each names a trigger and an observable outcome. | spec-ledger-lint | Kiro EARS; OpenSpec validate. No study links the format to correctness. | Proposed earlier as T3, unbuilt. | S–M | Hold. |
| R11 | Under boost, spend on a second reader on a different model, not on more effort. | ultra | ClarifyCodeBench (arXiv 2607.00711): more reasoning gives "marginal gains in identifying ambiguities". | Nothing local measures holes found against effort. | S | Hold. Neither paper tests a spec red-team. |

**Host changes since the 2026-10-15 review** (as reported, CLI 2.1.301 to 2.1.325):

| Change | Consequence here |
| --- | --- |
| 2.1.317: a subagent on a different model takes that model's saved effort, not the session's | `README.md:104-107` ("an unpaired boost escalates the model alone") needs re-reading against it. Both agents pin effort, so no break. |
| 2.1.319: `permissions.denyInsteadOfPrompting` | Answers the open question from the 2026-08-28 council: a hands-off goal run can deny instead of stalling. Name it in the Goal section; log denials to the goal ledger. |
| 2.1.323: `engines["claude-code"]` in `plugin.json` | Could declare the 2.1.292 floor the boost's `effort` depends on. The manifest docs page did not list it yet. |
| Agent frontmatter `omitClaudeMd` (2.1.271) | spec-adversary is blind to the conversation and still loads the project's `CLAUDE.md`. Setting it would make it blinder. |
| 2.1.302: desktop and VS Code always run subagents in the background | grill must wait for context-scout's report there; its Step 0 does not say so. |
| 2.1.319 / 2.1.323: after safeguards stop a subagent, Claude is told to retry narrower or tell the user, "instead of doing the work itself" | Conflicts, in that one case, with every "no dispatch → inline" fallback in the pipeline. |

Not found by the research at all: any study of question caps, harm from over-asking on clear
tasks, or blind against informed spec review. AskUserQuestion's per-call limits were not on the
fetched docs page, so grill's "up to 4 questions per round" is unverified by it.

## 4. Suggested order

| Wave | Items | Touches | Why this order |
| --- | --- | --- | --- |
| 1 | A1, A3, A4, A13, A14, A18, D1–D10, D12, D26 | taskmaster only | One version bump. Each has one right answer and needs no decision. A1, A4, A14 and A18 change scripts and get a fixture each. |
| 2 | A8–A12, A15, A19–A21, D11 | taskmaster only | Each needs a choice first: what card-verify is, whether sizes are recorded, slate or panel in brainstorm. |
| 3 | A5–A7, A23, A27, D24 | taskmaster + task-runner + overseer | Contract decisions between plugins. A5 is the one that weakens a safety claim. |
| 4 | A22, A24–A26, D13, D15–D23 | ui-ux, git-workflow, craft-layer, code-architecture, stack-scan, overseer, skill-router | One-line corrections, one bump each. |
| 5 | R1, R2, R3, R5, then R4 | grill, brainstorm, task-execution | Additions. Each is a sentence or a short section; none is measured, so they ship as `recorded`. |
| later | A2, A16, A17, R6, R7 | — | A2 is a design change to an opt-in hook. R6 and R7 want a spec of their own. |

## 5. What was not read

- Main thread, read in full: every taskmaster command, agent and `SKILL.md`; grill's, task-cards'
  and ultra's references; `README.md`, `plugin.json`, `hooks.json`, `lane.tsv`, `.chassis.json`.
  Not read in the main thread: `shell-authoring.md`, `real-components.md`, `ascii-patterns.md`, the
  starters, `shell.html`, `CHANGELOG.md` past 0.60.0, and the hooks and scripts beyond the lines
  cited above.
- Scripts-against-docs subagent: read every hook and script, `serve.py` and `check.js` in full;
  grepped `shell.html`; sampled the CHANGELOG to 0.57.0; did not open the starters, most test
  files, or `shell-authoring.md` lines 31–269.
- Runner-contract subagent: did not open task-runner's `behavioral-gate.sh`, `floors*.ts`,
  `spawn-cap.sh`, `rv-observe.sh`, most `scripts/__tests__/`, or `tests/*`.
- Cross-plugin subagent: read taskmaster's core, overseer's skill and dispatch prompts,
  code-architecture's `work.md` and coding-entry in full; excerpts or grep for every other plugin;
  no CHANGELOG and no test file.
- Nothing was run except `validate.sh`, taskmaster's harnesses and the A1 reproduction. Every
  "Effect" marked relayed is reasoning from the code, not an observed run.

## 6. Amendment — what was applied on this branch

The owner picked waves 1, 4 and 5, then answered seven choices for waves 2 and 3. Versions:
taskmaster 0.61.0, task-runner 0.58.0, and a patch each for approaches, code-architecture,
craft-layer, overseer, skill-router, stack-scan and ui-ux.

| Choice | Answer | Lands in |
| --- | --- | --- |
| A8 card-verify | Define it as the builder check (R4), boosted runs only | `ultra/references/dispatch-tiers.md` § Card-verify |
| A19 card sizes | A split test only; nothing recorded | task-cards, README, `task.md` |
| D11 brainstorm | Slate by default, panel for rework, as approaches' own rule | `brainstorm.md`, `plugin.json`, approaches |
| A25 specs | The whole folder is scratch; taskmaster ignores only its ledgers | grill |
| A5, A6 Goal and range review | Document the substitution; the runner is unchanged | ultra skill |
| A7 milestones | The runner runs the suite at each milestone close | task-execution |
| D17 picker pair | Remove taskmaster / task-runner | stack-scan |

**Fixed:** A1, A3–A15, A18–A26; D1–D13, D15–D19, D22–D26; R1, R2, R3, R4, R5. Four got a fixture
that was run against the old code and failed, then passed on the fix: A1 and A18
(`preview-cleanup.test.sh`, 3 of 8 cases red on the old script), A4 (`serve.test.sh`, where the
old server answered 200 to restoring a walkthrough over `current.html`), A14
(`card-lint-observability.test.sh`, 2 cases red on the old hook). Everything else is prose and
has no test.

**A16** was fixed on the README side only: the sentence now says a pick's hand-out is final.
**A9** was fixed by stating that the boost puts no tier on coverage; the unbound loop caps were
removed from the radius table rather than bound.

**Left open:**

| # | Why |
| --- | --- |
| A2 | Arming the clarify gate inside a slash-command run is a design change to an opt-in hook. |
| A17 | The guard's URL after `--port` is a hook code change; low impact. |
| A27 | `merged` is missing from `STATUSES`, and no card declares a primary file: runner code, with board tests to move. |
| D14 | Three undocumented environment variables, two of them test seams. |
| D20, D21 | Where a multi-screen ask is routed, and what the reminder says about `/work`: routing design across three plugins. |
| D27 | taskmaster ships no eval, so every agent-graded rule here, the five additions included, is unmeasured. |
| R6–R11 | Held; the evidence is weak or the change wants its own spec. |
| A7 residual | `plan-overlap.sh --dir` still levels the whole card set. The milestone order is prose in task-execution, standing recorded. |

**Gates on the fixed tree.** `validate.sh`, `generate.sh --check`, `context-budget.sh`,
`chassis-template-tests.sh` and `mod-tests.sh` pass, and so do all 16 taskmaster harnesses. Ten
checks fail on this machine with and without the change, in files the change does not touch:
`official-validate.sh` on four mod plugins (TypeScript errors in their tests under CLI 2.1.325;
the script pins 2.1.300), four harnesses that import `.ts` under Node 20
(`board-core`, `floors-core`, `status-core`, `pattern-parity`), and two that read a perl locale
warning as a failure (`candor/gate.test.sh`, `smoke/evidence-gate-hook-tests.sh`). Each was run on
the stashed tree and failed the same way.

**Not verified.** R5 rests on the host's tools reference, fetched once by a subagent and quoted
verbatim; R1 to R4 rest on web sources the main thread did not open. No taskmaster run was made
with the new text, so that a model follows any of the prose changes is untested.
