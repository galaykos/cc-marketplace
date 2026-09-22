---
name: in-codebase
description: Use when a design must be rendered with the project's OWN components on its OWN dev server — from a brief, a board, or a Claude Design handoff bundle (a folder of exported .html plus a README) — instead of restyled from a screenshot or export. Detects the stack, stands up a marked scratch entry, imports real components, measures token drift, and removes every trace after the pick.
---

## What this decides

A design is only "in the codebase" when the page you look at is built from the
components the product ships — same `Button`, same layout, same tokens — on the
dev server the product runs. Anything else is a picture of the design, and a
picture is what gets pasted into the tree as a second, drifting copy.

Two entry shapes, one procedure:

- **Brief or board** — "the pricing page from board 2" — render it with real components.
- **Handoff bundle** — a directory Claude Design exported (its exact layout is
  undocumented; treat any folder holding at least one `.html` and a README or chat
  file as one). Measure drift first, then render with real components.

## Rules the model gets wrong from memory

1. **The export is a reference, never a source.** Do not copy the bundle's HTML,
   CSS or class names into the project. Read it for structure, copy, states and
   spacing intent; build every element from the component library. A `.html` from a
   bundle that lands under `src/`, `resources/` or `app/` is a defect. Standing:
   agent-graded — `git status` after the pick is the check.
2. **Find components before writing any.** When `design-system/components.json`
   exists (`/design-kit:system` wrote it), the scratch page already opens with every
   component imported, its prop signature in a comment, and a strip rendering every
   variant — your job is composition and data, not discovery. Otherwise read, in
   order: `components=` from `--detect`; the library's index exports; Storybook
   stories; the two closest existing pages. A component you could not find is a
   question to the user, not a new file. Details: `references/finding-components.md`.
3. **Props come from the component, not the design.** Pass only what the signature
   comment (or the component's types, `defineProps`, Blade `@props`) lists. A
   `gap:` comment on the scratch page names a file the extractor could not fully
   read (a generic, an `extends`, an intersection) — open that file before using
   the component; never guess a prop. An invented prop renders as nothing and hides
   that the design asks for a variant the library lacks — surface a gap row instead.
4. **Every screen renders its states.** Populated, empty, loading and error, in
   that order, on the same scratch page, with the library's own empty/loading/error
   components. A design that shows only the populated state is not done.
5. **Scratch never touches a real file.** The only writes are the marked files
   `codebase-scaffold.sh --create` prints. Registering a provider in `app.tsx`,
   adding a route to a file other than `routes/web.php`, or editing a component
   "just for the preview" leaves no marker and survives cleanup. Standing: the
   marked files are a **gate** (`codebase-cleanup.sh --verify`); edits to real
   files are **agent-graded** — `git status` must show nothing after cleanup.
6. **Drift is a table, not a feeling.** For a bundle, run the drift script before
   rendering and act on every row: `match` uses that token; `near` uses the nearest
   token and says so; `no token` is a question — adopt it as a new token via
   `/design-kit:system` or map it to the nearest — never a literal in the tree.
   Standing: **gate** for the table's existence (the script runs or the command
   stops); the mapping decision is the user's.
7. **A named palette utility is drift too.** `bg-indigo-500` reaches a colour without
   passing the token layer at all, so it never appears in a stylesheet and every
   token-reading check stays green over it. `dk.sh drift <paths>` reads it and the
   literal colours beside it; `bg-primary` and `var(--primary)` are clean by
   construction. Run it on what you WROTE before the pick, not on the repo.
   Standing: **gate** where wired (`--ci` exits 1); nothing in this plugin runs it
   for you, so not run is not clean.

## Procedure

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh scratch --detect` → read
   `stack=`, `dev_url=`, `components=`, `lang=`. `stack=unknown` → ask which of
   `vite-react | vite-vue | next | nuxt | laravel` and pass `--stack`. Two stacks in
   one repo resolve to Laravel; override when the design belongs to the SPA.
2. Handoff bundle only: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/handoff-drift.py <dir>`
   and put the table in front of the user with one AskUserQuestion per `no token`
   row (adopt / map to nearest / leave as a gap). `references/handoff-bundle.md`
   says what to read in the bundle and what to ignore.
3. Consent, once per session (AskUserQuestion): the scratch files will be written
   into the project tree under `__design-kit__/` paths and removed after the pick.
   "Write the scratch entry (Recommended)" / "Show me the plan only". No write
   before the first option is chosen.
4. `dk.sh scratch --create <slug> --brief "<one line>"` → edit ONLY the files it
   printed as `wrote=`. `filled=` means the inventory pre-filled the page: keep the
   imports and the app stylesheet import, replace the strip with the composition, and
   keep any commented-out line until its required prop has real data. Start the dev
   server with `dev_cmd=` if it is not running, open `open=`. With no brief, the pick comes from
   `dk.sh decision --latest --consume` — the board's recorded artboard, knobs and edits.
5. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh drift <the files the scratch page added>`
   before showing the page, and fix each hit by reaching for the token instead. An
   empty design system exits 2 (`not measured`) — say so rather than reading it as
   clean. Then iterate on the scratch page while the user looks: one change per request, the
   dev server reloads. Take a screenshot when the environment offers one; say when
   it does not.
6. After the pick: record what was decided (which components, which variants,
   which tokens, any gap rows) in the reply and as one line via
   `dk.sh decision --record "…"` (→ `design-system/DECISIONS.md`), then run
   `dk.sh scratch --cleanup` and `dk.sh scratch --verify`. Verify failing means
   the turn is not done. The user may say "keep it" — then say in one line that
   `__design-kit__` paths remain and `--verify` will fail until they are removed.

## What this cannot do

- Render a stack it does not detect (Angular, SvelteKit, Rails views) — say so and
  fall back to `/design-kit:design` boards, which need no project.
- Prove the scratch page rendered — the browser does; the scripts only prove the
  files exist and later do not.
- Read a bundle format Anthropic has not documented — detection is lenient on
  purpose and says which files it read.
