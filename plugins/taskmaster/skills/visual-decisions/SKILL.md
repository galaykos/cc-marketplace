---
name: visual-decisions
description: Use during requirement clarification when a choice is visual or structural — layout variants, user flows, architecture topology, data shapes. Builds throwaway ASCII wireframes, side-by-side HTML mockups, or example payload tables so the user picks between concrete options instead of imagining them from prose.
---

## When to show instead of tell

Reach for a visual the moment describing options costs more words than drawing them:

- Layout or component variants — where things sit, what is emphasized.
- User flows — screens/steps and the transitions between them.
- Architecture topology — services, queues, data direction.
- Data shapes — candidate JSON/table structures for the same real scenario.

Do NOT use visuals for text-native tradeoffs (latency vs. cost, library A vs. B) —
a mockup of a sentence is theater. Those stay as multiple-choice questions.

## The fidelity ladder

Climb only as high as the decision requires, never higher:

1. **ASCII wireframe in chat** — seconds. Right for structure questions: rough
   placement, column counts, what is above the fold.
2. **Static HTML mockup** — minutes; served at the session preview URL. Right when
   spacing, hierarchy, or density drives the choice and boxes cannot carry it.
3. **Inline SVG inside that HTML** — for flows and topology diagrams.

There is no rung 4 — never build a working prototype to make a decision; mockups
are throwaway by design and die the moment the pick is made. Validating the
ASSEMBLED experience after picks land (multi-screen flows, whole landing
experiences) is a different job: the experience-walkthrough skill in this plugin.

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

Label variants A/B/C, caption each with its one-line tradeoff, keep both at equal
detail. Ask for the pick immediately below the drawing.

## HTML mockups

- One self-contained file: inline CSS, system font stack, zero external requests —
  no CDNs, no webfonts, no images (use CSS blocks and emoji as placeholders).
- All variants side by side in one page, each in a labeled frame: "A — dense
  table (fastest scanning)", "B — cards (more scannable metadata)".
- At most 3 variants, and variants differ on ONE axis at a time. If layout and
  navigation both vary, that is two separate decisions — two mockup passes.
- Equal fidelity per variant. A polished favorite next to a gray strawman is not a
  question, it is a sales pitch.
- Realistic placeholder data — "Invoice #4821 — $1,240.00 — overdue 12 days", not
  "Lorem ipsum". Judgment needs plausible content density.
- Write to `docs/mockups/YYYY-MM-DD-<topic>.html`, then copy to `current.html` so
  it appears at the session preview URL (see Preview below).

## Flows and topology as SVG

Embed inline SVG in the same HTML file: boxes, arrows, labels — nothing animated.
Two candidate flows render side by side the same way layouts do. For a quick
in-chat alternative, an ASCII arrow diagram (`login -> otp -> dashboard`) is often
enough; climb to SVG only when branches make ASCII unreadable.

## Click-through flows without a server

When the user must FEEL a navigation flow, not just see it: put every screen in one
file as a section, hide all but the first, and drive visibility with anchor links
and CSS `:target` — buttons are `<a href="#screen-2">`, and
`section:target { display: block }` swaps screens. A clickable multi-screen
prototype with zero JavaScript that works over `file://`.

## Preview: one live URL for the whole session

Always serve — every visual decision lands at the same address, in the same open
browser tab. One session server, one canonical file:

1. On the first visual decision, start `python3 -m http.server 8123 -d docs/mockups`
   in the background and note the PID (`php -S localhost:8123 -t docs/mockups` in
   PHP projects; python3 ships with macOS, PHP may not exist). Port busy?
   `lsof -ti :8123` — reuse the server if it is a previous mockup one, else bump.
2. Write each pass to its dated file for the ledger trail, then copy it to
   `current.html`. The user keeps one tab on `http://localhost:8123/current.html`;
   the snippet swaps content in place within a second — new variants, live tweaks
   ("make B denser"), and the NEXT decision all arrive in the same tab.
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

Kill the server by PID when the grill pipeline ends (spec written, cards emitted);
stale-server recovery: `lsof -ti :8123 | xargs kill`. Bind `0.0.0.0` only for
phone-on-LAN preview. `file://` open remains the fallback when no server runtime
exists. Always-live does not relax the discipline: at most 3 variants, one axis per
pass, no polish — the persistent tab replaces the reopen dance, not decision scope.

## Data-shape decisions

Show 2–3 candidate shapes carrying the SAME real scenario, then ask which matches
intent:

```jsonc
// A: flat            // B: nested
{ "user_id": 7,       { "user": { "id": 7 },
  "total_cents": 124000, "total": { "cents": 124000,
  "currency": "USD" }     "currency": "USD" } }
```

The scenario must be real enough to expose the differences (optional fields
present, one edge case included).

## Asking for the pick

- Ask via `AskUserQuestion`: one option per variant letter plus its tradeoff line;
  include "mix of the above" only when a mix is actually mergeable.
- On a mix answer ("A's layout with C's nav"), produce ONE merged variant and
  re-ask once. Do not iterate mockups more than twice — this is a decision aid,
  not a design sprint.
- Record the pick as a CLEAR row in the grill skill's ambiguity ledger, with the
  mockup file path as the source, and quote the choice in the spec.

## Anti-patterns

- Polishing mockups: shadows, transitions, brand colors. It dies after the pick.
- More than 3 variants — choice overload produces "whichever", not a decision.
- Variants that differ on several axes at once: the pick cannot be attributed to
  any single difference, so nothing actually got decided.
- Building real components "since we're at it" — implementation starts after the
  task cards exist, not inside a mockup file.
- External assets or frameworks in mockups — a mockup that needs a network is
  slower to open than the decision it serves.
- Reusing mockup HTML as the implementation starting point — implement from the
  spec instead; mockups carry none of the codebase's conventions.
