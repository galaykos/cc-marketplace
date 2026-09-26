---
name: a11y-audit
description: Use when writing or reviewing UI markup, styles, or interactions — a WCAG 2.2 AA checklist: semantics, contrast, keyboard access, focus, forms, media, and the ARIA rules that prevent well-meant attributes from making things worse.
---

> Last verified: 2026-09-26 — https://www.w3.org/WAI/WCAG22/Understanding/

# Accessibility Audit (WCAG 2.2 AA)

## Core rule

Accessibility is a correctness property, not polish: a keyboard trap is a
blocker bug for the user it traps. Findings carry the same severity as
functional defects — blockers block the merge, minors get an owner.

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
- `type="button"` on any `button` inside a form that is not the submit; an
  icon-only one needs `aria-label` and an `aria-hidden="true"` glyph.
- `lang` on `<html>`, and on any passage in another language (SC 3.1.1,
  3.1.2) — without it a screen reader reads French copy with English phonemes.

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

- Tab reaches it; Enter/Space activates it; Escape dismisses overlays.
- **A composite role is a contract.** `radiogroup`, `tablist`, `listbox`,
  `menu`, `tree`, `combobox` commit you to the APG keyboard pattern AND
  roving tabindex — one child tabbable (`0` on the active, `-1` on the
  rest), arrows moving between them. Tab-through-every-child with no
  arrow handling is not partial, it is false: the role promises a pattern
  the widget lacks. Ship the whole pattern or drop the role for buttons.
- Focusable but not actionable is a defect. `tabindex="0"` on a `span`
  with no role and no Enter/Space behaviour adds a stop that announces as
  text and leads nowhere, burying the route to the real action.
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
- Focused element stays visible: sticky headers and overlays must not
  fully cover it (SC 2.4.11); the indicator must exist and be visible
  (SC 2.4.7). Focus Appearance (SC 2.4.13) is AAA — never flag at AA.
- Content shown on hover or focus (tooltip, popover) owes all three:
  dismissible without moving the pointer, hoverable, and persistent until
  dismissed or invalid (SC 1.4.13).

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
- Help mechanisms — contact link, chat, FAQ — sit in the same relative
  place on every page that offers them (SC 3.2.6).
- `autocomplete` on every input collecting the user's OWN data, and only a
  token from the WCAG list (`name`, `email`, `tel`, `street-address`,
  `cc-number`, `current-password`) — an invented one is treated as `off` (SC 1.3.5).

## Status messages (SC 4.1.3)

- A message that appears without moving focus — toast, "Saved", result count,
  async done/failed — is announced only by `role="status"` (or
  `aria-live="polite"`) on a container ALREADY in the DOM; injecting region and
  text together announces nothing in most screen readers.
- `role="alert"` / `aria-live="assertive"` only for an error that interrupts.

## Media and images

- Alt text serves the image's purpose in context — what it means, not
  what it looks like. Decorative images get empty `alt=""` so screen
  readers skip them.
- Captions for video with speech; no autoplaying audio.
- Respect `prefers-reduced-motion`: gate non-essential animation,
  parallax, and auto-advancing carousels behind the media query.
- **Pause, stop, hide (SC 2.2.2, Level A).** Anything that starts on its own, moves, blinks or scrolls
  for more than 5 s beside other content — carousel autoplay, a logo marquee, a looping hero animation,
  rotating words — needs a visible pause or stop control for EVERY user, independent of
  `prefers-reduced-motion`. Pausing only while hovered or focused does not count: it restarts when
  focus leaves. Standing: recorded.

## Touch and pointer

- Target size: 24×24 CSS px is the 2.2 AA floor (SC 2.5.8) — a
  minimum, not the goal. Keep 44px in both dimensions, padding
  included, as the recommended target; the floor does not replace it.
- Every drag (reorder, slider, drawing) and every gesture (swipe, pinch)
  has a single-pointer alternative — visible controls doing the same job
  without dragging or tracing a path (SC 2.5.7). Keyboard access alone
  does not satisfy this; pointer users need the non-dragging route too.

## App widgets a mouse walk and axe both pass

Standing: recorded — each is a contract the default build breaks while axe and a mouse walk stay
green; `/ui-ux:audit` grades it, no script does.

- **Keyboard drag-and-drop.** Space picks up, arrows move, Space drops, Escape cancels and restores.
  Announce each step with the item's visible label and position ("Acme moved to Won, 2 of 5"), never
  an internal id — library defaults read the id. Focus stays on the moved item. SC 2.5.7 still wants
  the pointer route above: a visible "Move to…" control.
- **Tree and treegrid.** Parent rows carry `aria-expanded`; when the whole set is not in the DOM (lazy
  children, virtualized), every row carries `aria-level`, `aria-setsize`, `aria-posinset`. One tab stop.
- **Virtualized grids.** `aria-rowcount` on the grid is the true total (`-1` if unknown) and
  `aria-rowindex` on each rendered row its real position. Keep the focused row mounted when it scrolls
  out of the render window, or focus falls to `body`.
- **Sortable columns.** `aria-sort` on the sorted column's `th` only, with the sort a `button` inside it.
- **Matrix cells** (permission grids, rating scales): each control is named from its row AND column
  header, e.g. `aria-labelledby="row-id col-id"` — a `th scope` alone does not name a checkbox in a cell.
- **Custom slider handles.** `role="slider"` with `aria-valuenow`/`-min`/`-max`, a name, and
  `aria-valuetext` whenever the number is not what a person reads ("$1,200 a month", "Tuesday").
- **Drop zones.** The drop target is also a real `button` or labelled `input type="file"`; a `div`
  that only accepts drops has no keyboard and no non-drag route.
- **Single-key shortcuts (SC 2.1.4).** A shortcut on a bare letter, number or symbol (`j`/`k`, `e` to
  archive) can be turned off, remapped to add a modifier, or is active only while its component has focus.
- **Time limits and holds (SC 2.2.1).** A session timeout, seat hold or reservation warns before expiry
  and allows at least 20 s to extend with one action, unless real-time or essential. A visible
  countdown is never a ticking live region: `role="timer"` (implicitly `aria-live="off"`) and a
  status message only at thresholds.

## Boundaries

Standing: recorded — owns the WCAG audit only; visual and layout review is the
ui-ux-reviewer agent via `/code-review:review` (ui-ux-engineer fixes). A clean axe or Lighthouse run is
necessary, not sufficient.

## Anti-patterns

Named for citing in a finding; each rule is stated once above.

- **ARIA-sprinkling** — attributes added to quiet a linter, role unchecked.
- **Naked `outline: none`** — no replacement focus style.
- **Div soup** — click handlers standing in for buttons and links.
- **Default-state-only contrast** — hover, focus, disabled forgotten.
- **Filename alt** — `alt="image"`, `alt="photo"`, or the filename itself.
