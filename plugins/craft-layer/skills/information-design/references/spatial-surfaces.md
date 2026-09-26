# Spatial surfaces — maps, canvases, graphs, plans and pins

**The shared rule.** Every object the surface shows also exists as a focusable row in a list or
table, and the two stay in sync both ways:
- selecting a row highlights the object on the surface and pans it into view;
- selecting the object selects the row and scrolls it into view;
- the list is a visible, collapsible panel, not a hidden fallback: sighted keyboard users need
  it as much as screen-reader users.

The decorative-canvas rule (`aria-hidden` plus fallback content) is the wrong model when the
surface IS the data. 3D as a data view is covered in
`../../threejs-best-practices/references/data-3d.md`. Library choice is in
`product-packages.md`.

**Standing.** Each rule carries a tag:
- `recorded`: reached through `information-design`'s pointer. Nothing reads it back.
- `agent-graded`: the rule cites a WCAG 2.2 success criterion, which `/ui-ux:audit` judges.

The shared rule is `agent-graded` (SC 1.1.1, 1.3.1, 2.1.1). The "without it" failures are an
inference, not a measurement.

## Keyboard and non-drag routes

- **One tab stop.** The surface is a single tab stop. Inside it:
  - arrow keys move the selection between objects;
  - Enter opens the selected object and Escape clears the selection;
  - with an object selected, arrows nudge it one step (Shift for a larger step);
  - `+` and `−` zoom, and on-screen zoom buttons exist as well.

  `agent-graded` (SC 2.1.1)
- **A route that is not a drag.** Every pointer gesture has one (SC 2.5.7):
  - move: nudge with keys, or type coordinates in a properties panel;
  - connect: a "Connect to…" menu;
  - resize: numeric fields.

  `agent-graded`
- **A visible focus mark.** The selected object shows focus on the surface itself, not only in
  the list. `agent-graded` (SC 2.4.7)
- *Without it:* objects that exist only as pixels, and placement by mouse alone.

## Scale

- **Cluster, don't flood.** Past a few hundred markers or nodes, cluster in data space. MapLibre
  clusters a GeoJSON source natively (`cluster: true`), and `supercluster` covers other
  renderers. Each cluster marker states its count in text.
- **Pick the renderer by count.** Use DOM markers only for small counts, SVG up to hundreds, and
  canvas or WebGL beyond that.
- **Keep force layout off the render path.** Run it in a worker, or precompute it. Never
  restart the simulation on every component render.

`recorded`

## Maps

- **Client-only import.** Map libraries touch `window` when imported. Load them from a client
  component through a dynamic import (`next/dynamic` with `ssr: false` in Next.js).
  - Create the map once in an effect, keep the instance in a ref, and call `remove()` on
    unmount. Never remount it on every render.
  - MapLibre GL JS 6 is ESM-only and needs WebGL2.
  - `recorded`
- **Wheel zoom without hijacking the page scroll.** A map embedded in a scrolling page must not
  swallow the wheel. Use one of:
  - `cooperativeGestures` (MapLibre: zoom needs Ctrl or ⌘ with the wheel; touch pans with two
    fingers);
  - `scrollWheelZoom: false` (Leaflet) until the map is clicked or focused.

  Keyboard zoom stays on. `recorded`
- **Restricted tile tokens.** A token in client code is public. Scope it to read-only
  styles and tiles, and URL-restrict it where the provider allows. Mapbox's public-token URL
  restriction is best-effort by its own docs, so never ship a secret-scoped token
  (`secret-scanning:secret-scanning`). `recorded`
- **Markers.** A custom-element marker in MapLibre is not focusable by default: you own its
  `tabindex`, role and name. Leaflet markers take `keyboard`, `alt` and `title`. The list twin
  shrinks this burden without removing it. `agent-graded` (SC 4.1.2)

## 2D canvas editors (layout builders, whiteboards, floor planners)

- **World coordinates.** Store positions in world units. Do snapping, collision and grid maths
  in world units, and convert to screen pixels only at render, through the view transform.
  - *Without it:* snapping done in screen pixels breaks at every zoom level.
  - `recorded`
- **Canvas libraries give no accessible DOM.** Konva states it creates no accessible DOM for its
  shapes, and Fabric documents none. The list twin and a properties panel are how those objects
  exist for assistive technology. `agent-graded` (SC 4.1.2)
- **Undo for every mutation**, per `app-craft-floors.md` §6. `recorded`

## Node graphs and flow editors

- **Read-only graphs** (dependency, lineage, topology): the table twin lists each node with its
  edges ("api → depends on db, cache"). Edges have names ("Trigger to Filter"). `agent-graded`
  (SC 1.1.1)
- **Editable flows.** Use a flow library rather than hand-drawn edges.
  - React Flow ships focusable nodes and edges, arrow-key moves for selected nodes, and a live
    region announcing those moves. Localise its text with `ariaLabelConfig`, and never set
    `disableKeyboardA11y`.
  - You still owe the route to connect nodes without dragging, and the node table.
  - `agent-graded` (SC 2.5.7)

## SVG plans (seats, floors, sites)

- **Each region is a control.** It has a role (a button, or a checkbox for a selectable seat), a
  name ("Row F, seat 12") and a state (`aria-pressed`, `aria-checked` or `aria-disabled`).
  Availability shows as text plus pattern, never colour alone. `agent-graded` (SC 4.1.2, 1.4.1)
- **Hundreds of regions.** Make the plan one tab stop with arrow-key navigation, and add a
  list-and-filter route ("2 adjacent seats, rows D–F"). `agent-graded` (SC 2.1.1)
- **Zoom.** Zoom through buttons and the `viewBox`, never by re-laying out the plan. `recorded`

## Annotation pins and anchored comments

- **Anchor in data space.** Pins anchor to the data, never to screen pixels, which drift on
  zoom, resize and reflow. Depending on the medium, that is:
  - a document node id plus an offset;
  - an image coordinate normalised to 0–1;
  - a video timestamp;
  - a world coordinate.

  `recorded`
- **Create from the keyboard.** "Add comment here" at the current selection, not only by click.
  `agent-graded` (SC 2.1.1)
- **Pins and comments are linked.** Every pin is numbered and listed in a comments panel.
  Selecting either one selects the other, and they share a programmatic link
  (`aria-describedby` or a shared id). `agent-graded` (SC 1.3.1)
