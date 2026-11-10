import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

const INDEX = '/work/taskmaster-docs/tasks/ship/00-INDEX.md'
const RUN = '/work/.claude/task-runner/active-run.json'
const TOOL = 'mcp__task-runner__card_status'

const row = (id: string, status: string) => `| ${id} | Card ${id} | none | generic | A | ${status} |`

const BOARD = [
  '# Index',
  '',
  '| card | title | depends-on | agent | parallel group | status |',
  '|---|---|---|---|---|---|',
  row('01', 'done (ad591b7e)'),
  row('02', 'in_progress'),
  row('03', 'pending'),
  row('04', 'pending'),
  '',
  '## Coverage',
  '',
  '| Success criterion | Covered by | Status |',
  '|---|---|---|',
  '| 1. It ships | 02 | covered |',
  '',
].join('\n')

type Live = { version?: string; env?: Record<string, string>; run?: string | null; index?: string; branch?: string }

function seat(on: On, live: Live = {}) {
  const run = live.run === undefined ? JSON.stringify({ slug: 'ship', branch: 'feat/x', index_path: 'taskmaster-docs/tasks/ship/00-INDEX.md' }) : live.run
  const world = { disk: new Map<string, string>([[INDEX, live.index ?? BOARD]]), registered: [] as { name: string; isDeferred?: unknown }[], writes: 0 }

  if (run !== null) {
    world.disk.set(RUN, run)
  }

  // hooks/board.ts shares the module: its refresh asks the clock and paints a status line.
  mock.clock(on, { now: Date.UTC(2026, 10, 10, 12) })
  mock.env(on, live.env ?? {})

  on('ui.status', () => ({ value: undefined }))

  on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  on('session.id', () => ({ value: 'S1' }))
  on('session.cwd', () => ({ value: '/work' }))
  on('session.start', ($, e) => ({ cwd: e.cwd }))

  on('process.run', ($, e) => {
    const answers: Record<string, [number, string]> = {
      'git rev-parse --show-cdup': [0, '\n'],
      'git symbolic-ref -q HEAD': [0, `refs/heads/${live.branch ?? 'feat/x'}\n`],
    }
    const [exitCode, stdout] = answers[e.argv.join(' ')] ?? []

    return stdout === undefined || exitCode === undefined
      ? { deny: `unexpected command: ${e.argv.join(' ')}` }
      : { value: { exitCode, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  on('fs.read', ($, e) => {
    const file = world.disk.get(e.path)

    return file === undefined ? { deny: `ENOENT: ${e.path}` } : { value: file }
  })

  on('fs.write', ($, e) => {
    world.writes += 1
    world.disk.set(e.path, e.text)

    return { value: undefined }
  })

  on('tool.register', ($, e) => {
    world.registered.push({ name: e.name, isDeferred: e.isDeferred })

    return { value: { tool: `mcp__task-runner__${e.name}` } }
  })

  on('tool.call', ($, e) => {
    if (e.tool === 'Bash' && e.command.includes('register-run.sh')) {
      world.disk.set(RUN, JSON.stringify({ slug: 'ship', branch: 'feat/x', index_path: INDEX }))
    }

    return e.tool === TOOL ? { deny: 'no hook answered the registered tool' } : { result: 'ok' }
  })

  const statusOf = (id: string) => {
    const line = (world.disk.get(INDEX) ?? '').split('\n').find(found => found.startsWith(`| ${id} |`)) ?? ''

    return line.split('|').at(-2)?.trim()
  }

  return { world, statusOf }
}

const start = ($: { session: { start: (e: { cwd: string }) => Promise<unknown> } }) => $.session.start({ cwd: '/work' })

describe('card status tool', () => {
  test('is listed in front at session start while a run with an index is registered on this branch', async ($, on) => {
    const { world } = seat(on)

    await start($)

    expect(world.registered).toEqual([{ name: 'card_status', isDeferred: false }])
  })

  const UNLISTED: [string, Live][] = [
    ['no run', { run: null }],
    ['a run on another branch', { branch: 'other' }],
    ['a run with no index', { run: JSON.stringify({ slug: 'inline', branch: 'feat/x' }) }],
    ['the switch off', { env: { CC_CARD_STATUS: 'off' } }],
    ['a CLI below the mods floor', { version: '2.1.290' }],
  ]

  for (const [name, live] of UNLISTED) {
    test(`is not listed with ${name}`, async ($, on) => {
      const { world } = seat(on, live)

      await start($)

      expect(world.registered).toEqual([])
    })
  }

  test('is listed once the main loop runs register-run.sh, and only once', async ($, on) => {
    const { world } = seat(on, { run: null })

    await start($)
    await $.tool.call({ tool: 'Bash', command: 'bash "/p/scripts/register-run.sh" --index x', agentId: 'a1' })

    expect(world.registered, 'a subagent registers nothing').toEqual([])

    await $.tool.call({ tool: 'Bash', command: 'bash "/p/scripts/register-run.sh" --index x' })
    await $.tool.call({ tool: 'Bash', command: 'bash "/p/scripts/register-run.sh" --index x' })

    expect(world.registered).toHaveLength(1)
  })

  test('writes done with its detail and leaves every other line as it was', async ($, on) => {
    const { world, statusOf } = seat(on)

    const r = await $.tool.call({ tool: TOOL, card: '2', status: 'done', detail: '(9f1c2b3a)' })

    expect(r.result).toBe('card 2: in_progress → done — (9f1c2b3a)')
    expect(statusOf('02')).toBe('done — (9f1c2b3a)')
    expect(world.disk.get(INDEX)).toBe(BOARD.replace(row('02', 'in_progress'), row('02', 'done — (9f1c2b3a)')))
  })

  test('refuses a parked status with no reason, or a forecast in place of one, and writes nothing', async ($, on) => {
    const { world, statusOf } = seat(on)

    const bare = await $.tool.call({ tool: TOOL, card: '03', status: 'parked', detail: 'too large for one session' })
    const forecast = await $.tool.call({ tool: TOOL, card: '03', status: 'parked', reason: 'infeasible', detail: 'out of budget' })

    expect(bare.deny).toContain('a parked card names its reason')
    expect(forecast.deny).toContain('is a forecast, not a reason')
    expect(statusOf('03')).toBe('pending')
    expect(world.writes).toBe(0)
  })

  test('parks on evidence with the failing line, and refuses evidence with no detail', async ($, on) => {
    const { statusOf } = seat(on)

    const empty = await $.tool.call({ tool: TOOL, card: '03', status: 'parked', reason: 'evidence' })

    expect(empty.deny).toContain('needs a detail')

    await $.tool.call({ tool: TOOL, card: '03', status: 'parked', reason: 'evidence', detail: '3 cycles, TypeError at parse.py:41' })

    expect(statusOf('03')).toBe('parked (evidence: 3 cycles, TypeError at parse.py:41)')
  })

  test('a split names child rows that exist, never itself', async ($, on) => {
    const { statusOf } = seat(on)

    const none = await $.tool.call({ tool: TOOL, card: '02', status: 'parked', reason: 'split' })
    const missing = await $.tool.call({ tool: TOOL, card: '02', status: 'parked', reason: 'split', children: ['03', '09'] })
    const self = await $.tool.call({ tool: TOOL, card: '02', status: 'parked', reason: 'split', children: ['2'] })

    expect(none.deny).toContain('names its child cards')
    expect(missing.deny).toContain('child 09 has no card row')
    expect(self.deny).toContain('cannot be its own child')

    await $.tool.call({ tool: TOOL, card: '02', status: 'parked', reason: 'split', children: ['03', '04'] })

    expect(statusOf('02')).toBe('parked (split: 03 04)')
  })

  test('a split parent reopens only once every child is done', async ($, on) => {
    const { statusOf } = seat(on, { index: BOARD.replace(row('02', 'in_progress'), row('02', 'parked (split: 03 04)')).replace(row('03', 'pending'), row('03', 'done')) })

    const early = await $.tool.call({ tool: TOOL, card: '02', status: 'pending' })

    expect(early.deny).toContain('its child 04 is not done')
    expect(statusOf('02')).toBe('parked (split: 03 04)')

    await $.tool.call({ tool: TOOL, card: '04', status: 'done' })
    await $.tool.call({ tool: TOOL, card: '02', status: 'pending' })

    expect(statusOf('02')).toBe('pending')
  })

  test('refuses an unknown card, an unknown status and a detail that would break the row', async ($, on) => {
    const { world } = seat(on)

    const card = await $.tool.call({ tool: TOOL, card: '9', status: 'done' })
    const status = await $.tool.call({ tool: TOOL, card: '03', status: 'committed' })
    const pipe = await $.tool.call({ tool: TOOL, card: '03', status: 'done', detail: 'a | b' })

    expect(card.deny).toContain('no card 9 in the index (cards: 01 02 03 04)')
    expect(status.deny).toContain('status is one of')
    expect(pipe.deny).toContain('one line with no |')
    expect(world.writes).toBe(0)
  })

  test('refuses a subagent, and a call with no run registered', async ($, on) => {
    const { world } = seat(on)

    const worker = await $.tool.call({ tool: TOOL, card: '03', status: 'done', agentId: 'a1' })

    expect(worker.deny).toContain('Only the orchestrator writes the card index')
    expect(world.writes).toBe(0)

    world.disk.delete(RUN)

    const idle = await $.tool.call({ tool: TOOL, card: '03', status: 'done' })

    expect(idle.deny).toContain('No task-runner run')
  })

  test('an index with no card table is refused, not rewritten', async ($, on) => {
    const { world } = seat(on, { index: '# Index\n\nNo table.\n' })

    const r = await $.tool.call({ tool: TOOL, card: '01', status: 'done' })

    expect(r.deny).toContain('no card table')
    expect(world.writes).toBe(0)
  })
})
