import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import { MODS_FLOOR } from '../hooks/cc-kit'

const NOW = Date.UTC(2026, 9, 6, 12)
const MINUTE = 60_000
const HEAD = '1f0c6b2e9d4a7c3b5e8f0a1d2c3b4a5f6e7d8c9b'
const NEXT_HEAD = '9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c'
const PREV_HEAD = '0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b'
const GATE = '/work/.claude/task-runner/gate-pass.json'
const SENTINEL = '/work/.claude/cc-phase.json'
const FINISH = '/git-workflow:finish'
const INDEX = 'taskmaster-docs/tasks/ship-mods/00-INDEX.md'

function ran(exitCode: number, stdout: string) {
  return { exitCode, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
}

const gatePass = (head: string, counts?: { total: number; done: number; parked: number }) =>
  JSON.stringify({
    head,
    ...(counts && {
      index_path: INDEX,
      cards_total: counts.total,
      cards_done: counts.done,
      cards_parked: counts.parked,
    }),
  })

type Live = {
  version?: string
  shownAnswers?: readonly boolean[]
}

function seat(on: On, live: Live = {}) {
  const shownAnswers = [...(live.shownAnswers ?? [])]
  const world = {
    head: HEAD,
    branch: 'feat/x',
    originHead: 'origin/master' as string | undefined,
    upstream: undefined as string | undefined,
    suggest: undefined as string | undefined,
    disk: new Map<string, string>(),
    proposed: [] as string[],
    spawns: [] as string[],
  }

  mock.clock(on, { now: NOW })

  on('env.get', ($, e) => ({ value: e.name === 'CC_SUGGEST' ? world.suggest : undefined }))
  on('session.version', () => ({ value: { version: live.version ?? MODS_FLOOR } }))
  on('session.id', () => ({ value: 'S1' }))
  on('session.cwd', () => ({ value: '/work' }))

  on('process.run', ($, e) => {
    const git: Record<string, string | undefined> = {
      'git rev-parse --show-cdup': '',
      'git rev-parse HEAD': world.head,
      'git rev-parse --abbrev-ref HEAD': world.branch,
      'git symbolic-ref --short refs/remotes/origin/HEAD': world.originHead,
      'git rev-parse @{u}': world.upstream,
    }

    const command = e.argv.join(' ')

    world.spawns.push(command)

    if (!(command in git)) {
      return { deny: `unexpected command: ${command}` }
    }

    const stdout = git[command]

    return { value: stdout === undefined ? ran(128, '') : ran(0, `${stdout}\n`) }
  })

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

  on('turn.complete', ($, e) => ({ text: e.answer }))

  on('prompt.suggest', ($, e) => {
    world.proposed.push(e.text)

    return { isShown: shownAnswers.shift() ?? true }
  })

  return world
}

const endTurn = ($: Engine) =>
  $.turn.complete({ answer: 'done', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })

describe('suggest', () => {
  test('offers finish after a green run', async ($, on) => {
    const world = seat(on)

    world.disk.set(GATE, gatePass(HEAD, { total: 5, done: 5, parked: 0 }))
    await endTurn($)

    expect(world.proposed).toEqual([FINISH])
  })

  test('counts parked cards as closed', async ($, on) => {
    const world = seat(on)

    world.disk.set(GATE, gatePass(HEAD, { total: 5, done: 3, parked: 2 }))
    await endTurn($)

    expect(world.proposed).toEqual([FINISH])
  })

  test('stays silent unless done plus parked equals the total', async ($, on) => {
    const world = seat(on)

    for (const counts of [{ total: 5, done: 3, parked: 1 }, { total: 5, done: 4, parked: 2 }]) {
      world.disk.set(GATE, gatePass(HEAD, counts))
      await endTurn($)
    }

    expect(world.proposed).toEqual([])
  })

  test('stays silent on partial card counts', async ($, on) => {
    const world = seat(on)

    for (const count of ['cards_total', 'cards_done', 'cards_parked']) {
      world.disk.set(GATE, JSON.stringify({ head: HEAD, [count]: 5 }))
      await endTurn($)
    }

    expect(world.proposed).toEqual([])
  })

  test('offers finish after a plain run', async ($, on) => {
    const world = seat(on)

    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)

    expect(world.proposed).toEqual([FINISH])
  })

  test('stays silent when the gate passed at another head', async ($, on) => {
    const world = seat(on)

    world.disk.set(GATE, gatePass(NEXT_HEAD))
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent on the default branch origin/HEAD names', async ($, on) => {
    const world = seat(on)

    world.originHead = 'origin/develop'
    world.branch = 'develop'
    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('offers finish on master when origin/HEAD names another branch', async ($, on) => {
    const world = seat(on)

    world.originHead = 'origin/develop'
    world.branch = 'master'
    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)

    expect(world.proposed).toEqual([FINISH])
  })

  test('falls back to main and master when origin/HEAD is unset', async ($, on) => {
    const world = seat(on)

    world.originHead = undefined
    world.disk.set(GATE, gatePass(HEAD))

    for (const branch of ['main', 'master']) {
      world.branch = branch
      await endTurn($)
    }

    expect(world.proposed, 'main and master are the default').toEqual([])

    world.branch = 'feat/x'
    await endTurn($)

    expect(world.proposed, 'any other branch is offered').toEqual([FINISH])
  })

  test('stays silent on a detached HEAD', async ($, on) => {
    const world = seat(on)

    world.branch = 'HEAD'
    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent once the upstream is at the gate head', async ($, on) => {
    const world = seat(on)

    world.upstream = HEAD
    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('offers finish while the upstream is behind the gate head', async ($, on) => {
    const world = seat(on)

    world.upstream = PREV_HEAD
    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)

    expect(world.proposed).toEqual([FINISH])
  })

  test('stays silent without a gate pass', async ($, on) => {
    const world = seat(on)

    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('offers finish once per gate head', async ($, on) => {
    const world = seat(on)

    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)
    await endTurn($)

    expect(world.proposed, 'recorded once shown').toEqual([FINISH])

    world.head = NEXT_HEAD
    world.disk.set(GATE, gatePass(NEXT_HEAD))
    await endTurn($)

    expect(world.proposed, 'a new gate head is offered').toEqual([FINISH, FINISH])
  })

  test('offers finish again after a not-shown answer', async ($, on) => {
    const world = seat(on, { shownAnswers: [false, true] })

    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)
    await endTurn($)
    await endTurn($)

    expect(world.proposed).toEqual([FINISH, FINISH])
  })

  test('drops a not-shown offer once HEAD moves past the gate', async ($, on) => {
    const world = seat(on, { shownAnswers: [false] })

    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)
    world.head = NEXT_HEAD
    await endTurn($)

    expect(world.proposed).toEqual([FINISH])
  })

  test('stays silent under a live phase sentinel', async ($, on) => {
    const world = seat(on)

    world.disk.set(GATE, gatePass(HEAD))
    world.disk.set(SENTINEL, JSON.stringify({ phase: 'build', owner: 'task-runner:run', session_id: 'S1' }))
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent under CC_SUGGEST=off', async ($, on) => {
    const world = seat(on)

    world.suggest = 'off'
    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent below the CLI floor', async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('runs git rev-parse HEAD once at a turn end that offers finish', async ($, on) => {
    const world = seat(on)

    world.disk.set(GATE, gatePass(HEAD))
    await endTurn($)

    expect(world.proposed).toEqual([FINISH])
    expect(world.spawns.filter(command => command === 'git rev-parse HEAD')).toHaveLength(1)
  })
})
