# Opus 5.5 playbook alignment review, 2026-09-23

**Standing: `recorded`.** Nothing reads this file back. It is a review, not a gate.
Same shape as `2026-09-01-fable5-prompt-alignment.md`: every finding names the file
it rests on, and the outcome table at the end says what changed.

## Source

"Getting the most out of Opus 5.5 in Claude and Claude Code", Addy Osmani, claude.dev,
published 2026-09-22, fetched 2026-09-23. Unlike the September 1 review this is a
first-party publication, not a leak — a playbook of user-facing conventions, not a
system prompt. It is evidence about how the model *behaves*; it says nothing about the
plugin surface directly. The question asked of every plugin was the same three-way
one: does it contradict a convention, does it already carry one, is there a gap where
a shipped artifact should carry one.

Two host facts were re-verified against the live docs rather than the post (via the
`claude-code-guide` agent, 2026-09-23, CLI 2.1.280 installed):

- `ultrathink` is still a live keyword (`code.claude.com/docs/en/model-config.md`);
  the `opus` alias resolves to Opus 5.5; `effort` is frontmatter-only on the Agent path.
- The flag switch is `switchModelsOnFlag` in settings (`settings-reference.md`).
- One claim in that answer **contradicts** the marketplace and is left unresolved:
  the agent read `workflows.md` as offering no `effort` param on `Workflow`'s
  `agent()`, while `task-runner`'s `dispatch-tier.md` and every boost skill say effort
  binds ONLY there. Not settled here — it predates the post and is its own audit.

## The post's conventions, mapped

| Post says | Marketplace status | Where |
|---|---|---|
| Delete "think carefully / think hard" lines from prompts and saved instructions | **Clean.** No plugin injects one; the only "think" tokens are `ultrathink`, documented as the host's own keyword, never injected | grep in this review |
| Do not ask the model to reproduce its reasoning in the reply (a flag category) | **Clean.** No artifact asks for it | grep in this review |
| Say what "done" looks like; stop-and-ask rule in CLAUDE.md; keep going otherwise | **Carried, stronger.** task-runner forbids ending a live run's turn through prose ("starting card 01 now" binds nothing), Goal mode is hands-off with safety halts never suppressed; candor's cut list drops the closing offer | `task-runner/commands/run.md` step 1; `taskmaster/skills/ultra`; `candor/skills/terse-output` |
| Split big work across subagents, check each one's evidence | **Carried.** Scout-then-fan-out, evidence-backed returns, refuter panels | `task-runner/skills/delegation-contracts`, `verification-panels` |
| Keep the task list in a file that survives compaction | **Carried.** Status lives only in `00-INDEX.md`; compact-recovery hooks restore the decision record | `task-runner/skills/task-execution` § Sequencing; `approaches/hooks/compact-recovery.sh` |
| Read "what it needs from you" first when a run ends | **Gap → fixed.** candor's fixed report skeleton put Blocker/decision fifth of six | Finding 1 |
| Review: "only problems you'd block the merge for … and how to show it fails" | **Half carried → fixed.** The drop-what-would-not-change-the-author's-next-move rule and the false-positive taxonomy already do the first half; "how to show it fails" existed only on the `ReportFindings` path | Finding 2 |
| Research: mark what could not be confirmed and where you looked | **Carried.** `UNVERIFIED:` block with what was searched; `unconfirmed` verdict class | `ultra-deep-research/agents/researcher.md:29,42` |
| Design: name the styles to leave out; "avoid a generic look" swaps one default for another | **Carried in the craft flow, gap outside it → fixed.** The fingerprint registry is exactly a named leave-out list, and `concept-deck.md:267` names "banning in prose" as an anti-pattern; four of the post's five patterns were listed, one was not; a bare `/ui-ux:build` carried no list at all | Findings 3, 4 |
| Attach charts and screenshots; ask for the finished file; settled-answers instruction; fast mode; `/model` after a flag | **Not a plugin concern.** User-side conventions with no artifact to carry them | — |

## Finding 1 — candor's report skeleton buried the one part the post says to read first

**Severity: medium. Plugin: candor.**

`terse-output/SKILL.md` fixed the work-done skeleton as Verdict → Artifacts → Findings
→ Skipped → Blocker or decision → Next. The post: "When a long run ends, look first for
anything Claude is waiting on you for … Then read the rest." A 12-line `full` budget
with the blocker in slot five is a report whose most actionable line is the one the
reader reaches last. The hooks (`activate.sh`, `mode.sh`) read the contract block live
from the skill, so moving the slot moves the injected card with it.

**Fix:** Blocker or decision is slot 2. Content of every slot unchanged.

## Finding 2 — a critical finding did not have to say how to show it fails

**Severity: medium. Plugin: code-review.**

`commands/review.md` already maps `failure_scenario` ("concrete inputs-to-wrong-output")
onto `ReportFindings` — but only when the tool exists. The prose line, which is what the
stack fan-in merges on and what every host without the tool sees, required
`problem — fix` and nothing about reproduction. The post's review prompt asks for
"how to show it fails" as one of three fields, and pairs it with fewer false alarms —
which is the same argument the command's own self-refute pass makes.

**Fix:** `critical` and `high` findings carry the failing input or state inside the
problem clause, in the agent and the command. Format string unchanged.

## Finding 3 — the fingerprint registry listed four of the post's five defaults

**Severity: low. Plugin: craft-layer.**

`sameness-fingerprint.md` § Category-default chrome carried the cream background (as a
palette row), the italic accent word, the `01 / 02 / 03` labels and the monospace label.
Pill-shaped buttons were absent. The post names all five together as what the model
"falls back on" with no direction — a first-party statement of the model's own defaults,
which is exactly what that registry catalogues.

**Fix:** one row, with source and date, agent-graded like the rest of that list.

## Finding 4 — a bare `/ui-ux:build` handed the worker no leave-out list

**Severity: low-medium. Plugin: ui-ux.**

The craft flow threads `Banned vocabulary:` verbatim into the build (`craft.md:138`) and
`build.md` honours decided lines. A build invoked without a concept stage carried none,
so the worker got the model's defaults — the case the post describes. The post's other
half matters as much: a general "avoid a generic look" does not work, a named list does,
which is why the fix names patterns rather than adding an adjective.

**Fix:** with no `Banned vocabulary:`/`Signature:` line, the dispatch names the five
patterns as left out unless asked for, or hands the worker the fingerprint file when
craft-layer is installed. Standing: recorded.

## Checked and left alone, with the reason

- **`ultrathink` guidance stays.** The post says to delete "think hard" lines because the
  model thinks by default; `ultrathink` is a documented host keyword that sets the budget,
  still live on 2.1.280, and this marketplace documents it for users rather than injecting
  it. taskmaster's "all three knobs" table is accurate. No change.
- **`effort: xhigh` on reviewer agents stays.** The post's "lowest effort caught more bugs
  than Opus 5 at high effort" is one tester's report; no measurement here, and lowering a
  pin on that alone would be the same unmeasured move in the other direction. Recorded as
  the obvious control/treatment run if `turn-cost.sh --skills` ever shows the reviewers
  are what a session spends on.
- **No stale model IDs.** The only `claude-opus-5` strings are candor's test fixtures;
  `opus` resolves to 5.5 by alias. The role-floor ladder `haiku < sonnet < opus < fable`
  is unchanged by the launch.
- **The CLAUDE.md stop/continue rule is not shipped.** `hindsight:claude-md`'s proposal
  rule forbids generic advice, and the rule is per-project by the post's own framing
  ("edit it to fit your project"). task-runner already carries the behavioural half for
  runs it owns. A plugin that injects it into every session would be the compensation
  prose `model-tier-scoping.md` warns against.
- **Flagged-message model switch.** Six agents pin `model: opus`; a flagged subagent turn
  moves to an older model under the default `switchModelsOnFlag: true`. Nothing in a
  plugin can change that; the security plugin's work ("finding security vulnerabilities
  in source code") is named as allowed by the post.

## Outcome

| # | Plugin | Change | Version |
|---|---|---|---|
| 1 | candor | Blocker or decision is slot 2 of the work-done skeleton | 0.4.8 → 0.4.9 |
| 2 | code-review | critical/high findings say how to show it fails, in agent and command | 0.22.0 → 0.22.1 |
| 3 | craft-layer | pill-shaped-button row in the fingerprint registry | 0.53.0 → 0.53.1 |
| 4 | ui-ux | `/ui-ux:build` names five defaults to leave out when no decided lines arrive | 0.26.0 → 0.26.1 |

## What this review did NOT check

- No plugin was run against Opus 5.5. Every finding is a read of the post against the
  tree. The four fixes are documentation edits; none is measured.
- The `Workflow` `effort` contradiction above was noticed, not resolved.
- Only the September 22 post was read. Its related-posts list names a July 24 piece on
  context engineering already cited by `model-tier-scoping.md`; nothing newer was checked.
