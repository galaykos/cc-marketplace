# Marketplace efficiency uplift, 2026-08-31

**Standing: `recorded`.** Nothing reads this file back. The changes it describes
are enforced by the gates named against each; this document explains why they
were made and — more usefully — which four proposals were killed on evidence,
and why the largest one could not be executed at all.

## What this was

One `ultra-task` run: correct how this marketplace measures its own cost, reduce
what the corrected measurement reveals, give the task-card pipeline the
observable gate it admits it lacks, and run one uniform prose pass across all
plugins.

The run's own first plan was wrong, and the useful part of this record is how it
was found to be wrong. A blind four-persona panel produced three structural
objections; three blind spec adversaries then returned **68 holes, 11 blockers**
against the frozen spec. Four proposals died. The spec was rewritten before any
plugin was touched.

## The finding that reframes the rest

**This repo's headline efficiency metric measures a channel the host truncates.**

`plugin_desc_bytes()` (`scripts/context-budget.sh:70-82`) sums frontmatter
`description:` values across `skills/*/SKILL.md`, `commands/*.md` and
`agents/*.md`. That is the always-on figure. Two consequences follow, and
neither was written down anywhere before this run:

1. **Skill bodies and `references/` are not in it.** They load on invocation.
   Moving prose from a body into a reference file — which was this run's own
   first plan — relocates cost between two unmetered channels and cannot lower
   the always-on figure by one token. The script says so at `:665`;
   `plugin-checks.sh:54-56` says so again. The plan was drafted anyway.

2. **The host does not load all of it.** Claude Code allocates a budget for the
   skill listing and drops descriptions past it, least-invoked-first, names
   surviving. The eviction was observed live on 2026-08-26
   (`marketplace-necessity-review-2026-08-26.md:262-287`): ~31 marketplace
   descriptions arrived stripped, and the stripped set was nondeterministic at
   the margin across identical reloads.

Measured against a ~15,000-char documented default, only **two of 63 installs**
exceed the listing budget:

| install | listing chars | vs cap |
|---|---|---|
| `everything` | 44,689 | 3.0x |
| `taskmaster-suite` | 29,699 | 2.0x |
| `craft-suite` (largest under) | 10,592 | under |

Every other install loses nothing to eviction. So "reduce always-on tokens" is
the wrong goal for 61 of 63 installs, and for the two over the cap the currency
is not tokens — it is **which skills remain triggerable**. A stripped
description is a skill that can no longer be reached.

`scripts/context-budget.sh` now reports this as a report-only `listing:` channel.
It counts description text only: a SessionStart hook's stdout and an MCP
`tools/list` are always-on but are *not* part of the skill listing, so they are
eviction-proof and excluded. That distinction is the channel's whole point.

## The second finding: the deletion lever is void, not spent

The run was authorized to delete skills on evidence, using "no reachability
mechanism" as the bar. Applied honestly, **zero skills qualify** — including the
two this run first proposed.

A skill's `description:` **is** its dispatch channel. That is how 89 of the 116
shipped skills are reached at all. `plugins/skill-router/rules.tsv:70-74` records
the missing routing rows as deliberate — "their triggers are prompt-shaped, not
file-shaped" — and `rationale/host-lever-probes-2026-08-21.md:75-84` names
craft-layer directly: "Removing the description removes the only channel each of
those has." So "unrouted" is evidence of nothing.

Under a corrected bar — no inbound reference *and* no declared trigger —
`candor:straight-talk` carries a `definite_trigger` at `plugins/candor/lane.tsv:8`
and `git-workflow:review-exchange` is named in five shipped files. Deleting them
would also have cost more than it looked: `pc_lanes_resolve` fails on the
orphaned lane row, and `pc_removed_refs` is a hardcoded denylist
(`plugin-checks.sh:344,363`) that stays green after a deletion regardless — so the
success criterion asserting it would have been vacuous.

One genuine deletion survived: `plugins/brain/ROADMAP.md`, 93 lines of maintainer
planning shipped to every installer with a pointer into gitignored
`taskmaster-docs/`, flagged at `distillation-strategy-2026-08-20.md:427-428` and
never actioned.

## Killed on evidence

| Proposal | Died on |
|---|---|
| Rehome skill bodies into `references/` to cut always-on cost | Neither is in the always-on meter. Relocation between two unmetered channels. |
| Merge craft-layer's 7 motion skills | Already refuted at `distillation-2026-08-23.md:213` — "each carries a distinct engine contract" — *inside the line range the draft cited as its list of dead levers*. Independently: 698 non-empty body lines against a 200-line cap; `motion-tiers/SKILL.md:41` declares a `SOURCE OF TRUTH` marker `pc_source_of_truth` would fail on merge; six `references/` pointers would dangle. And merging six descriptions away deletes six live dispatch channels. |
| Treat "1 of 13 craft-layer skills routed" as evidence of dead weight | Backwards — the absence is deliberate and documented. |
| Move skill-router's routing from PostToolUse to PreToolUse | PostToolUse is the only hook channel reaching subagents (`route.sh:23-27`); `route.sh:165-181` reads the target file off disk, which does not exist pre-`Write`; no PreToolUse hook here emits `additionalContext` — all seven use `permissionDecision`; and `scripts/smoke/route-marker-tests.sh:145` asserts the event name. |

## Landed

| Change | Standing | Evidence |
|---|---|---|
| `context-budget.sh` listing channel, report-only | recorded | 2 installs flagged OVER; exit 0 |
| Per-tool probe drives five file shapes with guard-tripping content | gate (it is the metered channel) | `testing` 0 → 127 tok; dynamic total 2,501 → 2,731, honest, under the 2,900 ceiling |
| Sandbox separation (`EDIT_SANDBOX`) | gate | First attempt put fixtures in `HOOK_SANDBOX` and moved the always-on figure +36 tok on four bundles — pure contamination, caught and fixed |
| Card-lint run records + observer hook | gate | Keys on `transcript_path`, cksum-hashed before it becomes a path, `timeout=10`, warns rather than blocks; harness exercises both branches |
| Dead `spec §` citations purged from 5 shipped `remind.sh` | recorded | 0 remain anywhere in `plugins/`; fixed at the template + block, regenerated |
| `brain/ROADMAP.md` deleted | recorded | file and README reference gone |
| Two stale cost docs recounted | recorded | 61 → 52 leaves, 12,468 → 11,585 tokens, 48% → **51.1%** top-10 share |
| Meta-prose compressed across shipped skills | recorded | see the run report for the final corpus figure |

## Not done, and why — the part worth keeping

**Reducing `taskmaster-suite` below the listing cap is not reachable by trimming
descriptions, and the measurement is unambiguous.** The suite holds 29,100 chars
across **156 description-bearing files** in 32 member plugins. Only **seven**
exceed 300 chars, holding 2,611 chars between them. Cutting all seven to exactly
300 saves **511 chars — 1.8%**. Getting under the cap needs ~14,000 chars
removed, i.e. ~90 chars from every one of the 156 descriptions.

That is the refuted lever exactly: `distillation-2026-08-23.md:206-214` measured
description-trimming at 2.8% catalogue-wide; this suite measures 1.8%. And it is
the trade `context-budget.sh`'s own `ALWAYS_ON_CEILING` comment already rejects —
degrading dispatch quality across the catalogue to buy a fraction of a budget.

**The only route under the cap is fewer artifacts in the bundle, not shorter
descriptions.** Cost is artifact-count-driven; that is the same fact that refuted
the trimming lever in the first place. Reducing `taskmaster-suite`'s 32
dependencies is a product decision for the owner, not a fix branch's call. It is
the one open decision this run leaves.

Two smaller honest negatives, both recorded in `.claude/task-runner/reductions/`
rather than quietly dropped:

- **The per-edit probe's blind spot was misdiagnosed.** The premise was that six
  of nine per-edit hooks read 0 because of path shape. Measured: path shape
  explains **one** (`testing`). `task-runner` was already covered by the script's
  pre-existing Bash-matcher note. The remaining four are gated on session state
  the probe does not create, or on content narrower than a generic fixture.
  Widening the fixture until every guard trips would measure a worst case no real
  edit reaches. The corrected diagnosis is now in the script's closing notes.
- **The reminder-hook stdout trim was rejected on measurement.** The template
  emits one line. The messages are 144–228 B of per-plugin directive; trimming
  them buys ~50 B each at the cost of the nudge's specificity.

## What this run could not measure

**No claim is made that anything here improves model behaviour.** No control arm
exists, `claude plugin eval` is account-gated, and this repo's one real ablation
(`eval-ablation-2026-08-20.md`) measured **zero delta in every arm**. The
card-lint observer is asserted to be *enforceable*; it is not measured to be
*effective*. The distinction is the whole reason this section exists.

Also unmeasured, and stated rather than assumed:

- The ~15,000-char listing cap is a **documented default**, not a constant
  measured on this account, and it is configurable in `settings.json`. The
  listing channel names a risk; it never fails a build.
- `plugin.json` descriptions — 25,815 chars — are outside `plugin_desc_bytes()`.
  Whether the host charges for them is unverified. Not counted as a saving.
- Whether the card-lint observer changes whether anyone runs the linters. It
  records; nothing yet reads the records back except the observer itself.

## Residual: moving one gate's coverage

`pc_context_key` scans only `.hooks.PostToolUse`. The new observer is a
PostToolUse hook, so it is in scope — but that is luck, not design, and any later
move off that event would silently drop it out of the gate's view.
