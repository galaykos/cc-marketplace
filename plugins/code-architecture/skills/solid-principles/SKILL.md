---
name: solid-principles
description: Use when designing or reviewing classes, interfaces, inheritance, or module boundaries — SOLID with judgment: SRP, open/closed, Liskov, interface segregation, dependency inversion.
---

## The lens, not the law

SOLID is five heuristics for keeping change cheap in class and module design. Each one earns
its keep only when the pain it prevents actually exists in the code — applied by reflex, every
one of them mass-produces the indirection that simplicity-principles and yagni-check exist to
delete. For each principle: what it demands, the detection cue in real code, the concrete fix,
and when the apparent violation is actually fine.

## S — Single Responsibility: one reason to change

**Demands:** a class or module changes for one reason — one actor or feature area whose
requirements drive its edits.

**Cue:** the same class keeps showing up in diffs for unrelated feature requests.
`ReportService` gets edited for a tax-rule change, then a PDF-layout change, then an SMTP
migration — three unrelated pressures, one file. Names that need `Manager`, `Handler`, or an
"And" to stay honest are a secondary hint.

**Fix:** split along the reasons-to-change seams, not along method count. Extract the
formatting into one unit and the delivery into another; keep a thin orchestrator that calls
both. Each resulting piece should be editable by its own feature stream without touching the
others.

**Not a violation:** cohesive small helpers grouped for convenience — a module of five pure
string functions, or a value object that both parses and formats its own data. One conceptual
responsibility may legitimately span several methods; shattering a 40-line class into four
10-line classes nobody can find costs more than the "violation" ever did.

## O — Open/Closed: extend without modifying

**Demands:** adding a new variant of existing behavior should mean adding code, not editing
every place that dispatches on the old variants.

**Cue:** a `switch`/`if-else` chain on a type code that grows a new branch with every feature —
and the same chain is duplicated across other files, so each new variant becomes a scavenger
hunt for every dispatch site.

```
// Every new shape edits this function (and its siblings elsewhere):
function area(shape) {
  switch (shape.kind) {
    case 'circle': return Math.PI * shape.r ** 2;
    case 'rect':   return shape.w * shape.h;
    // next feature adds a case here, and in perimeter(), and in draw()...
  }
}
```

**Fix:** move the variant behavior onto the variants — polymorphism, a strategy map keyed by
type, or a handler registry — so a new variant is one new module and zero edits to the
dispatcher.

**Not a violation:** one switch statement in one place, with two cases, that has never grown.
And the inverse error is worse: building extension points before a second variant exists is
speculative generality — a single-implementation interface "for extensibility" is exactly what
the yagni-check skill flags. Open/Closed is a response to observed change pressure, not a
default posture.

## L — Liskov Substitution: subtypes honor the base contract

**Demands:** any code written against the base type works, unchanged and unsurprised, when
handed any subtype. Substitutability is behavioral, not just type-signature deep.

**Cue:** overrides that throw "not supported" (a `Square` IS-A `Rectangle` until `setWidth`
breaks it), overrides that strengthen preconditions (base accepts any string, subtype rejects
empty ones), weaken postconditions, or return surprise nulls where the base promised a value.
Callers doing `instanceof` checks before daring to call a method are the smoke from this fire.

**Fix:** repair the hierarchy, not the caller. Either the subtype genuinely isn't a subtype —
break the inheritance and use composition instead — or the base contract promises too much:
narrow it (a read-only base that doesn't promise `add`) so every subtype can honor what
remains.

**Not a violation:** subtypes that extend behavior, accept *more* inputs than the base
promised, or differ in performance characteristics. LSP constrains the promised contract, not
every observable difference between implementations.

## I — Interface Segregation: no forced dependence on unused methods

**Demands:** clients depend only on the methods they actually call. An interface is shaped by
its consumers, not by the convenience of its one big implementer.

**Cue:** fat interfaces with stub implementations — classes implementing a 12-method
`Repository` where seven methods throw `NotImplemented` or return dummy values just to satisfy
the compiler. Test mocks that stub a dozen methods to exercise one are the same signal seen
from the test side.

**Fix:** slice the interface along client seams — `Readable` for the consumers that only read,
`Writable` for the one that writes — and let the big implementer implement several small
interfaces. Existing callers then narrow their parameter types to the slice they use.

**Not a violation:** splitting a two-method interface nobody struggles with. If every
implementer implements everything honestly and every client uses both methods, segregation
adds files and names for zero relief. Segregate when stubs appear, not before.

## D — Dependency Inversion: abstractions at module boundaries

**Demands:** high-level policy does not import low-level detail; at significant module
boundaries, both sides depend on an abstraction the policy side owns.

**Cue:** domain logic constructing infrastructure directly — a pricing rule that news up a
database client, an order workflow with an HTTP call and retry loop inline, a driver import at
the top of a file that is supposedly pure business policy. The test suite tells on it: you
cannot test the rule without a running database.

**Fix:** define the interface the domain needs (`OrderStore`, `PaymentGateway`), inject the
concrete implementation at the composition root, and keep infrastructure imports out of domain
modules. The abstraction belongs to the consumer and is shaped by what it needs — not a mirror
of the vendor SDK's surface.

**Not a violation:** wrapping every concrete class in an interface by reflex. A value object,
a stdlib call, or a stable in-process collaborator needs no interface between you and it.
Invert at genuine boundaries — process edges, vendors, things you swap in tests — and let
everything inside a module stay concrete. Single-implementation interfaces everywhere is
yagni-check territory, not architecture.

## SOLID motivates patterns — it never mandates them

Every fix above lands on a structure some pattern catalog has a name for (strategy, adapter,
composition over inheritance). That is the correct direction of travel: the violation creates
the pressure, and a pattern is one possible relief — chosen via the design-patterns plugin's
pattern-selection skill, which also lists when NOT to use each. Never the reverse: "we should
use Strategy here" is not a requirement, and simplest-thing-first (simplicity-principles)
still wins whenever a plain function or a small local edit relieves the same pressure.

## When to apply

Apply as a review lens when a class keeps changing for unrelated reasons, a dispatch chain
keeps growing, a mock needs a dozen stubs, or domain tests demand real infrastructure — those
pains are the trigger. Don't run it as a pre-emptive checklist on greenfield code: write the
simple concrete version first (simplicity-principles), let real change pressure reveal which
seams matter, and reach for the relevant principle then.
