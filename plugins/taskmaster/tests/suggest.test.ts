import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const NOW = Date.UTC(2026, 9, 6, 12)
const MINUTE = 60_000
const SPEC = '/work/taskmaster-docs/specs/2026-10-06-orders.md'
const SENTINEL = '/work/.claude/cc-phase.json'
const LIVE_BUILD = JSON.stringify({ phase: 'build', owner: 'task-runner:run', session_id: 'S1' })

type Live = {
  cwd?: string
  suggest?: string
  shownAnswers?: readonly boolean[]
  refused?: string
  errored?: string
}

function ran(exitCode: number, stdout: string) {
  return { exitCode, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
}

function seat(on: On, live: Live = {}) {
  const answers = [...(live.shownAnswers ?? [])]
  const cwd = live.cwd ?? '/work'
  const world = { disk: new Map<string, string>(), proposed: [] as string[] }

  mock.clock(on, { now: NOW })
  mock.env(on, live.suggest === undefined ? {} : { CC_SUGGEST: live.suggest })

  on('session.version', () => ({ value: { version: '2.1.291' } }))
  on('session.id', () => ({ value: 'S1' }))
  on('session.cwd', () => ({ value: cwd }))

  on('process.run', ($, e) =>
    e.argv.join(' ') === 'git rev-parse --show-cdup'
      ? { value: ran(0, `${'../'.repeat(cwd.split('/').length - 2)}\n`) }
      : { deny: `unexpected command: ${e.argv.join(' ')}` },
  )

  on('fs.stat', ($, e) => {
    const text = world.disk.get(e.path)

    return text === undefined
      ? { deny: `ENOENT: ${e.path}` }
      : { value: { kind: 'file', size: text.length, mtimeMs: NOW - MINUTE, isLink: false } }
  })

  on('fs.read', ($, e) => {
    const text = world.disk.get(e.path)

    return text === undefined ? { deny: `ENOENT: ${e.path}` } : { value: text }
  })

  on('tool.call', ($, e) => {
    if (e.tool === 'Write' && e.file_path === live.refused) {
      return { deny: 'refused' }
    }

    if (e.tool === 'Write' && e.file_path === live.errored) {
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

const write = ($: Engine, path = SPEC, agentId?: string) =>
  $.tool.call({
    tool: 'Write',
    file_path: path,
    content: '# spec',
    ...(agentId !== undefined && { agentId }),
  })

const endTurn = ($: Engine) =>
  $.turn.complete({ answer: 'done', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })

describe('suggest', () => {
  test('offers redteam after a spec write', async ($, on) => {
    const world = seat(on)

    await write($)

    expect(world.proposed, 'nothing while the turn runs').toEqual([])

    await endTurn($)

    expect(world.proposed).toEqual([`/taskmaster:redteam ${SPEC}`])
  })

  test('offers redteam for a spec under the state root when the cwd is below it', async ($, on) => {
    const world = seat(on, { cwd: '/work/app' })

    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([`/taskmaster:redteam ${SPEC}`])
  })

  test("offers redteam for a sub-package's own spec", async ($, on) => {
    const world = seat(on, { cwd: '/work/app' })

    await write($, '/work/app/taskmaster-docs/specs/2026-10-06-orders.md')
    await endTurn($)

    expect(world.proposed).toEqual(['/taskmaster:redteam /work/app/taskmaster-docs/specs/2026-10-06-orders.md'])
  })

  test('offers the spec again next turn when the suggestion was not shown', async ($, on) => {
    const world = seat(on, { shownAnswers: [false, true] })

    await write($)
    await endTurn($)
    await endTurn($)
    await endTurn($)

    expect(world.proposed).toEqual([`/taskmaster:redteam ${SPEC}`, `/taskmaster:redteam ${SPEC}`])
  })

  test('does not offer a shown spec again after it is rewritten', async ($, on) => {
    const world = seat(on)

    await write($)
    await endTurn($)
    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([`/taskmaster:redteam ${SPEC}`])
  })

  test('stays silent while a phase sentinel is live', async ($, on) => {
    const world = seat(on)

    world.disk.set(SENTINEL, LIVE_BUILD)
    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent under CC_SUGGEST=off', async ($, on) => {
    const world = seat(on, { suggest: 'off' })

    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test("ignores a subagent's spec write", async ($, on) => {
    const world = seat(on)

    await write($, SPEC, 'a-explorer')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('ignores a write that is not a spec under the state root', async ($, on) => {
    const world = seat(on)

    for (const path of [
      '/work/README.md',
      '/work/taskmaster-docs/specs/notes.txt',
      '/work/taskmaster-docs/specs/old/2026-01-01-x.md',
      '/work/taskmaster-docs/specs/2026-10-06-orders-design.md',
      '/elsewhere/taskmaster-docs/specs/2026-10-06-orders.md',
    ]) {
      await write($, path)
      await endTurn($)
    }

    expect(world.proposed).toEqual([])
  })

  test('ignores a refused spec write', async ($, on) => {
    const world = seat(on, { refused: SPEC })

    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('ignores a spec write that errored', async ($, on) => {
    const world = seat(on, { errored: SPEC })

    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })
})
