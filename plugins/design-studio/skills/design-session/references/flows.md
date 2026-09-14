# Multi-page flows — pages, partials, and the flow record

A prototype is rarely one screen. Three files under `.design-studio/` carry the
rest, and the panel's **Go** tool walks them.

## Pages

One screen per `pages/<name>.html`, built from `assets/page-shell.html`. `/` is
`pages/index.html`. Links between screens are plain relative hrefs:
`<a href="/pages/reports.html">`. The page switcher in the panel lists every page
the server sees; nothing registers a page beyond the file existing.

Create a page when the user names a destination that has none ("link this to
Reports" with no `reports.html`): build it from the shell with the user's brief
or, without one, a titled empty shell — then say in the reply that it is empty.

**States are not pages.** Logged-out, empty, loading and error are variants of
one screen: a `data-state="empty"` on the page's root, with the variant's markup
inside it, and an edge whose `state` names it. Five files for one screen is drift.

## Partials

`partials/<name>.html` + `<!-- include: name -->` in a page. The server inlines it
on every request (three levels deep); a missing partial renders as a visible
`<!-- missing partial: … -->` comment. Use it for what every page shares — the
sidebar, the top bar — so one edit lands everywhere. The watcher reloads on
partial edits. The export inlines them so the folder opens from disk.

A gesture on an element inside a partial arrives with the page's selector; grep
`partials/` before `pages/` when the selector starts at a shared landmark.

## The flow record: `flow.json`

```json
{ "pages": ["index.html", "reports.html"],
  "edges": [ { "from": "index.html", "selector": "aside[data-td=\"sidebar\"] > a:nth-of-type(5)",
               "to": "reports.html", "label": "Reports", "state": null } ] }
```

You write it; the server only serves it (`GET /__td/flow`) so the panel can show
"Flows from this page". Keep it true:

- Adding or changing an href in a page or partial adds or updates the edge.
- A `message` with a selection that says "link this to X" → set the href, add
  the edge (create the page if missing), reply with both.
- A `navigate` event means the user walked `selector → to` from `page`. If that
  edge is missing from the record, the page had a link the record did not: add
  it and say so.
- Removing a link removes its edge; a page nothing links to is stated in the
  brief's Flows section as an orphan, not silently kept.

The brief renders the record as a mermaid graph (`references/export-targets.md`).
