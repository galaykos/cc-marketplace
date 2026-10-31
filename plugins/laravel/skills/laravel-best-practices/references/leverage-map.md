# Laravel per-major leverage — expanded map

> Last verified: 2026-08-12 — https://laravel.com/docs/13.x/releases
> Floor rule (from the SKILL body): recommend an idiom only when composer.json's
> `laravel/framework` floor is at or above the release that shipped it.
> Laravel 11 support status and its three upgrade inversions: checked 2026-10-31 against
> https://laravel.com/docs/11.x/upgrade and https://endoflife.date/laravel.

## Laravel 11 (2024-03) — the slim-skeleton boundary

- **Unsupported**: bug fixes ended 2025-09-03, security fixes 2026-03-12 (endoflife.date). An 11
  lockfile is an upgrade finding; flag it, then advise against what it has installed.
- **`->change()` drops every modifier you do not restate** (upgrade guide, "Likelihood Of Impact:
  High"). On 10, `$table->integer('votes')->nullable()->change()` kept the column's `unsigned`,
  `default` and `comment`; on 11+ it removes them. Repeat each modifier in the change:
  `->unsigned()->default(1)->comment('…')->nullable()->change()`. Indexes are untouched; add or drop
  them with index modifiers (`->unique(false)->change()`). The 13.x migrations docs keep the rule.
- **Carbon 3** (11 accepts Carbon 2 or 3): `diffIn*` methods return floats and can be negative to
  show direction. Code that compares `diffInDays()` to an int or treats it as a positive count
  changes meaning once `composer.lock` resolves Carbon 3; read Carbon's migration guide before
  fixing it.
- **`mariadb` driver**: 11 adds a dedicated driver. It behaves like the MySQL driver except that `uuid()`
  creates a native UUID column, not `char(36)`. Switching an existing app's connection to
  `mariadb` changes what old `uuid()` migrations build; the guide says to rewrite them as
  `char('uuid', 36)`.

- `bootstrap/app.php` is the single configuration surface: routing, middleware
  (`->withMiddleware`), and exception handling live there. `Http/Kernel.php`, the
  console kernel, and the middleware file stubs DO NOT EXIST — advice that says
  "add it to app/Http/Kernel.php" is pre-11 and lands nowhere.
- Casts are a `casts()` METHOD (can take arguments); the `$casts` property still
  works but new code uses the method.
- Also 11: `Limit::perSecond()`, health route (`health: '/up'`), `once()` memoization.
- Upgrade tell: an app upgraded FROM 10 may keep the old kernel files legitimately —
  the slim skeleton is the default for NEW 11+ apps, not a forced migration. Check
  which shape THIS app has before advising either way.

## Laravel 12 (2025) — a maintenance major, and that is the content

- Dependency updates plus new React/Vue/Svelte/Livewire starter kits; deliberately
  minimal breaking changes. Most apps upgrade with no code changes.
- The trap is ATTRIBUTION: when memory is unsure which version shipped a feature, 12
  is the wrong guess almost always. Describe the capability without pinning, or
  verify. (This paragraph exists because a maintenance major is exactly where a
  model hallucinates features to fill the gap.)

## Laravel 13 (2026-03-17) — PHP 8.3+ floor, zero breaking changes claimed

- **Attribute-first framework surface**: PHP attributes as an optional alternative in
  15+ locations — controllers and jobs carry `#[Middleware]`, `#[Authorize]`,
  `#[Tries]`, `#[Backoff]`, `#[Timeout]` instead of constructor/property config.
  Optional: do not rewrite a class-property codebase to attributes in passing; match
  the file's existing style (one app, one idiom).
- **First-party AI SDK**: unified text generation, tool-calling agents, embeddings,
  and vector-store integration in the framework. Before hand-wiring an HTTP client to
  a model provider in a 13 app, check whether the SDK covers it (and defer model
  facts to the built-in claude-api skill).
- **First-party JSON:API resources**: spec-compliant serialization, relationship
  inclusion, sparse fieldsets out of the box — on a 13 floor, prefer these over
  hand-rolled JSON:API layers; on lower floors do not imitate their shape by hand.
- **Queue routing**: `Queue::route()` centralizes queue/connection routing that
  previously lived per-job.
- **Smaller leverage**: `Cache::touch()` extends TTL without re-fetching; passkey
  authentication first-party; Reverb gains a database driver (real-time without
  Redis); starter kits reintroduce team-based multi-tenancy.
- Upgrade posture: like 12, most apps upgrade without code changes — flag the PHP
  8.3 floor first; that is the actual gate.

## How to use this file in a review

Resolve the installed major from composer.lock (the SKILL's Know-the-version rule),
then read ONLY that major's section plus every section BELOW it — features above the
floor are findings ("available after upgrade"), never recommendations.
