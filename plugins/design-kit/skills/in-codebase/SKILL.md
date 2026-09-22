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
2. **Find components before writing any.** Read, in this order:
   `components=` from `--detect`; the library's index exports; Storybook stories
   (`*.stories.*` name every variant); the two closest existing pages; the design
   system in `design-system/` or the `## Design system` block in CLAUDE.md. A
   component you could not find is a question to the user, not a new file.
   Details: `references/finding-components.md`.
3. **Props come from the component, not the design.** Open the component's
   signature (types, `defineProps`, Blade `@props`) and pass only what exists. An
   invented prop renders as nothing and hides that the design asks for a variant
   the library lacks — surface that as a gap row instead.
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

## Procedure

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/codebase-scaffold.sh --detect` → read
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
4. `codebase-scaffold.sh --create <slug>` → fill ONLY the files it printed as
   `wrote=`, importing real components and providers. Start the dev server with
   `dev_cmd=` if it is not running, open `open=`.
5. Iterate on the scratch page while the user looks: one change per request, the
   dev server reloads. Take a screenshot when the environment offers one; say when
   it does not.
6. After the pick: record what was decided (which components, which variants,
   which tokens, any gap rows) in the reply, then run
   `codebase-cleanup.sh` and `codebase-cleanup.sh --verify`. Verify failing means
   the turn is not done. The user may say "keep it" — then say in one line that
   `__design-kit__` paths remain and `--verify` will fail until they are removed.

## What this cannot do

- Render a stack it does not detect (Angular, SvelteKit, Rails views) — say so and
  fall back to `/design-kit:design` boards, which need no project.
- Prove the scratch page rendered — the browser does; the scripts only prove the
  files exist and later do not.
- Read a bundle format Anthropic has not documented — detection is lenient on
  purpose and says which files it read.
