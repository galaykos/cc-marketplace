# Product mock — the product on its own front door

When the product IS a screen (a console, a CRM, a planner, an inbox, analytics, billing, an AI
tool), buyers expect to see that screen, and the hero usually shows it. Strong and generic
front doors both show the product. What separates them is execution, and this file is the
execution. Whether the hero shows the product at all is a creative-direction decision.
`../../creative-direction/references/sameness-fingerprint.md` lists the chrome to move away
from.

**Standing.** Each rule carries a tag:
- `recorded`: written here and reached through `information-design`'s pointer. Nothing reads
  it back.
- `agent-graded`: the rule cites a WCAG 2.2 success criterion, which `/ui-ux:audit` judges when
  it runs.

The "without it" failures are inferred from reviewing shipped products. No control arm has
measured them.

## 1. Which screen

Show the one screen the buyer uses first. Show one screen, not a collage of four.

| Product | The screen |
| --- | --- |
| CRM, sales | the record table, with at most one record drawer open (`crm-screens.md`) |
| Pipeline, projects | the board, or the day-column planner |
| Support, shared inbox | three panes with the context panel |
| Analytics, billing, finance | a KPI strip, one chart and the breakdown table |
| Hosting, infra, observability | a resource page: status header, deploys or a log panel (`console-patterns.md`) |
| Agents, automation | the run log or the agent ledger (`ai-surfaces.md`) |
| Scheduling, booking | the week grid, or the booking picker mid-selection |

*Without it:* a dashboard assembled from every widget the product has, which reads as a
template. `recorded`

## 2. One frame, legible, no tilt

- **One frame:** a quiet window or a raw panel. Browser chrome with a URL only when the URL is
  the point.
- **Legible at 1280 px:** body text inside the mock must be readable at a 1280 px viewport. When
  it cannot be, promote the one figure that matters into a satellite card (§4). Do not ship
  shrunken, unreadable text.
- **No tilt on data:** no `perspective` or `rotateX` on a surface that carries data. Tilt costs
  legibility and reads as spectacle, not proof.
- **No device trio:** a laptop, phone and tablet group is the generic tier. Use a device
  composite only when multi-platform IS the claim.

`recorded`. No script checks the no-tilt half, though one could grep for it.

## 3. Crop or bleed

Let the frame bleed off one edge, or fade under a mask so the fold cuts mid-row. A fully
visible, centred card with a drop shadow reads as a picture of software, not as the software.
`recorded`

## 4. At most one floating layer

Allow at most one layer beyond the window: a record drawer, a status chip or a notification
card. That layer tells the headline's story (the drawer is open on the deal the headline
names). Toasts and chips scattered around the frame are category chrome.

One exception: a capability list shown as exploded fragments has no base window. Each fragment
must be a real control state ("Audit log · Enabled"), never a decorative toast. `recorded`

## 5. Data: fictional, specific, consistent

- **Specific:**
  - named entities with a mark, and people with avatars and roles;
  - dates relative to one fixed "now";
  - a realistic spread of statuses, not all green;
  - IDs and hashes in the product's real format.
- **Consistent:** sums add up. The stat tile equals the column total, and the board header sums
  its cards.
- **Never** real brands or organisations: they read as customer claims. **Never** "John Doe",
  "Acme", "Lorem", "Project 1" or "Item 3".
- **Masking and greeking:** mask identifiers ("•••• 4821"). Greek non-focal text with neutral
  bars, not lorem, so the eye lands on the named record.
- **Two number registers:** exact values inside the mock, rounded claims outside it. See
  `dense-ui-patterns.md`, "Numbers on marketing and product surfaces".
- **Claim slots:** entities inside the framed product are illustrative app data, not claim
  slots. Claims outside the frame stay governed by
  `../../creative-direction/references/content-depth.md`.

`recorded`

## 6. Hierarchy and accent inside the mock

The mock obeys this skill's own rules:
- one primary signal;
- quiet tertiary text;
- a near-neutral UI;
- the accent only on the primary action and the current selection;
- status roles only on status and deltas;
- the brand hue on the plate or on the one highlighted series, never across the chrome.

Colour roles are `ui-ux:theming-system`'s. *Without it:* every pill is tinted and the mock
shouts over the headline. `recorded`

## 7. The plate

Put the frame on the build's graphic system (Axis 5 in
`../../creative-direction/references/concept-deck.md`) or on plain ground. A tinted stage with a
neutral UI on it is the strong version. A radial glow puddle or a blurred gradient blob under
the frame is the category default. Never use a glow. `recorded`

## 8. Motion as evidence

- **Show real behaviour.** Motion demonstrates what the product actually does: a row arrives, a
  status flips to live, a query types and returns. This is Axis 4 "Motion as evidence". Run it
  at product speed. Do not use ambient drift.
- **Reduced motion shows the settled end state.** Under `prefers-reduced-motion`, show the end
  state: never the first frame, never an empty frame.
- **Tab tours:** an auto-advancing tab tour shows its progress, pauses on hover and focus, and
  under reduced motion shows the active tab statically.
- **Pause control:** anything that moves or loops for more than 5 s beside other content needs
  one (SC 2.2.2). `agent-graded`

## 9. Markup or image: an LCP decision

The mock is usually the largest element in the first viewport, so it is usually the LCP
element.
- **Live-coded:** HTML/CSS built from the app's own components and tokens. It is crisp at any
  pixel density and its text is real. It must still paint on first render. It cannot mount
  after hydration or show a skeleton at LCP.
- **Raster:**
  - export at twice the displayed CSS width;
  - use a modern format with explicit `width` and `height`;
  - set `fetchpriority="high"`;
  - never set `loading="lazy"` on the hero mock.
- **Polarity:** in both cases the polarity is fixed. The specimen is a picture of the product
  and does not follow the page's theme toggle.

Measuring LCP belongs to `resilience:performance-tuning`. `recorded`

## 10. Operable or inert, with a text equivalent

A live-coded mock is one of two things:
- **Operable:** the query runs, the tabs switch, and the focus order is sane.
- **Inert:** the `inert` attribute takes it out of the tab order and the accessibility tree.

A fake Run button that a keyboard user can Tab to, and that does nothing, is the failure (SC
2.4.3, 4.1.2).

An inert mock owes a text equivalent. Use a `<figure>` whose caption or visually hidden
sentence says what the screen shows, e.g. "Deals table: 8 open deals worth $412,300, one
overdue." A raster mock's `alt` says the same, never "dashboard screenshot" (SC 1.1.1).
`agent-graded`
