import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { hostOf, isSupported, stateRoot, switchOn } from './cc-kit'
import type { Host } from './cc-kit'
import { nextMilestone, overseerLine } from './status-core'

function parsed(text: string): unknown {
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

type Shown = { seen: string; line?: string }

type Refreshes = { cached?: Shown; latest: number }

// Programs opened before 2026-11-14 live in .claude/overseer/ until program.sh first copies them; then only the new dir counts.
async function programFile(host: Host, root: string): Promise<{ path: string; mtimeMs: number } | null> {
  const path = `${root}/.cc-artifacts/overseer/program.json`
  const stat = await host.stat(path).catch(() => null)

  if (stat) {
    return { path, mtimeMs: stat.mtimeMs }
  }

  if (await host.stat(`${root}/.cc-artifacts/overseer`).catch(() => null)) {
    return null
  }

  const legacy = `${root}/.claude/overseer/program.json`
  const old = await host.stat(legacy).catch(() => null)

  return old ? { path: legacy, mtimeMs: old.mtimeMs } : null
}

// null when the read failed, so nothing is cached and the next refresh reads again.
async function shownAt(host: Host, path: string, seen: string): Promise<Shown | null> {
  if (seen === '') {
    return { seen }
  }

  const text = await host.read(path).catch(() => null)

  if (text === null) {
    return null
  }

  const next = nextMilestone(parsed(text))

  return next ? { seen, line: overseerLine(next) } : { seen }
}

// The mtime skips the read, never the paint; only the newest of overlapping refreshes caches and paints.
async function refresh($: EngineInterface, refreshes: Refreshes, option: boolean): Promise<void> {
  const mine = ++refreshes.latest

  if (!isSupported((await $.session.version()).version)) {
    return
  }

  const host = hostOf($)
  const isOn = switchOn(await $.env.get('CC_OVERSEER_STATUS'), option)
  const found = isOn ? await programFile(host, await stateRoot(host)) : null
  const seen = found ? `${found.path}\t${found.mtimeMs}` : ''
  const shown = seen === refreshes.cached?.seen ? refreshes.cached : await shownAt(host, found?.path ?? '', seen)

  if (mine !== refreshes.latest) {
    return
  }

  refreshes.cached = shown ?? undefined
  $.ui.status(shown?.line)
}

// The calls that can change program.json: program.sh through Bash, or a hand edit through an edit tool.
const WRITERS = /^(?:Bash|Write|Edit|MultiEdit)$/

export function register(on: On, options: PluginOptions) {
  const refreshes: Refreshes = { latest: 0 }
  const option = options.cc_overseer_status !== false

  on('session.start', async ($, e, next) => {
    const started = await next(e)

    await refresh($, refreshes, option)

    return started
  }).catch(($, e, next) => next(e))

  // program.sh, the one writer of program.json, runs in the main loop: a subagent's calls cannot move the line, and a
  // read-only call (Read, Grep, Glob) cannot either, so neither waits for a git call.
  on('tool.call', { tool: WRITERS }, async ($, e, next) => {
    const r = await next(e)

    if (e.agentId === undefined) {
      await refresh($, refreshes, option)
    }

    return r
  }).catch(($, e, next) => next(e))
}
