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
- **Attribution is missing from half the sample.** `attributionSkill`/`attributionPlugin`
  records appear on CC **2.1.202** (574 recs / 853 requests), **2.1.217** (263 / 630)
  and **2.1.251** (9 / 73) — but **2.1.222 emits none at all across 1,444 requests
  and 9 sessions**, 48.6% of the sample. Every utilization figure below is therefore
  a **lower bound on what fired**, and the unattributed $303 bucket is mostly that
  version rather than genuinely plugin-free work. Do not use these counts to justify
  a deletion.
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

**So a byte in the prefix costs several times what a byte in the conversation
costs** — call it order-of-magnitude 3-4x rather than a constant, since 5.9x
assumes a body loads right after a compaction (median load position gives ~4x)
and summarized content partly survives.
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
in `context-budget.sh` has ever seen it. In aggregate across the whole sample it
is still only ~$3.20 (0.6%, R2) — which is the point of this table, not an
exception to it: **nothing in the prefix is worth much.**

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

1. **The always-on figure for those two installs is almost entirely not a cost.**
   `everything`'s 11,648-token entry is a catalogue weight; the charged
   description text is pinned at the cap. Not *exactly* zero: eviction drops
   description bodies with **names surviving**, so an over-cap install still pays
   for every artifact's name and owning plugin — `everything` carries 224 of those
   against a 76-artifact install's 76. That residue is tens of tokens per artifact,
   not hundreds. Trimming description *text* above the cap saves approximately
   nothing until the total drops under 15,000 chars.
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

**58 of 63 marketplace plugins and 102 of 116 skills show no recorded invocation.**
That is a floor, not a count: 48.6% of the sample runs a CC version that emits no
attribution at all (see bounds), most of these plugins are stack-specific and this
history has no Vue or Three.js work in it. What survives the caveat is the shape,
not the number — a small, stable core of workflow plugins carries the observable
traffic, and the corpus this repo gates, ratchets and budgets is exercised far
more narrowly than it is measured. **This is not evidence for deleting anything**;
the uplift run already established that the deletion lever is void on evidence.

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

**R1 — Delete `everything`, or cut it to ~70 artifacts.** **Done 2026-08-31:
removed** (marketplace 0.94.0). Two things the recommendation had not accounted
for, both found while executing it:

- **Deleting the bundle would have deleted a gate.** `validate.sh`'s README
  leaf-count check lived inside `if [ -f "$EV" ]`, keyed on the bundle's
  `plugin.json`. Removing the bundle would have made that check vanish silently
  — a passing build with one fewer check in it. It was rehomed first, and now
  runs unconditionally. *Removing an artifact can remove a gate riding on it,
  and nothing warns you.* That generalises past this removal.
- **The README's cap figure was wrong**, and it was the number that justified
  this recommendation. It read "~2k tokens at 200k, ~10k at 1M"; this repo's own
  live observation recorded ~19,949 chars stripped **at 1M**
  (`marketplace-necessity-review-2026-08-26.md`), consistent with a ~15,000-char
  absolute default binding before the 1% fraction. Corrected at the generator.

Also corrected: this section said `everything` cannot dispatch "two-thirds" of
what it advertises. At 224 artifacts against ~76 that fit, it is **about three
quarters**. And a stripped skill is name-only, not absent — autonomous dispatch
is what dies, since the description is the channel; an informed user naming the
skill explicitly can still reach it.

What is genuinely lost, stated rather than buried: nothing now asserts that a new
leaf plugin joins *any* bundle. The old failure mode (an aggregate install
silently omitting a leaf) is retired rather than unguarded, but a leaf that
belongs in a themed suite and is left out is now a WARN nobody writes.

The original recommendation, for the record: It ships 224
description-bearing artifacts into a ~72-artifact budget. It cannot dispatch
two-thirds of what it advertises, and which third works is nondeterministic
across reloads. Trimming descriptions cannot fix it (1.8% measured) and would not
save money if it could. `taskmaster-suite` at 156 artifacts has the same defect at
1.9x and the same fix: **fewer members**. This is the open owner decision the
uplift doc left, and my answer is: the reachability argument makes it a defect,
not a preference. Cost is not the reason to act; a bundle that silently drops
two-thirds of itself is.

**R2 — `CLAUDE.md` is an unmetered prefix item in every repo, and this one is the
worst offender.** **Done 2026-08-31: 25,427 → 18,971 bytes (−25%).** Not by
hitting the ~8,000-byte target this section originally named — that number was
invented here with nothing measuring it, and cutting to reach it would have
deleted operative text. The cut applied this repo's own rule instead: every `pc_*`
check carries 9–29 lines of its own header, so the gate section restated
arguments that already had a home, and one copy had drifted (it described
`pc_budget_crowding`'s ceiling as 150 lines four days after it moved to 200).
Counts were replaced by the command that recomputes them, which removes the
staleness class rather than resetting it — except the CI step count, which
`scripts/done-gate.sh:7` deliberately sole-carries here. Every rule, limit and
blessing marker survives; verified by grep, not by eye.

 It is the largest single controllable item in the prefix and no
channel has ever seen it. Sized across the sample:

| repo | `CLAUDE.md` | requests | cache-read cost in sample |
|---|---|---|---|
| cc-marketplace | **25,427 B** (~6,357 tok) | 81 | $0.26 |
| dominium (+2 worktrees) | 11,011 B | 1,055 | $1.45 |
| lynx-market | 11,069 B | 475 | $0.66 |
| link-catalyst (+worktree) | 11,011 B | 373 | $0.51 |
| traffic-hub-app | 11,011 B | 236 | $0.32 |

**Aggregate ≈ $3.20 of $536.20 — 0.6%.** Per *session* it is the biggest prefix
line item (~$0.70 in a 198-request session at cc-marketplace's size, ~$0.13 in
the 40-request sessions this repo actually runs), and in aggregate it is still
under one percent. Both facts are true and the second one is the one that should
govern effort.

Do it because it is cheap and safe, not because it is large. **Verified safe:**
`grep -rn "CLAUDE.md" scripts/ .github/ templates/` returns only prose citations
plus three smoke harnesses that copy the file into a mirror fixture with
`[ -f ] && cp` — permissive, no content assertion. Cutting it does not break CI.
Target ~8,000 bytes: keep the four gates, the doc-location rule, the lane schema
and the tier table; move the recount narratives and correction history to
`rationale/`, where they are read on demand at conversation rates rather than
prefix rates. The 11 KB work-repo files are the same lever with 3x the aggregate
and someone else's judgement to apply.

**R3 — Build the turns instrument, then stop building byte instruments.**
**Done: `scripts/turn-cost.sh`** (maintainer path, always exits 0). It reads
`~/.claude/projects/*/*.jsonl` and reports **turn blocks** — one real human
instruction and every model request that followed it before the next one. That is
the closest thing a transcript can witness to "cost per completed task";
completion is not recorded anywhere, so it measures cost per *instruction* and
says so. Built as an on-demand script rather than the `SessionEnd` hook this
paragraph originally proposed, for two reasons: a hook would charge every session
to measure cost, and it could only ever see forward, while the script scores the
whole existing history retroactively.

First run over this sample: **median 24 model requests per human instruction**,
mean 53, p90 119, max 491; median $3.98 per instruction, max $111.64. And it
refuses to score a single marketplace plugin — every one has fewer than 10 turn
blocks (task-runner 7, taskmaster 6, ui-ux 5, stack-scan 1, code-architecture 1),
so the ratios are withheld by default. **That refusal is the instrument working.**
The honest state of this question is "not enough sessions yet", and a table that
had produced a confident ranking from n=1 would have been the noise-wearing-a-table
failure `retirement-queue.sh`'s header warns about.

Its own biggest hole, printed on every run: **subagent turns are invisible** —
zero `isSidechain` records exist in any transcript here, and subagent requests are
billed. It under-counts precisely the orchestration-heavy plugins it was built to
look at.

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
