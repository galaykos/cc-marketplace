# design-patterns

Design pattern selection across the full GoF catalog: which pattern fits where,
when NOT to use one, and look-alike disambiguation. The pattern-selection skill
maps a named problem to the right creational/structural/behavioral pattern —
simplest-thing-first, refactor-to-pattern only when the simple thing breaks.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install design-patterns@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/design-patterns:suggest [problem-description]` | Suggest (or reject) a design pattern for a described problem |

## Example

```bash
/design-patterns:suggest we have 6 payment providers behind a growing if/else chain
/design-patterns:suggest cache invalidation needs to notify three unrelated modules
```

The command restates the problem without naming a pattern, proposes the simplest
non-pattern solution, and runs the skill's three-check gate. A pattern is
recommended only if the gate passes and it clearly beats the simple solution —
with its trade-offs named. Otherwise it says so explicitly.

## Pairs well with

- **code-architecture** — SOLID and YAGNI audits on the code a pattern would reshape
- **approaches** — compare structurally different approaches before committing to one
- **code-review** — catch pattern misuse and over-engineering in the resulting diff
