---
name: php-best-practices
description: Use when writing or reviewing plain PHP code — strict types and === discipline, PSR-4/PSR-12 conventions, version-aware advice pinned to the composer.json floor with a per-version leverage map (8.1 through 8.5), exception handling, DateTimeImmutable, boundary security (prepared statements, output escaping), value objects, static analysis. Framework-specific rules live in the laravel/livewire plugins.
---

## Know the version before advising

Version facts come from the manifests, never from assumption:

- `composer.json` `require.php` is the advice floor — recommend nothing above it,
  flag nothing the floor already solves. `config.platform.php` overrides it for
  dependency resolution; `composer.lock` says what is ACTUALLY installed (a `^2.0`
  constraint tells you nothing about whether 2.3's fix is present — the lock does).
- `php -v` is the runtime, relevant for CLI/CI mismatches with the floor.
- Mixed repos (Laravel + Vite) also carry `package.json`/lockfile — that governs the
  JS side only; never infer PHP capabilities from it, or vice versa.
- Floor below 8.1: do not modernize piecemeal in review — recommend a Rector-driven
  upgrade path first, then apply this skill at the new floor.

## Per-version leverage (advise at or below the floor)

Each release kills a category of workaround — using the workaround above its
killer version is a finding:

- **8.1** — enums replace class-constant clusters; `readonly` properties replace
  private-plus-getter immutability; first-class callables; `never` for functions
  that only throw/exit; `new Foo()` in initializers replaces nullable-then-assign.
- **8.2** — `readonly class` replaces per-property `readonly` noise; DNF types;
  constants in traits; `#[SensitiveParameter]` keeps secrets out of stack traces;
  dynamic properties deprecated — declare them or the class is lying about shape.
- **8.3** — typed class constants; `#[Override]` turns silent rename drift into a
  compile error (use it on every intentional override); `json_validate()` replaces
  decode-and-discard validation.
- **8.4** — property hooks kill getter/setter boilerplate (a hook beats 8 lines of
  accessor); asymmetric visibility `private(set)` kills clone-heavy readonly
  workarounds; `array_find`/`array_any`/`array_all` kill foreach-and-break scans;
  `new Foo()->bar()` chains without wrapping parens; lazy objects for costly
  construction behind proxies.
- **8.5** — pipe operator `|>` replaces inside-out nested call pyramids with
  left-to-right flow; `array_first()`/`array_last()` kill `reset()`/`end()` pointer
  juggling; clone-with (`clone($obj, [...])`) makes readonly "withers" one-liners;
  `#[NoDiscard]` flags ignored return values that must be used.

## Strict types and type declarations

`declare(strict_types=1)` at the top of every file — without it, PHP silently coerces
scalar arguments ("5 apples" passes as int 5). Type every parameter, return, and
property; untyped is a decision someone else has to reverse-engineer. Prefer precise
types over `mixed` (a last resort that pushes checking onto every caller), and
`?Foo` only when null is a real domain state — not a lazy default. Since 8.0, union
types beat doc-comment lies: `int|string` in the signature is checked, `@param` is not.

## Comparison discipline

- `===`/`!==` always. Loose `==` juggles types: `0 == "a"` changed meaning across
  PHP 8, `"1" == "01"` is true, `null == false` is true. Grep for `[^=!]==[^=]` in review.
- `in_array($x, $arr, true)` and `array_search($x, $arr, true)` — the strict flag is
  not optional; without it `in_array(0, ['a','b'])` was true for years of PHP.
- `match` over `switch`: strict comparison, no fallthrough, exhaustive by default
  (throws `UnhandledMatchError` instead of silently doing nothing).
- `??` for null-defaults, `?->` for nullable chains. `empty()` lies: `"0"` is empty,
  so is `0.0` — use explicit `=== null`, `=== ''`, or `count(...) === 0`.

## PSR conventions

- PSR-4 autoloading: namespace mirrors directory, one class per file, no manual
  `require`/`include` outside bootstrap — Composer's autoloader is the only loader.
- PSR-12 code style, enforced by a tool (php-cs-fixer or PHP_CodeSniffer), never by
  review comments. Style debates end in the config file.
- PSR-3 `LoggerInterface` for logging, PSR-7/15/18 interfaces at HTTP boundaries when
  outside a framework — depend on the interface, not a concrete client.

## Everyday modern syntax

- Constructor property promotion for value-ish classes: declaration, assignment, and
  (with `readonly`) immutability in one place. Back enums where they serialize, and
  validate boundary input through `::tryFrom`, not manual `in_array` checks.
- Arrow functions for one-expression closures; named arguments at call sites with
  many scalar/bool parameters — but prefer fixing the signature over naming five booleans.

## Errors and exceptions

- Throw typed exceptions; never return `false|array` unions to signal failure — that
  is how `strpos` bugs happen. One small exception hierarchy per domain
  (`InvoiceNotFound extends DomainException`), catch at the layer that can act.
- Empty `catch` blocks and `catch (\Throwable $e) {}` are bugs by definition; the `@`
  suppression operator is banned — it also hides the errors you did not anticipate.
- Convert warnings/notices to exceptions in bootstrap via `set_error_handler`; a
  warning that scrolls by in logs is a production incident on a delay.
- `finally` (or `try/finally`) for locks, temp files, transactions — cleanup must not
  depend on the happy path.

## Arrays, references, iteration

- `foreach ($items as &$item)` leaves a live reference after the loop — the classic
  "last element duplicated" bug. If you must use it, `unset($item)` immediately after;
  better, map to a new array and never mutate in place.
- `array_map`/`array_filter`/`array_reduce` when the operation is the point,
  `foreach` when flow control is — do not force pipelines through `array_reduce`
  gymnastics that a 4-line loop states plainly.
- Destructure with `[$a, $b] = $pair` and use spread `...` over `array_merge` in
  loops (quadratic). `array_is_list()` distinguishes lists from maps — PHP arrays
  are both, so name variables and types to say which one is meant.

## Strings, encoding, time

- `mb_*` functions for anything user-visible (`strlen('é')` is 2); UTF-8 everywhere,
  declared in `default_charset`, database DSN, and HTML meta.
- `DateTimeImmutable` always; mutable `DateTime` leaks modification through shared
  references. Pass timezones explicitly, store UTC, convert at the display edge.
  `strtotime` on user input is a parser lottery — use `createFromFormat` and check.

## Security at boundaries

- SQL: PDO/mysqli prepared statements with bound parameters, no string-built queries —
  including `ORDER BY`/`LIMIT`, which need allowlists since they cannot be bound.
- Output: escape at output time, not input time — `htmlspecialchars($s, ENT_QUOTES,
  'UTF-8')` for HTML context; storing pre-escaped data corrupts every non-HTML consumer.
- Passwords: `password_hash()`/`password_verify()`, nothing hand-rolled; secret
  comparison via `hash_equals()` to avoid timing leaks; tokens from `random_bytes()`,
  never `rand`/`mt_rand`/`uniqid`.
- Input: `filter_var` for emails/URLs/ints, enum `tryFrom` for closed sets; validate
  at the edge so the domain layer can trust its types.

## Object and dependency conventions

- Constructor injection over statics, singletons, and `global` — a class that news up
  its own dependencies cannot be tested or swapped. Keep containers at the composition
  root, not sprinkled `Container::get()` calls (service location hides coupling).
- Value objects for domain scalars that have rules: `Money`, `Email`, `UserId` —
  a `float` for currency is a rounding bug with a salary. `readonly` + named
  constructor (`Email::fromString`) validates once, then the type is proof.
- Small interfaces defined by the consumer; `final` on classes not designed for
  extension — inheritance is opt-in API surface, composition is the default.

## Tooling floor

- PHPStan (or Psalm) in CI: new code at max level, legacy rides the baseline file so
  the bar only rises. Treat "cannot type this" as a design smell before a tool problem.
- `composer.json` pins `"php"` in `require` and `config.platform.php` so local and CI
  resolve identical dependency sets; `composer validate` + `composer audit` in CI.
- Rector for version upgrades and mechanical modernization — one rule set per PR,
  reviewed like any other change, never a big-bang "modernize everything" commit.
