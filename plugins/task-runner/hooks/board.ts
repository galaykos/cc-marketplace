import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { parseIndex, statusLine } from './board-core'
import { activeRun, isSupported, liveSentinel, switchOn } from './cc-kit'
import type { Host } from './cc-kit'

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

type Refreshes = { latest: number }

const INACTIVE = { indexPath: null, mtimeMs: null, model: null, runActive: false, phase: '' }

// Only the newest of overlapping refreshes writes or paints: an older one finishing last would revive an ended run's line.
async function refresh($: EngineInterface, refreshes: Refreshes, option: boolean): Promise<void> {
  const mine = ++refreshes.latest

  if (!isSupported((await $.session.version()).version)) {
    return
  }

  const host = hostOf($)
  const isOn = switchOn(await $.env.get('CC_TASK_BOARD'), option)
  const run = isOn ? await activeRun(host) : null

  if (run === null) {
    if (mine !== refreshes.latest) {
      return
    }

    await $.state.set({ plugin: 'task-runner', key: 'board' }, INACTIVE)

    if (mine === refreshes.latest) {
      $.ui.status(undefined)
    }

    return
  }

  const listed = run.index_path ?? ''
  const indexPath = listed === '' ? null : listed.startsWith('/') ? listed : `${run.root}/${listed}`
  const mtimeMs = indexPath === null ? null : await host.stat(indexPath).then(s => s.mtimeMs, () => null)
  const { value: held } = await $.state.get({ plugin: 'task-runner', key: 'board' })

  const isHeld =
    mtimeMs !== null &&
    held !== undefined &&
    held.model !== null &&
    !('error' in held.model) &&
    held.indexPath === indexPath &&
    held.mtimeMs === mtimeMs

  const model =
    indexPath === null
      ? null
      : isHeld
        ? held.model
        : await host.read(indexPath).then(
            md => parseIndex(md, run.slug),
            (error: unknown) => ({ error: error instanceof Error ? error.message : String(error) }),
          )

  const phase = (await liveSentinel(host, run.root))?.phase ?? 'build'

  if (mine !== refreshes.latest) {
    return
  }

  await $.state.set({ plugin: 'task-runner', key: 'board' }, { indexPath, mtimeMs, model, runActive: true, phase })

  if (mine === refreshes.latest) {
    $.ui.status(model === null || 'error' in model ? `task-runner  ${phase}` : statusLine(model, phase))
  }
}

export function registerBoard(on: On, options: PluginOptions) {
  const refreshes: Refreshes = { latest: 0 }
  const option = options.cc_task_board !== false

  on('session.start', async ($, e, next) => {
    const r = await next(e)

    await refresh($, refreshes, option)

    return r
  }).catch(($, e, next) => next(e))

  on('tool.call', async ($, e, next) => {
    const r = await next(e)

    await refresh($, refreshes, option)

    return r
  }).catch(($, e, next) => next(e))
}
