# design-lab

See real components before deciding. Two tools that used to be separate plugins
(design-preview, registry-source) and were always installed together. The shadcn-studio <!-- removed-ok -->
sandbox that also merged here was removed in 0.2.0: it rendered components the project
did not have, so it decided nothing about the project — a greenfield decision now
falls back to the taskmaster shell mockup, and the variant-depth rules it carried
(lanes, states, serves/trades/breaks) live in `real-preview/references/`.

| Command / server | What it does |
|---|---|
| `/design-lab:preview [decision-description]` | Render 2–3 candidate variants with the project's **own** components on its own dev server — Vite (React or Vue/Nuxt) or Laravel Blade/Livewire — on a scratch surface removed at cleanup, behind a strict consent gate. Falls back to static shell mockups when neither stack is detected |
| `registry-source` MCP server | Read component registries from the source, never from memory: live list/search/get across Aceternity, shadcn and Magic UI, 24h-cached, every answer carrying its source URL, fetch date and a stale flag |
| `reui` MCP server | ReUI's own hosted registry, delivered by install and authenticated by your own browser sign-in |

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install design-lab@cc-plugins-marketplace
```

## Which tool, when

| Situation | Tool |
|---|---|
| Runnable Vite+React (or Vue/Nuxt, or Laravel Blade) host with components present | `/design-lab:preview` — the `real-preview` skill |
| Empty/greenfield dir, or a stack with no Vite/Laravel host | the taskmaster `visual-decisions` shell mockup, offered by `/design-lab:preview` as its fallback |
| Installing or reviewing a registry component (shadcn, ReUI, Aceternity, Magic UI) | the MCP servers below, via ui-ux's stack skills |

The renderer is consent-gated, writes only scratch files it can prove are its own,
and verifies cleanup: `scripts/preview-cleanup.sh <project-root>` removes every
`__design-preview__` artefact and exits non-zero if anything remains. Its fixture
harness is under `scripts/__tests__/`.

## Component registries (MCP)

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
| `reui` | **not served locally** — hosted MCP server at `mcp.reui.io` | see below |

**On ReUI.** `reui.io/r/*` answers `Authentication required … Bearer YOUR_LICENSE_KEY`, so
the local server has **no** ReUI entry at all — a credential-free scrape could only be a
half-working one, and a half-working entry teaches the model the registry is broken rather
than that it is paid. ReUI is served by its own hosted MCP server, declared beside this one
in `.mcp.json` (next section). The local server does not hold, request, forge or route a
licence key. That is not a workaround — it is the licence working as written. A paywall on
a convenience API is a fact about paying for tooling; the LICENSE file
(`github.com/keenthemes/reui`, MIT) is the fact about the code, and the two answer
different questions.

## Two servers, one install

`.mcp.json` declares **both** the local index server and ReUI's own hosted one:

| server | transport | auth |
| --- | --- | --- |
| `registry-source` | stdio, local, dependency-free | none |
| `reui` | http → `mcp.reui.io` | browser sign-in, once |

**The second entry exists because a marketplace has to DELIVER a capability, not describe
one.** ReUI's server is the right way to read that registry — live search, real component
APIs, exact install commands — and it was first set up by hand on one machine with
`claude mcp add`, which reaches exactly nobody who installs this marketplace. A plugin
shipping `.mcp.json` is the delivery mechanism; a note in a README saying "you could also
add…" is not.

To authenticate: `/mcp` → **reui** → **Authenticate**. A browser sign-in the user completes
themselves, so **no credential is ever held in this repo, in a plugin, or by an agent** — the
same reason the local server refuses to carry a licence key. Until that is done it reports
`Needs authentication` and the local server still answers for Aceternity, shadcn and Magic
UI, so nothing is blocked on it. Headless environments use a personal token via an
`Authorization` header, added locally and never committed.

## Install

Dependency-free — node built-ins and raw JSON-RPC over stdio, so there is no npm step and
nothing to rot against an SDK version. Installing the plugin is the whole setup; the only
manual step is the one-time ReUI browser sign-in above, and only if you want that registry.

If you previously added `reui` by hand (`claude mcp add --transport http reui
https://mcp.reui.io`), remove it once this plugin is installed — `claude mcp remove reui` —
or the same server is declared twice.

Cache lives at `~/.cache/claude-registry-source/`, 24h TTL, `refresh: true` on any tool to
bypass it.
