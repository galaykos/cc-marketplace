---
name: a11y-audit
description: "Use when writing or reviewing UI markup, styles, or interactions — a WCAG 2.2 AA checklist covering semantics, contrast, keyboard access, focus, forms, media, and the ARIA rules that prevent well-meant attributes from making things worse."
---

# Accessibility Audit (WCAG 2.2 AA)

## Core rule

Accessibility is a correctness property, not polish. A keyboard trap is a
blocker bug for the user it traps — for them the feature does not work at
all. Treat findings with the same severity as functional defects:
blockers block the merge, minors get an owner and a follow-up, and none
get waved off as "nice to have".

## Semantics first

Native elements before ARIA. The browser ships focus handling, keyboard
activation, and screen-reader semantics with every native control; a
rebuilt `div` ships none of them.

- `button` for actions — never a `div` with an onclick handler.
- `a` with an `href` for navigation. No destination means it is a button.
- Heading hierarchy without skips: h1, then h2, then h3. Never pick a
  heading level for its font size — style the correct level instead.
- Landmarks: exactly one `main`; `nav` around navigation blocks;
  `header` and `footer` where they apply.
- Lists as lists: `ul`/`ol`/`li` for anything that reads as a sequence.
- Tables with `th` and `scope` for data only, never for layout.

## First rule of ARIA

Don't use ARIA when a native element exists — no ARIA beats bad ARIA.

- `aria-*` on the wrong role is worse than nothing: it makes confident
  false promises to assistive technology.
- `aria-label` only when visible text cannot serve; when visible text
  exists, the accessible name must contain it.
- `aria-hidden` never on a focusable element — it creates a ghost tab
  stop that receives focus but announces nothing.

## Keyboard

Every interactive element must be reachable and operable by keyboard
alone.

- Tab reaches it; Enter/Space activates it; Escape dismisses overlays;
  arrow keys where convention demands them (menus, tabs, radio groups).
- No positive `tabindex`. Use `0` to join the natural order, `-1` for
  programmatic focus, and fix DOM order instead of reordering with it.
- Visible focus indicator on every focusable element. `outline: none`
  without an equally visible replacement is a violation, not a style.
- No keyboard traps. Modals must do both halves: contain focus while
  open AND release it on close.

## Focus management

- On route or view change, move focus to the new content or its heading —
  otherwise keyboard users are stranded on a stale element.
- On modal open, focus enters the dialog; on close, it returns to the
  element that triggered it.
- Provide a skip link so keyboard users can bypass repeated navigation.
- Focused element stays visible: sticky headers, toolbars, and other
  overlays must not fully cover it (SC 2.4.11 Focus Not Obscured); an
  indicator must exist and be visible (SC 2.4.7). A prominent indicator
  (Focus Appearance, SC 2.4.13) is AAA — recommend, never flag at AA.

## Contrast (AA)

- 4.5:1 for body text.
- 3:1 for large text (at least 24px, or 19px bold) and for UI components
  and graphical objects — input borders, icons, focus rings, chart lines.
- Check every state: hover, focus, active, disabled, placeholder, and
  text over images or gradients.
- Never color as the only signal. An error is red AND has an icon or
  text; a link in prose is colored AND underlined.

## Forms

- Every input has a programmatic label: `label for=` or, when a visible
  label genuinely cannot exist, `aria-label`.
- Errors are announced and associated: link the message with
  `aria-describedby` and flag the field with `aria-invalid`.
- Required is conveyed programmatically (the `required` attribute), not
  only by an asterisk in the visual label.
- No placeholder-as-label. Placeholders vanish on input and usually fail
  contrast; they supplement a label, never replace it.
- Redundant entry: never force re-typing of information already given
  in the same flow — auto-populate it or offer it back (SC 3.3.7).
- Accessible authentication: login must not hinge on a cognitive test —
  allow paste and password managers, no transcription puzzles (SC 3.3.8).

## Media and images

- Alt text serves the image's purpose in context — what it means, not
  what it looks like. Decorative images get empty `alt=""` so screen
  readers skip them.
- Captions for video with speech.
- No autoplaying audio.
- Respect `prefers-reduced-motion`: gate non-essential animation,
  parallax, and auto-advancing carousels behind the media query.

## Touch and pointer

- Target size: 24×24 CSS px is the 2.2 AA floor (SC 2.5.8) — a
  minimum, not the goal. Keep 44px in both dimensions, padding
  included, as the recommended target; the floor does not replace it.
- Dragging movements: every drag — reorder, slider, drawing — has a
  single-pointer alternative that works without dragging (SC 2.5.7).
- Every gesture (swipe, pinch) has a single-pointer alternative —
  visible controls that do the same thing.

## Consistent help

- Help mechanisms — contact link, chat, FAQ — sit in the same relative
  place on every page that offers them (SC 3.2.6).

## Worked micro-example

An icon-only delete button in a list row needs all of:

    <button type="button" aria-label="Delete item">
      <svg aria-hidden="true">…</svg>
    </button>

- `type="button"` so it never submits an enclosing form.
- `aria-label="Delete item"` because there is no visible text.
- A visible focus style (the default outline or a styled replacement).
- A confirm dialog that traps focus while open and returns focus to the
  triggering button on close — deletion is destructive, and a stray
  Enter from an invisible focus position must not destroy data.

## Boundaries

- General visual and layout review belongs to /ui-ux:review and the
  ui-ux plugin's agents; ui-ux-engineer implements the fixes. This skill
  owns the WCAG audit itself.
- Automated tooling (axe, Lighthouse) complements this checklist — a
  clean axe run is necessary, not sufficient. Tools cannot judge alt-text
  quality, focus-order sanity, or whether a label makes sense.

## Anti-patterns

- ARIA-sprinkling to silence linters — attributes added without checking
  the role they land on.
- `outline: none` with no replacement focus style.
- Div soup with click handlers standing in for buttons and links.
- Contrast fixed only on the default state, with hover, focus, and
  disabled states forgotten.
- `alt="image"`, `alt="photo"`, or the filename as alt text.
