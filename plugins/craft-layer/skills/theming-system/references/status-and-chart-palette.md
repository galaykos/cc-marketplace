# Status + chart palette — reserved roles and a theme-derived chart family

This reference owns two things: the reserved STATUS palette — its meat, genuinely net-new,
owned by no neighbouring skill — and the single SEAM that ties the chart palette to the
theme. It emits no colour value: the status entries below are ROLES, never colours, and the
chart half CITES its neighbours rather than restating them.

## The reserved status palette

Status is a set of RESERVED semantic roles — a small fixed vocabulary that means "the system
is reporting a condition", never "here is another brand colour". The roles form an ordered
severity ladder:

- **good** — the healthy / success / in-range condition: it worked, nothing needs doing.
- **warn** — the caution / degraded condition: attention wanted, not urgent; the soft edge of
  a problem.
- **serious** — the elevated tier between warn and critical: a real problem that is not yet an
  emergency (the step many systems collapse into warn and later regret).
- **critical** — the failure / stop / destructive condition: action required now; the loudest
  status.

Three rules make the palette RESERVED rather than decorative:

- **Never reused as a series colour.** A status role is off-limits to charts and to any
  categorical series. If `good` also stands for "series 3", a healthy row and a data category
  stop being distinguishable — the reservation is what keeps status legible. The chart family
  below is drawn from a DIFFERENT part of the system for exactly this reason.
- **Never colour alone.** A status ALWAYS ships with an icon AND a label, not a coloured dot by
  itself. Colour is reinforcement, never the sole carrier — a colour-blind user, a greyscale
  print, or a fast peripheral glance must still read the condition. Status carried by colour
  only fails the moment colour is unavailable.
- **A ladder, not a wheel.** good → warn → serious → critical is an ORDERED escalation, not four
  interchangeable roles. The system steps the ladder from its ramps in both modes
  (`light-dark-duality.md`) so the ordering stays legible on light and dark grounds alike.

Because status is net-new, its roles, their reservation, and the icon-plus-label rule live here
in full — this is where the palette is owned.

## The chart palette — derived, not bolted on

The one seam this file owns for charts: the chart palette DERIVES from the theme's ramps — it is
not a separate set of colours bolted onto a finished theme. The chart family is part of the
token SYSTEM, drawn from the same ramps as the surfaces and accent (yet held apart from the
reserved status roles above), so any subset of it still reads as one family with the rest of the
theme.

Everything else about charts belongs to a neighbour, cited not restated:

- `plugins/ui-ux/skills/shadcn-theming/SKILL.md` (lines 24–25) owns chart-family COHERENCE —
  the `chart-*` token family that reads as one family across any subset. This file requires that
  family to be DERIVED from the theme; shadcn-theming owns how the family itself is made
  coherent.
- `dataviz` — an external HOST skill, cited by NAME (it is not in this repo; never cite a repo
  path for it) — owns the categorical / sequential / diverging rules and the runnable palette
  VALIDATOR. On a host that has `dataviz`, the chart palette is validated there; craft-layer adds
  no chart gate of its own. This file states the derive-from-the-theme seam and defers the rules
  and the check to `dataviz`.

## What this file does not do

- It does not emit a colour value — no hex, no functional-colour scalar, no named colour used as
  a value. good / warn / serious / critical are ROLES; the values they map to are generated
  downstream by `/ui-ux:theme`.
- It does not restate `dataviz`'s categorical/sequential rules or its validator — it cites the
  skill by name and defers to it.
- It does not restate `shadcn-theming`'s chart-family coherence mechanics — it cites `:25-26` and
  requires only that the family derive from the theme.
- It does not step the light/dark modes — `light-dark-duality.md` owns the duality; this file only
  notes the status ladder must hold in both.
