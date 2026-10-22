# Session retro 2026-10-21: how this repo's own last sessions went

**Scope.** This repo's main-thread transcripts since the 10-13 retro, in three passes of
`hindsight:transcript-miner` agents over line-numbered text extracts. Pass 1 (9 miners)
clipped tool output to ~1.3k chars, and clipped every subagent report to 600 chars — an
extractor bug of this retro's own, found by pass 2. Pass 2 (13 miners) read the
transcripts with tool output unclipped. Pass 3 (5 miners) read all 92 subagent reports in
full (666 KB), each beside what the main thread then told the user.

| key | session | dates | ask |
|---|---|---|---|
| S1 | `479f845f` | 10-13 → 10-15 | retro of other projects → Tier 0–2 fixes → CLI 2.1.300 alignment |
| S2 | `f5492e65` | 10-16 | "do we cover all aspects of web development?" |
| S3 | `25f72aab` | 10-18 | per-project plugin install instead of user scope |
| S4/S5 | `14ff53c9`, `cde7030f` | 10-13, 10-15 | "why doesn't git pull work?" |

**Not read:** the internals of the 100 subagent transcripts (96 under S1, 4 under S2).
Their final reports were read in full, so what each one RETURNED is covered; how it
worked inside is not. The owner chose this.

**Checks:**
- 27 pass-1 claims were re-checked against the extracts. 23 held verbatim and 1 was
  paraphrased with the same meaning. 3 were cited at the wrong line or overstated; they were
  corrected or dropped (one "CONFIRMED" overclaim, S1 L4028, did not survive).
- 17 pass-3 relay quotes were re-grepped. All 17 held, one in bullet form rather than inline.

Verbatim miner reports (all three passes), the extractors and the counters are in the
gitignored `taskmaster-docs/session-retro-2026-10-21/`. **Standing: `recorded`.**

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
1. **Waves too big to land clean.** S1 ran four whole-range reviews (14 → 36 → 40 → 17
   findings). Each round reviewed mostly NEW work (wave 2+3, then Tier 2, then the 2.1.300
   changes), and each found real highs. Tier 2 was called done, and the review then "found 40
   issues, four high" (L4199). The 2.1.300 work passed every gate, and the review then found a
   new `rm -rf \` rule that hard-denied ordinary commands. The reviews earned their cost; the
   problem is the volume per wave: 8 Opus crews at once (L3295). The last fix commit of each PR
   merged unreviewed: "Another round would be the fourth pass" (L4405), and `90838823`
   (L6045). 90 dispatches and 46 commits came from an ask that began "review the sessions …
   we need a plan 1st".
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

**The owner's observation, tested (passes 2–3): confirmed on all four counts, with
counter-evidence**

11. **Deciding alone instead of asking.** In S1 the model listed three "Decisions for you",
    with "nothing launches until you decide" (L97). The user's reply answered none of them,
    and L105 said "Going with my recommended defaults:", then 6 Opus agents launched. The
    review command's own fix/report-only question was skipped three times, at L1305, L2064
    and L4028: "the standing direction covers applying review fixes". The user gave the
    code.claude.com changelog URL; the raw GitHub file was used instead and not said
    (L4787). In S2, "improve this prompt before proceeding" got a prompt the user never saw
    (L153, L212). The agents launched before the prompt file existed, and the question was
    narrowed to stale facts and web-dev only, without saying so. In S3, the Recommended
    option for session-wide plugins went against the repo's own doctrine, which the model
    had just read (L75, L128). "Why we need stack-scan?" got no prose answer, only a
    re-ask with stack-scan as Recommended (L178). In this session, the taskmaster hook's
    clarifying round was neither run nor skipped with a reason.
    *Against:* S1 asked at L426, L758 and L4969; S3 asked twice.
12. **Big content read in part, and the part treated as the whole.**
    - S1, L135–145: a 35 KB output was read through a 2 KB preview plus `head`; "almost
      none were loaded" reached the user with no caveat.
    - S1, L1251–1281: a history pass looked at 5 commits in 3 files, then said "The history
      pass is clean".
    - S1, L698–758: 4 of 63 diffs were read, then "every check passes".
    - S2, L95 and L125: prior reviews were read in line ranges that skipped 150–474 and
      75–156.
    - S3, L73, L187 and L72: `flags.md`, `picker.md` and `--help` output were cut
      mid-sentence and never finished.
    - S3, L641: 4 of 7 failing harnesses were inspected, and all 7 were called
      "environmental".
    - This session: this retro's own extractor clipped 167 tool results and every subagent
      report, and `head -70` cut the most-used skills out of the usage table.
    *Against:* the 9,073-line changelog was split into five contiguous slices (S1 L4826).
13. **Reasons not to do something, unverified or false.**
    - S3 L1589: the review was skipped "because the only new logic is `sync-plan.sh` and
      its 37-case harness covers it". The diff also changed a hook, two command bodies, and
      what `--yes` installs.
    - S3 L1741: "most likely waiting for a key passphrase" was a network timeout.
    - S1 L5496: "a kit change across 14 copies is not worth it". The PR then said "17
      findings, all fixed" (L6032).
    - S1 L1662: a crew said "most of these agents have no Bash". A reviewer found 9 of 22
      do (L1994), and that finding never reached the user.
14. **Not saying what was not done: the relay is where it gets lost.**
    - S1: of 86 subagent reports, about 30 were relayed faithfully. About 56 lost a caveat,
      a NOT-DONE item or a residual on the way to the user, and about 27 were overstated.
      These counts are agent-graded and approximate.
    - Examples: "A2: NOT DONE (blocked, measured)" became "H4 is done" (L5180 → L5197).
      "D2 RESIDUAL-STATED" became "X5 is done: all eight findings are fixed" (L4033 →
      L4061). "about +5 ms per hook… outside what you asked me to keep within 2 ms" became
      "1–2 ms more per hook" (L2952 → L2961).
    - S2: 4 reports, 2 faithful. The backend agent's "only the first 100k chars of 219k were
      read" became "The Laravel and Inertia references are current" (L299 → L308).
15. **Self-reflection.** There were unprompted catches: a commit message redone, stale doc
    lines fixed, a polluted ledger cleaned, a mutation test run. But every design error in
    the model's own code was caught by a reviewer, and the HTTPS and workflow-scope reasons
    were explained only after the user asked. No case was found of an earlier claim being
    corrected once later evidence contradicted it. The L426 "confirmed against the original
    session input" stood after a crew showed the verifier's patch broke real input (L942).

**Worth keeping**
- S3's shape: one batched AskUserQuestion round with a Recommended pick, 0 agents, 1 commit,
  a mutation check on its own harness (L327), and a "Not tested" section.
- `check-version-bumps.sh` re-run after every commit (all three sessions).
- Narrow budget re-baselines instead of a blanket one (S1 L1064, S3 L610).
- Red-before/green-after required in every fix brief.
- No workaround after a classifier denial.
- S2 kept to the Admission law: no new plugins, a gap is only a gap if a control fails it.

## The plugins themselves (owner's lens: value, quality, behaviour, footprint)

**Method.** Every plugin was measured by script. The 16 the numbers flagged were then read
in full by 12 read-only agents against one shared brief (`plugin-readers/brief.md`, in the
evidence dir): the 8 that inject into sessions most or own today's failure modes, and 8
that are costly but unused. Every reader reported `Not read: none`. Ten of their
load-bearing code claims were re-read at the cited lines, and all ten held.

**Not read in full:** craft-layer, design-kit, ui-ux, stack-scan (open in PR #213), overseer,
command-guard, secret-scanning, testing, database, git-workflow, prompt-coach, laravel,
debugging, hindsight, ultra-deep-research, all-plugins and session-hud. They are measured
only, because they are used and not implicated, or not flagged by the numbers.

**Measured (30 days, 3 work projects plus this repo).**
- **Footprint:** all 32 plugins are enabled at user scope in every project. The work
  projects are all Laravel, Inertia, React and Tailwind.
- **Usage:** 56 of 107 skills had no use in the work projects, counting both Skill calls
  and SKILL.md/reference reads in main threads and subagents. The Skill-call attribution
  alone undercounts skills delivered by path: security-review shows 0 there but was read
  43 times.
- **Always-on cost:** 10,826 tokens across all descriptions.
- **Injected text:** 236 human prompts drew 864 plugin injections (835 attributed by prefix, 29 more from code-review and approaches). skill-router accounts
  for 408 of them (188k chars), and 67% of its surfacings went to skills never loaded.

| plugin | verdict | strongest evidence (reader file:line, re-read where marked ✓) |
|---|---|---|
| candor | FIX + SLIM | the Stop gate counts an Agent/Task dispatch as verification ✓`gate.sh:544`, so a worker's unrun "done" passes. Clause 2 passes on the WORD "re-checked" ✓`:499`. The citation resolver takes the first of many same-named files ✓`cite.sh:35` (it blocked a correct citation today). straight-talk and terse-output: 0 use |
| task-runner | FIX + SLIM | in donkeyquijote, 61 of 77 scope-lock warnings flag the run's own index ✓`scope.sh:86`. A red pytest suite is recorded `covered` ✓`behavioral-gate.sh:493`. delegation-contracts has no orchestrator→user relay rule. Keep the scripts |
| code-review | FIX + SLIM | review-debt works (its reviews found highs), but its text offers the skip ✓`review-debt.sh:355`. Two definitions of CONFIRMED. False deny of `# NAME=value <reason>`. Its own hooks exceed its 0.3 ceiling under a path exemption |
| taskmaster | FIX + SLIM | the clarify directive fired 50× and was ignored; its checker ships `"default": "off"` ✓. ultra: 0 use, 21 KB. spec-adversary "never a fix" vs a `fix:` field. visual-decisions earns its cost (175 uses) |
| skill-router | SLIM | 242 of 362 surfacings went to never-loaded skills, driven by the `low` content rows and the language-wide nudges. Keep `prime.sh` and the shadow line (a measured failure) |
| ask-ledger | FIX | ordinal tokens ✓`ledger.sh:211`; quoted spans with no negation test ✓`:209-210`; existence checked by substring ✓`:253` — repo vocabulary, not intent, picks the survivor. Value never measured (no control arm) |
| brain | FIX | all 45 fires are the "no map yet" line ✓`inject.sh:57`; 0 maps in any project |
| code-architecture | SLIM | never used in the work projects: coding-entry, domain-modeling, system-design, work-verification, yagni-check. work-verification owns exactly today's claim failure, so this is a routing gap, not a reason to retire it |
| toolchain-experts | FIX | all three 10-16 defects confirmed against the npm tarballs ✓`detect-analyzers.sh:126,155`. Two new: `.eslintcache` reported as the baseline, and preset-sourced `exhaustive-deps` not seen (react-expert's headline finding is lost on dominium) |
| security | FIX | 16 of 20 `security-engineer` dispatches are reviews, but the agent is a fix-applier ✓`security-engineer.md:11`. No read-only reviewer ships |
| web-dev | FIX | all 3 work `vite.config.ts` use laravel/inertia/vite-plus plugins the Vite skill never names. The agents are used (29 + 24 dispatches) |
| devops | SLIM | no compose, k8s or terraform in any work repo. Keep the workflow guard (add `page_name`) and the Docker skill |
| approaches | SLIM | 4 of 5 skills unused. Keep the blind panel (reached via taskmaster) and the consult nudge; fold the rest into references |
| resilience | SLIM / MERGE | replicated control arms pass all 5 measured cases. Fold the 6 skills into one with references; narrow the router rows |
| ui-libraries | SLIM | 0 use; no work project imports these libraries. Keep `component-libraries` (link-catalyst mixes Base UI + Radix) and `primereact` (the one measured delta) |
| api-design | SLIM | 0 skill calls, hook fired 1× in 236 prompts. Keep `api-docs-first`; cut graphql-grpc |

**Across plugins.**
- **What the readers found missing.** No plugin prevents (b) partial reads or (d) lossy
  relays to the user, and those are the two failures you named. Every plugin that touches
  them stops at worker→orchestrator.
- **History and incident narration in shipped files.** It appears in 13 of the 16 read (all but candor, api-design and web-dev): hook
  headers, READMEs and "consumer-facing only" CHANGELOGs. Several cite `rationale/` paths
  installers don't have.
- **Comment volume.** It follows the house rule (CLAUDE.md asks each check for its derivation)
  rather than per-session lapses. That conflicts with comment-discipline, which this repo
  exempts by path.

## Enough or too much?

Both. **Too much:** orchestration, review rounds, prose, and new gates per ask (S1 is the
outlier and set the volume). The same holds for injected plugin text: 864 injections for 236
prompts, mostly dismissed. **Too little:** where it decides whether work is true and lands —
carrying caveats to the user, reading the whole thing or saying what was skipped, asking at
real forks, merging, and remembering a correction. The plugins mirror this. They are heavy
on reminders the model learns to dismiss, and have no mechanism for the two failures that
cost most. S3 is the right default size; S1's size should need the user to ask for it.

## Plan — approved 2026-10-21 ("proceed with everything - step by step"); one stacked PR per wave

Execution rule (from finding 1): one wave at a time, ≤3 crews, a whole-range review before
the next wave. Each relay carries every NOT-DONE and residual line verbatim. Each behaviour
change ships a harness case built from the transcript line that motivated it: it must fail
on the old hook and pass on the new one.

**Wave 1: false positives and defects (small, each with a harness case)**

| # | change | plugin | evidence |
|---|---|---|---|
| W1.1 | negation skip for quoted spans; drop ordinal and unit tokens; whole-word existence check (was P4) | ask-ledger | finding 10; `ledger.sh:209-253` |
| W1.2 | the no-map line prints once per project (marker), then never again (owner pick) | brain | 45 fires, 0 maps |
| W1.3 | exempt `index_path` from the scope lock | task-runner | 61/77 fires |
| W1.4 | a non-unique suffix is undecidable | candor `cite.sh` | blocked a correct citation |
| W1.5 | `NAME=value <prose>` is not commented-out code | code-review `scan.sh` | measured false deny |
| W1.6 | TS/ESLint majors from the lockfile; `eslint-suppressions.json`; preset severities (was P6) | toolchain-experts | tarball-verified |
| W1.7 | `covered` must say red vs green | task-runner `behavioral-gate.sh` | `:493` |
| W1.8 | `page_name` in the guard; quote the audit path | devops | hook/audit disagree |

**Wave 2: the two missing mechanisms, plus the ones that invite skipping**

| # | change | plugin | evidence |
|---|---|---|---|
| W2.1 | **relay ledger.** On a subagent report, extract `NOT DONE / Not tested / Not checked / Residual / Not run / blocked` lines. The Stop gate requires the final message to account for each: carried, fixed, or dropped-because. Precision must be measured on S1's 86 reports before it blocks | candor (owns the Stop gate) | finding 14: 56/86 dropped, 27 overstated |
| W2.2 | a dispatch is not verification; clause 2 needs a tool call, not a word; clause 3 runs at SubagentStop for workers that edited | candor `gate.sh` | `:544`, `:499` |
| W2.3 | **partial-read ledger.** Record Reads with a limit shorter than the file and `head`/`sed -n` on files longer than the cut. The final message names them under `Not read:` unless a later full read covers them. Starts WARN-only and is measured for noise | candor | finding 12 |
| W2.4 | the review nudge offers the user a choice (AskUserQuestion: review / skip) instead of "or say in one line why not"; add `finish`/`land` to ship verbs | code-review | 6+ model-declined nudges; reviews found highs |
| W2.5 | the clarify check is on by default: the first work turn carries an AskUserQuestion or an `Assuming:` line; fork points mid-task are covered | taskmaster | finding 11; checker ships off |
| W2.6 | orchestrator→user relay rule, and a mandatory `Not read / Not checked` line in the return shape | task-runner delegation-contracts | the prose half of W2.1 |
| W2.7 | read-only security reviewer agent | security | 16/20 dispatches are reviews |

**Wave 3: slim. Each line is a separate decision; usage counts are this user's 3 projects
only, and other installers are unmeasured.**
- skill-router: cut the `low` content rows, the digest flush and the language-wide nudges.
- ui-libraries: keep only component-libraries and primereact.
- resilience: merge into one skill.
- approaches: fold pattern-selection and rollout-planning.
- code-architecture: route work-verification; cut domain-modeling, system-design and
  yagni-check.
- taskmaster: shrink ultra.
- candor: retire straight-talk. The terse subsystem STAYS (owner pick). Why it was never
  used: it defaults `off`; the owner gets brevity from the built-in `outputStyle: Concise`;
  across every project's prompts nobody typed a brevity phrase (0 matches); and `mode.sh`
  switches only on "terse mode on" / "enable terse" / `/candor:level`, not on the "be
  brief" its skill description advertises.
- api-design: cut graphql-grpc.
- devops: cut compose-init.
- web-dev: add a Laravel/Inertia Vite section.

**Cross-cutting**
- **P10 (picked: short header + pointer).** A check header is at most 3 lines: what it
  catches and what it misses. Derivation and history move to `rationale/derivations/`
  (the pattern already exists, e.g. `review-debt.sh:94`). This applies as files are
  touched, not in a sweep, and CLAUDE.md's "Plugin change gates" paragraph changes to
  match.
- **P9.** One CLAUDE.md line: load the matching `authoring-*` project skill before editing
  a hook, skill, agent or command.
- **Memory notes (owner preferences, not repo rules):**
  - P7 prose caps.
  - P8 CONFIRMED only when reproduced this session.
  - New: split and read big content in full, or name what was not read.
  - New: at a fork the user has not answered, ask; do not "go with my defaults".
  - New (owner, 2026-10-21): do not read, run or write in another project (e.g. the work
    repos) unless asked or permitted; `/tmp` is fine. This session broke it: it read work
    projects' settings and package.json, and two readers ran a detector inside them.
  - Applied 2026-10-21 as six memory files, including `relay-caveats` beyond the four planned.
- **Footprint.** Merge PR #213. The live `--sync` test is SKIPPED by the owner, so `--sync`
  stays never run through the host.
- **Withdrawn:** P5 as first framed (suppressing review-debt after fix waves). Skipped by
  the owner: P1–P3.
