---
name: typescript-best-practices
description: Use when writing or reviewing TypeScript code — strict mode as the non-negotiable floor plus noUncheckedIndexedAccess/exactOptionalPropertyTypes, any vs unknown discipline, narrowing over assertions, discriminated unions with never-exhaustiveness, runtime validation at boundaries (zod/valibot, parse-don't-validate), generics restraint, as const and satisfies, string literal unions over enums, tsconfig hygiene, all pinned to the typescript version in the lockfile.
---

## Know the version before advising

Version facts come from the lockfile, never from memory:

- The locked `typescript` entry (package-lock.json / yarn.lock / pnpm-lock.yaml /
  bun.lock) is what actually compiles the code — a `^5.0` constraint permits 5.0
  through 5.x; only the lock says whether 5.5's inferred predicates are present.
- Feature floors that gate this skill's advice: `satisfies` 4.9; `const` type
  parameters, `verbatimModuleSyntax`, `moduleResolution: "bundler"` 5.0; `using`
  declarations 5.2; `NoInfer` 5.4; inferred type predicates on `.filter` 5.5;
  `--erasableSyntaxOnly` 5.8. Recommend nothing above the lock; flag no
  workaround the locked version has not yet killed.
- Read `tsconfig.json` (and its `extends` chain) before advising — half of this
  skill is compiler flags, and advice the config already enforces is noise.
- The build tool matters: Vite/esbuild/swc strip types without checking, so
  `tsc --noEmit` in CI is the only thing between a red squiggle and production.

## Strict mode is the floor

- `strict: true` is non-negotiable — it is a bundle (strictNullChecks,
  noImplicitAny, strictFunctionTypes, useUnknownInCatchVariables, ...) and every
  member kills a real bug class; null-unsoundness alone justifies it.
- Next tier, on by default in new projects: `noUncheckedIndexedAccess` makes
  `arr[i]` and `record[key]` return `T | undefined` — the out-of-bounds reads
  strict mode still misses; `exactOptionalPropertyTypes` separates "absent" from
  "explicitly undefined", which spread-merges and JSON round-trips treat differently.
- Cheap additional wins: `noImplicitOverride`, `noFallthroughCasesInSwitch`.
- Legacy adoption: turn the flags on, baseline the current errors, ratchet down —
  never leave strict off because old files complain.

## any is contagion

- One `any` infects everything downstream: it silences the checker through every
  property access, call, and assignment it flows into. Grep for explicit `any`
  in review; `noImplicitAny` only catches the implicit kind.
- Reach for `unknown` instead: it accepts everything but demands narrowing
  before use — the checking `any` skips, made mandatory.
- `as` is a claim without proof. Last resort only, with a comment defending why
  it is safe at this exact point; an assertion that needs `as unknown as T` to
  compile is a lie in writing.

## Keep literal inference

- `as const` freezes literal types on fixed data: tuples, config, lookup keys.
- `satisfies` (4.9+) checks a value against a type WITHOUT widening it — a
  `: Record<string, Route>` annotation erases the known keys; `satisfies
  Record<string, Route>` validates and keeps them. Use satisfies for config
  objects and maps; keep explicit annotations for exported function signatures,
  where inference leaking implementation detail is the bug.

## Narrowing toolbox

- Discriminated unions over boolean flags: `{ status: 'ok'; data: T } |
  { status: 'error'; error: E }` makes impossible states unrepresentable, where
  `{ ok: boolean; data?: T; error?: E }` invites checking one field and reading
  the other.
- Built-in narrowing first (`typeof`, `instanceof`, `in`, equality on the
  discriminant); write a type predicate (`x is Fish`) only when the check is
  reused. From 5.5, simple `.filter((x) => x !== null)` predicates are inferred.
- Exhaustiveness via `never`: in the `switch` default, `const _exhaustive:
  never = value` turns "someone added a variant" into a compile error instead
  of a silent fallthrough.

## Validate at runtime boundaries

Compile-time types stop where the program meets the world: API responses, env
vars, form input, `JSON.parse`, localStorage, queue messages.

- Parse with a schema (zod/valibot) at the edge and derive the static type from
  it (`z.infer`) — one source of truth, no type/validator drift.
- Parse, don't validate: convert loose input into a rich domain type once, at
  the boundary; everything downstream trusts the type instead of re-checking.
- Errors are a boundary too: `catch` binds `unknown` under strict — narrow with
  `instanceof` before touching `.message`. Prefer typed error unions or error
  subclasses over throwing strings and catching hopes.

## Generics restraint

- A type parameter used once is a plain type: `function log<T>(x: T): void` is
  `function log(x: unknown): void`. A generic earns its place by RELATING two
  positions — argument to return, or two arguments to each other.
- Constraints (`extends`) over conditional-type cleverness — a three-level
  conditional type produces error messages nobody can act on and compile times
  everybody pays for.
- Let inference fill type arguments at call sites; explicit `f<Foo>(...)`
  usually means the signature is fighting inference.

## Shapes, utilities, brands

- `interface` for object shapes a consumer may extend or declaration-merge
  (public library surface); `type` for unions, tuples, functions — and, as the
  internal default, object shapes too, since it cannot merge by accident.
- Reach for `Pick`/`Omit`/`Partial`/`Readonly`/`Record` before hand-rolling a
  mapped type; the reader already knows what the utility means.
- Branded types where same-shaped domains mix: `type UserId = string &
  { readonly __brand: 'UserId' }` makes passing an `OrderId` to `getUser` a
  compile error — cheap insurance in a codebase juggling several string IDs.

## Enums are legacy; unions won

- String literal unions (`type Status = 'active' | 'archived'`) or a `const`
  object cover the use cases. `enum` emits runtime code, so it breaks under
  type-stripping runtimes (Node `--experimental-strip-types`) and is rejected by
  `--erasableSyntaxOnly` (5.8); `const enum` is worse — it cannot survive
  isolated per-file compilation.
- Need runtime values plus a type? `const Status = { Active: 'active' } as
  const; type Status = (typeof Status)[keyof typeof Status]`.

## tsconfig hygiene

- `verbatimModuleSyntax` (5.0+): imports mean what they say, `import type` is
  explicit, transpilers stop guessing what to elide. Pair with
  `isolatedModules` for any esbuild/swc/babel build.
- `moduleResolution: "bundler"` for Vite-era apps (extensionless imports,
  `exports` maps honored); `NodeNext` for code Node itself will load —
  published libraries need the real rules, including file extensions.
- `skipLibCheck: true` is a pragmatic default for broken third-party `.d.ts` —
  it is never the fix for errors in your own declaration files.
- Monorepos: project references with `composite: true` — per-package type
  boundaries, incremental `tsc -b` that only rebuilds what changed.

## Anti-patterns

- Any-laundering via `JSON.parse`/`res.json()`: the `any` flows unchecked into
  typed code and the annotation on the receiving variable becomes fiction.
  Type the result `unknown` or parse it with a schema.
- Non-null `!` chains — each `!` is an unverified runtime bet, and `a!.b!.c` is
  two of them. Narrow, or use `?.` with a real fallback.
- `as unknown as T` to force a shape through — that is disabling the compiler
  locally without the honesty of a suppression comment.
- `@ts-ignore` over `@ts-expect-error`: ignore keeps suppressing after the
  error is gone; expect-error fails the build when it becomes unnecessary.
- The `Function` type, `{}`, or bare `object` as parameter types — write the
  signature, or use `Record<string, unknown>`/`unknown`.
- Annotating what inference already knows (`const n: number = 5`) — noise that
  buries the annotations that matter and widens literals for free.
- Boolean-flag state bags (`loading` + `error?` + `data?`) instead of a
  discriminated union — the type permits states the code cannot handle.
- Fixing a red build by loosening compiler flags — strictness ratchets one way.
