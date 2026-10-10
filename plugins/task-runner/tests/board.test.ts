import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine, Mounted } from 'claude-code/testing'

import { isPinOn } from '../hooks/board'

const NOW = Date.UTC(2026, 9, 6, 12)
const INDEX = '/work/taskmaster-docs/tasks/ship-mods/00-INDEX.md'
const RUN = '/work/.claude/task-runner/active-run.json'
const SENTINEL = '/work/.claude/cc-phase.json'

const row = (id: string, status: string, dependsOn = 'none', group = 'A') => `| ${id} | Card ${id} | ${dependsOn} | generic | ${group} | ${status} |`

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

const TASKS = '/work/taskmaster-docs/tasks'

const LAYOUT = [
  'Spec: taskmaster-docs/specs/ship-mods.md',
  'Ultra: true',
  '',
  '| card | title | depends-on | agent | parallel group | status |',
  '|---|---|---|---|---|---|',
  row('01', 'done (ad591b7e)'),
  row('05', 'in_progress (delegated)', '01', 'B'),
  row('06', 'pending', '05', 'C'),
  row('07', 'parked(needs a decision)', 'none', 'B'),
  row('08', 'blocked-by 06', '06', 'C'),
  '',
].join('\n')

const MILESTONES = [
  '| card | title | depends-on | agent | parallel group | status |',
  '|---|---|---|---|---|---|',
  row('01', 'done (ad591b7e)'),
  row('02', 'pending', '01'),
  row('03', 'pending', '02', 'B'),
  '',
  '### Milestone M1 — gates first',
  'Cards: 01, 02',
  '',
  '### Milestone M2 — then the pane',
  'Cards: 03',
  '',
].join('\n')

const PANE = { title: 'Task board', isFocused: false, bodyColumns: 40, placement: 'dock', scroll: { offset: 0, bodyRows: 3 }, view: {} } as const

const TASK_BOARD = { command: 'task-board', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 160 } } as const

type Live = { version?: string; env?: Record<string, string>; commands?: string[]; isNarrow?: boolean; onOpen?: () => Promise<void> }

function seat(on: On, live: Live = {}) {
  const world = {
    disk: new Map<string, { text: string; mtimeMs: number }>(),
    statuses: [] as (string | undefined)[],
    writes: 0,
    reads: [] as string[],
    failedReads: 0,
    unstatted: new Set<string>(),
    gate: undefined as { path: string; enter: () => void; released: Promise<void> } | undefined,
    writeGate: undefined as { enter: () => void; released: Promise<void> } | undefined,
    panes: new Set<string>(),
    unplaced: new Set<string>(),
    opened: [] as string[],
    closed: [] as string[],
    registered: [] as string[],
    fills: [] as string[],
    submits: [] as string[],
    ran: [] as string[],
  }
  const put = (path: string, text: string) => world.disk.set(path, { text, mtimeMs: (world.disk.get(path)?.mtimeMs ?? NOW - 60_000) + 1_000 })

  const gateOf = () => {
    let enter = () => {}
    let release = () => {}
    const reached = new Promise<void>(resolve => {
      enter = resolve
    })
    const released = new Promise<void>(resolve => {
      release = resolve
    })

    return { enter, released, reached, release }
  }

  // The next read of `path` answers what the file held when it was asked, once released: how two refreshes overlap.
  const holdNextRead = (path: string) => {
    const { enter, released, reached, release } = gateOf()

    world.gate = { path, enter, released }

    return { reached, release }
  }

  // The next board write of an active run lands in the engine's store only once released.
  const holdNextRunWrite = () => {
    const { enter, released, reached, release } = gateOf()

    world.writeGate = { enter, released }

    return { reached, release }
  }

  const clock = mock.clock(on, { now: NOW })
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

  on('fs.list', ($, e) => {
    const names = [...world.disk.keys()].filter(path => path.startsWith(`${e.path}/`)).map(path => path.slice(e.path.length + 1).split('/')[0] ?? '')

    return names.length === 0
      ? { deny: `ENOENT: ${e.path}` }
      : { value: [...new Set(names)].map(name => ({ name, kind: 'dir' as const, size: 0, mtimeMs: 0, isLink: false })) }
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

  on('state.set', async ($, e, next) => {
    world.writes += 1

    const gate = world.writeGate

    if (gate !== undefined && e.value.runActive) {
      world.writeGate = undefined
      gate.enter()
      await gate.released
    }

    return next(e)
  })

  on('ui.status', ($, e) => {
    world.statuses.push(e.text)

    return { value: undefined }
  })

  // As the engine leaves an unasked open waiting on a terminal too narrow to seat it.
  on('ui.open', async ($, e) => {
    world.opened.push(e.id)
    world.panes.add(e.id)

    if (live.isNarrow) {
      world.unplaced.add(e.id)
    } else {
      world.unplaced.delete(e.id)
    }

    await live.onOpen?.()

    return { value: live.isNarrow ? { isPlaced: false, reason: 'unasked panes open from 144 columns' } : { isPlaced: true } }
  })

  on('ui.close', ($, e) => {
    world.closed.push(e.id)
    world.panes.delete(e.id)
    world.unplaced.delete(e.id)

    return { value: undefined }
  })

  on('ui.panes', () => ({ value: [...world.panes].map(id => ({ id, title: 'Task board', isShown: true, isFocused: false, isPlaced: !world.unplaced.has(id) })) }))

  on('command.register', ($, e) => {
    world.registered.push(e.name)

    return { value: { command: e.name } }
  })

  on('command.list', () => ({
    value: (live.commands ?? ['task-runner:run', 'taskmaster:redteam']).map(name => ({ name, description: '', source: 'plugin' as const })),
  }))

  on('command.run', ($, e) => {
    world.ran.push(e.command)

    return { text: `Unknown command: /${e.command}` }
  })

  on('prompt.fill', ($, e) => {
    world.fills.push(e.text)

    return { isFilled: true }
  })

  on('prompt.submit', ($, e) => {
    world.submits.push(e.text)

    return { text: e.text }
  })

  return Object.assign(world, { put, holdNextRead, holdNextRunWrite, clock })
}

const SESSION = { cwd: '/work', surface: 'terminal', isInteractive: true } as const

const start = ($: Engine) => $.session.start(SESSION)

const edit = ($: Engine, old_string: string, new_string: string, agentId?: string) =>
  $.tool.call({ tool: 'Edit', file_path: INDEX, old_string, new_string, ...(agentId !== undefined && { agentId }) })

const mount = ($: Engine, bodyColumns: number = PANE.bodyColumns) =>
  $.ui.mount({ plugin: 'task-runner', surface: 'terminal', component: 'Pane', requestId: 'task-board', props: { ...PANE, bodyColumns } })

const lines = async (pane: Mounted<'terminal', 'Pane'>) => (await pane.findAll({ type: 'Text' })).map(text => text.text)

const drawn = async (pane: Mounted<'terminal', 'Pane'>) =>
  (await pane.findAll({})).filter(element => element.type === 'Text' || element.type === 'Button').map(element => element.text)

const buttons = async (pane: Mounted<'terminal', 'Pane'>) =>
  (await pane.findAll({ type: 'Button' })).map(button => ({
    label: button.text,
    hotkey: button.props.hotkey,
    plain: button.props.plain,
    autoFocus: button.props.autoFocus,
  }))

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

  test('writes the board state only when it changed', async ($, on) => {
    const world = seat(on)

    world.put(INDEX, BOARD)
    await start($)
    await $.tool.call({ tool: 'Bash', command: 'ls' })
    await $.tool.call({ tool: 'Bash', command: 'ls' })

    expect(world.writes, 'no run: written once').toBe(1)

    world.put(RUN, RUN_HERE)
    await $.tool.call({ tool: 'Bash', command: 'ls' })
    await $.tool.call({ tool: 'Bash', command: 'ls' })

    expect(world.writes, 'the run started: written once more').toBe(2)
    expect(world.statuses.at(-1)).toBe('task-runner  build  card 5/12  1 parked  goal')
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
    expect(world.registered).toEqual([])
    expect(world.opened).toEqual([])
  })

  test('pane renders layout A rows', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, LAYOUT)
    await start($)

    expect(await drawn(await mount($))).toEqual([
      'Task board  ship-mods  ULTRA',
      'build  1/5 done  1 parked',
      'Run next',
      'Red-team',
      '#  card                     grp  stat',
      '01 Card 01                   A   [x]',
      '05 Card 05                   B   [>]',
      '06 Card 06                   C   [ ] <05',
      '07 Card 07                   B   [-]',
      '08 Card 08                   C   [!] <06',
    ])
  })

  test('pane truncates a title to the pane width, down to eight cells', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, ['| card | title | depends-on | agent | parallel group | status |', '| 01 | Render the live task-board pane with fill buttons | none | generic | A | pending |'].join('\n'))
    await start($)

    const pane = await mount($)

    expect(await lines(pane)).toContain('01 Render the live task-board…  A   [ ]')

    await pane.redraw({ ...PANE, bodyColumns: 10 })

    expect(await lines(pane)).toContain('01 Render …  A   [ ]')
  })

  test('pane caps a long dependency hint instead of narrowing every title', async ($, on) => {
    const world = seat(on)
    const waiting = ['11', '14', '15', '16', '22', '23'].map(id => row(id, 'pending'))

    world.put(RUN, RUN_HERE)
    world.put(INDEX, ['| card | title | depends-on | agent | parallel group | status |', ...waiting, row('24', 'pending', '11, 14, 15, 16, 22, 23')].join('\n'))
    await start($)

    const shown = await lines(await mount($))

    expect([shown[2], shown[3], shown.at(-1)]).toEqual([
      '#  card                   grp  stat',
      '11 Card 11                 A   [ ]',
      '24 Card 24                 A   [ ] <11+5',
    ])
  })

  test('pane puts a header row before each milestone and its cards', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, MILESTONES)
    await start($)

    expect((await lines(await mount($))).slice(2)).toEqual([
      '#  card                     grp  stat',
      'Milestone M1 — gates first',
      '01 Card 01                   A   [x]',
      '02 Card 02                   A   [ ]',
      'Milestone M2 — then the pane',
      '03 Card 03                   B   [ ] <02',
    ])
  })

  test('pane says a plain run has no card index, with no buttons', async ($, on) => {
    const world = seat(on)

    world.put(RUN, PLAIN_RUN)
    await start($)

    const pane = await mount($)

    expect(await lines(pane)).toEqual(['plain run — no card index'])
    expect(await buttons(pane)).toEqual([])
  })

  test('pane says an unreadable index is unreadable, with no buttons', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, '# Task index\n\nCards follow.\n')
    await start($)

    const pane = await mount($)

    expect(await lines(pane)).toEqual([`index unreadable: ${INDEX}`])
    expect(await buttons(pane)).toEqual([])
  })

  test('/task-board with no active run shows the newest index as not running from its first frame', async ($, on) => {
    let first: string[] = []
    const world = seat(on, { onOpen: async () => void (first = await lines(await mount($))) })

    world.disk.set(`${TASKS}/alpha/00-INDEX.md`, { text: BOARD, mtimeMs: NOW - 120_000 })
    world.disk.set(INDEX, { text: LAYOUT, mtimeMs: NOW - 10_000 })
    world.disk.set(`${TASKS}/zulu/00-INDEX.md`, { text: BOARD, mtimeMs: NOW - 60_000 })
    await start($)
    await $.command.run(TASK_BOARD)

    expect(first.slice(0, 2)).toEqual(['Task board  ship-mods  ULTRA  not running', '1/5 done  1 parked'])
    expect(world.statuses).toEqual([undefined, undefined])
  })

  test('/task-board keeps the newest index when a tool call refreshes while it opens', async ($, on) => {
    const world = seat(on)

    world.put(INDEX, LAYOUT)
    await start($)

    const read = world.holdNextRead(RUN)
    const opening = $.command.run(TASK_BOARD)

    await read.reached
    await $.tool.call({ tool: 'Bash', command: 'true' })
    read.release()
    await opening

    expect((await lines(await mount($)))[0]).toBe('Task board  ship-mods  ULTRA  not running')
  })

  test('/task-board with no active run and no tasks directory says none was found', async ($, on) => {
    const world = seat(on)

    await start($)
    await $.command.run(TASK_BOARD)

    const pane = await mount($)

    expect(world.opened).toEqual(['task-board'])
    expect(await lines(pane)).toEqual(['no card index found'])
    expect(await buttons(pane)).toEqual([])
  })

  test('a tool call keeps the newest index on the open pane with no run', async ($, on) => {
    const world = seat(on)

    world.put(INDEX, LAYOUT)
    await start($)
    await $.command.run(TASK_BOARD)
    await $.tool.call({ tool: 'Bash', command: 'true' })

    expect((await lines(await mount($)))[0]).toBe('Task board  ship-mods  ULTRA  not running')
  })

  test('pane passes the drawing through below CLI 2.1.291', async ($, on) => {
    seat(on, { version: '2.1.290' })

    on('ui.render', { component: 'Pane' }, ($, e) => $.ui.resolve(e).Text({ children: 'drawn by core' }))

    expect(await lines(await mount($))).toEqual(['drawn by core'])
  })

  test('pane redraws when the index changes', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE_ABSOLUTE)
    world.put(INDEX, LAYOUT)
    await start($)

    const pane = await mount($)

    await edit($, row('06', 'pending', '05', 'C'), row('06', 'done (9f1c2b3a)', '05', 'C'))

    expect((await lines(pane))[1]).toBe('build  2/5 done  1 parked')
  })

  test('pane buttons are plain Run next on r, focused first, and Red-team on t', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, LAYOUT)
    await start($)

    expect(await buttons(await mount($))).toEqual([
      { label: 'Run next', hotkey: 'r', plain: true, autoFocus: true },
      { label: 'Red-team', hotkey: 't', plain: true },
    ])
  })

  test('run next fills the prompt box', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, LAYOUT)
    await start($)
    await (await mount($)).press({ key: 'run-next' })

    expect(world.fills).toEqual([`/task-runner:run ${INDEX}`])
    expect(world.submits).toEqual([])
    expect(world.ran).toEqual([])
  })

  test('red-team fills the redteam command for the spec', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, LAYOUT)
    await start($)
    await (await mount($)).press({ key: 'red-team' })

    expect(world.fills).toEqual(['/taskmaster:redteam /work/taskmaster-docs/specs/ship-mods.md'])
    expect(world.submits).toEqual([])
    expect(world.ran).toEqual([])
  })

  test('red-team is hidden without taskmaster', async ($, on) => {
    const world = seat(on, { commands: ['task-runner:run'] })

    world.put(RUN, RUN_HERE)
    world.put(INDEX, LAYOUT)
    await start($)

    expect(await buttons(await mount($))).toEqual([{ label: 'Run next', hotkey: 'r', plain: true, autoFocus: true }])
  })

  test('red-team is hidden for an index that names no spec', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, MILESTONES)
    await start($)

    expect(await buttons(await mount($))).toEqual([{ label: 'Run next', hotkey: 'r', plain: true, autoFocus: true }])
  })

  test('/task-board toggles the pane', async ($, on) => {
    const world = seat(on)

    await start($)
    await $.command.run(TASK_BOARD)
    await $.command.run(TASK_BOARD)

    expect(world.registered).toEqual(['task-board'])
    expect(world.opened).toEqual(['task-board'])
    expect(world.closed).toEqual(['task-board'])
  })

  test('opens the pane once when a run starts and the terminal places it', async ($, on) => {
    const world = seat(on)

    world.put(INDEX, LAYOUT)
    await start($)
    await $.tool.call({ tool: 'Write', file_path: RUN, content: RUN_HERE })

    expect([...world.panes]).toEqual(['task-board'])

    world.panes.delete('task-board')
    await $.tool.call({ tool: 'Bash', command: 'true' })

    expect(world.opened).toEqual(['task-board'])
  })

  test('opens the pane when the refresh that saw the run start is superseded as it writes', async ($, on) => {
    const world = seat(on)

    world.put(INDEX, LAYOUT)
    await start($)

    const write = world.holdNextRunWrite()
    const started = $.tool.call({ tool: 'Write', file_path: RUN, content: RUN_HERE })

    await write.reached

    const read = world.holdNextRead(RUN)
    const next = $.tool.call({ tool: 'Bash', command: 'true' })

    await read.reached
    write.release()
    await started
    read.release()
    await next

    expect(world.opened).toEqual(['task-board'])
  })

  test('does not reopen a pane the person closed when the run briefly reads as inactive', async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, LAYOUT)
    await start($)
    world.panes.delete('task-board')
    await $.tool.call({ tool: 'Bash', command: 'rm .claude/task-runner/active-run.json' })
    await $.tool.call({ tool: 'Write', file_path: RUN, content: RUN_HERE })

    expect(world.opened).toEqual(['task-board'])
  })

  test('withdraws the pane a run start opened where the terminal cannot place it', async ($, on) => {
    const world = seat(on, { isNarrow: true })

    world.put(INDEX, LAYOUT)
    await start($)
    await $.tool.call({ tool: 'Write', file_path: RUN, content: RUN_HERE })

    expect(world.opened).toEqual(['task-board'])
    expect([...world.panes]).toEqual([])
  })

  test('keeps the pane closed under CC_TASK_BOARD=off', async ($, on) => {
    const world = seat(on, { env: { CC_TASK_BOARD: 'off' } })

    world.put(RUN, RUN_HERE)
    world.put(INDEX, LAYOUT)
    await start($)
    await $.command.run(TASK_BOARD)

    expect(world.registered).toEqual([])
    expect(world.opened).toEqual([])
  })

  // The kit raises no person's ui.close, so the reopen itself is recorded, not tested; this guards the switch it reads.
  test('the pin is off unless the option or CC_TASK_BOARD_PIN turns it on', () => {
    expect(isPinOn(undefined, undefined)).toBe(false)
    expect(isPinOn('', false)).toBe(false)
    expect(isPinOn(undefined, true)).toBe(true)
    expect(isPinOn('on', undefined)).toBe(true)
    expect(isPinOn('1', false)).toBe(true)
    expect(isPinOn('off', true)).toBe(false)
    expect(isPinOn('0', true)).toBe(false)
  })

  test('with the pin on, /task-board still closes the pane for good', { options: { cc_task_board_pin: true } }, async ($, on) => {
    const world = seat(on)

    world.put(RUN, RUN_HERE)
    world.put(INDEX, LAYOUT)
    await start($)
    await $.command.run(TASK_BOARD)
    await world.clock.advance(1_000)

    expect(world.opened).toEqual(['task-board'])
    expect(world.closed).toEqual(['task-board'])
    expect([...world.panes]).toEqual([])
  })

  test('/task-board places a pane waiting undrawn instead of closing it', async ($, on) => {
    const world = seat(on)

    await start($)
    world.panes.add('task-board')
    world.unplaced.add('task-board')
    await $.command.run(TASK_BOARD)

    expect(world.opened).toEqual(['task-board'])
    expect(world.closed).toEqual([])
  })
})
