# Real components — the top rung of the ladder

The shell mockup mimics the look with theme tokens at ~90% fidelity and costs
nothing. This rung renders the variants with the project's **OWN** components on
its **own** dev server, and costs a consent gate, a dev server and a cleanup
verification. Escalate only when a shell mockup cannot carry the decision:

- the choice hinges on composed project components (a real `DataTable` with its
  real states, not a mimic);
- typography/spacing subtleties of the actual design system are the axis;
- the user explicitly asks to see the real thing.

One escalation per decision, not per pass. Everything cheaper — layout structure,
density, motion feel — stays in the shell.

> **Not the host browser tool.** `claude-in-chrome` INSPECTS a page the dev server
> already serves; this rung stands up a surface the app has no route for yet, then
> removes it. Use both. <!-- host-ok -->

## Detection — lock beats memory

Confirm ALL of these before offering anything (reuse the stack-scan inventory when
that plugin is installed):

| Check | Evidence required |
|-------|-------------------|
| Vite present | `vite.config.{ts,js,mjs}` exists, `vite` in devDependencies |
| Framework wired | `@vitejs/plugin-react` (or `-swc`), **or** `@vitejs/plugin-vue`, in the config's plugins |
| Dev script | `package.json` `scripts.dev` (or `scripts.start`) runs vite |
| Component paths | any of: `components.json` aliases, `tsconfig` paths, `src/components/`, or a UI library dep (`@mui/material`, `@astryxdesign/*`, `@radix-ui/*`, `@headlessui/*`, …). Library-agnostic |

Laravel (Blade/Livewire) takes the separate path below — detect it by `artisan` +
`composer.json` requiring `laravel/framework`, with `@vite` in a Blade layout. Any
check failing on both paths — greenfield included — → stay on the shell. Never
install anything to make detection pass, and never scaffold a throwaway app: a
sandbox rendering components the project does not have decides nothing about it.

## Consent gate — stricter than the mockup consent

This writes into the user's source tree. Before ANY write, ask via
`AskUserQuestion`, naming the exact artifacts:

> Render real-component preview? Writes `design-preview.html` (project root) and
> `src/__design-preview__/main.tsx`, then runs `npm run dev`. Both files are deleted
> after the pick.

On the Laravel path the prompt must name the route file too, because a scratch ROUTE
is reachable in a way a scratch HTML file is not:

> Render real-component preview? Writes
> `resources/views/__design-preview__.blade.php` and one route in `routes/web.php`
> inside a marked block, then runs the dev server. Both are removed after the pick.

Options: proceed / use the static shell mockup instead / skip. This gate is separate
from the mockup fidelity consent — that one covered throwaway files in
`taskmaster-docs/mockups/`, not the source tree. Ask once per session.

## The scratch surface — zero edits to existing files

Vite serves extra HTML entries in dev with their own module graph, so no router or
config integration is needed:

- `design-preview.html` at the project root: minimal HTML, `<div id="dp-root">`,
  `<script type="module" src="/src/__design-preview__/main.tsx">`.
- `src/__design-preview__/main.tsx`: imports the project's global stylesheet
  (whatever `src/main.tsx` imports), mounts, renders the variants.

**Vue / Nuxt:** the same trick, only the mount call differs —
`createApp(Preview).mount('#dp-root')`. Nuxt's own dev server does not serve extra
entries, so run `vite` against the app directory, or stay on the shell.

**Laravel Blade / Livewire: the trick does NOT transfer.** PHP owns routing, so there
is no extra-HTML-entry mechanism to borrow — assuming there is, and adding an entry
Vite never serves, is the failure this paragraph exists to prevent. The path is a
scratch route file (`routes/__design-preview__.php`, loaded by one marker-carrying
`require` line in `routes/web.php` — nothing loads it on its own) plus a scratch Blade
view carrying `@vite` and the variants. Name that file in the consent prompt and
verify its removal the same way: a leftover route in a real app is worse than a
leftover HTML file, because it is reachable.

Never modify existing files — not `vite.config`, not routes, not `index.html` —
except the single named Laravel case above, under its own consent. If the preview
cannot work without touching an existing file, stop and stay on the shell.

## The page

The skill's variant discipline is unchanged; only the ingredients are real. Variants
are composed from the project's own components, imported the way the app imports them
— never copies, never a library the project does not have. No shell chrome: the
project's global CSS already styles the page like the app. Components from a registry
(shadcn, ReUI, Aceternity): read real names and props from the registry's own MCP
server before authoring, never from memory. Record the pick as a CLEAR ledger row
with `src/__design-preview__/main.tsx` as the source.

Depth comes from one clear lane, that lane's real states, and realistic data — never
from more variants. Pick ONE lane per preview; mixing lanes breaks the comparison,
and two lanes is two previews:

- **design** — layout, placement, density, flow. Vary one structural axis, name it
  out loud (sidebar-vs-topbar, table-vs-cards, comfortable-vs-dense), hold content
  and theme constant and populate every variant identically.
- **creative** — concept or content (copy, tone, framing). Hold layout constant;
  variants are genuinely divergent premises, not one draft reworded. `populated` only.
- **dataviz** — which chart, which encoding, how a dashboard lays out. Render the
  project's REAL chart component wired to its own chart tokens. No chart library in
  the project → not a dataviz preview. Chart form and encoding are governed by the
  host's bundled `dataviz` skill. <!-- host-ok -->

Data lanes render every meaningful state, switchable from the preview header:
`populated` (realistic data, full interactivity), `empty` (the honest empty state,
not a blank box), `loading` (a skeleton in the real layout's shape), `error` (a clear
failure with a retry affordance). Each variant renders its OWN states — one that
omits `loading` or `error` falls through silently to whatever branch catches it, a
bug no compiler catches. Populate with specific, real-shaped data ("Invoice #4821 —
Northwind Traders — $1,240.00 — overdue 12 days"), never lorem ipsum: placeholders
that read like production data expose density problems lorem hides. Theme is a
constant backdrop, never a variant axis — colour decisions belong to `/ui-ux:theme`.

## Server lifecycle

- A dev server already running (detected port in use with a Vite response)? Reuse it
  — the entry appears at `/design-preview.html` without a restart. NEVER kill or
  restart a server this flow did not start.
- **Where the harness owns servers, start it there.** Claude Code's desktop app ships
  `mcp__Claude_Browser__preview_start`, which runs a dev server named in
  `.claude/launch.json`, reuses one already running, and opens the Browser pane on it
  — its own instruction is to use it instead of Bash for running servers. Add the
  project's dev script as a `launch.json` configuration if absent, start it by name,
  navigate to `/design-preview.html`, and stop it with `preview_stop` in place of the
  PID kill — only if this flow started it. <!-- host-ok -->
- Otherwise start the dev script in the background, note the PID, wait for the ready
  line, and hand over `http://localhost:<port>/design-preview.html`.
- Iteration: edit the entry in place — HMR updates the open tab; no new entries, no
  new ports, at most two passes.

## Cleanup — guaranteed, verified

**Standing: `gate`** — `scripts/preview-cleanup.sh` exits non-zero while any scratch
artifact survives, driven by `scripts/__tests__/preview-cleanup.test.sh` over a
fixture of every artifact shape. Residual: a scratch file renamed away from
`__design-preview__` is invisible to it, so never rename one. A preview that leaves
files behind is a failed run, whatever was picked.

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/preview-cleanup.sh <project-root>` at the
   pick, on abort, and on fallback alike — it removes every `__design-preview__`
   artifact, strips the marker line from `routes/web.php`, and exits non-zero if
   anything remains. `--verify` is the search-only mode.
2. On Laravel, ALSO run `php artisan route:list` and confirm the scratch route is
   gone — the script proves file and marker absence; only artisan proves the route
   table.
3. Kill the dev server ONLY if this flow started it, by noted PID.
4. Stale leftovers from a crashed session: run the same script before starting a new
   preview. That is the recovery.

## Fallback, and the anti-patterns this rung adds

**Standing: `agent-graded`** — nothing detects a scaffold being stood up; the list
below is the only guard. Detection failed, consent declined, or the server does not
come up in its normal boot time → the shell mockup decides it. Never leave a decision
undecided because the fancy path was unavailable. On top of the skill's own
anti-patterns:

- Editing existing project files to make the preview work — the scratch entry is
  additive or it does not happen.
- `npm install`, `composer require`, or any dependency change to enable a preview.
- Leaving scratch files behind, or keeping them "for later".
- Using the preview page as the implementation starting point.
- Standing up a scratch app so a greenfield project has something to preview in.
- Escalating here for a decision the shell can carry.
