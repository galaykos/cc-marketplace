# Framework bindings — tool → framework matrix

> Last verified: 2026-09-26 — https://livewire.laravel.com/docs/4.x/wire-ignore — npm:motion@13
>
> The per-framework package names below, checked on npm the same day. Bindings churn
> faster than anything else in this plugin: a framework's blessed motion package
> changes without the technique changing at all. Check the package still exists and
> is maintained before quoting a row.

Which concrete tool implements each tier depends on the stack. The tier DECISION is
framework-independent; the binding below picks the idiomatic package for that stack so
you do not, e.g., hand-roll Framer Motion in Vue when `motion-v` exists.

Library idioms stay in the owning skills — this is a routing table, not an API guide:
`plugins/ui-ux/skills/motion-best-practices/SKILL.md` and
`plugins/craft-layer/skills/threejs-best-practices/SKILL.md`.

## The matrix

| Stack | Tier 1 (UI state / layout) | Tier 2 (Timeline / SVG) | Tier 3 (3D / WebGL) | Tier 4 (Sprites) |
| --- | --- | --- | --- | --- |
| **React** | `motion` → `motion/react` (ex-Framer Motion) | `animejs` v4 | `@react-three/fiber` + `drei` over `three` | CSS `steps()` / rAF component |
| **Next** | `motion/react` (RSC-safe: animate in client components) | `animejs` v4 | `@react-three/fiber`, dynamically imported (`ssr: false`) | CSS `steps()` / rAF client component |
| **Vue** | `motion-v` (official) or `@vueuse/motion` | `animejs` v4 | `@tresjs/core` (R3F-equivalent) over `three` | CSS `steps()` / rAF composable |
| **Nuxt** | `motion-v` (Nuxt module `motion-v/nuxt`); `@vueuse/motion` last published March 2025 | `animejs` v4 | `@tresjs/nuxt` | CSS `steps()` / rAF composable |
| **Laravel + Inertia (React)** | `motion/react` in the Inertia React pages | `animejs` v4 | `@react-three/fiber` in a client-only island | CSS `steps()` / rAF component |
| **Laravel + Inertia (Vue)** | `motion-v` / `@vueuse/motion` | `animejs` v4 | `@tresjs/core` | CSS `steps()` / rAF composable |
| **Laravel + Livewire / Blade** | Alpine.js `x-transition` + CSS transitions (Alpine ships inside Livewire 3+) | `animejs` v4, mounted inside a `wire:ignore` element | `three` in an Alpine component inside `wire:ignore`, lazy-loaded | CSS `steps()` / rAF in an Alpine component |

## Binding rules

- **Framer Motion is React-family only.** In Vue / Nuxt use `motion-v` or
  `@vueuse/motion` for tier 1 — do not pull the React package into a Vue app.
- **anime.js, Three.js, and sprites are framework-neutral.** They bind to any stack;
  the only difference is the mount point (a component, a composable, or an Alpine
  `x-init`). The tier-1 choice is the one that actually forks per framework.
- **Laravel forks on the front-end driver, not on "Laravel".** Inertia-React → the React
  bindings; Inertia-Vue → the Vue bindings; Livewire/Blade → Alpine + CSS for tier 1 and
  the neutral libraries for the rest.
- **Livewire owns its DOM, so fence off what an engine owns.** Wrap every element a
  third-party engine writes to — a canvas, a split heading, a Lottie or Rive mount, a
  carousel track — in `wire:ignore`; otherwise Livewire's morph overwrites it on the next
  update. Livewire 3+ bundles Alpine: never `npm i alpinejs` or call `Alpine.start()`
  beside it (register plugins through Livewire's ESM build). Under `wire:navigate`, init
  in a `livewire:navigated` listener (it also fires on first load) instead of
  `DOMContentLoaded`, tear down on `livewire:navigating`, and keep a canvas or player
  alive across pages with `@persist`. This row covers mounting motion only — Livewire,
  Flux and Volt themselves are not covered here; use the vendor's version-matched
  guidelines. Standing: recorded.
- **SSR frameworks lazy-import tier 3.** Next (`dynamic(..., { ssr: false })`), Nuxt
  (`<ClientOnly>` / `.client` component), and Inertia islands must keep WebGL off the
  server render — it has no DOM there and it bloats the hydration payload. This is the
  same lazy-load the bundle budget already requires; see `webgl-3d.md`.

## Tier-1 alternatives you will meet

| Library | What it is | Reduced motion | Use when |
| --- | --- | --- | --- |
| **react-spring** (`@react-spring/web` v10) | Spring-physics hooks for React | NOT automatic: read `useReducedMotion()` and set `Globals.assign({ skipAnimation: true })` | The project already uses it. Never beside Motion on one element's transform; do not add it to a Motion project |
| **AutoAnimate** (`@formkit/auto-animate`, 0.x) | One line (`useAutoAnimate()` ref, `v-auto-animate`) animates a parent's children being added, removed or moved | Disables itself when the user prefers reduced motion | List add / remove / reorder, including high-frequency live lists where a view transition would restart (`page-transitions`) |

Standing: recorded.

## Fallbacks are per-binding too

The two mandatory fallbacks (reduced-motion, reduced-bundle) apply after the binding is
chosen, using that stack's idiom: `useReducedMotion()` in React, `useReducedMotion` from
`@vueuse/motion` in Vue, `matchMedia` in Alpine, and `gsap.matchMedia()`-style gates
where the owning skill documents them. Verify the current package names against each
library's docs before pinning a version-sensitive literal.
