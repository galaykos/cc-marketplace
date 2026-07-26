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
   The stop applies to the motion CEILING gates and the asset gates ONLY. The offer-contract,
   content-depth, and anti-sameness gates read page CONTENT, and the SIGNATURE gate is a motion
   FLOOR whose entire purpose is a build with too LITTLE motion — so all four still run on a
   fully static build, which is exactly when a marketing page is most likely to need them.
   Never report "nothing animates" as a clean motion table.

   **1b. MEASURE what the reviewer cannot.** The reviewer is Read/Grep/Glob and can see no
   file's byte size. You have Bash: before dispatching, collect the numbers its budget gates
   need and inject them as facts — per-asset gzipped and raw sizes for every shipped
   sprite/image/font/3D/Lottie file, and per-chunk gzipped size for the built bundle when a
   `dist/`/`build/` output exists (a project's own build command, `wc -c`, `gzip -c | wc -c`,
   or the bundler's report).

   **Check the NARROW VIEWPORT if you can drive a browser.** A page whose body scrolls
   horizontally at a phone width is a layout defect, and layout is this audit's job — not
   `/a11y:audit`'s and not `/performance:review`'s, so it falls between them and gets
   checked by nobody. The usual cause is structural rather than cosmetic: a grid or flex
   item defaults to `min-width: auto`, so one wide child — a data table, a code block, a
   chart — pushes the whole page wider instead of scrolling inside its own container.
   Compare `document.body.scrollWidth` against `documentElement.clientWidth` at a narrow
   width; any excess is a finding, and name the overflowing element. Also read the copy
   for direction words ("on the right", "below") that a reflowed layout makes false.
   No browser available → `not measured`, never a silent pass.

   **Read the SERVED HTML, not the browser's.** `curl -s <url>` — or the framework's
   SSR/prerender output — must already contain the headline, the body copy and the primary
   CTA text. An SPA shell (Inertia, a client-only React/Vue mount, a router with SSR merely
   *configured*) serves an empty root element and fills it from JS, and every check that runs
   in a browser passes anyway: the screenshot is perfect, the a11y tree is complete, the suite
   is green. The page is still blank to any crawler that does not execute JS — which on a
   marketing surface is a large part of the audience, and on a page about machine visibility
   is the entire argument. `curl -s <url> | grep -ci "<a distinctive headline word>"` returning
   0 is a FAIL, not a note, and it fails the whole page: no craft above the fold survives a
   document with no text in it. Configured is not running; only the response body settles it.
   No reachable URL → `not measured`, never a silent pass.

   Compute the CONTRAST RATIOS too — the reviewer cannot, and this is a craft gate rather
   than a deferred one. Read the resolved accent/ink/surface token values out of the theme
   (hex or the token file's channels), then compute WCAG relative-luminance ratios for each
   accent-on-surface pairing per theme with a short script, and inject the numbers. Where a
   value is only resolvable at runtime (a CSS var chain, a computed colour), say so for that
   pairing instead of guessing.

   Anything you cannot measure — no build output, no toolchain, an unresolvable colour — is
   injected as `not measured` for that item, and the reviewer reports it that way rather
   than asserting a verdict.

   Inject the FIELD ANCHOR alongside the measured totals, so a number means something.
   HTTP Archive Web Almanac medians for a home page (**last verified 2026-07-25**; the
   Almanac republishes annually, so treat these as aged and re-read before quoting them)
   are roughly 2.9MB total
   transfer on desktop (2.6MB mobile), ~700KB JavaScript, ~1MB images, and ~280KB of that JS
   unused — and only about half of mobile origins pass all three Core Web Vitals. A build
   sitting on those medians is average, not good. State the comparison as context, never as
   a pass/fail gate: the thresholds themselves (LCP ≤2.5s, INP ≤200ms, CLS ≤0.1) are field
   metrics this audit cannot measure, and remain `/performance:review`'s call.
2. Run the craft-specific gates by dispatching the findings to the `craft-reviewer`
   agent from this plugin. Inject the Read path to `${CLAUDE_PLUGIN_ROOT}/skills/motion-tiers/references/tier-budgets.md` (authoritative
   budgets) AND the Read paths to
   `${CLAUDE_PLUGIN_ROOT}/skills/creative-direction/references/sameness-fingerprint.md` and
   `${CLAUDE_PLUGIN_ROOT}/skills/creative-direction/references/content-depth.md` (the anti-sameness registry
   and the content-depth anchors) AND
   `${CLAUDE_PLUGIN_ROOT}/skills/creative-direction/references/offer-contract.md` (the deliverable scope +
   offer-spine slots) AND
   `${CLAUDE_PLUGIN_ROOT}/skills/creative-direction/references/ambition-tiers.md` (the reach
   tiers and the three floors `maximal` adds) AND — found by globbing `**/craft/offer-contract.md`,
   `**/craft/divergence-record.md`, `**/craft/section-ledger.md` and `**/craft/reference-board.md`
   (the fixed names the craft
   flow persists to; search the project and the session working area) — the PERSISTED contract
   instance and divergence record when they exist. Without the contract, the scope/length/mode
   AND the content-depth section-count checks have no anchor; without the record, anti-sameness
   has none. Report each as `not checked`, never as passing and never as failing. AND, when the run produced a
   section ledger, `${CLAUDE_PLUGIN_ROOT}/skills/section-decisions/references/section-ledger.md` plus the ledger
   itself AND
   `${CLAUDE_PLUGIN_ROOT}/skills/asset-sourcing/references/licence-discipline.md` (the provenance-manifest
   schema) AND the measurements from step 1b, and have it verify: the concept's ONE **signature
   interaction** shipped — the divergence record names it, the build task's `Signature:` line
   assigned it a section, and the named mechanism is implemented there (this is the motion
   FLOOR and the only gate that fails a page for too little motion; entrance reveals never
   count toward it — apply the three-part test in
   `${CLAUDE_PLUGIN_ROOT}/skills/creative-direction/references/moves-taxonomy.md`
   (repeatable · driven-not-fired · changes what the surface affords) and require ALL
   THREE, because a scroll-linked arrival passes the first two and is still an entrance;
   and no record means `not checked`, never a pass); the **typeface decision** was made
   rather than defaulted — the record must carry BOTH the family assignment per role with
   its loading strategy AND the SPEC it satisfies (the strategy, required axes/features,
   coverage, licence class and KB ceiling that
   `${CLAUDE_PLUGIN_ROOT}/skills/creative-direction/references/type-strategy.md` derives).
   A family with no spec behind it is a default wearing a decision's clothes, and is the
   whole reason this gate checks two things instead of one. Then verify the shipped build
   against the spec's hard filters — tabular figures where numbers are read down a column,
   a text cut or `opsz` axis where text runs small and dense, the declared coverage, and
   the KB ceiling against the measured font bytes from step 1b. A deliberate
   system/device font stack that SATISFIES its spec passes; this gate never judges which
   family won.

   **When the contract's archetype is `app/CRM`** — or the target has a logged-in,
   data-dense half — ALSO run the app-craft floors in
   `${CLAUDE_PLUGIN_ROOT}/skills/information-design/references/app-craft-floors.md`.
   The signature and content-depth floors are marketing-shaped and answer `not
   applicable` behind a login, which leaves an app judged only by ceilings — and a grey,
   sluggish, mouse-only panel passes every ceiling there is. Check what is checkable
   statically: a dense grid is ONE tab stop with arrow keys inside (the trigger suite
   measures this); the app states beyond the table four exist (first-run, permission
   denied, partial failure, stale/offline); density is offered rather than baked;
   destructive actions are undoable rather than confirm-gated; and a data surface earns
   its motion — a list that re-sorts or a value that changes with no transition at all is
   this floor's version of a page with no signature. Perceived speed (feedback under
   ~100ms, optimistic writes with a rollback path) is runtime and is reported
   `not measured` unless something measured it. On a marketing-only target, say the
   floor set does not apply rather than passing it silently.

   Every tier/engine in use honors
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
   finding, unless a conventional design was explicitly requested) — and **each entry is
   verified against the shipped source, one at a time, not taken on the record's word**: an
   entry claiming a default was broken while the build still contains it counts as
   placeholder, exactly as `sameness-fingerprint.md` says, and the count of contradicted
   entries is reported. This is the gate's most-skipped half — a record with many entries reads
   as thorough divergence, and a rich record whose type or palette row is contradicted by the
   shipped tokens is the failure mode that survives every other check;
   **ambition conformance** — read the contract's `Ambition` row and grade against THAT tier
   (`ambition-tiers.md`). At `maximal` the three reach floors are checked: at least THREE
   distinct motion capabilities driving real surfaces — a `motion-tiers` tier or a sibling
   engine each count once, from the step-1 detection; at least
   ONE authored graphic system — generative/procedural canvas, WebGL/shader surface,
   programmatic SVG system, sprites, or a designer-authored vector asset, where rules, borders,
   icons and type treatment are composition and do NOT count; and an asset posture that is not
   all-first-party-emptiness (a manifest declaring nothing shipped passes the licence gate and
   fails this floor). Each floor is waivable ONLY by a reasoned entry in the divergence record;
   a floor missed with no waiver is one finding naming the floor. No `Ambition` row in the
   contract → `not checked`, never a pass and never a fail, and never inferred from how the
   page looks;
   **boost evidence** — read the contract's `Boost` row. At `ultra-craft`, check three things
   the boost promised and nothing else can prove: a `craft/reference-board.md` exists (glob it
   the same way) carrying at least six fetched sources across the three lanes, each with a URL
   and a fetch date, AND a searches-run block recording a category-scoped query at each of the
   three named galleries — `land-book.com`, `awwwards.com`, `dribbble.com` — where a query
   recorded as fetch-blocked still discharges the search, per
   `${CLAUDE_PLUGIN_ROOT}/skills/ultra-craft/references/research-mandate.md`;
   a section ledger exists, because a boosted run pinned `guided` and its absence is a miss
   rather than the legitimate one-shot skip above; and a red-team record exists naming what it
   attacked. Each miss is one finding. A `none` row or no row → `not checked`, and never
   inferred from how thorough the build looks; and **content depth**
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
4. **Lead with COVERAGE — of gates AND of triggers.** Two numbers, because they
   answer different questions and only one of them is usually asked.

   `Gates: <checked> checked · <not-checked> not checked · <not-measured> not measured`
   `Triggers fired: <list> · not fired: <list>`

   A GATE is a defect type — wrong contrast, missing spine slot, absent signature. A
   TRIGGER is the condition that SURFACES a fault: the viewport, the motion preference,
   the colour mode, the zoom level, the input device. Gate coverage can improve forever
   while the trigger set never changes, and every defect reachable only under an unfired
   trigger stays invisible no matter how careful the review was. Report both or the
   verdict over-claims.

   The default trigger set for a visual build is: **default viewport · narrow viewport ·
   200% zoom · light · dark · reduced-motion · forced-colours · keyboard-only**. Fire what
   you can and NAME what you did not — `template/craft-gates/gates.spec.ts` in this plugin
   runs the browser-driveable ones in about two seconds and is what to hand a project that
   has no suite. When a trigger cannot be fired, list it under `not fired`; never let an
   unfired trigger read as a clean result.

   When anything is unchecked the report says in one sentence WHICH inputs were
   missing. A sheet of `not checked` rows reads as a clean audit at a glance — it is the
   opposite, and coverage is what makes that visible. State plainly that an audit whose
   coverage is mostly unchecked is not a verdict on the build, only a verdict on what was
   available to check.

   **Dropped artifacts are a FINDING, not `not checked`.** Absent working files mean "no
   input" only when the build never ran the craft flow. When the target carries evidence
   that it DID — a provenance manifest at one of the licence gate's names, a section
   ledger, a token system with the flow's role tiers, or the user saying so — then missing
   `craft/offer-contract.md` or `craft/divergence-record.md` is a run that decided its
   contract and threw it away, which is the failure step 0 exists to prevent. Report it as
   one finding naming the missing file, and keep the gates that needed it as `not checked`
   underneath. Never fail a build that plainly never ran the flow.

   Then the consolidated pass/fail table: the craft gates from step 2, then the
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
