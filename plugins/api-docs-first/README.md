# api-docs-first

Verify current API docs before writing integration code; ask for a URL or file
when docs are missing. For consuming third-party APIs — designing your own REST
APIs is the api-design plugin's domain.

The `docs-upkeep` plugin was merged into this one: its docs-upkeep skill (keep
your own docs true after a change) now ships here and its drift scan lives on
as `/api-docs-first:drift`. Nothing was dropped in the merge.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install api-docs-first@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/api-docs-first:check [library-sdk-or-api]` | Check that current API docs back the integration code you are about to write or review: reports the exact installed version from the lockfile, the docs source located, and the symbols/endpoints verified — or asks you for a docs URL or file and refuses to write integration code from memory until one is provided |
| `/api-docs-first:drift [path-range-or-repo]` | Scan the current change (or repo) for documentation drift — README claims, changelog gaps, stale examples, dead links — and list exact fixes |

## How it works

- The **api-docs-first skill** fires before writing any code that calls an
  external API, SDK, or third-party library: identify the exact installed
  version from the lockfile, verify against current official docs, and stop to
  ask for a docs URL or file when none are accessible.
- A **UserPromptSubmit hook** watches prompts for integration keywords (sdk,
  endpoint, integrate, webhook, oauth, graphql) and prints a one-line reminder
  to verify docs first. It never blocks the prompt and skips slash commands.

## Example

```bash
/api-docs-first:check stripe
/api-docs-first:check twilio-sdk
```

## Pairs well with

- **api-design** — designing your own REST APIs, the flip side of consuming others'
- **security** (api-auth skill) — reviewing the auth model of the API you are integrating
- **stack-scan** — inventories the installed versions this plugin verifies docs against
