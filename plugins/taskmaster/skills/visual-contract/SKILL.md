---
name: visual-contract
description: Use during spec writing, after visual or creative options were staged (via brainstorm or grill's visual-decisions), to bind the chosen picks into the spec as a `## Visual contract` section — a binding contract the implementing cards must conform to, mirroring how erd binds `## Data Model`. Fires only when a staged visual/creative decision exists; embeds a structural description per pick, not a live artifact.
---

## Where this sits

During spec writing, grill hands off here once visual or creative picks were
staged — the visuals counterpart to `erd`. erd binds the data shape as
`## Data Model`; this binds the chosen look, placement, and content as
`## Visual contract`. Both make a decision durable and enforceable so a card
cannot silently drop it. Fire only when a staged decision exists; a backend spec
with no visual surface gets no section and no nag.

## Collect from both sources

Staged decisions live in two places depending on the entry path; gather from
whichever exist — binding only one leaves the other path's picks unenforced:

- **Brainstorm path** — the design doc's `Staged decisions` section (label,
  rationale, tier).
- **Direct-grill path** — the CLEAR visual/creative ledger rows grill recorded
  when it switched to the `visual-decisions` skill (the pick and its source).

A task that entered at grill has no design doc, so keying only off the design doc
would silently drop its layout picks — exactly the gap this piece closes. If a
decision appears in both (a brainstorm pick grill later refined), bind the latest
and note the supersession — one entry per decision, never two.

## The `## Visual contract` section

One entry per decision, embedded in the spec:

- **Decision** — the question that was settled ("dashboard layout", "empty-state
  copy").
- **Lane** — design / creative / dataviz.
- **Chosen variant** — the winning option's label.
- **Structural description** — what it is, in words: placement, hierarchy,
  density, what data sits where, interaction; for dataviz, the chart type and
  encoding. Precise enough to build from without the mockup.
- **Motion** — only when motion WAS the decided axis: entrance direction, duration
  tier (fast/base/slow), easing family, hover/press feedback.
- **Theme** — only when theme WAS the decided axis: the token bundle (radius, space,
  shadow, font), so a decided look survives to the card.
- **Rationale** — three parts: **serves** (who it is for), **trades** (what it
  gives up), **breaks** (when it fails). One short clause each.

Group entries by surface or screen when there are several, in the order the user
meets them — a flat pile of unordered picks is hard for a card to conform to.

## Reconstructing the description

The sandbox is deleted at the pick and no JSX survives, so the structural
description is written from the recorded pick plus the spec's own data shapes —
never copied from a live artifact. Describe structure, not pixels: "a two-column
master/detail — left a sortable table of invoices, right the selected invoice's
line items; empty state a centered prompt" — and never theme or motion
UNLESS one WAS the decided axis: held constant and unrecorded when a fixed backdrop,
but the single axis that WAS decided is captured in its Motion/Theme field above.
(Colour is never a field here even when decided — it binds via `/ui-ux:theme`'s own
artifact; the Theme field records only the token bundle: radius/space/shadow/font.)

## Binding contract

State it in the spec: this section is a **binding contract**. Implementation
conforms to it; a deviation discovered mid-card goes back through re-approval of
the visual contract, never into silent drift — the rule `erd` sets for the data
model, one lane over. Downstream, task-cards makes surface-touching cards
reference it, spec-redteam attacks it under the visual/experience lens, and
coverage-check maps every entry to a conforming card.

## Distinct from Data Model

`## Data Model` binds persistent shape; `## Visual contract` binds appearance and
placement. They never overlap: a decision that is really about data shape belongs
in erd's section, not here. They share one task-cards conformance rule but are
checked by separate coverage correspondences, so keep each entry unambiguously
one or the other.

## Worked example

```
## Visual contract

### Invoice list layout  (design · variant B)
Structure: left, a sortable table (Invoice, Client, Amount, Status); right, the
selected invoice's line items in a Card. Empty: a centered "No invoices yet"
prompt with a primary action. Loading: skeleton rows. Error: inline retry.
Serves: triaging many invoices at once. Trades: detail-pane width. Breaks: on
narrow screens where the split collapses.
Binding — deviation re-approved here, not in the card.

### Revenue trend  (dataviz · variant A)
Structure: a bar chart of monthly revenue, last 12 months (x = month, y = amount,
chronological); a stat tile above showing the period total. Empty: "No revenue in
range". Serves: spotting seasonal dips. Trades: exact values (read the tile).
Breaks: beyond ~24 bars the axis gets cramped.
```

## Approval

Like the data model, the contract is the user's to approve before it binds. Show
the assembled `## Visual contract` and get an explicit yes; an unreviewed section
is a draft, not a contract. Once approved it is frozen — a later change re-opens
it here, never mid-card and never as a silent implementation choice.

## Anti-patterns

- Firing on a spec with no staged decision — an empty contract is nag, not rigor.
- Binding only the brainstorm design doc and dropping grill-native picks (or the
  reverse) — both entry paths produce decisions that must be bound.
- Describing colour, theme, or motion that was NOT the decided axis — those stay a
  constant backdrop; only the axis that WAS decided earns a Motion/Theme entry.
- Storing a dead mockup path or a localhost URL as the payload — the sandbox is
  gone by spec time; the words are the contract.
- Letting an entry blur into `## Data Model`'s job — persistent shape is erd's,
  and a card cannot conform to a decision filed under the wrong contract.
