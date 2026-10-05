# Upstream skill migration and comment-discipline audit — 2026-10-01

**Standing: `recorded`.** A dated audit; nothing reads it back. It briefs the milestones that
follow and is the per-rule provenance for two MIT upstreams. Maintainer-facing only: every rule
it accepts ships inside a plugin (owner instruction, 2026-10-01), never only here.

**Amended 2026-10-05.** Two statements below did not hold: the density ceiling moved from 0.2 to 0.3:1 (owner decision, 2026-10-03), and the roadmap did not run as listed — the plugin and repository comment cleanups beyond the first eight plugins were dropped as out of scope on 2026-10-05.

Sources: `dietrichgebert/ponytail` v4.10.0 (MIT, © 2026 DietrichGebert) and `mattpocock/skills`
v1.2.3 (MIT, © 2026 Matt Pocock), both read 2026-10-01 from a tarball of `main` (no SHA
recorded). Five read-only opus auditors; their returns are Parts A–E, moved here as delivered.
Paths in Parts A–E are relative to the repository root; `upstream/…` is the upstream tree.
Line numbers are those of the tree at `7fe57fa3`.

## What was asked

1. Comments "barely to none unless necessary, code should speak for itself" — for what the
   plugins make Claude write in an installer's project, and for this marketplace's own code.
2. Migrate ponytail and mattpocock/skills "where it makes sense".
3. Everything relevant ships as a plugin.

## Verdicts in one screen

| upstream | rows ruled on | adopt | fold | skip |
|---|---|---|---|---|
| ponytail | 33 | 0 (one optional eval case, deferred) | 11 | 21 |
| mattpocock/skills — 20 engineering skills and their inner rules | 48 | 0 | 15 | 33 |
| mattpocock/skills — 17 productivity / misc / in-progress skills + authoring doctrine | 31 | 0 | 6 (3 taken, 3 graded P3 and skipped) | 25 |

No new plugin. No upstream skill is taken whole: each is either already carried, tied to its
author's setup, or contradicts a house rule. What lands is individual rules, rewritten.

## Owner decisions taken from the audit (also in the program's decisions file)

- **The ladder is a section, not a skill** — "the reach order" in
  `plugins/code-architecture/skills/low-cognitive-load/SKILL.md`. Only two rungs are new here
  (look in this repo first; the platform after the stdlib) plus the ordering. "One line" is
  rejected: house rule is boring over short.
- **The shortcut marker is `shortcut: <the limit>; revisit when <trigger>`** — the fixed form of
  comment-discipline keep-case 1, counted by `debt-scan.sh` as a sixth category. `scan.sh` gets no
  exemption: an exemption would bless the prefix as a bypass.
- **Density ceiling drops from 0.4:1 to 0.2:1, on a prose-only numerator**, after the counter is
  fixed. Measured on 2,400 files in 13 sibling repos: the fixed counter denies 5.0% of existing
  files at 0.2 against 8.8% under today's rule at 0.4 — tighter and fewer false denies. The
  measurement is one owner's repos, no Python/Go/Rust; the CHANGELOG says so.
- **Path exemptions are scoped to a marketplace root.** `*/scripts/*.sh`, `*/templates/*`,
  `*/plugins/*/hooks/*` and `*/migrations/*` exist for this repo and today switch the comment
  hooks off for an installer's deploy scripts, template components, WordPress plugin hooks and
  migrations.
- **Candor's pre-edit reminder gains a comment clause, not a reach-order clause.** 120 bytes of
  headroom; the comment rule is the program's goal and reaches every subagent there; the hook's
  own record shows two zero results for sentences shaped like the reach-order one.
- **Only CLAUDE.md (and the hook env) overrides the comment default.** A repo's
  `CONTRIBUTING.md` becomes a convention *source* for review, never an override.
- **P3 rows are skipped** (re-pitch on "wait, what"; positive phrasing in the CLAUDE.md audit;
  session handoff sentence): each sharpens something the control arm likely already does.
- **Header cleanup is split by audience.** Contract, limits and off-switch stay shipped (one-line
  header + the plugin README); incident history and measurements move to
  `rationale/derivations/`. Help text read out of a header becomes a `usage()` heredoc first.
- **Citations by line number into code are replaced by function names** while the cleanup
  passes through; 147 line citations in dated `rationale/` records are left as dated records.

## What no part of this audit measured

No proposed rule has a control arm. Whether any of it changes what the model writes is unknown;
`plugins/code-review` ships no eval. Every CHANGELOG entry that lands a folded rule says
"unmeasured".

## Roadmap this audit produced

| id | milestone | plugins |
|---|---|---|
| m7 | Comment hooks see every write and every installer file: Bash coverage, exemptions scoped, generated-marker anchored | code-review |
| m8 | Density counter correct, ceiling 0.2 on prose lines, small-file rule, Edit judged by run length | code-review |
| m9 | `scan.sh` detectors: untyped/padded tags, Python docstrings, paragraph runs, markup comments, banner and stamp, lowercase todo | code-review |
| m10 | Reach and prose: candor clause, system-architect Code shape, router rows, reviewer comment pass, five contradictions reworded, skill residuals | candor, code-architecture, skill-router, code-review, approaches, design-kit, security |
| m11 | Fold ponytail: reach order, shelf smell, shortcut marker + debt category, yagni scope and `net:` line, fix placement | code-architecture, code-review, debugging |
| m12 | Fold mattpocock/skills: Parts B and C host changes, P1–P2 | code-review, code-architecture, debugging, git-workflow, hindsight, taskmaster, task-runner |
| m13 | Clean shared blocks and chassis templates, regenerate, re-paste (Part E batch B1) | 20 plugins |
| m14 | Clean plugin code, wave 1: skill-router, twins + craft-layer + ui-ux, candor, write guards (B3, B5, B6, B7) | 8 plugins |
| m15 | Clean plugin code, wave 2: code-review, testing + database, task-runner, taskmaster (B8–B11) | 5 plugins |
| m16 | Clean plugin code, wave 3: design-kit, hindsight + git-workflow, devops + stack-scan, the small ones, overseer (B12, B14–B17) | 12 plugins |
| m17 | Clean the check library and gate scripts, CLAUDE.md cites the new homes (B2, B4) | repo |
| m18 | Clean the remaining scripts and smoke harnesses (B13, B18) | repo |

## Part A — ponytail

### Verdict table
Legend: R = . · U = upstream (v4.10.0) · P = R/plugins · LCL = P/code-architecture/skills/low-cognitive-load/SKILL.md · H# = host block below. All rule text is house wording, not upstream prose.
| upstream unit | verdict | overlaps (path) | delta / reason |
|---|---|---|---|
| Rung 1 — need at all | skip (cited as step 1 in H1) | P/code-architecture/skills/yagni-check/SKILL.md:6-15, :64-81 | carried whole |
| Rung 2 — already in this codebase | fold → code-architecture:LCL (H1) | NOT carried: P/code-review/skills/reuse-hygiene/SKILL.md:15-28 checks that a symbol already found is alive, nothing says look first; host `simplify` is post-hoc. decisions.md row 3's "rungs 1-5 carried" is wrong for this rung | "Before writing a function or type, search the repo for one that already does it; then confirm it is alive (reuse-hygiene)." |
| Rung 3 — stdlib | skip (cited in H1) | P/approaches/skills/build-vs-buy/SKILL.md:25-27 | shelf order already opens with stdlib + installed framework |
| Rung 4 — native platform feature | fold → code-architecture:LCL (H1) | partial only: P/ui-ux/skills/a11y-audit/SKILL.md:18, P/database/skills/sql-best-practices/SKILL.md:99, P/ui-libraries/skills/component-libraries/SKILL.md:56; build-vs-buy's shelf list omits the platform | "After the standard library, the platform under it — what the browser, the database or the OS already does." |
| Rung 5 — already-installed dependency | skip (cited in H1) | build-vs-buy/SKILL.md:28, :52-53, :115-116 | carried (dependency extras, 20-line-subset rule, dependency maximalism) |
| Rung 6 — one line | skip — contradicts | P/code-architecture/skills/low-cognitive-load/references/kiss-dry.md:12-14; P/code-review/skills/comment-discipline/SKILL.md:106 | house rule is boring over short; H1 states "shorter is not a step" |
| Rung 7 — minimum code | skip (cited in H1) | P/code-architecture/skills/plan-before-code/references/surgical-edits.md:64; P/candor/hooks/preamble.sh move 1 | carried |
| Ladder order + run it only after reading the code | fold → code-architecture:LCL (H1) | none — the steps live in three plugins and no artifact orders them | "Read the code the change touches, then take the first step that covers the need; the order picks what to build on and never excuses skipping the read." |
| Bug fix = root cause, grep every caller | fold → debugging:skills/systematic-debugging/SKILL.md (H9) | root cause carried (:8); caller search carried for signature changes only (surgical-edits.md:42 last bullet); fix PLACEMENT across sibling callers carried nowhere | "List every caller of the function the fix touches: a guard at the reported call site repairs one path. Put the fix in the function they share, or name the callers left unfixed." |
| Rule — no unrequested abstractions | skip | yagni-check/SKILL.md:24-43 | carried |
| Rule — no boilerplate / scaffolding for later | skip | yagni-check/SKILL.md:19-23; surgical-edits.md:64 | carried |
| Rule — deletion over addition, boring over clever | skip | yagni-check/SKILL.md:47-62; kiss-dry.md:12-19 | carried |
| Rule — fewest files, shortest diff once understood | skip | preamble.sh move 1; P/code-architecture/skills/coding-entry/SKILL.md:114-118 (`budget:` line) | carried |
| Rule — ship the reduced version, question it in the same reply | skip — contradicts | surgical-edits.md:15-24 (say so BEFORE building); P/candor/hooks/avert.sh; ask-ledger Stop gate | house asks before doing less than named |
| Rule — two same-size options → the edge-case-correct one | fold → code-architecture:LCL (H1, one clause) | adjacent, not the same: build-vs-buy/SKILL.md:61-74 | "A step covers the need only when it is right on the edge cases the requirement has." |
| Rule — `ponytail:` shortcut marker | fold → code-review (H5, H6, H7) | keep-case 1, comment-discipline/SKILL.md:80-81, already admits the comment; no fixed form, nothing counts it | see (b) |
| Output contract | skip | P/candor/skills/terse-output/SKILL.md (budgets, `Skipped` slot); preamble.sh move 5 | carried, and stricter |
| Intensity lite / full / ultra | skip | P/candor/commands/level.md owns lite/full/ultra; `ultra` is a shared word already claimed (P/taskmaster/skills/ultra/SKILL.md:34) | levels parametrise the always-on persona decision 4 rejects |
| When NOT — validation, data-loss handling, security, a11y, explicit asks | fold → code-architecture:LCL (H1, one line) | yagni-check/SKILL.md:93-100 names error handling, validation, tests; security, accessibility and "what the user named" are not listed | "The order never cuts a trust-boundary check, handling that guards against data loss, a security control, a baseline accessibility behaviour, or a thing the user named." |
| When NOT — hardware calibration knob | skip | none | no hardware surface in this marketplace; one line cannot carry a new artifact |
| One runnable check | skip | coding-entry/SKILL.md:112-125; P/testing/skills/testing-best-practices/references/proportionality.md; R/templates/worker-agent.md.tmpl:48-50; preamble.sh moves 2-3 | carried; the "assert in main, no framework" half contradicts testing-best-practices where a runner exists |
| ponytail-review — 5 tags | fold → code-review:skills/code-smells/SKILL.md (H4) | delete = code-smells:74; yagni = code-smells:82 + P/code-architecture/commands/yagni.md; shrink = host `simplify` + kiss-dry (skip); stdlib and native have no review-time carrier | one Dispensables row, "Reinvented shelf": cue — hand-rolled code, or a dependency imported for one call, that the stdlib, platform or an installed dependency ships; fix — name the function or feature that replaces it |
| ponytail-review — net metric | fold → code-architecture:commands/yagni.md (H3) | none | "Close with `net: −N lines, −M dependencies` summed over the proposals." |
| ponytail-audit | fold → code-architecture:commands/yagni.md (H3) | yagni.md:6-7 already takes a file or module; reuse-hygiene deep pass (knip/vulture/deadcode) | "A directory scope ranks findings by lines removed, largest first." Hunt list skipped (yagni red flags + code-smells:56) |
| ponytail-debt | fold → code-review:scripts/debt-scan.sh + commands/review.md (H6) | debt-scan.sh:69-88 counts five categories, none reads a deferral marker | sixth category `shortcuts` + report-only list of markers with no trigger |
| ponytail-gain | skip | — | decision 3; figures are upstream benchmark medians, never measured on these skills |
| ponytail-help | skip | — | decision 3; the host lists commands |
| hook ponytail-activate | skip | P/candor/hooks/preamble.sh is the house pre-edit channel | decision 4 + no Node; re-injects the whole skill body each SessionStart |
| hook mode-tracker | skip | P/candor/hooks/mode.sh owns prompt-head level directives | no levels, nothing to track |
| hook subagent | skip — mechanism already here | preamble.sh SubagentStart branch (its text reached this reader); worker-agent.md.tmpl "Code shape" | H8's clause rides it |
| hook statusline | skip | none | no mode to show; wants a user settings.json edit |
| examples/ | skip | — | verbatim model output; the email-regex and CSV examples contradict build-vs-buy:68-69 and yagni-check:93-100; marker used as a restatement. H1 gets one house-written pair |
| benchmarks/ | skip harness · adopt (optional) → code-architecture/evals/reach-order/case.yaml | shape: P/code-architecture/evals/solid-control/case.yaml | promptfoo/python harness is not the `claude plugin eval` shape. One over-build-trap case (date input): upstream control arm overbuilt there (404 vs 23 LOC, Haiku, n=4) so headroom exists; no existing case can host a second prompt |

### Host changes
- **H1 · LCL** · body 85/200 lines, 5,016/14,000 B, longest line 95/300; description 215/500, leave it untouched. Add section "Before new code: the reach order" above "KISS and DRY" (:78), ~16 lines / ~1.1 kB → ~101 lines / ~6.1 kB: lead sentence; five steps — nothing (yagni-check) → this repo → stdlib then platform → installed dependency (build-vs-buy owns adding one) → new code, the least that satisfies the ask (surgical-edits); the two floor lines; "shorter is not a step" → references/kiss-dry.md; one good/bad pair; credit clause. rules.tsv: no row — R/plugins/skill-router/rules.tsv:105-115 already routes it on six globs. Residual: no row on .php/.tsx/.vue, reached there only via coding-entry or H8. lane.tsv: no row (skills are WARN-tier; a row needs a noun in R/scripts/lane-vocabulary.txt). Standing: recorded.
- **H2 · P/code-architecture/skills/coding-entry/SKILL.md** · 146/200, 8,898/14,000, longest 283/300, description 306/500. Zero new lines: extend the gloss at :24 with "and the reach order before new code". No rows. Standing: agent-graded, as the skill's own triage.
- **H3 · P/code-architecture/commands/yagni.md** · 22 lines, no body gate on commands; description unchanged. Two clauses: step 1 directory-scope ranking (+ reuse-hygiene deep pass for dead-symbol evidence when code-review is installed), step 4 `net:` close. No rows. Standing: agent-graded.
- **H4 · P/code-review/skills/code-smells/SKILL.md** · 113/200, 6,619/14,000, longest 189/300, description 198/500. +4 lines, one Dispensables row. No rows. Standing: agent-graded (smell pass of `/code-review:review`, review.md:88-89).
- **H5 · P/code-review/skills/comment-discipline/SKILL.md** · 163/200 (crowding ratchet trips at 197), 8,856/14,000, longest 108/300, description 401/500. +3 lines on keep-case 1 (:80-81), list stays closed: "A deliberate shortcut is this keep-case in one fixed form — `shortcut: <the limit>; revisit when <trigger>`. Both halves, one line; without the trigger it is a bare TODO." +2 lines under "What is enforced": form is agent-graded; scan.sh neither denies nor validates it. rules.tsv: none (absent on purpose, rules.tsv:61-65). lane row unchanged. Standing: recorded (form), agent-graded (comment-review, code-reviewer).
- **H6 · P/code-review/scripts/debt-scan.sh (158 lines) + P/code-review/commands/review.md:14-28 + P/code-review/scripts/__tests__/debt-scan.test.sh** · add `P_SHORTCUT='(#|//|--|/\*)[[:space:]]*shortcut:'`, key `shortcuts` in the JSON and the loop, a report-only list of markers carrying no trigger word (never ratcheted, like --age); review.md "Five categories" → six. A baseline lacking the key prints `-` and cannot fail (debt-scan.sh:110-116, read, not run). Residual: scan() reads 15 extensions (:61-63); a marker in .sh/.sql/.css is uncounted. Standing: the ratchet's existing one (review.md:25-28).
- **H7 · R/scripts/smoke/comment-discipline-hook-tests.sh §2 (:126)** · add assert_silent + assert_allows for a `shortcut:` line. Pins today's verdict, changes none. Standing: gate (CI smoke step).
- **H8 · P/candor/hooks/preamble.sh, move 1** · payload 880/1000 B (UserPromptSubmit), 877 (SubagentStart); bound at P/candor/scripts/__tests__/preamble-hook.test.sh:49. Insert ", reusing what the repo, stdlib, platform or an installed dependency already has" (80 B → 960). lane row unchanged. Standing: recorded; the hook's own header (:10-16) records two zero results for sentences of this shape — keep only if the with/without eval moves.
- **H9 · P/debugging/skills/systematic-debugging/SKILL.md** · 155/200, 7,444/14,000, longest 86/300, description 242/500. +3 lines in "The fix — justified, then verified" (:101). No rows. Standing: recorded. If decision 3 means two plugins only: same text on surgical-edits.md:42's last bullet (a reference, no budget).

### Answers (a) (b) (c)
(a) A section of LCL, not a new skill. Net-new text is ~16 lines (rungs 2 and 4, the order, the floor); rungs 1/3/5/7 are citations. LCL goes 85 → ~101 of 200 lines, 5,016 → ~6,100 of 14,000 B, description untouched. It is the only code-architecture skill that is both routed (six glob rows) and loaded by coding-entry (:24), so decision 4 is met with zero new rows. A new skill would add a description (~50-75 tok on a 725-tok baseline, tolerance 2 → context-budget FAIL), a trigger overlapping yagni-check / build-vs-buy / coding-entry, and to be reached: 6 rules.tsv rows + 12 `co-fire-ok` lines (pc_rules_overlap) + a sixth eager load in coding-entry. yagni-check has room (124/200, 7,866 B) but is unrouted and review-shaped.
(b) Name: `shortcut:`. Rejected: `ceiling:` (comment-discipline and density.sh already use "ceiling" for the comment ratio); `HACK`/`TODO` forms (scan.sh:324-330 warns, debt-scan counts them as bare markers); the upstream word (names a plugin nobody here installs). Keep-list: yes, it must learn it — as the fixed form of keep-case 1, so the closed list (:77-78) and the worker template's inline list stay true and templates/ is untouched. scan.sh: no. Probed its warn lane with 10 payloads (no writes): a `shortcut:` line, the upstream SKILL example (U/skills/ponytail/SKILL.md:64) and the upstream deep-clone comment (U/examples/deep-clone.md:27) all draw zero findings, so the deny lane, which reads the same detector, cannot fire — the marker word is the unrecoverable token restates() requires (scan.sh:359-375). Two shapes are denied today, both malformed markers: every word including the marker recoverable from the next line (`# lock: global lock` over `global_lock = …`), and a marker ending in `;` that contains `(` or `=` (scan.sh:294). An exempt() entry would change a gate verdict (binding decision) and bless the prefix as a bypass. density.sh counts the line; no change.
(c) Tags: `/code-review:review`, through its smell pass and code-smells — three tags are existing smell names, stdlib + native become H4's one row, and the finding format at code-smells:24 already puts the smell name where upstream puts the tag, so no tag vocabulary is added. Over-engineering-only audit, repo scope and the `net:` line: `/code-architecture:yagni`. Debt ledger: `/code-review:review --debt` over debt-scan.sh.

### Attribution
- code-architecture: README.md intro, beside the Karpathy clause (:4-8); CHANGELOG entry for the bumped version; one clause closing the new section (pattern: plan-before-code/SKILL.md:181).
- code-review: README.md; CHANGELOG entry; one clause on the keep-case line. Not in debt-scan.sh's header (decision 2 shrinks headers).
- candor (if H8 lands): CHANGELOG entry only. debugging (if H9 lands): README.md; it keeps no CHANGELOG.
- R/rationale/upstream-skill-migration-2026-10-01.md: per-rule provenance — github.com/DietrichGebert/ponytail v4.10.0, Copyright (c) 2026 DietrichGebert, MIT (precedent: R/rationale/four-laws-provenance.md). Nothing is copied verbatim, so no LICENSE copy.

### Risks
- `check-version-bumps.sh`: bump + CHANGELOG entry for code-architecture, code-review, candor (each keeps a CHANGELOG → gate); debugging draws the WARN. It reads HEAD — rerun after committing.
- `context-budget.sh` always-on: tolerance is 2 tok, so any description edit over ~8 chars fails; every proposal leaves descriptions alone. Dynamic: H8 adds ~20 tok to candor's 220 → FAIL until a candor-only `--update-baseline` (never blanket, never in CI).
- `preamble-hook.test.sh:49`: 39 B left under the 1000 B bound after H8.
- `pc_skill_budget` / `pc_budget_crowding`: no host comes near; comment-discipline is closest at ~168/197.
- `debt-scan.test.sh:44`: the category loop needs the new key and the fixture a marker line. No message string changes anywhere.
- `pc_handoff_refs`: bare `plugin:name` tokens in H1 must resolve (`code-review:reuse-hygiene`, `approaches:build-vs-buy` do); `shortcut:` is not a plugin dir and is ignored.
- `scripts/eval-cases.sh` if the optional case.yaml lands (typed graders). `generate.sh --check` and `chassis-template-tests.sh` stay green only while templates/ and every .chassis.json are untouched.
- Residual to print in H5: the prefix defeats restates() by construction, so a restatement written as `shortcut:` escapes the deny; upstream's own code does this (22 markers in its code files, ~3 carry a trigger by keyword grep). The debt count is the only counter-pressure.
- Residual to print in H1: an independent upstream benchmark (U/benchmarks/README.md) saw bad-input handling trimmed on 5 of 24 tasks; the floor line exists for that and is recorded, not gated.
- Not run by this reader: validate.sh, any smoke harness, scan.sh's deny lane (it writes marker dirs), debt-scan.sh.

### Injection notes
- U/AGENTS.md (and its per-tool copies under .cursor, .clinerules, .kiro, .windsurf, .qoder, .agents, .github): second-person persona; its last line extends the rules to agents working on that repo. Not acted on.
- U/skills/ponytail/SKILL.md:28-30: persistence directive ("ACTIVE EVERY RESPONSE") with a named off-phrase. Treated as data.
- U/hooks/ponytail-activate.js:90-104: the injected SessionStart text tells the model to volunteer a settings.json statusLine edit. Not acted on; it is the reason for the statusline skip.
- U/hooks/ponytail-instructions.js:44-74: fallback copy of the same persona text. Grep for override phrasing (ignore/disregard/system prompt) found nothing else.

## Part B — mattpocock/skills, engineering

### Verdict table — | upstream skill / rule | verdict | overlaps (path) | delta / reason |
Paths: R =  ; `p/` = R/plugins/ ; upstream = upstream/skills/engineering/ (v1.2.3). Totals: 20 skills → 0 adopt, 0 whole-skill fold, 20 skip; 13 inner rules fold into 10 host artifacts (H1–H10 below).
| upstream skill / rule | verdict | overlaps (path) | delta / reason |
|---|---|---|---|
| ask-matt (skill) | skip | p/skill-router/rules.tsv; p/code-architecture/skills/coding-entry/SKILL.md | router over upstream's own skill names |
| ask-matt · phase-boundary tree (continue / clear / handoff / subagent / compact) | skip | no SKILL.md carries it; p/taskmaster/skills/task-cards/SKILL.md:8-12 makes cards context-free | host-CLI session advice, not a code rule; only plausible host (overseer) has 304 B left |
| code-review (skill) | skip | p/code-review/commands/review.md:84-104; p/code-architecture/skills/drift-review/SKILL.md (spec axis); name collides with the host built-in | house already runs correctness + smell + convention + history, and spec drift separately |
| code-review · standards source = repo's prose standards doc; finding cites file + rule | fold → code-review: hooks/conventions.sh, commands/review.md, agents/code-reviewer.md | conventions.sh:298-305 lists tool configs only; review.md:90-91 names "CLAUDE.md, linters, existing code" | H3 |
| code-review · Mysterious Name smell | fold → code-review: skills/code-smells/SKILL.md | absent from catalog; low-cognitive-load:40-44 states naming, but the reviewer walks the catalog | H1 |
| code-review · Repeated Switches, Refused Bequest, Data Clumps | skip | code-smells:38-43, :98-100 | canonical-doctrine shape (R/rationale/measured-zero-shapes.md §2) |
| code-review · axes never merged or re-ranked | skip | review.md:101-104 | contradicts the house single severity-sorted list |
| code-review · spec found via issue refs in commits; ref/diff pre-check | skip | drift-review §0; review.md:11 | tracker-tied; minor |
| codebase-design (skill) | skip | p/code-architecture/skills/{low-cognitive-load,yagni-check,solid-principles}/SKILL.md | vocabulary layer; Ousterhout/Feathers canon = measured-zero §2 |
| codebase-design · depth / pass-through unit | fold → code-architecture: skills/low-cognitive-load/SKILL.md | :54-66 covers locality and wrapper functions, not the caller-cost measure | H4 |
| codebase-design · interface = every caller-facing fact, incl. call order | fold → code-review: skills/comment-discipline/SKILL.md | keep-case :87-89 lists units / ownership / throws, not ordering; plan-before-code:145-154 | H2b (three words) |
| codebase-design · deletion test; one adapter = hypothetical seam | skip | yagni-check:24-32, :47-62 | carried, with the dependency-inversion boundary upstream lacks |
| codebase-design · interface is the test surface; helper extracted only to test | skip | p/testing/skills/tdd/SKILL.md:68-69; testing-best-practices:8-11, :81-87 | carried |
| codebase-design · DEEPENING (dependency classes, replace-don't-layer) | skip | testing-best-practices:79-87; its references/proportionality.md:32-35 | carried |
| codebase-design · DESIGN-IT-TWICE (parallel rival designs) | skip | p/approaches/skills/approach-deliberation/references/blind-panel.md | carried (four fixed personas) |
| diagnosing-bugs (skill) | skip | p/debugging/skills/systematic-debugging/SKILL.md; probes + redaction already folded 2026-09-02 (:74-78, :112) | same loop |
| diagnosing-bugs · loop asserts the reported symptom; loop ladder; raise flake rate | fold → debugging: skills/systematic-debugging/SKILL.md | Phase 1 :21-29 asks for one command, not what it must assert | H6a |
| diagnosing-bugs · minimise before hypothesising | fold → same | input bisection exists only as last resort (:94-95) | H6b |
| diagnosing-bugs · rank rival hypotheses first | fold → same | :67-69 writes ONE; description says "one hypothesis one experiment" | H6c, worded so testing stays one-at-a-time |
| diagnosing-bugs · regression test only at a seam replaying the real call pattern; no seam = finding | fold → same | :115-116 graduates the repro unconditionally | H6d |
| diagnosing-bugs · HITL script template; perf branch | skip | p/resilience/skills/performance-tuning | 40-line read/printf loop a model writes from memory; fails Admission |
| domain-modeling (skill) | skip | p/code-architecture/skills/domain-modeling/SKILL.md (DDD toolkit) | upstream is glossary + ADR mechanics; ruled per rule |
| domain-modeling · glossary: canonical term + retired synonyms | fold → code-architecture: skills/domain-modeling/SKILL.md (+1 clause in low-cognitive-load) | no "glossary" anywhere under p/; :15-21 says share a language, not record it | H5, H4 |
| domain-modeling · decision record only if hard to reverse + surprising + real trade-off | fold → code-review: skills/comment-discipline/SKILL.md | :32 and :73 route to "ADRs" with no admission test | H2a |
| domain-modeling · user statement contradicted by code | fold → taskmaster: skills/grill/SKILL.md | Step 0 :28-32 covers code-answered rows only | H10 |
| domain-modeling · GLOSSARY-MAP / docs/adr layout | skip | brain/decisions.md, R/rationale/ | author's layout |
| grill-with-docs | skip | p/taskmaster/skills/grill/SKILL.md | body is two Skill calls; content judged under domain-modeling |
| implement | skip | p/task-runner/skills/task-execution; coding-entry | five lines of sequencing |
| implement-spec | skip | p/task-runner/skills/track-orchestration/SKILL.md § The contract | rolling frontier merges and pointer-only dispatch both contradict the house contract (strict waves; card text inline) |
| improve-codebase-architecture | skip | p/code-architecture/agents/architecture-reviewer.md; plan-before-code:111-132 (current/target HTML) | churn-scoped repo survey has no host procedure (reviewer is diff-scoped); CDN report tied to author |
| pr (skill) | skip | p/git-workflow/skills/branch-completion/SKILL.md § PR protocol (:97-116) | a template; house rule is that the repo's own PR template wins |
| pr · before/after evidence + reversibility / blast-radius line | fold → git-workflow: skills/branch-completion/SKILL.md | no-template fallback (:108-109) says what / why / how verified only | H7 |
| pr · visual-summary menu | skip | — | upstream copied it from humanlayer `show-me` (pr/CREDITS.md); second-hand licence unverified |
| prototype | skip | p/design-kit/skills/{in-codebase,design}; p/taskmaster/skills/{visual-decisions,experience-walkthrough}; approaches strategies.md:21-27 | keep-on-a-branch contradicts "spike code dies" and `dk.sh scratch --cleanup`; logic demo is procedure with no measured gap |
| research | skip | p/ultra-deep-research/skills/ultra-deep-research/SKILL.md:92-100; p/api-design/skills/api-docs-first | carried, with tiers and a verifier |
| retro (skill) | skip | p/hindsight/skills/harvest/SKILL.md; p/hindsight/commands/claude-md.md | single-session proposals contradict harvest's ≥2-session gate |
| retro · mechanical mistake → build the check; prose only for judgement; unwired existing check is the finding | fold → hindsight: skills/harvest/SKILL.md | apply gate (:117ff) has CLAUDE.md / memory / brain note, no check destination; the law lives only in R/.claude/skills/authoring-skills/SKILL.md:145-147 | H8 |
| retro · reviewer, not implementer, enforces standards | skip | R/templates/worker-agent.md.tmpl:37-50; code-review hooks | contradicts decision 1 (write-time enforcement) |
| setup-matt-pocock-skills | skip | — | author's setup (tracker, labels, docs/agents) |
| tdd | skip | p/testing/skills/tdd/SKILL.md (tautology + seams folded; p/testing/CHANGELOG.md:155-161) | "refactor outside the loop" contradicts tdd:19; DB-side-channel rule contradicts testing-best-practices:8-9 |
| to-spec | skip | grill:141-149 + spec-ledger-lint | "no file paths" contradicts the card-shape lint; "highest seam, ideally one" contradicts pyramid :21-31 |
| to-tickets (skill) | skip | p/taskmaster/skills/task-cards/SKILL.md | same job |
| to-tickets · wide refactor as expand → migrate batches → contract | fold → taskmaster: skills/task-cards/SKILL.md | :64-65 keeps any mechanical sweep as one card | H9 |
| to-tickets · prefactor first | fold → same | no "prefactor" under p/ | H9 |
| to-tickets · vertical slice per ticket; quiz the user | skip | task-cards:66-68, :128-129; coverage-check | house allows a verifiable horizontal split; machine lints replace the quiz |
| triage | skip | git-workflow review-exchange (verify the claim); code-review reuse-hygiene (already built); brain/decisions.md (rejections); task-runner delegation-contracts (briefs) | tracker state machine; no plugin owns a tracker and no inner rule lacks a host |
| wayfinder | skip | p/overseer/skills/overseer/SKILL.md; grill:114-125 | tracker-tied; overseer body is 189 L / 13,696 B, no room |
| wizard | skip | — | prompt-loop library a model writes from memory; writes .env and `gh secret`, colliding with secret-scanning and command-guard |
### Host changes — path · budget now · exact additions · rules.tsv / lane.tsv rows · standing
- H1 p/code-review/skills/code-smells/SKILL.md · 113 L / 6,619 B, desc 198/500 · under Dispensables before "Comment as deodorant" (:86): "Mysterious name. Cue: the body must be opened to learn what a symbol holds or does (`data`, `handle`, `process2`). Fix: rename; when no honest name fits, the unit does two jobs — split it, then name the halves." · rules.tsv none (catalog unrouted by declared limitation, rules.tsv:61-65); lane none · agent-graded.
- H2 p/code-review/skills/comment-discipline/SKILL.md · 163 L / 8,856 B, desc 401/500 · (a) append to "Reasoning narration" (:71-73): "It earns a decision record only when all three hold: costly to reverse, surprising without the context, a real alternative rejected. Three sentences is a full record; otherwise the PR or nowhere." (b) "Contract facts" keep-case (:87-89): add "required call order" · rules.tsv none (hooks are its channel); lane row exists, unchanged · recorded.
- H3 p/code-review/hooks/conventions.sh:298-305 + commands/review.md:90-91 + agents/code-reviewer.md step 5 · not a skill body · new prose-standards group in the `add` list: `CONTRIBUTING.md CODING_STANDARDS.md docs/CODING_STANDARDS.md STYLEGUIDE.md`; convention-pass text gains "and the repo's contributing or coding-standards doc when present; a convention finding cites file and rule" · none · hook half is an advisory one-shot hint (never blocks); review half agent-graded.
- H4 p/code-architecture/skills/low-cognitive-load/SKILL.md · 85 L / 5,016 B, desc 215/500 · end of "Locality of behavior" (after :66): "Judge a split by depth: what a caller must learn — signature, call order, error modes, required config — against what it gets done. A unit whose interface is as wide as its body is a pass-through; inline it. Splitting to hit a line count manufactures these." After :44: "When the repo keeps a glossary, take its canonical term, never a synonym it retires." · already routed (rules.tsv:105-115), no new row; lane none · recorded.
- H5 p/code-architecture/skills/domain-modeling/SKILL.md · 108 L / 5,572 B, desc 209/500 · after :21: "Write the language down where code can be checked against it: one glossary file per context; each entry the canonical term, one or two sentences on what it IS, and the synonyms it retires. Project terms only, no implementation detail; add the entry when the term is settled. A class, test title or task using a retired synonym is a finding." · unrouted, leave so; do not add "glossary" to the description; lane none · recorded.
- H6 p/debugging/skills/systematic-debugging/SKILL.md · 155 L / 7,444 B, desc 242/500 · (a) after :25: "The command asserts the reported symptom itself — not 'exits non-zero', not a neighbouring failure — and has been run once with its output kept. No test reaches it → script the next cheapest loop: curl against the dev server, a CLI run diffed against a known-good snapshot, a headless-browser step, a replayed captured request, old build vs new on one input."; flaky bullet (:26-27) gains "or raise the failure rate (loop it, add load) until it fails often enough to bisect". (b) end of Phase 1: "Then shrink it: drop inputs, callers and config one at a time, re-running after each; stop when removing anything turns it green." (c) after :69: "Before committing to the one, write two rivals and the observation that separates the three — a lone candidate anchors. Test one at a time regardless." (d) after :116: "The regression test sits where the bug's real call pattern can be replayed; if the only reachable seam is shallower, report that as a structural finding instead of shipping a test that cannot fail on this bug." ≈ +13 L · none (reached via /debugging:debug and the remind hook); lane row exists, unchanged · recorded.
- H7 p/git-workflow/skills/branch-completion/SKILL.md · 186 L / 9,825 B, desc 239/500 · extend the no-template fallback (:108-109): "plus before/after evidence copied from a run (failing then passing output, or the screenshot pair) and one reversibility line: revert-safe, or it moves data or a public contract — and who is hit if it is wrong"; reword :116 "Standing for both" to cover three · none; lane row exists, unchanged · agent-graded.
- H8 p/hindsight/skills/harvest/SKILL.md · 173 L / 10,196 B, desc 285/500 · Apply gate, Rules bullet (:117ff), a fourth destination: "A correction naming a fixed pattern — a banned call, an import shape, a file location — is not a rule line: propose the check (a rule in the linter the repo already runs, a pre-commit step, a CI job). Read the repo's lint script and CI first; a check that exists but is unwired is the finding." Record it in applied.jsonl under the existing kind `idea`; "three destinations" becomes four · none; lane none · recorded (every write still passes the apply gate).
- H9 p/taskmaster/skills/task-cards/SKILL.md · 182 L / 9,655 B, desc 230/500 · Sizing exception (:64-65) becomes "…stay one card while the whole sweep lands green in one commit. When it cannot, sequence it: one card adds the new form beside the old, one card per batch (package, directory) moves callers, a last card depending on every batch deletes the old form." After :116: "A refactor that makes a later card smaller is its own earlier card: behaviour-preserving, proved by the unchanged suite." ≈ +4 L · none; lane row exists, unchanged · agent-graded (card lints cannot see ordering intent).
- H10 p/taskmaster/skills/grill/SKILL.md · 167 L / 10,616 B, desc 229/500 · Step 0 bullets (after :32): "A user statement the code contradicts is CLEAR neither way: one UNKNOWN row quoting both, asked in round one." · none; lane none · agent-graded.
### Comment / code-shape rules found upstream — each with the house artifact that should carry it
- No engineering skill states a code-comment rule. "comment" in upstream/ and upstream/docs/engineering/ means tracker comments, HTML comments or one CSS scaffold comment. Nothing to add to scan.sh / density.sh. The only texts against default-none are prototype/UI.md:40 (plan line "in a top-of-file comment") and pr's `#`-annotated file trees; neither is folded.
- A name that cannot be made honest marks a unit doing two jobs → code-smells (H1); pairs with comment-discipline:68-69.
- One canonical term per concept, retired synonyms listed → domain-modeling (H5) + low-cognitive-load names (H4); gives comment-discipline:103 ("rename the variable") a source of truth.
- Deep unit, small interface, measured by caller cost → low-cognitive-load (H4). The comment-side half already ships as the comment-discipline keep-case "contract facts a signature cannot express"; add call order (H2b).
- A displaced "why" longer than one line becomes a decision record only under the three-condition test → comment-discipline (H2a). Directly usable as the admission test for the header-derivations-to-rationale/ milestone.
- Mechanical style rule → a check; prose only for judgement → hindsight:harvest (H8). Already house law for authors and already practised for comments (scan.sh, density.sh).
- Prose standards doc as a convention source → code-review conventions.sh + review (H3). Open question for the owner, recommended skip: upstream lets any standards doc override the baseline; house lets only CLAUDE.md (plus env for hooks) override comment-discipline (:19-22; worker template :47-48). Widening it means editing R/templates/ and regenerating every worker agent.
- Already carried, no change: test names as specs (testing-best-practices:16-17, comment-discipline:30); tagged debug probes removed before done (systematic-debugging:74-78, :112); speculative abstraction deleted (yagni-check).
### Attribution — where the MIT credit line goes per touched plugin
- code-review: CHANGELOG entry for the bumped version (gate) + one sentence in p/code-review/README.md under "## Comment discipline" (:70): rules adapted from mattpocock/skills v1.2.3 (MIT, © 2026 Matt Pocock), rewritten.
- code-architecture: CHANGELOG entry (gate) + p/code-architecture/README.md:3-7, beside the existing Karpathy clause (the precedent).
- debugging, git-workflow, hindsight, taskmaster: README line only. None has a CHANGELOG, and adding one opts the plugin in permanently — do not.
- Existing gap: the 2026-09-02 folds into debugging, taskmaster grill and git-workflow are credited only in R/rationale/2026-09-02-web-dev-merge.md:153-159 and p/testing/CHANGELOG.md:155-161; those three READMEs carry no credit. Close it in the same edit.
- R/rationale/upstream-skill-migration-2026-10-01.md: per rule → upstream file + version 1.2.3 (package.json, .claude-plugin/plugin.json). upstream has no .git, so no commit SHA is verifiable; the earlier review pinned 98d09c6.
- pr: its Summary menu belongs to Dex Horthy / humanlayer `show-me` (pr/CREDITS.md, frontmatter metadata.credits). H7 takes only Evidence + reversibility, which CREDITS.md does not attribute to it.
### Risks — gates likely to fire
- check-version-bumps.sh: six plugins change functional files (code-review, code-architecture, debugging, git-workflow, hindsight, taskmaster) → six plugin.json bumps. CHANGELOG entry is a gate for code-review and code-architecture, WARN for the other four. It reads HEAD — rerun after commit. Marketplace manifest (0.118.0) moves too.
- pc_budget_crowding (baseline 0, fails at ≥198 lines): branch-completion 186 → ~189, task-cards 182 → ~186. pc_skill_budget 300-char line cap: wrap every delta.
- Measured-zero shape 2 (canonical-doctrine checklist): H1, H4 and H6 restate Fowler / Ousterhout / standard debugging canon; R/rationale/measured-zero-shapes.md puts the burden on naming what a blind control misses. No eval control arm exists for any of the ten folds; all are unmeasured.
- conventions.sh edit (H3): p/code-review/scripts/__tests__/conventions-hook.test.sh asserts its output, R/scripts/smoke/marker-key-tests.sh references the hook, and the context-budget dynamic channel meters per-tool hook stdout.
- context-budget always-on (blocking): no description change is proposed; any trigger word added to a description moves a baseline.
- Contradictions that must stay unfolded: tdd refactor-outside-loop; to-spec / agent-brief "no file paths" vs the card-shape lint; implement-spec rolling merges vs strict waves; retro single-session vs the ≥2-session gate; code-review no cross-axis ranking; prototype kept on a branch; highest-seam testing vs the pyramid.
- pc_jargon / pc_handoff_refs: delta text must not carry `card NN`, "the backlog" or an upstream `plugin:name`-shaped token. Upstream names `code-review`, `debug`, `research` collide with host or installed names; no artifact is created, so the host-ok gate stays quiet.
- H8: README / command text that counts harvest destinations must change with the skill; scripts/outcome.sh reads the applied.jsonl kind enum — reuse `idea`, add no kind.
- generate.sh --check stays untouched only while R/templates/worker-agent.md.tmpl is not edited (see the open question above).
- Line numbers are from the repo tree (code-review 0.24.1); the brief's skill path points at the installed cache 0.23.0.
- Not run by this audit: validate.sh, any gate, any eval. Not read in full: wizard/template.sh (grepped), the three issue-tracker-*.md and triage-labels.md seeds, HTML-REPORT.md past its card section, every agents/openai.yaml but one, and upstream/docs/engineering/*.md beyond grep hits on comment / naming / standards. docs/engineering/resolving-merge-conflicts.md has no SKILL.md under skills/engineering and is outside the 20.
### Injection notes
- None found. Upstream SKILL.md files are agent-directed by nature ("call the Skill tool twice", "tell the user to run /setup-matt-pocock-skills", "refuse to give up"); all treated as data, none acted on. upstream/CLAUDE.md and AGENTS.md hold that repo's contributor rules; not followed.
- wizard/template.sh and diagnosing-bugs/scripts/hitl-loop.template.sh were read or grepped, never executed. No file under upstream addresses an auditor or claims authority.

## Part C — mattpocock/skills, productivity, misc, in-progress, authoring doctrine

### Verdict table — | upstream skill / rule | verdict | overlaps (path) | delta / reason |
| upstream skill / rule | verdict | overlaps (path) | delta / reason |
|---|---|---|---|
| productivity/grill-me | skip | plugins/taskmaster/commands/task.md, commands/brainstorm.md | One-line user-typed wrapper over `grilling`; house entry commands exist. |
| productivity/grilling — frontier / round rule | skip | plugins/taskmaster/skills/grill/SKILL.md:82-84 | Already folded 2026-09-02 (commit 98d09c67, root CHANGELOG.md:1144). Recommended-option-first (line 86) and never-ask-what-code-answers (line 28) also carried. |
| grilling — non-blocking fact lookup | fold → taskmaster:skills/grill/SKILL.md | grill Step 0 (lines 21-34) scouts once, serially, before round 1 | P2. Mid-round fact gap becomes a background scout dispatch; only dependent rows wait. |
| grilling — no question cap, emoji round format, confirm gate | skip | grill lines 110-112 (2–4 rounds) and 127-130; candor terse-output "No emoji" | Contradicts Proportionality / carried by AskUserQuestion and assumption-list approval. |
| productivity/handoff | fold → task-runner:skills/delegation-contracts/SKILL.md | delegation-contracts lines 14-35; overseer resume; plugins/skill-router/hooks/compact-capsule.sh; grill lines 53-63 | P3. Session handoff as the same prompt contract. No new command (upstream doc names a built-in `/handoff`; pc_host_overlap risk). |
| productivity/teach | skip | none (nearest design-kit:artifact, ultra-deep-research) | Stateful learning-workspace product; no existing plugin can host it and no single rule in it is hostable; a new plugin is outside the binding decision. |
| productivity/to-questionnaire | fold → taskmaster:skills/grill/SKILL.md + new references/questionnaire.md | grill lines 107-109 ("You decide" → ASSUMED) is the only non-answer path; overseer skill "Clarify" section | P2. A row a named third party holds gets a questionnaire file and stays UNKNOWN. |
| productivity/wait-what | fold → candor:skills/terse-output/SKILL.md § Exceptions | terse-output Exceptions ("asks to clarify, repeats a question") | P3, weak: sharpens an existing exception; control arm likely passes, so skip is defensible. GLOSSARY.md dependency dropped. |
| writing-for-agents — completion criteria (clarity + demand) | fold → task-runner:skills/delegation-contracts/SKILL.md | cards only: taskmaster verify-teeth (gate); ad-hoc dispatch prompts: nothing | P1. Strongest delta in this batch. SKILL-step half is repo-only, out of scope. |
| writing-for-agents — negation → positive target | fold → hindsight:commands/claude-md.md § 3 Proposals | none (grep: zero hits) | P3, unmeasured upstream. Only shipped host that writes agent-facing rules; SKILL-style half is repo-only, out of scope. |
| writing-for-agents — per-sentence no-op test | skip | plugins/hindsight/commands/claude-md.md (Conciseness criterion: restated code and generic advice) | Carried for CLAUDE.md; SKILL-body half is repo-only, out of scope. |
| writing-for-agents — environment-as-cache | skip | plugins/hindsight/commands/claude-md.md rubric row 1 and § 3 Proposals | Contradicts the only shipped host (it scores and adds build/test commands); repo-only, out of scope. |
| writing-for-agents — disclosure by branch | skip | none shipped | Repo-only (.claude/skills), out of scope under the plugin-first decision. |
| writing-for-agents — context pointers, two loads, sprawl/sediment, single source, router skill | skip | scripts/context-budget.sh; CLAUDE.md "cite, do not restate"; skill-router | Carried, several by gate. |
| writing-for-agents — leading words | skip | none shipped | Unmeasured style lever; coined body vocabulary runs against the pc_jargon intent. |
| writing-for-agents/SKILL-MECHANICS.md | skip | .claude/skills/authoring-commands/SKILL.md lines 39-52; authoring-skills/references/activation-fields.md | Carried in repo doctrine; no installer-facing rule. |
| misc/git-guardrails-claude-code | skip | plugins/command-guard/hooks/destructive-guard.sh:228-258; skills/destructive-commands/references/rules.md | Every pattern except plain `git push` is carried with quote-aware segment parsing; upstream is a substring grep. Plain-push ban is policy: host `permissions.deny`. |
| misc/migrate-to-shoehorn | skip | plugins/testing/skills/testing-best-practices/SKILL.md:39 | One library's migration recipe by the upstream author. |
| misc/scaffold-exercises | skip | none | Tied to upstream's `ai-hero-cli` course repo. |
| misc/setup-pre-commit | skip | plugins/code-review/hooks/conventions.sh:305 (detects .husky, .lintstagedrc) | Canonical setup recipe plus author's Prettier defaults; no rule the model lacks. |
| in-progress/claude-handoff | skip | host Agent background dispatch; delegation-contracts | One host flag (`claude --bg --name`, present on 2.1.286). Upstream's own handoff doc warns that a summary interpolated into a shell argument truncates silently. |
| in-progress/loop-me | skip | overseer skill "Clarify" section | Personal-automation workspace product, beta upstream; "ask once, late" carried in spirit. |
| in-progress/setup-ts-deep-modules | skip | testing-best-practices (public boundaries); taskmaster verify-teeth; code-architecture coding-entry (negative control) | TS-monorepo recipe plus a config file. "Prove the rule bites" carried. Boundary-linter rule is carried nowhere (grep zero for dependency-cruiser, deptrac, no-restricted-imports): decide with the engineering reader's codebase-design verdict. |
| in-progress/writing-beats, writing-fragments, writing-shape | skip ×3 | none | Article-writing workflow, no host; "re-read before write" is enforced by the host Edit tool. |
| upstream .agents/invocation.md | skip | authoring-commands lines 39-52; activation-fields.md | Model- vs user-invoked split carried; its two unmeasured claims are repo-only probes. |
| upstream .agents writing-docs doctrine | skip | CLAUDE.md Mission; scripts/validate.sh README gates (lines 605-664); scripts/removed-plugins.tsv | Tied to aihero.dev publishing; defining-constraint and archived-page rules carried. |
| upstream .agents install-block doctrine | skip | scripts/generate.sh offswitch-table; plugins/stack-scan/skills/vercel-skills-scout/SKILL.md:20-23 | Upstream install wording; duplicate-install overlap column already exists. |
| upstream ADR 0001 (hard vs soft dependency pointer) | skip | grill lines 134-139; authoring-plugins lines 70-84 | Carried: companion is prose; installed → use, absent → inline. |
| upstream ADR 0002 (ship as plugin) | skip | none | Upstream packaging decision. |
| upstream CLAUDE.md | skip | validate.sh routing reachability; pc_removed_refs; scripts/official-validate.sh | Carried by gate; its no-em-dash rule contradicts the house description format. |
| upstream GLOSSARY.md | skip | scripts/lane-vocabulary.txt; pc_jargon | Repo-specific terms; format belongs to the engineering reader's domain-modeling verdict. |

### Host changes — one block per host artifact: path · budget now · exact additions · rules.tsv / lane.tsv rows · standing
**plugins/taskmaster/skills/grill/SKILL.md** · body 166/200 lines, 10,615/14,000 B; description 229/500 · taskmaster 0.46.0, no CHANGELOG
- § Question mechanics, after "Offer concrete options": `A fact gap found mid-round is a context-scout dispatch, never a question: run it in the background and hold back only the rows that depend on it; the rest of the frontier is asked now.`
- § Question mechanics, after the "You decide" bullet: `"Not mine to answer", and a named person holds it: never ASSUME it at the cap. Ask who it goes to and what must come back, write the file per references/questionnaire.md; the row stays UNKNOWN until answers return or the user accepts a named default.`
- New `plugins/taskmaster/skills/grill/references/questionnaire.md` (about 25 lines, house voice): output `taskmaster-docs/questionnaires/YYYY-MM-DD-<slug>.md`; one recipient per file; purpose plus the decision riding on it; one context paragraph for a reader outside the session; deadline; "I don't know" invited; most-important-first; one idea per question with an answer stub; a why-line only where misreadable; closing catch-all; never interview the user about the subject.
- rules.tsv: none (grill has no row; trigger is prompt-shaped). lane.tsv: none (no grill row exists; skills are WARN-tier).
- Standing: first line agent-graded. Second: "no spec while UNKNOWN" is a gate (`spec-ledger-lint.sh` open-unknown); questionnaire shape is agent-graded.

**plugins/task-runner/skills/delegation-contracts/SKILL.md** · body 158/200 lines, 8,596/14,000 B; description 369/500 · task-runner 0.42.1, has CHANGELOG
- § Prompt contract, new bullet after "The required return shape": `**The done-when.** A bar the agent can check and cannot meet early: "every caller of parse() listed with its path and line", not "find the callers". A vague bar is where a worker stops short.`
- After "The test:" paragraph (lines 32-35): `A handoff to a fresh SESSION is this contract with a human-started reader: write it outside the tracked tree, cite specs, commits and diffs by path or SHA instead of retyping them, name the skills to load, and mark every claim this session did not verify.`
- rules.tsv: none. lane.tsv: existing row stays; optionally append "or handing work to a fresh session" to its trigger cell. Leave the description untouched.
- Standing: both recorded (nothing lints a dispatch prompt). Secret redaction is a gate only where secret-scanning is installed and the handoff goes through Write.

**plugins/candor/skills/terse-output/SKILL.md** · body 138/200 lines, 7,786/14,000 B; description 430/500 · candor 0.6.1, has CHANGELOG
- § Exceptions, outside the `terse-contract` markers: `A reply that did not land ("wait, what", "I'm lost", the same question again) is re-pitched, not repeated: one line of where the work stands, then the point in short whole sentences, one name per thing, in the repo's own terms.`
- rules.tsv / lane.tsv: none. Standing: unenforceable at write time, as the section already states.
- Reach caveat: plugins/candor/hooks/mode.sh:79 and plugins/candor/hooks/activate.sh:76 inject only the marked contract block, so this line is read only when the skill body is loaded.

**plugins/hindsight/commands/claude-md.md** · command file, so no SKILL body budget; description unchanged · hindsight 0.11.0, no CHANGELOG
- § 3 Proposals, after "Never add generic advice…": `Phrase a proposed rule as the behaviour to do; keep "never" for a hard guardrail, with the action to take beside it.`
- rules.tsv: none. lane.tsv: existing `hindsight:claude-md` row stays.
- Standing: agent-graded, same as the command's judgment half. P3. The harvest skill also writes rules into CLAUDE.md; its body was not read, so whether it needs the same line is open.

### Authoring-doctrine deltas — for .claude/skills/*
Marked per the plugin-first decision (decisions.md, 2026-10-01T15:09:55Z).
- Done-when on a step or prompt: ships in task-runner:skills/delegation-contracts/SKILL.md (see Host changes). SKILL-step half: repo-only (.claude/skills) — out of scope.
- State the target behaviour, not a bare prohibition: ships in hindsight:commands/claude-md.md (see Host changes). SKILL-style half: repo-only (.claude/skills) — out of scope.
- Per-sentence no-op test: already ships in hindsight:commands/claude-md.md (Conciseness criterion); no delta. SKILL-body half: repo-only (.claude/skills) — out of scope.
- Environment-as-cache: repo-only (.claude/skills) — out of scope; no plugin host, it contradicts the hindsight rubric.
- Choose `references/` by branch, not by overflow: repo-only (.claude/skills) — out of scope.
- Probe, whether a `disable-model-invocation: true` skill loads through the Skill tool: repo-only (.claude/skills) — out of scope. Two shipped skills carry the flag (taskmaster verify-teeth, task-runner behavioral-gate); in what was read both are reached by script or path.
- Probe, naming the Skill tool in an operative step: repo-only (.claude/skills) — out of scope.
- authoring-commands, authoring-agents, authoring-plugins, authoring-hooks: no delta.

### Attribution — where the MIT credit line goes per touched plugin
- task-runner: `plugins/task-runner/CHANGELOG.md`, entry for the bumped version (gate requires the entry): "done-when and session-handoff rules drawn from mattpocock/skills (MIT), rewritten, unmeasured".
- candor: `plugins/candor/CHANGELOG.md`, same form.
- taskmaster: no CHANGELOG (adding one opts in permanently), so `plugins/taskmaster/README.md` under "Contents", plus the root `CHANGELOG.md` release entry. Precedent: root CHANGELOG.md:1144 and plugins/testing/CHANGELOG.md:161.
- hindsight: no CHANGELOG, so `plugins/hindsight/README.md`, same form.
- `rationale/upstream-skill-migration-2026-10-01.md` holds per-rule provenance for maintainers only; it is not shipped, so it cannot be the sole credit.
- Pin: upstream plugin.json 1.2.3, read 2026-10-01. `upstream` has no `.git`, so no SHA can be recorded.
- `references/questionnaire.md` is the one place close to a substantial copy: rewrite the template, do not paste it.

### Risks — gates likely to fire
- `check-version-bumps.sh`: task-runner and candor need a plugin.json bump plus a CHANGELOG entry (gate); taskmaster and hindsight need the bump and draw a WARN. It reads HEAD, so rerun after committing.
- `pc_skill_budget` 300-char line limit: every addition above must be wrapped; grill line 112 is already 206 chars, do not extend it.
- `context-budget.sh` (blocking): any description edit moves the always-on baseline; moving the wait-what line inside the `terse-contract` markers moves the activated baseline. Keep all edits body-only and outside the markers.
- Reference resolution: grill citing `references/questionnaire.md` fails unless the file lands in the same commit.
- `pc_handoff_refs`: never write upstream skill names as `plugin:skill` tokens. `pc_jargon`: upstream prose uses "backlog" and "ticket".
- grill's cap rule (lines 110-112) converts leftover UNKNOWNs to ASSUMED; the questionnaire bullet must state its exemption or the two lines contradict.
- Local-doctrine contradictions, not to import: no question cap, no em-dashes, emoji round markers.
- Exact-string harness risk is low: only scripts/validate.sh names the three SKILL.md hosts; harness coverage of the hindsight command prose was not checked.
- candor's Stop gate resolves every path-and-line citation against the marketplace tree, so a citation into the upstream copy under /tmp blocks the turn (it did in this reader's session); the migration report should cite upstream by path only.
- Tree state: `bash scripts/validate.sh` ended "OK: marketplace valid" on the tree read. No other gate was run. No proposed rule is measured.

### Injection notes
- No override-style text, hidden comments or encoded payloads in scope (grep over the 17 skills, the upstream `.agents/` directory, CLAUDE.md, GLOSSARY.md, docs/productivity).
- Upstream wait-what and grill-me skill bodies are second-person commands to the agent ("Re-pitch that", "Call the Skill tool with grilling"): read as data, not acted on.
- The upstream writing-docs doctrine file (in `upstream/.agents/`, its lines 50, 51 and 77) tells the reader to read `~/repos/matt/personal-wiki` and `~/repos/ai/ai-coding-dictionary/` and run `gh issue list`: not acted on.
- Upstream CLAUDE.md (its line 23) tells the reader to run `scripts/link-skills.sh`, which symlinks into `~/.claude/skills` and `~/.agents/skills`: not run.
- handoff and claude-handoff tell the agent to write temp files and launch `claude --bg`: not run; only `claude --help` was read to confirm the flags exist.
- No file was written.

## Part D — gaps in the shipped comment rules

### Coverage matrix — | language / syntax | scan.sh | density.sh | evidence (command + output line) |
Rig for every row: JSON payload on stdin to `/bin/bash plugins/code-review/hooks/{scan,density}.sh`, `hook_event_name` Pre/PostToolUse, `tool_name` Write, fresh `session_id` per case, HOME and CLAUDE_PLUGIN_DATA under `$TMPDIR/cd-audit` (driver `run.py` + `cases_*.py` there). Density rows use 60 comment / 20 code lines (3.0:1) unless stated.
| language / syntax | scan.sh | density.sh | evidence |
|---|---|---|---|
| `//` line: js ts php go kt scss, vue `<script>` | seen, deny | counted | `js // line pre=DENY`; `.js density-pre=DENY … 3.0:1` |
| `/* x */` one-line, `* x` docblock line (js php css sql) | seen, deny | counted (js/php only) | `js /* */ one-line pre=DENY`; `php docblock summary pre=DENY` |
| `/* … */` middle lines with no leading `*` | unseen | counted as CODE | `js /* */ bare middle line pre=SILENT post=SILENT`; `js /* */ no leading * density-pre=SILENT` |
| trailing `code; // c` | unseen | counted as code | `js trailing comment pre=SILENT post=SILENT`; `js 60 trailing comments density-pre=SILENT` |
| Python `#` | seen, deny | counted | `py # line pre=DENY`; `.py density-pre=DENY` |
| Python docstring (`"""`, `:param`, Google `Args:`) | unseen; `:param` branch (scan.sh:334) reachable only as `# :param` | counted as CODE | `py docstring :param tags pre=SILENT post=SILENT`; `py 60-line docstring density-pre=SILENT` |
| PHPDoc `@param T $x`, JSDoc `@param {T} x` | deny only when description is empty or equals the name | counted | `php docblock dead tags pre=DENY`; `php docblock padded tags pre=SILENT` |
| TSDoc / Javadoc `@param id the id`, `@param id - the id` | unseen (name resolves to "the", scan.sh:340) | counted | `ts TSDoc @param no type pre=SILENT`; `java Javadoc @param pre=SILENT` |
| Go godoc, Rust `///` `//!` | seen, deny | counted | `go godoc summary pre=DENY`; `rust //! inner doc pre=DENY` |
| shell `# ` (.sh .zsh), Dockerfile, .tf, .lua `-- `, .ex, .pl, .graphql, .sql, .css | seen, deny (`#x` without space unseen) | extension not listed: unseen | `sh # (src/c.sh) pre=DENY`; `.sh/.sql/.css/.lua/.tf/Dockerfile/Makefile density-pre=SILENT` |
| Vue SFC | `<script>` `//` seen; `<template>` `<!-- -->` unseen | `<!-- -->` counted as code | `vue template <!-- --> pre=SILENT`; `vue <!-- --> x60 density-pre=SILENT` |
| Blade `{{-- --}}`, HTML `<!-- -->` in .blade.php, JSX `{/* */}` | unseen | counted as code | `blade {{-- --}} pre=SILENT`; `jsx {/* */} x60 density-pre=SILENT` |
| .html .erb .twig .astro .hs | extension not listed | not listed | `html ext pre=SILENT`; `.html density-pre=SILENT` |
| Ruby `=begin`, Elixir `@doc """`, C# `/// <summary>` | unseen / never matches | code / counted | `ruby =begin block pre=SILENT`; `elixir @doc heredoc pre=SILENT` |
| Rust `#[attr]`, C `#include`/`#define`, PHP `#[Attr]`, JS `#private`, C# `#region` | not comments | counted AS COMMENT | `rust attrs, ZERO comments density-pre=DENY … 2.0:1`; `C #include/#define, ZERO comments density-pre=DENY` |
| paths `*/templates/*`, `*/migrations/*`, `*/scripts/*.sh`, `*/build/*`, `*/plugins/*/hooks/*` | exempt | exempt | `src/templates/EmailTemplate.tsx scan-pre=SILENT density-pre=SILENT`; same for `database/migrations/…php`, `scripts/deploy.sh`, `packages/build/index.ts`, `wp-content/plugins/shop/hooks/cart.php`; control `bin/deploy.sh scan-pre=DENY` |
| any file written by the Bash tool | unseen | unseen | `scan.sh PreToolUse Bash heredoc -> SILENT (exit 0)` (all 4 hook/event pairs); live: Write of the same text was denied, the heredoc landed on disk |
| YAML / JSON / Markdown | excluded by design | excluded | `yaml # (excluded by design) pre=SILENT` |

### Gaps — one per line: `path:line — severity — input that gets through — proposed fix — standing (gate/agent-graded/recorded) — false-positive risk`
plugins/code-review/hooks/hooks.json:26,63 (+ scan.sh:141, density.sh:176) — critical — `cat > f.js <<'EOF'` holding `// increment the counter`, `// const old = compute(counter);` and `@return void`: on disk, no deny, no warning — add Bash to both matchers; paste the bash-write-targets + bash-write-chunks blocks; judge each chunk as the added text of its resolved target — gate — low (same detectors); residual: interpreter writes, cp/mv, variable paths, `sed -i`
plugins/code-review/hooks/scan.sh:168 (`*/templates/*`; density.sh:218) — high — INSTALLER files with no comment enforcement: every governed-extension file under any directory named `templates` at any depth (`src/templates/EmailTemplate.tsx`, `resources/views/templates/x.php`, both run: SILENT in both hooks; by the same glob also `app/templates/*.py`, `components/templates/*.vue`) — the pattern exists for this marketplace's `templates/` chassis dir; apply it only when the state root holds `.claude-plugin/marketplace.json` — gate — low
plugins/code-review/hooks/scan.sh:168 (`*/scripts/*.sh`; density.sh:218) — high — INSTALLER files: every `.sh` under any `scripts/` directory (`scripts/deploy.sh` run: SILENT; `bin/deploy.sh` is denied), i.e. the usual home of a project's deploy, release, CI and setup scripts; `case` globs cross `/`, so `scripts/ci/x.sh` matches too (read, not run); density.sh never lists `.sh`, so this is scan.sh's loss alone — same marketplace-root scoping — gate — low
plugins/code-review/hooks/scan.sh:168 (`*/plugins/*/hooks/*`; density.sh:218) — high — INSTALLER files: any file under `<anything>/plugins/<name>/hooks/` — a WordPress plugin's `wp-content/plugins/shop/hooks/cart.php` (run: SILENT both hooks); by the same glob a monorepo's `src/plugins/auth/hooks/useAuth.ts` and a Claude Code plugin author's own `plugins/<x>/hooks/*.sh` (read, not run) — same marketplace-root scoping — gate — low
plugins/code-review/hooks/scan.sh:167-168 (`*/migrations/*`, `*/build/*`, `*/.claude/*`; density.sh:217-218) — medium — INSTALLER files: `database/migrations/2026_10_01_create_users.php` and `packages/build/index.ts` run SILENT in both hooks; `.claude/hooks/*.sh` the installer writes is exempt by design — drop the migrations exemption (hand-written code); keep `dist/`, `vendor/`, `node_modules/`, `.git/`; treat `build/` as output only at the project root — gate — low to medium
plugins/code-review/hooks/density.sh:286-287 — high — 20 comment / 41 code (0.49:1) passes although every message, README:85 and SKILL.md:145 say 0.4:1; integer truncation makes the real deny threshold 0.5:1 — compare `pc*10 > CEIL*pcode` — gate — none; raises the deny rate on existing files from 8.8% to 13.0%
plugins/code-review/hooks/density.sh:266 — high — zero-comment Rust/C/PHP-attribute/JS-private/C# files denied at 1.8–2.0:1; a 60-line Python docstring, 60 `<!-- -->`, 60 bare block-comment lines pass — per-language classifier: `#` is a comment only in py/rb/php-not-`#[`; docstring and block state; delimiter-only lines and type-carrying tags out of the numerator — gate — this fix removes false denies; residual: triple-quoted literals that are not docstrings
plugins/code-review/hooks/density.sh:240 — high — a file one-third comment passes; sibling-repo median is 0.01:1 and 44.8% of files hold zero comment lines — after the two fixes above, default 0.2:1 on a prose-only numerator — gate — measured on 2,400 tracked files in 13 sibling repos: raw rule denies 8.8% at 0.4, 13.0% at 0.3, 17.2% at 0.2, 23.4% at 0.1; prose-only numerator 2.0% / 2.9% / 5.0% / 10.3%
plugins/code-review/hooks/density.sh:234-235 — high — 45-line file at 30 comment / 15 code and a 49-line file at 4.4:1: SILENT; 2,319 of 4,719 sibling-repo code files (49.1%) sit under the floor, 190 of them over 0.4:1 — small-file rule on an absolute prose-line count — gate — medium
plugins/code-review/hooks/density.sh:184 — high — an Edit adding 200 comment lines: PreToolUse SILENT; the PostToolUse warning is capped at 3 per context (:242) and once per file (:318) — judge an Edit by the run-length rule on the next line, not by a ratio — gate — low
plugins/code-review/hooks/scan.sh:382-395 — high — a 5-line `//` why-paragraph and a 5-line docblock narrating the design: SILENT in both lanes, against SKILL.md:16-17 and :71-73 ("one line, not a paragraph") — count consecutive prose comment lines in the added text (delimiters, tags, directives, licence excluded); warn at 3, deny at 5 — gate, bounded twice per file — medium: 18.8% of sibling files already hold a run of 5+, 10.6% a run of 8+
plugins/code-review/hooks/scan.sh:331-356 — high — `@param id the id`, `@param id - the id`, `@return the user` (TSDoc, Javadoc): SILENT — parse the untyped `name desc` and `name - desc` forms — gate — low
plugins/code-review/hooks/scan.sh:353-355 — high — `@param int $userId The ID of the user`, `@return string The user name`, `@var string` over a typed property: SILENT — run `restates()` on the tag description against the tag name plus the signature line — gate — low (every content word must be recoverable; a unit or ownership word breaks the match)
plugins/code-review/hooks/scan.sh:267-277 — high — `"""Get the user."""` under `def get_user`, `:param user_id: user id`, `user_id: The user id.`: SILENT — triple-quote state for .py feeding restatement, dead-tag and run-length checks — gate — low to medium (restrict to the first statement after def/class)
plugins/code-review/hooks/scan.sh:286-291,405 — medium — `// ===== HELPERS =====` only warns after the write; `//region Helpers`, `// MARK: - Helpers`, `// Step 1: validate`, `// Validation`: unseen — add the cues; make the decorated banner blockable — gate for decorated, warn for the rest — low; `MARK:` and `#region` are IDE-read, keep warn
plugins/code-review/hooks/scan.sh:307-323 — medium — the skill's own example `// modified by A. 2024-03-11` (SKILL.md:63): SILENT both lanes; also `// Updated: use the new client`, `// New: retry on 429`, `// Handle the null case that was crashing before` — add an author/date-stamp cue (blockable) and `^(updated|new|changed|fixed):` (warn) — gate / agent-graded — low for the stamp, medium for phrases
plugins/code-review/hooks/scan.sh:267-277,182-194 — medium — `<!-- the user list -->`, `{{-- … --}}`, `{/* … */}`, `=begin`; .html/.erb/.twig/.astro not listed — single-line markup comment forms in `cbody` plus the extensions — gate for commented-out markup, warn otherwise — low
plugins/code-review/hooks/scan.sh:267-277 — medium — `counter++; // increment the counter`: SILENT — trailing-comment extraction with string and URL masking — agent-graded (warn) — medium
plugins/code-review/hooks/density.sh:221-226 — medium — a 3.0:1 file in .sh/.sql/.css/.scss/.lua/.ex/.pl/.tf/.graphql/Dockerfile/Makefile: SILENT though scan.sh governs all of them — one extension list in hooks/paths.sh — gate — low
plugins/code-review/hooks/scan.sh:359-376 — medium — `// Get the user from the database` over `db.users.find(id)`; `// list of users who have not paid yet` over `const list`: SILENT, no mechanical cue exists — leave to a reviewer — agent-graded — n/a
plugins/code-review/skills/comment-discipline/SKILL.md:147-148 vs plugins/code-review/agents/code-reviewer.md:63-64 — medium — the skill says the code-reviewer agent judges kept comments; the agent defers "comment volume" to "comment-discipline" and has no comment pass, so only a typed `/code-review:review` or `/code-review:comment-review` grades the row above — give the agent a comment pass on changed lines, or correct the claim — agent-graded — n/a
plugins/code-review/skills/comment-discipline/SKILL.md:140-158 — medium — the `gate` bullet names no Bash residual, no 50-line floor, no extension or path limits and quotes 0.4:1; README:102 states the Bash gap, the skill does not — state the residuals in the skill (163/200 lines, 8,856/14,000 bytes used) — recorded — n/a
plugins/code-review/hooks/scan.sh:324-330 — low — `// todo handle errors later`: SILENT (case-sensitive); `// TODO(ivan): …` is flagged bare though SKILL.md:60 accepts an owner — case-insensitive match, one owner rule — agent-graded (warn) — low
plugins/code-review/hooks/scan.sh:458 (+ density.sh:279) — low — first line `// This is not generated by a tool`, then 60 comment / 20 code: density SILENT; any "generated by" or "do not edit" substring in the first five lines disables both denies — anchor to marker forms — gate — low
plugins/code-review/hooks/scan.sh:501 (+ density.sh:294) — low — the third write of the same noisy file in one context passes with a warning, by design; scan.sh:517-522 already names the fix (spend the bound on a landed write) — recorded residual — n/a

### Contradictions — artifacts that ask for comments: path:line — quote ≤12 words
plugins/approaches/skills/pattern-selection/SKILL.md:28 — "record why in a comment and move on"
plugins/approaches/skills/approach-deliberation/references/strategies.md:81 — "write the README section, docstring, or commit message BEFORE the implementation"
plugins/design-kit/skills/in-codebase/SKILL.md:120 — "keep any commented-out line until its required prop has real data"
plugins/design-kit/skills/in-codebase/SKILL.md:69 — "its prop signature in a comment" (script-written scratch page)
plugins/security/hooks/write-scan.sh:304 — "if input is truly static, say so in a comment"
Consistent with the keep-cases, no link required by any: ui-libraries aceternity SKILL.md:107, web-dev vite SKILL.md:66, resilience error-handling-design SKILL.md:60, stack-scan package-hygiene SKILL.md:69.

### Reach — how the rule reaches main thread and subagents; missing routes
Main thread, routes that exist: the skill's listing description (403 chars, carries "the default is none"); the deny/warn text of scan.sh and density.sh on Write|Edit|MultiEdit only; coding-entry SKILL.md:21 loads the body, but only when `/code-architecture:coding-task` is typed or the model picks that skill; `/code-review:review` (review.md:130) and `/code-review:comment-review`.
skill-router: no row, on purpose (rules.tsv:63-65, "its own … hook is the delivery channel"). `*.ts *.js *.py *.go *.rb *.rs` route to low-cognitive-load, whose lines 50-52 carry three lines of the rule; .php .tsx .jsx .vue .java .kt .swift .cs get no comment rule by route. Live: this agent's Write of a .py file drew router nudges for low-cognitive-load and solid-principles only.
Missing on an ordinary turn (plain prompt, heredoc write, any language): the skill body arrives by no route and no hook fires; candor's preamble (plugins/candor/hooks/preamble.sh:141) has five moves and no comment clause.
Subagents, routes that exist: 11 chassis workers (templates/worker-agent.md.tmpl:37-50, shipped as plugins/*/agents/*.md), task-executor.md:63-72, debugger.md:38-40, task-runner discipline-preamble clause 7; PreToolUse deny and PostToolUse warn both reach a subagent (live: this agent's Write of `// increment the counter` was denied; density state appeared under `~/.claude/plugins/data/code-review-cc-plugins-marketplace/`).
Subagents, missing: plugins/code-architecture/agents/system-architect.md has Write/Edit and no Code shape; built-in general-purpose/claude agents get nothing at SubagentStart (subagent-skills.sh matches plugin agents only, no `bestpractices-skill:` list names comment-discipline, candor's SubagentStart preamble has no comment clause); Bash writes from any subagent are unseen.

### Recommended m2 scope — ordered, each item one line with the files it touches and the harness that must prove it
1. Bash coverage — code-review plugin: hooks/scan.sh, hooks/density.sh, hooks/hooks.json, lane.tsv, README.md (residual list stays installer-facing), skills/comment-discipline/SKILL.md, CHANGELOG.md — scripts/smoke/comment-discipline-hook-tests.sh + comment-density-tests.sh (heredoc fires, `>>` fires, non-write silent, name inside a heredoc body silent), `pc_shared_blocks` via validate.sh, 20-run latency in the CHANGELOG, context-budget.sh dynamic channel
2. Installer path exemptions and generated-marker anchoring — code-review plugin: hooks/scan.sh:166-169,458, hooks/density.sh:216-219,279, hooks/paths.sh, README.md — both smoke files + plugins/code-review/scripts/__tests__/cwd-guard.test.sh; controls: this repo's `plugins/*/hooks/*` still exempt, an installer's `scripts/deploy.sh` and `src/templates/*.tsx` judged
3. Density counter correctness (truncation, per-language classifier, shared extension list) — code-review plugin: hooks/density.sh, hooks/paths.sh — comment-density-tests.sh with controls: zero-comment Rust/C/PHP-attribute file SILENT, 60-line docstring DENY, 0.49 vs 0.40 boundary
4. Ceiling 0.2 on prose lines, small-file rule, Edit judged by run length — code-review plugin: hooks/density.sh, .claude-plugin/plugin.json description, README.md:85, SKILL.md:145,153, CHANGELOG.md (measured deny rates stated for installers) — comment-density-tests.sh
5. scan.sh detectors: untyped and padded tags, Python docstrings, paragraph runs, markup comments, banner/stamp promotion, lowercase todo; no exemption for the `shortcut:` marker (decision row; no current detector matches it) — code-review plugin: hooks/scan.sh — comment-discipline-hook-tests.sh, each new deny paired with a keep-case control (`@return BelongsTo<Workspace, $this>`, `Timeout in milliseconds; throws on a closed pool`, a two-line linked constraint, a `// shortcut: …` line); existing message strings unchanged
6. Reach — candor plugin: hooks/preamble.sh (one "no comment by default" clause, main thread and every SubagentStart); code-architecture plugin: agents/system-architect.md (Code shape); skill-router plugin: rules.tsv (low-cognitive-load rows for .php/.tsx/.jsx/.vue, note at :63 updated) — plugins/candor/scripts/__tests__/preamble-hook.test.sh, scripts/smoke/route-marker-tests.sh + router-corpus, context-budget.sh
7. Reviewer tier — code-review plugin: agents/code-reviewer.md (comment pass on changed lines) or SKILL.md:147-148 corrected — validate.sh (prose; agent-graded)
8. Reword the five contradictions — approaches plugin: skills/pattern-selection/SKILL.md, skills/approach-deliberation/references/strategies.md; design-kit plugin: skills/in-codebase/SKILL.md; security plugin: hooks/write-scan.sh:304 — validate.sh; plugins/security/scripts/__tests__/write-scan.test.sh if it asserts that string
9. Version bump + CHANGELOG entry in every touched plugin's .claude-plugin/plugin.json — check-version-bumps.sh re-run after commit

### Unmeasured
- Whether the skill or the hooks change what the model writes: plugins/code-review has no evals dir, no control arm exists.
- True/false split of the files over each ceiling. Four eyeballed: one Larastan-generics file (false deny under the raw counter), two reasoning paragraphs, one field-restating docblock set.
- Sample bias: 13 repos of one owner, likely Claude-written; php 853, tsx 1,378, ts 106, kt 27, swift 20, js/mjs 16; no py/go/rs/java/rb/c files, so the attribute and docstring miscounts are proven only on constructed inputs.
- Installer path exemptions: five paths were run (`src/templates/…tsx`, `resources/views/templates/…php`, `database/migrations/…php`, `scripts/deploy.sh`, `wp-content/plugins/shop/hooks/cart.php`, plus `packages/build/index.ts`); nested `scripts/ci/x.sh`, `src/plugins/auth/hooks/useAuth.ts` and `app/templates/*.py` are read from the glob, not run. How many installer files these patterns cover in real projects was not counted.
- Deny rate per new write; the figures are per existing tracked file. `~/.claude/comment-discipline/density-ledger.jsonl` was not read.
- Share of writes that go through Bash today: 233 of 238 is quoted from scan.sh:39-40, not re-measured.
- Run-length thresholds per added fragment; only per-file prevalence was measured.
- Latency of chunk parsing in scan.sh/density.sh on Bash calls; not built.
- Listing eviction of the comment-discipline description; context-budget.sh and scripts/validate.sh were not run by this reader.
- Scratch: `$TMPDIR/cd-audit/` (drivers and case files) remains; the repo tree is unchanged (`git status --short` shows only the pre-existing `.DS_Store`).

## Part E — cleanup inventory of the marketplace's own code

### Counts
R = .; every path below is relative to R. Scope: tracked .sh/.py/.js/.mjs/.ts plus the two `.sh.tmpl`; `.claude/` tracks 0 code files (settings.json + skill .md only).
| dir | files | comment / total lines | byte-locked block copies (functional) | header contract (keep, 1 line) | header derivation + incident history (MOVE) | of which self-printed as --help | marker/directive regex hits | banner | inline narration / change-history (est.) | inline why (keep, cut to 1 line) (est.) | inline external constraint (keep) (est.) | inline restatement / step-label (est.) | blank `#` |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| plugins/*/hooks | 56 | 6389 / 14276 | 1911 | 170 | 1981 | 0 | 13 | 47 | ~1560 | ~270 | ~40 | ~78 | 319 |
| plugins/*/scripts (non-test) | 57 | 2581 / 11947 | 22 | 214 | 1440 | 819 (+124 inline), 26 scripts | 4 | 36 | ~250 | ~255 | ~70 | ~60 | 230 |
| plugins/*/scripts/__tests__ | 80 | 1974 / 13325 | 0 | 195 | 531 | 0 | 0 | 345 | ~350 | ~190 | 0 | ~290 (case labels) | 74 |
| plugins/* other (craft-gates template, serve.py, eval scaffolds) | 10 | 942 / 3546 | 0 | 87 | 204 | 0 | 0 | 4 | ~460 | ~65 | 0 | ~30 | 92 |
| scripts (top level) | 14 | 1658 / 4566 | 0 | 37 | 552 | 69 (turn-cost.sh) | 3 | 17 | ~690 | ~210 | ~28 | ~18 | 103 |
| scripts/lib | 2 | 1824 / 3472 | 0 | 116 | 1266 | 0 | 13 | 1 | ~213 | ~18 | ~15 | ~5 | 177 |
| scripts/smoke | 36 | 1424 / 6922 | 0 | 99 | 391 | 0 | 11 | 97 | ~295 | ~166 | ~15 | ~280 | 70 |
| scripts/smoke/validate-fixtures | 12 | 229 / 1087 | 0 | 27 | 68 | 0 | 0 | 19 | ~80 | ~2 | 0 | ~21 | 12 |
| templates/*.sh.tmpl | 2 | 98 / 161 | 0 | 2 | 1 | 0 | 2 | 0 | ~75 | ~14 | 0 | 0 | 4 |
| TOTAL | 269 | 17119 / 59302 (29%) | 1933 | 947 | 6434 | 888 (+124) | 46 | 566 | ~3970 | ~1190 | ~170 | ~780 | 1081 |
Method: census for every column except the four "est." ones — one Python pass over all 269 files (full-line comments, py docstrings, JS block comments; shell heredoc bodies skipped unless fed to an interpreter; header = first comment block of a file or the block touching a function definition; contract = its first ≤2 lines before the first blank comment line). The est. columns split the 6,112 inline lines by hand-reading a seeded random sample of 22 inline blocks per directory (all 12 for templates), 188 blocks, weighted by lines. Commented-out code: 0 found. Bare TODO/FIXME: 0 outside test fixtures. Trailing same-line comments: ~557, unclassified, not in the table. Marker column counts prose mentions too; functional markers in code files are 28 (3 context-key-ok, 3 TWIN, 8 generated-header, 12 shellcheck, 2 noqa).
The 1,933 byte-locked lines are copies of 183 comment lines in 6 source files, `templates/blocks/*.md` (418 lines, outside the 269). Largest single file: `scripts/lib/plugin-checks.sh`, 1775 comment / 3315 lines, 54 functions, 1,501 header lines.
### Machine-read comments and markers — path:line — who reads it — consequence if removed
- `plugins/hindsight/hooks/skill-use.sh:67`, `plugins/overseer/hooks/track-read.sh:19`, `plugins/task-runner/hooks/spawn-cap.sh:79` `# context-key-ok:` — `pc_context_key` (`scripts/lib/plugin-checks.sh:2242`, whole-file grep) — FAIL `context-keyed-on-session`. skill-use.sh passes one line earlier (:2241) on a COMMENT mention of `transcript_path`; once that comment goes the marker is all that holds it.
- `# TWIN: <path> is an identical copy save this line` at `plugins/taskmaster/hooks/preview-guard.sh:46`, `plugins/ui-ux/hooks/preview-guard.sh:46`, `plugins/ui-ux/scripts/contrast.mjs:19` — `pc_twin_files` (`plugin-checks.sh:1360`, exact sentence) and `scripts/smoke/preview-guard-tests.sh:39-43` — a reword gives `twin … (unparseable marker)`; twins are compared whole, comments included, so both copies (and `plugins/craft-layer/template/craft-gates/contrast.mjs`) must be cleaned identically.
- Line 2 `# generated from templates/…` in the 8 generated hooks and both `.tmpl:2` — `scripts/validate.sh:402,428`, `scripts/smoke/chassis-template-tests.sh:95,144` — FAIL "chassis-shaped file has no generated header".
- Shared-block comment text — `pc_shared_blocks` (`plugin-checks.sh:406`, whole-block substring) for 5 blocks, `generate.sh --check` for phase-guard in the 5 generated reminders — `shared-block-drift`. `plugins/design-kit/hooks/unread-pick.sh` carries phase-guard by hand; no gate holds that copy.
- `plugins/git-workflow/hooks/no-ai-trailer.sh:30` (first comment line with `CLAUDE_AI_TRAILER=`) — `scripts/generate.sh:409-410` scrapes it into the README "Turning things off" row — reword or removal gives `generate.sh --check` DRIFT on README.md.
- Any hook comment containing `${CC_*:-`, `${CLAUDE_*:-`, `${*_BOOST:-`, `${*_STOP_GATE:-` — `pc_switch_reads` (`plugin-checks.sh:485`; that grep is not comment-stripped) feeds the README table and `pc_offswitch_named` — none comment-only today; a new comment can add a phantom row.
- `plugins/skill-router/hooks/prime.sh`, any text `add <word> ` — `scripts/validate.sh:465` and `pc_prime_coverage` (`plugin-checks.sh:2658`) read comments too — a comment saying "add foo " FAILs as an unknown skill; 0 comment hits today.
- `plugins/skill-router/hooks/route-prompt.sh`, lines matching `printf .%s. "$head" | grep` — `pc_route_prompt_greps` (`plugin-checks.sh:3311`) counts comment lines, budget 4. Trailing comments on code lines of route.sh / route-prompt.sh are not stripped by `validate.sh:471` / `plugin-checks.sh:3281`: a skill name or `/plugin:cmd` there FAILs.
- Marker tokens anywhere in a hook, including inside a sentence: `env-shebang-ok:` (`plugin-checks.sh:240`), `cwd-mkdir-ok:` (:302), `state-root-ok:` (:373), `offswitch-ok:` (:506), `marker-key-ok:` (:2327), `harness-payload-ok:` (:2590, harness files) — a pointer line that quotes one silently exempts the file; none present today.
- TSV comment markers (not code files, same hazard): `plugins/skill-router/rules.tsv` 24 `# co-fire-ok:` lines (`plugin-checks.sh:1027,1071`), `plugins/ui-ux/lane.tsv:14` `# lane-cofire-ok:` (:1705, :1837), `# generated:start` / `# generated:end` in 14 `plugins/*/lane.tsv` (`scripts/generate.sh:184-206`).
- Header-as-help by LINE NUMBER, `sed -n 'A,Bp' "$0"`, 15 call sites: `plugins/code-review/scripts/debt-scan.sh:46`; design-kit `artifact-publish.sh:32`, `board-export.sh:23`, `codebase-cleanup.sh:19`, `codebase-scaffold.sh:41`, `deck-export.sh:26`, `dk-usage.sh:44`, `dk.sh:87` and `:373`, `preview.sh:24`; devops `plan-audit.sh:101`, `workflow-audit.sh:36`; `plugins/git-workflow/scripts/scratch-ignore.sh:45`; `plugins/overseer/scripts/skill-path.sh:18` — a shrunk header makes --help print code. Three already overrun into code: artifact-publish.sh (line 24), codebase-cleanup.sh (15-16), preview.sh (15).
- Header-as-help to a sentinel: `plugins/design-kit/scripts/snapshot.sh:77`, `plugins/overseer/scripts/program.sh:102`, `scripts/turn-cost.sh:95` — the help text IS the header (70 / 66 / 69 lines).
- Header-as-help, every column-0 comment, `grep -E '^#' "$0"`, 11 scripts: `plugins/stack-scan/scripts/licence-scan.sh:54`; task-runner `negative-control.sh:103`, `reduction-record.sh:60`, `review-skip.sh:41`, `sweep-residual.sh:53`; taskmaster `card-shape-lint.sh:69`, `goal-ledger-check.sh:34`, `skills-stamp-lint.sh:48`, `spec-ledger-lint.sh:66`, `verify-teeth-lint.sh:115`; `plugins/testing/scripts/flake-hunt.sh:43` — 519 lines printed, 124 of them inline comments. No harness asserts help text; usage tests match `usage error:` printed by code.
- `scripts/gate-coverage.sh:37,39` counts check NAMES, comments included — 44 comment mentions in validate.sh/context-budget.sh inflate WIRED; the HARNESS column rests on a comment-only mention for pc_skill_budget (`scripts/smoke/guard-tests.sh`), pc_prime_coverage (`prime-map-tests.sh`), pc_listing_entry_cost (`plugins/all-plugins/scripts/__tests__/all-plugins.test.sh`), pc_false_standing (`hook-syntax-tests.sh`), pc_plugin_dependencies (`chassis-template-tests.sh`), pc_harness_payload (8 harnesses) — cleaning flips those to NONE (report-only, never fails).
- Fixture comments are test DATA: `scripts/smoke/lanes-tests.sh:82,136,148,155,518-524` and `:429-451`, `scripts/smoke/validate-fixtures/gate-fixtures-check.sh:97,212`, `validate-fixtures/rules-collision.tsv:2`, every non-harness file under `scripts/smoke/validate-fixtures/` and `scripts/smoke/router-corpus/` — do not clean.
- Harnesses that read gate CODE text (comment-safe, refactor-unsafe): `scripts/smoke/cmd-skill-shadow-tests.sh:68`, `renames-ledger-tests.sh:115`, `validate-fixtures/deference-check.sh:95`, `stray-dir-check.sh:78`, `role-floors-check.sh:123-124`, `lanes-tests.sh:342`, `prompt-route-tests.sh:290-296`, `done-gate-tests.sh:121,139-140`; satisfied by a comment mention alone: `marker-key-tests.sh:109,154`, `plugins/stack-scan/scripts/__tests__/pick.test.sh:31`; `plugins/all-plugins/scripts/__tests__/all-plugins.test.sh:358` needs `main "$@"` as the last line.
- `scripts/smoke/prompt-route-tests.sh:38-40` copies `plugins/skill-router/hooks/route-prompt.sh` at start and copies it BACK on exit — an edit made to that hook while the harness runs is reverted silently.
- Tool directives (keep): 12 `# shellcheck` (7 smoke harnesses, `scripts/generate.sh:63`, flake-hunt.sh, pick.sh, candor measure.sh); 2 `# noqa: BLE001` (`plugins/design-kit/scripts/system-extract.py:619,636`).
- Nothing reads the result: comment-discipline's hooks exempt `*/scripts/*.sh`, `*/templates/*`, `*/plugins/*/hooks/*` (`plugins/code-review/hooks/scan.sh:166-167`, `density.sh:217-218`) — 247 of 269 files; cleanliness of the cleanup has standing `recorded`.
### Line-number citations at risk — citing file:line → cited file:line
- `CLAUDE.md:329` → `scripts/done-gate.sh:7`; `CLAUDE.md:276` (`:36`) → `scripts/check-version-bumps.sh:36`; `CLAUDE.md:378` (`:2-3`) → `scripts/authoring-guard.sh:2-3`. All three accurate today.
- `README.md`, `.claude/skills/**`, plugin README / SKILL / commands / agents → none into code (`.claude/skills/authoring-skills/references/doctrine.md:113-119` cites lines of a SKILL.md).
- `plugins/git-workflow/skills/branch-completion/references/marketplace-scratch.tsv` (shipped, nothing checks the numbers), 30 citations: :19→`plugins/design-kit/scripts/dk.sh:35`; :20→`codebase-scaffold.sh:31`; :23→`plugins/craft-layer/template/craft-gates/gates.spec.ts:192`; :25→`plugins/task-runner/hooks/drift.sh:121`; :26→`plugins/skill-router/hooks/compact-capsule.sh:145`; :27→`plugins/overseer/scripts/program.sh:230`; :29→code-review `density.sh:244`, `scan.sh:491`, `verbosity.sh:194`; :30→`review-debt.sh:204`; :31→skill-router `route.sh:425`, `summary.sh:125`, `route-prompt.sh:142`, `compact-capsule.sh:165`; :32→`plugins/candor/hooks/gate.sh:315`; :33→`plugins/testing/hooks/test-shape.sh:189`; :34→`plugins/ui-ux/hooks/palette-default.sh:186`; :38→`plugins/command-guard/hooks/destructive-guard.sh:450`; :42→`summary.sh:163`, `scripts/turn-cost.sh:313`; :43→hindsight `collect.sh:96`, `skill-use.sh:86`, `scripts/outcome.sh:23`, `scripts/turn-cost.sh:321`; :44→`density.sh:433`, `verbosity.sh:245`; :45→candor `mode.sh:90,194`, `activate.sh:64`; :46→`destructive-guard.sh:885`.
- Of those 30, 28 land on the code line today (dk.sh:35 and destructive-guard.sh:450 land on comments); every one moves when its file's header shrinks.
- `templates/blocks/phase-guard.md:3` → `scripts/lib/template-engine.sh:50` (already off by one, the hardcode is :51); copied into 5 generated reminders at :32 and `plugins/design-kit/hooks/unread-pick.sh:109`.
- Code comments citing code lines, 20: `scripts/lib/plugin-checks.sh:265`→`plugins/overseer/hooks/track-read.sh:30-31`; `:2218`→`plugins/skill-router/hooks/route.sh:16-18`; `:2619`→`scripts/generate.sh:216-221`; `plugins/skill-router/hooks/prime.sh:65`→`scripts/generate.sh:216-221`; `route.sh:321`→`route-prompt.sh:26`; `route.sh:375`→`track-read.sh:30`; `route-prompt.sh:215`→`plugins/testing/hooks/test-shape.sh:90`; `plugins/security/hooks/write-scan.sh:239`→`plugins/ask-ledger/hooks/ledger.sh:53`; `plugins/taskmaster/scripts/goal-ledger-check.sh:48`→`plugins/task-runner/hooks/scope.sh:31-35`; `plugins/testing/hooks/test-shape.sh:167` and `plugins/ui-ux/hooks/palette-default.sh:163`→`track-read.sh:30-31`; `scripts/smoke/prompt-route-tests.sh:155`→`route.sh:156`; `scripts/smoke/route-marker-tests.sh:225`→`route.sh:118`.
- Of 9 of those spot-checked, 8 are already stale (only track-read.sh:30 holds) — replace with function-name citations rather than renumber.
- Dated records, falsified by any shift: `rationale/` 147 citations in 21 files (marketplace-review-2026-07-28.md 26, marketplace-trend-audit-2026-09-16.md 25, marketplace-coverage-review-2026-08-02.md 16); root `CHANGELOG.md:254`→`scripts/validate.sh:559-561`; plugin CHANGELOGs 9 (skill-router 3, code-architecture 2, task-runner 2, approaches 1, candor 1).
### Chassis-generated and byte-compared sets
- From `templates/reminder-hook.sh.tmpl` (clean there, then `scripts/generate.sh --write`): `plugins/api-design/hooks/remind.sh`, `plugins/approaches/hooks/remind.sh`, `plugins/approaches/hooks/consult-remind.sh`, `plugins/debugging/hooks/remind.sh`, `plugins/taskmaster/hooks/remind.sh` (274-282 lines, 170-177 comment lines each).
- From `templates/boost-hook.sh.tmpl`: `plugins/craft-layer/hooks/ultra-craft.sh`, `plugins/task-runner/hooks/ultra-assess.sh`, `plugins/taskmaster/hooks/ultra.sh`.
- From `templates/worker-agent.md.tmpl` (not code, same gate): 10 agents in database, devops, laravel, resilience (2), security, testing, ui-ux (2), web-dev.
- Also byte-compared by `generate.sh --check`: the generated block in 14 `plugins/*/lane.tsv`, `plugins/stack-scan/skills/plugin-scout/references/catalog.md`, README.md between the off-switch markers. `--write` patch-bumps each changed plugin once PER RUN. `templates/samples/*.json` are inputs to `scripts/smoke/chassis-template-tests.sh`, not compared outputs; the only golden is built inside `scripts/smoke/template-engine-tests.sh:69`.
- Byte-locked pasted blocks: option-resolver 43 copies, state-root 29, plugin-state 11, bash-write-targets 10, bash-write-chunks 4, phase-guard 6 — 52 distinct carriers (8 generated, 44 hand) in 20 plugins, including `plugins/design-kit/scripts/dk.sh` and `plugins/taskmaster/scripts/phase-sentinel.sh`.
### Refactors that delete the need for a comment — top 30
- `scripts/lib/plugin-checks.sh:122,127,142` — 200 / 14000 / 300 unnamed under a 71-line header — `SKILL_BODY_MAX_LINES`, `SKILL_BODY_MAX_BYTES`, `SKILL_LINE_MAX_CHARS` (also `:695` 198, `:3072` 500, `scripts/validate.sh:169` 700, `:713` 25).
- `scripts/lib/plugin-checks.sh:229-250` (again near :294, :364, :498, :2177, :2231, :2318) — hooks.json walk copied 7 times with locals `hj d p sh rel` — one `_pc_registered_hooks <root> [events]` printing `plugin<TAB>script`.
- `scripts/lib/plugin-checks.sh:121,126,694,2419,2506` — frontmatter-strip awk repeated 5 times — `_pc_skill_body <file>`.
- `scripts/lib/plugin-checks.sh:879-987` (pc_removed_refs) — 109-line body, 78 comment lines each glossing one regex alternation — one named variable per reference shape, joined.
- `scripts/lib/plugin-checks.sh:813-835` (pc_jargon) — regexes explained by example sentences — the sentences are already assertions in `scripts/smoke/validate-fixtures/parity-check.sh:190-205`; keep the test, drop the prose.
- `scripts/lib/plugin-checks.sh:1786-1906` (pc_lanes_adjacency, 121 lines) and `:1937-2020` (pc_lanes_coverage, 84 lines, 23 comment lines) — split per artifact kind (`_lanes_cov_agents`, `_lanes_cov_prompt_hooks`, `_lanes_cov_deny_hooks`).
- `scripts/lib/plugin-checks.sh:484` (pc_switch_reads) — 58-line header for a 12-line body; `shape` packs four name families — name each, and name the host-variable exclusion list at :491.
- `scripts/lib/plugin-checks.sh:1030` — `local -a P S` under "# collect content rows" — `patterns`, `skills`; `scripts/lib/template-engine.sh:116,125` "pass 1 / pass 2" — two named awk functions.
- `scripts/validate.sh:717-960` — 23 `x_gap=$(pc_x …)` blocks under 111 comment lines — one table of (check, args, tier, message) run by a loop; blocked until the 7 wiring assertions listed above are rewritten with it.
- `scripts/validate.sh:205-232` `rhit ohit hhit dhit mdf`, `:20` `pj`, `:456` `SR`, `:540` `RP`, `:748` `lo lf` — spell them out (`removed_ref_hits`, `md_file`, `plugin_json`, `router_dir`, `lane_file`).
- `scripts/validate.sh:433,571,717,970,996,1006,1020` — section banners (two still carry card labels "W2-M2", "W2-M5") over 1,044 lines with 7 functions — one function per section called from `main`.
- `plugins/candor/hooks/gate.sh:328,650,738,794,863` — five CLAUSE banners, only clause 4 is a function (`run_clause`, :353) — `clause_run_incomplete`, `clause_fabricated_citation`, `clause_unevidenced_reversal`, `clause_naked_completion`, `clause_lockfile_drift`.
- `plugins/candor/hooks/gate.sh:346,521,620,712,761,812` — 180 / 200 / 4000 / 25 / 400 / 30 unnamed — `INFLIGHT_TTL_MIN`, `SAID_TAIL_LINES`, `TRANSCRIPT_TAIL_LINES`, `MAX_CITATIONS_CHECKED`, `EVIDENCE_MIN_BYTES`, `CLAIM_WINDOW_LINES`.
- `templates/reminder-hook.sh.tmpl:27-57` — four refusals glossed by 30 comment lines — `is_machinery_prompt`, `is_about_hooks`, `is_own_echo`, `is_question_only`.
- `templates/reminder-hook.sh.tmpl:82-97` — claim, compare, sweep under 26 comment lines — `claim_rank`, `best_rank`, `sweep_stale_markers`.
- `-mmin +1440` literal in 11 hand hooks and the template (`plugins/ask-ledger/hooks/ledger.sh:111`, candor `preamble.sh:138`, `avert.sh:109`, `plugins/code-review/hooks/conventions.sh:293`, `plugins/secret-scanning/hooks/unicode-scan.sh:275`, `plugins/security/hooks/write-scan.sh:245`, `plugins/skill-router/hooks/route-prompt.sh:240`, taskmaster `card-lint-observe.sh:171`, `clarify-gate.sh:70`, both `preview-guard.sh:134`, `templates/reminder-hook.sh.tmpl:97`) — `MARKER_TTL_MIN=1440`.
- Scrub-then-head pipeline in 6 places with windows 200 / 400 / 600 (`templates/reminder-hook.sh.tmpl:27-28`, `templates/boost-hook.sh.tmpl:34-35`, `plugins/ask-ledger/hooks/ledger.sh:100`, `plugins/candor/hooks/mode.sh:141`, `preamble.sh:124`, `plugins/skill-router/hooks/route-prompt.sh:165`) — a shared block `cc_prompt_head <prompt> <chars>`.
- `head -n 8` at `plugins/command-guard/hooks/config-guard.sh:261`, `plugins/secret-scanning/hooks/unicode-scan.sh:340`, `plugins/security/hooks/write-scan.sh:209`, `plugins/skill-router/hooks/route.sh:336` — `MAX_BASH_TARGETS=8`; the name states the cap the header is asked to state.
- `plugins/code-review/hooks/density.sh:434` and `verbosity.sh:246` — 1048576 — `LEDGER_MAX_BYTES`; `density.sh:279` and `scan.sh:458` duplicate the generated-file probe — `is_generated_file` in `hooks/paths.sh`.
- `plugins/skill-router/hooks/route.sh:589,650,657,681` — four step banners inside the main block — `nudge_high_confidence`, `deliver_envelope`, `collect_low_confidence`, `persist_state`.
- `plugins/skill-router/hooks/route.sh:494-543` — 49 comment lines specifying the marker grammar above one function with locals `alt m neg req rc` — grammar to the rationale file, locals renamed.
- `plugins/command-guard/hooks/destructive-guard.sh:82-948` — 19 banner lines partition 1,031 lines — one function or rule table per family; the banner text becomes the name.
- `plugins/task-runner/scripts/behavioral-gate.sh:209,267,309,327,437` — `(a) CLASSIFY / (b) / (c)` banners, `:216` nine `HAS_*` flags — `classify_changed`, `run_own_tests`, `zero_check`, one `langs` list.
- `scripts/remove-plugin.sh:126,142,156,163,176,189` — steps numbered `# 1.` to `# 6.` in one flow — six named functions.
- Help by line number, 15 call sites (`plugins/design-kit/scripts/dk.sh:87` `'2,51p'`, `:373` `'7,24p'`, …; 3 already print code) — a `usage()` heredoc per script, so the header stops being load-bearing.
- Help by `grep -E '^#' "$0"`, 11 scripts (`plugins/taskmaster/scripts/verify-teeth-lint.sh:115` prints 37 inline comment lines, `plugins/task-runner/scripts/negative-control.sh:103` prints 29) — the same `usage()` heredoc.
- `scripts/generate.sh:409-410` — README cell scraped from a hook comment; `:437` 104 unnamed — read the sentence from a manifest key, `NOTE_MAX_CHARS=104`.
- `scripts/context-budget.sh:526-527` (97 / 103) and `:861` (15) — `NEAR_BAND_PCT`, `DRIFT_WARN_PCT`; `scripts/done-gate.sh:197-198` 10 — `MAX_FINDINGS_SHOWN`.
- `plugins/taskmaster/hooks/preview-guard.sh:46` ↔ `plugins/ui-ux/hooks/preview-guard.sh:46` — hand-kept twin needing a marker comment and two gates — render both from one chassis template (same for `plugins/ui-ux/scripts/contrast.mjs:19`).
- `plugins/craft-layer/template/craft-gates/divergence.mjs:780,861,1069,1635,1646` — section banners in a 1,771-line file — one module per assertion family; `gates.spec.ts:69,172,406` likewise.
### rationale/ layout + CLAUDE.md sentences to change
- Precedent to follow: `rationale/2026-09-26-taskmaster-prose-derivations.md` — text MOVED verbatim under a heading naming its source file, a pointer left behind (rationale/README.md forbids keeping a second copy).
- New directory `rationale/derivations/`, undated file names because code points at them. Anchors: `## <repo path>` then `### <function or section name>`; pointer in code = `# Why, limits, history: rationale/derivations/<file>.md § <name>` — a name, never a line number, and never a marker token.
- `plugin-checks-hooks.md` (13 checks, 330 header lines: hook_timeout, hook_shebang, hook_exec, cwd_validated, state_root, shared_blocks, switch_reads, offswitch_named, context_key, marker_key, harness_payload, phase_guard, twin_files); `plugin-checks-lanes.md` (8, 188, plus the 41-line format block at `plugin-checks.sh:1500`); `plugin-checks-routing.md` (9, 214); `plugin-checks-budget-listing.md` (7, 259); `plugin-checks-docs-refs.md` (11, 397 + 116 inline); `plugin-checks-manifests.md` (3, 102).
- `gate-scripts.md` — one `##` per script under `scripts/` (validate.sh's per-gate prose, context-budget.sh incl. `LISTING_*`, generate.sh, done-gate.sh, authoring-guard.sh, gate-coverage.sh, the other 8); `templates-and-blocks.md` — 6 blocks, 2 templates, template-engine.sh; `plugin-<name>.md` — one per code-bearing plugin (26), `##` per hook or script; `harnesses.md` only for incident notes a test name cannot carry.
- Stays in the script: the one-line contract (for a `pc_*`: args, the output token, return code), help text as a `usage()` heredoc, one-line linked external constraints, functional markers, `no-ai-trailer.sh:30` until generate.sh stops scraping it.
- `CLAUDE.md:128-131` "Every derivation below lives in the check's own header … carries a header explaining …" → derivations live in `rationale/derivations/plugin-checks-<family>.md`; the header is a contract line plus pointer. `:139` "restating a check's header here" → "a check's derivation".
- `CLAUDE.md:143` "the measurement that made it is in its header"; `:155` "the check's header says what a good one looks like"; `:202` "derivation in the script's `LISTING_*` header"; `:304` "its own header says a hit is a mention"; `:340` "its header says why"; `:350` "its own header says it needs a live model" → each repointed to its rationale anchor.
- `CLAUDE.md:276` drop `:36` and keep the quoted `git diff`; `:329` `scripts/done-gate.sh:7` → rationale anchor; `:378` drop `:2-3`. Add one bullet to "Where documentation lives" naming `rationale/derivations/` as the home of gate and hook derivations.
- The Honest-limitation gloss ("a gate names what it does NOT catch") needs its location restated: the residual list is in the rationale file, cited from the header. Same edit in `.claude/skills/authoring-skills/references/doctrine.md:57`.
- Other sentences the move falsifies: `.claude/skills/hook-bash-writes/SKILL.md:41,69,71` ("name these in the hook header"); `.claude/skills/chassis-workflow/SKILL.md:39` ("Its header comment is the authoritative contract"); `scripts/generate.sh:447` → `README.md:187` ("read out of its header", generated text); `plugins/design-kit/README.md:174`; `plugins/devops/README.md:27,39`; `plugins/skill-router/README.md:103` (quotes the route-prompt.sh header verbatim); `plugins/ui-ux/README.md:106`; `plugins/taskmaster/skills/verify-teeth/SKILL.md:38`.
- Reach, to state not hide: `rationale/` is a repo path, not shipped, so an installer of one plugin loses the in-file residual lists unless the plugin README carries them.
### Batches — | batch | files | proving harnesses | plugins to bump | risk |
| batch | files | proving harnesses | plugins to bump | risk |
|---|---|---|---|---|
| B1 blocks + templates (atomic, lands first) | 8 hand-edited: `templates/blocks/*.md` (6), `templates/{reminder,boost}-hook.sh.tmpl`; then mechanical only: `generate.sh --write` (8 hooks) and verbatim re-paste into 44 carriers — exceeds 12 by construction | chassis-template-tests, template-engine-tests, option-resolver-tests, bash-write-targets-tests, preserve-block-tests, validate-fixtures/gate-fixtures-check, hook-guard-tests, hook-syntax-tests, plugin-data-state-tests, lanes-tests, every `plugins/*/scripts/__tests__/*.test.sh`, `generate.sh --check` | all 20 carriers: 6 auto (api-design, approaches, craft-layer, debugging, task-runner, taskmaster), 14 by hand (ask-ledger, brain, candor, code-review, command-guard, database, design-kit, devops, hindsight, secret-scanning, security, skill-router, testing, ui-ux) | highest |
| B2 check library | `scripts/lib/plugin-checks.sh`, `scripts/lib/template-engine.sh` (+ 6 rationale files) | cmd-skill-shadow, done-gate, hook-budget, lanes, marker-key, option-resolver, prompt-route, renames-ledger, rules-overlap, scout-names, source-of-truth, prime-map, guard-tests, template-engine-tests, all 5 validate-fixtures checks; `gate-coverage.sh` output diffed before/after | none | high — the session's own Stop hook (done-gate.sh) and PostToolUse hook source this file |
| B3 skill-router | 7 hooks, 3 tests (10) | 3 own tests, prompt-route-tests, route-marker-tests, prime-map-tests, enablement-filter-tests, versioned-layout-tests, rules-overlap-tests, validate-fixtures/parity-check, validate.sh | covered by B1; CHANGELOG entry | high — never concurrent with any run of prompt-route-tests |
| B4 gate scripts | validate.sh, context-budget.sh, generate.sh, done-gate.sh, authoring-guard.sh, gate-coverage.sh (6) + CLAUDE.md | done-gate-tests, guard-tests, lanes-tests, cmd-skill-shadow-tests, renames-ledger-tests, prompt-route-tests, hook-budget-tests, chassis-template-tests, preserve-block-tests, 5 validate-fixtures checks; context-budget.sh run alone | none | high |
| B5 twins + craft-layer + ui-ux | taskmaster preview-guard.sh; ui-ux 2 hooks, contrast.mjs, 1 test; craft-layer contrast.mjs, divergence.mjs, gates.spec.ts, playwright.config.ts, technique-fingerprint.py, 2 tests (12) | preview-guard-tests, lanes-tests, craft-gates.test, technique-fingerprint.test, palette-default.test | covered by B1 | medium-high |
| B6 candor ×2 | 5 hooks + 5 scripts (10); 7 tests + 3 eval scaffolds (10) | 7 own tests, completion-gate-hook-tests, evidence-gate-hook-tests | covered by B1; CHANGELOG | medium-high |
| B7 write guards | command-guard 4, secret-scanning 4, security 2 (10) | 5 own tests, bash-write-targets-tests, gate-fixtures-check | covered by B1 | medium-high |
| B8 code-review | 6 hooks, debt-scan.sh, 4 tests (11) | 4 own tests, comment-density-tests, comment-discipline-hook-tests, verbosity-hook-tests | covered by B1; CHANGELOG | medium |
| B9 testing + database | 6 + 2 (8) | 4 own tests, bash-write-targets-tests | covered by B1 | medium |
| B10 task-runner ×2 | 6 hooks + 6 scripts (12); 1 script + 11 tests (12) | 11 own tests, behavioral-verification-tests, completion-gate-hook-tests | covered by B1; CHANGELOG | medium |
| B11 taskmaster ×2 | 2 hooks + 9 scripts + serve.py (12); 9 tests (9) | 9 own tests, hook-guard-tests | covered by B1 (no CHANGELOG: WARN) | medium |
| B12 design-kit ×3 | hook + 9 .sh scripts (10); 8 py/mjs + 4 tests (12); 12 tests (12) | 16 own tests | covered by B1; CHANGELOG | medium |
| B13 other scripts | check-doc-staleness, check-version-bumps, eval-cases, run-evals, host-constants, official-validate, remove-plugin, turn-cost (8) | eval-case-tests, run-evals-tests, official-validate.sh; NONE for check-doc-staleness, check-version-bumps, remove-plugin, turn-cost | none | medium-low |
| B14 hindsight + git-workflow | 7 + 4 (11), plus the scratch ledger's citations | 5 own tests, plugin-data-state-tests, `generate.sh --check` (README row) | git-workflow; hindsight covered | medium-low |
| B15 devops + stack-scan | 5 + 6 (11) | 5 own tests | stack-scan (CHANGELOG); devops covered | low |
| B16 approaches + ask-ledger + brain + all-plugins | 4 + 4 + 1 + 2 (11) | 5 own tests; brain inject.sh has NONE | all-plugins; rest covered | low |
| B17 overseer + toolchain-experts + ultra-deep-research | 8 + 2 + 2 (12) | 3 own tests | all three (overseer and ultra-deep-research have CHANGELOG) | low |
| B18 smoke harnesses ×4 | 41 harness .sh in 12 / 12 / 12 / 5; the 7 fixture files excluded | each harness on itself, plus one planted-defect rerun, since a cleaned harness passing proves little | none | low for the tree, weakest proof |
Bump rule as measured: `check-version-bumps.sh` compares to the base ref, so one bump per plugin covers the whole branch; any file under `plugins/<p>/` except root README/CHANGELOG/ROADMAP counts, tests included; 17 of the 26 code plugins have a CHANGELOG and need an entry for the final version (gate), 9 draw a WARN; the gate reads HEAD, so rerun it after committing.
### Unmeasured
- No smoke harness or plugin test was run. Run on this tree: `bash scripts/validate.sh` (rc 0, 0 FAIL, 9 WARN), `bash scripts/generate.sh --check` (rc 0), `bash scripts/gate-coverage.sh` (51 checks, 48 with a harness, 3 NONE).
- The four est. columns come from 188 hand-read blocks; treat each as ±15 points. Trailing comments (~557) are a regex count.
- Classifier blind spots: JS `/* --- x */` banners count as inline; comments inside awk/python programs embedded in shell strings count as shell comments; fixture hook bodies in harness heredocs whose opener names `sh`/`bash` are counted (seen in gate-fixtures-check.sh).
- The 147 rationale and 10 CHANGELOG line citations were counted, not verified; code-to-code citations were spot-checked 9 of 20.
- Not counted: `plugins/candor/scripts/statusline.ps1`, comments in .tsv/.yaml/.json/.md, the 10 generated agents.
- Whether worker sessions run code-review's hooks: 4 governed files sit over the 0.4:1 ceiling today (`plugins/candor/scripts/shrink.mjs` 0.58, craft-gates `divergence.mjs` 0.46, `gates.spec.ts` 0.45, `plugins/taskmaster/scripts/theme-axis-check.py` 0.42), so a whole-file Write there is denied until the ratio drops; an Edit is not.
- Whether B1's 44-carrier re-paste should count against the 12-file cap, or the block comments (183 source lines) stay as they are — a decision for the orchestrator, not measured.
