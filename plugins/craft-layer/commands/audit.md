---
description: Audit a crafted web app's motion and asset gates, delegating a11y and performance to their owning tools
argument-hint: [path-or-scope]
---

Audit the craft gates for the target in $ARGUMENTS (if empty, ask which path or
scope to audit first). Load the `motion-tiers` skill from this plugin for the tier
taxonomy and its per-tier budgets, then:

1. Detect what the target uses: grep the scope for each animation tier's imports and
   entry points — Framer Motion / `motion`, anime.js, Three.js / R3F / `<canvas>`,
   sprite sheets, and the Vector tier (`lottie-web`/`@lottiefiles/*`/`@dotlottie/*`,
   `@rive-app/*`, `.lottie`/`.json` animation data, `.riv`) — AND the sibling engines (scroll-orchestration/Lenis, page-transitions/
   View Transitions, interaction-fx, physics-motion/matter, motion-sequencing/theatre,
   webgl-effects), plus any 3D/WebGL surface — AND scan for shipped visual/font ASSETS, whether
   committed FILES (icons, SVG, raster images, 3D models, Lottie/Rive, webfonts, background
   video) or third-party refs grepped from SOURCE — absolute-URL refs at an `https?://` host
   (`@font-face`/`@import`/`<link>`/`url()`/`<use href>`), inline `data:`/over-threshold `<svg>`
   blobs, and URL-fetched `.lottie`/`.riv`/`.glb`/font — and a
   provenance manifest. List the tier(s), engine(s), surface(s), and assets found. If
   nothing animates BUT shipped assets are present, still run the asset/licence gates in
   step 2 — do not stop. Only when there is neither motion nor a shipped asset, say so and stop.
   The motion/asset stop applies to the motion and asset gates ONLY — the offer-contract,
   content-depth, and anti-sameness gates read page CONTENT and still run on a fully static
   build, which is exactly when a marketing page is most likely to need them.

   **1b. MEASURE what the reviewer cannot.** The reviewer is Read/Grep/Glob and can see no
   file's byte size. You have Bash: before dispatching, collect the numbers its budget gates
   need and inject them as facts — per-asset gzipped and raw sizes for every shipped
   sprite/image/font/3D/Lottie file, and per-chunk gzipped size for the built bundle when a
   `dist/`/`build/` output exists (a project's own build command, `wc -c`, `gzip -c | wc -c`,
   or the bundler's report).

   Compute the CONTRAST RATIOS too — the reviewer cannot, and this is a craft gate rather
   than a deferred one. Read the resolved accent/ink/surface token values out of the theme
   (hex or the token file's channels), then compute WCAG relative-luminance ratios for each
   accent-on-surface pairing per theme with a short script, and inject the numbers. Where a
   value is only resolvable at runtime (a CSS var chain, a computed colour), say so for that
   pairing instead of guessing.

   Anything you cannot measure — no build output, no toolchain, an unresolvable colour — is
   injected as `not measured` for that item, and the reviewer reports it that way rather
   than asserting a verdict.
2. Run the craft-specific gates by dispatching the findings to the `craft-reviewer`
   agent from this plugin. Inject the Read path to `${CLAUDE_PLUGIN_ROOT}/skills/motion-tiers/references/tier-budgets.md` (authoritative
   budgets) AND the Read paths to
   `${CLAUDE_PLUGIN_ROOT}/skills/creative-direction/references/sameness-fingerprint.md` and
   `${CLAUDE_PLUGIN_ROOT}/skills/creative-direction/references/content-depth.md` (the anti-sameness registry
   and the content-depth anchors) AND
   `${CLAUDE_PLUGIN_ROOT}/skills/creative-direction/references/offer-contract.md` (the deliverable scope +
   offer-spine slots) AND — found by globbing `**/craft/offer-contract.md`,
   `**/craft/divergence-record.md` and `**/craft/section-ledger.md` (the fixed names the craft
   flow persists to; search the project and the session working area) — the PERSISTED contract
   instance and divergence record when they exist. Without the contract, the scope/length/mode
   AND the content-depth section-count checks have no anchor; without the record, anti-sameness
   has none. Report each as `not checked`, never as passing and never as failing. AND, when the run produced a
   section ledger, `${CLAUDE_PLUGIN_ROOT}/skills/section-decisions/references/section-ledger.md` plus the ledger
   itself AND
   `${CLAUDE_PLUGIN_ROOT}/skills/asset-sourcing/references/licence-discipline.md` (the provenance-manifest
   schema) AND the measurements from step 1b, and have it verify: every tier/engine in use honors
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
   template; claim/aggregate metrics ship as `{{metric:*}}` slots and capability claims —
   coverage, integrations, supported platforms, SLAs, compliance certifications — as
   `{{capability:*}}` slots, both rendered as labeled
   illustrative samples — not raw `{{mustache}}`, not unmarked invented literals; offer
   numerals like price/fee/step-count are fine, ONE disclosure marker per figure plus at most
   one regional footnote, no operator-addressed headline, no empty placeholder tiles); and the
   **offer contract** — the shipped
   routes match the pinned scope, ONE product identity under its REAL name (in `<title>` +
   hero, not a concept-invented wordmark), every offer-spine slot answered per marketing
   page (plain-language what — checked against the divergence record's metaphor vocabulary,
   not by taste — audience, problem, how-it-works, price, proof, objection, one
   repeated CTA verb), a proof region PRESENT as slots rather than deleted, and the declared
   page LENGTH honored (on `long-scroll` the section range is a floor, not a finding — instead
   check spine-answered-early, recurring one-verb CTA, varied section shapes, wayfinding past
   ~8 sections, lazy below-fold instruments); and, when a section ledger exists, **ledger
   conformance** — every row has its section in the build, no marketing section is
   unaccounted for, each row's `locks` actually ships, and `source: auto` rows are reported
   rather than flagged (no ledger → skip this gate; a one-shot build is not a finding).
   Collect its
   `path:line — severity — problem — fix` lines.
3. Delegate the checks craft-layer does not own — do not re-implement them: FULL
   accessibility → `/a11y:audit $ARGUMENTS` (the accent-vs-surface contrast pre-check is
   already covered as a craft gate in step 2; a11y owns the comprehensive pass);
   performance / Lighthouse / Core Web Vitals → `/performance:review $ARGUMENTS`.
   `/performance:review` requires the `performance` plugin; skipped if not installed. Run each
   against the same scope and collect their verdicts.
4. Report one consolidated pass/fail table: the craft gates from step 2, then the
   delegated results from step 3. Both delegates are STATIC reviews, not Lighthouse runs, so
   present Performance ≥ 90 / Accessibility ≥ 95 as the bar their findings are read against —
   never as a measured score, and never as a hard CI gate. A row whose delegate was skipped
   (plugin not installed) or whose input was `not measured` says so explicitly; a gate that
   could not run is reported `not checked`, never folded into a pass. Order findings by
   severity and name the owning tool for each delegated line.
5. When findings map to real files, offer the fix as a selectable choice
   (AskUserQuestion): "Fix the craft findings now" / "Report only". craft-layer ships no
   writer — both its agents are read-only — so route the accepted fixes down a static chain:
   `task-runner:task-executor` when the task-runner plugin is installed, else
   `ui-ux:ui-ux-engineer` for markup/style/component work, else apply them inline. Findings
   owned by a delegate go to that delegate's own worker (`a11y:a11y-engineer`,
   `performance:performance-engineer`). Headless: report only and print the exact
   `/a11y:audit` and `/performance:review` commands to rerun.
