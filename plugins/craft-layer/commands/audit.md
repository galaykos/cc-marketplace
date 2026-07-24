---
description: Audit a crafted web app's motion and asset gates, delegating a11y and performance to their owning tools
argument-hint: [path-or-scope]
---

Audit the craft gates for the target in $ARGUMENTS (if empty, ask which path or
scope to audit first). Load the `motion-tiers` skill from this plugin for the tier
taxonomy and its per-tier budgets, then:

1. Detect what the target uses: grep the scope for each animation tier's imports and
   entry points — Framer Motion / `motion`, anime.js, Three.js / R3F / `<canvas>`,
   and sprite sheets — plus any 3D/WebGL surface. List the tier(s) and surface(s)
   found; if none animate, say so and stop.
2. Run the craft-specific gates by dispatching the findings to the `craft-reviewer`
   agent from this plugin. Inject the Read path to `../skills/motion-tiers` so it
   checks against the authoritative budgets, and have it verify: every tier in use
   honors `prefers-reduced-motion`; each 3D/WebGL surface is lazy-loaded with a
   static fallback; each tier is within its per-tier budget from `motion-tiers`; and
   sprites/assets stay within their size budget. Collect its `path:line — severity —
   problem — fix` lines.
3. Delegate the checks craft-layer does not own — do not re-implement them:
   accessibility → `/a11y:audit $ARGUMENTS`; performance / Lighthouse / Core Web
   Vitals → `/performance:review $ARGUMENTS`. Run each against the same scope and
   collect their verdicts.
4. Report one consolidated pass/fail table: the craft gates from step 2, then the
   delegated results from step 3 presented against their audited TARGETS —
   Lighthouse Performance ≥ 90 and Accessibility ≥ 95. Frame these as targets the
   audit measures, not hard CI gates. Order findings by severity and name the owning
   tool for each delegated line.
5. When findings map to real files, offer the fix as a selectable choice
   (AskUserQuestion): "Route craft findings to craft-layer now" / "Report only".
   Headless: report only and print the exact `/a11y:audit` and `/performance:review`
   commands to rerun.
