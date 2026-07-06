# php

PHP best practices for plain PHP: strict types and `===` discipline, PSR-4/PSR-12
conventions, exceptions, `DateTimeImmutable`, boundary security (prepared
statements, output escaping), value objects, static analysis — with a
version-aware 8.1–8.5 leverage map pinned to the composer.json floor.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install php@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/php:review [files-or-diff]` | Review PHP code against the skill, pinned to the composer.json PHP floor (`require.php` / `config.platform.php`) so nothing above the floor is suggested |

## Example

```bash
/php:review src/Domain/Order.php
/php:review         # reviews the current diff
```

Advice is version-aware: features are recommended at or below the floor only —
enums and readonly properties on 8.1+, `readonly` classes and DNF types on 8.2+,
`json_validate()` on 8.3+ — resolved from composer.json, never assumed.

## Pairs well with

- **laravel** — framework rules for Laravel apps built on this PHP layer
- **livewire** — component-side review for Livewire 3 on the same PHP base
- **packages** — audits the composer dependencies this advice pins against
