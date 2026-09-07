# ASCII wireframe patterns

The monospace vocabulary for the **Quick ASCII only** fidelity tier — one shared
convention set so every wireframe in a session reads the same, not an improvised
box each time. Draw in a fenced block; keep it structural, never decorative.

## Boxes, split panes, column grids

Frame with `+`, `-`, `|`; split a pane with an interior `+---+` seam; a column
grid is repeated equal-width cells on one row.

```
+-----------------------------+   +-------+-------------------+   +----+----+----+
| single frame                |   | left  | right pane        |   | c1 | c2 | c3 |
+-----------------------------+   +-------+-------------------+   +----+----+----+
        one region                   split pane (2-up)              3-column grid
```

## Flow arrows: branch and loop

Inline `->` for a linear step; label a branch with its condition; a loop arcs
back on its own line with a `^----+` rail and a `(loop …)` note.

```
login -> otp -> dashboard                     (linear)
           +-- ok? yes --> dashboard
checkout --+                                   (branch)
           +-- ok? no  --> retry
draft -> review -> publish
           ^-----------+  (loop: back to review on reject)
```

## Selection and active-state markers

- Selected row: leading `>` (`> Row two`); unselected rows indent two spaces.
- Active tab: `[Tab]` in brackets; inactive tabs bare (`Tab`).
- Checked / toggled: `[x]` on, `[ ]` off; radio `(o)` on, `( )` off.

```
Tab one  [Tab two]  Tab three          > Inbox (12)
                                         Archive
```

## Emphasis and element vocabulary

- **CAPS** — the primary action / emphasized element: `SAVE`, `CHECKOUT`.
- `(@)` — an avatar or account glyph.
- `[input]` — a text field (`[Search...]`, `[email]`).
- `<btn>` — a secondary button (`<Cancel>`, `<Back>`).

```
| (@) Jordan     [Search...]           <Filter>   SAVE |
```

## State annotation suffixes

Append a pane's state to its label so one wireframe shows the per-state delta:

- `(empty)` — no-data / zero state.
- `(loading…)` — pending fetch.
- `(error!)` — failed state.

```
| Results (empty)  |   | Results (loading…) |   | Results (error!) |
```

## Numbered callouts (mirrors the shell's callout↔tradeoff pairing)

Just as a shell mockup pins a `data-n` badge to its numbered tradeoff bullet,
an ASCII wireframe pins `(1)`, `(2)` inside the drawing to a numbered tradeoff
list below — same number, same claim, so the pick reads by number.

```
+----------+----------------+
| Nav (1)  |  Feed (2)      |
+----------+----------------+
(1) fixed sidebar — one-tap reach, costs width
(2) single column — full-bleed cards, no peek at siblings
```

## Two worked examples (equal detail, one-line tradeoff caption)

```
+----------------------------+   +----------------------------+
| Logo   [Search]      (@)   |   | Logo                 (@)   |
+------+---------------------+   +----------------------------+
| Nav  |  Card  Card  Card   |   |  List item ...........     |
| (1)  |  Card  Card  Card   |   |  List item ........... (2) |
+------+---------------------+   +----------------------------+
     A: sidebar + grid                 B: topbar + list
A — scan-many: nav always in reach (1), density up front.
B — read-one: full width per row (2), nav one tap away.
```

```
step 1 -> step 2 -> DONE        1  2  3  [REVIEW]  ->  DONE
     A: linear stepper                B: tabbed sections
A — one path, no skipping; long forms feel endless.
B — jump between sections; easy to submit half-done.
```
