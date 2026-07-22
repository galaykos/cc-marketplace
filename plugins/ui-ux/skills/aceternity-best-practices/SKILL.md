---
name: aceternity-best-practices
description: Use when building or reviewing Aceternity UI (ui.aceternity.com) motion-heavy marketing/landing components — placement limits, framer-motion deps, perf budgets, reduced-motion, theming, docs-check before API claims.
---

## What Aceternity is — and where it belongs

Aceternity UI (https://ui.aceternity.com/components) is a copy-paste library of
motion-heavy React + Tailwind components: hero effects, animated backgrounds,
3D cards, spotlights, marquees. It is a MARKETING toolkit — landing pages,
product showcases, campaign pages. Inside an app shell (dashboards, settings,
CRUD screens) the same components read as noise and cost real frames; the
correct amount of Aceternity in an admin panel is usually zero. Pairing is the
norm: shadcn/ReUI for the app, Aceternity for the pitch.

## Latest docs before any assertion

Library shape — what Aceternity is, where it belongs, install discipline, the
component category inventory — is answered locally by
`references/aceternity.md`; read that first, no network needed. Everything
per-component stays live:

Copy-paste libraries have no package version to read — the component page IS
the version. Before asserting a component's name, props, dependencies, or
install command, fetch its page under https://ui.aceternity.com/components.
Component code there changes in place; a snippet remembered from months ago
diverges silently. If the page is unreachable, say so and ask — do not
reconstruct the component from memory.

## Install discipline

- Each component page lists its install path (CLI or manual) and its exact
  dependencies — follow the page, not a remembered pattern. Most components
  need the `motion` package (formerly `framer-motion`) and `cn()`; some need
  extra packages or Tailwind config additions listed on that page.
- Manual installs must take EVERYTHING the page shows: the util, the config
  additions, the sibling sub-components. A half-pasted component compiles and
  then animates wrong.
- The code lands in your repo and is owned from that moment: read it, adapt
  it, review it in PRs. Re-pasting an updated version later overwrites local
  edits — diff first, same as every registry component.

## The motion dependency is an architectural decision

- `motion` is a real bundle cost. If exactly one landing page uses Aceternity,
  the app shell must not pay for it: keep effect components in route-level
  chunks (dynamic import / route code splitting), never in shared layout.
- Standardize on ONE motion library version; two majors of framer-motion/motion
  in one lockfile is a finding, not a coincidence.
- Server components can't hold these — they are client components by nature
  (`"use client"`); pushing the boundary down (effect leaf nodes, static
  parents) keeps the RSC tree mostly server.

## Performance budget per effect

Animated backgrounds and canvas effects are the most expensive pixels on the
page. Gates before shipping:

- Above-the-fold effect: measure LCP with the effect in place — a hero
  animation that delays the hero text lost the trade.
- Below-the-fold effects: lazy-load on approach (intersection observer or
  dynamic import) — a footer sparkle must not load with the hero.
- Continuous animations (marquees, beams, floating cards) must pause when
  off-screen and on `document.hidden`; check the pasted code actually does
  this — many demos don't, because demos are always on screen.
- One hero effect per view. Stacking spotlight + beams + grid background is a
  GPU bill, and visually they cancel each other out anyway.

## Reduced motion is non-negotiable

Marketing pages are exactly where vestibular-triggering motion lives. Every
Aceternity usage ships with a `prefers-reduced-motion` story:

- Best: a static variant (first animation frame or a plain gradient) rendered
  when the media query matches.
- Minimum: animations collapse to fades; nothing translates, scales, or
  parallaxes.
- The pasted component rarely handles this for you — check and add it; its
  absence is a review finding, not a polish item.

## SSR and hydration

Effect components are a hydration-mismatch factory: randomized particle
positions, `Math.random()` in render, `window` reads for dimensions. On
Next.js/SSR:

- Anything randomized or viewport-dependent renders client-only (dynamic
  import with `ssr: false`, or a mounted-state gate) — the server must not
  guess pixel positions the client will reroll.
- Check the pasted code for direct `window`/`document` access outside effects;
  demos run client-side and hide the crash until the first server render.

## Theming: keep effects on the token system

Aceternity snippets frequently ship with hardcoded palettes (dark heroes,
neon accents). On a project with a shadcn theme (see shadcn-theming skill):

- Rewire snippet colors to the project tokens where the effect is meant to
  match the brand; leave literal values only where the effect IS the specific
  artwork — and say so in a comment.
- Dark-only components must be checked in light mode before shipping; many
  demos assume a dark page and vanish on white.

## Anti-patterns

- Asserting component props or dependencies from memory — the docs page is
  the only source of truth for a versionless library.
- Aceternity effects inside app-shell UI (tables, forms, nav) — wrong tool.
- `motion` imported in the shared layout for a single landing-page effect.
- Continuous animation without off-screen/tab-hidden pausing.
- No `prefers-reduced-motion` handling on translating/parallax effects.
- Half-pasted installs missing the util, config additions, or sub-components.
- Stacked hero effects competing on one view.
- Hardcoded demo palette left in place on a token-themed project.
