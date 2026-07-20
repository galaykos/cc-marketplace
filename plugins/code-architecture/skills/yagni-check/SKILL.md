---
name: yagni-check
description: Use when designing or reviewing for speculative generality — flags abstractions, config options, flexibility nobody asked for.
---

## The core question

For every abstraction, parameter, or configuration point: **who needs this today, and can you
point to the caller?** If the answer is "no one yet, but we might need it later," it fails the
check. "You aren't gonna need it" is not a claim about the future — it's a claim about the
present: the need does not exist in the code right now, so the code should not exist either.

Speculative flexibility isn't free. It costs review time, test surface, documentation, and a
harder-to-navigate codebase, paid today, for a benefit that may never arrive and — even if it
does — will likely need a different shape than the one you guessed.

## Red flags

- **Unused parameters "for later."** A function grows a `options` argument, a `strategy`
  callback, or an extra field that nothing currently passes a non-default value for. It exists
  because someone imagined a future caller.
- **Single-implementation interfaces/abstract classes.** An `interface PaymentProvider` with
  exactly one class implementing it, introduced "in case we add another provider." An interface
  with one implementation isn't abstraction, it's indirection with no payoff yet.
- **Config nobody sets.** A setting, env var, or feature flag that has always been left at its
  default in every environment. If it's never been changed, it isn't configuration — it's a
  constant wearing a costume.
- **Premature plugin systems.** A registry, hook system, or `middleware[]` pipeline built before
  there are two real things to plug in. Plugin architectures earn their complexity only once
  variation is observed, not anticipated.
- **Speculative generality in data models.** A `metadata: Record<string, any>` column or a
  `type` discriminator with one branch, added so the schema "can handle anything later."
- **Layered indirection with no current variation.** A factory that always returns the same
  concrete type, a repository interface with one backing store, a base class with one subclass
  that overrides nothing meaningful.
- **"While I'm in here" scope creep.** Generalizing a function to handle inputs the current
  feature never produces, because it was easy to do while already editing that code.

## The "delete until it hurts" test

For any abstraction or flexibility point you're unsure about, mentally (or actually, on a
branch) delete it and inline the single concrete case. Then ask: does anything break, does any
real requirement stop being met, does the code get *harder* to read?

- If deleting it changes nothing observable and the code reads the same or better inlined —
  it was speculative. Leave it deleted.
- If deleting it breaks a real, currently-existing caller or requirement — it wasn't
  speculative, keep it.
- If you're not sure which, that uncertainty is itself the answer: it means nothing in the
  current codebase actually depends on the generality, so it goes.

Push the test past the first cut: if removing one layer of indirection reveals a second layer
that also has no real caller, keep peeling. Stop only when removing more would break something
that exists today.

## Pushing back on requirements bloat

Speculative generality often arrives disguised as a requirement: "make it configurable," "build
it so we can swap X later," "support plugins from day one." Treat these the same way as
self-introduced abstractions — ask for the concrete second case.

- Ask: "Do we have a second real use case today, or is this for a hypothetical future one?" If
  it's hypothetical, propose building the concrete version now and generalizing when the second
  case actually shows up (see simplicity-principles: rule of three).
- Ask: "What breaks if we ship the simple version and revisit this when it's actually needed?"
  Usually: nothing. Revisiting later, with a real second case in hand, produces a better
  abstraction than guessing now.
- If a stakeholder insists on future-proofing with no concrete second case, name the cost
  explicitly ("this doubles the surface area we test and maintain, for a scenario that may
  never occur, and may not need this shape even if it does") and let them make an informed
  call rather than defaulting to "yes" because generality sounds responsible.
- It's easier to add an abstraction later than to remove a wrong one now — removing a wrong
  abstraction that other code has grown to depend on is a migration, not an edit.

## Before / after

**Before:** `function sendNotification(user, message, channel = 'email', retries = 3,
formatter = defaultFormatter)` — only `email` is ever passed, `retries` is never set to
anything but 3, `formatter` has exactly one implementation.

**After:** `function sendEmail(user, message)`. When SMS support becomes a real, scheduled
requirement, the channel parameter (or a proper strategy split) gets added then, informed by
what SMS actually needs — which will likely differ from the guess made today.

## What YAGNI does not mean

YAGNI is not an excuse to skip error handling, input validation, tests, or basic robustness for
requirements that exist *today*. It targets flexibility for hypothetical future requirements,
not correctness for the requirement in front of you. Don't confuse "don't build the plugin
system nobody asked for" with "don't handle the error case that will definitely occur in
production." The check is about speculative *generality*, not about doing the current job
properly.

Likewise, YAGNI doesn't mean refuse to think ahead at all — it means don't pay implementation
cost for the future today. Naming things well, keeping functions small, and keeping modules
loosely coupled all make future changes cheaper without adding present-day speculative
mechanism; that's good design, not a YAGNI violation.

## Quick review checklist

When reviewing a diff or design, scan for each of these and ask "who calls this today?":

- [ ] Every parameter has at least one real caller passing a non-default value.
- [ ] Every interface/abstract type has at least two real implementations, or one implementation
      plus a concretely scheduled second one.
- [ ] Every config key has been set to something other than its default in at least one real
      environment.
- [ ] Every "pluggable" or "extensible" mechanism has at least two things currently plugged in.
- [ ] Every generic/flexible data field (`metadata`, `options`, `extra`) has a concrete,
      currently-consumed shape, not just "room for anything."

Any unchecked box is a candidate for the delete-until-it-hurts test above.

## When to apply

Run this check when designing a new function/module, and again in review whenever a diff adds a
parameter, interface, config key, or "generic" mechanism that isn't immediately exercised by an
existing caller. It pairs with simplicity-principles for what to do once you've confirmed
something is speculative (delete it) versus genuinely reused (extract it).
