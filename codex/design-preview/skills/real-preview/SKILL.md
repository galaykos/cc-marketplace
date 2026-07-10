---
name: real-preview
description: Use when a visual decision needs REAL component fidelity — the project's actual design-system components, true typography and spacing — beyond what token-mimicking static mockups can show. Vite + React projects only; renders 2-3 candidate variants in a scratch dev-server entry with zero edits to existing files, strict consent before writing into the source tree, and guaranteed cleanup. Falls back to the taskmaster shell mockup when Vite is absent.
---

## When to escalate here

This is the top rung of the mockup fidelity ladder — an optional escalation, not
a replacement. Reach for it only when a static shell mockup with theme tokens
cannot carry the decision:

- The choice hinges on the project's composed components (a real `DataTable`
  with its real states, not a mimic).
- Typography/spacing subtleties of the actual design system are the axis.
- The user explicitly asks to see the real thing.

Everything cheaper — layout structure, density, motion feel — stays in the
taskmaster visual-decisions shell. One escalation per decision, not per pass.

## Detection — lock beats memory

Confirm ALL of these before offering anything (reuse the stack-scan inventory
when that plugin is installed):

| Check | Evidence required |
|-------|-------------------|
| Vite present | `vite.config.{ts,js,mjs}` exists, `vite` in devDependencies |
| React wired | `@vitejs/plugin-react` (or `-swc`) in the config's plugins |
| Dev script | `package.json` `scripts.dev` (or `scripts.start`) runs vite |
| Component paths | `components.json` aliases, or `tsconfig` paths, or `src/components/` |

Any check failing → skip straight to Fallback. Never `npm install` anything to
make detection pass.

## Consent gate — stricter than mockups

This flow writes into the user's source tree. Before ANY write, ask via
`AskUserQuestion`, naming the exact artifacts:

> Render real-component preview? Writes `design-preview.html` (project root) and
> `src/__design-preview__/main.tsx`, then runs `npm run dev`. Both files are
> deleted after the pick.

Options: proceed / use static shell mockup instead / skip. This gate is separate
from any mockup fidelity consent already given — that consent covered throwaway
files in `docs/mockups/`, not the source tree. Ask once per session.

## The scratch surface — zero edits to existing files

Vite serves extra HTML entries in dev with their own module graph, so no router
or config integration is needed:

- `design-preview.html` at the project root: minimal HTML, `<div id="dp-root">`,
  `<script type="module" src="/src/__design-preview__/main.tsx">`.
- `src/__design-preview__/main.tsx`: imports the project's global stylesheet
  (whatever `src/main.tsx` imports), mounts React, renders the variants.

Never modify existing files — not `vite.config`, not routes, not `index.html`.
If the preview cannot work without touching an existing file, stop and fall back.

## The preview page

Same decision discipline as the shell, real ingredients:

- 2–3 variants side by side, differing on ONE axis, equal fidelity.
- Variants composed from the project's OWN components via its aliases
  (`@/components/ui/button`, not copies) with realistic data.
- A slim header: the decision question, axis name, variant labels A/B/C with a
  one-line tradeoff each. Plain elements, no shell chrome — the project's global
  CSS already styles the page like the app.

## Server lifecycle

- A dev server already running (user's terminal, detected port in use with a
  Vite response)? Reuse it — the entry appears at `/design-preview.html` without
  a restart. NEVER kill or restart a server this flow did not start.
- Otherwise start the dev script in the background, note the PID, wait for the
  ready line, and hand over `http://localhost:<port>/design-preview.html`.
- Iteration: edit `main.tsx` in place — Vite HMR updates the open tab; no new
  entries, no new ports, at most two passes.

## Asking for the pick

`AskUserQuestion`, one option per variant plus tradeoff line. Inside a taskmaster
pipeline, record the pick as a CLEAR ledger row with
`src/__design-preview__/main.tsx` as the source and quote the choice in the spec.

## Cleanup — guaranteed, verified

A preview that leaves files behind is a failed run, whatever was picked:

1. Delete `design-preview.html` and `src/__design-preview__/` at the pick, on
   abort, and on fallback alike.
2. Verify: list both paths and confirm absence; a repo-wide search for
   `__design-preview__` must come back empty.
3. Kill the dev server ONLY if this flow started it (by noted PID).
4. Stale leftovers from a crashed session: the same search-and-delete is the
   recovery, run it before starting a new preview.

## Fallback — the decision still happens

Detection failed, consent declined, or the server does not come up in its normal
boot time: offer the taskmaster visual-decisions shell mockup (when installed)
with theme tokens — it mimics the look at ~90% fidelity. Without taskmaster,
state exactly which check failed and decide via ASCII/description. Never leave
the decision undecided because the fancy path was unavailable.

## Anti-patterns

- Editing existing project files to make the preview work — config, routes,
  components. The scratch entry is additive or it does not happen.
- `npm install` (or any dependency change) to enable a preview.
- Leaving scratch files behind, or "keeping them for later" — the pick is
  recorded in the ledger/spec; the files die.
- Using the preview page as the implementation starting point.
- Escalating here for decisions the static shell can carry — real components
  cost a consent gate and a dev server; spend that only when fidelity is the axis.
- More than 3 variants or more than one axis — same rule as every mockup pass.
