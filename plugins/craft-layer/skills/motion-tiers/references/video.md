# Background video — the playback contract

> Last verified: 2026-09-26 — https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/video

The ONE owner of how a background or decorative `<video>` plays: a hero loop, a video
tile, footage behind type. Neighbours keep their own halves and point here:
`sprite.md` owns the sheet-vs-video crossover (when a clip stops being a sprite);
`plugins/craft-layer/skills/asset-sourcing/SKILL.md` owns where the footage comes from
and its licence. A video that carries information (a demo, a talk) needs captions and
real controls — that is `/ui-ux:audit`'s media contract, not this file.

## Markup

```html
<video autoplay muted loop playsinline preload="metadata"
       poster="hero.avif" width="1600" height="900" aria-hidden="true">
  <source src="hero.webm" type="video/webm">
  <source src="hero.mp4" type="video/mp4">
</video>
```

- **`muted`** is what lets autoplay through: browsers block audible autoplay, and media
  with no audio track or a muted one is exempt. Ship decorative footage with no audio
  track at all.
- **`playsinline`** is required for inline autoplay in iOS Safari.
- `play()` returns a promise. On `NotAllowedError`, keep the poster and show a play
  control; never retry in a loop.
- `aria-hidden="true"` only when the video is pure decoration; the words it sits behind
  are real DOM text.

## Poster and LCP

- Always a poster, sized to the box (`width` / `height` or `aspect-ratio`) so nothing
  shifts. It is the reduced-motion state, the Save-Data state and the failure state.
- For LCP a `<video>` counts at the EARLIER of poster load and first-frame paint
  (web.dev). A hero video's poster is therefore the LCP image: AVIF/WebP, compressed like
  any hero image, fetched early.

## Preload policy

- The default `preload` differs by browser (the spec advises `metadata`), so set it.
- Hero, above the fold: autoplay fetches the file anyway; keep the poster cheap and the
  encode short.
- Below the fold: `preload="none"` and attach the `src` (or call `load()`) from an
  `IntersectionObserver` as it nears the viewport. `loading="lazy"` on `<video>` is
  Chromium-only (Chrome 150), so do not rely on it alone.
- Pause when out of view and when `document.hidden`; resume on return.

## Pause control and reduced motion

- A loop running past five seconds beside other content needs a visible, labelled,
  keyboard-reachable pause/play button (WCAG 2.2.2) — for every user, whatever their OS
  setting (`../SKILL.md`). Remember the choice for the session.
- Under `prefers-reduced-motion: reduce`, do not autoplay: render without `autoplay` or
  pause on a SUBSCRIBED media query (see `vector.md`), and show the poster. The play
  control still works — the user may choose motion.

## Encode

- WebM (VP9 or AV1) first, MP4 (H.264) as the fallback `<source>`; trim to the shortest
  loop that reads; no audio track for decoration.
- Text over footage: check contrast against the brightest frame, or add a scrim.

Standing: mostly recorded. One case is gated: the craft-gates reduced-motion pass
(`plugins/craft-layer/template/craft-gates/gates.spec.ts`, run by `/craft-layer:audit`)
fails a video still playing a loop under reduced motion with no controls and no pause
button nearby. Poster, preload, LCP and encode are read back by nothing.
