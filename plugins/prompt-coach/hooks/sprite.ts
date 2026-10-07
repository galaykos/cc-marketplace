export type Pose = 'idle' | 'thinking' | 'talking'

type Cell = { char: string; fg: number; bg: number }

// First-party pixel art drawn in code for this plugin: provenance ours, no third-party asset.
export const PALETTE: Readonly<Record<string, number | null>> = {
  '.': null,
  k: 0x1f1a2e,
  c: 0x2f6fd6,
  w: 0xffffff,
  s: 0xf5c9a0,
  m: 0xd9455f,
  g: 0x2fa36b,
  y: 0xffcc33,
}

const IDLE = [
  '................',
  '.....kkkkkk.....',
  '....kcccccck....',
  '...kcwcccccck...',
  '..kcccccccccck..',
  '...kssssssssk...',
  '...kswksswksk...',
  '...kskksskksk...',
  '...kssssssssk...',
  '...kssksskssk...',
  '...kssskksssk...',
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
  '...kskksskksk...',
  '...kswwsswwsk...',
  '...kssssssssk...',
  '...ksssskkssk...',
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
  '...kskksskksk...',
  '...kswwsswwsk...',
  '...kssssssssk...',
  '...ksssskkssk...',
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
  '...kswksswksk...',
  '...kskksskksk...',
  '...kssssssssk...',
  '...ksskkkkssk...',
  '...ksskmmkssk...',
  '....ksskkssk....',
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
  '...kswksswksk...',
  '...kskksskksk...',
  '...kssssssssk...',
  '...ksskkkkssk...',
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

function cell(top: number | null, bottom: number | null): Cell {
  if (top !== null) return { char: '▀', fg: top, bg: bottom ?? TERMINAL_DEFAULT }
  // A default foreground is the terminal's text colour, not its background, so a clear top half needs the lower block.
  if (bottom !== null) return { char: '▄', fg: bottom, bg: TERMINAL_DEFAULT }
  return { char: ' ', fg: TERMINAL_DEFAULT, bg: TERMINAL_DEFAULT }
}

export function toRaster(frame: readonly string[]): Cell[][] {
  return Array.from({ length: SIZE / 2 }, (_, row) =>
    Array.from({ length: SIZE }, (_, x) => cell(colorAt(frame, x, row * 2), colorAt(frame, x, row * 2 + 1))))
}

// The starting renderer only: the CLI decides whether Image draws pixels, and the caller drops to Raster on a denied blit.
export function rendererFor(env: { TERM?: string; TERM_PROGRAM?: string; TMUX?: string }): 'image' | 'raster' {
  return (env.TERM === 'xterm-kitty' || env.TERM_PROGRAM === 'ghostty') && !env.TMUX ? 'image' : 'raster'
}
