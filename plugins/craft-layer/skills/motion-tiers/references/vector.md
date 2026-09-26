# Tier 5 — Vector (Lottie / Rive)

> Last verified: 2026-09-26 — https://rive.app/docs/runtimes/choose-a-renderer/overview — npm:@rive-app/react-webgl2@4
>
> Package names, the Rive renderer pick and data binding. The runtime SIZES that decide
> a tier live in `tier-budgets.md`; re-verify there.

Designer-authored vector motion: the animation is produced in a design tool and
shipped as an asset the runtime plays, instead of being hand-coded property by
property. Reach for it when a designer has already authored the motion, or when the
same result would be expensive to reproduce in Framer Motion / anime.js.

## Lottie vs Rive — the decision

| | **Lottie** | **Rive** |
| --- | --- | --- |
| Package | `@lottiefiles/dotlottie-react` | `@rive-app/react-webgl2` (default); `@rive-app/react-canvas` for several instances on screen |
| Asset | `.lottie` (or `.json`) | `.riv` |
| Model | **Timeline playback** — plays / loops / segments a fixed sequence | **Interactive state-machine** — data-bound view-model properties drive transitions between states |
| Renderer | SVG / Canvas | WASM runtime; `webgl2` draws with the Rive Renderer, `canvas` with Canvas2D |
| Choose when | Hero loops, illustrative icons, onboarding sequences, decorative motion that just plays | Cursor / hover / scroll / data-driven motion, toggles, characters that respond to user input |

Rule of thumb: if the motion only ever **plays**, use Lottie; if the motion must
**respond** to state or user input, use Rive's state-machine. Do not build a Rive
state-machine for motion that a Lottie timeline covers — it costs bundle and authoring
time for no interaction.

`.lottie` (dotLottie) is the preferred Lottie container: it is a zipped bundle,
smaller than raw `.json`, and can hold multiple animations + themes.

## Budget

- **Asset size** — treat the `.lottie` / `.riv` file as an image-class asset: keep it
  small, measure it, and record the KB per surface like every other tier. Optimize the
  export (drop hidden layers, reduce keyframes, avoid huge embedded raster/expressions);
  a bloated Lottie JSON is a common regression.
- **Runtime** — the player itself is a dependency. `@lottiefiles/dotlottie-react` runs
  the playback engine; every Rive package ships a WASM runtime, and the `tier-budgets.md`
  figure is measured on `@rive-app/canvas` — measure the package you install and record
  it there. Neither the player
  nor the asset belongs in the initial bundle for below-the-fold or non-critical motion.
- **Main-thread cost** — Canvas rendering and complex vector scenes cost CPU/GPU each
  frame. Keep scenes simple, pause when offscreen (`IntersectionObserver`), and prefer
  the dotLottie Web Worker path when playing multiple animations.

## prefers-reduced-motion path

Movement must be removable, and the preference can change while the page is open — so
SUBSCRIBE to the media query; a one-time `.matches` read at mount misses the change:

```js
const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
const apply = () => (mq.matches ? holdPoster() : play());
apply();
mq.addEventListener("change", apply); // remove it on unmount
```

- **Reduced motion = a static poster frame.** Do not autoplay. Render a single frame
  (the export's poster / first frame, or a stopped player) so the surface still carries
  its meaning without motion.
- Lottie: mount with `autoplay={false}` and seek to the poster frame, or swap in the
  poster image; do not loop.
- Rive: hold the state machine on its resting state — do not set the view-model
  properties or fire the triggers that drive the animation. Rive's React docs say to use
  **data binding** for new work (`useViewModelInstance` plus the typed
  `useViewModelInstanceBoolean` / `Number` / `Trigger` hooks); state machine inputs "will
  be removed in a future major version", so do not build on them. Standing: recorded.
- This is an accessibility requirement, not polish. `motion-best-practices` owns the CSS
  kill-switch idioms.
- A loop running past five seconds also needs a visible pause control, whatever the
  preference (`../SKILL.md`, the pause rule under the two fallbacks).

## reduced-bundle path (poster + lazy)

The default initial render is a **poster image**, not the vector asset:

1. Ship a lightweight poster image (a WebP/AVIF still of the animation) as the initial,
   in-bundle render — fast first paint, no player, no asset.
2. **Lazy-load** the player runtime and the `.lottie` / `.riv` asset only when the
   surface matters: on viewport entry (`IntersectionObserver` / `whileInView`), on
   interaction, or after idle. Code-split the player so its KB never lands in the
   initial bundle.
3. Cross-fade the live vector over the poster once it is ready; if the asset never
   loads (slow network, save-data), the poster is the graceful final state.

A "reduced-bundle" path that still ships the full player + asset up front is not a
reduced-bundle path — measure it.

## Packages (pin at author time)

- Lottie (React): `@lottiefiles/dotlottie-react` (dotLottie player).
- Rive (React): `@rive-app/react-webgl2` — Rive's recommended pick, the Rive Renderer,
  so everything authorable in the editor renders (vector feathering included).
  `@rive-app/react-canvas` when several Rive instances share a screen or a slightly
  smaller package matters; `react-canvas-lite` only for files with no text, layouts,
  scripting or audio. The packages share one API, so switching is cheap.
- Framework-neutral cores exist (`@lottiefiles/dotlottie-web`, `@rive-app/webgl2`,
  `@rive-app/canvas`) for non-React stacks; bind per the stack in
  `references/framework-bindings.md`.
