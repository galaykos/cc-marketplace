# Design capability corpus — 2026-09-25

**Plugins this serves:** `ui-ux`, `craft-layer`, `web-dev`, `laravel`. The question behind it: when a user asks
for "a CRM like Attio" or "a console like Laravel Cloud / Sevalla", which techniques would the build need, and
does a marketplace skill carry the rules for each one? This directory is the evidence, not the answer. Nothing
here has been built yet, and no control arm has run (see § What this does not show).

| file | what |
|---|---|
| `sites.md` / `sites.tsv` | **1,530 live sites**. 1,193 are apps, SaaS, hosting consoles, CRMs, studios and so on; 337 are shadcn registries. Each row has its detected framework, UI system, motion/3D libraries, other libraries, rendered look and host. |
| `ideas.md` / `ideas.tsv` | **500 web-app ideas**. Each one is pinned to one UI stack, one motion/3D choice, one data-viz choice and one backend. Each has 2 reference sites from the corpus, the marketplace skill covering each axis, and its gaps. |
| `tools/` | The scripts that produced every number here: `detect.py`, `build.py`, `shots.py` and `gallery.py`. |

Screenshots (1280×800, one light-scheme and one dark-scheme per site, ~700 MB) are **not tracked**. `tools/shots.py`
regenerates them, and `tools/gallery.py` writes a filterable `index.html` over them. The working copy used for this
run lives in the gitignored `taskmaster-docs/design-corpus-2026-09-25/shots/`.

## How the list was built

1. **Candidates (1,659):**
   - a seed list of 1,250 domains written by category: CRM, hosting/PaaS (Laravel Cloud, Forge, Vapor, Nova, Sevalla, Kinsta, Vercel, Railway, Render, Fly…), dev tools, data, observability, security, AI, productivity, fintech, marketing, support, HR, commerce, CMS, scheduling, the Laravel/PHP ecosystem, open-source apps, vertical SaaS, framework and motion-library sites, motion-forward studios and consumer apps;
   - hosts harvested from the Tailwind showcase, MUI showcase, saasframe, darkmodedesign, onepagelove and godly galleries;
   - every homepage in shadcn's own registry directory (`apps/v4/registry/directory.json`, 382 entries).
2. **Liveness:** 1,537 returned HTML. 115 failed (66 × 403, 20 timeouts, the rest other HTTP codes) and 7 hit a bot wall. Deduping by final URL after redirects leaves **1,530**.
3. **Category comes from the seed list, not from detection.** A site sits where it was seeded.

## How "uses X" was decided

`tools/detect.py` fetches the homepage, then up to 24 first-party JS files and 6 CSS files, capped at 20 MB per site. First-party means the same registrable domain, a brand-named CDN, or a site-builder CDN. It then matches one regex per technology; the signature table is the `SIG` dict at the top of the script. Two guards apply:

- **A match inside an embedded `package.json` map** (e.g. `"solid-js":"^1.9"`) is a mention, not a use, and is discarded.
- **View Transitions and CSS scroll-driven count only from markup or CSS.** React 19 / Next ship view-transition CSS strings in their runtime.

**Precision audit.** Three passes each sampled 3–4 hits per technology, for 29 technologies, and read the matching snippet.
- **Pass 1** found these false positives:
  - Sonner's `[data-styled=true]` counted as styled-components (239 → 67 sites after the fix);
  - "recharts" containing "echarts" (186 → 8);
  - prose like "three.js" in a benchmark table;
  - Webflow variables named `--_apps---colors--popover-foreground` counted as shadcn;
  - `.p-card-parent`-style custom classes counted as PrimeReact (14 → 5);
  - docs link text counted as React Three Fiber (23 → 17);
  - loose Lottie and StyleX strings.
- **Every fix was applied and the whole corpus rescanned.**
- **Post-fix sample:** 35 of 36 re-checked hits and 42 of 42 hits on unchanged signatures were real. The single miss (proton.me / Astro) no longer matched on re-fetch.
- **The sample is too small to bound any single technology's precision tightly.** It only rules out gross noise.

**Read the columns with these limits:**
- **A blank cell means "not detected", never "not used".** Lazy chunks past the 24-file cap, server-only rendering and third-party-hosted assets all hide a library.
- **Some hits mean "installed in the codebase", not "rendered on this page".** Examples are `[vaul-drawer]`, `[cmdk-…]` or `.recharts-…` selectors in Tailwind output: Tailwind scans every component file, so a shadcn Drawer that is never opened still leaves its CSS. For shadcn-based sites this is the norm.
- **Third-party widgets count.** Clerk's embed brings Emotion, and an Inkeep search widget brings Chakra CSS. The Chakra rule was narrowed for that reason.
- **`shadcn/ui*` is an inference.** It means shadcn's `data-slot` markup or its CSS-variable set, not a package import (shadcn has none).
- **`registry-motion*`** means Magic UI / Aceternity-style keyframe class names (`animate-marquee`, `animate-shimmer`, …).

**Look** comes from rendering, not markup:
- `tools/shots.py` screenshots each site in headless Chrome twice, forcing `prefers-color-scheme` light and then dark.
- It measures mean luminance, colourfulness and dominant accent hue.
- A first version guessed dark mode from `<html class="dark">` and `theme-color`. That flag caught **3 of 14** dark sites in a screenshot check, so it was dropped.
- A second trap: headless Chrome defaults to the **dark** scheme. radix-ui.com and ui.shadcn.com rendered dark until the light scheme was forced.
- "Light + dark (follows OS)" means the two passes differ: light pass bright, dark pass dark.
- A screenshot is the first paint after load, capped at 12 s. Preloaders and WebGL scenes that render late are measured as whatever showed first.

Rendered look of the 1,193 non-registry sites (light-scheme pass, luminance thresholds 0.3 / 0.6):

| look | sites |
|---|---|
| Light | 559 |
| Dark only | 302 |
| Mid-tone | 165 |
| Light + dark (follows OS) | 166 |
| no screenshot | 1 |

- **Colour:** 558 sites measure muted (colourfulness < 0.04) and 231 vivid (> 0.12). Accent hues run blue 306, orange 117, violet 96, green 85, red 78, teal 75, yellow 32, pink 17.
- **Type:** 82 load a serif display face and 304 load a monospace face (from `@font-face`, Google Fonts URLs and next/font class names).
- **Dark shares by category:**
  - Lean dark: hosting/PaaS (32 dark-only of 76, against 25 light) and studios (16 of 30).
  - Lean light: CRM (7 dark of 58) and AI (20 of 86).
- **Spot checks by eye, 22 screenshots in all:**
  - they found the headless dark-scheme bias above, which the two-pass method fixed;
  - Laravel Cloud measures light (0.97) and is light; the markup guess had called it dark;
  - Sevalla's dark pass (0.32) is a dark hero over a white dashboard mock-up, which is why "follows OS" is a luminance *difference* of at least 0.35 and not a threshold.

## What the corpus says

Prevalence is over the **1,193 non-registry sites**; the 337 registries are 82% shadcn and would skew every row.

| technology | sites | share | marketplace coverage |
|---|---|---|---|
| Tailwind | 602 | 50% | `ui-ux:tailwind-best-practices` |
| React | 569 | 48% | via the framework skills |
| Next.js | 455 | 38% | `web-dev:nextjs-best-practices` |
| Motion (ex-Framer Motion) | 280 | 23% | `ui-ux:motion-best-practices`, `craft-layer:motion-tiers` |
| Radix | 250 | 21% | grouped in `ui-ux:component-libraries`; the shadcn skills |
| Swiper / Splide / Embla (carousels) | 233 / 65 / 54 | 20% / 5% / 5% | **none** |
| Lottie | 184 | 15% | `craft-layer:motion-tiers` |
| GSAP + ScrollTrigger | 171 | 14% | `craft-layer:scroll-orchestration` |
| shadcn/ui* | 153 | 13% | `ui-ux:shadcn-best-practices` |
| Webflow / WordPress / Framer-built | 133 / 118 / 44 | 11% / 10% / 4% | out of scope (not code a build produces) |
| Sanity / Contentful | 98 / 61 | 8% / 5% | **none** |
| CSS scroll-driven animations | 90 | 8% | `craft-layer:scroll-orchestration` |
| Astro | 80 | 7% | mention only |
| View Transitions API | 75 | 6% | `craft-layer:page-transitions` |
| Recharts | 71 | 6% (31% of registries) | mention only (`craft-layer:information-design`) |
| Base UI / Headless UI | 60 / 71 | 5% / 6% | grouped in `ui-ux:component-libraries` |
| Alpine.js / Livewire | 59 / 22 | 5% / 2% | mention only |
| Tiptap / Lexical (rich text) | 50 / 39 | 4% / 3% | **none** |
| Lenis | 51 | 4% | `craft-layer:scroll-orchestration` |
| Rive | 48 | 4% | `craft-layer:motion-tiers` |
| three.js / R3F | 41 / 17 | 3% / 1% | `craft-layer:threejs-best-practices` |
| MUI | 31 | 3% | `ui-ux:mui-best-practices` |
| Spline / Unicorn Studio / Paper Shaders | 7 / 6 / 9 | <1% each | **none** |
| PrimeReact / PrimeVue | 5 | <1% | PrimeVue grouped in `ui-ux:component-libraries`; PrimeReact none |
| Astryx | 1 (its own site) | — | `ui-ux:astryx-best-practices` |

Motion tier over the 1,193 non-registry sites:
- **3D/WebGL:** 57 (5%)
- **Scroll-choreographed:** 249 (21%)
- **JS motion only:** 387 (32%)
- **Static or CSS-only:** 500 (42%)

The studio bucket is the ceiling: half of the 30 studio sites run GSAP + ScrollTrigger, a third run three.js, and a third run Lenis.

Per-category stacks worth knowing:
- **Hosting / PaaS (76):** Tailwind 62%, Next.js 29%, Radix 24%, GSAP 18%, shadcn* 14%.
  - Laravel Cloud is Laravel + Inertia + React + Tailwind v4 + Radix.
  - Sevalla is Next.js + shadcn/Radix + Tailwind + Motion.
- **Laravel & PHP ecosystem (43):** Tailwind 74%, Alpine 65%, Livewire 40%, Inertia 5%. Laravel's own ecosystem ships Livewire, and the marketplace's Laravel UI coverage is Inertia.
- **CRM (58):** Webflow-built marketing sites (29%) with Swiper, Lottie and GSAP. The CRMs' app UIs sit behind logins and are not in this corpus.
- **Studios (30):** GSAP/ScrollTrigger 50%, three.js 33%, Lenis 33%, Nuxt 20%.

## The capability check (500 ideas)

The stack mix is exactly what was asked for:

| stack | ideas |
|---|---|
| shadcn/ui | 110 |
| shadcn registries | 90 (16 registries named) |
| Tailwind + Headless UI / Base UI / React Aria / Catalyst | 70 |
| MUI | 70 |
| PrimeReact | 60 |
| Other (Mantine, Ant Design, HeroUI, Chakra, Radix Themes, PrimeVue, Vuetify, daisyUI, Flowbite, Park UI, Nuxt UI, Element Plus) | 60 |
| Astryx | 40 |

Every axis of an idea (UI stack, registry, motion/3D, data viz, backend) was looked up against the frontmatter of every
shipped `SKILL.md`. The tiers:
- **Dedicated:** the skill is named for the technology.
- **Grouped:** the technology is named in a multi-library skill's frontmatter, e.g. `component-libraries`.
- **Mention only:** the technology appears in some skill body.
- **None.**

**215 of the 500 ideas have every axis covered** at the dedicated or grouped tier. The other 285 have at least one axis
with a mention-only or no-skill tier. (The first commit of this file said 258: `tools/build.py` credited PrimeReact to
`component-libraries` because its regex `PrimeReact|PrimeVue` matched a PrimeVue mention. Nothing under `plugins/`
named PrimeReact on 2026-09-25; the 60 PrimeReact ideas are a gap. Corrected 2026-09-26, found by the review in
`taskmaster-docs/design-corpus-2026-09-25/review/ui-systems.md` Q4.)
- **Covered well:** shadcn/ui, Tailwind, MUI (including MUI X Charts), Astryx, ReUI, Aceternity, Motion, GSAP/ScrollTrigger/Lenis, three.js/R3F, Rive/Lottie, anime.js, Matter.js, View Transitions, CSS scroll-driven, Laravel + Inertia, Next.js and Vite.
- **Grouped only:** Mantine, Ant Design, HeroUI, Chakra, PrimeVue, Vuetify, Element Plus and Park UI. These rest on `ui-ux:component-libraries`: library-agnostic rules plus a docs link per library.
- **No skill at all:** PrimeReact (60 ideas). Nothing under `plugins/` named it.
- **Mention only:** Radix Themes, daisyUI, Flowbite and Nuxt UI.

**Where the marketplace has nothing, ranked by how many ideas need it:**

1. **Data-viz libraries: 135 of the 500 ideas, 6% of sites, 31% of registries.**
   - Recharts appears as a mention only, in 49 ideas.
   - These have no skill at all: Chart.js (23 ideas), ECharts (22), Tremor charts (16), D3 (15, mention only), AG Grid (5), TanStack Table (4), Nivo (1).
   - Only MUI X Charts (34 ideas) is covered, through `mui-best-practices`.
   - `craft-layer:information-design` defers chart form and colour to a `dataviz` skill that this marketplace does not ship.
   - This is the largest single gap.
2. **shadcn registries other than ReUI and Aceternity: 83 of the 90 registry ideas, spread over 14 registries.**
   - By idea count: Tremor 13, Origin UI 8, Magic UI 8, shadcnblocks 8, 21st.dev 5, Cult UI 5, Skiper UI 5, Animate UI 5, Kokonut UI 5, Motion Primitives 5, Eldora UI 5, React Bits 4, Smooth UI 4, tweakcn 3.
   - Fourteen skills would fail the Admission law.
   - One reference covering namespaced `@registry/item` installs from the 382-entry directory, inside `shadcn-best-practices`, would cover all of them.
3. **PrimeReact: 60 ideas, no coverage.**
   - Nothing under `plugins/` names it; the first version of this file wrongly said `component-libraries` covered it.
   - The scan saw PrimeReact 11 emitting `data-scope`/`data-part` markup, a different architecture from the `p-component` classes a v10 memory recites.
   - That is the version-churn pattern that justified `mui-best-practices`. It is worth a dedicated skill **if** a control run shows the base model getting v11 wrong.
4. **Frameworks: Nuxt (14 ideas, mention only), React Router framework mode (11, none), Astro (10, mention only).** These are `web-dev` territory.
5. **Motion gaps: AutoAnimate (15 ideas), Spline (8), Paper Shaders (7).**
   - `craft-layer:motion-tiers` / `webgl-effects` cover three.js but not the no-code 3D runtime (Spline, Unicorn Studio) or shader-preset libraries.
6. **From the site scan, not the ideas:**
   - carousels (Swiper, Splide, Embla: 20% / 5% / 5% of sites, and a known accessibility trap);
   - headless CMS content modelling (Sanity, Contentful);
   - rich-text editors (Tiptap, Lexical);
   - Livewire + Alpine for Laravel-shaped builds.

## What this does not show

- **Coverage means a skill names the technology, not that the skill makes the build better.** Nothing here measured a
  build. The repo's own rule applies (`CLAUDE.md` § Where documentation lives): a skill earns its place only if a control arm shows
  the base model failing without it. The proper capability check is to pick about 10 ideas (one per UI stack, plus a 3D one,
  a data-viz one and a Laravel + Inertia one) and build each with and without the plugins, graded against the reference
  sites' screenshots.
- **The corpus sees marketing homepages.** The app UIs behind sign-in (Attio's CRM, Laravel Cloud's console) are not
  scanned. The dashboards in the 500 ideas are exactly the surfaces the corpus cannot see.
- **Detection lower-bounds usage** (§ How "uses X" was decided).
- **The ideas were generated by five parallel model runs with exact stack quotas.**
  - Seven cross-shard near-duplicates were found by token overlap and replaced by hand.
  - Uniqueness is checked mechanically on names and on pitch overlap (Jaccard ≥ 0.3), not judged by a human.
- **Reference sites for an idea are scored mechanically:**
  - +3 for a matching detected UI stack;
  - +3 for a matching motion library;
  - +1 for data viz;
  - +1 for category;
  - a penalty for reuse.
  They show the technique in the wild, not that the site is the same kind of product.

## Reproduce

```bash
python3 tools/detect.py tools/candidates.json results.jsonl 32   # ~20 min at 32 processes
python3 tools/shots.py results.jsonl shots/light looks_light.json light
python3 tools/shots.py results.jsonl shots/dark  looks_dark.json  dark
LOOKS=looks_light.json LOOKS_DARK=looks_dark.json CORPUS_DATE=2026-09-25 \
  python3 tools/build.py results.jsonl <ideas_dir> <out_dir> <repo_root>
python3 tools/gallery.py results.jsonl shots
```

`tools/candidates.json` is the exact 1,659-entry input: `{site: category code}`, covering the seed list, the gallery harvest and the
registry directory. The idea shards were model-generated, so the `ideas_*.tsv` inputs are the committed `ideas.tsv` minus its last three columns.
