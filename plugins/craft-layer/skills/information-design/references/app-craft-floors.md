# App-craft floors — what "too little" means behind the login

Every positive gate craft-layer ships is shaped like a marketing page. The
signature-interaction floor wants a hero. The content-depth floor counts
sections. The offer spine asks what the page sells. Point them at an internal
CRM and they answer `not applicable`, so an app surface falls through every
floor the plugin has and is judged only by ceilings — budgets, contrast,
reduced-motion — all of which a grey, sluggish, mouse-only admin panel passes
perfectly.

These are the floors for the surface behind the login. Same logic as the
signature floor: **they fail a build for doing too little.** They apply when the
archetype is `app/CRM`, and to the logged-in half of a `product/SaaS` build; the
front door keeps the marketing floors.

The reference class is the products this category is actually measured against —
the ones whose craft is felt as speed and control rather than seen as decoration.

## 1. Perceived speed

The floor most responsible for whether an app feels crafted, and the one no
contrast checker will ever catch.

- **Interaction feedback inside ~100ms.** Not completion — acknowledgement. A
  row highlights, a control depresses, a value commits locally. One product in
  this class made a 100ms budget its central design constraint, and it is the
  single most-copied thing about it.
- **Mutations are optimistic, with a real rollback path.** Apply the change
  locally, reconcile after, and on failure restore the prior value AND say what
  happened. Optimistic UI with no rollback is not speed, it is lying.
- **No spinner under about a second** (NN/g): an indicator that flashes reads as
  a glitch. Skeletons for container-shaped loads, a spinner for a single tile,
  a determinate bar past ten seconds.
- A surface that blocks on the network for its first paint has failed this floor
  however fast the network happened to be during development.

## 2. Keyboard reach

Not the accessibility floor — that is the minimum. This is the craft dimension:
in this category a keyboard-first product is the differentiator, and the
palette is how users discover the shortcuts they graduate to.

- **Every primary action reachable without a pointer**, and the path is short.
- **A dense grid is one tab stop**, arrow keys within (`dense-ui-patterns.md`).
- **Focus is never lost** on dismiss, delete, or route change: it returns to a
  defensible place, not to `<body>`.
- A command palette is earned, not assumed — but when the action surface has
  outgrown the nav, its absence is the finding.

## 3. State completeness

`dense-ui-patterns.md` requires four states per table. The APP owes more, and
these are the ones that ship broken because they are hard to reach in dev:

- **First run** — the org with no data at all, which is every customer's first
  impression and the state most often designed last.
- **Permission denied** — a real state with a real explanation, not a blank grid.
- **Partial failure** — three tiles loaded, one did not. The page must not
  present a partial truth as a whole one.
- **Stale / offline** — data shown after connectivity dropped is labelled as
  such, or it is a lie with a timestamp on it.

## 4. Motion that carries data

A dense surface is not a motion-free surface. `information-design`'s rule that
motion serves the reading is a CEILING; this is the floor under it. Route the
work to the existing tiers (`product-packages.md` says which):

- **Where a thing went.** A row leaving on filter, a card changing column, a
  list re-sorting — a shared-layout transition makes the change readable where a
  hard swap makes it a flash the eye cannot follow.
- **That a number changed.** Interpolate a KPI to its new value rather than
  swapping the glyphs; the movement is what tells a glancing reader to look.
- **That an optimistic write is provisional**, and that it settled or reverted.

Bounded by two rules that keep this a floor and not a licence: motion must never
delay the first read, and everything here must survive `prefers-reduced-motion`
by becoming instant — never by becoming absent, since the information the motion
carried has to arrive some other way.

## 5. Density is offered

Comfortable / cozy / compact is a user choice, not a designer's (see
`dense-ui-patterns.md`), and the row-action target holds the 24×24 floor at every
one of them.

## 6. Undo over confirm

Destructive actions in a data product should be reversible rather than gated by a
modal. A confirm dialog interrupts every user to prevent the mistakes of a few
and is routinely click-throughed; an undo affordance costs the mistaken user
seconds and everyone else nothing. Reserve confirmation for the genuinely
irreversible, and say plainly what will be destroyed when you do.

## What this file is not

Not a design. Not a component list. Not a claim that an app must have a command
palette, optimistic writes, and animated counters — each is earned by the
product's own shape. It is a set of questions an app surface must ANSWER, in the
same way the signature floor is a question a landing page must answer, so that
"we shipped a grey table that passes contrast" stops counting as done.
