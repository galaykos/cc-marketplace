---
name: visual-decisions
description: Use during requirement clarification when a choice is visual or structural — layout variants, user flows, architecture topology, data shapes. Builds throwaway ASCII wireframes, theme-aware HTML mockups from a shipped shell (rendered in the project's own colors when detectable), or example payload tables so the user picks between concrete options instead of imagining them from prose. Asks fidelity consent (full mockups / ASCII only / none) on first use per session.
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

- **Full mockups (Recommended)** — shell-based HTML at the live preview URL.
- **Quick ASCII only** — inline wireframes and tables only; skip the HTML mockups,
  click-through, and Preview sections entirely — no server, no files.
- **No mockups** — dormant for the session; visual choices become plain multiple-choice.

The answer holds all session — never re-ask. The gate is lazy: fire only when a
genuinely visual choice exists and a build is imminent, never at task intake.

## The fidelity ladder

Climb only as high as the decision requires, never higher:

1. **ASCII wireframe in chat** — seconds. Right for structure questions: rough
   placement, column counts, what is above the fold.
2. **Shell-based HTML mockup** — minutes; served at the session preview URL. Right
   when spacing, hierarchy, or density drives the choice and boxes cannot carry it.
3. **Inline SVG inside a variant slot** — for flows and topology diagrams.

There is no rung 4 — never build a working prototype to decide; mockups die at the
pick. Validating the ASSEMBLED experience afterwards is the experience-walkthrough skill.

## ASCII wireframes

```
+----------------------------+   +----------------------------+
| Logo    [Search]     (@)   |   | Logo                 (@)   |
+------+---------------------+   +----------------------------+
| Nav  |  Card  Card  Card   |   |  List item ............    |
+------+---------------------+   +----------------------------+
      A: sidebar + grid                 B: topbar + list
```

Label variants A/B/C at equal detail, caption each with its one-line tradeoff,
ask for the pick immediately below the drawing.

## HTML mockups from the shell

Never hand-write mockup HTML. Copy `assets/shell.html` (relative to this skill's
directory) to `docs/mockups/YYYY-MM-DD-<topic>.html` and fill its slots:

- Header: `SLOT: question`, `SLOT: axis`, `SLOT: pass` (e.g. "pass 1 of 2").
- Per variant: `SLOT: variant-A-label`, `-caption`, `-content`, and numbered
  tradeoff bullets (`<li data-n="1">`) in `SLOT: tradeoffs-A`; same for B/C.
- Place `<span class="vd-callout" data-n="1">1</span>` badges in variant content
  where each numbered bullet applies — hover highlights the pair.
- Two variants only? Delete the `FRAME-C-START…FRAME-C-END` block.
- Build variant content from the shell's primitives (`vd-app`, `vd-nav`,
  `vd-sidenav`, `vd-tabs`, `vd-toolbar`, `vd-table`, `vd-cards`, `vd-split`,
  `vd-kpi`, `vd-form`, `vd-chip`, `vd-alert`, `vd-dialog`…) — real density, no inline styles.
- No primitive fits? Add shared classes to the `SLOT: custom-css` block — never
  style one variant differently from its rivals.

The shell carries the polish — header, frames, panels, compare modes, auto-reload.
Do not restyle it. Discipline unchanged:

- At most 3 variants, differing on ONE axis at a time — two axes are two
  decisions, two mockup passes.
- Equal fidelity per variant; realistic placeholder data ("Invoice #4821 —
  $1,240.00 — overdue 12 days", never lorem ipsum).
- Shell missing or unreadable (broken plugin cache): build a minimal self-contained
  mockup by hand the old way and tell the user the shell was unavailable.

## Theme tokens: mockups in the project's own look

Map context-scout's `Theme tokens` table into the shell's `SLOT: theme-project`
block as the `--vd-*` variables; un-hide `#vd-theme-toggle` and set
`data-vd-theme="project"` on `<html>` so the user can flip project ↔ baseline. Rules:

- Missing tokens keep baseline defaults; tokens style chrome and accents only —
  content text stays high-contrast neutrals by shell design.
- No scout report? One glob for `globals.css`/`components.json`/Tailwind config,
  read only on hit. Miss or confidence `none`: keep baseline and hidden toggle,
  put "baseline theme" in `SLOT: theme-note` — never pass baseline off as the app's.
- Theme never differs between variants — equal application is non-negotiable.

## Flows and topology as SVG

Embed inline SVG in a variant content slot: boxes, arrows, labels — nothing animated.
ASCII arrows (`login -> otp -> dashboard`) suffice in chat; SVG when branches grow.

## Click-through flows without a server

When the user must FEEL a navigation flow: every screen is a section in one file;
`<a href="#screen-2">` buttons plus `section:target { display: block }` swap
screens. A clickable prototype, zero JavaScript, works over `file://`.

## Preview: one live URL for the whole session

Always serve — every decision lands in the same tab. One server, one canonical file:

1. On the first visual decision, start `python3 -m http.server 8123 -d docs/mockups`
   in the background, note the PID (`php -S` for PHP projects). Port busy?
   `lsof -ti :8123` — reuse a prior mockup server, else bump.
2. Write each pass to a dated file (ledger trail), copy to `current.html` — the
   user's tab at `http://localhost:8123/current.html` sees every pass in place.
3. Auto-reload needs no setup: the shell embeds a body-compare polling snippet
   (server gone → the page stays usable; any static server works).

Kill the server by PID at pipeline end; stale recovery: `lsof -ti :8123 | xargs kill`.
Bind `0.0.0.0` only for phone-on-LAN; `file://` is the no-runtime fallback.

## Data-shape decisions

Show 2–3 shapes carrying the SAME real scenario, edge case included — which matches intent?

```jsonc
// A: flat            // B: nested
{ "user_id": 7,       { "user": { "id": 7 },
  "total_cents": 124000, "total": { "cents": 124000,
  "currency": "USD" }     "currency": "USD" } }
```

## Asking for the pick

- Ask via `AskUserQuestion`: one option per variant letter plus its tradeoff line;
  include "mix of the above" only when a mix is actually mergeable.
- On a mix answer ("A's layout with C's nav"): ONE merged variant, one re-ask —
  at most two passes; decision aid, not design sprint.
- Record the pick as a CLEAR ledger row (source: the mockup file path); quote it
  in the spec.

## Anti-patterns

- Styling inside a variant slot — polish lives in the shell, never in variant
  content; a hand-decorated favorite next to plain rivals is a sales pitch.
- More than 3 variants — choice overload produces "whichever", not a decision.
- Variants differing on several axes — the pick cannot be attributed, so nothing
  actually got decided.
- Building real components "since we're at it" — implementation starts after the cards.
- External assets or frameworks — a networked mockup opens slower than the decision
  it serves.
- Reusing mockup HTML or the shell as the implementation start — implement from
  the spec; mockups carry none of the codebase's conventions.
