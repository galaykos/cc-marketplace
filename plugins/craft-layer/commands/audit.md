---
description: Audit a crafted web app's motion and asset gates, delegating a11y and performance to their owning tools
argument-hint: [path-or-scope]
---

Audit the craft gates for the target in `$ARGUMENTS` (if empty, ask which path or scope first). Load the
`motion-tiers` skill for the tier taxonomy and its budgets. This command MEASURES, RESOLVES and REPORTS;
the `craft-reviewer` agent owns the gate checks — dispatch to it, never restate its check list here.

1. **Detect what shipped.** Grep the scope for each animation tier's imports and entry points (Framer
   Motion/`motion`, anime.js, Three.js/R3F/`<canvas>`, sprite sheets, the Vector tier —
   `lottie-web`/`@lottiefiles/*`/`@dotlottie/*`/`@rive-app/*`, `.lottie`/`.riv`), the sibling engines
   (scroll-orchestration/Lenis, page-transitions/View Transitions, interaction-fx, physics-motion,
   webgl-effects), every shipped visual/font ASSET — committed files and third-party
   refs from source (absolute-URL `@font-face`/`@import`/`<link>`/`url()`/`<use href>`, inline
   `data:`/oversized `<svg>`, URL-fetched `.lottie`/`.riv`/`.glb`/font) — every `component-source:`
   marker, and the provenance manifest.

   If nothing animates but assets shipped, still run the asset/licence gates. Only when there is neither
   motion nor a shipped asset do you stop — and that stop covers the motion CEILING gates and asset gates
   ONLY. The offer-contract, content-depth and anti-sameness gates read page CONTENT, and the SIGNATURE
   gate is a motion FLOOR whose whole purpose is a build with too LITTLE motion, so all four run on a
   fully static build. Never report "nothing animates" as a clean motion table.

2. **MEASURE what the reviewer cannot.** It is Read/Grep/Glob and can see no byte size. You have Bash:
   collect the numbers its budget gates need and inject them as facts.

   - Per-asset gzipped and raw sizes for every sprite/image/font/3D/Lottie file; per-chunk gzipped size
     for the built bundle when a `dist/`/`build/` output exists.
   - **A scrubbed frame sequence** — caps in `${CLAUDE_PLUGIN_ROOT}/skills/motion-tiers/references/tier-budgets.md`,
     and nothing else checks them: TOTAL bytes across every frame (not the per-frame size, which always
     looks fine), the FRAME COUNT, and whether the poster frame ships EAGER — a real `<img>`, not lazy
     and not canvas-only, because it is the no-JS state and the LCP candidate. No sequence → nothing to
     measure, not a failure.
   - **CONTRAST RATIOS** — resolve the accent/ink/surface token values and compute WCAG
     relative-luminance ratios per pairing per theme. A value only resolvable at runtime is
     `not measured` for that pairing, never guessed.
   - **NARROW VIEWPORT**, if you can drive a browser. A body scrolling horizontally at phone width is a
     layout defect, and layout is this audit's job — not `/a11y:audit`'s and not `/performance:review`'s,
     so it otherwise falls between them and nobody checks it. Compare `document.body.scrollWidth` against
     `documentElement.clientWidth` and name the overflowing element; the usual cause is structural, a
     grid or flex item defaulting to `min-width: auto` so one wide child pushes the page instead of
     scrolling inside itself. Also read the copy for direction words a reflow makes false. No browser →
     `not measured`.
   - **THE SERVED HTML, not the browser's.** `curl -s <url>` — or the SSR/prerender output — must already
     contain the headline, body copy and primary CTA text. An SPA shell serves an empty root and fills it
     from JS, and every browser-run check passes anyway: perfect screenshot, complete a11y tree, green
     suite, page still blank to any crawler that does not execute JS.
     `curl -s <url> | grep -ci "<a distinctive headline word>"` returning 0 is a FAIL, not a note, and it
     fails the whole page. Configured is not running; only the response body settles it. No reachable
     URL → `not measured`.

   Anything unmeasurable — no build output, no toolchain, an unresolvable colour — is injected as
   `not measured` for that item, and the reviewer reports it that way rather than asserting a verdict.

3. **Resolve the persisted artifacts BY RUN STAMP.** Glob `**/craft/offer-contract.md`,
   `divergence-record.md`, `build-task.md`, `content-source.md`, `section-ledger.md` and
   `reference-board.md` across the project AND the session working area. **When a glob matches more than
   one file, never take the first hit.** Each opens with
   `Run: <instant> · <product-slug> · <absolute project root>`. Drop every match whose project field is
   not the target. One candidate left wins; several, and the strictly NEWEST instant wins, but only when
   the run's other artifacts carry that same stamp. Everything else — two sharing an instant, one stamped
   while a sibling is not, stamps disagreeing — is UNDECIDABLE: report `not checked (ambiguous craft
   artifacts: <n> matched — <path> <stamp>, …)`, list every candidate, grade nothing from any of them. A
   single unstamped candidate is used and reported `stamp absent (pre-stamp artifact)`. Disagreeing
   stamps are additionally ONE finding naming the file an earlier run left behind
   (`.../references/offer-contract.md` Part 8).

4. **RUN THE SCRIPT GATES — they are Bash, so they are yours, not the reviewer's.** Run them from the
   PLUGIN, never a copy: a vendored gate is a snapshot with no freshness signal, and a stale gate reports
   green with authority. `gates.spec.ts` costs `@playwright/test` + `@axe-core/playwright` + a Chromium
   download in the target's tree — install those only when the suite is actually going to run, this
   session, against a reachable server.

   ```
   cd <project> && CLAUDE_PLUGIN_ROOT=<craft-layer root> \
     CRAFT_CONTRACT=<…/craft/offer-contract.md> CRAFT_DIVERGENCE_RECORD=<…/craft/divergence-record.md> \
     CRAFT_BUILD_TASK=<…/craft/build-task.md> CRAFT_CONTENT_SOURCE=<…/craft/content-source.md> \
     CRAFT_TOKEN_SOURCE=<the CSS holding the tokens> \
     node ${CLAUDE_PLUGIN_ROOT}/template/craft-gates/divergence.mjs
   BASE_URL=<the dev server> CRAFT_EXPECT_TITLE=<the contract's product name> npx playwright test
   ```

   Pass the paths step 3 resolved: `divergence.mjs` resolves `craft/…` relative to the PROJECT ROOT while
   the craft flow persists to the run's working area — the session scratch on a project with no
   `taskmaster-docs/`, outside the project. Omit them and `spine-register` and `craft-stamp` both report
   `not checked` on the ordinary case, which reads as a clean run rather than an ungraded one.
   `CLAUDE_PLUGIN_ROOT` keeps both corpora live rather than the frozen snapshots it prints without it.
   `CRAFT_TOKEN_SOURCE` is required whenever the tokens are not where the gates look — `contrast.mjs`
   treats a missing token source as a FAILURE and three `divergence.mjs` assertions cannot resolve
   without it. `CRAFT_EXPECT_TITLE` is the only thing proving the server on that port is THIS build; the
   suite runs inside the target and cannot read the contract, and without it reports `IDENTITY NOT
   MEASURED` and captures anyway — carry that phrase into the `Visual:` line rather than dropping it.

   Carry the verdicts into the table: **exit 1 is a FINDING** to resolve or waive in
   `<project>/.craft-layer/waivers.json` with a reason · **exit 2 is `not measured`** · a gate never run
   is `not checked`. None of the three is a pass.

5. **CAPTURE and OPEN the images — at EVERY tier, not just a boosted run.** A DOM assertion proves an
   element exists, carries the right text and computes the right colour. It cannot see text running off
   its viewBox, two annotations landing on each other, or a fixed rail covering the column beneath —
   the defects a reader meets first and a query never meets at all. The suite writes two PNGs per
   breakpoint (390, 768, 1280, light and dark) into `<project>/.craft-layer/shots/`. READ each and
   describe what is visible, hunting: text CLIPPED at a container or viewBox edge, OVERLAPPING labels,
   truncation ellipses, fixed elements covering content, any element whose rendered position differs
   from where the markup implies. Inject the shot paths into step 6 so the reviewer opens them too.
   Anything found in an image IS a finding. **When a capture will not save, retry with an ABSOLUTE PATH
   inside an allowed root before concluding the capability is unavailable** — a tool that refuses one
   path is not a tool that cannot write. Only then `Visual: NOT CAPTURED (<reason>)`: reported, never
   blocking, never implied by silence.

6. **Dispatch `craft-reviewer`** with the step-2 measurements, the step-3 artifacts, the step-5 shot
   paths, and Read paths to the references its checks cite: `motion-tiers/references/tier-budgets.md` ·
   `creative-direction/references/` `sameness-fingerprint.md`, `content-depth.md`, `offer-contract.md`,
   `ambition-tiers.md`, `content-source.md`, `concept-deck.md`, `moves-taxonomy.md`, `type-strategy.md`,
   `register-corpus.md` · `scroll-orchestration/references/scroll-acts.md` ·
   `asset-sourcing/references/` `licence-discipline.md`, `component-sourcing.md` ·
   `section-decisions/references/section-ledger.md` plus the ledger when one exists · and, when the
   contract's archetype is `app/CRM` or the target has a logged-in data-dense half,
   `information-design/references/app-craft-floors.md`.

   The agent's prompt carries what it checks and what each missing input makes `not checked`. Two things
   this step still tells it: which artifacts resolved and which are absent with the reason, and that a
   missing input is `not checked` — never a pass, never a fail, never inferred from how the page reads.
   Collect its `path:line — severity — problem — fix` lines.

7. **Delegate what craft-layer does not own** — do not re-implement: full accessibility →
   `/a11y:audit $ARGUMENTS` (the accent-vs-surface contrast pre-check stays a craft gate; a11y owns the
   comprehensive pass); performance / Core Web Vitals → `/performance:review $ARGUMENTS`, skipped when
   the `performance` plugin is absent. Same scope, collect both verdicts.

8. **Report — lead with COVERAGE, of gates AND of triggers.**

   ```
   Gates: <n> checked · <n> not checked · <n> not measured
   Triggers fired: <list> · not fired: <list>
   Visual: <n> shots opened          (or: Visual: NOT CAPTURED (<reason>))
   ```

   A GATE is a defect type — wrong contrast, missing spine slot, absent signature. A TRIGGER is the
   condition that SURFACES a fault: viewport, motion preference, colour mode, zoom, input device. Gate
   coverage can improve forever while the trigger set never changes, and a defect reachable only under an
   unfired trigger stays invisible however careful the review was. The default set: **default viewport ·
   narrow viewport · 200% zoom · light · dark · reduced-motion · forced-colours · keyboard-only · capture
   at 390/768/1280**. Fire what you can and NAME what you did not.

   When anything is unchecked, say in one sentence WHICH inputs were missing. A sheet of `not checked`
   rows reads as a clean audit at a glance and is the opposite: an audit whose coverage is mostly
   unchecked is not a verdict on the build, only on what was available to check.

   **Dropped artifacts are a FINDING, not `not checked`.** Absent working files mean "no input" only when
   the build never ran the craft flow. When the target shows it DID — a provenance manifest, a section
   ledger, a token system with the flow's role tiers, or the user saying so — a missing contract,
   divergence record or build task is a run that decided its contract and threw it away. The build task
   belongs on that list for a sharper reason than symmetry: without it the signature gate and reach floor
   4 both report `not checked`, so a discarded build task is a floor waived by omission, the one waiver
   route the reach floors do not grant. One finding naming the missing file, with the gates that needed
   it `not checked` underneath. Never fail a build that plainly never ran the flow.

   **A green project suite is not this audit.** The likeliest failure is a build ending with the target's
   own tests, typecheck or lint passing and the run reading that as done. That proves the code is
   correct. It proves nothing about whether the signature shipped, the contract was honored, or the
   divergence record's claims are true of what was built.

   Then the consolidated table: craft gates, then the delegated results. Both delegates are STATIC
   reviews, not Lighthouse runs, so present Performance ≥ 90 / Accessibility ≥ 95 as the bar their
   findings are read against — never a measured score, never a hard CI gate. A row whose delegate was
   skipped or whose input was `not measured` says so. Order findings by severity and name the owning tool
   for each delegated line.

9. **Append the run log.** After the audit runs, append ONE row to `<project>/.craft-layer/run-log.md`
   (creating it with its header when missing) and trim to the last 5:
   `| date | brief-slug | hue-family | type-strategy | spine | signature | draw |`, where `draw` holds
   the five drawn deck options joined by ` / `. A row is appended only AFTER the audit runs, so a failed
   or abandoned run appends nothing; the trim keeps the memory a window, not an archive; a malformed log
   is treated as EMPTY and warned about, never fatal. This is what the next run's `draw-repeat` grades
   against — an unwritten row makes the next run repeat this one.

10. **Offer the fix.** When findings map to real files, offer it as an AskUserQuestion choice: "Fix the
    craft findings now" / "Report only". craft-layer ships no writer — both its agents are read-only —
    so route accepted fixes to `task-runner:task-executor` when installed, else `ui-ux:ui-ux-engineer`
    for markup/style/component work, else apply inline. Findings owned by a delegate go to that
    delegate's worker (`a11y:a11y-engineer`, `performance:performance-engineer`). Whichever worker you
    land on has no `Skill` tool: resolve its agent file first — several copies exist and they DISAGREE about which skills the worker names, so use the three-rung ladder in `orchestration:delegation-contracts` `references/skill-priming.md` § Resolving the AGENT file — then resolve each token of its `bestpractices-skill:` frontmatter to an
    installed `SKILL.md` and inject `Read <abs-path>` per hit into the dispatch, skipping misses.
    Then, for every craft skill THIS audit loaded that the
    head's frontmatter does NOT name, inject it too marked **supplementary**. No head here
    names one: `task-runner:task-executor` (first preference) declares nothing at all, and
    `ui-ux-engineer`/`a11y-engineer`/`performance-engineer` declare tokens that exclude
    every craft skill — so keyed on an EMPTY frontmatter this fires on one head and misses
    the other three, and the fixes are applied against none of the rubric they were judged by (`orchestration:delegation-contracts` § Skill priming). Headless: report only,
    and print the exact `/a11y:audit` and `/performance:review` commands to rerun.
