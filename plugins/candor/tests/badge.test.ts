import type { On } from 'claude-code'
import { describe, expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const LEVEL_FILE = '/home/u/.claude/terse-mode'

const HINT = { isDraft: false, isWorking: false, hint: '? for shortcuts' }

type Live = { version?: string; env?: Record<string, string> }

function seat(on: On, live: Live = {}) {
  const world = {
    env: { HOME: '/home/u', ...live.env } as Record<string, string | undefined>,
    disk: new Map<string, string>(),
    links: new Set<string>(),
    io: [] as string[],
    tails: [] as (string | undefined)[],
    get tail() {
      return this.tails.at(-1)
    },
  }

  on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  on('env.get', ($, e) => ({ value: world.env[e.name] }))

  on('fs.stat', ($, e) => {
    world.io.push(`stat ${e.path}`)

    const text = world.disk.get(e.path)

    return text === undefined
      ? { deny: `ENOENT: ${e.path}` }
      : { value: { kind: 'file', size: text.length, mtimeMs: 0, isLink: world.links.has(e.path) } }
  })

  on('fs.read', ($, e) => {
    world.io.push(`read ${e.path}`)

    const text = world.disk.get(e.path)

    return text === undefined ? { deny: `ENOENT: ${e.path}` } : { value: text }
  })

  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('tool.call', () => ({ result: 'ok' }))

  // The engine beneath every plugin: records the tail the chain handed it.
  on('ui.render', { component: 'PromptHint' }, ($, e) => {
    world.tails.push(e.props.tail)

    return $.ui.resolve(e).Text({ children: e.props.hint })
  })

  return world
}

const start = ($: Engine) => $.session.start({ cwd: '/work', surface: 'terminal', isInteractive: true })

const mount = ($: Engine, tail?: string) =>
  $.ui.mount({ plugin: 'candor', surface: 'terminal', component: 'PromptHint', props: tail === undefined ? HINT : { ...HINT, tail } })

describe('badge', () => {
  test('appends the badge after a tail another plugin set', async ($, on) => {
    const world = seat(on)

    world.disk.set(LEVEL_FILE, 'ultra\n')
    await start($)
    await mount($, 'session 12m')

    expect(world.tail).toBe('session 12m · [TERSE:ULTRA]')
  })

  test('sets the tail to the badge alone when none was set', async ($, on) => {
    const world = seat(on)

    world.disk.set(LEVEL_FILE, '  wenyan-full extra words\nlite\n')
    await start($)
    await mount($)

    expect(world.tail).toBe('[TERSE:WENYAN-FULL]')
  })

  test('adds no tail while terse is off', async ($, on) => {
    const world = seat(on)

    await start($)
    await mount($)
    await mount($, 'session 12m')

    expect(world.tails).toEqual([undefined, 'session 12m'])
  })

  test('takes CC_TERSE over the level file, the level file over cc_terse', { options: { cc_terse: 'lite' } }, async ($, on) => {
    const world = seat(on)

    await start($)
    const ui = await mount($)
    expect(world.tail, 'the option alone').toBe('[TERSE:LITE]')

    world.disk.set(LEVEL_FILE, 'full\n')
    await $.turn.start({ text: '/candor:level full', turnId: 't1' })
    await ui.drawn()
    expect(world.tail, 'the level file over the option').toBe('[TERSE:FULL]')

    world.env.CC_TERSE = 'ultra'
    await $.turn.start({ text: 'next', turnId: 't2' })
    await ui.drawn()
    expect(world.tail, 'CC_TERSE over both').toBe('[TERSE:ULTRA]')
  })

  test('shows nothing for a value out of vocabulary, as statusline.sh does, without falling through', { options: { cc_terse: 'full' } }, async ($, on) => {
    const world = seat(on)

    world.disk.set(LEVEL_FILE, 'ultra\r\n')
    await start($)
    await mount($)

    expect(world.tail).toBe(undefined)
  })

  test('shows nothing for a symlinked level file, even under CC_TERSE', async ($, on) => {
    const world = seat(on, { env: { CC_TERSE: 'ultra' } })

    world.disk.set(LEVEL_FILE, 'ultra\n')
    world.links.add(LEVEL_FILE)
    await start($)
    await mount($)

    expect(world.tail).toBe(undefined)
  })

  test('reads the level file under CLAUDE_CONFIG_DIR when set', async ($, on) => {
    const world = seat(on, { env: { CLAUDE_CONFIG_DIR: '/cfg' } })

    world.disk.set(LEVEL_FILE, 'ultra\n')
    world.disk.set('/cfg/terse-mode', 'lite\n')
    await start($)
    await mount($)

    expect(world.tail).toBe('[TERSE:LITE]')
  })

  test('follows the level switched off mid-session, and back on', async ($, on) => {
    const world = seat(on)

    world.disk.set(LEVEL_FILE, 'full\n')
    await start($)
    const ui = await mount($, 'session 12m')
    expect(world.tail, 'shown before the switch').toBe('session 12m · [TERSE:FULL]')

    world.disk.delete(LEVEL_FILE)
    await $.turn.start({ text: '/candor:level off', turnId: 't1' })
    await ui.drawn()
    expect(world.tail, 'cleared at the next turn').toBe('session 12m')

    world.disk.set(LEVEL_FILE, 'lite\n')
    await $.tool.call({ tool: 'Bash', command: 'true' })
    await ui.drawn()
    expect(world.tail, 'back after a tool call').toBe('session 12m · [TERSE:LITE]')
  })

  test('draws the badge after a reload that raises no session.start', async ($, on) => {
    const world = seat(on)

    world.disk.set(LEVEL_FILE, 'ultra\n')
    const ui = await mount($)
    await ui.drawn()

    expect(world.tails).toEqual([undefined, '[TERSE:ULTRA]'])
  })

  test('leaves the line untouched with CC_TERSE_BADGE=off', async ($, on) => {
    const world = seat(on, { env: { CC_TERSE_BADGE: 'off' } })

    world.disk.set(LEVEL_FILE, 'ultra\n')
    await start($)
    await mount($, 'session 12m')

    expect(world.tails).toEqual(['session 12m'])
  })

  test('leaves the line untouched with cc_terse_badge off in /config', { options: { cc_terse_badge: false } }, async ($, on) => {
    const world = seat(on)

    world.disk.set(LEVEL_FILE, 'ultra\n')
    await start($)
    await mount($)

    expect(world.tails).toEqual([undefined])
  })

  test('lets CC_TERSE_BADGE=on override cc_terse_badge off in /config', { options: { cc_terse_badge: false } }, async ($, on) => {
    const world = seat(on, { env: { CC_TERSE_BADGE: 'on' } })

    world.disk.set(LEVEL_FILE, 'ultra\n')
    await start($)
    await mount($)

    expect(world.tail).toBe('[TERSE:ULTRA]')
  })

  test('does nothing below CLI 2.1.291', async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    world.disk.set(LEVEL_FILE, 'ultra\n')
    await start($)
    await $.turn.start({ text: 'go', turnId: 't1' })
    await mount($, 'session 12m')

    expect({ tails: world.tails, io: world.io }).toEqual({ tails: ['session 12m'], io: [] })
  })
})
