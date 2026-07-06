# laravel

Laravel best practices: Eloquent N+1 prevention and eager loading, form request
validation, thin controllers with service/action classes, queued jobs,
authorization policies, and additive-first migrations.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install laravel@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/laravel:review [files-or-diff]` | Review controllers, models, jobs, and migrations against the skill, pinned to the installed `laravel/framework` version from composer.lock |

## Example

```bash
/laravel:review app/Http/Controllers/OrderController.php
/laravel:review         # reviews the current diff
```

Advice pins to the installed `laravel/framework` version, so APIs are only
suggested when your release actually ships them.

## Pairs well with

- **php** — the underlying PHP layer these framework rules sit on
- **livewire** — full-stack component review for Livewire 3 in the same app
- **inertia** — backend side of Inertia pages that laravel:review pairs with
