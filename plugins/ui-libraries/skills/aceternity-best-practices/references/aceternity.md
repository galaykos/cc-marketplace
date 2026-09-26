# Aceternity UI digest — library shape and registry specifics

> Last verified: 2026-09-26 — https://ui.aceternity.com/components

Read on demand from aceternity-best-practices. Answers library-shape questions
locally. Per-component names, props, dependencies, and install commands are
LIVE-FETCH-ONLY — component code on the site changes in place, so anything
component-specific comes from that component's page, fetched fresh.

Generic shadcn registry mechanics — namespaces in `components.json`, the CLI's
built-in directory and its health field, `view`/`add --dry-run`/`--diff` before
`--overwrite` — are stated once in `ui-ux:shadcn-best-practices`,
`references/registries.md`. Only what is specific to Aceternity is below.

## What it is

- Copy-paste library of free React & Next.js components, built on Tailwind CSS
  and Motion; self-described as shadcn-compatible components with
  microinteractions and animations. Paid Pro blocks and templates sit on top.
- Motion-heavy by design: hero effects, animated backgrounds, 3D cards,
  parallax, marquees. Code is vendored into your repo, not installed as a
  versioned package — the component page is the only version.

## Where it belongs

- Pitch surfaces: landing pages, product showcases, campaign pages.
- Not app shells: dashboards, settings, CRUD/admin screens read the same
  effects as noise and pay real frames for them.
- Pairing is the norm: shadcn/ReUI for the app, Aceternity for the pitch.

## Registry specifics

- Namespace `@aceternity` → `https://ui.aceternity.com/registry/{name}.json`.
  There is NO `{style}` segment: one build serves every shadcn style and base,
  so an item does not adapt to a Base UI or Radix project — read what it imports.
- It is in the shadcn CLI's built-in directory, so `npx shadcn@latest add
  @aceternity/<component>` resolves without a `registries` entry; its own docs
  still show the entry, and the full-URL form
  (`npx shadcn@latest add https://ui.aceternity.com/registry/<component>.json`)
  works either way.
- Manual install: copy the code block plus EVERYTHING the page lists — the
  `cn()` util, config additions, sibling sub-components. A half-paste compiles
  and then animates wrong.
- Which route a given component supports, and its exact commands, live on that
  component's page — fetch it; never reuse a remembered install block.

## Dependency expectations

- Animation engine: the `motion` package. The site's prose still says "Framer
  Motion", but the registry items declare `motion`, not `framer-motion` — install
  the package the item declares.
- Icons: `@tabler/icons-react` is the common icon dependency; a project on
  another icon set gains a second one with each such item.
- Some items need extra packages (`three` and `@react-three/fiber` for the 3D
  ones) or Tailwind/config additions — listed only on their own page and in the
  registry JSON.

## Component categories — shape only, NO COUNT

Backgrounds & Effects; Card Components; Scroll & Parallax; Text Components;
Buttons; Loaders; Navigation; Inputs & Forms; Overlays & Popovers; Carousels
& Sliders; Layout & Grid; Data & Visualization; Cursor & Pointer; 3D; Sections
and Blocks (hero, feature, card sections); Labs.

**No number lives in this file, deliberately.** A count in a static file goes wrong
as soon as the registry changes, and a `Last verified` date cannot tell a wrong figure
from a right one; the registry index is the only thing that knows.

Get it live instead. `https://ui.aceternity.com/registry.json` is the current
inventory, raw: per-item dependencies, and the 3D/particle runtimes that price a
block's bundle cost before it is installed. Aceternity ships no MCP server of its
own — fetch the JSON, do not recite a count.

## Not in this digest — live-fetch-only

Per-component props, code, dependencies, and install commands. Component code
changes in place with no version marker; fetch the component's page under
https://ui.aceternity.com/components before asserting any of them.

Standing: **recorded** — no script checks an install against these facts; the
reviewer applying `aceternity-best-practices` is the only reader (agent-graded).
