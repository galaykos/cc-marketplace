import type { On } from 'claude-code'
import { describe, expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const PROGRAM = '/work/.claude/overseer/program.json'

type Milestone = { id: string; title: string; status: string; depends?: string[] }

type Live = {
  version?: string
  env?: Record<string, string>
}

const m = (id: string, title: string, status: string, depends: string[] = []): Milestone => ({
  id,
  title,
  status,
  depends,
})

const IN_FLIGHT = [
  m('m1', 'Walking skeleton', 'done'),
  m('m2', 'Client list', 'accepting', ['m1']),
  m('m3', 'Import', 'queued'),
]

const IN_FLIGHT_LINE = 'overseer  milestone 2/3  m2 Client list (accepting)'

// The session runs in a subdirectory, so the line is found only through the git toplevel.
function seat(on: On, live: Live = {}) {
  const world = {
    env: { ...live.env } as Record<string, string>,
    disk: new Map<string, { text: string; mtimeMs: number }>(),
    lines: [] as (string | undefined)[],
    io: [] as string[],
    mtimeMs: 0,
    failedReads: 0,
    gate: undefined as { enter: () => void; released: Promise<void> } | undefined,
    write(text: string) {
      this.mtimeMs += 1000
      this.disk.set(PROGRAM, { text, mtimeMs: this.mtimeMs })
    },
    save(milestones: Milestone[]) {
      this.write(JSON.stringify({ goal: 'Build a CRM', milestones }))
    },
    // The next read waits at the gate until released: how a test makes two refreshes overlap.
    holdNextRead() {
      let enter = () => {}
      let release = () => {}
      const reached = new Promise<void>(resolve => {
        enter = resolve
      })
      const released = new Promise<void>(resolve => {
        release = resolve
      })

      this.gate = { enter, released }

      return { reached, release }
    },
    get line() {
      return this.lines.at(-1)
    },
  }

  on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  on('session.cwd', () => ({ value: '/work/app' }))
  on('env.get', ($, e) => ({ value: world.env[e.name] }))

  on('process.run', ($, e) => {
    world.io.push(e.argv.join(' '))

    return e.argv.join(' ') === 'git rev-parse --show-cdup'
      ? { value: { exitCode: 0, stdout: '../\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
      : { deny: `unexpected command: ${e.argv.join(' ')}` }
  })

  on('fs.stat', ($, e) => {
    world.io.push(`stat ${e.path}`)

    const file = world.disk.get(e.path)

    return file
      ? { value: { kind: 'file', size: file.text.length, mtimeMs: file.mtimeMs, isLink: false } }
      : { deny: `ENOENT: ${e.path}` }
  })

  on('fs.read', async ($, e) => {
    world.io.push(`read ${e.path}`)

    const gate = world.gate

    if (gate) {
      world.gate = undefined
      gate.enter()
      await gate.released
    }

    if (world.failedReads > 0) {
      world.failedReads -= 1

      return { deny: `EIO: ${e.path}` }
    }

    const file = world.disk.get(e.path)

    return file ? { value: file.text } : { deny: `ENOENT: ${e.path}` }
  })

  on('ui.status', ($, e) => {
    world.lines.push(e.text)

    return { value: undefined }
  })

  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('tool.call', () => ({ result: 'ok' }))

  return world
}

const start = ($: Engine) => $.session.start({ cwd: '/work/app', surface: 'terminal', isInteractive: true })

const runTool = ($: Engine) => $.tool.call({ tool: 'Bash', command: 'program.sh milestone set --id m1' })

describe('status-line', () => {
  test('shows the next open milestone', async ($, on) => {
    const world = seat(on)

    world.save(IN_FLIGHT)
    await start($)

    expect(world.line).toBe(IN_FLIGHT_LINE)
  })

  test('clears when every milestone is done, parked or waiting on a parked one', async ($, on) => {
    const world = seat(on)

    world.save(IN_FLIGHT)
    await start($)
    expect(world.line, 'shown before the program closes').toBe(IN_FLIGHT_LINE)

    world.save([m('m1', 'Walking skeleton', 'done'), m('m2', 'Client list', 'parked'), m('m3', 'Import', 'queued', ['m2'])])
    await runTool($)

    expect(world.line).toBe(undefined)
  })

  test('follows program.json edited mid-session', async ($, on) => {
    const world = seat(on)

    world.save([m('m1', 'Walking skeleton', 'queued'), m('m2', 'Client list', 'queued', ['m1'])])
    await start($)
    expect(world.line).toBe('overseer  milestone 1/2  m1 Walking skeleton (queued)')

    world.save([m('m1', 'Walking skeleton', 'done'), m('m2', 'Client list', 'queued', ['m1'])])
    const r = await runTool($)

    expect(world.line).toBe('overseer  milestone 2/2  m2 Client list (queued)')
    expect(r.result, 'the tool call passes through').toBe('ok')
  })

  test('leaves a subagent’s tool call to the next main-loop one', async ($, on) => {
    const world = seat(on)

    world.save([m('m1', 'Walking skeleton', 'queued'), m('m2', 'Client list', 'queued', ['m1'])])
    await start($)

    world.save([m('m1', 'Walking skeleton', 'done'), m('m2', 'Client list', 'queued', ['m1'])])
    const r = await $.tool.call({ tool: 'Read', file_path: '/work/app/README.md', agentId: 'a1' })

    expect(world.line, 'unchanged after the subagent’s call').toBe('overseer  milestone 1/2  m1 Walking skeleton (queued)')
    expect(r.result, 'the tool call passes through').toBe('ok')

    await runTool($)

    expect(world.line).toBe('overseer  milestone 2/2  m2 Client list (queued)')
  })

  test('clears when program.json is gone', async ($, on) => {
    const world = seat(on)

    world.save(IN_FLIGHT)
    await start($)
    expect(world.line, 'shown before the file goes').toBe(IN_FLIGHT_LINE)

    world.disk.delete(PROGRAM)
    await runTool($)

    expect(world.line).toBe(undefined)
  })

  test('clears with CC_OVERSEER_STATUS=off', async ($, on) => {
    const world = seat(on)

    world.save(IN_FLIGHT)
    await start($)
    expect(world.line, 'shown before the switch').toBe(IN_FLIGHT_LINE)

    world.env.CC_OVERSEER_STATUS = 'off'
    await runTool($)

    expect(world.line).toBe(undefined)
  })

  test('pins nothing with cc_overseer_status off in /config', { options: { cc_overseer_status: false } }, async ($, on) => {
    const world = seat(on)

    world.save(IN_FLIGHT)
    await start($)
    await runTool($)

    expect(world.lines.filter(line => line !== undefined)).toEqual([])
  })

  test('lets CC_OVERSEER_STATUS=on override cc_overseer_status off in /config', { options: { cc_overseer_status: false } }, async ($, on) => {
    const world = seat(on, { env: { CC_OVERSEER_STATUS: 'on' } })

    world.save(IN_FLIGHT)
    await start($)

    expect(world.line).toBe(IN_FLIGHT_LINE)
  })

  test('clears when program.json is malformed', async ($, on) => {
    const world = seat(on)

    world.save(IN_FLIGHT)
    await start($)
    expect(world.line, 'shown before the file breaks').toBe(IN_FLIGHT_LINE)

    world.write('{"milestones": [')
    await runTool($)

    expect(world.line).toBe(undefined)
  })

  test('reads program.json once while its mtime stands, and keeps the line', async ($, on) => {
    const world = seat(on)

    world.save(IN_FLIGHT)
    await start($)
    await runTool($)

    expect(world.io.filter(entry => entry.startsWith('read '))).toEqual([`read ${PROGRAM}`])
    expect(world.line).toBe(IN_FLIGHT_LINE)
  })

  test('retries a read that failed at the next refresh', async ($, on) => {
    const world = seat(on)

    world.save(IN_FLIGHT)
    world.failedReads = 1
    await start($)
    await runTool($)

    expect(world.line).toBe(IN_FLIGHT_LINE)
  })

  test('an older refresh finishing last does not repaint over a newer clear', async ($, on) => {
    const world = seat(on)

    world.save(IN_FLIGHT)

    const read = world.holdNextRead()
    const older = runTool($)

    await read.reached
    world.env.CC_OVERSEER_STATUS = 'off'
    await runTool($)
    read.release()
    await older

    expect(world.line).toBe(undefined)
  })

  test('does nothing below CLI 2.1.291', async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    world.save(IN_FLIGHT)
    await start($)
    await runTool($)

    expect({ lines: world.lines, io: world.io }).toEqual({ lines: [], io: [] })
  })
})
