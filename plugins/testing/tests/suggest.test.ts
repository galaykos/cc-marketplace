import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

type Live = { version?: string; suggest?: string; failing?: readonly string[] }

function seat(on: On, live: Live = {}) {
  const world = { proposed: [] as string[], failing: new Set(live.failing ?? []), editFails: false }

  mock.env(on, live.suggest === undefined ? {} : { CC_SUGGEST: live.suggest })
  on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  on('session.id', () => ({ value: 'S1' }))
  on('session.cwd', () => ({ value: '/work' }))

  on('process.run', ($, e) =>
    e.argv.join(' ') === 'git rev-parse --show-cdup'
      ? { value: { exitCode: 0, stdout: '\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
      : { deny: `unexpected command: ${e.argv.join(' ')}` },
  )

  on('fs.read', ($, e) => ({ deny: `ENOENT: ${e.path}` }))
  on('fs.stat', ($, e) => ({ deny: `ENOENT: ${e.path}` }))

  on('tool.call', ($, e) => {
    if (e.tool !== 'Bash') {
      return world.editFails ? { isError: true, result: 'File has not been read yet', text: 'File has not been read yet' } : { result: 'ok' }
    }

    return world.failing.has(e.command)
      ? { isError: true, result: 'Exit code 1', text: 'Exit code 1' }
      : { result: { stdout: 'ok', stderr: '', interrupted: false } }
  })

  on('turn.complete', ($, e) => ({ text: e.answer }))

  on('prompt.suggest', ($, e) => {
    world.proposed.push(e.text)

    return { isShown: true }
  })

  return world
}

const bash = ($: Engine, command: string) => $.tool.call({ tool: 'Bash', command })

const edit = ($: Engine) => $.tool.call({ tool: 'Edit', file_path: '/work/src/a.ts', old_string: 'a', new_string: 'b' })

const endTurn = ($: Engine) => $.turn.complete({ answer: 'done', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })

const HUNT = '/testing:flake-hunt'

describe('suggest', () => {
  test('offers a flake hunt when one test command passes and fails with no edit between', async ($, on) => {
    const world = seat(on)

    await bash($, 'npm test')
    world.failing.add('npm test')
    await bash($, 'npm test')
    await endTurn($)

    expect(world.proposed).toEqual([HUNT])
  })

  test('a fail then a pass after an edit is a fix, not a flake', async ($, on) => {
    const world = seat(on, { failing: ['vendor/bin/pest'] })

    await bash($, 'vendor/bin/pest')
    await edit($)
    world.failing.clear()
    await bash($, 'vendor/bin/pest')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('an edit that errored is not a change', async ($, on) => {
    const world = seat(on, { failing: ['pytest -q'] })

    world.editFails = true
    await bash($, 'pytest -q')
    await edit($)
    world.failing.clear()
    await bash($, 'pytest -q')
    await endTurn($)

    expect(world.proposed).toEqual([HUNT])
  })

  test('only test runners count', async ($, on) => {
    const world = seat(on)

    await bash($, 'npm run build')
    world.failing.add('npm run build')
    await bash($, 'npm run build')
    await bash($, 'cat test/fixtures/a.json')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('recognises the runners the hunt resolves to', async ($, on) => {
    const world = seat(on)
    const runners = ['pnpm test', 'yarn run test', 'npx vitest run', 'php artisan test', 'go test ./...', 'cargo test', './node_modules/.bin/jest', 'npx playwright test']

    for (const runner of runners) {
      world.failing.delete(runner)
      await bash($, runner)
      world.failing.add(runner)
      await bash($, runner)
      await endTurn($)
    }

    expect(world.proposed).toEqual(runners.map(() => HUNT))
  })

  test('stays silent under CC_SUGGEST=off', async ($, on) => {
    const world = seat(on, { suggest: 'off' })

    await bash($, 'npm test')
    world.failing.add('npm test')
    await bash($, 'npm test')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })
})
