import type { Args, FsStat, On, SessionMessage, UiBlitArgs } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine, Mounted } from 'claude-code/testing'

import { BLINK, FRAMES, toRaster } from '../hooks/sprite'
import type { Pose } from '../hooks/sprite'

const NOW = Date.UTC(2026, 9, 7, 12)
const ROOT = '/work'
const RUN = '/work/.claude/task-runner/active-run.json'
const INDEX = '/work/taskmaster-docs/tasks/login/00-INDEX.md'
const SPEC = '/work/taskmaster-docs/specs/login.md'

const ZERO = { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }

const PROMPT = 'fix the bug we talked about'
const OTHER = 'rename the parse helper in src/utils.ts'
const REASON = 'Nothing here says which bug.'
const REWRITE = 'Fix the null check in src/auth.ts login() so a <null> user is rejected.'

const IN_RUN = {
  [RUN]: JSON.stringify({ slug: 'login', branch: 'feat/login', index_path: 'taskmaster-docs/tasks/login/00-INDEX.md' }),
  [INDEX]: [
    'Spec: taskmaster-docs/specs/login.md',
    '',
    '| card | title | depends-on | agent | parallel group | status |',
    '|---|---|---|---|---|---|',
    '| 02 | Wire the session cookie | none | backend | B | in_progress (delegated) |',
    '',
  ].join('\n'),
  [SPEC]: ['## Goal', '', 'People stay signed in.', '', '## Decisions', '', '| D1 | Sessions live in an httpOnly cookie. | user |', ''].join('\n'),
}

const TURNS: SessionMessage[] = [{ role: 'user', text: 'Keep the session in an httpOnly cookie.', toolUses: [] }]

const BAND = { hasSurvey: false, isWorking: false, maxRows: 17, bodyColumns: 75, scroll: { offset: 0, bodyRows: 16 }, view: {} } as const

type Reply = { text: string; afterMs?: number }

type Live = { env?: Record<string, string>; files?: Record<string, string>; messages?: SessionMessage[] }

const answer = (text: string, afterMs?: number): Reply => ({ text, afterMs })

const verdict = (kind: string, decision?: string) =>
  JSON.stringify({
    verdict: kind === 'unclear' ? 'unclear' : 'conflict',
    kind,
    ...(decision !== undefined && { decision }),
    confidence: 'high',
    reason: REASON,
    rewrite: REWRITE,
  })

const dropOf = (kind: string) => ({ drop: `prompt-coach held this prompt (${kind}); set CC_PROMPT_COACH=off to stop` })

const composer = (text: string, more: Partial<Args<'prompt.submit'>> = {}): Args<'prompt.submit'> => ({
  text,
  wait: false,
  origin: { kind: 'composer' },
  ...more,
})

function seat(on: On, live: Live = {}) {
  const world = {
    clock: mock.clock(on, { now: NOW }),
    env: { ...live.env } as Record<string, string | undefined>,
    files: new Map(Object.entries(live.files ?? {})),
    replies: { haiku: [answer('unclear')], standby: [answer(verdict('unclear'))] } as Record<'haiku' | 'standby', Reply[]>,
    calls: [] as string[],
    toasts: [] as string[],
    fills: [] as { text: string; mode: string }[],
    submitted: [] as string[],
    blits: [] as UiBlitArgs[],
    box: '',
    isFillRefused: false,
    denyBlit: (() => undefined) as (args: UiBlitArgs) => string | undefined,
    // A blit answers only once this settles: how an answer arrives after the band has moved on.
    blitGate: undefined as Promise<void> | undefined,
    isBlitRefused: false,
    passes: [] as unknown[],
    stateWriteMs: 0,
    opened: [] as unknown[],
    statuses: [] as (string | undefined)[],
    panes: [] as string[],
    closed: [] as string[],
    paneReads: 0,
  }

  on('session.version', () => ({ value: { version: '2.1.291' } }))
  on('env.get', ($, e) => ({ value: world.env[e.name] }))
  on('session.cwd', () => ({ value: ROOT }))
  on('session.surfaces', () => ({ value: ['terminal'] }))
  on('session.messages', () => ({ value: live.messages ?? [] }))

  on('process.run', ($, e) => {
    const answers: Record<string, [number, string]> = {
      'git rev-parse --show-cdup': [0, '\n'],
      'git rev-parse --abbrev-ref HEAD': [0, 'feat/login\n'],
      'git ls-files --error-unmatch -- .claude/task-runner/active-run.json': [1, ''],
    }
    const ran = answers[e.argv.join(' ')]

    return ran === undefined
      ? { deny: `unexpected command: ${e.argv.join(' ')}` }
      : { value: { exitCode: ran[0], stdout: ran[1], stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  on('fs.stat', ($, e) => {
    const text = world.files.get(e.path)

    if (text === undefined && e.path !== ROOT) {
      return { deny: `ENOENT: ${e.path}` }
    }

    const stat: FsStat = { kind: e.path === ROOT ? 'dir' : 'file', size: text?.length ?? 0, mtimeMs: NOW, isLink: false, ...(e.resolve && { realPath: e.path }) }

    return { value: stat }
  })

  on('fs.read', ($, e) => {
    const text = world.files.get(e.path)

    return text === undefined ? { deny: `ENOENT: ${e.path}` } : { value: text }
  })

  on('model.complete', async ($, e) => {
    const stage = e.model === 'haiku' ? 'haiku' : 'standby'
    const replies = world.replies[stage]
    const reply = replies[world.calls.filter(model => (model === 'haiku') === (stage === 'haiku')).length % replies.length] ?? answer('clear')

    world.calls.push(e.model)

    if (reply.afterMs !== undefined) {
      await world.clock.sleep(reply.afterMs)
    } else {
      // A live judge takes long enough for the band to draw; the kit draws it once the clock settles.
      await world.clock.settle()
    }

    return { value: { isAnswered: true, text: reply.text, usage: ZERO } }
  })

  on('ui.toast', ($, e) => {
    world.toasts.push(e.text)

    return { value: undefined }
  })

  on('ui.blit', async ($, e) => {
    world.blits.push(e)
    await world.blitGate

    if (world.isBlitRefused) {
      return { deny: 'refused by a hook' }
    }

    const deny = world.denyBlit(e)

    return { value: deny === undefined ? {} : { deny } }
  })

  // The engine's own band: what shows while the coach draws nothing.
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => $.ui.resolve(e).Box({}))

  on('ui.render', { component: 'Pane' }, ($, e) => $.ui.resolve(e).Box({}))

  on('ui.status', ($, e) => {
    world.statuses.push(e.text)

    return { value: undefined }
  })

  on('ui.panes', () => {
    world.paneReads += 1

    return { value: world.panes.map(id => ({ id, title: 'coach', isShown: true, isFocused: false, isPlaced: true })) }
  })

  on('ui.close', ($, e) => {
    world.closed.push(e.id)

    return { value: undefined }
  })

  on('ui.open', ($, e) => {
    world.opened.push(e)

    return { value: { isPlaced: true } }
  })

  on('prompt.read', () => ({ value: { text: world.box, cursor: world.box.length } }))

  on('prompt.fill', ($, e) => {
    world.fills.push({ text: e.text, mode: e.mode })

    // As the box does, it drops the code points a terminal draws as nothing.
    if (!world.isFillRefused) {
      world.box = e.text.replace(/\u200B/g, '')
    }

    return { isFilled: !world.isFillRefused }
  })

  on('state.set', async ($, e, next) => {
    if (e.key === 'pass') {
      world.passes.push(e.value)
    }

    if (world.stateWriteMs > 0) {
      await world.clock.sleep(world.stateWriteMs)
    }

    return next(e)
  })

  on('prompt.submit', ($, e) => {
    world.submitted.push(e.text)
    world.box = ''

    return { text: e.text }
  })

  return world
}

type Band = Mounted<'terminal', 'AbovePrompt'>

type Drawn = { type: string; props?: Record<string, unknown>; children?: Drawn[] }

const SHORT = { ...BAND, maxRows: 4, scroll: { offset: 0, bodyRows: 3 } }

const NOT_MOUNTED = 'no Raster of its own is mounted under key "marker" in above-prompt'

const MUTED_NOTE = 'prompt-coach muted for this session — a new session turns it back on'

const mount = ($: Engine, props: typeof BAND | typeof SHORT = BAND) =>
  $.ui.mount({ plugin: 'prompt-coach', surface: 'terminal', component: 'AbovePrompt', requestId: 'above-prompt', props })

const lines = async (band: Band) => (await band.findAll({})).filter(el => el.type === 'Text' || el.type === 'Button').map(el => el.text)

const buttons = async (band: Band) => (await band.findAll({ type: 'Button' })).map(el => [el.props.hotkey, el.text, el.props.plain, el.props.autoFocus])

const spriteOf = (band: Band) => band.find({ key: 'sprite' })

const shapeOf = async (band: Band) => {
  const sprite = await spriteOf(band)

  return [sprite?.type, sprite?.props.columns, sprite?.props.rows]
}

// Each cell as [glyph, foreground, background], decoded from the little-endian u32 triplets a Raster's cells pack.
function decoded(cells: unknown): [string, number, number][] {
  const view = new DataView(Uint8Array.from(atob(String(cells)), ch => ch.charCodeAt(0)).buffer)

  return Array.from({ length: view.byteLength / 12 }, (_, i) => [
    String.fromCodePoint(view.getUint32(i * 12, true)),
    view.getUint32(i * 12 + 4, true),
    view.getUint32(i * 12 + 8, true),
  ])
}

const frameCells = (pose: Pose, frame: number) => toRaster(FRAMES[pose][frame] ?? []).flat().map(cell => [cell.char, cell.fg, cell.bg])

const blitCells = (args: UiBlitArgs | undefined) => (args !== undefined && 'cells' in args ? decoded(args.cells) : [])

// The blit the coach makes before a drop: the band's blank marker cell, whatever the sprite.
const isMarkerCheck = (args: UiBlitArgs | undefined) =>
  args?.requestId === 'above-prompt' && args.key === 'marker' && JSON.stringify(blitCells(args)) === JSON.stringify([[' ', 0x01000000, 0x01000000]])

// Starts the submit and moves the clock past the judge's answer, so the band draws and animates meanwhile.
async function judged($: Engine, world: ReturnType<typeof seat>, text = PROMPT, afterMs = 900) {
  const held = $.prompt.submit(composer(text))

  await world.clock.advance(afterMs)

  return held
}

describe('band', () => {
  test('thinking shows the sprite and checking your prompt', async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [answer('clear', 1000)]

    const band = await mount($)

    expect(await lines(band), 'nothing of the coach before Enter').toEqual([])

    const submitted = $.prompt.submit(composer(PROMPT))

    await world.clock.settle()

    expect(await lines(band)).toEqual(['checking your prompt…'])
    expect(await buttons(band)).toEqual([])
    expect(decoded((await spriteOf(band))?.props.cells)).toEqual(frameCells('thinking', 1))

    await world.clock.advance(250)

    expect(blitCells(world.blits.at(-1)), 'the thinking loop').toEqual(frameCells('thinking', 0))

    await world.clock.advance(750)

    expect(await submitted).toEqual({ text: PROMPT })
    expect(await lines(band), 'gone once the judgment resolves').toEqual([])
  })

  test('speaking shows your text, the reason and the rewrite', async ($, on) => {
    const world = seat(on)
    const text = `${PROMPT}\nthe one from yesterday`
    const band = await mount($)

    world.replies.haiku = [answer('unclear', 900)]

    expect(await judged($, world, text)).toEqual(dropOf('unclear'))
    expect(await lines(band)).toEqual([
      'Use rewrite',
      'Send anyway',
      'Mute',
      '(1, 2 fill the box; Enter sends)',
      `Unclear: ${REASON}`,
      'You wrote:',
      text,
      'Suggest:',
      REWRITE,
    ])
    expect((await band.find({ type: 'Text', text: /^Unclear: / }))?.props.wrap, 'the reason keeps to one row').toBe('truncate-end')

    const [label, value] = ((await band.findAll({ type: 'Box' })).find(box => box.text === `Suggest:${REWRITE}`)?.children ?? []) as Drawn[]

    expect([label?.props, value?.props], 'a fixed label column, so wrapped and multi-line values keep their indent').toEqual([
      { width: 11, flexShrink: 0 },
      { flexShrink: 1 },
    ])
  })

  test('speaking uses the talking pose and the You wrote and Suggest labels', async ($, on) => {
    const world = seat(on)
    const band = await mount($)

    // Off the 250 ms frame boundary, so no frame and the verdict land at one instant.
    world.replies.haiku = [answer('unclear', 900)]
    await judged($, world)

    const thinkingBlits = world.blits.length

    expect((await lines(band)).filter(line => /^(You wrote|Suggest):$/.test(line))).toEqual(['You wrote:', 'Suggest:'])
    expect(decoded((await spriteOf(band))?.props.cells), 'drawn with the mouth closed').toEqual(frameCells('talking', 1))

    await world.clock.advance(250 * 30)

    const talking = world.blits.slice(thinkingBlits).map(blitCells)

    expect(thinkingBlits + talking.length, 'twenty frames within 5 s of Enter, and the check before the drop').toBe(21)
    expect(talking.slice(0, 2), 'the talking loop').toEqual([frameCells('talking', 1), frameCells('talking', 0)])
    expect(talking.at(-1), 'ends with the mouth closed').toEqual(frameCells('talking', 1))
  })

  test('shows at most the judged length of a long prompt, and 2 fills it whole', async ($, on) => {
    const world = seat(on)
    const long = `${PROMPT} ${'and more '.repeat(600)}`
    const band = await mount($)

    await $.prompt.submit(composer(long))

    expect(await lines(band)).toContain(`${long.slice(0, 4000)}…`)

    await band.press({ key: 'send' })

    expect(world.fills).toEqual([{ text: long, mode: 'replace' }])
  })

  test('names each conflict kind', async ($, on) => {
    const world = seat(on, { files: IN_RUN, messages: TURNS })

    world.replies.standby = [verdict('unclear'), verdict('off-card'), verdict('reopens', 'D1'), verdict('contradicts')].map(text => answer(text))

    const band = await mount($)
    const named: string[] = []

    for (const kind of ['unclear', 'off-card', 'reopens', 'contradicts']) {
      expect(await $.prompt.submit(composer(PROMPT))).toEqual(dropOf(kind))
      named.push((await lines(band))[4] ?? '')
    }

    expect(named).toEqual([`Unclear: ${REASON}`, `Off-card: ${REASON}`, `Reopens D1: ${REASON}`, `Contradicts an earlier turn: ${REASON}`])
  })

  test('the button row is the first row of the bubble', async ($, on) => {
    seat(on)

    const band = await mount($)

    await $.prompt.submit(composer(PROMPT))

    const bubble = (await band.findAll({ type: 'Box' })).find(box => box.props.flexDirection === 'column')
    const [first] = (bubble?.children ?? []) as Drawn[]

    expect(first?.children?.map(child => [child.type, child.props?.hotkey])).toEqual([
      ['Button', '1'],
      ['Button', '2'],
      ['Button', '3'],
      ['Text', undefined],
    ])
    expect(first?.props?.flexWrap, 'a narrow band wraps the hint, never the buttons off the first row').toBe('wrap')
    expect(await buttons(band), 'plain engine Buttons, the engine drawing each digit; the focus enters on the first').toEqual([
      ['1', 'Use rewrite', true, true],
      ['2', 'Send anyway', true, undefined],
      ['3', 'Mute', true, undefined],
    ])
    expect((await band.findAll({ type: 'Box' })).filter(box => box.props.borderStyle !== undefined), 'no frame of its own').toEqual([])
  })

  test('a short or narrow band draws no sprite, and its digit Buttons lead', async ($, on) => {
    const world = seat(on)

    const text = `${PROMPT}\nthe one from yesterday`
    const band = await mount($, SHORT)

    expect(await $.prompt.submit(composer(text)), 'held on an 80x24 band too').toEqual(dropOf('unclear'))
    expect(await lines(band)).toEqual([
      'Use rewrite',
      'Send anyway',
      'Mute',
      '(1, 2 fill the box; Enter sends)',
      `Unclear: ${REASON}`,
      'Suggest:',
      REWRITE,
      'You wrote:',
      `${PROMPT} the one from yesterday`,
    ])
    expect((await band.find({ type: 'Text', text: `${PROMPT} the one from yesterday` }))?.props.wrap, 'cut to one row').toBe('truncate-end')
    expect(await spriteOf(band), 'no sprite').toBeUndefined()
    expect(isMarkerCheck(world.blits.at(-1)), 'the drop was checked on the marker cell').toBe(true)

    await band.redraw({ ...BAND, bodyColumns: 50 })

    expect((await lines(band)).slice(4), 'a narrow tall band keeps the order').toEqual([`Unclear: ${REASON}`, 'You wrote:', text, 'Suggest:', REWRITE])
    expect(await spriteOf(band)).toBeUndefined()
  })

  test('1 fills the rewrite and it passes unjudged', async ($, on) => {
    const world = seat(on)

    // The judge was asked to write each ‹ of its input back as <; one it left is restored.
    world.replies.standby = [answer(verdict('unclear').replace('<null>', '‹null>'))]

    const band = await mount($)

    await $.prompt.submit(composer(PROMPT))

    expect(await lines(band)).toContain(REWRITE)

    await band.press({ key: 'use' })

    expect(world.fills).toEqual([{ text: REWRITE, mode: 'replace' }])
    expect(world.submitted, 'the coach never submits').toEqual([])

    const calls = world.calls.length

    expect(await $.prompt.submit(composer(REWRITE))).toEqual({ text: REWRITE })
    expect(world.calls.length).toBe(calls)
  })

  test('a rewrite keeps a ‹ the person typed', async ($, on) => {
    const world = seat(on)
    const quoted = 'Quote the error as ‹null› in docs/errors.md.'

    world.replies.standby = [answer(verdict('unclear').replace(REWRITE, quoted))]

    const band = await mount($)

    await $.prompt.submit(composer('quote the error as ‹null› in the docs'))
    await band.press({ key: 'use' })

    expect(world.fills.map(fill => fill.text)).toEqual([quoted])
  })

  test('2 fills your text and it passes unjudged', async ($, on) => {
    const world = seat(on)
    const text = 'fix the bug\u200B we talked about'
    const band = await mount($)

    await $.prompt.submit(composer(text))
    await band.press({ key: 'send' })

    expect(world.fills).toEqual([{ text, mode: 'replace' }])
    expect(world.submitted, 'the coach never submits').toEqual([])

    const calls = world.calls.length

    expect(await $.prompt.submit(composer(world.box)), 'the text as the box holds it').toEqual({ text: PROMPT })
    expect(world.calls.length).toBe(calls)
  })

  test('records a filled text once, and only once the box took it', async ($, on) => {
    const world = seat(on)
    const band = await mount($)

    await $.prompt.submit(composer(PROMPT))

    world.isFillRefused = true
    await band.press({ key: 'use' })

    expect(world.passes, 'a refused fill').toEqual([])

    world.isFillRefused = false
    await band.press({ key: 'use' })

    // Enter empties the box whether the prompt is sent or dropped.
    world.box = ''
    await $.prompt.submit(composer(OTHER))
    await band.press({ key: 'use' })

    expect(world.fills.map(fill => fill.text)).toEqual([REWRITE, REWRITE, REWRITE])
    expect(world.passes.length, 'the second rewrite was already marked').toBe(1)
  })

  test('3 mutes the coach for the session', async ($, on) => {
    const world = seat(on)
    const band = await mount($)

    await $.prompt.submit(composer(PROMPT))
    await band.press({ key: 'mute' })

    expect(await lines(band)).toEqual([])
    expect(world.toasts).toEqual([MUTED_NOTE])

    const calls = world.calls.length

    expect(await $.prompt.submit(composer(OTHER))).toEqual({ text: OTHER })
    expect(await $.prompt.submit(composer(PROMPT))).toEqual({ text: PROMPT })
    expect(world.calls.length, 'no model call once muted').toBe(calls)
    expect(world.fills).toEqual([])
  })

  test('a button press ends the bubble', async ($, on) => {
    const world = seat(on)
    const band = await mount($)

    await $.prompt.submit(composer(PROMPT))

    world.box = 'half of a new prompt'
    await band.press({ key: 'use' })

    expect(world.fills, 'a draft typed since the drop is never overwritten').toEqual([])
    expect(world.toasts).toEqual(['Clear the prompt box, then press 1 or 2 again'])
    expect(await lines(band)).toContain(REWRITE)

    world.box = ''
    world.isFillRefused = true
    await band.press({ key: 'send' })

    expect(await lines(band), 'a refused fill leaves the text in the bubble').toContain(PROMPT)

    world.isFillRefused = false
    await band.press({ key: 'send' })

    expect(await lines(band)).toEqual([])
  })

  test('no frame is blitted once the bubble ends', async ($, on) => {
    const world = seat(on)
    const band = await mount($)

    await $.prompt.submit(composer(PROMPT))
    await world.clock.advance(250)
    await band.press({ key: 'send' })

    const blits = world.blits.length

    await world.clock.advance(5000)

    expect(blits, 'the check before the drop and one frame').toBe(2)
    expect(world.blits.length).toBe(blits)
  })

  test('clears on the next submit', async ($, on) => {
    seat(on)

    const band = await mount($)

    await $.prompt.submit(composer(PROMPT))
    await $.prompt.submit(composer('a peer says the deploy finished', { origin: { kind: 'bridge' } }))

    expect(await lines(band), 'a prompt the person did not type keeps it').toContain(`Unclear: ${REASON}`)

    await $.prompt.submit(composer('/help'))

    expect(await lines(band), 'a slash command typed in the composer clears it').toEqual([])
  })

  test('after-cap hint shows without buttons and clears on the next submit', async ($, on) => {
    const world = seat(on)

    on('state.get', ($, e) => ({ value: { value: e.key === 'escalations' ? 10 : undefined, version: 0 } }))

    world.replies.haiku = [answer('unclear'), answer('clear')]

    const band = await mount($)

    expect(await $.prompt.submit(composer(PROMPT)), 'not held').toEqual({ text: PROMPT })
    expect(await lines(band)).toEqual(['Sent, but a quick check found it unclear: the 10 full checks of this session are used.'])
    expect(await buttons(band)).toEqual([])
    expect(decoded((await spriteOf(band))?.props.cells), 'the idle pose').toEqual(frameCells('idle', 0))

    await world.clock.advance(250 * 4)

    expect(world.blits.map(blitCells), 'one blit for the pose, though it does not loop').toEqual([frameCells('idle', 0)])

    await $.prompt.submit(composer(OTHER))

    expect(await lines(band)).toEqual([])
  })

  test('starts as Image on kitty outside tmux, Raster inside tmux, and falls back to Raster on a denied Image blit', async ($, on) => {
    const world = seat(on, { env: { TERM: 'xterm-kitty' } })

    world.replies.haiku = [answer('clear', 1000)]

    const band = await mount($)

    const shapeWhileHeld = async (afterMs = 0) => {
      const held = $.prompt.submit(composer(PROMPT))

      await world.clock.advance(afterMs)

      const shape = await shapeOf(band)

      await world.clock.advance(1000 - afterMs)
      await held

      return shape
    }

    expect(await shapeWhileHeld(), 'kitty').toEqual(['Image', 16, 8])

    world.env.TMUX = '/tmp/tmux-1000/default,4242,0'

    expect(await shapeWhileHeld(), 'kitty in tmux').toEqual(['Raster', 16, 8])

    world.env = { TERM: 'xterm-256color', TERM_PROGRAM: 'ghostty' }

    expect(await shapeWhileHeld(), 'Ghostty').toEqual(['Image', 16, 8])

    world.denyBlit = args => ('source' in args ? 'the Image draws its alt here: the terminal draws no placeholder images' : undefined)

    expect(await shapeWhileHeld(250), 'after a denied Image blit').toEqual(['Raster', 16, 8])
    expect(await shapeWhileHeld(), 'for the rest of the session').toEqual(['Raster', 16, 8])
  })

  test('passes and toasts when the band cannot show', async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [answer('unclear', 900)]

    const band = await mount($)

    world.denyBlit = args => ('cells' in args ? NOT_MOUNTED : undefined)

    expect(await judged($, world), 'collapsed').toEqual({ text: PROMPT })

    world.denyBlit = () => undefined

    expect(await judged($, world), 'shown again').toEqual(dropOf('unclear'))

    world.denyBlit = () => 'the cells do not decode'

    expect(await judged($, world), 'a blit refused for another reason').toEqual({ text: PROMPT })

    world.denyBlit = () => undefined
    world.isBlitRefused = true

    expect(await judged($, world), 'a blit that never reaches the band').toEqual({ text: PROMPT })

    world.isBlitRefused = false

    world.denyBlit = () => undefined
    await band.redraw({ ...BAND, hasSurvey: true })

    expect(await judged($, world), 'under a survey').toEqual({ text: PROMPT })

    await band.redraw(BAND)

    expect(await judged($, world), 'the survey gone').toEqual(dropOf('unclear'))
    expect(world.toasts).toEqual([
      'Flagged (unclear) but sent: the plugin panel above the prompt is hidden.',
      'Flagged (unclear) but sent: the plugin panel above the prompt is not showing the coach.',
      'Flagged (unclear) but sent: the plugin panel above the prompt is not showing the coach.',
      'Flagged (unclear) but sent: a survey holds the plugin panel above the prompt.',
    ])
  })

  test('passes and toasts when no band is drawn', async ($, on) => {
    const world = seat(on)

    expect(await $.prompt.submit(composer(PROMPT))).toEqual({ text: PROMPT })
    expect(world.toasts).toEqual(['Flagged (unclear) but sent: the plugin panel above the prompt is not showing the coach.'])
  })

  test('passes when the band collapses between the last frame and the verdict', async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [answer('unclear', 900)]
    await mount($)

    const held = $.prompt.submit(composer(PROMPT))

    await world.clock.advance(800)

    expect(world.blits.length, 'the frames so far were taken').toBe(3)

    world.denyBlit = () => NOT_MOUNTED
    await world.clock.advance(100)

    expect(await held).toEqual({ text: PROMPT })
    expect(world.toasts).toEqual(['Flagged (unclear) but sent: the plugin panel above the prompt is hidden.'])
  })

  test('a check of the band that never answers passes the prompt at the deadline', async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [answer('unclear', 900)]
    await mount($)

    const held = $.prompt.submit(composer(PROMPT))

    await world.clock.advance(800)

    world.blitGate = new Promise<void>(() => {})
    await world.clock.advance(4199)

    let isSettled = false

    void held.then(() => {
      isSettled = true
    })
    await world.clock.settle()

    expect(isSettled, 'still held a millisecond before 5 s').toBe(false)

    await world.clock.advance(1)

    expect(await held).toEqual({ text: PROMPT })
    expect(world.toasts).toEqual(['Flagged (unclear) but sent: the plugin panel above the prompt is not showing the coach.'])
  })

  test('a verdict counted past the deadline passes the prompt', async ($, on) => {
    const world = seat(on)

    world.stateWriteMs = 40
    world.replies = { haiku: [answer('unclear', 900)], standby: [answer(verdict('unclear'), 4060)] }
    await mount($)

    let passedAt: number | null = null

    const held = $.prompt.submit(composer(PROMPT)).then(r => {
      passedAt = world.clock.now()

      return r
    })

    await world.clock.advance(4900)

    world.blitGate = new Promise<void>(() => {})
    await world.clock.advance(300)

    expect(await held).toEqual({ text: PROMPT })
    expect(passedAt, 'once the late answer was counted, past 5 s').toBe(NOW + 5080)
    expect(world.toasts).toEqual([])
  })

  test('a band the surface let go is not checked at its old address', async ($, on) => {
    const world = seat(on)
    const band = await mount($)

    await $.prompt.submit(composer(PROMPT))
    await band.unmount()

    const blits = world.blits.length

    expect(await $.prompt.submit(composer(OTHER))).toEqual({ text: OTHER })
    expect(world.blits.length, 'nothing blitted where the band was').toBe(blits)
    expect(world.toasts).toEqual(['Flagged (unclear) but sent: the plugin panel above the prompt is not showing the coach.'])
  })

  test('a collapsed band on kitty passes the prompt and keeps the Image', async ($, on) => {
    const world = seat(on, { env: { TERM: 'xterm-kitty' } })

    world.replies.haiku = [answer('unclear', 900)]

    const band = await mount($)

    world.denyBlit = args => ('source' in args ? 'no Image of its own is mounted under key "sprite" in above-prompt' : NOT_MOUNTED)

    expect(await judged($, world)).toEqual({ text: PROMPT })
    expect(world.toasts).toEqual(['Flagged (unclear) but sent: the plugin panel above the prompt is hidden.'])

    world.denyBlit = () => undefined

    expect(await judged($, world), 'shown again').toEqual(dropOf('unclear'))
    expect(isMarkerCheck(world.blits.at(-1)), 'checked on the Raster marker, not the Image').toBe(true)
    expect((await band.find({ key: 'marker' }))?.props, 'the marker drawn beside the Image').toMatchObject({ columns: 1, rows: 1 })
    expect(await shapeOf(band), 'not taken for a terminal without pixels').toEqual(['Image', 16, 8])

    world.replies.haiku = [answer('unclear')]
    world.denyBlit = args => ('source' in args ? 'the Image draws its alt here: the terminal draws no placeholder images' : undefined)

    expect(await $.prompt.submit(composer(PROMPT)), 'an Image drawn as its alt still shows the bubble').toEqual(dropOf('unclear'))

    await world.clock.advance(250)

    expect(await shapeOf(band), 'and Raster takes over at its next frame').toEqual(['Raster', 16, 8])
  })
})

const FULLSCREEN = { columns: 200, rows: 50, isFullscreen: true } as const

const PANE = { title: 'coach', isFocused: false, bodyColumns: 18, placement: 'dock', scroll: { offset: 0, bodyRows: 40 }, view: {} } as const

const mountFullscreen = ($: Engine, viewport: { columns: number; rows: number; isFullscreen?: boolean } = FULLSCREEN) =>
  $.ui.mount({ plugin: 'prompt-coach', surface: 'terminal', component: 'AbovePrompt', requestId: 'above-prompt', props: BAND, viewport })

const mountPane = ($: Engine, bodyColumns: number = PANE.bodyColumns) =>
  $.ui.mount({ plugin: 'prompt-coach', surface: 'terminal', component: 'Pane', requestId: 'prompt-coach', props: { ...PANE, bodyColumns } })

const paneBlits = (world: ReturnType<typeof seat>) => world.blits.filter(args => args.requestId === 'prompt-coach').map(blitCells)

const blinkCells = toRaster(BLINK).flat().map(cell => [cell.char, cell.fg, cell.bg])

describe('mascot', () => {
  test('opens one docked pane a session, only under the fullscreen renderer', async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [answer('clear', 600)]

    await mountFullscreen($)
    await world.clock.settle()

    expect(world.opened).toEqual([{ id: 'prompt-coach', title: 'coach', columns: 18 }])

    await judged($, world)

    expect(world.opened, 'a later draw of the band opens nothing more, so a pane the person closed stays closed').toHaveLength(1)
  })

  test('opens no pane where the renderer would seat it inline', async ($, on) => {
    const world = seat(on)

    await mountFullscreen($, { columns: 200, rows: 50, isFullscreen: false })
    await world.clock.settle()

    expect(world.opened).toEqual([])
  })

  test('CC_COACH_MASCOT=off opens no pane, and the coach still judges', async ($, on) => {
    const world = seat(on, { env: { CC_COACH_MASCOT: 'off' } })

    await mountFullscreen($)
    await world.clock.settle()

    expect(world.opened).toEqual([])
    expect(await judged($, world)).toEqual(dropOf('unclear'))
  })

  test('CC_PROMPT_COACH=off opens no pane either', async ($, on) => {
    const world = seat(on, { env: { CC_PROMPT_COACH: 'off' } })

    await mountFullscreen($)
    await world.clock.settle()

    expect(world.opened).toEqual([])
  })

  test('the pane shows the idle sprite and follows the judgment', async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [answer('clear', 1000)]

    const pane = await mountPane($)

    expect(await shapeOf(pane)).toEqual(['Raster', 16, 8])
    expect(decoded((await spriteOf(pane))?.props.cells)).toEqual(frameCells('idle', 0))
    expect(await lines(pane), 'no caption at rest, and the Still button').toEqual(['Still'])

    const submitted = $.prompt.submit(composer(PROMPT))

    await world.clock.settle()

    expect(decoded((await spriteOf(pane))?.props.cells), 'thinking while the band holds the prompt').toEqual(frameCells('thinking', 1))
    expect(await lines(pane)).toEqual(['checking…', 'Still'])

    await world.clock.advance(250)

    expect(paneBlits(world).at(-1), 'animated with the band').toEqual(frameCells('thinking', 0))

    await world.clock.advance(750)
    await submitted

    expect(decoded((await spriteOf(pane))?.props.cells), 'back at rest once the prompt passes').toEqual(frameCells('idle', 0))
  })

  test('says flagged while the band shows a bubble', async ($, on) => {
    const world = seat(on)
    const pane = await mountPane($)

    await mount($)

    world.replies.haiku = [answer('unclear', 900)]

    expect(await judged($, world)).toEqual(dropOf('unclear'))
    expect(await lines(pane)).toEqual(['flagged', 'Still'])
    expect(decoded((await spriteOf(pane))?.props.cells)).toEqual(frameCells('talking', 1))
  })

  test('blinks every 4 s at rest and opens its eyes again', async ($, on) => {
    const world = seat(on)

    await mountPane($)
    await world.clock.advance(4000)

    expect(paneBlits(world)).toEqual([blinkCells])

    await world.clock.advance(150)

    expect(paneBlits(world)).toEqual([blinkCells, frameCells('idle', 0)])

    await world.clock.advance(4000)

    expect(paneBlits(world), 'and again 4 s later').toHaveLength(4)
  })

  test('Still stops the blink for the session and leaves the sprite', async ($, on) => {
    const world = seat(on)
    const pane = await mountPane($)

    await pane.press({ key: 'still' })
    await world.clock.advance(12_000)

    expect(paneBlits(world)).toEqual([])
    expect(await lines(pane), 'the button goes once it has done its job').toEqual([])
    expect(await shapeOf(pane)).toEqual(['Raster', 16, 8])
  })

  test('a pane that refuses the blink stops blinking until it draws again', async ($, on) => {
    const world = seat(on)
    const pane = await mountPane($)

    world.denyBlit = args => (args.requestId === 'prompt-coach' ? 'no Raster of its own is mounted under key "sprite" in prompt-coach' : undefined)

    await world.clock.advance(12_000)

    expect(paneBlits(world), 'one refused try, then none').toHaveLength(1)

    world.denyBlit = () => undefined
    await pane.redraw()
    await world.clock.advance(4000)

    expect(paneBlits(world).at(-1), 'blinking again once the pane draws').toEqual(blinkCells)
  })

  test('a pane narrower than the sprite shows no sprite and never blinks', async ($, on) => {
    const world = seat(on)
    const pane = await mountPane($, 10)

    await world.clock.advance(8000)

    expect(await spriteOf(pane)).toBeUndefined()
    expect(await lines(pane)).toEqual([])
    expect(paneBlits(world)).toEqual([])
  })

  test('statusline shows a text face in any renderer, and opens no pane', { options: { cc_coach_mascot: 'statusline' } }, async ($, on) => {
    const world = seat(on)

    await mountFullscreen($, { columns: 100, rows: 30, isFullscreen: false })
    await world.clock.settle()

    expect(world.statuses).toEqual(['(^_^) coach'])
    expect(world.opened).toEqual([])
  })

  test('the status line follows the judgment', { options: { cc_coach_mascot: 'statusline' } }, async ($, on) => {
    const world = seat(on)

    await mountFullscreen($)
    await world.clock.settle()

    world.replies.haiku = [answer('unclear', 900)]

    expect(await judged($, world)).toEqual(dropOf('unclear'))
    expect(world.statuses).toEqual(['(^_^) coach', '(-_-) coach  checking…', `(O_O) coach  Unclear: ${REASON}`])

    world.replies.haiku = [answer('clear', 600)]
    await judged($, world, OTHER)

    expect(world.statuses.slice(3), 'the next prompt ends the flag').toEqual(['(^_^) coach', '(-_-) coach  checking…', '(^_^) coach'])
  })

  test('CC_COACH_MASCOT=statusline beats the pane option', { options: { cc_coach_mascot: 'pane' } }, async ($, on) => {
    const world = seat(on, { env: { CC_COACH_MASCOT: 'statusline' } })

    await mountFullscreen($)
    await world.clock.settle()

    expect([world.statuses, world.opened]).toEqual([['(^_^) coach'], []])
  })

  test('off shows no mascot at all', { options: { cc_coach_mascot: 'off' } }, async ($, on) => {
    const world = seat(on)

    await mountFullscreen($)
    await world.clock.settle()

    expect([world.statuses, world.opened], 'only the clear of a face an earlier display left').toEqual([[undefined], []])
  })

  test('CC_COACH_MASCOT=0 is off, as the other switches read it', { options: { cc_coach_mascot: 'statusline' } }, async ($, on) => {
    const world = seat(on, { env: { CC_COACH_MASCOT: '0' } })

    await mountFullscreen($)
    await world.clock.settle()

    expect([world.statuses, world.opened]).toEqual([[undefined], []])
  })

  test('a display other than pane closes the pane a /config change left open', { options: { cc_coach_mascot: 'statusline' } }, async ($, on) => {
    const world = seat(on)

    world.panes = ['prompt-coach']
    await mountFullscreen($)
    await world.clock.settle()

    expect([world.closed, world.statuses]).toEqual([['prompt-coach'], ['(^_^) coach']])
  })

  test('the pane draws nothing and never blinks unless the display is pane', { options: { cc_coach_mascot: 'off' } }, async ($, on) => {
    const world = seat(on)
    const pane = await mountPane($)

    await world.clock.advance(8000)

    expect([await spriteOf(pane), await lines(pane), paneBlits(world)]).toEqual([undefined, [], []])
  })

  test('a frame still in flight when the judgment ends is not blitted over the redrawn pane', async ($, on) => {
    const world = seat(on)
    let release = () => {}

    world.replies.haiku = [answer('clear', 1000)]
    await mountPane($)
    await mount($)

    const submitted = $.prompt.submit(composer(PROMPT))

    await world.clock.settle()
    world.blitGate = new Promise(resolve => {
      release = resolve
    })
    await world.clock.advance(1000)
    await submitted
    release()
    await world.clock.settle()

    expect(paneBlits(world).filter(cells => JSON.stringify(cells) !== JSON.stringify(blinkCells))).toEqual([])
  })

  test('a switch to pane clears the face a statusline display left', async ($, on) => {
    const world = seat(on)

    await mountFullscreen($)
    await world.clock.settle()

    expect([world.statuses, world.opened]).toEqual([[undefined], [{ id: 'prompt-coach', title: 'coach', columns: 18 }]])
  })

  test('looks for a leftover pane once, however often the band draws', { options: { cc_coach_mascot: 'off' } }, async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [answer('clear', 600)]
    await mountFullscreen($)
    await judged($, world)
    await judged($, world, OTHER)

    expect(world.paneReads).toBe(1)
  })

  test('clears a leftover face once while a pane waits for the fullscreen renderer', async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [answer('clear', 600)]
    await mountFullscreen($, { columns: 100, rows: 30, isFullscreen: false })
    await judged($, world)
    await judged($, world, OTHER)

    expect([world.statuses, world.opened]).toEqual([[undefined], []])
  })
})

