# Export — the four deliverables

Run on `end`, on `/theme-design:export`, or when the user asks in chat. Offer the
four as one multi-select AskUserQuestion with the ones already chosen at `init`
pre-stated; write only what was picked. Everything lands under
`.theme-design/export/<YYYY-MM-DD>/` except the direct write, which touches the
project.

## 1. `tokens.css`

Copy `.theme-design/tokens.css` as is — it is already the deliverable. Before the
copy, check every `:root` token has a `.dark` twin where the light one is a colour
(`grep -c` both blocks; the counts match or the export says which are missing) and
that `--foreground` on `--background` and `--primary-foreground` on `--primary`
each pass 4.5:1 in BOTH variants. A failing pair is reported, not silently fixed:
the user chose those colours in the session.

## 2. Prototype pages

Copy `.theme-design/pages/*.html`, `.theme-design/skin.css`, and the shipped
`server/icons.svg` and `server/charts.js` from `${CLAUDE_PLUGIN_ROOT}` (as
`icons.svg`, `charts.js`; rewrite `/icons.svg#` and `/charts.js` to `./`). If the
session ended with rich on, add `data-rich` to `<html>` in the copies — the
server injected it live and the folder has no server. They are clean on
disk — the editor is injected at serve time and never written — so no stripping
step exists. Inline every `<!-- include: name -->` from `partials/` (the server
did this at serve time; the folder has no server), rewrite `/tokens.css`,
`/skin.css` and `/pages/x.html` links to `./tokens.css`, `./skin.css` and
`./x.html` so the folder walks from the filesystem, and name the skin in the
brief's Direction as a lookalike, not the library.
Proxy-mode sessions have no pages; say so instead of exporting an empty folder.

## 3. Design brief (`brief.md`)

From `.theme-design/decisions.md` (one line per accepted change) and
`transcript.md` (the conversation). Sections, in this order, each a short list:

- **Direction** — the two or three sentences the session converged on.
- **Layout** — per page/screen: structure, hierarchy, what moved and why.
- **Tokens** — the sheet's role names with their light/dark values, and every
  token added during the session with the reason.
- **Flows** — `flow.json` as a mermaid `graph LR` (page nodes, edge labels from
  `label`, `state` in brackets), then one line per orphan page. Omit the section
  only when the session has one page.
- **Components and states** — anything the user named as a repeated element.
- **Open questions** — every question asked in a reply that got no answer.

Quote the user where a decision was theirs; never invent a rationale for a gesture
that came without one — write "moved, no reason given".

## 4. Direct write into the project's theme file

Detect the target from the manifest, all signals before deciding:

| signal | target | mapping |
|---|---|---|
| `components.json` (shadcn/ReUI/Aceternity) | the file `tailwind.css`/`globals.css` in `components.json` points at | same names; replace the `:root` and `.dark` blocks |
| Tailwind v4, no `components.json` | the CSS with `@import "tailwindcss"` | wrap as `@theme { --color-primary: var(--primary); … }` after the token blocks |
| Tailwind v3 | `globals.css` + `tailwind.config.*` `theme.extend.colors` | tokens as CSS variables; config maps `primary: "var(--primary)"` |
| Bootstrap Sass | the partial before `@import "bootstrap"` | hand-map `$primary`, `$body-bg`, `$body-color`, `$border-radius`; say the rest has no Bootstrap twin |
| `@astryxdesign/core` | the `defineTheme()` file | light/dark tuples; follow the project's existing shape |

Show the diff and ask "Apply (Recommended)" / "Skip — keep the export only" before
writing. When the ui-ux plugin is installed, its `shadcn-theming` reference
`token-vocabularies.md` carries the per-stack traps in more depth; read it for
Bootstrap and Astryx.
