---
name: javascript-best-practices
description: Use when writing or reviewing plain (non-TypeScript) JavaScript — strict equality and coercion traps, const/let over var, ESM/CommonJS interop, async correctness, this-binding and arrows, closures and leaks, immutability and shared references, error cause chains, boundary validation of JSON/fetch data, number precision/BigInt, prototype-pollution and eval security — pinned to the Node/ES floor from engines/browserslist/lockfile. Framework rules and types live in their own plugins.
---

This is VANILLA JavaScript, not TypeScript — no compiler catches the mistakes below, so the discipline lives in the code and the review. Version facts come from the manifests, never from memory.

## Know the version before advising

- `package.json` `engines.node` is the runtime floor for server code — advise
  nothing above it, flag nothing it solves. Absent it, `.nvmrc`/`.tool-versions`
  is the next signal; the lockfile records what actually resolved (a `^20`
  constraint says nothing about whether a Node 22 API is present).
- `browserslist` (package.json or `.browserslistrc`) is a SEPARATE floor for
  browser code — its oldest target, not Node, gates what syntax survives without
  transpilation. Node runtime and browser targets are different floors; advise
  against the lower of whichever applies to the file.
- `"type": "module"` decides ESM vs CJS for `.js` files — it changes what
  `import`/`require`, `__dirname`, and top-level `await` mean. Check it first.
- A bundler (Vite/esbuild/Babel) may transpile above the floor, but only when its
  config proves it — do not assume down-leveling nobody configured.

## Per-version leverage (advise at or below the floor)

Each ES release retires a workaround — using it above its killer version is a
finding, using the feature below the floor is a bug:

- **ES2020** — optional chaining `a?.b`, nullish `??`, `import.meta`, `BigInt`,
  `Promise.allSettled`, `globalThis` — replaces `a && a.b` ladders and `0`/`''`-swallowing `||`-defaults.
- **ES2021** — `replaceAll`, logical assignment `??=`/`||=`/`&&=`, numeric separators, `Promise.any`.
- **ES2022** — top-level `await`, `.at(-1)`, `Object.hasOwn` (over
  `hasOwnProperty.call`), Error `cause`, class fields and true private `#members`.
- **ES2023** — immutable-copy `toSorted`/`toReversed`/`toSpliced`/`with`, `findLast`/`findLastIndex`.
- **ES2024** — `Object.groupBy`/`Map.groupBy`, `Promise.withResolvers`, the regex `/v` flag.
- **ES2025** — iterator helpers (lazy `.map`/`.filter`/`.take` on iterators), Set
  methods (`union`/`intersection`), `RegExp.escape`, `Promise.try`, JSON modules, `Float16Array`.
- **ES2026** — `Array.fromAsync` (async-iterable → array), `Error.isError`,
  `Math.sumPrecise`, `Uint8Array` base64/hex codecs.
- `structuredClone(value)` (Node 17+, modern browsers) is the deep-clone answer,
  replacing `JSON.parse(JSON.stringify(...))` which drops `Date`/`Map`/`undefined`.

## Equality and coercion

- `===`/`!==` always; `==` juggles types: `0 == ''`, `'1' == 1`, `[] == false`
  are all true, `NaN === NaN` is false (use `Number.isNaN`). Grep for `[^=!]==[^=]`.
- The one sanctioned loose check is `x == null` — true for exactly `null`/
  `undefined`, false for `0`/`''`/`false`. Use it deliberately as the nullish test.
- Truthiness traps: `0`, `''`, `NaN`, `null`, `undefined`, `false` are all falsy,
  so `if (count)` skips a real `0`. Test the condition you mean (`count > 0`,
  `value != null`), not a coincidental coercion.

## Bindings, scope, and this

- `const` by default, `let` when reassigned, `var` never — `var` is
  function-scoped and hoisted, resurrecting the loop-closure bug block-scoped
  `let` fixes for free.
- `this` is bound by CALL SITE, not definition — a method torn off its object
  (`const f = obj.method; f()`) loses `this` (pass `obj.method.bind(obj)`). Arrow
  functions capture the enclosing `this`: right for callbacks, WRONG for object and
  prototype methods and anything called with `new` or needing a dynamic `this`.

```js
const obj = { n: 1, get: () => this.n };   // bad — arrow captures module this, not obj
const obj = { n: 1, get() { return this.n } }; // good
```

## Modules: ESM vs CommonJS

- Pick one per package and honor `"type"`. In ESM there is no `__dirname` — derive
  it: `const __dirname = path.dirname(fileURLToPath(import.meta.url))`.
- Interop bites at the default export: `import fs from 'fs'` and
  `import { readFile } from 'fs'` are not interchangeable, and a CJS
  `module.exports = fn` arrives as the ESM default. Prefer named exports — they
  tree-shake and survive refactors that rename the default.

## Async correctness

- Await the promise or return it — a floating async call loses its error and its
  ordering, and an unawaited rejection is an unhandledRejection (a modern-Node crash).
- Independent work runs concurrently: `await Promise.all([a(), b()])`, not two
  sequential awaits. `Promise.allSettled` when one failure must not abort the rest.
- Sequential-in-loop is usually the bug: `for (const x of xs) await f(x)` runs one
  at a time; `Promise.all(xs.map(f))` runs them together (cap concurrency if the
  target can be overwhelmed).

```js
for (const id of ids) results.push(await fetchOne(id)); // bad — serial round-trips
const results = await Promise.all(ids.map(fetchOne));   // good — concurrent
```

- Event-loop order, practically: sync code finishes, then microtasks (resolved
  promises, `queueMicrotask`) drain FULLY, then one macrotask (`setTimeout`, I/O),
  and repeat — so a `.then` beats `setTimeout(…, 0)`, a microtask that re-queues
  microtasks starves I/O, and a long sync loop freezes every pending callback.

## References, closures, and leaks

- Objects and arrays are assigned by reference: `const b = a` aliases, mutating
  `b` mutates `a`. Spread (`{ ...obj }`, `[...arr]`) copies one level only — nested
  objects stay shared, so deep-copy with `structuredClone`. Prefer the ES2023
  non-mutating methods (`toSorted`, `with`) over `sort`/splice-in-place.
- Closures capture variables by reference, so the whole enclosing scope lives as
  long as the closure — a handler closing over a large object pins it.
- Every `addEventListener`, `setInterval`, and subscription needs a matching
  teardown (`removeEventListener`/`clearInterval`/unsubscribe), or it leaks along
  with its captured scope. Tie teardown to the lifecycle that created it.

## Errors

- `throw new Error(msg)` (or an `Error` subclass), never a string — a thrown string
  has no stack. Chain: `throw new Error('load failed', { cause: err })` keeps the original.
- `catch` binds whatever was thrown, which may not be an `Error` — narrow before
  touching `.message` (`err instanceof Error ? err.message : String(err)`). Never
  swallow: an empty `catch {}` is a deleted bug report.

## Validate at the boundary

- `JSON.parse`, `res.json()`, `localStorage`, env vars, and message payloads
  return UNTRUSTED, unknown-shaped data — treating the result as the shape you
  hoped for is how `undefined is not a function` reaches production. Validate at
  the edge (a schema like zod/valibot, or hand-written guards); the rest of the
  code then trusts the checked shape.
- Numbers are IEEE-754 doubles: `0.1 + 0.2 !== 0.3`, and integers above
  `Number.MAX_SAFE_INTEGER` (2^53−1) silently lose precision — deadly for money,
  IDs, and DB bigints. Use integer minor units or a decimal library for currency;
  use `BigInt` for exact large integers (it will not mix with `Number` in
  arithmetic, and `JSON.parse` cannot produce it — parse from the string).

## Security at boundaries

- Prototype pollution: assigning attacker-controlled keys (`obj[key] = val` from
  parsed input) lets `__proto__`/`constructor`/`prototype` poison
  `Object.prototype` globally. Reject those keys, use a `Map`, or
  `Object.create(null)` for lookup tables built from external data.
- Never `eval`/`new Function` on anything derived from input — it is arbitrary
  code execution. There is almost always a parser or lookup that does the job.

## Common mistakes

- `==` where `===` was meant; `if (value)` guards a real `0`/`''` fails; `var`.
- Arrow functions as object/prototype methods (lost `this`); floating promises and
  `for … await` serial loops where `Promise.all` belonged.
- `JSON.parse(JSON.stringify(x))` clone (drops `Date`/`Map`/`undefined`) over
  `structuredClone`; mutating a shared array/object through an alias.
- `throw 'string'`, empty `catch {}`, a `catch` that logs and continues; trusting
  `res.json()` shape unvalidated; `parseInt` without a radix; `for…in` over arrays.

## Verify Against Current Docs

Language features land at different Node and browser versions, and APIs like
`structuredClone`, iterator helpers, and `Array.fromAsync` are version-sensitive.
Before relying on memory, check https://developer.mozilla.org/en-US/docs/Web/JavaScript
(and https://nodejs.org/docs for runtime APIs), tying every version-sensitive call
to the actual `engines`/`browserslist` floor and the lockfile.
