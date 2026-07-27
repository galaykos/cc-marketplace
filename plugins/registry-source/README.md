# registry-source

An MCP server that reads component registries **from the source**, so a build never
picks a component — or estimates what a registry contains — from recall.

## Why it exists

Two skills in this marketplace already forbid working from memory, in plain words:

- `ui-ux/skills/reui-best-practices` — *"never write ReUI API details from memory"*
- `ui-ux/skills/aceternity-best-practices` — *"do not reconstruct the component from memory"*

A run breached both anyway, three times in one session:

| claim made from recall | actual |
| --- | --- |
| "a ~60-component registry" | **270** components |
| "the library is licence-gated, unavailable" | install API is paid; **the code is MIT on GitHub** |
| "the library is free and open-source" (after reading a marketing page) | the **endpoint** does require a key |

None of that was disobedience. Recall does not feel like breaking a rule — it feels like
knowing something, and the moment a check would have helped is the moment it feels least
necessary. Prose cannot fire there. A tool in the tool list can, because it makes reaching
for the source cheaper than remembering.

## Why a cache and not a scraped copy

The obvious alternative — scrape the registries once into a tidy file for the model — puts
the same bug one layer out, and this repo can prove it twice over: the hand-written
inventory in `ui-ux/skills/aceternity-best-practices/references/aceternity.md` was five days
old and said "100+" against an actual 270, and the gate copied into a built project was
already older than the plugin that shipped it.

So every answer carries `source`, `fetched_at`, `from` (`network` | `cache`) and `stale`
beside the data. Same bytes on disk as a scraped copy; opposite epistemics. The cache is a
speed and offline concession, never an authority — when the network is gone it says how old
what it is serving is, and when there is no cache either it says *unreachable* rather than
letting a plausible reconstruction through.

## Tools

| tool | answers |
| --- | --- |
| `registry_list` | everything in a registry (or all of them): name, kind, deps, heaviness, count |
| `registry_search` | which component does X — matched on name, kind and dependency |
| `registry_get` | one component's real entry: exact deps, file list, source, install command |

`heavy` flags anything pulling a 3D/particle runtime (`three`, `@react-three/*`,
`three-globe`, `cobe`, `@tsparticles/*`, `simplex-noise`). A registry index is the only place
a build can learn what a block **costs** before installing it, which is what craft-layer's
ambition floors and its "house motion must not satisfy a reach floor" clause both turn on.

## Registries

| registry | source | note |
| --- | --- | --- |
| `aceternity` | `ui.aceternity.com/registry.json` | motion-heavy marketing blocks; several are `heavy` |
| `shadcn` | `ui.shadcn.com/r/index.json` | the base primitives most registries build on |
| `magicui` | `magicui.design/r/registry.json` | animated marketing components |
| `reui` | `github.com/keenthemes/reui` (MIT) | index only — see below |

**On ReUI.** `reui.io/r/*` answers `Authentication required … Bearer YOUR_LICENSE_KEY`. This
server does not hold, request, forge or route a licence key, and points at the project's own
MIT repository instead. That is not a workaround — it is the licence working as written. A
paywall on a convenience API is a fact about paying for tooling; the LICENSE file is the fact
about the code, and the two answer different questions.

## Install

Dependency-free — node built-ins and raw JSON-RPC over stdio, so there is no npm step and
nothing to rot against an SDK version. The plugin ships `.mcp.json`; installing the plugin
is the whole setup.

Cache lives at `~/.cache/claude-registry-source/`, 24h TTL, `refresh: true` on any tool to
bypass it.
