---
name: laravel-best-practices
description: Use when writing or reviewing Laravel code — Eloquent N+1 prevention and eager loading, form request validation, thin controllers with service/action classes, queued jobs, authorization policies, migrations.
---

## N+1 prevention — eager load, don't lazy load in loops

Accessing a relationship inside a loop fires one query per iteration. Eager load with
`with()` before the loop, or `loadMissing()` when a collection may already have some
relations loaded (skips ones already present). In dev/CI, call
`Model::preventLazyLoading(! app()->isProduction())` in `AppServiceProvider::boot()` so a
missed eager load throws in tests/local dev instead of silently degrading production —
staying off in production so an unexpected access degrades rather than 500s for real users.

```php
// Bad: N+1 — one query per post to fetch its author
foreach (Post::all() as $post) { echo $post->author->name; }
// Good: eager loaded — two queries total
foreach (Post::with('author')->get() as $post) { echo $post->author->name; }
```

## Validation belongs in FormRequest classes

Controllers should not call `$request->validate()` inline or hand-roll rules. Extract a
`FormRequest` per action: it centralizes rules, keeps `authorize()` next to validation, and
is testable independent of the controller.

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

A controller method should orchestrate: validate (FormRequest), authorize, delegate, return
a response. Multi-step business logic (side effects, external calls, cross-model
coordination) belongs in a single-purpose action class, reusable from jobs/commands and
testable without an HTTP request.

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

Register a `Policy` per model and check it in `FormRequest::authorize()` or via
`$this->authorize()` / `Gate::authorize()` in the controller. Blade's `@can` only hides UI —
it doesn't stop a direct request to the route, so relying on it alone leaves the action
unprotected.

```php
// Bad: only guarded in the view; controller has no check, route stays reachable directly
@can('update', $post) <a href="{{ route('posts.edit', $post) }}">Edit</a> @endcan
// Good: guarded where the action executes
class UpdatePostRequest extends FormRequest {
    public function authorize(): bool { return $this->user()->can('update', $this->route('post')); }
}
```

## Queue slow work — small, idempotent payloads

Dispatch anything slow (email, exports, external API calls) to a queued job instead of
blocking the request. Pass IDs, not hydrated models: `SerializesModels` serializes a model
reference and re-fetches it from the database when the job runs, so a full model instance in
the constructor bloats the payload without keeping data any fresher. Jobs run more than once
(retries, timeouts, manual re-dispatch) — write `handle()` so running it twice is safe.

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

Only read `env()` inside `config/*.php` files. Once `php artisan config:cache` runs (every
production deploy should), Laravel loads the cached config array and `env()` calls outside
config files return `null` — the raw `.env` file is no longer consulted. Read values via
`config('services.stripe.key')` everywhere else so cached and uncached environments behave
the same.

```php
// Bad: works locally, returns null once config is cached in production
$key = env('STRIPE_KEY');
// Good: reads the cached config, works in every environment
$key = config('services.stripe.key'); // config/services.php: 'key' => env('STRIPE_KEY')
```

## Migrations — additive-first, honest `down()`, never edit shipped ones

Prefer additive migrations (new column, new table) over destructive ones on tables with
data; drop/rename later once code no longer depends on the old shape. Write a `down()` that
actually reverses `up()` — an empty or wrong `down()` makes rollback silently lose data or
fail. Once a migration ships to any shared environment, don't edit it: add a new migration
instead, since editing history breaks anyone who already ran it.

```php
// Bad: down() doesn't reverse up() — rollback leaves the column behind
public function up(): void { Schema::table('users', fn ($t) => $t->string('phone')->nullable()); }
public function down(): void { /* forgot to drop the column */ }
// Good: down() mirrors up()
public function down(): void { Schema::table('users', fn ($t) => $t->dropColumn('phone')); }
```

## Common mistakes

- Looping over a relationship without eager loading, or eager loading a relation never used.
- Validating in the controller instead of a `FormRequest`, scattering rules across actions.
- Fat controllers reaching into multiple models/services directly instead of delegating.
- Relying on `@can` in Blade as the only authorization check, leaving the route open.
- Passing whole Eloquent models into queued job constructors instead of IDs.
- Writing job `handle()` methods that aren't safe to run twice.
- Calling `env()` outside `config/*.php`, which breaks silently after `config:cache`.
- Editing a migration that already ran in a shared environment instead of adding a new one.
- Leaving `down()` empty or incorrect, making rollback unsafe.

## Verify Against Current Docs

Eloquent eager-loading APIs, the `preventLazyLoading`/strict-mode toggles, queue
configuration, and policy/gate registration have changed across Laravel major versions.
Before relying on memory for version-sensitive APIs, check https://laravel.com/docs against
the actual `laravel/framework` version in the project's `composer.json`.
