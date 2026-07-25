# Sequencing patterns — theatre.js core, scroll drive, camera sync, editor export

> **Last verified: 2026-07-25 — and the news is bad.** theatre.js's latest public
> release is v0.7.0 (August 2023); its README says active development moved to a
> private repo pending a 1.0 that has not shipped, and package advisors mark it
> inactive. The mechanics below are still correct; the DEPENDENCY may not be. Read
> the maintenance gate in `../SKILL.md` before adopting, and re-check the release
> state — this note is a snapshot, not a verdict.

Read on demand from the motion-sequencing SKILL. GSAP timeline/tween mechanics are NOT
re-taught here — they live in `plugins/ui-ux/skills/motion-best-practices/references/gsap.md`.
Scroll progress comes from `plugins/craft-layer/skills/scroll-orchestration/SKILL.md`; 3D
scene/camera rules from `plugins/threejs/skills/threejs-best-practices/SKILL.md`. This file
is the theatre.js how-to.

## The @theatre/core model

- A `project` holds one or more `sheets`; a sheet holds `sheetObject`s; each object
  declares the props it animates (numbers, colors, vectors) with default values. theatre
  stores keyframes and gives you interpolated values.
- Read values via `onValuesChange(obj, (v) => { ... })` and write them to DOM transforms,
  a three.js camera, or shader uniforms in that callback. Keep one subscription per object.
- Position: a `sequence` per sheet has a `position` (seconds). Move it to scrub the whole
  multi-track sequence at once.

## Driving position

- **Time:** `sheet.sequence.play({ range, iterationCount })` on load or on enter — intros,
  loader→hero assembly, ambient loops.
- **Scroll:** set `sheet.sequence.position = progress * duration` where `progress` is the
  smoothed 0..1 from scroll-orchestration. Do NOT add a second scroll listener — read the
  progress it already produces so both agree (its single-scroll contract).

## Syncing a three.js camera

- Declare camera props (`position` x/y/z, `lookAt`, `fov`) on a sheet object; in the
  values callback, apply them to the three.js camera each frame. The render loop, renderer,
  and disposal are threejs-best-practices — this only feeds the camera values.

## Editor → runtime workflow (studio is dev-only)

- In development: `import studio from '@theatre/studio'; studio.initialize()` — tune the
  sequence visually, then `studio` lets you export the project state to JSON.
- Commit the exported JSON and load it in production via `getProject(name, { state })`.
- Guard the studio import so it is stripped from prod, e.g. `if (import.meta.env.DEV) {
  const studio = (await import('@theatre/studio')).default; studio.initialize() }` — the
  dynamic, dev-gated import lets the bundler drop it. Production ships `@theatre/core` +
  the JSON only.

## reduced-motion (defer, don't restate)

- The SKILL owns the mandate: under `prefers-reduced-motion: reduce`, set
  `sequence.position` to the END (final pose) and never play/scrub. This file only notes
  that the final position is the reduced state.

## Verify

- `@theatre/studio` is imported only under a dev guard and absent from the prod bundle.
- The sequence is driven by ONE source (time or scroll-orchestration progress), not a
  second scroll loop.
- Reduced-motion lands on the final position; 3D disposal follows threejs-best-practices.
