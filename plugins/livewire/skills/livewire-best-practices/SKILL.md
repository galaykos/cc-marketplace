---
name: livewire-best-practices
description: Use when writing or reviewing Livewire 3 or 4 code — component granularity, wire:model live/blur/debounce modifiers, computed properties, locked properties, pagination, Alpine interop.
---

## `wire:model` is deferred by default — opt into `.live` deliberately

Livewire 3 inverted Livewire 2's default (and v4 keeps it): `wire:model` batches input into the
next network request (form submit, button click) instead of firing one on every keystroke. Add
`wire:model.live` only when you actually need server state on every keystroke (live search,
character counters). Prefer `.live.debounce.500ms` over bare `.live` for anything typed — every
live update is a full roundtrip plus a re-render. Use `.blur` when the update should happen on
field exit instead.

```blade
{{-- Bad (Livewire 2 habit): every keystroke round-trips to the server --}}
<input wire:model.live="query">

{{-- Good: deferred (default) --}} <input wire:model="query">
{{-- Good: opted into live, debounced --}} <input wire:model.live.debounce.500ms="query">
{{-- Good: sync on blur, not per keystroke --}} <input wire:model.blur="email">
```

## `#[Computed]` for derived data

Use `#[Computed]` on a method to derive values from component state instead of recomputing the
same query or transformation inline in Blade. It's cached per request (accessed as
`$this->total`) — calling it repeatedly, even in a loop, does not re-run the underlying logic,
unlike a plain method.

```php
// Bad: a plain method re-runs its query every time it's touched in the template
public function getTotal() { return $this->items->sum('price'); }

// Good: computed, cached for the request — safe to reference in a loop
#[Computed]
public function total() { return $this->items->sum('price'); }
```

```blade
{{-- Bad: plain method call per row re-executes the query each time --}}
@foreach ($rows as $row) {{ $this->getTotal() }} @endforeach

{{-- Good: computed property, cached, reused across the render --}}
<p>Total: {{ $this->total }}</p>
```

## `#[Locked]` for values the client must not tamper with

Public properties are client-mutable state — Livewire serializes them to the page and trusts
what comes back on the next request unless told otherwise. Any property representing an ID,
price, or ownership check that drives an authorization decision needs `#[Locked]` so a tampered
payload throws instead of silently succeeding. It's not a substitute for authorization checks —
it only stops the property from being *changed*; still verify the current user may act on that id.

```php
// Bad: nothing stops a crafted request from swapping the id to load another user's record
public int $invoiceId;

// Good: Livewire rejects any client-side mutation of this property
#[Locked]
public int $invoiceId;
```

## Component granularity + `wire:key` in loops

Keep components small and single-purpose — a component re-renders (and diffs) as a unit, so a
monolithic component re-renders far more DOM than the interaction touched. Split by concern (a
row, a filter panel, a modal) rather than one component per page.

Every element rendered in a loop needs an explicit `wire:key` — Livewire's DOM diffing relies on
it to track identity across re-renders. Without it, Livewire falls back to positional diffing,
which can attach the wrong state (an open dropdown, a focused input) to the wrong row after an
add/remove/reorder.

```blade
{{-- Bad: no key — diffing falls back to position, breaking identity on reorder --}}
@foreach ($items as $item) <livewire:item-row :item="$item" /> @endforeach

{{-- Good: stable key tied to the actual record --}}
@foreach ($items as $item) <livewire:item-row :item="$item" :key="$item->id" /> @endforeach
```

## Pagination via `WithPagination`

Use the `WithPagination` trait rather than hand-rolling offset math — it integrates with
Livewire's query string binding and re-render cycle correctly.

```php
use Livewire\WithPagination;

class ProductList extends Component
{
    use WithPagination;

    public function render()
    {
        return view('livewire.product-list', ['products' => Product::paginate(10)]);
    }
}
```

## Component communication: events vs props

Use `$dispatch()` / `#[On]` for sibling-to-sibling or loosely-coupled communication — the
dispatcher doesn't need to know who's listening. Use props (`<livewire:child :prop="$value" />`)
for direct parent→child data flow, where the relationship is already explicit in the template.

```php
// Emitting component (Livewire 3 — not emit(), which is v2)
$this->dispatch('cart-updated', count: $this->cartCount);

// Listening component
#[On('cart-updated')]
public function refreshBadge($count) { $this->badgeCount = $count; }
```

## Alpine for pure client-side state, `$wire` to bridge

Use Alpine for UI state that never needs to touch the server — dropdown open/closed, tab
selection, a toggle. Round-tripping to Livewire for state the server never needs wastes a
request. When Alpine needs to read or call into server state, use the `$wire` bridge rather than
duplicating the value in both an Alpine `x-data` property and a Livewire public property — two
sources of truth drift out of sync.

```blade
{{-- Good: dropdown state is pure UI, stays in Alpine --}}
<div x-data="{ open: false }">
    <button @click="open = !open">Menu</button>
    <div x-show="open">...</div>
</div>

{{-- Good: Alpine calls server state via $wire instead of a duplicate property --}}
<button @click="$wire.addToCart(productId)" x-text="$wire.cartCount"></button>
```

## Common mistakes

- Adding `wire:model.live` everywhere out of Livewire 2 habit, turning every keystroke into a
  network request.
- Using `emit()`/`emitTo()` (Livewire 2 API) instead of `$dispatch()`/`#[On]` (Livewire 3+).
- Calling a plain method instead of `#[Computed]` for values reused across a template.
- Leaving IDs or ownership-relevant properties unlocked and mutable from the client.
- Missing `wire:key` in `@foreach` loops rendering components or `wire:model`-bound rows.
- One giant component handling a whole page instead of composed child components.
- Duplicating the same state in both an Alpine `x-data` field and a Livewire public property.
- Hand-rolling pagination instead of using `WithPagination`.

## Verify Against Current Docs

Livewire's defaults and APIs changed materially across majors: v2 → v3 flipped `wire:model`'s
default and renamed `emit()` to `$dispatch()`; v4 (current since January 2026) keeps both but
adds single-file components, islands, and `Route::livewire()` routing. Check the current docs:
https://livewire.laravel.com
