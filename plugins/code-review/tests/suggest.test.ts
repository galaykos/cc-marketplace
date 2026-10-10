import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const NOW = Date.UTC(2026, 9, 6, 12)
const MINUTE = 60_000
const REVIEW = '/code-review:review'

type Live = {
  version?: string
  suggest?: string
  cwd?: string
  cdup?: string
  refused?: string
  errored?: string
  shownAnswers?: readonly boolean[]
}

function ran(exitCode: number, stdout: string) {
  return { exitCode, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
}

function seat(on: On, live: Live = {}) {
  const answers = [...(live.shownAnswers ?? [])]
  const cwd = live.cwd ?? '/work'
  const world = {
    head: 'aaa111',
    branch: 'feat/x',
    disk: new Map<string, string>(),
    proposed: [] as string[],
  }

  mock.clock(on, { now: NOW })
  mock.env(on, live.suggest === undefined ? {} : { CC_SUGGEST: live.suggest })

  on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  on('session.id', () => ({ value: 'S1' }))
  on('session.cwd', () => ({ value: cwd }))

  on('process.run', ($, e) => {
    const answers: Record<string, string> = {
      'git rev-parse --show-cdup': live.cdup ?? '',
      'git rev-parse HEAD': world.head,
      'git rev-parse --abbrev-ref HEAD': world.branch,
    }

    const stdout = answers[e.argv.join(' ')]

    return stdout === undefined ? { deny: `unexpected command: ${e.argv.join(' ')}` } : { value: ran(0, `${stdout}\n`) }
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

  on('tool.call', ($, e) => {
    const path = 'file_path' in e ? e.file_path : ''

    if (path === live.refused) {
      return { deny: 'refused' }
    }

    if (path === live.errored) {
      return { isError: true, result: 'File has not been read yet', text: 'File has not been read yet' }
    }

    return { result: 'ok' }
  })

  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', ($, e) => ({ text: e.answer }))

  on('prompt.suggest', ($, e) => {
    world.proposed.push(e.text)

    return { isShown: answers.shift() ?? true }
  })

  return world
}

const runOn = (branch: string) =>
  JSON.stringify({ slug: 'ship', base: 'e04bbbc7', branch, index_path: 'taskmaster-docs/tasks/ship/00-INDEX.md' })

const edit = ($: Engine, file_path = '/work/src/app.ts') =>
  $.tool.call({ tool: 'Edit', file_path, old_string: 'a', new_string: 'b' })

const THREE = ['/work/src/app.ts', '/work/src/util.ts', '/work/src/api.ts']

async function editAll($: Engine, paths: readonly string[] = THREE) {
  for (const path of paths) {
    await edit($, path)
  }
}

const startTurn = ($: Engine, turnId: string) => $.turn.start({ text: 'go on', turnId })

const endTurn = ($: Engine) =>
  $.turn.complete({ answer: 'done', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })

describe('suggest', () => {
  test('offers review after a turn that edited three code files', async ($, on) => {
    const world = seat(on)

    await editAll($)
    await endTurn($)

    expect(world.proposed).toEqual([REVIEW])
  })

  test('stays silent after a turn that edited two code files, one of them twice', async ($, on) => {
    const world = seat(on)

    await editAll($, ['/work/src/app.ts', '/work/src/util.ts', '/work/src/app.ts'])
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('counts each turn afresh', async ($, on) => {
    const world = seat(on)

    await startTurn($, 't1')
    await editAll($, ['/work/src/app.ts', '/work/src/util.ts'])
    await endTurn($)
    await startTurn($, 't2')
    await edit($, '/work/src/api.ts')
    await endTurn($)

    expect(world.proposed, 'two files, then one').toEqual([])

    await startTurn($, 't3')
    await editAll($)
    await endTurn($)

    expect(world.proposed, 'three in one turn').toEqual([REVIEW])
  })

  test('counts a write, a multi-edit and a notebook edit of code', async ($, on) => {
    const world = seat(on)

    await $.tool.call({ tool: 'Write', file_path: '/work/src/new.ts', content: 'x' })
    await $.tool.call({ tool: 'MultiEdit', file_path: '/work/src/app.ts', edits: [{ old_string: 'a', new_string: 'b' }] })
    await $.tool.call({ tool: 'NotebookEdit', notebook_path: '/work/analysis.ipynb', new_source: 'x = 1' })
    await endTurn($)

    expect(world.proposed).toEqual([REVIEW])
  })

  test('stays silent after doc-only edits', async ($, on) => {
    const world = seat(on)

    await $.tool.call({ tool: 'Write', file_path: '/work/README.md', content: '# x' })
    await edit($, '/work/notes/CHANGES.RST')
    await edit($, '/work/site/page.mdx')
    await edit($, '/work/LICENSE.txt')
    await edit($, '/work/docs/example.ts')
    await edit($, '/work/packages/ui/docs/usage.ts')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('counts code in a repository that sits beneath a docs directory', async ($, on) => {
    const world = seat(on, { cwd: '/home/me/docs/app' })

    await editAll($, ['/home/me/docs/app/src/app.ts', '/home/me/docs/app/src/util.ts', '/home/me/docs/app/src/api.ts'])
    await endTurn($)

    expect(world.proposed).toEqual([REVIEW])
  })

  test('reads docs paths from the repository root when the cwd is a subdirectory', async ($, on) => {
    const world = seat(on, { cwd: '/home/me/docs/app/src', cdup: '../' })

    await editAll($, ['/home/me/docs/app/lib/util.ts', '/home/me/docs/app/lib/app.ts', '/home/me/docs/app/src/api.ts'])
    await endTurn($)

    expect(world.proposed).toEqual([REVIEW])
  })

  test('stays silent after an edit outside the repository', async ($, on) => {
    const world = seat(on)

    await edit($, '/tmp/scratch.py')
    await edit($, '/home/me/.claude/settings.json')
    await editAll($, ['/work/src/app.ts', '/work/src/util.ts'])
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent after a refused edit', async ($, on) => {
    const world = seat(on, { refused: '/work/src/app.ts' })

    await editAll($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent after an edit that errored', async ($, on) => {
    const world = seat(on, { errored: '/work/src/app.ts' })

    await editAll($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent for edits made during an active run on this branch, after the run ends', async ($, on) => {
    const world = seat(on)

    world.disk.set('/work/.claude/task-runner/active-run.json', runOn('feat/x'))
    await editAll($)
    world.disk.delete('/work/.claude/task-runner/active-run.json')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('drops the offer when a run starts on this branch before the turn ends', async ($, on) => {
    const world = seat(on)

    await editAll($)
    world.disk.set('/work/.claude/task-runner/active-run.json', runOn('feat/x'))
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('offers review when the registered run is on another branch', async ($, on) => {
    const world = seat(on)

    world.disk.set('/work/.claude/task-runner/active-run.json', runOn('master'))
    await editAll($)
    await endTurn($)

    expect(world.proposed).toEqual([REVIEW])
  })

  test('offers review once per HEAD once shown', async ($, on) => {
    const world = seat(on)

    await editAll($)
    await endTurn($)
    await editAll($)
    await endTurn($)

    expect(world.proposed, 'not re-offered on the same HEAD').toEqual([REVIEW])

    world.head = 'bbb222'
    await editAll($)
    await endTurn($)

    expect(world.proposed, 'offered again after HEAD moves').toEqual([REVIEW, REVIEW])
  })

  test('re-offers at the next turn end after a not-shown answer', async ($, on) => {
    const world = seat(on, { shownAnswers: [false, true] })

    await editAll($)
    await endTurn($)
    await endTurn($)
    await endTurn($)

    expect(world.proposed).toEqual([REVIEW, REVIEW])
  })

  test('stays silent under a live phase sentinel', async ($, on) => {
    const world = seat(on)

    world.disk.set('/work/.claude/cc-phase.json', JSON.stringify({ phase: 'build', session_id: 'S1' }))
    await editAll($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent under CC_SUGGEST=off', async ($, on) => {
    const world = seat(on, { suggest: 'off' })

    await editAll($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent below CLI 2.1.291', async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    await editAll($)
    await endTurn($)

    expect(world.proposed).toEqual([])
  })
})
