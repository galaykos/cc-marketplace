# Aceternity UI digest — library shape and install discipline

> Last verified: 2026-07-22 — https://ui.aceternity.com/components

Read on demand from aceternity-best-practices. Answers library-shape questions
locally. Per-component names, props, dependencies, and install commands are
LIVE-FETCH-ONLY — component code on the site changes in place, so anything
component-specific comes from that component's page, fetched fresh.

## What it is

- Copy-paste library of free React & Next.js components, built on Tailwind CSS
  and Framer Motion; self-described as shadcn-compatible components with
  microinteractions and animations.
- Motion-heavy by design: hero effects, animated backgrounds, 3D cards,
  parallax, marquees. Code is vendored into your repo, not installed as a
  versioned package — the component page is the only version.

## Where it belongs

- Pitch surfaces: landing pages, product showcases, campaign pages.
- Not app shells: dashboards, settings, CRUD/admin screens read the same
  effects as noise and pay real frames for them.
- Pairing is the norm: shadcn/ReUI for the app, Aceternity for the pitch.

## Install paths

- CLI (shadcn registry): `npx shadcn@latest init` once, then either the full
  registry URL — `npx shadcn@latest add https://ui.aceternity.com/registry/<component>.json` —
  or, with an `@aceternity` namespaced registry entry in `components.json`,
  `npx shadcn@latest add @aceternity/<component>`.
- Manual: copy the code block plus EVERYTHING the page lists — the `cn()`
  util, config additions, sibling sub-components. A half-paste compiles and
  then animates wrong.
- Which route a given component supports, and its exact commands, live on that
  component's page — fetch it; never reuse a remembered install block.

## Dependency expectations

- Baseline utilities: `clsx` + `tailwind-merge` behind a `cn()` helper in
  `lib/utils.ts` — the same shape shadcn projects already have.
- Animation engine: the `motion` package (formerly `framer-motion`); most
  animated components require it.
- Some components need extra packages or Tailwind/config additions — listed
  only on their own page; there is no global manifest to consult instead.

## Component category inventory (index as fetched today)

Backgrounds & Effects; Card Components; Scroll & Parallax; Text Components;
Buttons; Loaders; Navigation; Inputs & Forms; Overlays & Popovers; Carousels
& Sliders; Layout & Grid; Data & Visualization; Cursor & Pointer; 3D
Components; Sections & Blocks (hero, feature, pricing, testimonial blocks).
100+ components across these categories; individual names churn — the live
index is authoritative for what exists right now.

## Not in this digest — live-fetch-only

Per-component props, code, dependencies, and install commands. Component code
changes in place with no version marker; fetch the component's page under
https://ui.aceternity.com/components before asserting any of them.
