# Framework bindings — tool → framework matrix

Which concrete tool implements each tier depends on the stack. The tier DECISION is
framework-independent; the binding below picks the idiomatic package for that stack so
you do not, e.g., hand-roll Framer Motion in Vue when `motion-v` exists.

Library idioms stay in the owning skills — this is a routing table, not an API guide:
`plugins/ui-ux/skills/motion-best-practices/SKILL.md` and
`plugins/threejs/skills/threejs-best-practices/SKILL.md`.

## The matrix

| Stack | Tier 1 (UI state / layout) | Tier 2 (timeline / SVG) | Tier 3 (3D / WebGL) | Tier 4 (sprites) |
| --- | --- | --- | --- | --- |
| **React** | `motion` → `motion/react` (ex-Framer Motion) | `animejs` v4 | `@react-three/fiber` + `drei` over `three` | CSS `steps()` / rAF component |
| **Next** | `motion/react` (RSC-safe: animate in client components) | `animejs` v4 | `@react-three/fiber`, dynamically imported (`ssr: false`) | CSS `steps()` / rAF client component |
| **Vue** | `motion-v` (official) or `@vueuse/motion` | `animejs` v4 | `@tresjs/core` (R3F-equivalent) over `three` | CSS `steps()` / rAF composable |
| **Nuxt** | `@vueuse/motion` (Nuxt module) or `motion-v` | `animejs` v4 | `@tresjs/nuxt` | CSS `steps()` / rAF composable |
| **Laravel + Inertia (React)** | `motion/react` in the Inertia React pages | `animejs` v4 | `@react-three/fiber` in a client-only island | CSS `steps()` / rAF component |
| **Laravel + Inertia (Vue)** | `motion-v` / `@vueuse/motion` | `animejs` v4 | `@tresjs/core` | CSS `steps()` / rAF composable |
| **Laravel + Livewire / Blade** | Alpine.js `x-transition` + CSS transitions | `animejs` v4 (imported in the entry bundle) | `three` mounted in an Alpine component, lazy-loaded | CSS `steps()` / rAF in an Alpine component |

## Binding rules

- **Framer Motion is React-family only.** In Vue / Nuxt use `motion-v` or
  `@vueuse/motion` for tier 1 — do not pull the React package into a Vue app.
- **anime.js, Three.js, and sprites are framework-neutral.** They bind to any stack;
  the only difference is the mount point (a component, a composable, or an Alpine
  `x-init`). The tier-1 choice is the one that actually forks per framework.
- **Laravel forks on the front-end driver, not on "Laravel".** Inertia-React → the React
  bindings; Inertia-Vue → the Vue bindings; Livewire/Blade → Alpine + CSS for tier 1 and
  the neutral libraries for the rest.
- **SSR frameworks lazy-import tier 3.** Next (`dynamic(..., { ssr: false })`), Nuxt
  (`<ClientOnly>` / `.client` component), and Inertia islands must keep WebGL off the
  server render — it has no DOM there and it bloats the hydration payload. This is the
  same lazy-load the bundle budget already requires; see `webgl-3d.md`.

## Fallbacks are per-binding too

The two mandatory fallbacks (reduced-motion, reduced-bundle) apply after the binding is
chosen, using that stack's idiom: `useReducedMotion()` in React, `useReducedMotion` from
`@vueuse/motion` in Vue, `matchMedia` in Alpine, and `gsap.matchMedia()`-style gates
where the owning skill documents them. Verify the current package names against each
library's docs before pinning a version-sensitive literal.
