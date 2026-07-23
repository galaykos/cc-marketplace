# build-vs-buy

Gate zero before writing a generic capability: check whether a library,
service, or stdlib feature already solves it — candidate health table,
take/wrap/write verdict, and a never-hand-roll list (crypto, auth, timezones,
parsers). A `UserPromptSubmit` hook nudges the check when a prompt proposes
building a commonly-solved capability.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install build-vs-buy@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/build-vs-buy:check [capability]` | Run a build-vs-buy check on a capability before implementing it — existing-solution search, health table, take/wrap/write verdict |

## How it works

- **Skill** (`build-vs-buy`) — the protocol: name the capability generically,
  check the stdlib/framework first, then search the stack's registry, build a
  health/license/coverage table, and land on take, wrap, or write.
- **Hook** (`UserPromptSubmit`) — when a prompt pairs a build verb ("build",
  "implement", "roll my own", "from scratch") with a commonly-solved
  capability (auth, parsers, timezones, queues, caching, payments, ...), it
  prints a one-line reminder to weigh take/wrap/write first. Fail-open: it
  never blocks the prompt and stays silent on slash commands.

A significant verdict is stated inline with its candidate table as the
"options considered" record — no file is written unless the project already
keeps decision docs.

## Example

```bash
/build-vs-buy:check rate limiting for the public API
/build-vs-buy:check     # asks which capability is about to be implemented
```

## Pairs well with

- **approaches** — deliberate the shortlisted options once "take library X" is on the table
- **packages** — audit the dependency you just adopted for vulnerabilities and staleness
- **stack-scan** — inventory what's actually installed before searching the registry
