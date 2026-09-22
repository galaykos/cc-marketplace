# Artboard primitives

Every artboard body is plain HTML using these classes. The shell (`assets/board-shell.html`)
styles them from the knob variables (`--dk-space`, `--dk-radius`, `--dk-accent-h`,
`--dk-type`, `--dk-density`, scheme), so a knob move restyles every primitive at once.
Hand-written CSS in a body is allowed via the spec's `css` field but escapes the knobs —
use it for the one signature element, not for layout.

Fill each primitive with the product's real words and numbers. The builder rejects
"lorem ipsum" and any external `src`/`href`/`url()`/`@import`; a board renders with the
network off.

## Layout

| Class | Use |
|---|---|
| `dk-pad` | page padding |
| `dk-stack` | vertical rhythm (`gap` = 2 × space) |
| `dk-row` (+ `between`) | horizontal cluster; `between` spreads ends |
| `dk-grid` | responsive card/stat grid, 160px minimum column |
| `dk-sidebar` | `<div class="dk-sidebar"><nav>…</nav><div>…</div></div>` — 220px rail + content, fills the frame |

## Navigation

```html
<nav class="dk-nav"><span class="brand">Ledgerly</span><a href="#" aria-current="page">Inbox</a><a href="#">Paid</a><span class="spacer"></span><button class="dk-btn small">New invoice</button></nav>
<nav class="dk-tabbar"><a href="#" aria-current="page">Queue</a><a href="#">Paid</a><a href="#">Settings</a></nav>
<div class="dk-tabs"><a href="#" aria-current="page">All</a><a href="#">Overdue</a></div>
```

`dk-nav` sticks to the top; `dk-tabbar` sits at the frame's bottom on phones. Mark the
current item with `aria-current="page"`.

## Content

```html
<section class="dk-hero split"><div class="dk-stack"><h1>Headline</h1><p class="muted">One sentence of substance.</p><a class="dk-btn" href="#">Primary action</a></div><div class="visual"></div></section>
<div class="dk-card"><h3>Title</h3><p class="muted">Meta</p><p>Body</p></div>
<ul class="dk-list"><li><span class="avatar">NT</span><span class="grow">Primary line</span><span class="dk-badge warn">Due soon</span></li></ul>
<div class="dk-stat"><span class="label">Awaiting approval</span><span class="value">€48,210</span><span class="delta up">+12% this week</span></div>
<table class="dk-table"><tr><th>Vendor</th><th class="num">Amount</th></tr><tr><td>Northwind Traders</td><td class="num">€1,240.00</td></tr></table>
<div class="dk-media">PDF preview</div>
```

`dk-hero` variants: default (left), `center`, `split` (text + `visual` block). Badges:
`dk-badge` plus `ok` | `warn` | `danger`. `dk-media` is the image/chart placeholder — label
it with what it would show.

## Forms and actions

```html
<form class="dk-form"><div class="dk-field"><label for="cc">Cost centre</label><input id="cc" class="dk-input" value="OPS-22"><span class="hint">Required for approval</span></div><button class="dk-btn">Approve €1,240.00</button></form>
<div class="dk-field"><label for="e">Email</label><input id="e" class="dk-input" aria-invalid="true" value="ivan@"><span class="err">Enter a full address</span></div>
<button class="dk-btn ghost">Secondary</button> <button class="dk-btn small">Compact</button>
```

Buttons and inputs are 44px tall by default (`small` is 34px): the touch-target floor.
Button text says what happens ("Approve €1,240.00"), never "Submit".

## States

```html
<div class="dk-empty"><h3>No invoices yet</h3><p>Forward one to inbox@ledgerly.app and it appears here.</p><button class="dk-btn">Add manually</button></div>
<div class="dk-loading"><span class="dk-skeleton" style="width:60%"></span><span class="dk-skeleton" style="width:40%"></span></div>
<div class="dk-error"><h3>Couldn't load the queue</h3><p>Ledgerly can't reach the bank feed. Try again or work offline.</p></div>
<div class="dk-dialog"><div><h2>Approve 12 invoices?</h2><p>€48,210 goes out on Friday.</p><div class="dk-row"><button class="dk-btn ghost">Cancel</button><button class="dk-btn">Approve all</button></div></div></div>
```

An empty state invites an action; an error names what went wrong and what to do; a
dialog's confirm button repeats the consequence. `dk-dialog` overlays the frame — put it
last in the body, and only in one artboard per board or every direction reads the same.

## Type and helpers

`h1` 1.9em, `h2` 1.35em, `h3` 1.05em, all scaled by the type knob; `.muted` for secondary
text. Keep body lines under ~80 characters; the `desktop` frame is 1280px wide, so wrap
long text in a column (`max-width` via the spec's `css` field) rather than letting it run.
