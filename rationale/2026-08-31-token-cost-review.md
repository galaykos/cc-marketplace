# Where the money actually goes: a measured token-cost review, 2026-08-31

**Standing: `recorded`.** Nothing reads this file back. It is a measurement, not a
gate. Every number below is reproducible from the commands in the appendix.

Companion to `2026-08-31-efficiency-uplift.md`, written the same day. That doc
corrected **which channel** this repo measures. This one measures **what the
channel is worth in dollars**, against real spend, and reaches a conclusion the
uplift run could not: the marketplace's byte surface is not the reason the bill
is high, and no amount of further trimming will change that.

## Sample and its bounds — read this before quoting a number

- 22 transcript files under `~/.claude/projects/`, **15 of which carry usage
  records**; **2,974 model requests**; one machine; local history only.
- Two models in the sample: `claude-opus-4-8` (1,482 requests) and
  `claude-opus-5` (1,509). Both price at **$5/MTok in, $25/MTok out**.
- Cache multipliers: read **0.1x**, 1-hour write **2x**, 5-minute write 1.25x.
  Source: the `claude-api` skill's `shared/prompt-caching.md:142`, cached
  2026-06-24. Measured here: **100% of cache writes were 1-hour TTL**
  (`ephemeral_1h_input_tokens` 11.99M, `ephemeral_5m_input_tokens` 0). A review
  that assumed the 1.25x default would have under-stated the write channel by 60%.
- Plugin attribution uses `attributionPlugin` carried forward to the next
  attribution-bearing record. It **over-attributes** — a plugin gets charged for
  turns after its skill stopped being the active thing. Treat the per-plugin
  table as an upper bound.
- `~/.claude/hindsight/*/skills.jsonl` and `~/.claude/skill-router/*/surfaced.jsonl`
  are **empty on this machine**, so the ledgers `retirement-queue.sh` reads have
  nothing in them. Utilization below comes from transcript attribution instead.
- The ~15,000-char skill-listing cap is a **documented default**, not measured on
  this account. Same caveat the uplift doc records.

## The headline

**$536.20 of measured spend across 2,974 requests.** Decomposed:

| channel | raw tokens | multiplier | $ | share |
|---|---|---|---|---|
| cache **read** | 662.99M | 0.1x | **$331.50** | **61.8%** |
| cache **write** (1h) | 11.99M | 2x | $118.05 | 22.0% |
| **output** | 3.37M | 5x | $84.21 | 15.7% |
| fresh input | 0.49M | 1x | $2.44 | 0.5% |

**Nearly two-thirds of the bill is re-reading context that was already sent.**
Not generating, not thinking — re-reading. Median context per request is
**181,927 tokens**; mean 226,855; p90 478,086; max 934,124.

Cost per request is **$0.180 on average and remarkably flat** — $0.127 to $0.220
across every plugin bucket, including the no-plugin baseline at $0.201. That
flatness is the finding: **spend tracks how long a session runs and how big its
context is, not which plugin is loaded.**

## The cost model this repo does not have

A token's price is its size times *where it sits*, and there are only two places:

**The system-prompt prefix** — skill/command/agent `description:` values,
`CLAUDE.md`, SessionStart hook stdout. Written once at 2x, then read at 0.1x on
**every** request of the session, and **it survives compaction**. Effective
multiplier over a 200-request session: `2 + 199x0.1` = **~21.9x**.

**The conversation body** — skill bodies, `references/`, hook injections, tool
results. Written once at 2x, read at 0.1x until the next auto-compaction.
Measured here: **28 compactions across 15 sessions, every one a ~50% drop, median
39 requests apart** (min 3, mean 74, max 269). Effective multiplier ≈
`2 + 39x0.1` = **~5.9x**.

**So a byte in the prefix costs ~3.7x a byte in the conversation.**
`context-budget.sh` meters the prefix. **It is metering the right channel, and
the uplift doc's defence of it was correct** — but for a reason neither document
states: not because always-on is "what every session pays", but because the
prefix is the only surface compaction cannot evict.

I came into this review believing the opposite — that bodies (202k tokens) and
`references/` (184k tokens) dwarf descriptions (47k chars) and are therefore the
real cost. That framing compares corpus bytes and is wrong. Corrected: a skill
body loads only when invoked, gets halved every ~39 requests, and costs
**~$0.05 per invocation** at 1,741 tokens average. There is no case for a body
budget on cost grounds.

## What the always-on surface is actually worth

Per session (198 requests, the measured median), at Opus rates:

| item | tokens | $/session | share of the $35.75 session |
|---|---|---|---|
| this repo's `CLAUDE.md` | 6,357 | **$0.70** | 2.0% |
| `everything` skill listing, **as charged** (capped) | ~3,750 | $0.41 | 1.1% |
| `craft-suite` listing (8,318 chars) | 2,080 | $0.23 | 0.6% |
| `always-on-suite` listing (6,221 chars) | 1,555 | $0.17 | 0.5% |
| one skill body invocation | 1,741 | $0.05 | 0.1% |

**This repo's own `CLAUDE.md` costs more per session than the entire 52-plugin
catalogue it governs.** It is 25,427 bytes, it is in the prefix, and it is
re-read on every one of a session's requests. It is not a plugin, so no channel
in `context-budget.sh` has ever seen it.

The whole always-on surface is **~1% of a session's cost.** The uplift run was
right to refuse to trade dispatch quality for it, and right that trimming buys
1.8–2.8%. The number that was missing is that 2.8% of 1% is **nothing** — 2.8% of
$0.41 is one cent per session.

## The reframe: over the listing cap, the tokens are free and the skill is broken

`everything` sums 43,936 chars of description; `taskmaster-suite` 29,100; the cap
is ~15,000. The host **drops** the overflow (observed live 2026-08-26,
`marketplace-necessity-review-2026-08-26.md:262-287`, nondeterministic at the
margin). Dropped text is not sent, so it is **not charged**.

Two consequences the uplift doc's listing channel implies but does not say:

1. **The always-on figure for those two installs is not a cost.** `everything`'s
   11,648-token entry is a catalogue weight; the charged prefix is pinned at the
   cap, the same as any install that reaches it. Trimming descriptions there
   saves **$0.00** until the total drops under 15,000 chars.
2. **What is lost is reachability, and it is nondeterministic.** `everything`
   ships 224 description-bearing artifacts. At the measured 196-char average, the
   cap holds about **76**. Roughly two-thirds of the bundle's skills cannot be
   dispatched on any given reload, and *which* two-thirds changes between reloads.

That is a correctness defect wearing a cost defect's clothes.

## Utilization: 6 plugins of 63, 15 skills of 116

Every skill that ever fired in the sample:

| plugin | skills fired | $ attributed (upper bound) | share |
|---|---|---|---|
| task-runner | task-execution, run | $102.00 | 19.0% |
| taskmaster | task-cards, brainstorm, task, spec-redteam, grill, coverage-check, taskmaster | $25.64 | 4.8% |
| ui-ux | build, aceternity-best-practices | $16.88 | 3.1% |
| stack-scan | installed-versions | $4.59 | 0.9% |
| code-architecture | plan-before-code, plan | $2.04 | 0.4% |
| *(caveman — a different marketplace)* | caveman | $81.82 | 15.3% |

**58 of 63 marketplace plugins and 102 of 116 skills never fired once.** On this machine, in
this history. That is not proof they are dead — most are stack-specific and this
sample has no Vue or Three.js work in it — but it does mean the corpus this repo
gates, ratchets and budgets is, empirically, ~13% exercised.

## The lever nothing here measures: turns

`task-runner` contexts: **464 requests at $0.220 each = $102.00, 19% of all
measured spend.** Its entire shipped surface is 11,071 tokens of bodies, 14,175
of references, 1,501 chars of description. Even if every byte of it loaded into
the prefix of every session, it would cost ~$2.80 a session. It is charged $102.

**The ratio between what a plugin ships and what its workflow costs is ~40:1 for
the most-used plugin in this marketplace.** A workflow that turns a 20-turn task
into a 200-turn task costs 10x, and 10x of $0.18/request swamps every byte
decision in this repo combined.

Nothing in `scripts/` measures turns per completed task. Three context-budget
baselines, a crowding ratchet, a 200-line body cap, a description linter, and a
listing channel all meter the ~1% surface. The 99% has no instrument at all.

To be explicit about what this does **not** say: a plugin that induces 400 turns
may be worth it. `task-runner` may be buying 400 turns of work that would
otherwise be 400 turns of the user's own prompting. **This review measures cost,
not value**, and this repo has no control arm for value —
`eval-ablation-2026-08-20.md` measured zero delta in every arm. That is precisely
why cost-per-completed-task is the number worth building, and why "fewer turns"
is not automatically an improvement.

## Ranked levers, by measured dollars

**1. Context length. 61.8% of spend, and the only lever of this size.**
Median 182k, p90 478k. Compaction fires every ~39 requests and halves it, so it
is already working — the p90 says it fires late. Halving median context halves the cache-read
channel, worth roughly **−31% of total spend**. The levers are session hygiene (`/clear` between
unrelated tasks), narrower tool output, and not reading whole files. **None of
them is a plugin change**, and that is the most important sentence in this
document.

**2. Turns per completed task. Unmeasured, ~19% attributable to one plugin.**
Build the instrument before tuning anything. Proposal in the next section.

**3. Output tokens. 15.7% at a 5x multiplier.** 1,133 tokens per response
average. `terse` is the only plugin in this marketplace that attacks a top-three
cost term, and its activated cost is 1,891 tokens of prefix, or **$0.21/session**. At
$25/MTok that is repaid by cutting **~8,200 output tokens per session** — 3.7% of
the 224,000 a median session generates. Plausible; unmeasured here.

**4. The always-on prefix. ~1% of session spend, correctly metered, already
optimized.** Recommend: stop working on it.

**5. Skill bodies and `references/`. ~0.1% per invocation.** Recommend: no gate,
no budget, no trimming pass. `craft-layer` already does the right thing anyway —
ref:body ratio 3.3 with genuinely conditional loads (`asset-sourcing/SKILL.md:44`
routes to `references/animated-modals.md` only for a modal). Two plugins carry
fat bodies with no offload — `code-architecture` (1,988 tok/skill, ref:body 0.38)
and `resilience` (1,733, 0.00) — worth about two cents per invocation. Not a
branch.

## Recommendations, in the order I would do them

**R1 — Delete `everything`, or cut it to ~70 artifacts.** It ships 224
description-bearing artifacts into a ~72-artifact budget. It cannot dispatch
two-thirds of what it advertises, and which third works is nondeterministic
across reloads. Trimming descriptions cannot fix it (1.8% measured) and would not
save money if it could. `taskmaster-suite` at 156 artifacts has the same defect at
1.9x and the same fix: **fewer members**. This is the open owner decision the
uplift doc left, and my answer is: the reachability argument makes it a defect,
not a preference. Cost is not the reason to act; a bundle that silently drops
two-thirds of itself is.

**R2 — Cut this repo's `CLAUDE.md`.** 25,427 bytes, ~$0.70/session, the single
largest controllable item in the prefix, larger than the whole plugin catalogue.
Most of its length is recount narrative and correction history — genuinely
valuable, and it belongs in `rationale/` where it is read on demand. Leave the
four gates, the doc-location rule, the lane schema, and pointers. Target ~8,000
bytes. Nothing gates this file's size today.

**R3 — Build the turns instrument, then stop building byte instruments.**
Minimum viable: a `SessionEnd` reader over the transcript that records requests,
cumulative context, and `attributionSkill` spans per session, so a plugin can be
scored on **cost per completed task**. Everything needed is already in
`~/.claude/projects/*/*.jsonl`; this review is a one-off version of it. Standing
would be `recorded` — it informs, it cannot gate, because a high-turn plugin may
be earning its turns.

**R4 — Add one line to `context-budget.sh`'s listing channel**: above the cap,
the overflow is dropped and therefore *not charged*, so an OVER status is a
reachability warning and never a cost warning. The channel currently reports a
number that reads like a bill.

**R5 — Session hygiene, for the user rather than the repo.** p90 context of
478k and sessions reaching 934k against a 1M window mean long-lived sessions are
carrying work they finished hours ago. Compaction is halving them every ~39
requests and they still climb. `/clear` between unrelated tasks is worth more
than every optimization in this repo's history put together.

## What I got wrong on the way here, since the method is the point

Two hypotheses died on measurement before the ones above survived:

- **"Hooks re-inject their catalogue on every prompt, so dynamic cost compounds."**
  False. `route-prompt.sh:116-120` claims a once-per-session marker and
  `route.sh:28-55` dedups per skill. The 2,731-token dynamic channel is
  essentially once-per-session. (One real observation in passing, filed as a
  correctness note and not a cost one: the catalogue marker at
  `route-prompt.sh:118` keys on raw `.session_id` while the flush block at `:46`
  keys on `.transcript_path // .session_id`. That is the exact split
  `pc_context_key` exists to catch, but that gate scans only
  `.hooks.PostToolUse` and this is `UserPromptSubmit`, so it is out of scope. The
  effect is a subagent being deduped against a catalogue it never received —
  cheaper, and wrong.)

- **"Bodies are 202k tokens and descriptions 47k chars, so the repo meters the
  small channel."** False, and it compares the wrong quantity. Prefix bytes carry
  a ~21.9x session multiplier against a body's ~5.9x, and bodies load
  conditionally. The repo meters the right channel. It just meters a channel
  worth ~1%.

Both were plausible, both were checkable in two greps, and both would have
produced a confident wrong recommendation. The uplift doc's four killed proposals
plus these two makes six in one day — which is the argument for measuring before
proposing, stated with evidence rather than as advice.

## Appendix — reproduce every number

```bash
# spend decomposition, compaction interval, context distribution, attribution
# (all read ~/.claude/projects/*/*.jsonl; see git history of this branch)
python3 -c "import json,glob,os,collections;..."   # full scripts in the review session

# corpus sizes
find plugins -name SKILL.md | xargs wc -c | tail -1          # bodies
find plugins -path '*/references/*' -name '*.md' | xargs wc -c | tail -1
wc -c CLAUDE.md
bash scripts/context-budget.sh                                # all three channels + listing
```
