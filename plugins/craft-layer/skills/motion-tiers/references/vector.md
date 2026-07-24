# Tier 5 — Vector (Lottie / Rive)

Designer-authored vector motion: the animation is produced in a design tool and
shipped as an asset the runtime plays, instead of being hand-coded property by
property. Reach for it when a designer has already authored the motion, or when the
same result would be expensive to reproduce in Framer Motion / anime.js.

## Lottie vs Rive — the decision

| | **Lottie** | **Rive** |
| --- | --- | --- |
| Package | `@lottiefiles/dotlottie-react` | `@rive-app/react-canvas` |
| Asset | `.lottie` (or `.json`) | `.riv` |
| Model | **Timeline playback** — plays / loops / segments a fixed sequence | **Interactive state-machine** — inputs drive transitions between states |
| Renderer | SVG / Canvas | Canvas (WebGL/WASM runtime) |
| Choose when | Hero loops, illustrative icons, onboarding sequences, decorative motion that just plays | Cursor / hover / scroll / data-driven motion, toggles, characters that respond to inputs |

Rule of thumb: if the motion only ever **plays**, use Lottie; if the motion must
**react** to state or user input, use Rive's state-machine. Do not build a Rive
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
  the playback engine; `@rive-app/react-canvas` ships a WASM runtime. Neither the player
  nor the asset belongs in the initial bundle for below-the-fold or non-critical motion.
- **Main-thread cost** — Canvas rendering and complex vector scenes cost CPU/GPU each
  frame. Keep scenes simple, pause when offscreen (`IntersectionObserver`), and prefer
  the dotLottie Web Worker path when playing multiple animations.

## prefers-reduced-motion path

Movement must be removable. Gate before playing:

```js
const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
```

- **Reduced motion = a static poster frame.** Do not autoplay. Render a single frame
  (the export's poster / first frame, or a stopped player) so the surface still carries
  its meaning without motion.
- Lottie: mount with `autoplay={false}` and seek to the poster frame, or swap in the
  poster image; do not loop.
- Rive: hold the state-machine on its resting state — do not fire the inputs that drive
  the animation.
- This is an accessibility requirement, not polish. `motion-best-practices` owns the CSS
  kill-switch idioms.

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
- Rive (React): `@rive-app/react-canvas` (Canvas runtime + state-machine).
- Framework-neutral cores exist (`@lottiefiles/dotlottie-web`, `@rive-app/canvas`) for
  non-React stacks; bind per the stack in `references/framework-bindings.md`.
