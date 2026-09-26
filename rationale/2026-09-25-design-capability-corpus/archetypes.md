# Archetype reference sites — 2026-09-25 corpus

`plugins/craft-layer/skills/creative-direction/references/archetype-recipes.md` maps the 10
hero/page archetypes to the skills that build them and names no sites, on purpose — a roster in
a shipped file ages into the house look. This file is the roster it points at.

- **Source:** the four visual review reports in `taskmaster-docs/design-corpus-2026-09-25/review/`
  — `visual-infra.md`, `visual-business.md`, `visual-verticals.md`, `visual-craft.md` — each
  written by a different reviewer over a different slice of the 1,530-site corpus, using its own
  label names. This file maps those labels onto the recipe file's 10 archetype names and pulls
  only the sites each report actually names as an example for that shape.
- **Counts are single-reviewer eyeball counts at first paint**, not a second-coded or measured
  sample. Every report says so of itself (`visual-infra.md:377`, `visual-business.md:9`,
  `visual-verticals.md:22`, `visual-craft.md:30-31`). Treat a row here as "the reviewer saw this",
  not as a verified population.
- **Plugins must never copy these names into a shipped file.** That is the doctrine rule this
  file exists to satisfy: `moves-taxonomy.md:9-11` and `mining-method.md:23-25` forbid a
  named-site catalog under `plugins/`, and `visual-craft.md` §4.4 states the same conflict
  explicitly for this exact request. This file is the compliant version — the evidence lives in
  `rationale/`, the shipped recipe cites this path, and nothing under `plugins/` names a site.
- **Stack column** (`framework · UI · motion/3D`) is joined from
  `rationale/2026-09-25-design-capability-corpus/sites.tsv` on `site`; a blank means the detector
  found nothing, not that the site uses nothing (`sites.tsv`'s own caveat, see the corpus README).
- **Screenshots** live at `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png`
  (one per site, 1280×800, first paint). They are gitignored and not part of this commit;
  regenerate with `python3 rationale/2026-09-25-design-capability-corpus/tools/shots.py`.

---

## Editorial statement

Recipe row: `editorial statement` in `archetype-recipes.md`.

| site | category | framework · UI · motion/3D | why it is a good specimen |
|---|---|---|---|
| wearecollins.com | Motion-forward studios | Nuxt · Motion, View Transitions API · JS motion | reviewer's own "editorial statement (quiet line, media below)" bucket (`visual-craft.md:53`) |
| work.co | Motion-forward studios | React (WordPress) · — · Static/CSS | same bucket |
| ramotion.com | Motion-forward studios | — (DatoCMS) · Lottie · JS motion | same bucket |
| planetscale.com | Databases, data & internal tools | Remix/React Router · Headless UI, Tailwind · Static/CSS | "an all-mono prose homepage" (`visual-infra.md:138`), also labelled "Prose / docs / editorial page" |
| laravel-news.com | Laravel & PHP ecosystem | Livewire, Alpine.js · Tailwind · Static/CSS | "Laravel News as a newspaper" (`visual-infra.md:136`) |
| cognition.ai | AI products & LLM tooling | Next.js · shadcn/ui (likely), Tailwind · JS motion | "a memo: left text nav, numbered sections, serif body, visible column rules" (`visual-business.md:111`) |

Screenshots: `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png` for each site above.

## Typographic

Recipe row: `typographic`.

| site | category | framework · UI · motion/3D | why it is a good specimen |
|---|---|---|---|
| darkroom.engineering | Motion-forward studios | Next.js (Sanity) · GSAP ScrollTrigger, Lenis, View Transitions · Scroll-choreographed | "full-width pixel display face, red on black" (`visual-craft.md:51`) |
| cuberto.com | Motion-forward studios | Astro · GSAP, GSAP ScrollTrigger, Lenis, View Transitions · Scroll-choreographed | "masked line build-in, caught mid-animation" (`visual-craft.md:51`) |
| instrument.com | Motion-forward studios | Nuxt (Storyblok) · GSAP, GSAP ScrollTrigger · Scroll-choreographed | "a wordmark set to the full frame width" (`visual-craft.md:51`) |
| basement.studio | Motion-forward studios | Next.js (Sanity) · three.js, R3F, Motion, react-spring · 3D/WebGL | "a three-line 90 px grotesk" (`visual-craft.md:51`) |
| metalab.com | Motion-forward studios | Next.js (Sanity) · GSAP, GSAP ScrollTrigger, Lenis, Motion · Scroll-choreographed | "serif words scattered over the viewport with location, founding year and local time as micro-type" (`visual-craft.md:51`) |

Screenshots: `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png` for each site above.

## Living system

Recipe row: `living system`.

| site | category | framework · UI · motion/3D | why it is a good specimen |
|---|---|---|---|
| unicorn.studio | Framework & motion-library sites | Vue · Unicorn Studio · 3D/WebGL | the hero is literally a hosted shader-scene editor: "shader hero" (`visual-craft.md:70`) |
| fantasy.co | Motion-forward studios | Nuxt (DatoCMS) · Tailwind, three.js, GSAP, GSAP ScrollTrigger, Lenis · 3D/WebGL | "a shader-glow blob" (`visual-craft.md:50`), one of the few that renders almost immediately (`visual-craft.md:255`) |
| liquefy-ui.com | shadcn registries | React · Base UI · Static/CSS | "a live 'liquid glass' panel over a photo"; its sliders "retint the whole site as you move it" (`visual-craft.md:101-102, 112`) |

Only 3 examples found across the four reports for this shape — the corpus's shader/particle work
mostly shows up as a hero on registries and studios, not as a standalone marketing archetype.

Screenshots: `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png` for each site above.

## Product-in-motion

Recipe row: `product-in-motion`.

| site | category | framework · UI · motion/3D | why it is a good specimen |
|---|---|---|---|
| cloud.laravel.com | Cloud hosting & PaaS | Laravel, Inertia, React · Radix, Tailwind · Scroll-choreographed (CSS scroll-driven) | "a tabbed product tour directly under the hero, advancing with a progress underline": Deploy/Run/Scale (`visual-infra.md:157`) |
| northflank.com | Cloud hosting & PaaS | Next.js · styled-components, Emotion · JS motion | same tabbed-tour move: Deployments/Previews/Sandboxes (`visual-infra.md:157`) |
| tempo.new | AI products & LLM tooling | React · Base UI, Tailwind · Static/CSS | "persona or use-case tabs that swap the demo" — Designers/PMs/Engineers/Agents, auto-advance bar (`visual-business.md:225`) |
| getlago.com | Fintech, billing & payroll | Next.js · shadcn/ui (likely), Radix, Tailwind · Static/CSS | ships a visible "Pause" control on its animated panel (`visual-verticals.md:240`) |

Screenshots: `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png` for each site above.

## Spatial scene

Recipe row: `spatial scene`.

| site | category | framework · UI · motion/3D | why it is a good specimen |
|---|---|---|---|
| igloo.inc | Motion-forward studios | Nuxt · three.js (live-rendered; detector floor, see note) · 3D/WebGL | "photoreal snowfield; each piece of work is an object with a HUD callout" (`visual-craft.md:50`) |
| activetheory.net | Motion-forward studios | — (live-rendered; detector floor, see note) · Static/CSS | "a particle forest that you fly through on scroll" (`visual-craft.md:50`) |
| halo-lab.com | Motion-forward studios | Webflow · Spline, GSAP, GSAP ScrollTrigger, Lenis, Lottie · 3D/WebGL | "a rendered hand and orb, via Spline" (`visual-craft.md:50`) |

**Detector floor:** `sites.tsv` flags igloo and activetheory as `Static/CSS`. The report's own live
Playwright renders (`review/live/*.png`) show both are full-screen WebGL — first-paint detection
undercounts the studio ceiling (`visual-craft.md:26-28`).

Screenshots: `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png` for each site above.

## Interface specimen

Recipe row: `interface specimen`.

| site | category | framework · UI · motion/3D | why it is a good specimen |
|---|---|---|---|
| sevalla.com | Cloud hosting & PaaS | Next.js · shadcn/ui (likely), Radix, Tailwind · JS motion | live-coded specimen with real resource nouns, fixed polarity even inside a dark hero (`visual-infra.md:44-47, 201, 207`) |
| render.com | Cloud hosting & PaaS | Next.js (Sanity) · Radix, Tailwind, Motion, Lottie · JS motion | "app-backend ✓ Available" with memory/CPU sparklines, per-service sparkline cards (`visual-infra.md:145, 220`) |
| metabase.com | Databases, data & internal tools | Astro · Bootstrap, Tailwind · Static/CSS | stat tiles with a delta beside a stacked bar chart and an AI chat side panel (`visual-infra.md:229`) |
| twenty.com | CRM & sales | Next.js · Base UI, Lottie · JS motion | "serif H1, macOS-framed Companies table" — a real record table as the specimen (`visual-business.md:96`) |
| attio.com | CRM & sales | Next.js (Storyblok) · Radix, Base UI, Tailwind, Motion · JS motion | one of the CRM leaders whose "settled" screen grammar the report builds §1 §4 around (`visual-business.md:33-39, 96`) |

Screenshots: `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png` for each site above.

## Working instrument

Recipe row: `working instrument`.

| site | category | framework · UI · motion/3D | why it is a good specimen |
|---|---|---|---|
| turbopuffer.com | Databases, data & internal tools | Next.js · shadcn/ui (likely), Radix, Tailwind · Static/CSS | "an ASCII architecture diagram plus a live calculator" above the fold (`visual-infra.md:49, 138`) |
| axiom.co | Observability & incident response | Next.js (Storyblok) · shadcn/ui (likely), Base UI, Tailwind, Motion · Scroll-choreographed | "a query with a Run button": `where ['event.type'] == "charge.failed"` (`visual-infra.md:49, 162`) |
| chartmogul.com | Product analytics & experimentation | — · — · Static/CSS | "`>_` prompt, typed question, five domain-question chips" (`visual-business.md:104`) |
| cal.com | Scheduling, forms & e-sign | Framer (site builder) · Motion (Framer Motion) · JS motion | "a working month picker" — the booking calendar itself is the hero (`visual-verticals.md:93`) |
| convex.dev | Databases, data & internal tools | Next.js · Headless UI, Tailwind · Static/CSS | "copy the setup prompt for your agent" chips, plus npm/GitHub proof in the nav (`visual-infra.md:163, 166`) |

Screenshots: `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png` for each site above.

## Project index

Recipe row: `project index`.

| site | category | framework · UI · motion/3D | why it is a good specimen |
|---|---|---|---|
| obys.agency | Motion-forward studios | — (live-rendered; detector floor) · Static/CSS | "an infinite vertical wheel of projects with a focus lens, a synced title list and a Vertical/Horizontal/Grid switch" (`visual-craft.md:52`) |
| pentagram.com | Motion-forward studios | — · Tailwind, GSAP, GSAP ScrollTrigger, Barba/Swup · Scroll-choreographed | "a sentence filter, 'We design [Books] for [Everyone]'" (`visual-craft.md:52`) |
| studiofreight.com | Motion-forward studios | Nuxt (Storyblok) · GSAP, GSAP ScrollTrigger, Lenis · Scroll-choreographed | "a scattered field of thumbnails around one serif line" (`visual-craft.md:52`) |
| threejs.org | Framework & motion-library sites | — · three.js, anime.js, react-spring · 3D/WebGL | "a 6×7 wall of user projects IS the homepage, with nav as a mono sidebar" (`visual-craft.md:71`) |

Screenshots: `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png` for each site above.

## Library / registry / dev-tool front door

Recipe row: `library / registry / dev-tool front door`.

| site | category | framework · UI · motion/3D | why it is a good specimen |
|---|---|---|---|
| ui.shadcn.com | UI libraries & design systems | Next.js · shadcn/ui (likely), Radix, Base UI, Tailwind · Scroll-choreographed | live real components above the fold — buttons, inputs, a chart, a QR card in a 3-column bento (`visual-craft.md:99`) |
| skiper-ui.com | UI libraries & design systems | Next.js · shadcn/ui (likely), Radix, Base UI, Tailwind, Motion · Scroll-choreographed | "the headline is its own masked-rolling split-text component" (`visual-craft.md:101`) |
| kokonutui.com | UI libraries & design systems | Next.js · Radix, Tailwind, Motion · JS motion | install command as the primary CTA: `npx shadcn@latest mcp init --client claude` (`visual-craft.md:100`) |
| 21st.dev | UI libraries & design systems | Next.js · shadcn/ui (likely), Radix, Tailwind, View Transitions · JS motion | "a carousel of animated heroes, filtered by chips such as Shaders or Liquid & metal" (`visual-craft.md:101`) |
| smoothui.dev | UI libraries & design systems | Next.js · shadcn/ui (likely), Radix, Tailwind, Motion, react-spring · JS motion | hero control panel that re-parameterises the whole site: colour swatches, Calm/Energetic, pause, sound toggle, theme, 3D (`visual-craft.md:102, 113`) |

Screenshots: `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png` for each site above.

## WebGL-first site (page level)

Recipe row: `WebGL-first site (page level)`.

| site | category | framework · UI · motion/3D | why it is a good specimen |
|---|---|---|---|
| immersive-g.com | Motion-forward studios | Nuxt · three.js, GSAP, GSAP ScrollTrigger, Lenis, Lottie · 3D/WebGL | named in R7 as one of the two sites whose "one fixed canvas behind the page" tracks DOM rects with scroll velocity fed in as a uniform (`visual-craft.md:214, 359-361`); "plaster-relief world" (`:50`) |
| lusion.co | Motion-forward studios | Astro · three.js · 3D/WebGL | the other named DOM-synced site: "a physics-toy scene inside a rounded frame, with a `000` load counter" (`visual-craft.md:50, 214`) |

Only 2 examples found. The report ties the DOM-synced, scroll-driving-the-camera architecture
specifically to these two sites (`visual-craft.md` §4.2 M3 and R7); it does not name a third. Note
that their scroll mechanism (`body{overflow:hidden}`, wheel-hijacked) is flagged elsewhere in the
same report as the anti-pattern to avoid — the recipe's own `Built by` column points at Lenis over
native scroll instead (as `locomotive.ca` does, `visual-craft.md:213-325`), so use these two for the
page-level *shape*, not for the scroll implementation.

Screenshots: `taskmaster-docs/design-corpus-2026-09-25/shots/light/<site>.png` for each site above.

---

## How to use this

`design-research` picks references from here for a brief, then re-verifies each one live — a
screenshot from 2026-09-25 is not proof of what a site looks like today. This list ages: re-run the
corpus scan (`rationale/2026-09-25-design-capability-corpus/README.md` § Reproduce) before trusting
it for a build much later than this date.
