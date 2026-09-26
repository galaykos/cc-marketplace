# Visual contract — binding staged picks into the spec

Invoked from `grill/SKILL.md` step 2 when visual or creative options were staged
and a pick was made (brainstorm's staging area or grill's visual-decisions): it
binds the picks into a `## Visual contract` spec section the cards must conform
to — the visuals counterpart to erd's `## Data Model`. Fires only on a staged
pick; a backend spec gets no section and no nag. Exceptions: § Walk access, a
ledger row for any UI behind sign-in or data, and the Interaction contract field.

## Collect from both sources

Staged decisions live in two places depending on the entry path; gather from
whichever exist — binding only one leaves the other path's picks unenforced
(a task that entered at grill has no design doc):

- **Brainstorm path** — the design doc's `Staged decisions` section (label,
  rationale, tier).
- **Direct-grill path** — the CLEAR visual/creative ledger rows grill recorded
  when it switched to the `visual-decisions` skill (the pick and its source).

If a decision appears in both (a brainstorm pick grill later refined), bind the latest
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
- **Narrow (375)** — each screen entry: what stacks, what hides (and where to),
  what scrolls in its own container at 375 px. A decision, never "responsive";
  the 375 walk checks it.
- **Interaction contract** — any screen with a composite widget (grid, tree, tabs,
  listbox, board), a drag, or a live region, staged or not (unstaged: an entry of this
  field alone): the keyboard model (one tab stop, arrows inside), the non-drag route
  for each drag (SC 2.5.7), and live updates (what announces, how often, what pauses
  them). The UI walk exercises it.
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
never copied from a live artifact. Describe structure, not pixels, as in the worked
example below. Colour is never a field even when decided — it binds via
`/ui-ux:theme`'s own artifact; the Theme field records only the token bundle.

## Binding contract

State it in the spec: this section is a **binding contract**. Implementation
conforms to it; a deviation discovered mid-card goes back through re-approval of
the visual contract, never into silent drift — the rule `erd` sets for the data
model, one lane over.

## Worked example

```
## Visual contract

### Invoice list layout  (design · variant B)
Structure: left, a sortable table (Invoice, Client, Amount, Status); right, the
selected invoice's line items in a Card. Empty: a centered "No invoices yet"
prompt with a primary action. Loading: skeleton rows. Error: inline retry.
Narrow (375): the split stacks; rows become cards, and the selected invoice
opens as a full-width sheet whose line items scroll inside it.
Serves: triaging many invoices at once. Trades: detail-pane width. Breaks: an
invoice with hundreds of line items.
Binding — deviation re-approved here, not in the card.

### Revenue trend  (dataviz · variant A)
Structure: a bar chart of monthly revenue, last 12 months (x = month, y = amount,
chronological); a stat tile above showing the period total. Empty: "No revenue in
range". Narrow (375): tile above, the chart scrolls sideways in its frame.
Serves: spotting seasonal dips. Trades: exact values (read the tile).
Breaks: beyond ~24 bars the axis gets cramped.
```

## Walk access — a ledger row, not a contract entry

Grill adds it whenever the spec has UI behind sign-in or UI that renders only with data:

```
| 9 | Walk access | self-register at /register; WalkSeeder: pending, failed-caption, empty | CLEAR | user, round 2 |
```

**Sign-in**, never with the user's password: self-registration, a seeded user with an
agent-set password, or an env-guarded local-only login route plus a test proving it 404s
outside local. **Data**: a seeder or factory per walked state, failure and empty included;
a state needing a key or a second actor is named not walked, with its covering test. The
row is also a success criterion, so coverage-check expects the access card. Milestone
form: overseer's `skills/overseer/references/acceptance.md` Protocol step 2; cite, do not
copy (why: `rationale/2026-09-26-taskmaster-prose-derivations.md`). **Standing:**
agent-graded; an UNKNOWN value blocks the spec (`spec-ledger-lint.sh`, gate).

## Approval

Like the data model, the contract is the user's to approve before it binds. Show
the assembled `## Visual contract` and get an explicit yes; an unreviewed section
is a draft, not a contract. Once approved it is frozen; § Binding contract governs change.

## Anti-patterns

- Binding only the brainstorm design doc and dropping grill-native picks (or the
  reverse) — both entry paths produce decisions that must be bound.
- Describing colour, theme, or motion that was NOT the decided axis — those stay a
  constant backdrop; only the axis that WAS decided earns a Motion/Theme entry.
- Storing a dead mockup path or a localhost URL as the payload — the sandbox is
  gone by spec time; the words are the contract.
- Letting an entry blur into `## Data Model`'s job — persistent shape is erd's,
  checked by a separate coverage correspondence; a card cannot conform to a
  decision filed under the wrong contract.
