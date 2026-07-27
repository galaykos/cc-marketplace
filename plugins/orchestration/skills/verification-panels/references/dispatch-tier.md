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
and refuses its own `ULTRA-<X> ACTIVE` banner echoed back. That converts "any mention
anywhere fires the boost" into "a mention that reads like an invocation fires it" — an
unquoted, unnegated quotation in the opening 200 characters still fires, and an
invocation past 200 characters no longer does. The off switch is the reliable control.
