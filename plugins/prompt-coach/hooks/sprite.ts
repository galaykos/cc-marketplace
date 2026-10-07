export type Pose = 'idle' | 'thinking' | 'talking'

type Cell = { char: string; fg: number; bg: number }

// First-party pixel art drawn in code for this plugin: provenance ours, no third-party asset.
export const PALETTE: Readonly<Record<string, number | null>> = {
  '.': null,
  k: 0x1f1a2e,
  e: 0x1f1a2e,
  c: 0x2f6fd6,
  w: 0xffffff,
  s: 0xf5c9a0,
  m: 0xd9455f,
  g: 0x2fa36b,
  y: 0xd97706,
}

// Raster draws the outline in the terminal's text colour, so the silhouette shows on a dark theme and a light one.
const OUTLINE = 'k'

// What a Raster half shows: a colour, the terminal's background (null) or its text colour.
type Ink = number | null | 'text'

const IDLE = [
  '................',
  '.....kkkkkk.....',
  '....kcccccck....',
  '...kcwcccccck...',
  '..kcccccccccck..',
  '...kssssssssk...',
  '...kswesswesk...',
  '...kseesseesk...',
  '...kssssssssk...',
  '...kssessessk...',
  '...kssseesssk...',
  '....kssssssk....',
  '..kggkkkkkkggk..',
  '.kggggwggwggggk.',
  '.kgggggyygggggk.',
  '.kggggggggggggk.',
]

const THINKING_A = [
  '................',
  '.....kkkkkk.....',
  '....kcccccck....',
  '...kcwcccccck.y.',
  '..kcccccccccck..',
  '...kssssssssk...',
  '...kseesseesk...',
  '...kswwsswwsk...',
  '...kssssssssk...',
  '...ksssseessk...',
  '...kssssssssk...',
  '....kssssssk....',
  '..kggkkkkkkggk..',
  '.kggggwggwggggk.',
  '.kgggggyygggggk.',
  '.kggggggggggggk.',
]

const THINKING_B = [
  '.............yy.',
  '.....kkkkkk..yy.',
  '....kcccccck....',
  '...kcwcccccck...',
  '..kcccccccccck..',
  '...kssssssssk...',
  '...kseesseesk...',
  '...kswwsswwsk...',
  '...kssssssssk...',
  '...ksssseessk...',
  '...kssssssssk...',
  '....kssssssk....',
  '..kggkkkkkkggk..',
  '.kggggwggwggggk.',
  '.kgggggyygggggk.',
  '.kggggggggggggk.',
]

const TALKING_A = [
  '................',
  '.....kkkkkk.....',
  '....kcccccck....',
  '...kcwcccccck...',
  '..kcccccccccck..',
  '...kssssssssk...',
  '...kswesswesk...',
  '...kseesseesk...',
  '...kssssssssk...',
  '...ksseeeessk...',
  '...kssemmessk...',
  '....ksseessk....',
  '..kggkkkkkkggk..',
  '.kggggwggwggggk.',
  '.kgggggyygggggk.',
  '.kggggggggggggk.',
]

const TALKING_B = [
  '................',
  '.....kkkkkk.....',
  '....kcccccck....',
  '...kcwcccccck...',
  '..kcccccccccck..',
  '...kssssssssk...',
  '...kswesswesk...',
  '...kseesseesk...',
  '...kssssssssk...',
  '...ksseeeessk...',
  '...kssssssssk...',
  '....kssssssk....',
  '..kggkkkkkkggk..',
  '.kggggwggwggggk.',
  '.kgggggyygggggk.',
  '.kggggggggggggk.',
]

export const FRAMES: Record<Pose, readonly (readonly string[])[]> = {
  idle: [IDLE],
  thinking: [THINKING_A, THINKING_B],
  talking: [TALKING_A, TALKING_B],
}

const SIZE = 16

const TERMINAL_DEFAULT = 0x01000000

function colorAt(frame: readonly string[], x: number, y: number): number | null {
  const ch = frame[y]?.[x] ?? ''
  const color = PALETTE[ch]
  if (color === undefined) throw new Error(`sprite: pixel ${x},${y} '${ch}' is not in PALETTE`)
  return color
}

export function toRgba(frame: readonly string[]): Uint8Array {
  const rgba = new Uint8Array(SIZE * SIZE * 4)
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const color = colorAt(frame, x, y)
      if (color !== null) rgba.set([color >> 16, (color >> 8) & 0xff, color & 0xff, 0xff], (y * SIZE + x) * 4)
    }
  }
  return rgba
}

function inkAt(frame: readonly string[], x: number, y: number): Ink {
  const color = colorAt(frame, x, y)
  return frame[y]?.[x] === OUTLINE ? 'text' : color
}

const slot = (ink: Ink) => (typeof ink === 'number' ? ink : TERMINAL_DEFAULT)

// Text ink can sit only in the glyph's half (a default fg) and a clear half only in the background's: that picks the block.
function cell(top: Ink, bottom: Ink): Cell {
  if (top === null && bottom === null) return { char: ' ', fg: TERMINAL_DEFAULT, bg: TERMINAL_DEFAULT }
  if (top === 'text' && bottom === 'text') return { char: '█', fg: TERMINAL_DEFAULT, bg: TERMINAL_DEFAULT }
  if (top === null || bottom === 'text') return { char: '▄', fg: slot(bottom), bg: slot(top) }
  return { char: '▀', fg: slot(top), bg: slot(bottom) }
}

export function toRaster(frame: readonly string[]): Cell[][] {
  return Array.from({ length: SIZE / 2 }, (_, row) =>
    Array.from({ length: SIZE }, (_, x) => cell(inkAt(frame, x, row * 2), inkAt(frame, x, row * 2 + 1))))
}

// The starting renderer only: the CLI decides whether Image draws pixels, and the caller drops to Raster on a denied blit.
export function rendererFor(env: { TERM?: string; TERM_PROGRAM?: string; TMUX?: string }): 'image' | 'raster' {
  return (env.TERM === 'xterm-kitty' || env.TERM_PROGRAM === 'ghostty') && !env.TMUX ? 'image' : 'raster'
}
