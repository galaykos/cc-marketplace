---
name: laravel-best-practices
description: Use when writing or reviewing Laravel code — Eloquent N+1 prevention and eager loading, form request validation, thin controllers with service/action classes, queued jobs, authorization policies, migrations.
---

## Know the version before advising

Version facts come from the manifests, never from assumption:

- `composer.json` `require.laravel/framework` is the advice floor — recommend nothing above it. `composer.lock` says what is ACTUALLY installed (`^11.0` says nothing about whether 11.20's fix is present — the lock does).
- The floor implies a PHP floor: Laravel 10 needs PHP 8.1+, 11 and 12 need 8.2+, 13 needs 8.3+. Cross-check `require.php`; a mixed repo's `package.json` governs the JS side only — never infer framework capabilities from it.

## Per-version leverage (advise at or below the floor)

Recommend the newer idiom only when the floor is at or above the release that shipped it. Verify anything version-sensitive against https://laravel.com/docs before pinning it:

- **Laravel 11** — the slimmed skeleton: `bootstrap/app.php` is the single config surface for routing, middleware, and exceptions, so there is no `Http/Kernel.php` or console kernel and the old middleware files are gone (customize via `->withMiddleware`). Model casts as a `casts()` METHOD, not the `$casts` property, so casts take arguments. Per-second rate limiting (`Limit::perSecond(...)`). Health-check routing (`health: '/up'`). The `once()` helper memoizes a callback for the current request.
- **Laravel 12** — a maintenance release: upstream dependency updates and new React/Vue/Svelte/Livewire starter kits, with deliberately minimal breaking changes (most apps upgrade without code changes). Do not attribute new idioms to 12 by default — if a capability's introducing version is uncertain, describe it without pinning a version.
- **Laravel 13** (current, March 2026; requires PHP 8.3+) — first-party AI SDK, JSON:API resources, attribute-first controllers and jobs (`#[Middleware]`, `#[Authorize]`, `#[Tries]`, `#[Backoff]`, `#[Timeout]`), `Queue::route()` for central queue/connection routing, `Cache::touch()` TTL extension, and vector-similarity query clauses. Like 12, breaking changes are minimal — most apps upgrade without code changes.

## N+1 prevention — eager load, don't lazy load in loops

Accessing a relationship inside a loop fires one query per iteration. Eager load with `with()` before the loop, or `loadMissing()` when a collection may already have some relations loaded (skips ones already present). In dev/CI, call `Model::preventLazyLoading(! app()->isProduction())` in `AppServiceProvider::boot()` so a missed eager load throws in tests/local dev instead of silently degrading production — staying off in production so an unexpected access degrades rather than 500s for real users.

```php
// Bad: N+1 — one query per post to fetch its author
foreach (Post::all() as $post) { echo $post->author->name; }
// Good: eager loaded — two queries total
foreach (Post::with('author')->get() as $post) { echo $post->author->name; }
```

## Validation belongs in FormRequest classes

Controllers should not call `$request->validate()` inline or hand-roll rules. Extract a `FormRequest` per action: it centralizes rules, keeps `authorize()` next to validation, and is testable independent of the controller.

```php
// Bad: validation logic living in the controller
public function store(Request $request) {
    Post::create($request->validate(['title' => 'required|max:255']));
}
// Good: FormRequest owns rules + authorization
public function store(StorePostRequest $request) {
    Post::create($request->validated());
}
class StorePostRequest extends FormRequest {
    public function authorize(): bool { return $this->user()->can('create', Post::class); }
    public function rules(): array { return ['title' => ['required', 'max:255']]; }
}
```

## Thin controllers — push logic into actions/services

A controller method should orchestrate: validate (FormRequest), authorize, delegate, return a response. Multi-step business logic (side effects, external calls, cross-model coordination) belongs in a single-purpose action class, reusable from jobs/commands and testable without an HTTP request.

```php
// Bad: business logic inline in the controller
public function store(StorePostRequest $request) {
    $post = Post::create($request->validated());
    $post->tags()->sync($request->input('tags', []));
    Notification::send($post->author, new PostPublished($post));
    return redirect()->route('posts.show', $post);
}
// Good: controller delegates to an action
public function store(StorePostRequest $request, PublishPost $action) {
    return redirect()->route('posts.show', $action->handle($request->validated()));
}
```

## Authorization — policies and gates, never Blade-only

Register a `Policy` per model and check it in `FormRequest::authorize()` or via `$this->authorize()` / `Gate::authorize()` in the controller. Blade's `@can` only hides UI — it doesn't stop a direct request to the route, so relying on it alone leaves the action unprotected.

```php
// Bad: only guarded in the view; controller has no check, route stays reachable directly
@can('update', $post) <a href="{{ route('posts.edit', $post) }}">Edit</a> @endcan
// Good: guarded where the action executes
class UpdatePostRequest extends FormRequest {
    public function authorize(): bool { return $this->user()->can('update', $this->route('post')); }
}
```

## Mass assignment — guard model input

Every model needs an explicit allowlist. Prefer `$fillable` (allowlist) over `$guarded` (denylist) — a denylist silently opens every column you forget to add. Passing raw input into an unguarded model is the OWASP mass-assignment bug: `Model::create($request->all())` lets an attacker set columns you never intended (`role`, `is_admin`, `user_id`). Feed models validated data from the FormRequest, backed by a real `$fillable`.

```php
// Bad: raw input into an unguarded model — attacker POSTs "is_admin": true
class User extends Model { protected $guarded = []; }
User::create($request->all());
// Good: validated data + explicit allowlist, dangerous columns not fillable
class User extends Model { protected $fillable = ['name', 'email']; }
User::create($request->validated()); // FormRequest already dropped unknown keys
```

Type attributes with the `casts()` method (Laravel 11+) or the `$casts` property so `is_admin` is a real `bool`, not a string that compares wrong. Shape API output through an API Resource (`JsonResource`) rather than returning the model directly — returning `$model` leaks every attribute (password hashes, internal flags) and couples clients to column names.

## Queue slow work — small, idempotent payloads

Dispatch anything slow (email, exports, external API calls) to a queued job instead of blocking the request. Pass IDs, not hydrated models: `SerializesModels` re-fetches a fresh copy on execution, so dispatch-time attributes are discarded — don't rely on stale state. The real bloat/fragility risk is loaded relations (serialized recursively, re-fetched too) and appended/non-Eloquent properties; keep payloads to ids/scalars. Jobs run more than once — write `handle()` so it's safe to run twice.

```php
// Bad: hydrated model in the constructor, non-idempotent charge
class ChargeOrder implements ShouldQueue {
    public function __construct(public Order $order) {}
    public function handle(): void { Payment::charge($this->order); } // charges again on retry
}

// Good: pass the id, guard against duplicate execution
class ChargeOrder implements ShouldQueue {
    public function __construct(public int $orderId) {}
    public function handle(): void {
        $order = Order::findOrFail($this->orderId);
        if ($order->isPaid()) return;
        Payment::charge($order);
    }
}
```

## Config/env discipline — `config()`, not `env()`, outside config files

Only read `env()` inside `config/*.php` files. Once `php artisan config:cache` runs (every production deploy should), Laravel loads the cached config array and `env()` calls outside config files return `null` — the raw `.env` file is no longer consulted. Read values via `config('services.stripe.key')` everywhere else so cached and uncached environments behave the same.

```php
// Bad: works locally, returns null once config is cached in production
$key = env('STRIPE_KEY');
// Good: reads the cached config, works in every environment
$key = config('services.stripe.key'); // config/services.php: 'key' => env('STRIPE_KEY')
```

## Migrations — additive-first, honest `down()`, never edit shipped ones

Prefer additive migrations (new column, new table) over destructive ones on tables with data; drop/rename later once code no longer depends on the old shape. Write a `down()` that actually reverses `up()` — an empty or wrong `down()` makes rollback silently lose data or fail. Once a migration ships to any shared environment, don't edit it: add a new migration instead, since editing history breaks anyone who already ran it.

```php
// Bad: down() doesn't reverse up() — rollback leaves the column behind
public function up(): void { Schema::table('users', fn ($t) => $t->string('phone')->nullable()); }
public function down(): void { /* forgot to drop the column */ }
// Good: down() mirrors up()
public function down(): void { Schema::table('users', fn ($t) => $t->dropColumn('phone')); }
```

## Common mistakes

- Looping over a relationship without eager loading, or eager loading a relation never used.
- Validating in the controller instead of a `FormRequest`, and fat controllers reaching into multiple models/services directly instead of delegating.
- Relying on `@can` in Blade as the only authorization check, leaving the route open.
- Mass assignment via an unguarded model fed `$request->all()`; use a real `$fillable` plus `$request->validated()`.
- Returning a full Eloquent model to the client instead of an API Resource, leaking internal attributes.
- Passing whole Eloquent models into queued job constructors instead of IDs, or writing `handle()` methods that aren't safe to run twice.
- Calling `env()` outside `config/*.php` (breaks after `config:cache`), editing a migration that already ran, or leaving `down()` empty/incorrect.

## Verify Against Current Docs

Eloquent eager-loading APIs, the `preventLazyLoading`/strict-mode toggles, queue configuration, and policy/gate registration have changed across Laravel major versions. Before relying on memory for version-sensitive APIs, check https://laravel.com/docs against the actual `laravel/framework` version in the project's `composer.json`.
