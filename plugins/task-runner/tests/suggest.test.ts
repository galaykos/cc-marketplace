import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const NOW = Date.UTC(2026, 9, 6, 12)
const INDEX = '/work/taskmaster-docs/tasks/ship-mods/00-INDEX.md'
const OLDER = '/work/taskmaster-docs/tasks/older/00-INDEX.md'
const RUN = '/work/.claude/task-runner/active-run.json'
const SENTINEL = '/work/.claude/cc-phase.json'
const GATE = '/work/.claude/task-runner/gate-pass.json'

const OPEN = ['| card | title | status |', '|---|---|---|', '| 01 | Kit | done (ad591b7e) |', '| 02 | Suggest | pending |', ''].join('\n')
const CLOSED = ['| card | title | status |', '|---|---|---|', '| 01 | Kit | Done (ad591b7e) |', '| 02 | Suggest | parked: needs a decision |', '| 03 | Docs | skipped', ''].join('\n')

const RUN_HERE = JSON.stringify({ slug: 'ship-mods', base: 'e04bbbc7', branch: 'feat/x' })
const RUN_ELSEWHERE = JSON.stringify({ slug: 'ship-mods', base: 'e04bbbc7', branch: 'master' })
const SHAPE = JSON.stringify({ phase: 'shape', owner: 'taskmaster:task', session_id: 'S1' })
const BUILD = JSON.stringify({ phase: 'build', owner: 'task-runner:run', session_id: 'S1' })

type Live = {
  version?: string
  env?: Record<string, string>
  shownAnswers?: readonly boolean[]
  failWrites?: 'deny' | 'error'
}

function seat(on: On, live: Live = {}) {
  const answers = [...(live.shownAnswers ?? [])]
  const world = { session: 'S1', disk: new Map<string, string>(), proposed: [] as string[] }

  mock.clock(on, { now: NOW })
  mock.env(on, live.env ?? {})

  on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  on('session.id', () => ({ value: world.session }))
  on('session.cwd', () => ({ value: '/work' }))

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
    const text = world.disk.get(e.path)

    return text === undefined
      ? { deny: `ENOENT: ${e.path}` }
      : { value: { kind: 'file', size: text.length, mtimeMs: NOW - 60_000, isLink: false } }
  })

  on('fs.read', ($, e) => {
    const text = world.disk.get(e.path)

    return text === undefined ? { deny: `ENOENT: ${e.path}` } : { value: text }
  })

  on('tool.call', ($, e) => {
    if (live.failWrites === 'deny') {
      return { deny: 'blocked by a PreToolUse hook' }
    }

    if (live.failWrites === 'error') {
      return { isError: true, result: 'File has not been read yet', text: 'File has not been read yet' }
    }

    if (e.tool === 'Write') {
      world.disk.set(e.file_path, e.content)
    }

    return { result: 'written' }
  })

  on('turn.complete', ($, e) => ({ text: e.answer }))

  on('prompt.suggest', ($, e) => {
    world.proposed.push(e.text)

    return { isShown: answers.shift() ?? true }
  })

  return world
}

const write = ($: Engine, path = INDEX, content = OPEN) => $.tool.call({ tool: 'Write', file_path: path, content })

const endTurn = ($: Engine) =>
  $.turn.complete({ answer: 'done', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })

describe('suggest', () => {
  test('offers run after an index write', async ($, on) => {
    const world = seat(on)

    await write($)

    expect(world.proposed, 'nothing while the turn runs').toEqual([])

    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`])
  })

  test('offers it once per index once shown', async ($, on) => {
    const world = seat(on)

    await write($)
    await endTurn($)
    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`])
  })

  test('offers it again after a not-shown answer', async ($, on) => {
    const world = seat(on, { shownAnswers: [false, true] })

    await write($)
    await endTurn($)
    await endTurn($)
    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`, `/task-runner:run ${INDEX}`])
  })

  test('stays silent for an index written while a run is active on this branch', async ($, on) => {
    const world = seat(on)

    world.disk.set(RUN, RUN_HERE)
    await write($)
    world.disk.delete(RUN)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('drops the index for good when Run now registers a run on this branch before the turn ends', async ($, on) => {
    const world = seat(on)

    world.disk.set(SENTINEL, SHAPE)
    await write($)
    world.disk.delete(SENTINEL)
    world.disk.set(RUN, RUN_HERE)
    await endTurn($)
    world.disk.delete(RUN)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('offers it after Stop here clears the sentinel live at the write', async ($, on) => {
    const world = seat(on)

    world.disk.set(SENTINEL, SHAPE)
    await write($)
    world.disk.delete(SENTINEL)
    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`])
  })

  test('stays silent while the sentinel stays live through the turn end, and offers it once cleared', async ($, on) => {
    const world = seat(on)

    world.disk.set(SENTINEL, SHAPE)
    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])

    world.disk.delete(SENTINEL)
    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`])
  })

  test('stays silent once the run Run now started has closed every card', async ($, on) => {
    const world = seat(on)

    world.disk.set(SENTINEL, SHAPE)
    await write($)
    world.disk.set(SENTINEL, BUILD)
    world.disk.set(RUN, RUN_HERE)
    await endTurn($)
    world.disk.set(INDEX, CLOSED)
    world.disk.delete(RUN)
    world.disk.delete(SENTINEL)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('offers it after a run ends with a card still open', async ($, on) => {
    const world = seat(on)

    world.disk.set(SENTINEL, SHAPE)
    await write($)
    world.disk.set(SENTINEL, BUILD)
    world.disk.set(RUN, RUN_HERE)
    await endTurn($)
    world.disk.delete(RUN)
    world.disk.delete(SENTINEL)
    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`])
  })

  test('stays silent for an index gate-pass.json names, relative or absolute', async ($, on) => {
    const world = seat(on)

    world.disk.set(GATE, JSON.stringify({ head: 'e04bbbc7', index_path: 'taskmaster-docs/tasks/ship-mods/00-INDEX.md' }))
    await write($)
    await endTurn($)
    world.disk.set(GATE, JSON.stringify({ head: 'e04bbbc7', index_path: OLDER }))
    await write($, OLDER)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('offers it when gate-pass.json names another index', async ($, on) => {
    const world = seat(on)

    world.disk.set(GATE, JSON.stringify({ head: 'e04bbbc7', index_path: 'taskmaster-docs/tasks/older/00-INDEX.md' }))
    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`])
  })

  test('offers an index with no card rows it can read', async ($, on) => {
    const world = seat(on)

    await write($, INDEX, '# Index\n\nCards follow.\n')
    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`])
  })

  test('drops an index waiting to be shown once every card is closed', async ($, on) => {
    const world = seat(on, { shownAnswers: [false, true] })

    await write($)
    await endTurn($)
    world.disk.set(INDEX, CLOSED)
    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`])
  })

  test('a closed index does not displace one still waiting to be shown', async ($, on) => {
    const world = seat(on, { shownAnswers: [false, true] })

    await write($)
    await endTurn($)
    await write($, OLDER, CLOSED)
    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`, `/task-runner:run ${INDEX}`])
  })

  test('offers it while the only active run is on another branch', async ($, on) => {
    const world = seat(on)

    world.disk.set(RUN, RUN_ELSEWHERE)
    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([`/task-runner:run ${INDEX}`])
  })

  test('forgets an index written in another session', async ($, on) => {
    const world = seat(on)

    await write($)
    world.session = 'S2'
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent under CC_SUGGEST=off', async ($, on) => {
    const world = seat(on, { env: { CC_SUGGEST: 'off' } })

    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent below CLI 2.1.291', async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('ignores a Write that is not a card index', async ($, on) => {
    const world = seat(on)

    await write($, '/work/taskmaster-docs/tasks/ship-mods/01-kit.md')
    await write($, '/work/taskmaster-docs/specs/00-INDEX.md')
    await write($, '/work/taskmaster-docs/tasks/ship-mods/old/00-INDEX.md')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('ignores an index in another checkout outside the state root', async ($, on) => {
    const world = seat(on)

    await write($, '/main/taskmaster-docs/tasks/ship-mods/00-INDEX.md')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('ignores an index under a fixture directory of the state root', async ($, on) => {
    const world = seat(on)

    await write($, '/work/plugins/taskmaster/tests/fixtures/taskmaster-docs/tasks/demo/00-INDEX.md')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('ignores an index Write that was denied', async ($, on) => {
    const world = seat(on, { failWrites: 'deny' })

    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('ignores an index Write that errored', async ($, on) => {
    const world = seat(on, { failWrites: 'error' })

    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })
})
