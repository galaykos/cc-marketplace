# Archetype recipes — which skills build each hero shape

`moves-taxonomy.md` says each category points at the skill that OWNS its execution, and its
hero shapes named none, so the thread dropped exactly where a concept becomes a build. This
map closes it: one row per hero or page archetype, naming the MECHANISM, the skills that build
it, and the stack and budget anchor. It chooses nothing; the concept picks the shape.

**No sites here, by the categorical line.** Reference sites per archetype, the counts behind
each row and the screenshots live next to the design corpus in
`rationale/2026-09-25-design-capability-corpus/`, never in this plugin: a roster in a shipped
file ages into the house look (`moves-taxonomy.md`, `design-research`'s mining method).

| Archetype | Mechanism | Built by | Stack and budget anchor |
| --- | --- | --- | --- |
| editorial statement | a headline with a standfirst and one authored image or none; words and measure carry the argument | `type-strategy.md`; `kinetic-typography` (`references/type-system.md`); `asset-sourcing` for the image | no motion tier needed; the webfont KB ceiling is the budget; the LCP element is text |
| typographic | the setting is the image — frame-sized type, variable axes, at most one masked reveal | `kinetic-typography` (`type-system.md`, `variable-fonts.md`, `text-reveals.md`); `type-strategy.md` | one focal type animation per surface; the static type contract under reduced motion; a web licence tier |
| living system | a generative or simulated field that answers input — shader, particles, bodies | `webgl-effects` (`references/effect-pipeline.md`); `physics-motion`; `motion-tiers` tier 3 | the GPU pass cap and capability fallback in `webgl-effects`; a poster under reduced motion; paused off-screen |
| product-in-motion | the product's behaviour demonstrated as a loop or a scripted sequence | `motion-tiers` tier 1 (coded UI) or tier 5 (vector), or `<video>`; `ui-ux:motion-best-practices` | a poster frame first; a loop past five seconds owes a visible pause (WCAG 2.2.2) |
| spatial scene | a 3D scene the visitor looks into or steers | `motion-tiers` tier 3 (`references/webgl-3d.md`); `threejs-best-practices`; `asset-sourcing` (`references/vector-3d.md`) | tier 3 figures in `motion-tiers/references/tier-budgets.md`; the two-render contract in `webgl-3d.md` |
| interface specimen | the app's own components rendered as a cropped, fixed-polarity specimen with fictional-but-specific data; operable, or `inert` with a text alternative | `information-design` (`references/product-mock.md` for the front-door execution, `dense-ui-patterns.md` inside it); the stack's component skill in `ui-ux`; `content-depth.md` (mock carve-out) | usually the LCP element, so real markup vs image is a performance decision; no perspective tilt on data; at most one floating layer |
| working instrument | an operable slice — a query, a calculator, a prompt with domain chips, a copy-the-command chip — over canned or real data | `information-design`; the stack's component skill in `ui-ux`; `ui-ux:a11y-audit` (labels, keyboard, result announcement) | a static example state renders with no JS; results announce through one polite live region |
| project index | the work list as the first screen — rows that preview on hover AND focus, filter or scrub | `interaction-fx` (`references/pointer-patterns.md`); `page-transitions` (row to case study); `scroll-orchestration` (`references/scroll-acts.md`) when scrubbed | a static list in document order; preview media lazy; reduced motion drops the follower, never the list |
| library / registry / dev-tool front door | a live component is the hero; the install command is the primary action; preview and code are the unit | `ui-ux:shadcn-best-practices` (registry installs); `ui-ux:motion-best-practices`; `offer-contract.md` (the install as the one primary action) | the live component is the proof slot, never a screenshot; motion off-switches visible, sound off by default |
| WebGL-first site (page level) | one canvas persisting across routes, DOM and GL rects kept in sync, scroll driving the camera, a loader with real progress | `threejs-best-practices` (`references/webgl-first-site.md`); `scroll-orchestration` (Lenis over native scroll, never a virtual scroller); `page-transitions`; `motion-tiers` tier 3 | `maximal` ambition; the words stay in the served HTML; arrival follows `webgl-3d.md` |

Paths without a skill prefix are this skill's own references; a bare skill name is craft-layer's.

Standing: `recorded` — a map, not a gate. Nothing checks that a build used the owner a row
names, and a row naming a reference another skill has not written yet is a pointer, not a
promise that it exists.
