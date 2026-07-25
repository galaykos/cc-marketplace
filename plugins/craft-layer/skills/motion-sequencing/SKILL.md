---
name: motion-sequencing
description: Use when a surface needs a complex multi-track sequence — many elements or a 3D camera on one timeline, or a production a designer tunes in a visual editor — beyond a single tween or scrub a GSAP timeline handles. Decides GSAP-timeline vs theatre.js, builds declarative sheets driven by time or scroll progress, keeps the @theatre/studio editor out of production, and mandates a reduced-motion jump-to-final; references gsap.md, scroll-orchestration, and threejs-best-practices by path.
---

## What this decides

This skill decides WHETHER a sequence needs a declarative multi-track timeline (and a
visual editor) versus a code-only GSAP timeline — and how to run one within budget. It
does NOT re-teach timeline/tween mechanics: GSAP `timeline()`, tweens, and easing live in
`plugins/ui-ux/skills/motion-best-practices/references/gsap.md`. Reference it, never copy.

**Reconciliation:** GSAP timelines (gsap.md) own simple, code-authored sequencing;
`plugins/craft-layer/skills/scroll-orchestration/SKILL.md` owns the scroll scrub itself.
This skill owns COMPLEX, multi-track choreography authored as declarative sheets — many
objects on precise beats, a designer tuning it in an editor, or a 3D camera + scene + DOM
synced on ONE timeline. theatre.js is the tool; it needs its library (`@theatre/core`),
so native-first does not apply.

## Decide: does the sequence need a multi-track timeline?

Answer before adding anything; take the first that fits:

1. One tween, or one property scrubbed on scroll → **gsap.md** (or CSS); not this.
2. A handful of coordinated elements you can express in code → a **GSAP timeline**
   (gsap.md), still not this.
3. A multi-track production — many objects on precise beats, or a designer needs to tune
   timing in a visual editor → **theatre.js declarative sheets.**
4. A 3D **camera + scene + DOM** that must move together on one timeline → theatre.js
   driving the three.js camera (threejs-best-practices) alongside DOM props.

If the sequence reads the same when simplified to two or three tweens, keep it in a GSAP
timeline — a sheet + editor is overhead you have not earned.

## Maintenance gate — check before adopting theatre.js

theatre.js is the right SHAPE for options 3 and 4 and has no equivalent, but it is not a
safe default: its last public release is v0.7.0 (August 2023), its README states active
development moved to a private repo pending a 1.0 that has not shipped, and package
advisors mark it inactive. Adopting an unmaintained runtime is a decision, so make it
explicitly:

- Re-check the release state at adoption time — this note is a snapshot, not a verdict.
  `references/sequencing-patterns.md` carries the `Last verified:` date for it.
- Options 1 and 2 (GSAP timeline) are the default whenever they can express the sequence;
  escalate to a sheet only when the visual editor or the DOM+3D-camera sync is the actual
  requirement, not when it is merely tidier.
- Adopt it only where the exported state JSON is the durable artefact and the runtime is
  replaceable — the sheet's keyframes must survive swapping the player for a GSAP
  timeline. Never let theatre.js own state nothing else can read.

## Declarative sheets (the runtime)

- `@theatre/core` models a project → sheet → object → keyed props. You declare the props
  an object animates; theatre stores the keyframes and gives you the interpolated values
  each frame. Wire those values to DOM transforms, a three.js camera, or shader uniforms.
- Scope sheets to a surface; one sequence driver. Ship the exported state JSON, not the
  editor. Model + keying detail: `references/sequencing-patterns.md`.

## Driving the sequence — time or scroll

- **Time**: play the sequence position on load / on enter (an intro, a loader→hero
  assembly).
- **Scroll**: bind the sequence position to scroll progress from
  `scroll-orchestration` — do NOT start a second scroll loop; consume the smoothed
  progress it already produces (its single-scroll contract). This is how you get
  scrollytelling with many synced tracks.

## The editor → runtime workflow

- `@theatre/studio` is the visual editor: import it in DEV ONLY, tune the sequence, export
  the state, and commit the exported JSON. Production imports `@theatre/core` + that JSON —
  never the studio. Guard the studio import behind a dev check so bundlers tree-shake it.
- The exported JSON is the source of truth for timing — treat it like committed config, not
  a generated artifact, so a designer's tuning survives rebuilds. Export detail:
  `references/sequencing-patterns.md`.

## Common shapes

Concrete surfaces this unlocks (each still respects the budget + reduced-motion below):

- **Cinematic scrollytelling** — many elements + a 3D camera advancing on one scroll-driven
  timeline (a product story told in chapters as you scroll).
- **Guided 3D tour / reveal** — camera moves between framed views synced with captions and
  UI, all on one sequence.
- **Orchestrated intro** — a loader that hands off to a hero assembling itself, precise
  beats a hand-coded timeline would be brittle to maintain.
- **Designer-tuned campaign** — a high-production landing where a designer tunes timing in
  the editor and exports, without touching code.

## prefers-reduced-motion (mandatory)

- Under `matchMedia('(prefers-reduced-motion: reduce)')`: do NOT auto-play or scroll-scrub
  the sequence — set it to its FINAL state (the end pose) so the surface reads complete and
  still. Gate the play/scrub start behind the query; honour runtime changes.

## Perf budget

- `@theatre/studio` MUST be excluded from the production bundle (dev-only import) — shipping
  it is a large, needless payload. Ship `@theatre/core` + exported JSON only.
- One sequence driver; scope sheets; pause off-screen. For 3D, the render/disposal rules
  are threejs-best-practices, not restated here.

## References

- `references/sequencing-patterns.md` — the `@theatre/core` project/sheet/object model,
  keying, driving position from time or scroll, syncing a three.js camera, and the
  dev-only studio export workflow.
- GSAP timelines/tweens: `plugins/ui-ux/skills/motion-best-practices/references/gsap.md`.
- Scroll progress driver: `plugins/craft-layer/skills/scroll-orchestration/SKILL.md`.
- 3D camera/scene it drives: `plugins/threejs/skills/threejs-best-practices/SKILL.md`.

## Anti-patterns

- **theatre.js for one tween** — a sheet + editor for what a GSAP timeline or CSS does.
- **Shipping @theatre/studio** — the editor in the production bundle; dev-only import only.
- **A second scroll loop** — driving the sequence from its own scroll listener instead of
  scroll-orchestration's smoothed progress (two scroll positions drift).
- **No reduced-motion jump-to-final** — an auto-playing/scrubbed sequence with no reduced
  path; reduced users must land on the end state, not watch it play.
- **Re-teaching GSAP timelines** here instead of referencing gsap.md.
