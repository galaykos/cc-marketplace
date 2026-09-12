# Product judgment — what the overseer decides without asking

The user gave one sentence. Everything below is decided by you, written to `charter.md`
under `## Product decisions` with a one-line rationale each, and bound into every brief.
A decision the user later overrides is re-recorded, never argued.

## Build on what we have

1. **Inventory first, choose second.** The component library, styling system, form
   pattern, table pattern, toast, dialog and icon set already in the tree are the defaults.
   A project with `components/ui/*.tsx` and `@radix-ui/*` IS a shadcn project — do not
   introduce MUI beside it. A Blade project stays Blade unless the goal says otherwise.
2. **Extend the existing skeleton.** Reuse the app layout, auth, navigation, settings
   pages and test base classes. A new feature is a new page in the existing layout, a new
   route in the existing group, a new test beside its siblings.
3. **Dependencies are a decision, not a reflex.** Adding a package needs a reason in
   `decisions.md` and must pass the project's own rules (a `CLAUDE.md` that says "do not
   change dependencies without approval" turns the add into a Clarify question or an
   ASSUMED-NO). Prefer a 40-line component to a 400 KB package for one interaction.
4. **Suggest what is missing; do not sneak it in.** No tests, no lint, no CI, no type
   check, no a11y baseline, no error monitoring, no seeders — each goes into the charter's
   `## Suggested improvements` list with the milestone it would help. The first milestone
   may add a test runner when there is none, because acceptance needs one; nothing else
   arrives uninvited.

## Known starter defects — check at discovery, not after a reviewer finds them

The plugin has no memory across programs; this list is it. A starter matched here puts
each row in the charter's product decisions as "fix in m1" or "suggested", never as a
surprise in a review. Add a row when a simulation or a program finds one.

| Starter | Defect | Where it bit |
| --- | --- | --- |
| Laravel 13 + Inertia React starter (Fortify, shadcn-style `components/ui`) | focus-visible ring on button/input/select/checkbox/toggle/badge ≈1.2:1 in both modes | simulations 1 and 2, fixed twice |
| same | Radix-based `sheet`, `select`, `dropdown-menu`, `navigation-menu` animations not `motion-safe:` | simulations 1 and 2 |
| same | `NavUser` rendered outside `SidebarProvider` warns on `/register` | simulation 2 |
| same | dialog action buttons 36 px tall at 375 (44 px target) | simulation 2 |
| same | CI workflow triggers on `main` while the base branch is `master` | simulation 2 (the scan prints it) |
| Vite `react-ts` template | `tsconfig.app.json` / `tsconfig.node.json` never set `strict`; starter App/hero assets ship; no test runner | simulation 3 (a reviewer found the strict flag) |

## Choosing a component library (greenfield only)

Ask the Clarify round only when the tree has none AND the goal's register is unclear.
Otherwise decide by register: product/admin UI → shadcn/ui (owned code, Radix, Tailwind);
marketing/landing → the same plus `craft-layer` motion tiers when installed; a design
system the client already owns → that one. Record the pick and the reason. `/ui-ux:build`
and the `*-best-practices` skills own the how; you own the which.

## Motion policy — decide it once per program

| Animate | Do not animate |
| --- | --- |
| state transitions the user caused: open/close, add/remove, success, upload progress | data tables, form fields, page loads, anything on every render |
| micro-feedback ≤ 200 ms: hover, press, focus rings | anything that delays the first interaction |
| skeletons for loads > 300 ms | decorative loops on product screens |

Every animation respects `prefers-reduced-motion`. The `ui-ux` motion skill carries the
techniques; this table is the product rule a brief quotes.

## Clarity rules that every brief inherits

- One primary action per screen, visibly primary. Destructive actions confirm, and the
  confirm names the object ("Delete photo?").
- Empty, loading, error and success states are designed, not defaulted: an empty state
  says what to do next; an error names the fix; success is confirmed once, not thrice.
- Forms validate inline on blur and on submit, keep the user's input on failure, and
  say what was wrong in words a person would use.
- Text is content, not filler: no "Lorem", no "Click here", no jargon the user did not
  bring. Labels name the thing; buttons name the verb.
- Mobile is a first-class width: nothing hides behind hover, tap targets ≥ 44 px, tables
  collapse or scroll deliberately, the primary action stays reachable.
- Colour and contrast meet WCAG 2.2 AA; `/ui-ux:audit` when installed, else a manual
  check of the contrast pairs in the brief.

## Scope discipline

- A milestone ships one user-visible capability with its states and its tests.
- "While I'm here" work becomes a queued milestone or a suggestion, never a diff.
- The walking skeleton comes first in a greenfield project; the riskiest integration
  (payments, uploads, third-party auth) comes second, not last.
