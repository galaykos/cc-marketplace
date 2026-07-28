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
   *(Fixed 2026-07-28 — §6 P0-2, as a measurement rather than rule 28.)*
3. **Comment enforcement is `HOOK-WARN` by explicit design**
   (`plugins/comment-discipline/hooks/scan.sh:12-14`), and PostToolUse fires
   *after* the write. The comments are already on disk when the warning arrives.
   *(Fixed 2026-07-28 — §6 P0-3, PreToolUse deny on 2 of 5 categories.)*
4. **`quality-suite` is 14 plugins / 2,908 always-on tokens, of which 11 are pure
   `PROSE`.** Its three hook-carrying members (`comment-discipline` warn,
   `secret-scanning` deny, `database` ask) enforce nothing about code quality.
   *(Fixed 2026-07-28 — §7: split into a 6-plugin mechanism bundle at 949 tokens
   and an 8-plugin advisory bundle at 1,873.)*
5. **7 skills fire on every code edit with the same trigger phrase** ("when
   writing or reviewing code"). Two of them contradict each other on interfaces.
   *(Partly fixed 2026-07-28 — 7 → 5 by folding two to references (§7); the
   contradiction arbitrated in §6 P1-2.)*
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
    *(4 after P0-3. The ratio is the point, and 4:124 is not materially better
    than 3:124 — the cut list still stands.)*

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
| F | Result vs **original request** | `code-architecture:drift-review` | `skills/drift-review/SKILL.md:3` "reviews the whole diff against what was asked"; **2026-07-28** wired into `task-execution/SKILL.md:145-148` completion protocol (§6 P1-3) | PROSE + COMMAND → part of the completion protocol, still PROSE-tier | **ADVISORY** — the only request-level check. `taskmaster:coverage` is explicitly *not* this: `skills/coverage-check/SKILL.md:14` "delivered code against criteria later — this checks that the criteria are all [covered]" |
| G | See it / cost it before build | `taskmaster:visual-decisions`, `design-preview`, `approaches:size` | wireframes + mockups exist; `approaches:size` emits S/M/L/XL | COMMAND | **PARTIAL** — see-it: yes. Cost-it: estimates are write-only. No file records predicted-vs-actual for `approaches:size`, `task-runner` speedup, or `context-budget` deltas. Nothing reads them back |

### Unnamed axes — where the reported failures live

| # | Capability | Evidence | Mechanism | Verdict |
|---|---|---|---|---|
| H | **Output discipline** | At audit time: `grep -rilE "terse\|concise output\|token efficien\|output style\|response length"` over `plugins/**` → zero governance hits, no `outputStyles/` in any of 65 plugins. **Fixed 2026-07-28** — `comment-discipline/hooks/verbosity.sh` (§6 P0-2) | none → HOOK-WARN | MISSING → **ADVISORY** |
| I | **Comment discipline** | At audit time `comment-discipline/hooks/scan.sh:12-14` declared "This hook still NEVER blocks or vetoes an edit". **Fixed 2026-07-28** — a PreToolUse lane now denies 2 of the 5 categories, one-shot per file (§6 P0-3) | HOOK-WARN → HOOK-BLOCK (2 of 5) | ADVISORY → **PARTIAL** |
| J | **Failure honesty** | Paths to done-on-assertion enumerated in §3.3 | GATE (holed) | **PARTIAL** |
| K | **Instruction dilution** | 124 SKILL.md; `everything` 10,723 tok; top-5 collisions in §4. **2026-07-28** — 2 non-discriminating skills folded to references (§7), C1/C2 arbitrated (§6 P1-2), `quality-suite` split 2,908 → 949 + 1,873. 122 skills now; the ratio barely moves | — | **SEVERE** |
| L | **Trigger reliability** | 10-skill sample below | — | **PARTIAL** — 4/10 non-discriminating |
| M | **Measurability** | No `*eval*` / `*benchmark*` file under `plugins/` or `scripts/`. `scripts/smoke/canary.sh:2` "NOT a CI gate (needs a live model)". `hindsight/hooks/collect.sh:6` writes; only `/hindsight:harvest` reads. **2026-07-28** — `verbosity.sh` now leaves a per-scan ledger (§6 P2), the first data trail here; still write-only, so the axis does not move | none | **MISSING** |

### L — 10-skill trigger sample

| Skill | Description trigger | Discriminating? |
|---|---|---|
| `code-architecture:simplicity-principles` | "when writing or reviewing code" | **No** — fires on everything. *Folded to a reference 2026-07-28 (§7)* |
| `code-architecture:low-cognitive-load` | "when writing or reviewing for readability" | **No** |
| `code-architecture:surgical-coding` | "writing, editing, or refactoring code outside a planned pipeline" | **No** — negatively scoped, unfalsifiable at fire time. *Folded to a reference 2026-07-28 (§7)* |
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

**Resolved 2026-07-28** (§6 P1-2) — both files now name the discriminator: origin,
not implementation count.

Triggers: `yagni-check:3` "designing or reviewing for speculative generality";
`solid-principles:3` "designing or reviewing classes, interfaces, inheritance, or
module boundaries". Both fire on the same interface. **Same plugin.** No arbitration
line in either file.

### C2 — Catch blocks, two owners

> `plugins/resilience/skills/error-handling-design/SKILL.md:45`
> "A catch block that only logs and rethrows at a layer [is a smell]"

> `plugins/observability/skills/observability-design/SKILL.md:145-146`
> "Silent catch blocks — an exception swallowed with no log, metric, or span event"

**Resolved 2026-07-28** (§6 P1-2) — existence is resilience's, emission is
observability's, one finding under one owner.

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

### P0-3 — Narrow comment-discipline to a targeted block — **APPLIED 2026-07-28**

**Files:** `plugins/comment-discipline/hooks/scan.sh`, `hooks/hooks.json`,
`README.md`, `plugin.json` 0.3.0 → 0.4.0 (+ `marketplace.json` sync),
`scripts/smoke/comment-discipline-hook-tests.sh`.

One detector, two lanes, chosen by `hook_event_name` (absent ⇒ PostToolUse, the
original behavior — no existing caller changes):

| Category | PostToolUse | PreToolUse |
|---|---|---|
| Comment restating the next line | warn | **deny** |
| Commented-out code | warn | **deny** |
| Section banner | warn | allow |
| Bare `TODO` | warn | allow |
| Docblock tag repeating the signature | warn | allow |

Mechanism: HOOK-WARN → **HOOK-BLOCK** for two of five categories. **Net tokens: 0.**

**Deviation from the originally-proposed fix, and why:**

| Proposed | Shipped | Reason |
|---|---|---|
| `permissionDecision:"ask"` | **`"deny"`** | `ask` interrupts the *human* for a style nit the *model* wrote — dozens of prompts during a task run, about something the human cannot usefully adjudicate. `deny` returns the correction to the party that can act on it |

**Why only two of five categories.** Only those two have detectors strict enough to
carry a veto: `restates()` requires *every* content word of the comment to be
recoverable from the code line (a rule the file already justifies at `:183-184` —
"Requiring ALL of them, not a ratio, is what keeps this warning credible"), and
`is_code()` matches syntax, not prose. Banners and dead docblock tags are
house-style calls; a bare `TODO` can be a legitimate mid-task marker.

**Why it cannot wedge a session.** The deny is one-shot per file per session (same
bounding idea as `completion-gate.sh`'s one-block-per-commit). A second edit to the
same file passes and the PostToolUse lane warns instead — a false positive costs one
extra turn. Without a `session_id` the bound is unenforceable, so the deny is
withheld entirely.

**Breaks — and what was done about them.** The §3.2 cost table listed four things a
block would break. Generated files, hook headers, and the repo's own scripts were
already excluded by the path/extension filters at `scan.sh:44-56`; a `@generated` /
`generated by` / `do not edit` marker in the first five added lines was added on top.
The smoke suite's file-level assertion "hook emits no blocking JSON" was the fourth,
and it had to change: it grepped the source for `permissionDecision`, which can no
longer distinguish an emission from an emission *on the correct lane*. It is now a
Stop-key-only grep plus a behavioral assertion that PostToolUse never carries a
`permissionDecision`.

**Verification:** `scripts/smoke/comment-discipline-hook-tests.sh` — **all cases
passed**, 11 new (2 lane-separation, 9 PreToolUse: both denies, the one-shot bound,
per-file re-arm, all three warn-only categories staying allowed, a keep-case comment,
the generated-file exemption, and the no-session_id withholding). All four repo gates
green; `plugin-scout` 0.8.1 → 0.8.2 for its regenerated `catalog.md`.

### P1-1 — Green-shaped loop exit — **DROPPED 2026-07-28, on inspection**

The proposed line would have restated text the file already carries. The completion
protocol at `task-execution/SKILL.md:143-150` already requires (1) "Every task is done
or parked-with-reason — none silently skipped" and (3) a final report table of "task /
status / verify command / evidence line, plus the parked list with reasons". A halted
task is therefore neither silently dropped nor reportable as done.

The residual is real but small: "parked-with-reason" can absorb a halt, and the run
then completes with an honest parked entry rather than a red one. Closing it would cost
a **deletion** — that SKILL body sits at exactly the 150-line ceiling — to add a
sentence beside one already saying most of it.

Adding a redundant prose rule, at the ceiling, to a file this review criticises for
prose density, is the anti-pattern the review is about. Dropped and recorded, not
quietly skipped.

### P1-2 — Arbitration lines for C1 and C2 — **APPLIED 2026-07-28**

Both collisions resolved by naming the **discriminator**, not by picking a winner —
a bare "X wins" would be wrong half the time.

| Conflict | Files | Discriminator |
|---|---|---|
| C1 — single-implementation interface | `yagni-check/SKILL.md:24-32`, `solid-principles/SKILL.md:117-121` | **Origin, not implementation count.** Written by the consumer to state what it needs at a genuine boundary → SOLID, and one implementation is normal. Added ahead of a second provider nobody asked for → YAGNI |
| C2 — catch blocks | `error-handling-design/SKILL.md:43-46`, `observability-design/SKILL.md:144-147` | **Existence vs emission.** Whether the catch should EXIST and where it sits → resilience. What a kept catch must EMIT → observability. One finding, one owner |

**Net lines: 0 in two of the four files.** `error-handling-design` was at exactly 150
and `observability-design` at 145, so the resilience text was compressed into the
existing bullet's line count rather than appended. Bumps: `code-architecture` 0.9.3,
`resilience` 0.2.1, `observability` 0.2.8.

### P1-3 — Request-level satisfaction gate — **APPLIED 2026-07-28**

**File:** `plugins/task-runner/skills/task-execution/SKILL.md:145-148` (completion
protocol, item 2). `drift-review` now joins the end-of-run checks when
`code-architecture` is installed, reading the whole-run diff **against what was
ASKED** — the axis F gap, which no suite covers. Follows the pattern already there
for `api-docs-first`'s drift check.

Mechanism: COMMAND → part of the completion protocol (still PROSE-tier: the protocol
is agent-followed, and `completion-gate.sh` checks a gate-pass record, not this).
Stated plainly: this does not make axis F `ENFORCED`. **Net lines: 0** — item 2 rewritten
within its existing four lines, since that body is also at the 150 ceiling.
`task-runner` 0.21.2.

### P2 — everything else — **partially applied 2026-07-28**

| Item | Status |
|---|---|
| **E3 regression case** (§8) | **Applied.** `evidence-gate-hook-tests.sh` case 20: a failure word *plus* real post-edit execution must pass on the EVIDENCE path, not the escape path. It is the case that stays green if the P0-1 tightening ever over-reaches, while 13-15 flip. Suite 19 → **20 passed** |
| **Measurement trail** (axis M) | **Applied.** `verbosity.sh` records every scan — warned or not — to `~/.claude/comment-discipline/verbosity-ledger.jsonl` (machine-local, 1 MB cap). The P0-2 threshold was calibrated once, on one machine, from transcripts predating the hook; without a record of what it sees in practice, nothing could ever say whether 600 is right or whether the warning changed the sessions that got it. **Write-only by design and labelled so** — nothing reads it back, and calling it a feedback loop today would be exactly the `hindsight` over-claim this review flagged in Verdict 9 |
| **`license` on 1 of 65** | **Not a defect — closed, no change.** The outlier is `registry-source`, the one plugin shipping executable code (`mcp/server.mjs`) rather than only markdown. A plugin that ships redistributable code declaring MIT is correct; 64 markdown-only plugins inheriting the repo `LICENSE` is also correct. Nothing in `validate.sh`, `lib/plugin-checks.sh`, or `authoring-plugins/SKILL.md` reads the field. Adding it to 64 files would cost 64 version bumps for inert metadata — the churn would be the defect |
| **Estimate write-back** (axis G) | **Not started.** `approaches:size`, task-runner speedup estimates, and `context-budget` deltas remain write-only |
| **`hindsight` auto-read** | **Not started.** Its ledger is still read only by the `/hindsight:harvest` COMMAND |
| **Review-command consolidation** | **Not started** — belongs with §7, which is unapplied |

---

## 7. Structural proposals

**Merges / deletions — executed 2026-07-28, with two corrections.**

| # | Proposed | Outcome |
|---|---|---|
| 1 | Delete `simplicity-principles`, fold KISS/DRY into `low-cognitive-load` | **Done** — as a fold, not a delete. Its 114-line body moved to `low-cognitive-load/references/kiss-dry.md`; the skill directory is gone. −1 always-on trigger, 0 lines of material lost |
| 2 | Delete `surgical-coding`, fold into `plan-before-code` | **Done, same shape** — body at `plan-before-code/references/surgical-edits.md`, Karpathy attribution carried with the text. −1 always-on trigger |
| 3 | Merge `approaches:size` + `approaches:estimation` | **NOT DONE — the review was wrong.** `size` is a *command*, `estimation` is the *skill* it invokes. All six `approaches` commands have exactly this shape (`compare`→`strategy-catalog`, `opinions`→`opinion-round`, `pattern`→`pattern-selection`, `rollout`→`rollout-planning`, `build-vs-buy`→`build-vs-buy`), and it is the documented house pattern — `authoring-commands`: a command is "a thin entry point over a skill". Merging them would delete the pattern and leave `estimation` with no command. Counting a command and its skill as "one capability, two surfaces" was a misread |
| 4 | Demote 4 plugins out of `everything` | **NOT DONE — forbidden by an existing gate.** `scripts/validate.sh:178-181` fails the build if `everything` omits any non-suite plugin. The gate is right: a bundle named `everything` that silently drops four plugins is precisely the over-claim this repo's own convention forbids. Attempted, caught by the gate, reverted byte-for-byte. The 10.6k concern is real; the answer is the category suites, which already exist |
| 5 | Split `quality-suite` | **Done.** 14 → 6 (mechanism-bearing) + new `quality-principles-suite` at 8 (advisory) |

**Split, measured** (`scripts/context-budget.sh`):

| Bundle | Members | Before | After |
|---|---|---|---|
| `quality-suite` | 14 → 6 | 2,908 | **949** |
| `quality-principles-suite` | new, 8 | — | **1,873** |

A project wanting the enforcing half now pays 949 instead of 2,908. Taking both
costs 2,822 — still less than the old single bundle, since each suite description
is counted once.

**New surfaces: two, both paid for**, as §7 required.

| New | Paid by |
|---|---|
| `comment-discipline` verbosity capability (P0-2) | `simplicity-principles` deletion |
| `quality-principles-suite` | `surgical-coding` deletion |

**Not attempted:** demoting plugins out of `everything` (item 4 above), and the
review-command consolidation, which needs its own pass.

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
| E5 | `Write` a file containing `// increment the counter` above `counter++;`; PreToolUse payload | P0-3 | `permissionDecision:"deny"` emitted | **Run → deny ✓** |
| E6 | Same file a second time in the same session | P0-3 one-shot bound | no decision emitted | **Run → silent ✓** |
| E7 | Same, but added text opens with `// @generated by tool — do not edit` | P0-3 exemption | no decision emitted | **Run → silent ✓** |
| E7b | Warn-only categories (bare `TODO`, section banner) on the PreToolUse lane | P0-3 scoping | no decision emitted | **Run → silent ✓** |
| E7c | PreToolUse payload with no `session_id` | P0-3 cannot bound ⇒ withhold | no decision emitted | **Run → silent ✓** |
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
