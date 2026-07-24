---
description: Audit a crafted web app's motion and asset gates, delegating a11y and performance to their owning tools
argument-hint: [path-or-scope]
---

Audit the craft gates for the target in $ARGUMENTS (if empty, ask which path or
scope to audit first). Load the `motion-tiers` skill from this plugin for the tier
taxonomy and its per-tier budgets, then:

1. Detect what the target uses: grep the scope for each animation tier's imports and
   entry points — Framer Motion / `motion`, anime.js, Three.js / R3F / `<canvas>`,
   sprite sheets — AND the sibling engines (scroll-orchestration/Lenis, page-transitions/
   View Transitions, interaction-fx, physics-motion/matter, motion-sequencing/theatre,
   webgl-effects), plus any 3D/WebGL surface — AND scan for shipped visual/font ASSETS, whether
   committed FILES (icons, SVG, raster images, 3D models, Lottie/Rive, webfonts, background
   video) or third-party refs grepped from SOURCE — absolute-URL refs at an `https?://` host
   (`@font-face`/`@import`/`<link>`/`url()`/`<use href>`), inline `data:`/over-threshold `<svg>`
   blobs, and URL-fetched `.lottie`/`.riv`/`.glb`/font — and a
   provenance manifest. List the tier(s), engine(s), surface(s), and assets found. If
   nothing animates BUT shipped assets are present, still run the asset/licence gates in
   step 2 — do not stop. Only when there is neither motion nor a shipped asset, say so and stop.
2. Run the craft-specific gates by dispatching the findings to the `craft-reviewer`
   agent from this plugin. Inject the Read path to `../skills/motion-tiers` (authoritative
   budgets) AND the Read paths to
   `../skills/creative-direction/references/sameness-fingerprint.md` and
   `../skills/creative-direction/references/content-depth.md` (the anti-sameness registry
   and the content-depth anchors) AND
   `../skills/asset-sourcing/references/licence-discipline.md` (the provenance-manifest
   schema), and have it verify: every tier/engine in use honors
   `prefers-reduced-motion`; each 3D/WebGL surface is lazy-loaded with a static fallback;
   each tier is within its per-tier budget AND the COMBINED initial motion JS is budgeted
   (non-hero engines lazy-loaded); sprites/assets stay within budget; the **licence gate** —
   every shipped third-party/AI asset — a committed FILE or a source ref (absolute-URL, inline
   `data:`/`<svg>`-with-marker, URL-fetched) — has a complete non-empty provenance record
   (manifest exists, no orphan asset OR unprovenanced ref, enumerated licence-class + source; an
   absolute-URL ref needs a record unless declared first-party), run even on a static
   asset-only build; **asset-fit** — right format per kind + a reduced-bundle fallback +
   source-class match (bytes stay with the existing sprite/asset budget, not re-counted);
   the **accent clears contrast on every surface AND size** it lands on (large ≥3:1, body ≥4.5:1; on a light
   theme small text/marks use a darker accent step than the display accent — text ≥4.5:1,
   non-text marks ≥3:1); the newer skills
   meet their done-ness (page-transition instant-nav fallback, webgl GPU/pass budget +
   capability fallback + off-screen loop pause + an error boundary for chunk-load/context
   failure, interaction-fx real-cursor +
   `pointer:coarse` disable, physics body-cap + reduced static, motion-sequencing
   studio-excluded-from-prod); the concept's **divergence record** breaks ≥1
   sameness-fingerprint default (a build matching the fingerprint with an empty record is a
   finding, unless a conventional design was explicitly requested); and **content depth**
   meets the archetype anchors + typed-slot specificity (anchors are tunable ranges, not a
   template; claim/aggregate metrics ship as `{{metric:*}}` slots rendered as labeled
   illustrative samples — not raw `{{mustache}}`, not unmarked invented literals; offer
   numerals like price/fee/step-count are fine). Collect its
   `path:line — severity — problem — fix` lines.
3. Delegate the checks craft-layer does not own — do not re-implement them: FULL
   accessibility → `/a11y:audit $ARGUMENTS` (the accent-vs-surface contrast pre-check is
   already covered as a craft gate in step 2; a11y owns the comprehensive pass);
   performance / Lighthouse / Core Web Vitals → `/performance:review $ARGUMENTS`.
   `/performance:review` requires the `performance` plugin; skipped if not installed. Run each
   against the same scope and collect their verdicts.
4. Report one consolidated pass/fail table: the craft gates from step 2, then the
   delegated results from step 3 presented against their audited TARGETS —
   Lighthouse Performance ≥ 90 and Accessibility ≥ 95. Frame these as targets the
   audit measures, not hard CI gates. Order findings by severity and name the owning
   tool for each delegated line.
5. When findings map to real files, offer the fix as a selectable choice
   (AskUserQuestion): "Route craft findings to craft-layer now" / "Report only".
   Headless: report only and print the exact `/a11y:audit` and `/performance:review`
   commands to rerun.
