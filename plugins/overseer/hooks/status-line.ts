import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { isSupported, stateRoot, switchOn } from './cc-kit'
import type { Host } from './cc-kit'
import { nextMilestone, overseerLine } from './status-core'

// Shared block templates/mods/host-block.ts — re-paste byte-for-byte.
function hostOf($: EngineInterface): Host {
  return {
    run: (argv, init) => $.process.run(argv, init),
    read: path => $.fs.read(path),
    stat: path => $.fs.stat(path),
    now: () => $.clock.now(),
    sessionId: () => $.session.id(),
    cwd: () => $.session.cwd(),
    projectDir: () => $.env.get('CLAUDE_PROJECT_DIR'),
  }
}

function parsed(text: string): unknown {
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

type Shown = { seen: string; line?: string }

type Refreshes = { cached?: Shown; latest: number }

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
  const path = isOn ? `${await stateRoot(host)}/.claude/overseer/program.json` : ''
  const stat = path === '' ? null : await host.stat(path).catch(() => null)
  const seen = stat ? `${path}\t${stat.mtimeMs}` : ''
  const shown = seen === refreshes.cached?.seen ? refreshes.cached : await shownAt(host, path, seen)

  if (mine !== refreshes.latest) {
    return
  }

  refreshes.cached = shown ?? undefined
  $.ui.status(shown?.line)
}

export function register(on: On, options: PluginOptions) {
  const refreshes: Refreshes = { latest: 0 }
  const option = options.cc_overseer_status !== false

  on('session.start', async ($, e, next) => {
    const started = await next(e)

    await refresh($, refreshes, option)

    return started
  }).catch(($, e, next) => next(e))

  on('tool.call', async ($, e, next) => {
    const r = await next(e)

    await refresh($, refreshes, option)

    return r
  }).catch(($, e, next) => next(e))
}
