# Event protocol — what the browser sends, what each becomes

Every event is one JSON line in `.theme-design/events.jsonl`, with `seq` (monotonic),
`ts`, `page` (path), `tool` (the panel tool active), and for element events the
`describe()` block: `selector`, `tag`, `text` (first 80 chars), `rect` `{x,y,w,h}`
in page coordinates, and `computed` `{color, background, font, padding, margin,
radius}` as the browser computed them BEFORE the gesture.

| type | extra fields | it means | edit it becomes |
|---|---|---|---|
| `message` | `text`, optional `selector` | chat; selector = element selected when sent | whatever the text asks, scoped to the selector when present |
| `select` | describe | the user pointed at something | nothing on its own; context for the next event |
| `annotate` | describe, `text` | a note bound to an element | a scoped brief — treat as `message` about that element |
| `move` | describe, `dx`, `dy`, `drop` `{target, position: before/after, sibling}` or null | dragged and dropped | with `drop`: reorder in the DOM (`sibling:true`) or move into a new parent; without: a layout change in the direction of the delta |
| `resize` | describe, `to` `{w,h}` | corner-handle drag | width/height, column span, basis, padding or aspect, per the element's role |
| `text` | describe, `before`, `after` | inline text edit | replace the content verbatim |
| `style` | describe, `property` (`color` or `background-color`), `value` hex | colour picked in the inspector | the nearest token, or a new one, or the element alone when told "just this" |
| `skin` | `name` | the panel's skin selector, already applied by the server | no edit; note the preference in `decisions.md` (`references/skins.md`) |
| `end` | – | End session pressed | export, then stop |

## Reading a batch

- Order is arrival order. Later events on the same selector supersede earlier ones
  of the same type; a `text` and a `style` on one element are both real.
- `computed` values are the browser's, e.g. `rgb(37, 99, 235)`. Match them to
  `tokens.css` by converting; a match means "this came from that token".
- `rect` is where the element WAS. For `move` without a drop, `rect + (dx,dy)` is
  where the user wanted it; the nearest layout that puts it there wins.
- `page` tells which file (html mode) or which route (proxy mode) the gesture was
  on. Do not apply a gesture from `/pages/pricing.html` to `index.html`. In html
  mode `/` is `pages/index.html`: the root serves it directly.

## Selector shape

`#id` when the element has one; otherwise a chain of up to five
`tag.class1.class2:nth-of-type(n)` segments, cut short at the first ancestor with a
`data-td` or `data-testid` attribute. Editor-owned classes (`__td-*`) are never
included. When you generate a page, give landmarks and repeated blocks a `data-td`
so regenerating the page does not change the selectors the user has been clicking.

## Replying

`POST /__td/reply` with `{"text": "...", "reload": true|false}` and the
`X-Theme-Design: 1` header. `text` is broadcast to the panel and appended to
`transcript.md`; `reload:true` reloads every open tab of the session. In `html`
mode the file watcher already reloads on save, so `reload` there is only for a
change the watcher cannot see (an image swapped under the same name is one).

## Cursor discipline

`/__td/next` marks its batch consumed by writing `.theme-design/cursor`. The prompt
hook writes the same file when it injects events into a terminal turn. Read events
from ONE surface per turn; if a terminal prompt arrived with injected events, do not
also poll until those are applied.
