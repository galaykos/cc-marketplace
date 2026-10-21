# Session retro 2026-10-21: how this repo's own last sessions went

**Scope.** This repo's main-thread transcripts since the 10-13 retro, read in full by nine
`hindsight:transcript-miner` agents over line-numbered text extracts (tool output clipped to
~1.3k chars, Edit/Write bodies to 3k):

| key | session | dates | ask |
|---|---|---|---|
| S1 | `479f845f` | 10-13 → 10-15 | retro of other projects → Tier 0–2 fixes → CLI 2.1.300 alignment |
| S2 | `f5492e65` | 10-16 | "do we cover all aspects of web development?" |
| S3 | `25f72aab` | 10-18 | per-project plugin install instead of user scope |
| S4/S5 | `14ff53c9`, `cde7030f` | 10-13, 10-15 | "why doesn't git pull work?" |

**Not read:** the 100 subagent transcripts (96 under S1, 4 under S2); only their dispatch
prompts and hand-backs as the main thread saw them. 27 miner claims used here were re-checked
against the extracts. 23 held verbatim and 1 was paraphrased with the same meaning. 3 were
cited at the wrong line or overstated; they were corrected or dropped (one "CONFIRMED"
overclaim, S1 L4028, did not survive). Verbatim miner reports,
the extractor and the comment counter are in the gitignored
`taskmaster-docs/session-retro-2026-10-21/`. **Standing: `recorded`.**

## Measured, not estimated

| | S1 | S2 | S3 |
|---|---|---|---|
| Agent dispatches | 90 (72 set to opus) | 4 | 0 |
| Skill tool calls | 9, all `code-review` | 0 | 0 |
| AskUserQuestion | 1 | 0 | 2 |
| Commits / diff | 46 / +13,754 −1,595 in 368 files | 1 / +207 (unpushed) | 1 / +550 −70 |
| Whole-range review rounds | 4 (14 → 36 → 40 → 17 findings) | 0 | 0 |
| Model chat text | 20,533 words | 749 | 1,274 |
| End state | merged by the user by hand | branch never pushed | PR #213 still open |

Added shell lines in S1 are 23% comments, the same as the repo's existing shell (24%).
`scripts/lib/plugin-checks.sh` additions are 46% comments (162/355). S3's `sync-plan.sh`
opens with a 50-line header (code starts at line 51 of 153).

## Findings

**Too much**
1. **Review → fix → review loops.** In S1, every fix wave shipped new bugs that the next round
   caught. Tier 2 was called done, and the next review "found 40 issues, four high" (L4199). The
   2.1.300 work passed every gate, then a new `rm -rf \` rule hard-denied ordinary commands.
   The model said itself: "Another round would be the fourth pass" (S1 L4405). 90 dispatches
   and 46 commits came from an ask that began "review the sessions … we need a plan 1st".
2. **Prose.** Commit bodies ran 20–30 lines (S1 L3794, L4277, L5368). The same crew table
   was posted three times (S1 L1327, L1454, L1502). The rationale status block was rewritten
   after every wave. Chat replies after each hand-back ran 25–35 lines. The Concise style
   was active throughout.
3. **Comments, by house style, not by lapse.** Sessions match the repo's own density. The
   volume comes from CLAUDE.md's rule that each check carries "what it catches, what it does
   not, and what shipped that made it exist". That conflicts with `comment-discipline`'s
   "the default is none". Change-narration comments still slipped in (S1 L921, L1908).
4. **New gates with false positives.** `pc_agent_tool_fit`, `pc_gating_catch` and
   `pc_plugin_root_quoting` landed (the last promoted to FAIL). The review found that "the
   new agent tool-fit lint has false positives" (S1 L1967).

**Not enough**
5. **The last step is handed back.** "PR+Merge" was asked twice and merged by the model zero
   times: auto-mode denied `gh pr merge` (S1 L4440, L4463; S3 L926). User: "You have access to
   gh, just merge man" (S1 L4452). PR #213 is still open, and S2's branch was never pushed.
6. **Skills are not loaded in the main thread.** S2 and S3 made zero Skill calls. S3 wrote a
   script and a 37-case harness, and ignored the `testing-best-practices` nudge (L846). S2
   "improved the prompt" by hand and launched without showing it (L153: "Rewritten prompt
   below. I'm running it now"). S1 delegated the skill reads to crews, which is defensible.
7. **Live proof is skipped.** S3 never ran `--sync` through the host, and said so (L712). S1:
   "the new hook event wasn't probed live". S2: "Nothing was run". Local node v20 cannot run
   the `.ts` harnesses (S3 L667), so 7 harnesses were not run locally.
8. **Corrections don't persist.** `git pull` over SSH failed in four sessions (S4, S5, S1
   L6048–6221, S3 L940). There were two different diagnoses (port 22 blocked vs QoS-marked
   packets dropped) and no durable fix. The memory dir is empty. The gh HTTPS credential
   helper is already configured.

**Wrong, or claimed past the evidence**
9. Subagent findings were relayed as confirmed:
   - The K2 premise was called "Confirmed" (S1 L4954); an executor later measured "The
     finding overstates the problem" (L5068).
   - A shard claim marked CONFIRMED was re-attributed after the doc was written (S2 L581).
   - "$6–10 of evals" (S2 L626) has no source.
10. **Our own hooks get dismissed.** The review-debt nudge was declined at least six times
    ("I'm not running another", S1 L4855; "skipping it", S3 L734). ask-ledger flagged "1st
    then" (S1 L33), and today flagged "summerizing", a negated, quoted, misspelled word in
    the user's prompt. skill-router's hand-back misfire is fixed since (frames skipped,
    `route-prompt.sh:96-98`).

**Worth keeping**
- S3's shape: one batched AskUserQuestion round with a Recommended pick, 0 agents, 1 commit,
  a mutation check on its own harness (L327), and a "Not tested" section.
- `check-version-bumps.sh` re-run after every commit (all three sessions).
- Narrow budget re-baselines instead of a blanket one (S1 L1064, S3 L610).
- Red-before/green-after required in every fix brief.
- No workaround after a classifier denial.
- S2 kept to the Admission law: no new plugins, a gap is only a gap if a control fails it.

## Enough or too much?

Both. **Too much** orchestration, review rounds, prose and new gates per ask: S1 is the
outlier, and it set the volume. **Too little** at the edges that decide whether work lands:
merging, pushing, live host proof, loading the matching skill, and remembering a correction.
S3 is the right default size. S1's size should need the user to ask for it explicitly.

## Draft plan (pick before any edit)

| # | change | improves |
|---|---|---|
| P1 | allow `gh pr merge` in user settings; memory: "PR+Merge" is the authorization | workflow (machine) |
| P2 | `origin` → HTTPS via the existing gh credential helper; memory note | workflow (machine) |
| P3 | `.nvmrc` pinning CI's node 24 so local `.ts` harnesses run | gates |
| P4 | ask-ledger: skip quoted terms inside a negation ("no X", "not X") | `ask-ledger` |
| P5 | review-debt: after a whole-range review whose fixes went red-before/green-after, nudge once, not after every fix commit | `code-review` |
| P6 | fix S2's three `toolchain-experts` defects (absent `strict` read as off though TS 6 defaults it on; `.eslintrc*` read as live though ESLint 10 removed it; TS 7's missing compiler API unchecked); push or drop S2's branch | `toolchain-experts` |
| P7 | feedback memory: commit body ≤5 lines, hand-back replies ≤5 lines, one status block per task | working style |
| P8 | feedback memory: "CONFIRMED" only when reproduced in this session; relayed numbers say so | working style |
| P9 | CLAUDE.md line: load the matching `authoring-*` project skill before editing a hook, skill, agent or command | repo rule |
| P10 | decide check headers: keep derivations inline, or ≤3-line header + `rationale/` pointer | `comment-discipline` vs CLAUDE.md |
