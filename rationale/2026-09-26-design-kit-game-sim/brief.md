# The brief — raw, and improved

## 1. Raw (the user's words, run 1)

```
/design-kit:design a tic tac toe high res 2D sprites game
```

Ten words. It names a subject and an asset class, no audience, no metric, no device, no
visual language, no motion intent, no content. Every one of those became the drafter's guess.

## 2. Improved (runs 2 and 3)

Derived line by line from `research.md`; each clause traces to a shard's "brief lines". Written
as the argument to `/design-kit:design`, so it is one paragraph plus the two flags the command
parses. The same text is the control arm's prompt.

```
/design-kit:design --screens 3 --device phone Sprite tic-tac-toe: a two-player hot-seat game
(two people, one phone or one laptop, 30-second rounds) where the marks are two hi-res 2D
sprite CHARACTERS, not letters. Audience: two friends, or a parent and child. The one thing it
must make easy: see whose turn it is and place a mark in one tap. Diverge on structure, not
palette: (a) what the first screen is — board immediately vs character pick first; (b) where
turn and result feedback lives — a HUD banner, the sprites themselves reacting, or the board
surface; (c) how a win is announced — in-place winning line plus celebration vs a result
sheet. Sprites: two characters built from a three-shape vocabulary (rounded rectangle,
circle, rounded triangle), inline SVG, each with idle / placed / win / lose states; on every
artboard show one cell mid-pop (placed) and the winning line in the win state, so the motion
intent reads on a still frame, and annotate durations beside them: place-in ≤ 300 ms spring
with bounce ≤ 0.3, press 100–160 ms at scale 0.97, stagger 30–80 ms for the board reveal,
reduced-motion = opacity fade, never a frozen board, transform/opacity only. Visual language:
calm neutral base, two saturated player accents a colour-blind player can tell apart
(blue/orange class), marks distinct by silhouette and weight not hue; one named open-licence
display face for title and result (Fredoka or Bricolage Grotesque) and one plain rounded UI
face for the HUD; tabular numerals on the score; HUD text ≥ 4.5:1, marks may sit at APCA
Lc 45; no purple-blue gradient, no all-caps eyebrow, no 01/02 step markers, no emoji as icons,
no glass panels, no bounce-on-every-hover. Real content: players Mara and Tomasz, score 2–1,
round 4, Mara's diagonal win, the rematch button naming who starts next ("Rematch — Tomasz
starts"); after a result the rematch is the primary action and takes focus. Board =
min(80vw, 60vh, 420px), cells ≥ 44 px at 375 px wide, turn banner is a live region, each
cell's accessible name is "Row r, column c, empty | Mara | Tomasz".
```

## 3. What the improvement is made of

| clause | source line |
|---|---|
| hot-seat, two people, one device, 30-second rounds; parent and child | prior overseer charter for `../tictactoe-sprites-test` (2026-09-12), the only in-house statement of this product |
| the one metric (see turn, place in one tap) | SKILL.md step 1 demands it; the raw brief had none |
| three structural axes named | SKILL.md step 2 names only SaaS axes; shard A: "a named minimal shape vocabulary … a named placement juice mechanism" |
| three-shape vocabulary, four sprite states | shard A (Duolingo shape language, t1); overseer charter's idle/placed/win/lose |
| show placed + win state on a still frame, annotate durations | shard C: static HTML can carry inline keyframes; durations from Kowalski STANDARDS.md (t2) |
| blue/orange class, silhouette not hue | shard D (colorcontrast.org, t3) |
| APCA Lc 45 for marks, 4.5:1 for HUD | shard D (APCA docs, t1); shard B (gameaccessibilityguidelines, t2) |
| Fredoka / Bricolage Grotesque + rounded UI face; tabular numerals | shard B |
| rejection list | shards B and D (925studios 2026-09-23; smoothui 2026-06-24; the four horsemen) |
| Mara/Tomasz, 2–1, round 4, "Rematch — Tomasz starts" | SKILL.md "real content" rule; the loser-starts convention from the overseer charter |
| board size, 44 px cells, live region, cell names | overseer charter must-haves 6–7 and its live-region decision |

## 4. Control prompt (run 3, no plugin)

The same paragraph, prefixed so a bare model produces a comparable artifact:

```
Draft 3 UI directions for the brief below as artboards side by side in ONE self-contained HTML
file at control/board.html (no external assets, no CDN, no lorem). Each artboard: a title, a
one-line trade-off, and a 375×812 phone frame. Then print one line per artboard.
Brief: <the paragraph above>
```
