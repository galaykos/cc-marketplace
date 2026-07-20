---
name: pattern-selection
description: Use when structuring code and weighing — or naming — a design pattern (Factory, Strategy, Observer, Decorator, and the rest of the GoF catalog). Maps a problem to the right creational/structural/behavioral pattern, gives when-NOT per pattern, disambiguates look-alikes, points to the full catalog; simplest-thing-first, refactor-to-pattern only when the simple thing breaks.
---

## The rule: name the problem first, pattern second

If you can't state the problem the pattern solves in one plain sentence, you don't need the
pattern. Patterns are named solutions to recurring problems, not a checklist to apply up front,
and not "more professional" than a plain function or a conditional. Start with the simplest thing
that could work; reach for a pattern only when that simple thing demonstrably breaks down
(duplicated branching that keeps growing, a caller that needs to swap behavior it doesn't own).
Each row below carries a **Skip when** — the failure mode of applying it too early.

## Gate: earn the pattern before you read the map

The map routes; this gate decides whether to route at all. Answer all three — any **no** means
stop and ship the plain version. Do not skim to the table first.

1. **Named the simple version?** State the non-pattern solution — a function, a conditional, a
   plain object. If you can't, you don't understand the problem yet, let alone the pattern.
2. **Has it actually broken *here*?** Breakage is concrete and present: branching that keeps
   growing, one change forcing edits in N places, a caller needing to swap behavior it doesn't
   own. "Might need it later" is not breakage — it's speculation. Speculation loses.
3. **Problem stated in one sentence without a pattern name?** If the only justification is
   "cleaner" or "more professional," that's pattern-for-pattern's-sake. Stop.

Three yeses → open the map. Otherwise the simple version *is* the answer; record why in a comment
and move on.

## How to use the map

1. State the problem in one sentence — the recurring pain, not the solution you already imagined.
2. Find the row whose **Use when** matches that pain; check its **Skip when** does not describe you.
3. If two rows fit, read the **Look-alikes** section — the difference is intent, not shape.
4. Open `references/catalog.md` for that pattern's example before writing it. Prefer the idiom form.

## Problem → pattern map

### Creational
| Pattern | Use when | Skip when |
|---|---|---|
| Factory Method | one seam must pick the concrete type by variant/env | a single `new` or object literal already reads clearly |
| Abstract Factory | a family of related objects must vary together (theme, platform driver) | only one product, or the family never grows a second axis |
| Builder | assembly has many optional steps → a telescoping constructor | ≤3 args, all required — just call the constructor |
| Prototype | cloning a configured instance beats rebuilding from scratch | construction is cheap; `structuredClone`/spread already clones |
| Module / DI (not Singleton) | one shared resource (DB pool, config) injected or module-scoped | never the Singleton class — it hides global mutable state; inject instead |

### Structural
| Pattern | Use when | Skip when |
|---|---|---|
| Adapter | wrap an incompatible third-party/legacy interface into the shape you expect | you own both sides — change the signature, don't add a permanent translator |
| Bridge | abstraction and implementation must vary on two independent axes | only one axis varies — there is no cross-product to decouple |
| Composite | leaf and tree must be treated uniformly (UI tree, AST, filesystem) | a flat list with no recursion |
| Decorator | stackable cross-cutting wrap (logging, retry, caching) around an object | a one-off addition — inline it at the call site |
| Facade | hide a messy multi-part subsystem behind one simple entry point | the subsystem is already small and clear |
| Flyweight | share heavy immutable state across very many instances | few instances, or the shared state is cheap |
| Proxy | control access to a target — lazy-load, remote, permission guard | no access concern — call the target directly |

### Behavioral
| Pattern | Use when | Skip when |
|---|---|---|
| Chain of Responsibility | ordered handlers, each may handle or pass the request (middleware) | 2–3 fixed checks — an early-return `if` sequence is more direct |
| Command | an operation must become a value to queue, log, retry, or undo | called immediately, never deferred or undone — just call the function |
| Interpreter | evaluate sentences of a small grammar you define (rules DSL) | anything non-trivial — use a real parser library |
| Iterator | traverse a collection without exposing its internals | the language gives it (`for…of`, generators) |
| Mediator | many-to-many communication collapsed through one hub | only two colleagues — let them talk directly |
| Memento | snapshot and restore opaque state for undo | the inverse op is cheap to compute — use Command undo |
| Observer | notify unknown listeners when state changes | a single fixed callee — that's just a function call |
| State | behavior changes with an internal state (a state machine) | a fixed `if/else` on a value that won't grow new states |
| Strategy | interchangeable algorithm chosen by the caller | two fixed branches that will never gain a third |
| Template Method | fixed skeleton, subclasses fill in steps | composition (inject a Strategy) fits — prefer it over inheritance |
| Visitor | add new operations over a stable node hierarchy | the node set changes often — Visitor makes that painful |

## Look-alikes — same shape, different intent

- **Strategy vs State** — identical structure; Strategy is swapped by the caller, State swaps
  itself as internal data changes.
- **Decorator vs Proxy** — both wrap a target; Decorator adds behavior, Proxy controls access
  (and may add nothing).
- **Observer vs Mediator** — Observer is one source → many listeners; Mediator is many ↔ many
  routed through a hub.
- **Command vs Memento** — undo via a known inverse (Command) vs an opaque snapshot (Memento).
- **Adapter vs Facade** — Adapter converts one interface to another expected one; Facade invents
  a simpler interface over several.
- **Factory Method vs Abstract Factory vs Builder** — one product by subtype / a whole family
  together / one product assembled in many steps.

## The idiom-collapse three

In languages with closures and first-class functions (JavaScript, TypeScript, PHP), reach for the
idiom before the class-based form:

```js
// Strategy → a function parameter          Command → a closure capturing intent + inverse
checkout(cart, blackFridayPricing);         const cmd = { do: () => doc.insert(t), undo: () => doc.delete(t) };
// Observer → an event emitter
bus.on("order:placed", sendConfirmationEmail);
```

Two more that collapse the same way:

```js
// State → a table of behaviors keyed by the current state (no class per state)
const transitions = { idle: startFn, running: pauseFn, paused: resumeFn };
transitions[machine.state]();
// Template Method → a higher-order function taking the varying step, not a subclass
const report = (fmt) => `<<${section(fmt)}>>`;   // fmt is the injected step
```

## Anti-patterns to avoid

- **Pattern-for-pattern's-sake**: reaching for Strategy/Factory/Observer because it "looks more
  professional," when a function or a conditional already says the same thing more plainly.
- **Singleton-as-global-state**: using Singleton to smuggle mutable global state past code review;
  it's the same problem as a global variable with extra ceremony.
- **Inheritance where composition fits**: a class hierarchy to share behavior when injecting a
  dependency (Strategy over Template Method) would do it without coupling subclasses to a taxonomy.

## Full catalog — intent, structure, example per pattern

For any pattern in the map, read `references/catalog.md` (this skill's directory) before writing
code: it carries the intent, a minimal structure, a runnable example, and the collapse-to-idiom
note for all patterns above plus non-GoF ones (Repository, Null Object, DI). Do not reconstruct a
pattern from memory. For diagrams or a fuller applicability checklist, the GoF write-ups live at
https://refactoring.guru/design-patterns
