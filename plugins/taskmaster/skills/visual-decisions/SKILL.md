---
name: visual-decisions
description: Use during requirement clarification when a choice is visual or structural — layout variants, user flows, architecture topology, data shapes. Builds throwaway ASCII wireframes, side-by-side HTML mockups, or example payload tables so the user picks between concrete options instead of imagining them from prose. Asks fidelity consent (full mockups / ASCII only / none) on first use per session.
---

## When to show instead of tell

Reach for a visual the moment describing options costs more words than drawing them:

- Layout or component variants — where things sit, what is emphasized.
- User flows — screens/steps and the transitions between them.
- Architecture topology — services, queues, data direction.
- Data shapes — candidate JSON/table structures for the same real scenario.

Do NOT use visuals for text-native tradeoffs (latency vs. cost, library A vs. B) —
a mockup of a sentence is theater. Those stay as multiple-choice questions.

## Consent gate

Before building the session's FIRST visual artifact, ask via `AskUserQuestion`:

- **Full mockups (Recommended)** — HTML/live preview; format per decision type.
- **Quick ASCII only** — inline wireframes and tables only; skip the HTML
  mockups, click-through, and Preview sections entirely — no server, no files.
- **No mockups** — dormant for the session; visual choices become plain-text
  `AskUserQuestion`s.

The answer holds all session — never re-ask. The gate is lazy: fire only when a
genuinely visual choice exists and a build is imminent, never at task intake.

## The fidelity ladder

Climb only as high as the decision requires, never higher:

1. **ASCII wireframe in chat** — seconds. Right for structure questions: rough
   placement, column counts, what is above the fold.
2. **Static HTML mockup** — minutes; served at the session preview URL. Right when
   spacing, hierarchy, or density drives the choice and boxes cannot carry it.
3. **Inline SVG inside that HTML** — for flows and topology diagrams.

There is no rung 4 — never build a working prototype to decide; mockups die at the
pick. Validating the ASSEMBLED experience afterwards is the experience-walkthrough skill.

## ASCII wireframes

```
+----------------------------------+   +----------------------------------+
| Logo        [Search]       (@)   |   | Logo                       (@)   |
+------+---------------------------+   +----------------------------------+
| Nav  |  Card   Card   Card       |   |  Filters > inline row            |
| Nav  |  Card   Card   Card       |   |  List item ................      |
+------+---------------------------+   |  List item ................      |
        A: sidebar + grid              +----------------------------------+
                                              B: topbar + list
```

Label variants A/B/C at equal detail, caption each with its one-line tradeoff,
ask for the pick immediately below the drawing.

## HTML mockups

- One self-contained file: inline CSS, system font stack, zero external requests —
  no CDNs, no webfonts, no images (CSS blocks and emoji as placeholders).
- All variants side by side in one page, each in a labeled frame: "A — dense
  table (fastest scanning)", "B — cards (more scannable metadata)".
- Under each frame, a compact tradeoff panel: 2–3 pro/con bullets, identical
  styling across variants (richer = favoritism), scoped to the ONE axis being decided.
- Footer strip: the decision question plus the axis name — the persistent tab
  stays self-explanatory. Helpers are plain text; no charts or scoring matrices.
- At most 3 variants, and variants differ on ONE axis at a time. If layout and
  navigation both vary, that is two decisions — two mockup passes.
- Equal fidelity per variant — a polished favorite next to a strawman is a sales pitch.
- Realistic placeholder data — "Invoice #4821 — $1,240.00 — overdue 12 days", not
  "Lorem ipsum". Judgment needs plausible content density.
- Write to `docs/mockups/YYYY-MM-DD-<topic>.html`, then copy to `current.html` so
  it appears at the session preview URL (see Preview below).

## Flows and topology as SVG

Embed inline SVG in the same HTML file: boxes, arrows, labels — nothing animated.
Candidate flows render side by side like layouts. In chat, ASCII arrows (`login ->
otp -> dashboard`) often suffice; climb to SVG when branches make ASCII unreadable.

## Click-through flows without a server

When the user must FEEL a navigation flow: every screen is a section in one file,
all but the first hidden via anchor links and CSS `:target` — buttons are
`<a href="#screen-2">`, `section:target { display: block }` swaps screens. A
clickable prototype, zero JavaScript, works over `file://`.

## Preview: one live URL for the whole session

Always serve — every decision lands in the same open tab. One session server, one
canonical file:

1. On the first visual decision, start `python3 -m http.server 8123 -d docs/mockups`
   in the background, note the PID (`php -S localhost:8123 -t docs/mockups` in PHP
   projects). Port busy? `lsof -ti :8123` — reuse a prior mockup server, else bump.
2. Write each pass to a dated file (ledger trail), copy to `current.html` — the
   user's tab at `http://localhost:8123/current.html` sees every pass in place.
3. Embed the reload snippet in every mockup — body-compare polling, works with any
   static server, zero dependencies:

```html
<script>
(() => {
  let last = null;
  setInterval(async () => {
    try {
      const body = await (await fetch(location.href, { cache: 'no-store' })).text();
      if (last !== null && body !== last) location.reload();
      last = body;
    } catch { /* server gone: stop reloading, page stays usable */ }
  }, 1000);
})();
</script>
```

Kill the server by PID at pipeline end; stale recovery: `lsof -ti :8123 | xargs kill`.
Bind `0.0.0.0` only for phone-on-LAN; `file://` is the no-runtime fallback.
Always-live relaxes nothing: max 3 variants, one axis per pass, no polish.

## Data-shape decisions

Show 2–3 candidate shapes carrying the SAME real scenario (optional fields
present, one edge case included) and ask which matches intent:

```jsonc
// A: flat            // B: nested
{ "user_id": 7,       { "user": { "id": 7 },
  "total_cents": 124000, "total": { "cents": 124000,
  "currency": "USD" }     "currency": "USD" } }
```

## Asking for the pick

- Ask via `AskUserQuestion`: one option per variant letter plus its tradeoff line;
  include "mix of the above" only when a mix is actually mergeable.
- On a mix answer ("A's layout with C's nav"), produce ONE merged variant and
  re-ask once. Mockups iterate at most twice — decision aid, not design sprint.
- Record the pick as a CLEAR row in the grill skill's ambiguity ledger, with the
  mockup file path as the source, and quote the choice in the spec.

## Anti-patterns

- Polishing mockups (shadows, transitions, brand colors) — it dies after the pick.
- More than 3 variants — choice overload produces "whichever", not a decision.
- Variants differing on several axes — the pick cannot be attributed, so nothing
  actually got decided.
- Building real components "since we're at it" — implementation starts after the cards.
- External assets or frameworks — a networked mockup opens slower than the decision
  it serves.
- Reusing mockup HTML as the implementation start — implement from the spec;
  mockups carry none of the codebase's conventions.
