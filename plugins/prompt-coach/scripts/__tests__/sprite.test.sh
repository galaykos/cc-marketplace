#!/usr/bin/env bash
# sprite.test.sh — hooks/sprite.ts under node: every frame 16x16 in palette, RGBA bytes and Raster half-block cells
#   against the pixels with transparency and the theme-coloured outline honoured, the thinking dots' contrast, and the
#   starting renderer from TERM/TERM_PROGRAM/TMUX.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPRITE="$ROOT/hooks/sprite.ts"
command -v node >/dev/null || { echo "FAIL: node is required"; exit 1; }
ERR=$(mktemp); trap 'rm -f "$ERR"' EXIT
pass=0; fail=0

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

CASES='
import { pathToFileURL } from "node:url"
const { PALETTE, FRAMES, toRgba, toRaster, rendererFor } = await import(pathToFileURL(process.argv[1]).href)
const DEFAULT = 0x01000000
const frames = Object.entries(FRAMES).flatMap(([pose, list]) => list.map((f, i) => [pose + " " + i, f]))
const color = (f, x, y) => PALETTE[f[y][x]]
const pixels = (f) => f.flatMap((row, y) => [...row].map((_, x) => [x, y, color(f, x, y)]))
const throws = (fn) => { try { fn(); return "no throw" } catch { return "throws" } }
// What the terminal paints in each half of a cell: a default fg is its text colour, a default bg its background.
const shown = ({ char, fg, bg }) => {
  const f = fg === DEFAULT ? "terminal text" : fg, b = bg === DEFAULT ? "terminal background" : bg
  return char === "▀" ? [f, b] : char === "▄" ? [b, f] : char === " " ? [b, b] : char === "█" ? [f, f] : ["glyph " + char]
}
// The outline is drawn in the terminal text colour so it flips with the theme; every other pixel in its own colour.
const seen = (f, x, y) => f[y][x] === "k" ? "terminal text" : color(f, x, y) === null ? "terminal background" : color(f, x, y)
const kinds = ".kc"
const PAIRS = [...kinds].flatMap((top) => [...kinds].map((bottom) => top + bottom))
const PAIRED = [0, 1].map((half) => PAIRS.map((p) => p[half]).join("").padEnd(16, ".")).concat(Array(14).fill(".".repeat(16)))
const luminance = (c) => [c >> 16, (c >> 8) & 255, c & 255].map((v) => v / 255).map((v) => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4)
  .reduce((sum, v, i) => sum + v * [0.2126, 0.7152, 0.0722][i], 0)
const contrast = (a, b) => { const [hi, lo] = [luminance(a), luminance(b)].sort((p, q) => q - p); return (hi + 0.05) / (lo + 0.05) }
const env = (TERM, TERM_PROGRAM, TMUX) => rendererFor({ TERM, TERM_PROGRAM, TMUX })
const TMUX = "/tmp/tmux-1000/default,4242,0"
const cases = [
  ["FRAMES holds one idle frame and two each for thinking and talking",
    Object.fromEntries(Object.entries(FRAMES).map(([p, l]) => [p, l.length])), { idle: 1, thinking: 2, talking: 2 }],
  ["every frame is 16 rows of 16 palette characters",
    frames.filter(([, f]) => f.length !== 16 || f.some((r) => r.length !== 16 || [...r].some((ch) => !Object.hasOwn(PALETTE, ch))))
      .map(([n]) => n), []],
  ["the palette has one transparent entry and 0xRRGGBB colours otherwise",
    { clear: Object.keys(PALETTE).filter((k) => PALETTE[k] === null),
      bad: Object.keys(PALETTE).filter((k) => PALETTE[k] !== null && !(Number.isInteger(PALETTE[k]) && PALETTE[k] >= 0 && PALETTE[k] <= 0xffffff)) },
    { clear: ["."], bad: [] }],
  ["each two-frame loop changes pixels between its frames",
    ["thinking", "talking"].map((p) => FRAMES[p][0].join("") !== FRAMES[p][1].join("")), [true, true]],
  ["toRgba gives a 1024-byte Uint8Array for every frame",
    frames.map(([, f]) => { const b = toRgba(f); return b instanceof Uint8Array && b.length }), frames.map(() => 1024)],
  ["every RGBA pixel is its palette colour at alpha 255, or all zero where transparent",
    frames.flatMap(([n, f]) => { const b = toRgba(f); return pixels(f).filter(([x, y, c]) => {
      const got = [...b.slice((y * 16 + x) * 4, (y * 16 + x) * 4 + 4)]
      return got.join() !== (c === null ? [0, 0, 0, 0] : [c >> 16, (c >> 8) & 255, c & 255, 255]).join()
    }).map(([x, y]) => n + " " + x + "," + y) }), []],
  ["toRaster gives 8 rows of 16 cells for every frame",
    frames.map(([, f]) => toRaster(f).map((r) => r.length)), frames.map(() => Array(8).fill(16))],
  ["every Raster cell paints its top pixel above and its bottom pixel below, transparent as the terminal background",
    frames.flatMap(([n, f]) => toRaster(f).flatMap((row, r) => row.map((cell, x) => [x, r, cell]))
      .filter(([x, r, cell]) => JSON.stringify(shown(cell)) !== JSON.stringify([seen(f, x, 2 * r), seen(f, x, 2 * r + 1)]))
      .map(([x, r]) => n + " cell " + x + "," + r)), []],
  ["each of the nine pairs of clear, outline and colour halves paints its two pixels, glyph chosen per cell",
    toRaster(PAIRED)[0].slice(0, 9).map((cell, x) => JSON.stringify(shown(cell)) === JSON.stringify([seen(PAIRED, x, 0), seen(PAIRED, x, 1)]) ? cell.char : "wrong " + PAIRS[x]),
    [" ", "▄", "▄", "▀", "█", "▀", "▀", "▄", "▀"]],
  ["the thinking dots reach 3:1 against both a white and a black background",
    [0xffffff, 0x000000].map((bg) => contrast(PALETTE.y, bg) >= 3), [true, true]],
  ["an out-of-palette or missing pixel throws in both renderers",
    [throws(() => toRgba(FRAMES.idle[0].map((r, y) => y === 3 ? "Z" + r.slice(1) : r))), throws(() => toRaster(FRAMES.idle[0].slice(1)))],
    ["throws", "throws"]],
  ["kitty or Ghostty outside tmux starts as Image", [env("xterm-kitty"), env("xterm-ghostty", "ghostty")], ["image", "image"]],
  ["kitty or Ghostty inside tmux starts as Raster",
    [env("xterm-kitty", undefined, TMUX), env("tmux-256color", "ghostty", TMUX)], ["raster", "raster"]],
  ["every other terminal starts as Raster",
    [env("xterm-256color"), env("xterm-256color", "iTerm.app"), env("xterm-256color", "WezTerm"), env()],
    ["raster", "raster", "raster", "raster"]],
]
for (const [name, got, want] of cases) console.log([name, JSON.stringify(got), JSON.stringify(want)].join("\t"))
'

if out=$(node --input-type=module -e "$CASES" "$SPRITE" 2>"$ERR"); then
  while IFS=$'\t' read -r name got want; do
    [ "$got" = "$want" ] && ok "$name" || bad "$name" "got $got, want $want"
  done <<<"$out"
else
  bad "node runs sprite.ts" "$(cat "$ERR")"
fi

printf '\nsprite: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
