# Finding the real components

Read in this order and stop when the design's every element has a home. Each
source names what it proves and what it does not.

| Source | Proves | Does not prove |
|---|---|---|
| `design-system/components.json` (written by `/design-kit:system`; read by `--create`) | every component's source path, export kind, props with types/defaults/required flags, union variants, story names | anything listed under its `gaps` — a generic, an `extends`, an intersection or a spread the regex could not resolve; open the file it names |
| `components=` dir from `--detect` | where the library lives | that every export is current — check `git log -1` on a file that looks abandoned |
| Index exports (`src/components/index.ts`, `resources/js/Components/index.js`) | the public surface the app itself imports | variants and props |
| Storybook stories (`*.stories.tsx`, `*.stories.vue`) | every variant the team considered worth a story, with real args | that a story still matches the shipped component — run the story if Storybook is up |
| The two closest existing pages (same section of the app) | composition, layout wrapper, data-fetching shape, which provider stack a page needs | that those pages are the pattern to copy — they may be the legacy one; ask if two pages disagree |
| `design-system/` or the `## Design system` block in CLAUDE.md | token names and roles | component names |
| Blade `@props([...])`, `defineProps<...>()`, TS prop types | the props that exist | the visual result of each combination |

## Stack-specific reads

- **Vite React / Next.js**: component roots plus `app/(routes)/**/page.tsx` for
  layout wrappers; the providers a page needs are in `app/layout.tsx` or `main.tsx`.
  Import providers INTO the scratch entry; never register the scratch entry in them.
- **Vite Vue / Nuxt**: `components/` auto-import means an undeclared component
  renders silently as an unknown element — check the name exists before relying
  on it. Nuxt scratch pages get the default layout; pass `definePageMeta({ layout })`
  when the design needs another.
- **Laravel Blade**: anonymous components under `resources/views/components/`
  (`<x-name>`), class components under `app/View/Components/`, Livewire under
  `app/Livewire/`. The scratch view extends the real layout component — read which
  one `resources/views/layouts/` or the closest page uses.

## Gap rows

When an element has no component: write a `gap` line in the reply — element,
closest existing component, what is missing (a variant? a prop? a whole
component?) — and render the closest existing component with a visible label
"gap: <what>" on the scratch page. The user decides whether the library grows;
the scratch page never invents the component.
