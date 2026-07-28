# The boost dispatch tier — stated once

Every Extreme Boost contract in this marketplace uses one tier string, and this is it:

    model=auto, effort=xhigh

**`auto`** resolves at dispatch to the session model or opus, whichever is higher on
`haiku<sonnet<opus<fable` — escalate, never downgrade. It is a FLOOR: it never lowers an
agent below the tier its own frontmatter ships. Never edit frontmatter to achieve a
boost; the override belongs to dispatch.

**`effort`** is settable ONLY on the `Workflow` `agent()` path. The Agent tool has no
effort knob, so inline dispatch escalates the model only — a contract that promises
`effort=xhigh` inline is promising something the tool cannot do.

Consumers — `taskmaster:ultra`, `orchestration:ultra-assess`, `craft-layer:ultra-craft`
— cite this file. Each keeps only what is genuinely its own: taskmaster the goal-mode
ledger and the `Ultra:`/`Goal:` index markers, orchestration the assessment recipe and
its "never emits task cards" rule, craft-layer the six bindings and the live-research
mandate.

## Native harness interop — `ultracode`, `ultrathink`, workflow size

The boost is a dispatch contract; Claude Code's own harness owns whether the
`Workflow` tool may be called at all, how hard the main thread thinks, and how wide a
single workflow may fan out. Four rules follow, and every boost consumer inherits them.

**The `Workflow` path needs an explicit opt-in, not merely a visible tool.** The tool
can appear in the tool list while the harness still forbids calling it — its own
contract restricts use to a user opt-in: the `ultracode` keyword, ultracode standing on
for the session, the user asking for a fan-out in their own words, or *a skill whose
instructions tell you to call it*. A boost skill is that last clause, so a boosted run
may fan out — but only because the user invoked the boost. Absent any opt-in, take the
inline fallback and label it. Practical consequence, worth telling the user once:
**`ultracode` is the half of the boost this marketplace cannot supply.** Without it
`effort=xhigh` is unreachable (Agent has no effort knob, above), so an unpaired boost
buys model escalation only.

**`ultrathink` is orthogonal and complementary.** It raises MAIN-THREAD reasoning for a
turn; the boost raises SUBAGENT tier and never touches the session model. Neither
substitutes for the other, and the boost hooks do not fire on it. `ultrathink ultracode
ultra-<token> <task>` is the fully-loaded form: deep orchestrator, real fan-out,
boosted panels.

**The session's workflow-size guideline caps the ceilings.** Fan-out counts here are
sized to blast radius and gated by `budget.remaining()`; the harness adds a per-workflow
agent-count guideline (default *medium*, under 15 agents). It binds too. When a sized
ceiling would exceed it, shrink stages toward their inline fallback — never drop a
mandatory phase — and `log()` what was shrunk, per this skill's no-silent-caps rule.

**Interactive phases never fan out.** Workflow subagents have no user I/O: no
`AskUserQuestion`, no preview-server pick, no consent gate. Any phase whose output is a
user decision runs in the main thread, whatever the boost or an ultracode default says.
The boost widens reasoning phases (recon, red-team, coverage, verify, synthesis) only.

## Why the hooks still carry their own copy

The three `UserPromptSubmit` hooks inject this tier as literal text. An injected
directive cannot cite a file — it IS the contract for that turn, read by a model that
has not opened anything yet. So the hook copies stay, and this file is the readable
source they are kept in step with.

Standing: **recorded**. `scripts/validate.sh` checks that every trigger token in
taskmaster's hook is named in its command preamble; nothing checks that the four tier
strings agree.


## Residual: no cross-plugin activation guard

`taskmaster`, `orchestration` and `craft-layer` install independently, declare no
dependencies on each other, and share no writable location — each hook is a separate
process holding only its own `$CLAUDE_PLUGIN_ROOT`. A prompt naming two boost tokens
injects both directives and **nothing can stop it**. `ultra-craft` carries a one-line
rule about not printing two banners; that governs OUTPUT, not activation, and it is the
most that is implementable.

Standing: **unenforceable**, stated rather than papered over.

What IS implementable, because environment is the one thing three separate processes
share: `CC_BOOST=off` disables every boost hook in the marketplace; `TASKMASTER_BOOST`,
`ORCHESTRATION_BOOST` and `CRAFT_BOOST` disable one each. An off switch works
cross-plugin even though a mutual-exclusion guard does not.

Trigger narrowing is likewise heuristic, not parsing. Each hook drops fenced and
backticked spans, looks only at the first 200 characters, refuses a negated mention,
and refuses a banner of its own family echoed back — `ultra-(task|goal|assess|craft)
ACTIVE`, enumerated rather than `ultra-<anything> ACTIVE`. The enumeration is the fix
for a live false-negative: the loose form also matched the harness's own vocabulary, so
"ultracode active — now ultra-task X" and "ultrathink active, ultra-task X" silently
suppressed the boost the user had just typed. Narrowing converts "any mention anywhere
fires the boost" into "a mention that reads like an invocation fires it" — an unquoted,
unnegated quotation in the opening 200 characters still fires, and an invocation past
200 characters no longer does. The off switch is the reliable control.

Standing: **gated**, narrowly. `scripts/smoke/hook-guard-tests.sh` asserts the four
boost tokens still fire and that a `ultracode active` / `ultrathink active` preamble no
longer suppresses them. Nothing gates the other three narrowings.
