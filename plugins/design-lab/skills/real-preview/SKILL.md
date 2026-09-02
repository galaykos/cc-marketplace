---
name: real-preview
description: Use when a visual decision needs REAL component fidelity — the project's actual design-system components, true typography and spacing — beyond token-mimicking static mockups. Vite (React or Vue/Nuxt) and Laravel Blade/Livewire; scratch entry, strict consent, guaranteed cleanup. Falls back to the taskmaster shell mockup when neither path is available.
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

> **Boundary with the built-in `claude-in-chrome`.** The host drives a page the dev
> server already serves — screenshots, console, clicks — and is the better tool for
> INSPECTING a running app. This skill does the other half: standing up a scratch
> surface rendering 2-3 variants the app has no route for yet, then removing it. Use
> both — this renders the options, the host looks at them. <!-- host-ok -->

## Detection — lock beats memory

Confirm ALL of these before offering anything (reuse the stack-scan inventory
when that plugin is installed):

| Check | Evidence required |
|-------|-------------------|
| Vite present | `vite.config.{ts,js,mjs}` exists, `vite` in devDependencies |
| Framework wired | `@vitejs/plugin-react` (or `-swc`), **or** `@vitejs/plugin-vue`, in the config's plugins |
| Dev script | `package.json` `scripts.dev` (or `scripts.start`) runs vite |
| Component paths | `components.json` aliases, or `tsconfig` paths, or `src/components/` |

Laravel (Blade/Livewire) takes the SEPARATE path below — detect it by
`artisan` + `composer.json` requiring `laravel/framework`, with `@vite` in a
Blade layout. Any check failing on both paths → skip straight to Fallback. Never
`npm install` or `composer require` anything to make detection pass.

## Consent gate — stricter than mockups

This flow writes into the user's source tree. Before ANY write, ask via
`AskUserQuestion`, naming the exact artifacts:

> Render real-component preview? Writes `design-preview.html` (project root) and
> `src/__design-preview__/main.tsx`, then runs `npm run dev`. Both files are
> deleted after the pick.

On the Laravel path the prompt must name the route file too, because a scratch
ROUTE is reachable in a way a scratch HTML file is not:

> Render real-component preview? Writes `resources/views/__design-preview__.blade.php`
> and one route in `routes/web.php` inside a marked block, then runs the dev
> server. Both are removed after the pick.

Options: proceed / use static shell mockup instead / skip. This gate is separate
from any mockup fidelity consent already given — that consent covered throwaway
files in `taskmaster-docs/mockups/`, not the source tree. Ask once per session.

## The scratch surface — zero edits to existing files

Vite serves extra HTML entries in dev with their own module graph, so no router
or config integration is needed:

- `design-preview.html` at the project root: minimal HTML, `<div id="dp-root">`,
  `<script type="module" src="/src/__design-preview__/main.tsx">`.
- `src/__design-preview__/main.tsx`: imports the project's global stylesheet
  (whatever `src/main.tsx` imports), mounts React, renders the variants.

**Vue / Nuxt:** the same trick, unchanged. Only the mount call differs —
`createApp(Preview).mount('#dp-root')` in `src/__design-preview__/main.ts`, with
the entry importing the project's global stylesheet exactly as the React path
does. Nuxt's own dev server does not serve extra entries, so for a Nuxt project
run `vite` against the app directory, or fall back.

**Laravel Blade / Livewire: the trick does NOT transfer.** PHP owns routing, so
there is no extra-HTML-entry mechanism to borrow — assuming there is, and adding
an entry Vite never serves, is the failure this section exists to prevent. The
path is instead: a scratch route file (`routes/__design-preview__.php`, loaded by one
marker-carrying `require` line in `routes/web.php` — nothing loads it on its own) or one closure added to `routes/web.php` behind a clearly marked
block, plus a scratch Blade view carrying `@vite` and the variants. Because that
touches `routes/web.php` in the one case where a separate file cannot be loaded
without registering it, name that file explicitly in the consent prompt, and
verify its removal the same way — a leftover route in a real app is worse than a
leftover HTML file, because it is reachable.

Never modify existing files — not `vite.config`, not routes, not `index.html` —
except the single named Laravel case above, under its own consent. If the preview
cannot work without touching an existing file, stop and fall back.

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
- **Where the harness owns servers, start it there.** Claude Code's desktop app
  ships `mcp__Claude_Browser__preview_start`, which runs a dev server named in
  `.claude/launch.json`, reuses one already running, and opens the Browser pane on
  it — and its own instruction is to use it instead of Bash for running servers.
  When that tool is present: add the project's dev script as a `launch.json`
  configuration (`name`, `runtimeExecutable`, `runtimeArgs`, `port`) if it is not
  there, start it by name, then navigate to `/design-preview.html`. Stop it with
  `preview_stop` in place of the PID kill below, and only if this flow started it.
- Otherwise (the CLI, or no preview tool) start the dev script in the background,
  note the PID, wait for the ready line, and hand over
  `http://localhost:<port>/design-preview.html`.
- Iteration: edit `main.tsx` in place — Vite HMR updates the open tab; no new
  entries, no new ports, at most two passes.

## Asking for the pick

`AskUserQuestion`, one option per variant plus tradeoff line. Inside a taskmaster
pipeline, record the pick as a CLEAR ledger row with
`src/__design-preview__/main.tsx` as the source and quote the choice in the spec.

## Cleanup — guaranteed, verified

A preview that leaves files behind is a failed run, whatever was picked:

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/preview-cleanup.sh <project-root>` at the
   pick, on abort, and on fallback alike — it removes every `__design-preview__`
   artifact, strips the marker line from `routes/web.php`, and exits non-zero
   if anything remains. `--verify` is the search-only mode.
2. On Laravel, ALSO run `php artisan route:list` and confirm the scratch route
   is gone — the script proves file/marker absence; only artisan proves the
   route table. (The script keys on the marker — hence no renaming, ever.)
3. Kill the dev server ONLY if this flow started it (by noted PID).
4. Stale leftovers from a crashed session: run the same script before starting
   a new preview — that is the recovery.

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
