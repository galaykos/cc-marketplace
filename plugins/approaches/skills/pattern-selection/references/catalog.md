# Pattern catalog — intent, structure, example

One entry per pattern the selector map names. Each: **Intent** (one line), **Use / Skip**
(mirrors the map), **Example** (minimal, runnable-shaped), and where useful a **Collapse** note
(the language idiom that replaces the class-based form). Names and categories follow the GoF
catalog. Read the entry before writing the pattern — do not reconstruct from memory.

---

## Creational

### Factory Method
- **Intent** — defer which concrete class to instantiate to a single seam, chosen by variant/env.
- **Use** — a caller shouldn't know or name the concrete type. **Skip** — one `new` reads clearly.
```js
function createLogger(env) {
  return env === "prod" ? new JsonLogger() : new PrettyLogger();
}
```

### Abstract Factory
- **Intent** — produce a *family* of related objects that must stay consistent together.
- **Use** — themes, platform driver sets (button+dialog+menu of one look). **Skip** — one product.
```js
const uiKit = theme === "dark"
  ? { button: DarkButton, dialog: DarkDialog }
  : { button: LightButton, dialog: LightDialog };
```

### Builder
- **Intent** — assemble a complex object step by step, avoiding a telescoping constructor.
- **Use** — many optional parts. **Skip** — ≤3 required args; call the constructor.
```js
const q = new QueryBuilder().from("users").where("age", ">", 18).limit(10).build();
```

### Prototype
- **Intent** — create new objects by cloning a configured instance.
- **Use** — construction is expensive and an existing instance is a good template. **Skip** — cheap
  to build fresh.
```js
const base = { role: "user", perms: ["read"] };
const editor = structuredClone(base); editor.perms.push("write");
```

### Singleton → Module / DI (do not use the Singleton class)
- **Intent** — one shared instance of a resource. The GoF Singleton (private ctor + static
  `getInstance`) hardcodes global mutable state, makes tests fight over one instance, and hides the
  dependency from signatures. Use a module export or constructor injection instead.
```js
// db.js — a module is already one instance per process
export const pool = createPool(config);
// consumers receive `pool` by import or injection, not via a global getInstance()
```

---

## Structural

### Adapter
- **Intent** — translate one interface into the one a client expects.
- **Use** — third-party/legacy shape you cannot change. **Skip** — you own both sides.
```js
// old lib is callback-based, app expects a promise
const adapted = (arg) => new Promise((res) => oldLib.doThing(arg, res));
```

### Bridge
- **Intent** — decouple an abstraction from its implementation so both vary independently.
- **Use** — two axes of change (shape × renderer). **Skip** — only one axis varies.
```js
class Shape { constructor(renderer) { this.r = renderer; } }   // r = SVG or Canvas impl
class Circle extends Shape { draw() { this.r.drawCircle(); } }
```

### Composite
- **Intent** — treat individual objects and compositions of them uniformly (part–whole trees).
- **Use** — UI trees, ASTs, filesystems. **Skip** — a flat list with no recursion.
```js
const size = (node) =>
  node.children ? node.children.reduce((n, c) => n + size(c), 0) : node.bytes;
```

### Decorator
- **Intent** — add responsibilities to an object dynamically, stackably, without subclassing.
- **Use** — cross-cutting wrap (logging, retry, cache). **Skip** — a one-off; inline it.
```js
const withRetry = (fn) => async (...a) => { try { return await fn(...a); } catch { return fn(...a); } };
const withLog   = (fn) => async (...a) => { console.log(a); return fn(...a); };
const robust = withLog(withRetry(fetchThing));   // stacks
```

### Facade
- **Intent** — a single simple entry point over a messy multi-part subsystem.
- **Use** — hide orchestration of several classes. **Skip** — the subsystem is already small.
```js
// one call hides encoder + muxer + uploader
function publishVideo(file) { return upload(mux(encode(file))); }
```

### Flyweight
- **Intent** — share heavy immutable state across many instances to cut memory.
- **Use** — thousands of objects with common data (glyphs, tiles). **Skip** — few instances.
```js
const glyphCache = new Map();
const glyph = (ch) => glyphCache.get(ch) ?? glyphCache.set(ch, renderGlyph(ch)).get(ch);
```

### Proxy
- **Intent** — a stand-in that controls access to a target (lazy, remote, protection).
- **Use** — defer/authorize/guard access. **Skip** — no access concern; call directly.
```js
const lazy = new Proxy({}, { get: (_, k) => (heavy ??= load())[k] });   // load on first access
```

---

## Behavioral

### Chain of Responsibility
- **Intent** — pass a request along handlers until one handles it.
- **Use** — middleware, staged validation. **Skip** — 2–3 fixed checks; early-return ifs.
```js
for (const handler of middleware) { if (handler(req)) break; }   // first to return truthy wins
```

### Command
- **Intent** — turn a request into a first-class object to queue, log, retry, or undo.
- **Use** — deferred/undoable operations. **Skip** — called immediately, never undone.
```js
const cmd = { do: () => doc.insert(text), undo: () => doc.delete(text) };
history.push(cmd); cmd.do();
```

### Interpreter
- **Intent** — represent a small grammar and evaluate its sentences.
- **Use** — a bounded rules/expression DSL you own. **Skip** — anything real; use a parser lib.
```js
const evalNode = (n) => n.op === "+" ? evalNode(n.l) + evalNode(n.r) : n.value;
```

### Iterator
- **Intent** — traverse a collection without exposing its representation.
- **Use** — custom traversal order. **Skip** — the language provides it.
```js
function* inorder(node) { if (!node) return; yield* inorder(node.l); yield node.v; yield* inorder(node.r); }
```

### Mediator
- **Intent** — route many-to-many interactions through one object so colleagues don't couple.
- **Use** — a form's fields enabling/disabling each other, chat room. **Skip** — only two parties.
```js
const room = { join(u) { this.users.push(u); }, send(from, msg) { this.users.forEach(u => u !== from && u.recv(msg)); }, users: [] };
```

### Memento
- **Intent** — capture and restore an object's state without exposing its internals.
- **Use** — undo where the inverse is not cheaply computable. **Skip** — a known inverse (Command).
```js
const save = () => structuredClone(editor.state);           // opaque snapshot
const restore = (snap) => { editor.state = snap; };
```

### Observer
- **Intent** — notify a changing set of listeners when a subject changes, without coupling to them.
- **Use** — one source, many/unknown reactors. **Skip** — a single fixed callee.
```js
bus.on("order:placed", sendConfirmationEmail);
bus.on("order:placed", updateInventory);
```

### State
- **Intent** — alter an object's behavior when its internal state changes (a state machine).
- **Use** — behavior depends on a state that transitions. **Skip** — a fixed `if` that won't grow.
```js
const transitions = { idle: startFn, running: pauseFn, paused: resumeFn };
transitions[machine.state]();   // behavior swaps as `state` changes — the object drives it
```

### Strategy
- **Intent** — define a family of interchangeable algorithms, chosen by the caller.
- **Use** — swap pricing/sorting/validation at a call site. **Skip** — two branches, no third coming.
```js
function checkout(cart, priceStrategy) { return priceStrategy(cart); }
checkout(cart, blackFridayPricing);   // caller picks — contrast State, where the object picks
```

### Template Method
- **Intent** — a fixed algorithm skeleton with subclass-supplied steps.
- **Use** — shared flow, varying steps. **Skip** — prefer composition: inject a Strategy instead.
```js
const report = (renderSection) => `<<${renderSection()}>>`;   // skeleton fixed, step injected
```

### Visitor
- **Intent** — add new operations over a stable object structure without changing its classes.
- **Use** — many operations over a fixed node set (AST passes). **Skip** — the node set changes often.
```js
const visit = (node, v) => v[node.type](node);   // add ops by adding keys to v, not touching nodes
```

---

## Beyond GoF (worth knowing)

### Repository
- **Intent** — a collection-like interface over data access, so callers don't embed query details.
- **Use** — isolate persistence, swap the store, test with an in-memory fake. **Skip** — a thin app
  where the ORM/query builder already is your data layer — a pass-through Repository is ceremony.

### Null Object
- **Intent** — a do-nothing object with the expected interface, to remove `null` checks.
- **Use** — a default that safely absorbs calls (a no-op logger). **Skip** — when `null` genuinely
  means "handle this differently," hiding it defers a real decision.

### Dependency Injection
- **Intent** — pass a collaborator in rather than constructing it inside — the composition-first
  answer to shared state and hard-wired dependencies. Underpins the Strategy/Module preferences above.
