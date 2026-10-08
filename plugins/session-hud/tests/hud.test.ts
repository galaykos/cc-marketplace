import type { On, SessionUsage } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine, Mounted } from 'claude-code/testing'

const NOW = Date.UTC(2026, 9, 8, 12)

const HINT = { isDraft: false, isWorking: false, hint: '? for shortcuts' } as const

const PANE = { title: 'HUD', isFocused: false, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 20 }, view: {} } as const

const HUD = { command: 'hud', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 160 } } as const

type Live = { version?: string; env?: Record<string, string>; isGit?: boolean; isDirty?: boolean }

function seat(on: On, live: Live = {}) {
  const world = {
    costUsd: 1.2,
    percent: 43 as number | undefined,
    statuses: [] as (string | undefined)[],
    panes: new Set<string>(),
    opened: [] as string[],
    closed: [] as string[],
    registered: [] as string[],
    git: [] as string[],
    pointer: undefined as string | undefined,
    writes: [] as [string, string][],
    clock: mock.clock(on, { now: NOW }),
    usage(breakdown: boolean): SessionUsage {
      return {
        startedAt: NOW - 42 * 60_000,
        context: {
          window: 200_000,
          ...(this.percent !== undefined && { percent: this.percent, tokens: this.percent * 2000 }),
          ...(breakdown && {
            breakdown: {
              categories: [
                { name: 'Messages', tokens: 50_000, color: 'x', isDeferred: false, kind: 'used' },
                { name: 'Free space', tokens: 90_000, color: 'x', isDeferred: false, kind: 'free' },
              ],
              totalTokens: 86_000,
              maxTokens: 200_000,
              rawMaxTokens: 200_000,
              autoCompactThreshold: 160_000,
            } as unknown as NonNullable<SessionUsage['context']['breakdown']>,
          }),
        },
        rateLimits: [{ kind: 'five_hour', percentUsed: 61, resetsAt: new Date(NOW + 2 * 3_600_000 + 5 * 60_000).toISOString() }],
        cost: { usd: this.costUsd },
      }
    },
  }

  mock.env(on, { HOME: '/home/u', ...live.env })

  on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  on('session.id', () => ({ value: 'S1' }))
  on('session.cwd', () => ({ value: '/work' }))
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.usage', ($, e) => ({ value: world.usage(e.breakdown !== undefined) }))

  on('process.run', ($, e) => {
    const command = e.argv.join(' ')

    world.git.push(command)

    if (live.isGit === false) {
      return { value: { exitCode: 128, stdout: '', stderr: 'fatal: not a git repository', isStdoutTruncated: false, isStderrTruncated: false } }
    }

    const answers: Record<string, string> = {
      'git rev-parse --abbrev-ref HEAD': 'main\n',
      'git status --porcelain --untracked-files=no': live.isDirty === false ? '' : ' M src/app.ts\n',
    }
    const stdout = answers[command]

    return stdout === undefined
      ? { deny: `unexpected command: ${command}` }
      : { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  on('fs.read', ($, e) =>
    e.path === '/home/u/.claude/plugins/session-hud-root' && world.pointer !== undefined ? { value: world.pointer } : { deny: `ENOENT: ${e.path}` },
  )

  on('fs.write', ($, e) => {
    world.writes.push([e.path, e.text])
    world.pointer = e.text

    return { value: undefined }
  })

  on('ui.status', ($, e) => {
    world.statuses.push(e.text)

    return { value: undefined }
  })

  on('ui.open', ($, e) => {
    world.opened.push(e.id)
    world.panes.add(e.id)

    return { value: { isPlaced: true } }
  })

  on('ui.close', ($, e) => {
    world.closed.push(e.id)
    world.panes.delete(e.id)

    return { value: undefined }
  })

  on('ui.panes', () => ({ value: [...world.panes].map(id => ({ id, title: 'HUD', isShown: true, isFocused: false, isPlaced: true })) }))

  on('command.register', ($, e) => {
    world.registered.push(e.name)

    return { value: { command: e.name } }
  })

  on('command.run', ($, e) => ({ text: `Unknown command: /${e.command}` }))
  on('tool.call', () => ({ result: 'ok' }))
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', ($, e) => ({ text: e.answer }))

  // As core draws them: the hint line with whatever tail reached it, the footer as its word and seconds.
  on('ui.render', { component: 'PromptHint' }, ($, e) => $.ui.resolve(e).Text({ children: `${e.props.hint}|${e.props.tail ?? ''}` }))
  on('ui.render', { component: 'TurnDuration' }, ($, e) => $.ui.resolve(e).Text({ children: `${e.props.word} for ${Math.round(e.props.durationMs / 1000)}s` }))
  on('ui.render', { component: 'Pane' }, ($, e) => $.ui.resolve(e).Text({ children: 'drawn by core' }))

  return world
}

const start = ($: Engine) => $.session.start({ cwd: '/work', surface: 'terminal', isInteractive: true })

const texts = async <C extends 'PromptHint' | 'TurnDuration' | 'Pane'>(drawing: Mounted<'terminal', C>) =>
  (await drawing.findAll({ type: 'Text' })).map(text => text.text)

const hint = async ($: Engine, tail?: string) =>
  texts(
    await $.ui.mount({
      plugin: 'session-hud',
      surface: 'terminal',
      component: 'PromptHint',
      requestId: 'prompt-hint',
      props: tail === undefined ? HINT : { ...HINT, tail },
    }),
  )

const footer = async ($: Engine, requestId: string, durationMs: number) =>
  texts(await $.ui.mount({ plugin: 'session-hud', surface: 'terminal', component: 'TurnDuration', requestId, props: { word: 'Baked', durationMs } }))

const pane = async ($: Engine) => texts(await $.ui.mount({ plugin: 'session-hud', surface: 'terminal', component: 'Pane', requestId: 'hud', props: PANE }))

const LINE = 'ctx 43% · 5h 61% ↻2h05m · $1.20 · 42m · main*'

describe('session-hud', () => {
  test('adds every segment to the hint line at session start', async ($, on) => {
    seat(on)
    await start($)

    expect(await hint($)).toEqual([`? for shortcuts|${LINE}`])
  })

  test("appends after another plugin's tail instead of replacing it", async ($, on) => {
    seat(on)
    await start($)

    expect(await hint($, '[TERSE:FULL]')).toEqual([`? for shortcuts|[TERSE:FULL] · ${LINE}`])
  })

  test('follows the cc_hud_segments order', { options: { cc_hud_segments: 'cost,context' } }, async ($, on) => {
    seat(on)
    await start($)

    expect(await hint($)).toEqual(['? for shortcuts|$1.20 · ctx 43%'])
  })

  test('lets CC_HUD_SEGMENTS override the option', { options: { cc_hud_segments: 'cost' } }, async ($, on) => {
    seat(on, { env: { CC_HUD_SEGMENTS: 'git' } })
    await start($)

    expect(await hint($)).toEqual(['? for shortcuts|main*'])
  })

  test('runs no git command when the git segment is not picked', { options: { cc_hud_segments: 'context' } }, async ($, on) => {
    const world = seat(on)

    await start($)

    expect(world.git).toEqual([])
  })

  test('shows no branch outside a git repository', async ($, on) => {
    seat(on, { isGit: false })
    await start($)

    expect(await hint($)).toEqual(['? for shortcuts|ctx 43% · 5h 61% ↻2h05m · $1.20 · 42m'])
  })

  test('marks a clean tree without the star', async ($, on) => {
    seat(on, { isDirty: false })
    await start($)

    expect((await hint($))[0]?.endsWith('· main')).toBe(true)
  })

  test('leaves the hint line alone with CC_HUD_HINT=off', async ($, on) => {
    seat(on, { env: { CC_HUD_HINT: 'off' } })
    await start($)

    expect(await hint($)).toEqual(['? for shortcuts|'])
  })

  test('pins no status line by default', async ($, on) => {
    const world = seat(on)

    await start($)

    expect(world.statuses.filter(line => line !== undefined)).toEqual([])
  })

  test('pins the status line with cc_hud_status on', { options: { cc_hud_status: true } }, async ($, on) => {
    const world = seat(on)

    await start($)

    expect(world.statuses.at(-1)).toBe(LINE)
  })

  test('refreshes the line after a tool call once the gap has passed', async ($, on) => {
    const world = seat(on)

    await start($)
    world.costUsd = 2.5
    await world.clock.advance(2_000)
    await $.tool.call({ tool: 'Bash', command: 'ls' })

    expect(await hint($), 'the countdown moved on with the clock').toEqual(['? for shortcuts|ctx 43% · 5h 61% ↻2h04m · $2.50 · 42m · main*'])
  })

  test('does nothing below the mods floor', async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    await start($)

    expect(await hint($)).toEqual(['? for shortcuts|'])
    expect(world.registered).toEqual([])
  })

  test("adds the turn's output, cost and context growth to its closing line", async ($, on) => {
    const world = seat(on)

    await start($)
    await $.turn.start({ text: 'fix it', turnId: 't1' })
    world.costUsd = 1.28
    world.percent = 49
    await $.turn.complete({
      answer: 'done',
      durationMs: 64_000,
      isAborted: false,
      turnId: 't1',
      reason: 'answer',
      usage: { model: 'claude-opus-5-5', input_tokens: 10, output_tokens: 3_200, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 },
    })

    const drawn = await $.ui.mount({ plugin: 'session-hud', surface: 'terminal', component: 'TurnDuration', requestId: 'm1', props: { word: 'Baked', durationMs: 64_000 } })

    expect(await texts(drawn)).toEqual(['Baked for 64s', '  3.2k out · $0.08 · ctx +6%'])

    await drawn.redraw()

    expect(await texts(drawn), 'a redraw of the same footer keeps its line').toEqual(['Baked for 64s', '  3.2k out · $0.08 · ctx +6%'])
  })

  test("leaves an older turn's footer as the engine draws it", async ($, on) => {
    seat(on)
    await start($)
    await $.turn.complete({
      answer: 'done',
      durationMs: 64_000,
      isAborted: false,
      turnId: 't1',
      reason: 'answer',
      usage: { model: 'claude-opus-5-5', input_tokens: 10, output_tokens: 3_200, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 },
    })

    expect(await footer($, 'm0', 12_000)).toEqual(['Baked for 12s'])
  })

  test('leaves footers alone with cc_hud_turn off', { options: { cc_hud_turn: false } }, async ($, on) => {
    seat(on)
    await start($)
    await $.turn.complete({
      answer: 'done',
      durationMs: 5_000,
      isAborted: false,
      turnId: 't1',
      reason: 'answer',
      usage: { model: 'claude-opus-5-5', input_tokens: 10, output_tokens: 900, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 },
    })

    expect(await footer($, 'm1', 5_000)).toEqual(['Baked for 5s'])
  })

  test('points the subagent rows command at this plugin, once', async ($, on) => {
    const world = seat(on)

    await start($)
    await start($)

    expect(world.writes.length).toBe(1)
    expect(world.writes[0]?.[0]).toBe('/home/u/.claude/plugins/session-hud-root')
    expect(world.writes[0]?.[1].trim().length).toBeGreaterThan(0)
  })

  test('honours CLAUDE_CONFIG_DIR for the pointer', async ($, on) => {
    const world = seat(on, { env: { CLAUDE_CONFIG_DIR: '/cfg/' } })

    await start($)

    expect(world.writes.map(([path]) => path)).toEqual(['/cfg/plugins/session-hud-root'])
  })

  test('starts after a reload that raises no session.start', async ($, on) => {
    const world = seat(on)
    const drawn = await $.ui.mount({ plugin: 'session-hud', surface: 'terminal', component: 'PromptHint', requestId: 'prompt-hint', props: HINT })

    await world.clock.advance(0)

    expect(await texts(drawn)).toEqual([`? for shortcuts|${LINE}`])
    expect(world.registered).toEqual(['hud'])
  })

  test('/hud works after a reload that raises no session.start', async ($, on) => {
    const world = seat(on)

    await $.command.run(HUD)

    expect(world.opened).toEqual(['hud'])
  })

  test('keeps the turn line whole with every other surface off', { options: { cc_hud_hint: false } }, async ($, on) => {
    const world = seat(on)

    await start($)
    await $.turn.start({ text: 'fix it', turnId: 't1' })
    world.costUsd = 1.28
    world.percent = 49
    await $.turn.complete({
      answer: 'done',
      durationMs: 4_000,
      isAborted: false,
      turnId: 't1',
      reason: 'answer',
      usage: { model: 'claude-opus-5-5', input_tokens: 10, output_tokens: 3_200, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 },
    })

    expect(await footer($, 'm1', 4_000)).toEqual(['Baked for 4s', '  3.2k out · $0.08 · ctx +6%'])
    expect(world.git, 'no line shows git, so none runs').toEqual([])
  })

  test("a footer drawn before the turn started never takes that turn's line", async ($, on) => {
    seat(on)
    await start($)

    const old = await $.ui.mount({ plugin: 'session-hud', surface: 'terminal', component: 'TurnDuration', requestId: 'old', props: { word: 'Baked', durationMs: 3_000 } })

    await $.turn.start({ text: 'fix it', turnId: 't1' })
    await $.turn.complete({
      answer: 'done',
      durationMs: 3_400,
      isAborted: false,
      turnId: 't1',
      reason: 'answer',
      usage: { model: 'claude-opus-5-5', input_tokens: 10, output_tokens: 900, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 },
    })
    await old.redraw()

    expect(await texts(old)).toEqual(['Baked for 3s'])
    expect(await footer($, 'new', 3_400)).toEqual(['Baked for 3s', '  900 out'])
  })

  test('/hud registers, opens the pane, and closes it on a second run', async ($, on) => {
    const world = seat(on)

    await start($)
    expect(world.registered).toEqual(['hud'])

    await $.command.run(HUD)
    expect(world.opened).toEqual(['hud'])

    await $.command.run(HUD)
    expect(world.closed).toEqual(['hud'])
  })

  test('the pane draws context, its breakdown, rate limits and the session', async ($, on) => {
    seat(on)
    await start($)
    await $.command.run(HUD)

    const rows = await pane($)

    expect(rows[0]).toBe('Context')
    expect(rows).toContain('compacts at 160k (80%)')
    expect(rows.some(row => row.includes('Messages'))).toBe(true)
    expect(rows.some(row => row.includes('Free space'))).toBe(false)
    expect(rows.at(-1)).toBe('$1.20  42m  main*')
  })
})
