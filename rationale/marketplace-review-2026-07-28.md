# Marketplace review — 2026-07-28

Adversarial, review-only. 57 leaf plugins + 8 bundles, 124 `SKILL.md`, 89
`references/*.md`, 29 agents, 16 `hooks.json`, 32 `review.md` commands.
Context numbers from `bash scripts/context-budget.sh` (measured, 2026-07-28).

Mechanism labels: `PROSE` / `COMMAND` / `HOOK-WARN` / `HOOK-ASK` / `HOOK-BLOCK` / `GATE`.

---

## 1. Verdict

1. **The evidence gate is disarmed by the word "failing" — measured, not inferred.**
   `plugins/code-architecture/hooks/evidence-gate.sh:76` matches its honesty-escape
   regex — which includes bare `fail|fails|failing|failed|failure` — against the
   whole assistant tail (`:63-67`, `tail -30` lines of assistant text), then `exit 0` at `:77`
   *before* the mutation/evidence scan. Reproduction in §8; results:

   | Synthetic turn (one `Edit`, no exec after) | Observed exit | Should be |
   |---|---|---|
   | `Fixed the failing test - should work now.` | **0 (passes)** | 2 |
   | `Fixed it. The old failure is gone.` | **0 (passes)** | 2 |
   | `Done - did not run the suite.` | 0 (passes) | 0 ✓ |
   | `Implemented the parser. All set.` | 2 (blocks) | 2 ✓ |

   The gate works exactly until the turn mentions a failure — i.e. it fails on
   bug-fix turns, which is most of them. Largest single-change effect on failure #3.
2. **Output discipline is `MISSING`, and 27 SKILL.md lines actively demand
   narration.** Chattiness is not an absence of suppression; it is a marketplace
   requirement. Any "be concise" rule added as prose loses to those 27.
3. **Comment enforcement is `HOOK-WARN` by explicit design**
   (`plugins/comment-discipline/hooks/scan.sh:12-14`), and PostToolUse fires
   *after* the write. The comments are already on disk when the warning arrives.
4. **`quality-suite` is 14 plugins / 2,908 always-on tokens, of which 11 are pure
   `PROSE`.** Its three hook-carrying members (`comment-discipline` warn,
   `secret-scanning` deny, `database` ask) enforce nothing about code quality.
5. **7 skills fire on every code edit with the same trigger phrase** ("when
   writing or reviewing code"). Two of them contradict each other on interfaces.
6. **`everything` = 10,723 always-on tokens** before a single file is read, and 14
   plugins ship per-prompt/per-tool hook output the budget script does not meter.
7. **Nothing compares the delivered result to the original request.**
   `taskmaster:coverage` compares cards↔spec and says so
   (`skills/coverage-check/SKILL.md:14`). `drift-review` is the only request-level
   check and it is `PROSE` + `COMMAND`.
8. **Nothing measures anything.** Zero eval or benchmark artifacts under
   `plugins/` or `scripts/`. `scripts/smoke/canary.sh:2` is the only live-model
   harness and is deliberately not a CI step. Every behavioral claim in this
   marketplace is unmeasured.
9. **`hindsight` is write-only in practice** — `hooks/collect.sh:6` appends to
   `$HOME/.claude/hindsight/<slug>/ledger.jsonl`; the only reader is the
   `/hindsight:harvest` `COMMAND`.
10. **Honest conclusion: the marketplace is too large for its enforcement mass.**
    3 real gates (2 Stop, 1 PreToolUse-deny) carry 124 skills. Cut list in §7.

---

## 2. Coverage matrix

### Named axes

| # | Capability | Plugin | Evidence | Mechanism | Verdict |
|---|---|---|---|---|---|
| A | Judgment before first edit | `approaches`, `code-architecture`, `taskmaster`, `fresh-take` | `approaches/hooks/remind.sh:3` "Fail open: never block the prompt"; same line in `fresh-take/hooks/remind.sh:3`, `taskmaster/hooks/remind.sh:3`, `api-docs-first/hooks/remind.sh:3` | HOOK-WARN + COMMAND | **ADVISORY** — no hard stop exists; all four reminders are skippable in silence |
| B | Scope lock | `task-runner` | `hooks/scope.sh:4` "warns (non-blocking)"; `skills/task-execution/SKILL.md:12-17` | HOOK-WARN + PROSE | **ADVISORY** |
| B′ | Verify-fix loop exit | `task-runner` | `skills/task-execution/SKILL.md:35` "Three failed fix cycles → halt the task"; `:85` reviewer pass shares "the SAME three-cycle ceiling", `--crew` gets "its own fresh budget" | PROSE | **PARTIAL** — exit condition is budget-shaped, not green-shaped. Cycle 4 halts with evidence; it does not continue, and it does not turn green |
| C | Verification requires output | `code-architecture` | `skills/work-verification/SKILL.md:22-31` "never assert without output"; enforced by `hooks/evidence-gate.sh` | GATE (holed) | **PARTIAL** — see §3.3 and Verdict 1 |
| C′ | Behavioral completion | `task-runner` | `skills/behavioral-gate/SKILL.md:104-108`, `hooks/completion-gate.sh` exit 2 | GATE | **ENFORCED** for registered runs; fail-open otherwise (`SKILL.md:113-118`, stated) |
| D | Tests run vs written | `testing` | `skills/testing-best-practices/SKILL.md` is authoring guidance throughout; no runner, no gate | PROSE | **ADVISORY** — `testing` never runs anything. Running belongs to `task-runner:behavioral-gate`, which is a different plugin the user may not have |
| E | Review agreement | `code-review` | `commands/review.md:20-28` enumerates and loads matching stack skills in one pass; `:54-60` names a single owner per finding | COMMAND | **PARTIAL** — fan-in is real, not just claimed. But 32 `review.md` commands ship, and `:26` instructs "never tell the user to run the per-stack review commands" — the sprawl is contradicted by its own flagship |
| F | Result vs **original request** | `code-architecture:drift-review` | `skills/drift-review/SKILL.md:3` "reviews the whole diff against what was asked" | PROSE + COMMAND | **ADVISORY** — the only request-level check. `taskmaster:coverage` is explicitly *not* this: `skills/coverage-check/SKILL.md:14` "delivered code against criteria later — this checks that the criteria are all [covered]" |
| G | See it / cost it before build | `taskmaster:visual-decisions`, `design-preview`, `approaches:size` | wireframes + mockups exist; `approaches:size` emits S/M/L/XL | COMMAND | **PARTIAL** — see-it: yes. Cost-it: estimates are write-only. No file records predicted-vs-actual for `approaches:size`, `task-runner` speedup, or `context-budget` deltas. Nothing reads them back |

### Unnamed axes — where the reported failures live

| # | Capability | Evidence | Mechanism | Verdict |
|---|---|---|---|---|
| H | **Output discipline** | At audit time: `grep -rilE "terse\|concise output\|token efficien\|output style\|response length"` over `plugins/**` → zero governance hits, no `outputStyles/` in any of 65 plugins. **Fixed 2026-07-28** — `comment-discipline/hooks/verbosity.sh` (§6 P0-2) | none → HOOK-WARN | MISSING → **ADVISORY** |
| I | **Comment discipline** | `comment-discipline/hooks/scan.sh:12-14`: "This hook still NEVER blocks or vetoes an edit — it emits no `permissionDecision` and no `decision`" | HOOK-WARN | **ADVISORY** — confirmed warn-only by the file's own declaration |
| J | **Failure honesty** | Paths to done-on-assertion enumerated in §3.3 | GATE (holed) | **PARTIAL** |
| K | **Instruction dilution** | 124 SKILL.md; `everything` 10,723 tok; top-5 collisions in §4 | — | **SEVERE** |
| L | **Trigger reliability** | 10-skill sample below | — | **PARTIAL** — 4/10 non-discriminating |
| M | **Measurability** | No `*eval*` / `*benchmark*` file under `plugins/` or `scripts/`. `scripts/smoke/canary.sh:2` "NOT a CI gate (needs a live model)". `hindsight/hooks/collect.sh:6` writes; only `/hindsight:harvest` reads | none | **MISSING** |

### L — 10-skill trigger sample

| Skill | Description trigger | Discriminating? |
|---|---|---|
| `code-architecture:simplicity-principles` | "when writing or reviewing code" | **No** — fires on everything |
| `code-architecture:low-cognitive-load` | "when writing or reviewing for readability" | **No** |
| `code-architecture:surgical-coding` | "writing, editing, or refactoring code outside a planned pipeline" | **No** — negatively scoped, unfalsifiable at fire time |
| `code-review:code-smells` | "reviewing, refactoring, or judging code quality" | **No** |
| `comment-discipline` | "…and deciding whether a comment should exist" | Marginal — decision clause narrows it |
| `api-docs-first` | "before writing any code that calls an external API, SDK, or third-party library" | Yes |
| `mysql-best-practices` | "MySQL 8.0+ … MariaDB is NOT MySQL — see mariadb" | Yes — names its negative |
| `mariadb-best-practices` | "MariaDB-vs-MySQL divergences … MySQL rules in mysql" | Yes |
| `nextjs-best-practices` | "Next.js App Router … server vs client component boundaries" | Yes |
| `a11y-audit` | "writing or reviewing UI markup, styles, or interactions" | Marginal — bounded by artifact type |

All four non-discriminating skills live in `code-architecture` / `code-review`,
both in `quality-suite`, both always-on. Ambition, not discrimination.

### Hook inventory by real mechanism

| Plugin | Event | File:line | Mechanism |
|---|---|---|---|
| `secret-scanning` | PreToolUse | `hooks/scan.sh:41` `permissionDecision:"deny"` | **HOOK-BLOCK** |
| `database` | PreToolUse | `hooks/guard.sh:65` `permissionDecision:"ask"` | HOOK-ASK |
| `ui-ux` / `taskmaster` | PreToolUse Artifact | `hooks/preview-guard.sh:17-18` "ask" | HOOK-ASK (twins) |
| `code-architecture` | Stop | `hooks/evidence-gate.sh:111` `exit 2` | **GATE** (holed, §3.3) |
| `task-runner` | Stop | `hooks/completion-gate.sh` `exit 2` | **GATE** (fail-open on unregistered) |
| `comment-discipline` | PostToolUse | `hooks/scan.sh:12-14` | HOOK-WARN |
| `task-runner` | PostToolUse | `hooks/scope.sh:4` | HOOK-WARN |
| `skill-router` | PostToolUse | `hooks/route.sh:8` | HOOK-WARN (injection) |
| `approaches`,`fresh-take`,`taskmaster`,`api-docs-first`,`craft-layer`,`orchestration` | UserPromptSubmit | each `:2-3` "Fail open: never block the prompt" | HOOK-WARN ×6 |
| `brain`,`skill-router` | SessionStart | injection | context-only |
| `hindsight`,`skill-router` | SessionEnd | `collect.sh:6` | write-only |

**3 blocking mechanisms** (1 deny + 2 Stop gates) against **124 skills**.

---

## 3. Root causes

### 3.1 Too chatty

Not a missing rule. **A requested behavior.**

| Finding | Evidence |
|---|---|
| No output contract exists | Axis H: zero hits, zero `outputStyles/` |
| Narration is instructed | 27 lines across `plugins/**/SKILL.md` matching `report back\|print (a\|the) table\|announce\|restate\|tell the user` |
| The pipeline is ledger-shaped | `taskmaster:grill` ambiguity ledger, `craft-layer:sections` section ledger, `task-execution` status tracking, `coverage-check` two-correspondence tables — each a documented artifact the model must emit |
| Reminders add turns | 6 UserPromptSubmit hooks, unmetered by `context-budget.sh` (its own closing note names all 14 unmetered plugins) |

**Why "be concise" rules fail here:** they are `PROSE` competing against 27 `PROSE`
instructions that are *more specific* and *task-local*. Specific beats general in
context. Adding rule 28 loses to rules 1–27 by construction. The fix must be a
different mechanism class, not more prose — §6 P0-2.

### 3.2 Too many comments

Enforcement path, end to end:

```
Edit/Write → [file written to disk] → PostToolUse → scan.sh
  → additionalContext JSON, exit 0 → model reads warning → model may ignore
```

`scan.sh:12-14` states the design: `additionalContext` "is NOT a blocking key: it
adds context, it cannot veto." Two independent failures: **(a)** the write already
happened, **(b)** the model is free to continue.

**Cost of moving to `HOOK-BLOCK` (PreToolUse deny):**

| Breaks | Why |
|---|---|
| Generated files | `scripts/generate.sh` templates emit header comments by design (`generate.sh:233`) |
| Smoke fixtures | `scripts/smoke/comment-discipline-hook` asserts current warn behavior and exact message strings |
| The hooks themselves | Every hook in this repo opens with a 10–25 line rationale block — `completion-gate.sh:1-25`, `evidence-gate.sh:1-46`. A blocking comment-rule would reject the marketplace's own house style |
| Doc-comment conventions | PHPDoc/JSDoc required by some stacks |

**Verdict:** full block is wrong. Targeted block on the *high-confidence restatement*
subset only, with an allowlist for generated/hook/fixture paths — §6 P0-3.

### 3.3 Code fails / quality isn't there

Four separable causes, ranked.

**(a) The green-build gate has a hole.** `evidence-gate.sh`:

```
:63-67   said = tail -30 lines of assistant text (whole tail, not the claim sentence)
:70-71   CLAIM matched → continue
:76      ACK = '…|fail|fails|failing|failed|failure|…'
:77      ACK matched anywhere in `said` → exit 0     ← short-circuits before evidence scan
:80-92   [mutation + evidence-order scan — never reached]
```

Any turn whose tail contained whole-word `failing`, `failed`, `failure`, or
`fail` passed without an evidence check. That is the *normal vocabulary of a
bug-fix turn*. Confirmed by execution — see §1 table and the §8 reproduction.
`CC_EVIDENCE_GATE=off` (`:48`) and `=warn` (`:110`) remain documented opt-outs.

**Status: fixed 2026-07-28** — §6 P0-1. Line numbers above describe the
pre-fix file; the shipped ACK is phrase-scoped and the three regression cases
are locked in `scripts/smoke/evidence-gate-hook-tests.sh` (cases 13-15).

**(b) The loop exits on budget, not on green.**
`task-execution/SKILL.md:35` — three failed cycles → halt. Correct as honesty;
insufficient as quality. A halted task is red code with an honest label. Nothing in
the serial path converts halt into "not done" for the *user's* summary unless the
`completion-gate` fires, and that gate is fail-open for any run that did not write
`active-run.json` (`behavioral-gate/SKILL.md:113-118`, stated openly).

**(c) Dilution.** §4. 7 always-on skills instructing the same edit, two of them in
direct contradiction. Under long context the model satisfies none of them fully.

**(d) Stack facts from recall.** `registry-source` exists precisely because
component registries were being answered from memory (`plugin.json` description:
"Read component registries from the source, never from memory"). The same failure
mode is unguarded everywhere else: `api-docs-first` covers external APIs as `PROSE`
(`SKILL.md:3` "Never code an integration from memory") with a `HOOK-WARN` reminder
(`hooks/remind.sh:3` fail-open). `stack-scan` reads manifests but is a `COMMAND`.
41 stack `*-best-practices` skills assert version-pinned facts with no source check
at all — `not verified` whether any are stale, but nothing in the repo could detect
it if they were.

---

## 4. Conflict map

### C1 — YAGNI vs SOLID, same trigger, opposite instruction

> `plugins/code-architecture/skills/yagni-check/SKILL.md:24-26`
> "**Single-implementation interfaces/abstract classes.** An `interface PaymentProvider`
> with exactly one class implementing it… An interface with one implementation isn't
> abstraction, it's indirection with no payoff yet."

> `plugins/code-architecture/skills/solid-principles/SKILL.md:104,113`
> "boundaries, both sides depend on an abstraction the policy side owns."
> "The abstraction belongs to the consumer and is shaped by what it needs"

Triggers: `yagni-check:3` "designing or reviewing for speculative generality";
`solid-principles:3` "designing or reviewing classes, interfaces, inheritance, or
module boundaries". Both fire on the same interface. **Same plugin.** No arbitration
line in either file.

### C2 — Catch blocks, two owners

> `plugins/resilience/skills/error-handling-design/SKILL.md:45`
> "A catch block that only logs and rethrows at a layer [is a smell]"

> `plugins/observability/skills/observability-design/SKILL.md:145-146`
> "Silent catch blocks — an exception swallowed with no log, metric, or span event"

Not contradictory, but the same finding with two owners and no arbiter.
`code-review/commands/review.md:54-60` has an ownership protocol — it applies only
inside `/code-review:review`, not when the skills fire on their own triggers. Both
are in `quality-suite`.

### C3 — Edit-time pile-up (7 skills, one trigger)

`simplicity-principles`, `low-cognitive-load`, `surgical-coding`,
`comment-discipline`, `code-smells`, `solid-principles`, `yagni-check` — all
descriptions match "writing or reviewing code". All in `quality-suite` (2,908 tok).
Leading dilution candidate.

### C4 — Review sprawl contradicted by its own flagship

32 `review.md` commands ship. `code-review/commands/review.md:26` instructs:
"never tell the user to run the per-stack review commands". The flagship loads the
stack skills inline; the 20+ per-stack `:review` commands then exist as surfaces the
flagship says not to route to. Every one is always-on description cost.

### C5 — Four pre-first-edit surfaces, three fail-open reminders

`approaches` (6 commands), `code-architecture:plan`, `taskmaster:grill`,
`fresh-take:consult`. Reminder hooks in `approaches`, `fresh-take`, `taskmaster`,
`api-docs-first` can all fire on one prompt. None blocks. Net effect: four
suggestions and no decision.

---

## 5. Context budget

Measured `bash scripts/context-budget.sh`, 2026-07-28. Total 10,732.

| Plugin | Tokens | Justification | Cut? |
|---|---|---|---|
| `everything` | 10,723 | convenience meta-bundle | Keep, warn harder in README |
| `taskmaster-suite` | 7,224 | 30 deps | Keep |
| `quality-suite` | 2,908 | 14 deps, 11 pure PROSE | **Split** — see §7 |
| `frontend-suite` | 2,785 | 17 deps | Keep |
| `process-suite` | 1,903 | 9 deps | Keep |
| `craft-layer` | 1,025 | 13 skills, one domain | Keep |
| `taskmaster` | 931 | 11 skills, the pipeline | Keep |
| `ui-ux` | 586 | 9 skills | Keep |
| `approaches` | 581 | 7 skills, 6 commands | **Demote** — merge `size`+`estimation` into one |
| `php-suite` / `db-suite` | 569 / 466 | category bundles | Keep |
| `code-architecture` | 462 | 9 skills, 4 non-discriminating | **Cut 2** (§7) |
| `claude-authoring` | 407 | 7 skills, authoring-time only | **Demote out of `everything`** |
| `task-runner` | 379 | the only behavioral gate | Keep — strengthen |
| `system-design` | 311 | overlaps `code-architecture` at the boundary | Keep, add arbitration line |
| `security` | 299 | 4 skills | Keep |
| `resilience` | 297 | 3 skills, C2 overlap | Keep, add arbitration |
| `orchestration` | 230 | 3 skills | Keep |
| `code-review` | 225 | flagship fan-in | Keep |
| `ultra-deep-research` | 223 | research-only | **Demote out of `everything`** |
| `registry-source` / `skill-router` | 0 / 0 | no description cost | Keep |
| remaining 40 leaves | 54–187 each | stack-specific, discriminating triggers | Keep |

**Unmetered:** `context-budget.sh` closing note names 14 plugins whose per-prompt /
per-tool hook output is not counted — `api-docs-first approaches code-architecture
comment-discipline craft-layer database fresh-take hindsight orchestration
secret-scanning skill-router task-runner taskmaster ui-ux`. Real always-on cost is
above 10,732 by an amount this repo cannot currently measure.

---

## 6. Fix list

### P0-1 — Close the evidence-gate honesty hole — **APPLIED 2026-07-28**

**File:** `plugins/code-architecture/hooks/evidence-gate.sh` (ACK block).
`plugin.json` 0.9.1 → 0.9.2.

Before:
```bash
ACK='…|cannot verify|could not verify|fail|fails|failing|failed|failure|not green|…'
```

After — failure vocabulary phrase-scoped, so the failing thing must be the CHECK
or must carry its cause:
```bash
ACK='…|cannot verify|could not verify|not green|still fail(ing|s)?|currently fail(ing|s)?|(tests?|suite|build|lint|checks?|it) (still |currently )?fail(ing|ed|s)?|fail(ing|ed|s)? (with|on|because|due)|in progress|…'
```

Mechanism: GATE (holed) → GATE. **Net tokens: 0** (hook body, not description).

**Deviations from the originally-proposed fix, and why:**

| Proposed | Shipped | Reason |
|---|---|---|
| Scope ACK to the last text block | **not done** | Every measured escape (E1, E4) was *same-sentence* — scoping fixes none of them, and would block honest reports that state the caveat before the summary. Recorded instead as a named residual in the hook header |
| Drop `please verify\|verify manually` | **kept** | Those are honest hand-off phrasings, not evasions |

**Verification:** `scripts/smoke/evidence-gate-hook-tests.sh` extended 12 → 19
cases (3 regression, 4 honest-report guards). **19 passed, 0 failed.** All four
repo gates green (`validate`, `check-version-bumps master`, `context-budget`,
`generate --check`), plus `hook-syntax` (44 scripts) and `hook-guard`.

### P0-2 — Output contract as a mechanism, not a rule — **APPLIED 2026-07-28**

**Files:** new `plugins/comment-discipline/hooks/verbosity.sh`; `hooks/hooks.json`;
`README.md`; `plugin.json` 0.2.0 → 0.3.0 (+ `marketplace.json` description sync);
new `scripts/smoke/verbosity-hook-tests.sh`; one CI step.

Mechanism: `MISSING` → HOOK-WARN. **Net always-on tokens: 0** — `context-budget.sh`
meters skill/command/agent descriptions, and `comment-discipline` stays at 107.

**The metric.** Assistant-text characters ÷ assistant tool calls, cumulative over
the session transcript. High = narrating relative to doing.

**Threshold calibrated on real data, not chosen.** 1,933 local session transcripts
with ≥8 tool calls:

| Population | n | p50 | p90 | p95 | p99 | max |
|---|---|---|---|---|---|---|
| Main thread | 135 | 155 | 325 | 389 | 821 | 910 |
| Subagent | 1,798 | 152 | 441 | 634 | 1,118 | 3,120 |

Threshold **600 chars/tool-call** → fired on 3 of 135 main-thread sessions (2.2%),
none below p95. It catches outliers; it does not nag the median.

**Subagents exempted** — their p95 (634) exceeds the main thread's *max*-adjacent
region because a subagent's final text *is* its return value. Judging them on this
metric measures the wrong thing. Exemption is by transcript path (`*/subagents/*`).

**Deviations from the originally-proposed fix, and why:**

| Proposed | Shipped | Reason |
|---|---|---|
| `Stop` event | **`PostToolUse`** | A Stop hook reaches the model only by blocking (`evidence-gate.sh:41-42`). Spending a turn to complain about output volume emits more prose than it saves. PostToolUse `additionalContext` reaches the model mid-session, where it can still change the next turns |
| Add a skill section | **no skill** | `skills/comment-discipline/SKILL.md` body is at exactly 150 lines — the `validate.sh` ceiling. A section costs a deletion, and the whole argument for this fix was that it is *not* prose. The hook is the mechanism; the README carries the explanation |
| `UserPromptSubmit` (considered) | rejected | Would enter the reminder-budget contention (`scripts/smoke/hook-guard-tests.sh`: "first matching hook speaks, second yields") and be suppressed by the 6 existing reminders |

**Argue-or-drop (ground rule 4): passes.** It adds zero always-on tokens and zero
standing rules. It reports a measured fact about the current session that nothing
else in the marketplace measures — and in doing so puts the first real number
against axis M.

**Verification:** `scripts/smoke/verbosity-hook-tests.sh` — **12 passed, 0 failed**
(terse/median/just-under silent; outlier warns; once-per-session bound; fresh
session re-arms; subagent exempt; <8 calls, <60 lines, missing, malformed, and
partial payloads all fail open silently; every case asserts rc 0 — it can never
block). All four repo gates green, plus `hook-syntax` (46 scripts) and `hook-guard`.

**Residuals, stated in the hook header:** cumulative metric (an early-verbose
session stays flagged); prose the *user asked for* counts against the ratio; the
threshold is one machine's calibration; assumes `PostToolUse` carries
`transcript_path` — if it does not, the hook is silent rather than wrong.

### P0-3 — Narrow comment-discipline to a targeted block

**File:** `plugins/comment-discipline/hooks/scan.sh` + `hooks/hooks.json`

Add a **PreToolUse** matcher alongside the existing PostToolUse, emitting
`permissionDecision:"ask"` (not `"deny"`) on the highest-confidence restatement
patterns only, with a path allowlist for `hooks/`, `templates/`, `scripts/smoke/`,
and any file whose head matches `generated by`.

Mechanism: HOOK-WARN → HOOK-ASK. **Net tokens: 0.**
**Breaks:** §3.2 table — mitigated by the allowlist. `scripts/smoke/comment-discipline-hook`
fixtures need the new event added.

### P1-1 — Green-shaped loop exit

**File:** `plugins/task-runner/skills/task-execution/SKILL.md:35`

Before: "**Three failed fix cycles → halt the task.**"
After: add — "A halted task is RED, never reported inside a done summary. The run's
final status line must name every halted task by id before any completion claim."

Mechanism: PROSE → PROSE (but readable by `completion-gate`). **Net: +15 tok.**

### P1-2 — Arbitration lines for C1 and C2

**Files:** `yagni-check/SKILL.md`, `solid-principles/SKILL.md`,
`error-handling-design/SKILL.md`, `observability-design/SKILL.md`.
One line each naming the sibling and who wins. **Net: +30 tok total.**

### P1-3 — Request-level satisfaction gate

**File:** `plugins/code-architecture/skills/drift-review/SKILL.md`
Wire `drift-review` into `task-runner`'s completion protocol so it runs on the
final diff rather than only on invocation. Mechanism: COMMAND → GATE-adjacent.

### P2 — everything else

Estimate write-back (axis G), `hindsight` auto-read, review-command consolidation,
`license` key present on 1 of 65 `plugin.json`.

---

## 7. Structural proposals

**Merges / deletions (pay for the new surfaces):**

| Action | Rationale |
|---|---|
| Delete `code-architecture:simplicity-principles`, fold KISS/DRY into `low-cognitive-load` | Both non-discriminating, both always-on, overlapping content. −1 skill |
| Delete `code-architecture:surgical-coding`, fold into `plan-before-code` | Trigger is negatively scoped and unfalsifiable at fire time. −1 skill |
| Merge `approaches:size` + `approaches:estimation` | One capability, two surfaces |
| Demote `claude-authoring`, `ultra-deep-research`, `vercel-skills-scout`, `plugin-scout` out of `everything` | Authoring/meta tools; always-on cost, rarely decisive during coding. −~900 tok |
| Split `quality-suite` → `quality-suite` (the 3 with mechanisms + `code-review` + `testing`) and `quality-principles-suite` (the 9 prose skills) | Lets a user take enforcement without dilution |

**New surfaces — two, both paid for:**

1. **`comment-discipline` verbosity capability** (P0-2) — paid by
   `simplicity-principles` deletion.
2. **Nothing else.** The prior turn's `lean-output` + `definition-of-done`
   proposals are **withdrawn**: `definition-of-done` is ~70% duplicate of
   `evidence-gate` + `completion-gate` + `behavioral-gate` + `drift-review`, and
   the correct move is P0-1 (fix the hole) not P0-new (add a fifth gate).
   `lean-output` as a standalone plugin would ship prose into a system where
   prose is the failing mechanism.

**Argued against:** adding a `release-ops` plugin (Phase-6 gap named in the prior
audit) — real, but it does not touch the three reported failures. P2.

---

## 8. Eval plan

Runnable without human judgment. Each proves or disproves one P0.

| # | Scenario | Proves | Pass condition | Run? |
|---|---|---|---|---|
| E1 | Synthetic transcript: `Edit` tool row, then assistant text `"Fixed the failing test - should work now."`, no Bash after. Pipe to `evidence-gate.sh` | P0-1 | Pre-fix: exit 0. **Post-fix: exit 2** | **Run 2026-07-28 → exit 0, hole confirmed** |
| E2 | Same, text `"Done - did not run the suite."` | P0-1 no false positive | exit 0 both before and after | **Run → exit 0 ✓** |
| E3 | Same, text `"All tests pass."` with a `Bash` row after the last `Edit` | P0-1 no regression | exit 0 both | not run |
| E4 | Same, text `"Fixed it. The old failure is gone."` | P0-1 tightening | Pre: exit 0. **Post-fix: exit 2** | **Run → exit 0, hole confirmed** |
| E4b | Control: `"Implemented the parser. All set."` (no failure noun) | gate is otherwise live | exit 2 | **Run → exit 2 ✓** |
| E5 | `Write` a file containing `// increment i by one` above `i++`; pipe to `scan.sh` PreToolUse matcher | P0-3 | `permissionDecision:"ask"` emitted | not run — P0-3 not applied |
| E6 | Same, but target path `plugins/foo/hooks/bar.sh` (allowlisted) | P0-3 no false positive | no decision emitted, exit 0 | not run |
| E7 | Same, but file head contains `generated by scripts/generate.sh` | P0-3 allowlist | no decision emitted | not run |
| E8 | Synthetic PostToolUse payload, transcript at 1,000 chars/tool-call | P0-2 | warn emitted; **not** emitted at 200 / 155 / 590 chars per call | **Run → 12/12, `scripts/smoke/verbosity-hook-tests.sh`** |

E1–E4b are pure `printf | bash hooks/evidence-gate.sh` — no model in the loop.
E5–E8 likewise. All belong in `scripts/smoke/` as CI steps, which would also give
this marketplace its **first** measurement of anything (axis M).

Reproduction used for E1/E2/E4/E4b (each transcript = one `Edit` tool_use row, then
one assistant text block; marker file cleared between runs):

```bash
printf '{"transcript_path":"%s","cwd":"%s","stop_hook_active":false}' "$TX" "$DIR" \
  | bash plugins/code-architecture/hooks/evidence-gate.sh; echo "exit $?"
rm -f "$DIR/.claude/evidence-gate-last"
```

---

## 9. Not verified

- Whether any of the 41 stack `*-best-practices` skills contain stale version
  claims. Nothing in the repo could detect it.
- Real always-on token cost including the 14 unmetered hook-output plugins.
- Whether `skill-router`'s `rules.tsv` routing fires correctly in practice —
  `scripts/smoke/route-marker` tests the marker, not the routing decision quality.
- Whether the 6 UserPromptSubmit reminders fire at useful rates. No telemetry.
