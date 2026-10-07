import type { Elements, ImageSource, RenderElement, UiBlitArgs } from 'claude-code'

import type { CoachView } from './coach'
import { LIMITS } from './coach-core'
import type { Label, Verdict } from './coach-core'
import { FRAMES, rendererFor, toRaster, toRgba } from './sprite'
import type { Pose } from './sprite'

export type Renderer = ReturnType<typeof rendererFor>

export type CoachKit = {
  ui: Pick<Elements['terminal'], 'Box' | 'Text' | 'Button' | 'Raster' | 'Image'>
  // The sprite's renderer, or null where the band has no room for it.
  sprite: Renderer | null
  bodyRows: number
  fill: (text: string) => Promise<void>
  mute: () => Promise<void>
}

type SpriteKit = { ui: Pick<Elements['terminal'], 'Raster' | 'Image'>; sprite: Renderer | null }

export type MascotKit = SpriteKit & {
  ui: Pick<Elements['terminal'], 'Box' | 'Text' | 'Button'>
  // Stops the idle blink for the session; null once it is stopped.
  still: (() => void) | null
}

const SPRITE = { key: 'sprite', columns: 16, rows: 8, pixels: 16 } as const

const CAPTIONS: Record<Pose, string> = { idle: '', thinking: 'checking…', talking: 'flagged' }

// A blank Raster cell in every drawing of the coach: the one element a blit can test the band with on any terminal.
const MARKER_KEY = 'marker'

const SPRITE_MIN_COLUMNS = 70

const LABEL_COLUMNS = 11

const TERMINAL_DEFAULT = 0x01000000

const HINTS: Record<Exclude<Label, 'clear'>, string> = {
  unclear: `Sent, but a quick check found it unclear: the ${LIMITS.cap} full checks of this session are used.`,
  conflict: `Sent, but a quick check flagged a possible conflict: the ${LIMITS.cap} full checks of this session are used.`,
}

export function poseOf(view: CoachView): Pose {
  return view.mode === 'thinking' ? 'thinking' : view.mode === 'speaking' ? 'talking' : 'idle'
}

export function frameOf(pose: Pose, tick: number): readonly string[] {
  const frames = FRAMES[pose]

  return frames[tick % frames.length] ?? []
}

// The frame a pose is drawn in and ends on: the talking loop stops with its mouth closed.
export function restOf(pose: Pose): readonly string[] {
  return FRAMES[pose].at(-1) ?? []
}

export function spriteFor(renderer: Renderer, columns: number, bodyRows: number): Renderer | null {
  return columns >= SPRITE_MIN_COLUMNS && bodyRows >= SPRITE.rows ? renderer : null
}

// The pane holds the sprite alone, so it needs only the sprite's own cells.
export function mascotSpriteFor(renderer: Renderer, columns: number, bodyRows: number): Renderer | null {
  return columns >= SPRITE.columns && bodyRows >= SPRITE.rows ? renderer : null
}

const base64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes))

// Each cell carries its own glyph: sprite.ts picks the block, or a space, that leaves a transparent half to the background.
function packed(cells: readonly { char: string; fg: number; bg: number }[]): string {
  const words = new DataView(new ArrayBuffer(cells.length * 12))

  cells.forEach((cell, i) => {
    words.setUint32(i * 12, cell.char.codePointAt(0) ?? 0x20, true)
    words.setUint32(i * 12 + 4, cell.fg, true)
    words.setUint32(i * 12 + 8, cell.bg, true)
  })

  return base64(new Uint8Array(words.buffer))
}

const BLANK = packed([{ char: ' ', fg: TERMINAL_DEFAULT, bg: TERMINAL_DEFAULT }])

function sourceOf(frame: readonly string[]): ImageSource {
  return { rgba: base64(toRgba(frame)), width: SPRITE.pixels, height: SPRITE.pixels }
}

export function spriteBlit(requestId: string, renderer: Renderer, frame: readonly string[]): UiBlitArgs {
  return renderer === 'image'
    ? { requestId, key: SPRITE.key, source: sourceOf(frame) }
    : { requestId, key: SPRITE.key, cells: packed(toRaster(frame).flat()) }
}

export function markerBlit(requestId: string): UiBlitArgs {
  return { requestId, key: MARKER_KEY, cells: BLANK }
}

function kindOf(verdict: Verdict): string {
  switch (verdict.kind) {
    case 'unclear':
      return 'Unclear'
    case 'off-card':
      return 'Off-card'
    case 'reopens':
      return `Reopens ${verdict.decision ?? 'a decision'}`
    case 'contradicts':
      return 'Contradicts an earlier turn'
  }
}

// The judge saw no more than this; a far longer prompt would push the tree past the engine's 100,000-character bound.
function shown(text: string): string {
  return text.length <= LIMITS.promptChars ? text : `${text.slice(0, LIMITS.promptChars).replace(/[\uD800-\uDBFF]$/, '')}…`
}

function spriteOf(kit: SpriteKit, pose: Pose): RenderElement | null {
  const { Image, Raster } = kit.ui
  const frame = restOf(pose)

  switch (kit.sprite) {
    case 'image':
      return <Image key={SPRITE.key} source={sourceOf(frame)} columns={SPRITE.columns} rows={SPRITE.rows} alt=" " />
    case 'raster':
      return <Raster key={SPRITE.key} columns={SPRITE.columns} rows={SPRITE.rows} cells={packed(toRaster(frame).flat())} />
    case null:
      return null
  }
}

function field(kit: CoachKit, label: string, value: string, wrap: 'wrap' | 'truncate-end'): RenderElement {
  const { Box, Text } = kit.ui

  return (
    <Box flexDirection="row">
      <Box width={LABEL_COLUMNS} flexShrink={0}>
        <Text>{label}</Text>
      </Box>
      <Box flexShrink={1}>
        <Text wrap={wrap}>{value}</Text>
      </Box>
    </Box>
  )
}

// The button row leads: a short band shows only its first rows, and a digit presses only a Button in view.
function speakingLines(kit: CoachKit, text: string, verdict: Verdict): RenderElement[] {
  const { Box, Text, Button } = kit.ui
  const buttons = (
    <Box flexDirection="row" flexWrap="wrap" columnGap={2}>
      <Button key="use" hotkey="1" plain autoFocus onPress={() => kit.fill(verdict.rewrite)}>
        Use rewrite
      </Button>
      <Button key="send" hotkey="2" plain onPress={() => kit.fill(text)}>
        Send anyway
      </Button>
      <Button key="mute" hotkey="3" plain onPress={() => kit.mute()}>
        Mute
      </Button>
      <Text>(1, 2 fill the box; Enter sends)</Text>
    </Box>
  )
  const reason = <Text wrap="truncate-end">{`${kindOf(verdict)}: ${verdict.reason}`}</Text>
  const suggest = field(kit, 'Suggest:', verdict.rewrite, 'wrap')

  if (kit.bodyRows < SPRITE.rows) {
    return [buttons, reason, suggest, field(kit, 'You wrote:', shown(text).replace(/\s+/g, ' '), 'truncate-end')]
  }

  return [buttons, reason, field(kit, 'You wrote:', shown(text), 'wrap'), suggest]
}

export function coachView(kit: CoachKit, view: Exclude<CoachView, { mode: 'idle' }>): RenderElement {
  const { Box, Text, Raster } = kit.ui

  const lines =
    view.mode === 'speaking'
      ? speakingLines(kit, view.text, view.verdict)
      : [<Text>{view.mode === 'thinking' ? 'checking your prompt…' : HINTS[view.label]}</Text>]

  return (
    <Box flexDirection="row" gap={1}>
      <Box flexShrink={0}>
        <Raster key={MARKER_KEY} columns={1} rows={1} cells={BLANK} />
        {spriteOf(kit, poseOf(view))}
      </Box>
      <Box flexDirection="column" flexGrow={1}>
        {lines}
      </Box>
    </Box>
  )
}

// A blink that runs past 5 s needs a stop control in view (WCAG 2.2.2), so Still shows whenever one is due.
export function mascotView(kit: MascotKit, view: CoachView): RenderElement {
  const { Box, Text, Button } = kit.ui
  const pose = poseOf(view)
  const still = kit.sprite === null ? null : kit.still

  return (
    <Box flexDirection="column">
      {spriteOf(kit, pose)}
      {CAPTIONS[pose] === '' ? null : <Text>{CAPTIONS[pose]}</Text>}
      {still === null ? null : (
        <Button key="still" hotkey="s" plain onPress={still}>
          Still
        </Button>
      )}
    </Box>
  )
}
