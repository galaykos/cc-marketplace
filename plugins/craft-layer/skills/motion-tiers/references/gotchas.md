# Motion tool-usage gotchas

Traps that break real builds — how to wield the tools, not what to design. Each is a
bug that costs uniqueness or accessibility, not a style rule.

## Gradient text on split letters → invisible

`background-clip: text` + `color: transparent` on a word whose letters are separate
child spans: the children inherit `transparent` but carry NO gradient of their own, so
they paint nothing — the word vanishes. Fix: keep the gradient word as ONE element
(still animatable as a single unit), or apply the gradient to each glyph span. Never
split a `bg-clip:text` word into transparent children.

## whileInView / scroll-reveal → hidden until observed

An element that starts at `opacity: 0` and only reveals via an IntersectionObserver
(`whileInView`, custom reveal hooks) stays invisible whenever the observer never fires:
no-JS, an SSG/prerender snapshot, print, a full-page screenshot, an in-view-on-load
race, or a crawler that does not scroll. Fix: guarantee a visible fallback — start from
`opacity: 1` and only hide when JS is confirmed (e.g. a `js-ready` class on `<html>`),
or pair `viewport={{ once: true, amount: 0.2 }}` with a safety timeout that clears the
hidden state. The content must be readable with the animation stripped out.

## Split-text headings → screen-reader letter soup

Splitting a heading into per-letter or per-word spans makes assistive tech announce it
character-by-character ("B u i l d"). Fix: put the real phrase on the container's
`aria-label` and mark every split span `aria-hidden="true"`.

## One writer per property

Two tiers — or two libraries — animating the same `transform` / `opacity` on one
element fight each frame and jank. Pick a single owner per property per element; if a
handoff is needed, have one release before the other takes over.

## Scroll-linked motion without a smooth-scroll contract

Mixing native scroll, a smooth-scroll library, and scroll-driven animation with no
single source of truth causes drift and jitter (the animation reads one scroll position,
the page uses another). Choose ONE contract: native scroll + CSS scroll-driven
animations, or one smooth-scroll lib feeding one animation engine — never both at once.

## SPA route change desyncs smooth scroll from native scroll

On a client-side navigation, a collapsing layout — most often a pinned ScrollTrigger's
pin-spacer disappearing when the old route unmounts — leaves the native scroll position
and the smooth-scroll library's internal position disagreeing (native at 320px, the lib
at 0). The next scroll jumps, or the new page lands mid-content. Fix: on every route
change, inside a `requestAnimationFrame` AFTER the new route has laid out, hard-reset
native scroll (`window.scrollTo(0, 0)`) AND force-resync the smooth-scroll instance
(`lenis.scrollTo(0, { immediate: true, force: true })`), THEN call
`ScrollTrigger.refresh()` so pins recompute against the new document height. Resetting
only one of the two positions is the trap — they must be reset together.
