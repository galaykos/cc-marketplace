# design-kit against a game brief — simulation of 2026-09-26

**Plugin this serves:** `design-kit` (`/design-kit:design`). Question: what does the board
drafter produce when the brief is not a SaaS screen but a **tic-tac-toe game with high-res 2D
sprites**, and which of its rules, primitives and knobs stop carrying their weight there?

Fixture: `../design-kit-sim-tictactoe/` (empty git repo, no tokens, no components). Runs are
headless `claude -p --plugin-dir ../cc-marketplace/plugins/design-kit` sessions; logs and the
built boards stay in the fixture (`runs/`, `.design-kit/boards/`). Standing of everything
here: **recorded** — n=1 per arm unless a row says otherwise.

| file | what |
|---|---|
| `README.md` | this: static review, run table, findings, what changed in the plugin |
| `research.md` | the four research shards (visual style, typography, motion, graphic conventions), claims with sources |
| `brief.md` | the raw prompt, and the improved brief derived from the research |

## 1. Static review — what the files say before anything ran

Read: `commands/design.md`, `skills/design/SKILL.md`, `references/primitives.md`,
`references/spec-format.md`, `assets/board-shell.html`, `scripts/board-build.py`.

1. **The primitive set is SaaS-shaped.** `dk-nav`, `dk-table`, `dk-stat`, `dk-list`, `dk-card`,
   `dk-form`, `dk-empty/loading/error`, `dk-dialog`, `dk-hero`. Nothing names a board, a grid of
   equal cells, a HUD, a character slot or a turn indicator. `dk-media` is the only visual
   placeholder and it is a labelled grey box. A game body is therefore hand-written CSS, which
   the skill itself says the knobs ignore.
2. **Typography is one system stack and a size multiplier.** `--dk-font` is the tokens file's
   face or `system-ui, …`; there is no display face and no way to load one — the builder's
   `EXTERNAL` gate blocks `@import`, `<link>` and any `//` URL, and a base64 `@font-face` would
   pass the regex at ~100 KB per weight. For a game the display face is a direction-level
   decision, and the board cannot show it.
3. **The divergence axis is defined for tools.** SKILL.md step 2 names "navigation model,
   information hierarchy, density, primary action placement". None applies to a 3×3 board. The
   axes a game brief needs — mark style, feedback model, board-first vs lobby-first, what the
   idle screen does — are not named, so the model must invent them or fall back to layout.
4. **Motion can be shown but nothing says so.** Inline `<style>` with `@keyframes` and inline
   SVG pass the gate; Lottie/Rive/sprite sheets cannot (no `<script src>`, no external file).
   The skill treats artboards as still mockups ("Mockups are for deciding"), so a brief whose
   substance is motion gets a static frame and, at best, prose about motion.
5. **Device default.** `desktop` unless the brief says mobile/app/phone. "Game" is not in the
   list; tic-tac-toe is phone-first.
6. **Real-content rule has no game reading.** The lorem gate cannot see "Player 1 / Player 2" or
   a placeholder "X"; the skill's own example (a 34-character vendor name) has no equivalent
   for a mark, a score, a character.
7. **One accent hue.** The knob rotates a single accent; a two-player game needs two opposing
   colours that a colour-blind reader can tell apart, and the shell has one.
8. **A11y floor is nav-shaped.** 44px targets and visible focus apply; `aria-current` on nav
   and labels bound to inputs do not; nothing mentions non-colour win cues, `aria-live` for
   the turn banner, or the cells' accessible names.
9. **`dk-hero .visual` ships a gradient wash**, which the skill's "default tells" list forbids as
   decoration.
10. **In `-p` mode** the consent gate is absent and the command takes the recommended default,
    as in the 2026-09-22 simulation.

## 2. Runs

| # | arm | brief | result |
|---|---|---|---|
| 1 | plugin, raw brief | `a tic tac toe high res 2D sprites game` | 3 desktop artboards, built twice (the second build patched a shell bug the model found); log `runs/01-raw-brief.log`, PNGs `.design-kit/boards/2026-09-26-tic-tac-toe-sprites-board-{1,2,3}.png` |
| 2 | plugin, improved brief | `brief.md` §2 | 3 phone artboards, one build; log `runs/02-improved-brief.log`, PNGs `.design-kit/boards/2026-09-26-sprite-tic-tac-toe-board-{1,2,3}.png` |
| 3 | no plugin, improved brief (control) | `brief.md` §2 | one HTML file, 3 phone artboards with a spec header; log `runs/03-control.log`, `control/board.html`, `control/board.png` |
| 4 | plugin **0.7.0**, raw brief, same fixture | as run 1 | 3 phone artboards, characters with states, `dk-cells`/`dk-note`/`--dk-accent-2` used; **confounded**: run 2's spec was on disk and the names, score and durations came back verbatim; `runs/04-raw-brief-0.7.0.log`, `evidence/2026-09-26-tic-tac-toe-with-sprites-board-{1,2,3}.png` |
| 5 | plugin **0.7.0**, raw brief, **clean fixture** | as run 1 | 3 phone artboards; Noor (Zig, a cross with a face) vs Felix (Bubble, a ring), idle/placed/win/lose, blue/orange via `--dk-accent-2`, `dk-cells`, a `dk-note` per artboard with durations, reduced-motion swap and the shipped-asset plan (512 px PNG per state at 1×/2×/3×, or Rive), "Display face: decide it in tokens.json; the board cannot load one"; no nav, sidebar or table; `runs/05-raw-brief-0.7.0-clean.log`, `evidence/clean-2026-09-27-tic-tac-toe-sprites-board-{1,2,3}.png` |

## 3. Findings

### Run 1 — the plugin with the raw brief (what the drafter does unaided)

The three artboards, read from the PNGs:

1. **Arcade table** (desktop 1280×800): a 3×3 of stroked X and O glyphs, X in the accent blue,
   O in the foreground black, on `dk-surface` cells; one HUD line at the bottom — "Undo last
   move · Turn 6 of 9 · 00:41 · Forfeit game". Roughly 40% of the frame is empty.
2. **Sprite stage**: a `dk-nav` ("Noughts · Play · Sprites · Leaderboard · Invite a friend"
   accent button), the board at half width, and a `dk-card` "Piece set: Neon Ink — 2048 × 2048
   sprite atlas, 12 frames per mark" showing four X's at rising opacity as "frames", tabs for
   Chalk / Woodcut / Paper cut, "Use Neon Ink" and "Preview on board" buttons.
3. **Match hub**: a `dk-sidebar` lobby (Current match, Quick play, Friends (4 online), Piece
   sets, Settings, Recent games with avatars and ±rating chips), two `dk-stat` tiles (Series
   4–2, Rating 1,462 +18), a `dk-table` move log (Move / Player / Square / Time), a "Ranked ·
   best of 7" pill badge, and a `dk-dialog` "Mira wins the series 4–2 — Back to lobby / Rematch
   Tomasz".

What that shows, each tied to a line in §1:

- **F1 — "sprite" became a glyph.** Every mark is a stroked path in the shell's accent; there is
  no character, no state, no motion. The model's own summary calls it "the inline SVG X/O
  sprite that follows the accent-hue knob". Nothing in the skill says a sprite is a drawn thing
  with states (§1.1, §1.4).
- **F2 — the SaaS idiom walked in through the primitives.** Direction 2 is a nav bar and a
  settings card; direction 3 is a CRM (sidebar, stat tiles, data table, pill badge, dialog).
  The primitives are the only vocabulary the skill offers, so two of three "structural
  answers" are the shell's own furniture with a board dropped in (§1.1, §1.3).
- **F3 — invented mechanics stand in for real content.** A move timer ("00:41", "00:12 left"),
  "Turn 6 of 9", undo, forfeit, a rating system, a best-of-7 series, an online friends list.
  The "real content" rule was read as "invent detail", because the brief gave none and the
  skill's example of real content is an invoice (§1.6).
- **F4 — desktop.** A tic-tac-toe on a 1280-wide frame; direction 1 is mostly whitespace
  (§1.5).
- **F5 — one accent.** X is the accent, O is black; the hue knob moves one player (§1.7).
- **F6 — system type throughout.** No display face on any artboard; the score in direction 3 is
  the `dk-stat` value style (§1.2).
- **F7 — no motion, on a brief about sprites.** Zero `@keyframes`; the "frames" in direction 2
  are four opacities (§1.4).
- **F8 — a shell defect, found by the run itself.** `.dk-frame` has no `position`, so
  `.dk-dialog` (`position:absolute; inset:0`) escaped its artboard onto the canvas; the model
  patched it in the spec's `css` and named it as a plugin bug. Confirmed by grep: no
  `position` on `.dk-frame`, `.dk-screen` or `.dk-board` in the shell; no harness case
  mentions a dialog. Fixed in §4.

### Run 2 — the plugin with the improved brief

Three 375×812 frames, all at Mara's diagonal win in round 4, score 2–1, the last cell frozen
at scale 1.08 with "280 ms · bounce 0.25" pinned to it, "Rematch — Tomasz starts" as the
focused primary, and a footer of durations (place-in, press, reveal stagger, win line,
reduced motion, transform/opacity only) on every artboard:

1. **Board first, HUD banner** — the banner is the live region and swaps to the result in
   place; trade-off: the celebration competes with the rematch for the eye.
2. **Pick characters, sprites react** — the pick is the first screen (shown folded as a strip),
   two dock sprites carry turn and result, a bottom sheet announces the win; trade-off: a
   screen before play and a sheet over part of the board.
3. **Board surface is the HUD** — a 6px rim in the active colour and a label above the board
   carry turn and result, losing cells sink to 40%; trade-off: the rim is the only cue.

Two characters, Bloop (rounded rectangle + circle, heavy) and Spike (rounded triangle,
light), in inline SVG with idle/placed/win/lose poses. The second accent was derived by the
model as `hsl(calc(var(--dk-accent-h) + 170) …)` so the hue knob rotates both. Annotations
were hand-written as `.tt-annot` (11px, muted, dashed left rule). `tabular-nums` on scores.
Fredoka and Bricolage Grotesque were named first in a font stack and rendered as the system
face, because nothing can load a font through the offline gate.

Every finding F1–F7 from run 1 is absent here. The brief did that, not the plugin: none of
the rules that changed between the runs live in the skill, all of them live in `brief.md`.

### Run 3 — the base model with the improved brief and no plugin

One 36 KB HTML file. A header of four spec cards — Type (Fredoka / Bricolage, Nunito, tabular
score, "no fonts are loaded"), Colour (paper, ink 14.5:1, Mara text 5.8:1, Tomasz text 5.0:1,
marks ≈ APCA Lc 50–55, "marks differ by silhouette … and weight … so hue is redundant"),
Motion (260 ms spring bounce 0.25, press 120 ms to 0.97, stagger 45 ms, win line 240 ms,
reduced motion 160–200 ms fade), Accessibility (board = min(80vw, 60vh, 420px), cells 89 px
at 375, live region, cell names, rematch takes focus). Then three phone frames — Straight in /
Pick, then play / Tabletop (a 180°-rotated far rail so both players read their own side) —
each with a second thumbnail of its first screen, numbered callouts on the frame, and four
real `@keyframes` behind a `prefers-reduced-motion` guard. Pip (drop) and Tok (cat) as inline
SVG characters with poses.

Set beside run 2, it is at least as good a design and a better spec. What it does not have
is everything the plugin IS: a pan/zoom canvas, editable text, knobs, "Pick this" posting to a
loopback route, `dk decision` reading it back, the lorem/external gates, the gallery, the
tokens stamp. It also could not be opened by `/design-kit:in-codebase`.

### What the three runs say together

- **The brief is the lever.** Raw brief → a CRM with a board in it. Improved brief → two drawn
  characters with states on phone frames, with or without the plugin. Every design-quality
  delta here is attributable to `brief.md`, and the plugin's design rules did not move it.
- **The plugin's admission is the mechanism, not the taste.** Knobs, the decision channel, the
  gates, the hand-off to in-codebase. That is what the README already claims; this simulation
  is the first time the taste half was measured against a control, and it did not earn its
  place on this brief.
- **So the skill should carry the brief.** The user will not type 2,000 characters of research.
  What can be carried as rules the drafter gets wrong from memory: the game-shaped divergence
  axes, sprite ≠ glyph, motion on a still frame, real content for a game, the second accent,
  phone for a game. What cannot: a display face (gate), Lottie/Rive on the board (gate), the
  specific research (a face name, a duration) — those stay in the brief or the token file.
- **The shell was missing three things both runs hand-wrote:** a positioned frame, a second
  accent, an annotation style. Run 1 also hand-wrote a cell grid; run 2 did too.

What run 1 did well, so the findings are not one-sided: real names (Mira, Tomasz), a 3–2 /
4–2 series score, cells well above 44 px, the trade-off lines are honest ("busiest screen,
slowest to first move"), and it stopped at the consent gate with an accurate statement of
what it could not do without a person.

## 4. What changed in the plugin (design-kit 0.6.1 → 0.7.0)

| change | trigger | standing |
|---|---|---|
| `.dk-frame{position:relative}` | F8, the dialog escaping its frame in run 1 | **gate** — `board-build.test.sh` asserts it |
| `--dk-accent-2` (hue + 170°), `dk-cells`, `dk-cell` (`p2`, `win`), `dk-note` in the shell; a "Play, and notes on the frame" section in `primitives.md` | F5, F7; both runs hand-wrote a cell grid, run 2 hand-wrote the accent derivation and the annotation style | **gate** for presence in a built board; **recorded** for use |
| SKILL.md step 2: the axes a game/toy/character brief diverges on; "a nav, sidebar, stat tile or data table on such a brief is the primitive set leaking in" | F2 | **agent-graded** |
| SKILL.md rules: a sprite is a character, not a glyph; motion has to read on a still frame; real content for a game; the board cannot show a display face | F1, F3, F6, F7 | **agent-graded**; the font one is a stated **gate-imposed limit** |
| SKILL.md knobs paragraph: the hue knob rotates both accents | F5 | recorded |
| `commands/design.md` step 1: game, play → `phone` | F4 | recorded |
| `CHANGELOG.md` 0.7.0 | — | gate (changelog coverage) |

Not changed, and why: no font loading (the offline gate is the product; a base64 face is
~100 KB per weight and would pass the regex while defeating the point); no Lottie/Rive
runtime in the shell (same gate; the note names the runtime); no "spec header" like the
control's (the board's top bar carries the brief, and a spec is what `design-system/` is for);
no eval case (an eval whose control passes cannot measure the skill — CLAUDE.md — and the
control here passed the brief).

## What this does not show

- **n=1 per arm, one model (`claude-fable-5-1`), one day.** A −1.00 delta in this repo once
  failed to replicate on three more runs; nothing here is a delta, it is three artifacts read
  side by side.
- **The new rules were re-run once, cleanly.** Run 5 fed the raw ten-word brief to 0.7.0 in
  a fixture with nothing on disk: phone frames, two drawn characters with four states, two
  accents, cells and notes from the shell, durations and the asset plan annotated, no SaaS
  furniture — every run-1 finding F1–F7 absent. Run 4 showed the same shape but is not
  evidence: run 2's spec was in `.design-kit/boards/` and its names, score and durations
  came back verbatim, so the model had read it. One clean run is one run; the vote spread
  rule in CLAUDE.md applies, and what is claimed here is "the rules land at least once", not a
  delta.
- **A small path defect surfaced in run 4 and is not fixed.** With `DESIGN_KIT_DIR` set, the
  builder wrote the board there but the model wrote the spec to the literal
  `.design-kit/boards/` the command names, and `workshop.json` recorded that literal path. An
  override is an edge path; recorded here, not patched.
- **No person picked on a board.** The consent and pick prompts do not exist in `-p` mode;
  every run stopped where a human would click.
- **The screenshots are the evidence.** They live in the fixture (`../design-kit-sim-tictactoe/`),
  not in this repository; the fixture's `evidence/` directory carries the seven PNGs and the
  three logs, committed there.
- **The research shards are tier 2–4.** Fonts.google.com and Dribbble did not render for the
  fetcher; the Duolingo, APCA, MDN, web.dev, Poki and Apple pages did. One statistic in
  circulation (OKLCH "18 percent") was checked against its claimed source and is not there.
