import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import {
  activeRun,
  isSupported,
  liveSentinel,
  MODS_FLOOR,
  stateRoot,
  switchOn,
} from '../hooks/cc-kit'
import type { Host } from '../hooks/cc-kit'

const NOW = Date.UTC(2026, 9, 6, 12)
const MINUTE = 60_000
const SENTINEL = '/work/.claude/cc-phase.json'
const RUN = '/work/.claude/task-runner/active-run.json'
const A_MD = '/work/a.md'

const LIVE_BUILD = JSON.stringify({ phase: 'build', owner: 'task-runner:run', session_id: 'S1' })

type Repo = { toplevel: string; branch: string; real?: string }

type World = {
  cwd?: string
  projectDir?: string
  repos?: readonly Repo[]
  files?: Readonly<Record<string, { text: string; mtimeMs: number }>>
}

function ran(exitCode: number, stdout: string) {
  return { exitCode, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
}

function hostIn(world: World): Host {
  const cwd = world.cwd ?? '/work'

  const fileAt = async (path: string) => {
    const file = world.files?.[path]

    if (!file) {
      throw new Error(`ENOENT: ${path}`)
    }

    return file
  }

  return {
    run: async (argv, init) => {
      const dir = init?.cwd ?? cwd

      const repo = [...(world.repos ?? [])]
        .filter(r => dir === r.toplevel || dir.startsWith(`${r.toplevel}/`))
        .sort((a, b) => b.toplevel.length - a.toplevel.length)[0]

      const depth = repo ? dir.slice(repo.toplevel.length).split('/').filter(Boolean).length : 0

      const answers: Record<string, string | undefined> = {
        'git rev-parse --show-cdup': repo && '../'.repeat(depth),
        'git rev-parse --show-toplevel': repo && (repo.real ?? repo.toplevel),
        'git rev-parse --abbrev-ref HEAD': repo?.branch,
      }

      const command = argv.join(' ')

      if (!(command in answers)) {
        throw new Error(`unexpected command: ${command}`)
      }

      const stdout = answers[command]

      return stdout === undefined ? ran(128, '') : ran(0, `${stdout}\n`)
    },
    read: async path => (await fileAt(path)).text,
    stat: async path => ({ kind: 'file', size: 0, mtimeMs: (await fileAt(path)).mtimeMs, isLink: false }),
    now: async () => NOW,
    sessionId: async () => 'S1',
    cwd: async () => cwd,
    projectDir: async () => world.projectDir,
  }
}

const REPO = [{ toplevel: '/work', branch: 'feat/x' }]

const sentinelAt = (body: Record<string, string>, ageMinutes = 1, root = '/work') => ({
  [`${root}/.claude/cc-phase.json`]: { text: JSON.stringify(body), mtimeMs: NOW - ageMinutes * MINUTE },
})

const RUN_FILE = {
  [RUN]: {
    text: JSON.stringify({
      slug: 'ship-mods',
      base: 'e04bbbc7',
      branch: 'feat/x',
      index_path: 'taskmaster-docs/tasks/ship-mods/00-INDEX.md',
    }),
    mtimeMs: NOW,
  },
}

type Live = {
  version?: string
  suggest?: string
  shownAnswers?: readonly boolean[]
}

function seat(on: On, live: Live = {}) {
  const answers = [...(live.shownAnswers ?? [])]
  const world = {
    session: 'S1',
    suggest: live.suggest,
    disk: new Map<string, string>(),
    proposed: [] as string[],
    io: [] as string[],
    envReads: [] as string[],
    board: [] as string[],
  }

  mock.clock(on, { now: NOW })

  on('env.get', ($, e) => {
    world.envReads.push(e.name)

    return { value: e.name === 'CC_SUGGEST' ? world.suggest : undefined }
  })

  on('store.set', ($, e) => {
    world.board.push(String(e.value))

    return { value: undefined }
  })

  on('session.version', () => ({ value: { version: live.version ?? MODS_FLOOR } }))
  on('session.id', () => ({ value: world.session }))
  on('session.cwd', () => ({ value: '/work' }))

  on('process.run', ($, e) => {
    world.io.push(e.argv.join(' '))

    return e.argv.join(' ') === 'git rev-parse --show-cdup'
      ? { value: ran(0, '\n') }
      : { deny: `unexpected command: ${e.argv.join(' ')}` }
  })

  on('fs.stat', ($, e) => {
    world.io.push(`stat ${e.path}`)

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

const write = ($: Engine, path = A_MD, agentId?: string) =>
  $.tool.call({
    tool: 'Write',
    file_path: path,
    content: 'x',
    ...(agentId !== undefined && { agentId }),
  })

const endTurn = ($: Engine) =>
  $.turn.complete({ answer: 'done', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })

describe('cc-kit', () => {
  test('isSupported is false below the floor', () => {
    expect(isSupported('2.1.290')).toBe(false)
  })

  test('isSupported is true at the floor', () => {
    expect(isSupported(MODS_FLOOR)).toBe(true)
  })

  test('isSupported compares numeric parts above the floor', () => {
    expect(isSupported('2.1.1000')).toBe(true)
    expect(isSupported('10.0.0')).toBe(true)
  })

  test('isSupported is false for an unparseable version', () => {
    expect(isSupported('dev')).toBe(false)
    expect(isSupported('')).toBe(false)
  })

  test('switchOn reads off, 0 and false in any case as off', () => {
    for (const value of ['off', 'OFF', '0', 'false', 'False']) {
      expect(switchOn(value, true), value).toBe(false)
    }
  })

  test('switchOn reads any other non-empty value as on', () => {
    for (const value of ['on', '1', 'yes']) {
      expect(switchOn(value, false), value).toBe(true)
    }
  })

  test('switchOn falls back to the option when unset or empty, else on', () => {
    expect(switchOn(undefined, true)).toBe(true)
    expect(switchOn(undefined, false)).toBe(false)
    expect(switchOn('', false)).toBe(false)
    expect(switchOn(undefined)).toBe(true)
  })

  test('stateRoot is the git toplevel above the cwd', async () => {
    const host = hostIn({ cwd: '/work/app/Models', repos: REPO, projectDir: '/elsewhere' })

    expect(await stateRoot(host)).toBe('/work')
  })

  test('stateRoot inside a git worktree is the worktree toplevel', async () => {
    const host = hostIn({
      cwd: '/work/.claude/worktrees/feat/src',
      projectDir: '/work',
      repos: [...REPO, { toplevel: '/work/.claude/worktrees/feat', branch: 'feat' }],
    })

    expect(await stateRoot(host)).toBe('/work/.claude/worktrees/feat')
  })

  test('stateRoot keeps the symlinked spelling git --show-toplevel would resolve', async () => {
    const host = hostIn({
      cwd: '/link/r/sub',
      repos: [{ toplevel: '/link/r', real: '/real/r', branch: 'main' }],
    })

    expect(await stateRoot(host)).toBe('/link/r')
  })

  test('stateRoot outside git falls back to CLAUDE_PROJECT_DIR when the cwd is under it', async () => {
    expect(await stateRoot(hostIn({ cwd: '/proj/sub', projectDir: '/proj/' }))).toBe('/proj')
  })

  test('stateRoot outside git and the project dir falls back to the cwd', async () => {
    expect(await stateRoot(hostIn({ cwd: '/project-two/x', projectDir: '/proj' }))).toBe('/project-two/x')
  })

  test('liveSentinel reads an unexpired sentinel of this session', async () => {
    const files = sentinelAt({ phase: 'build', owner: 'task-runner:run', session_id: 'S1' }, 119)

    expect(await liveSentinel(hostIn({ repos: REPO, files }))).toEqual({ phase: 'build' })
  })

  test('liveSentinel reads the sentinel under a root it is given', async () => {
    const files = sentinelAt({ phase: 'plan', session_id: 'S1' }, 1, '/elsewhere')

    expect(await liveSentinel(hostIn({ repos: REPO, files }), '/elsewhere')).toEqual({ phase: 'plan' })
  })

  test('liveSentinel ignores a sentinel past the 120-minute TTL', async () => {
    const files = sentinelAt({ phase: 'build', owner: 'task-runner:run', session_id: 'S1' }, 121)

    expect(await liveSentinel(hostIn({ repos: REPO, files }))).toBe(null)
  })

  test("liveSentinel ignores another session's sentinel, counts one naming none", async () => {
    const other = sentinelAt({ phase: 'build', owner: 'task-runner:run', session_id: 'S2' })
    const blind = sentinelAt({ phase: 'ship', owner: 'git-workflow:finish' })

    expect(await liveSentinel(hostIn({ repos: REPO, files: other }))).toBe(null)
    expect(await liveSentinel(hostIn({ repos: REPO, files: blind }))).toEqual({ phase: 'ship' })
  })

  test('liveSentinel reads a malformed sentinel as none', async () => {
    const files = { [SENTINEL]: { text: '{"phase":', mtimeMs: NOW - MINUTE } }

    expect(await liveSentinel(hostIn({ repos: REPO, files }))).toBe(null)
  })

  test('activeRun returns the run registered on the current branch, with its root', async () => {
    expect(await activeRun(hostIn({ repos: REPO, files: RUN_FILE }))).toEqual({
      slug: 'ship-mods',
      branch: 'feat/x',
      index_path: 'taskmaster-docs/tasks/ship-mods/00-INDEX.md',
      root: '/work',
    })
  })

  test('activeRun ignores a run on another branch', async () => {
    const repos = [{ toplevel: '/work', branch: 'master' }]

    expect(await activeRun(hostIn({ repos, files: RUN_FILE }))).toBe(null)
  })

  test('activeRun is null without a run file', async () => {
    expect(await activeRun(hostIn({ repos: REPO }))).toBe(null)
  })

  test('registerSuggestion shows a suggestion after the turn ends', async ($, on) => {
    const world = seat(on)

    await write($)

    expect(world.proposed, 'nothing while the turn runs').toEqual([])

    await endTurn($)

    expect(world.proposed).toEqual(['/probe /work/a.md'])

    await write($)
    await endTurn($)

    expect(world.proposed, 'recorded once shown').toEqual(['/probe /work/a.md'])
  })

  test('registerSuggestion re-proposes after a not-shown answer', async ($, on) => {
    const world = seat(on, { shownAnswers: [false, true] })

    await write($)
    await endTurn($)
    await endTurn($)
    await endTurn($)

    expect(world.proposed).toEqual(['/probe /work/a.md', '/probe /work/a.md'])
  })

  test('registerSuggestion is silent under a live sentinel, and after it lifts', async ($, on) => {
    const world = seat(on)

    world.disk.set(SENTINEL, LIVE_BUILD)
    await write($)
    await endTurn($)
    world.disk.delete(SENTINEL)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('registerSuggestion drops a key when a sentinel is live at delivery', async ($, on) => {
    const world = seat(on)

    await write($)
    world.disk.set(SENTINEL, LIVE_BUILD)
    await endTurn($)
    world.disk.delete(SENTINEL)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('registerSuggestion arms nothing while a sentinel is live', async ($, on) => {
    const world = seat(on)

    world.disk.set(SENTINEL, LIVE_BUILD)
    await write($)
    world.disk.delete(SENTINEL)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('registerSuggestion arms nothing while CC_SUGGEST is off', async ($, on) => {
    const world = seat(on, { suggest: 'off' })

    await write($)
    world.suggest = undefined
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('registerSuggestion is silent under CC_SUGGEST=off', async ($, on) => {
    const world = seat(on, { suggest: 'off' })

    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('registerSuggestion ignores subagent tool calls', async ($, on) => {
    const world = seat(on)

    await write($, A_MD, 'a-explorer')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('registerSuggestion is silent below the floor', async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    await write($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('registerSuggestion proposes only the most recent key of a turn', async ($, on) => {
    const world = seat(on)

    await write($, '/work/a.md')
    await write($, '/work/b.md')
    await endTurn($)
    await endTurn($)

    expect(world.proposed).toEqual(['/probe /work/b.md'])
  })

  test('registerSuggestion forgets keys armed in another session', async ($, on) => {
    const world = seat(on)

    await write($)
    world.session = 'S2'
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('registerSuggestion drops a key no longer due at delivery', async ($, on) => {
    const world = seat(on)

    await write($)
    world.disk.delete(A_MD)
    await endTurn($)
    world.disk.set(A_MD, 'x')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('registerSuggestion proposes the key atTurnEnd returns', { options: { probe_turn_end: true } }, async ($, on) => {
    const world = seat(on)

    world.disk.set('/work/PROBE.md', 'x')
    await endTurn($)

    expect(world.proposed).toEqual(['/probe /work/PROBE.md'])
  })

  test('registerSuggestion runs no git or stat for a tool call that arms nothing', async ($, on) => {
    const world = seat(on)

    await write($, '/work/a.ts')

    expect(world.io).toEqual([])
  })

  test('registerSuggestion runs no git or stat at a turn end with nothing armed and no atTurnEnd', async ($, on) => {
    const world = seat(on)

    await endTurn($)

    expect(world.io).toEqual([])
  })

  test('registerSuggestion never passes a non-Write tool call to onToolCall', async ($, on) => {
    const world = seat(on)

    world.disk.set('/work/r.md', 'x')
    await $.tool.call({ tool: 'Read', file_path: '/work/r.md' })
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test("registerSuggestion coexists with the module's own unmatched tool.call hook", { options: { probe_board: true } }, async ($, on) => {
    const world = seat(on)

    await write($)
    await $.tool.call({ tool: 'Read', file_path: A_MD })
    await endTurn($)

    expect(world.board, 'the own hook saw every call').toEqual(['Write', 'Read'])
    expect(world.proposed, 'the matched hook armed the Write').toEqual(['/probe /work/a.md'])
  })

  test('registerSuggestion without onToolCall registers no tool.call hook', { options: { probe_board: true, probe_tool_key: false, probe_turn_end: true } }, async ($, on) => {
    const world = seat(on)

    await write($)

    expect(world.board, 'the module loaded beside its own hook').toEqual(['Write'])
    expect(world.envReads, 'no suggestion hook ran on the call').toEqual([])

    world.disk.set('/work/PROBE.md', 'x')
    await endTurn($)

    expect(world.proposed).toEqual(['/probe /work/PROBE.md'])
  })
})
