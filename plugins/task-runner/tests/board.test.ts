import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const NOW = Date.UTC(2026, 9, 6, 12)
const INDEX = '/work/taskmaster-docs/tasks/ship-mods/00-INDEX.md'
const RUN = '/work/.claude/task-runner/active-run.json'
const SENTINEL = '/work/.claude/cc-phase.json'

const row = (id: string, status: string) => `| ${id} | Card ${id} | none | generic | A | ${status} |`

const BOARD = [
  'Spec: taskmaster-docs/specs/ship-mods.md',
  'Goal: true (two lanes)',
  '',
  '| card | title | depends-on | agent | parallel group | status |',
  '|---|---|---|---|---|---|',
  ...['01', '02', '03', '04'].map(id => row(id, 'done (ad591b7e)')),
  row('05', 'in_progress (delegated)'),
  ...['06', '07', '08', '09', '10', '11'].map(id => row(id, 'pending')),
  row('12', 'parked(needs a decision)'),
  '',
].join('\n')

const RUN_HERE = JSON.stringify({ slug: 'ship-mods', branch: 'feat/x', index_path: 'taskmaster-docs/tasks/ship-mods/00-INDEX.md' })
const RUN_HERE_ABSOLUTE = JSON.stringify({ slug: 'ship-mods', branch: 'feat/x', index_path: INDEX })
const RUN_ELSEWHERE = JSON.stringify({ slug: 'ship-mods', branch: 'master', index_path: INDEX })
const PLAIN_RUN = JSON.stringify({ slug: 'adhoc', branch: 'feat/x' })
const VERIFY = JSON.stringify({ phase: 'verify', owner: 'task-runner:run', session_id: 'S1' })

type Live = { version?: string; env?: Record<string, string> }

function seat(on: On, live: Live = {}) {
  const world = {
    disk: new Map<string, { text: string; mtimeMs: number }>(),
    statuses: [] as (string | undefined)[],
    reads: [] as string[],
    failedReads: 0,
    unstatted: new Set<string>(),
    gate: undefined as { path: string; enter: () => void; released: Promise<void> } | undefined,
  }
  const put = (path: string, text: string) => world.disk.set(path, { text, mtimeMs: (world.disk.get(path)?.mtimeMs ?? NOW - 60_000) + 1_000 })

  // The next read of `path` answers what the file held when it was asked, once released: how two refreshes overlap.
  const holdNextRead = (path: string) => {
    let enter = () => {}
    let release = () => {}
    const reached = new Promise<void>(resolve => {
      enter = resolve
    })
    const released = new Promise<void>(resolve => {
      release = resolve
    })

    world.gate = { path, enter, released }

    return { reached, release }
  }

  mock.clock(on, { now: NOW })
  mock.env(on, live.env ?? {})

  on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  on('session.id', () => ({ value: 'S1' }))
  on('session.cwd', () => ({ value: '/work' }))
  on('session.start', ($, e) => ({ cwd: e.cwd }))

  on('process.run', ($, e) => {
    const answers: Record<string, string> = {
      'git rev-parse --show-cdup': '\n',
      'git rev-parse --abbrev-ref HEAD': 'feat/x\n',
    }
    const stdout = answers[e.argv.join(' ')]

    return stdout === undefined
      ? { deny: `unexpected command: ${e.argv.join(' ')}` }
      : { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  on('fs.stat', ($, e) => {
    const file = world.disk.get(e.path)

    return file === undefined || world.unstatted.has(e.path)
      ? { deny: `ENOENT: ${e.path}` }
      : { value: { kind: 'file', size: file.text.length, mtimeMs: file.mtimeMs, isLink: false } }
  })

  on('fs.read', async ($, e) => {
    world.reads.push(e.path)

    const file = world.disk.get(e.path)
    const gate = world.gate

    if (gate?.path === e.path) {
      world.gate = undefined
      gate.enter()
      await gate.released
    }

    if (e.path === INDEX && world.failedReads > 0) {
      world.failedReads -= 1

      return { deny: `EIO: ${e.path}` }
    }

    return file === undefined ? { deny: `ENOENT: ${e.path}` } : { value: file.text }
  })

  on('tool.call', ($, e) => {
    if (e.tool === 'Write') {
      put(e.file_path, e.content)
    }

    if (e.tool === 'Edit') {
      put(e.file_path, (world.disk.get(e.file_path)?.text ?? '').replace(e.old_string, e.new_string))
    }

    if (e.tool === 'Bash' && e.command === 'rm .claude/task-runner/active-run.json') {
      world.disk.delete(RUN)
    }

    return { result: 'ok' }
  })

  on('ui.status', ($, e) => {
    world.statuses.push(e.text)

    return { value: undefined }
  })

  return Object.assign(world, { put, holdNextRead })
}

const SESSION = { cwd: '/work', surface: 'terminal', isInteractive: true } as const

const start = ($: Engine) => $.session.start(SESSION)

const edit = ($: Engine, old_string: string, new_string: string, agentId?: string) =>
  $.tool.call({ tool: 'Edit', file_path: INDEX, old_string, new_string, ...(agentId !== undefined && { agentId }) })

describe('board', () => {
  test('status line shows card 5/12 with one parked', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, BOARD)
    world.put(SENTINEL, VERIFY)
    await start($)

    expect(world.statuses).toEqual(['task-runner  verify  card 5/12  1 parked  goal'])
  })

  test('clears the line while the run is on another branch', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_ELSEWHERE)
    world.put(INDEX, BOARD)
    await start($)

    expect(world.statuses).toEqual([undefined])
  })

  test('a plain run shows the phase with no card part', async ($, on) => {
    const world = seat(on)

    world.put(RUN, PLAIN_RUN)
    await start($)

    expect(world.statuses).toEqual(['task-runner  build'])
  })

  test('an index with no card table shows the phase with no card part', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, '# Task index\n\nCards follow.\n')
    await start($)

    expect(world.statuses).toEqual(['task-runner  build'])
  })

  test('updates the line when a subagent edits the index mid-turn', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE_ABSOLUTE)
    world.put(INDEX, BOARD)
    await start($)
    await edit(
      $,
      `${row('05', 'in_progress (delegated)')}\n${row('06', 'pending')}`,
      `${row('05', 'done (9f1c2b3a)')}\n${row('06', 'in_progress (delegated)')}`,
      'a1',
    )

    expect(world.statuses).toEqual(['task-runner  build  card 5/12  1 parked  goal', 'task-runner  build  card 6/12  1 parked  goal'])
  })

  test('reads the index again only once its mtime changes', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, BOARD)
    await start($)
    await $.tool.call({ tool: 'Bash', command: 'true' })
    await edit($, row('07', 'pending'), row('07', 'blocked-by 05'))

    expect(world.reads.filter(path => path === INDEX)).toEqual([INDEX, INDEX])
  })

  test('reads the index again after a failed read at the same mtime', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, BOARD)
    world.failedReads = 1
    await start($)
    await $.tool.call({ tool: 'Bash', command: 'true' })

    expect(world.statuses).toEqual(['task-runner  build', 'task-runner  build  card 5/12  1 parked  goal'])
  })

  test('reads the index on every refresh while it cannot be statted', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, BOARD)
    world.unstatted.add(INDEX)
    await start($)
    await edit($, `${row('05', 'in_progress (delegated)')}\n${row('06', 'pending')}`, `${row('05', 'done (9f1c2b3a)')}\n${row('06', 'in_progress (delegated)')}`)

    expect(world.statuses).toEqual(['task-runner  build  card 5/12  1 parked  goal', 'task-runner  build  card 6/12  1 parked  goal'])
  })

  test('an older refresh finishing last does not repaint an ended run', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, BOARD)

    const read = world.holdNextRead(RUN)
    const older = $.tool.call({ tool: 'Bash', command: 'true' })

    await read.reached
    await $.tool.call({ tool: 'Bash', command: 'rm .claude/task-runner/active-run.json' })
    read.release()
    await older

    expect(world.statuses).toEqual([undefined])
  })

  test('an older refresh finishing last does not clear a run that started', async ($, on) => {
    const world = seat(on)

    world.put(INDEX, BOARD)

    const read = world.holdNextRead(RUN)
    const older = $.tool.call({ tool: 'Bash', command: 'true' })

    await read.reached
    await $.tool.call({ tool: 'Write', file_path: RUN, content: RUN_HERE })
    read.release()
    await older

    expect(world.statuses).toEqual(['task-runner  build  card 5/12  1 parked  goal'])
  })

  test('clears the line when the run ends', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, BOARD)
    await start($)
    await $.tool.call({ tool: 'Bash', command: 'rm .claude/task-runner/active-run.json' })

    expect(world.statuses).toEqual(['task-runner  build  card 5/12  1 parked  goal', undefined])
  })

  test('clears the line under CC_TASK_BOARD=off', async ($, on) => {
    const world = seat(on, { env: { CC_TASK_BOARD: 'off' } })

    world.put(RUN, RUN_HERE)
    world.put(INDEX, BOARD)
    await start($)

    expect(world.statuses).toEqual([undefined])
  })

  test('clears the line with cc_task_board off in /config', { options: { cc_task_board: false } }, async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, BOARD)
    await start($)

    expect(world.statuses).toEqual([undefined])
  })

  test('sets nothing below CLI 2.1.291', async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    world.put(RUN, RUN_HERE)
    world.put(INDEX, BOARD)
    await start($)
    await $.tool.call({ tool: 'Bash', command: 'true' })

    expect(world.statuses).toEqual([])
  })
})
