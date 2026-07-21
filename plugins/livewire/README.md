# livewire

Livewire 3/4 best practices: deferred `wire:model` and `.live`/`.blur`/`.debounce`
modifiers, `#[Computed]` and `#[Locked]` properties, component granularity and
`wire:key` in loops, `WithPagination`, events vs props, and Alpine interop via
`$wire`.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install livewire@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/livewire:review [files-or-diff]` | Review Livewire components and Blade views against the skill, pinned to the installed `livewire/livewire` version from composer.lock |

## Example

```bash
/livewire:review app/Livewire/OrderSearch.php
/livewire:review         # reviews the current diff
```

Advice pins to the installed `livewire/livewire` version, so v3-specific
guidance (deferred `wire:model`, attribute-based `#[Computed]`) matches your
release.

## Pairs well with

- **laravel** — the framework backing every Livewire component
- **php** — the underlying PHP layer these components run on
