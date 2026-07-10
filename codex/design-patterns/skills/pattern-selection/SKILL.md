---
name: pattern-selection
description: Use when structuring code and considering a design pattern — maps problems to patterns (creational, structural, behavioral), and lists when NOT to use each; simplest-thing-first.
---

## The rule: name the problem first, pattern second

If you can't state the problem the pattern solves in one plain sentence, you don't need the
pattern. Patterns are named solutions to recurring problems, not a checklist to apply up front,
and not "more professional" than a plain function or a conditional. Start with the simplest thing
that could work; reach for a pattern only when that simple thing demonstrably breaks down
(duplicated branching that keeps growing, a caller that needs to swap behavior it doesn't own).

## Problem → pattern map

| Problem | Pattern | Category |
|---|---|---|
| Object creation with variants (subclass choice, optional steps) | Factory / Builder | Creational |
| Incompatible interface between existing code and what you need | Adapter | Structural |
| Swap an algorithm or behavior at runtime | Strategy | Behavioral |
| React to events or state changes from multiple listeners | Observer | Behavioral |
| Wrap an object with cross-cutting behavior (logging, caching, auth) | Decorator | Structural |
| Sequential processing where any step can bail out or handle it | Chain of Responsibility | Behavioral |
| Undoable or queueable operations | Command | Behavioral |
| One shared resource, config, or connection | Module / DI (not Singleton) | — |

## Factory / Builder — object creation with variants

Use when constructing an object requires choosing among variants, or assembly needs several
optional steps that would otherwise become a constructor with eight optional arguments. Do NOT
use when a single `new` call or a plain object literal already reads clearly — a Factory around
one concrete class adds a layer without adding a choice.

```js
// Factory: caller doesn't need to know which concrete class it gets
function createLogger(env) {
  return env === "prod" ? new JsonLogger() : new PrettyLogger();
}
```

## Adapter — incompatible interface

Use when you must plug a third-party or legacy API into code that expects a different shape and
cannot change either side. Do NOT use when you control both sides — just change the callee's
signature instead of adding a permanent translation layer.

```js
// Adapter: old lib returns callbacks, app expects promises
const adapted = (arg) => new Promise((res) => oldLib.doThing(arg, res));
```

## Strategy — swap behavior at runtime

Use when a caller selects among interchangeable algorithms (sorting, pricing, validation) without
an if/else ladder growing at every call site. Do NOT use for two fixed branches that never gain a
third — a plain `if` beats a two-class hierarchy built for hypothetical future variants.

```js
// Strategy as a function parameter — no class hierarchy needed
function checkout(cart, priceStrategy) { return priceStrategy(cart); }
checkout(cart, standardPricing);
checkout(cart, blackFridayPricing);
```

## Observer — react to events or state changes

Use when one or more parts of the system must react to something happening elsewhere, and the
source shouldn't need to know who's listening. Do NOT use for a single fixed caller/callee
relationship — that's just a function call, and subscribe/notify adds indirection for nothing.

```js
// Observer via a plain event emitter
bus.on("order:placed", sendConfirmationEmail);
bus.on("order:placed", updateInventory);
```

## Decorator — cross-cutting wrap

Use when you need to add behavior (logging, retries, caching) around an existing object without
modifying its class, and you may need to stack several such wraps. Do NOT use for a one-off
addition — inline the logic at the call site rather than defining a wrapper used exactly once.

```js
// Decorator: wraps fetch with retry, leaves the original untouched
const withRetry = (fn) => async (...args) => { try { return await fn(...args); } catch { return fn(...args); } };
```

## Chain of Responsibility — sequential processing with bail-out

Use for a pipeline of handlers where each gets a chance to process or reject a request and the
set of handlers changes independently of the caller (middleware, validation stages). Do NOT use
for two or three fixed checks — an early-return sequence of `if` statements is more direct.

```js
// Chain of Responsibility as an array of functions, short-circuiting
for (const handler of middleware) { if (handler(req)) break; }
```

## Command — undoable or queueable operations

Use when an operation needs to be queued, logged, retried, or undone — the request itself must
become a first-class value, not just a function call. Do NOT use when you only ever call the
operation immediately with no need to defer, queue, or undo it — that's just calling the function.

```js
// Command as a closure — capture intent and its inverse
const cmd = { do: () => doc.insert(text), undo: () => doc.delete(text) };
```

## Module / DI over Singleton — single shared resource

Use a module-level instance or constructor-injected dependency when something must be shared
(a DB pool, a config object). Do NOT reach for the classic Singleton pattern (private constructor
+ static `getInstance`) — it hardcodes global mutable state, makes tests fight over shared
instances, and hides the dependency from callers' signatures. A module export or an injected
instance gives you the same "one instance" property without the coupling.

```js
// Not Singleton class — a module is already one instance per process
// db.js
export const pool = createPool(config);
```

## Anti-patterns to avoid

- **Pattern-for-pattern's-sake**: reaching for Strategy/Factory/Observer because it "looks more
  professional," when a function or a conditional already says the same thing more plainly.
- **Singleton-as-global-state**: using Singleton to smuggle mutable global state past code review;
  it's the same problem as a global variable with extra ceremony.
- **Inheritance where composition fits**: building a class hierarchy to share behavior when
  injecting a dependency or embedding a helper object would do it without coupling subclasses to
  a rigid taxonomy.

## Language-idiom note

In languages with closures and first-class functions (JavaScript, TypeScript, PHP), many GoF
patterns collapse into simpler idioms — reach for these before the classic class-based form:

- **Strategy** → a function passed as a parameter.
- **Command** → a closure capturing the action (and optionally its inverse for undo).
- **Observer** → an event emitter (`EventEmitter`, DOM events, a pub/sub bus).

## Docs pointer

Pattern names, intents, and structure diagrams in this skill follow the standard GoF catalog.
When you need a fuller writeup, applicability checklist, or a diagram for a pattern not covered
above, check the reference catalog rather than relying on memory: https://refactoring.guru/design-patterns
