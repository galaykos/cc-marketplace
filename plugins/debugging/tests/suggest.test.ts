import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

type Live = { version?: string; suggest?: string; sentinel?: string; failing?: readonly string[]; interrupted?: string; refused?: string }

function seat(on: On, live: Live = {}) {
  const world = { proposed: [] as string[], failing: new Set(live.failing ?? []) }

  mock.env(on, live.suggest === undefined ? {} : { CC_SUGGEST: live.suggest })
  on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  on('session.id', () => ({ value: 'S1' }))
  on('session.cwd', () => ({ value: '/work' }))

  on('process.run', ($, e) =>
    e.argv.join(' ') === 'git rev-parse --show-cdup'
      ? { value: { exitCode: 0, stdout: '\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
      : { deny: `unexpected command: ${e.argv.join(' ')}` },
  )

  on('fs.read', ($, e) => (e.path === '/work/.claude/cc-phase.json' && live.sentinel !== undefined ? { value: live.sentinel } : { deny: `ENOENT: ${e.path}` }))
  on('fs.stat', ($, e) => ({ deny: `ENOENT: ${e.path}` }))

  on('tool.call', ($, e) => {
    const command = 'command' in e ? String(e.command) : ''

    if (command === live.refused) {
      return { deny: 'refused' }
    }

    if (command === live.interrupted) {
      return { isError: true, result: { stdout: '', stderr: '', interrupted: true }, text: 'Interrupted' }
    }

    return world.failing.has(command.replace(/\s+/g, ' '))
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

const endTurn = ($: Engine) => $.turn.complete({ answer: 'done', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })

const DEBUG = (command: string) => `/debugging:debug \`${command}\` failed twice`

describe('suggest', () => {
  test('offers debugging once the same command has failed twice', async ($, on) => {
    const world = seat(on, { failing: ['npm run build'] })

    await bash($, 'npm run build')
    await endTurn($)

    expect(world.proposed, 'one failure is not a loop').toEqual([])

    await bash($, 'npm  run build')
    await endTurn($)

    expect(world.proposed, 'whitespace does not make it another command').toEqual([DEBUG('npm run build')])
  })

  test('a pass in between starts the count again', async ($, on) => {
    const world = seat(on, { failing: ['make'] })

    await bash($, 'make')
    world.failing.delete('make')
    await bash($, 'make')
    world.failing.add('make')
    await bash($, 'make')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('two different failing commands are not a loop', async ($, on) => {
    const world = seat(on, { failing: ['npm test', 'npm run lint'] })

    await bash($, 'npm test')
    await bash($, 'npm run lint')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('an interrupted or refused command does not count', async ($, on) => {
    const world = seat(on, { interrupted: 'sleep 100', refused: 'rm -rf build' })

    await bash($, 'sleep 100')
    await bash($, 'sleep 100')
    await bash($, 'rm -rf build')
    await bash($, 'rm -rf build')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('cuts a long command in the suggestion', async ($, on) => {
    const long = `node scripts/check.js ${'--flag '.repeat(20)}`.trim()
    const world = seat(on, { failing: [long] })

    await bash($, long)
    await bash($, long)
    await endTurn($)

    expect(world.proposed).toEqual([DEBUG(`${long.slice(0, 79)}…`)])
  })

  test('stays silent under CC_SUGGEST=off', async ($, on) => {
    const world = seat(on, { suggest: 'off', failing: ['make'] })

    await bash($, 'make')
    await bash($, 'make')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })

  test('stays silent below CLI 2.1.291', async ($, on) => {
    const world = seat(on, { version: '2.1.290', failing: ['make'] })

    await bash($, 'make')
    await bash($, 'make')
    await endTurn($)

    expect(world.proposed).toEqual([])
  })
})
