import type { EngineInterface, On, PluginOptions, PluginState } from 'claude-code'

import { parseIndex, statusLine } from './board-core'
import { boardView } from './board-view'
import { activeRun, isSupported, liveSentinel, stateRoot, switchOn } from './cc-kit'
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

type Refreshes = { latest: number; opening: number; paintedRun: string; hasRedTeam: boolean }

type Board = PluginState['task-runner']['board']

const BOARD = { plugin: 'task-runner', key: 'board' } as const

const PANE = { id: 'task-board', title: 'Task board' }

const INACTIVE: Board = { indexPath: null, mtimeMs: null, model: null, runActive: false, phase: '', hasRedTeam: false }

const REOPEN_MS = 100

async function isBoardOn($: EngineInterface, option: boolean): Promise<boolean> {
  return isSupported((await $.session.version()).version) && switchOn(await $.env.get('CC_TASK_BOARD'), option)
}

// The pane calls below answer a safe default rather than throw: a throw after the tool ran fails the person's call closed.
async function isPaneOpen($: EngineInterface): Promise<boolean> {
  return $.ui.panes().then(panes => panes.some(pane => pane.id === PANE.id), () => false)
}

// A pinned reopen below the width floor is listed but undrawn; /task-board must place it, not close it.
async function isPanePlaced($: EngineInterface): Promise<boolean> {
  return $.ui.panes().then(panes => panes.some(pane => pane.id === PANE.id && pane.isPlaced), () => false)
}

async function isRedTeamListed($: EngineInterface): Promise<boolean> {
  return $.command.list().then(commands => commands.some(command => command.name === 'taskmaster:redteam'), () => false)
}

// The spec path is filled into the prompt beside the absolute index path, so it is stored absolute too.
function rooted(model: ReturnType<typeof parseIndex>, root: string): ReturnType<typeof parseIndex> {
  return 'error' in model || model.specPath === null ? model : { ...model, specPath: `${root}/${model.specPath}` }
}

async function indexOf(host: Host, held: Board | undefined, root: string, indexPath: string, slug: string): Promise<Pick<Board, 'mtimeMs' | 'model'>> {
  const mtimeMs = await host.stat(indexPath).then(s => s.mtimeMs, () => null)

  const isHeld =
    mtimeMs !== null &&
    held !== undefined &&
    held.model !== null &&
    !('error' in held.model) &&
    held.indexPath === indexPath &&
    held.mtimeMs === mtimeMs

  const model = isHeld
    ? held.model
    : await host.read(indexPath).then(
        md => rooted(parseIndex(md, slug), root),
        (error: unknown) => ({ error: error instanceof Error ? error.message : String(error) }),
      )

  return { mtimeMs, model }
}

async function newestBoard($: EngineInterface, host: Host, held: Board | undefined, hasRedTeam: boolean): Promise<Board> {
  const root = await stateRoot(host)
  const tasks = `${root}/taskmaster-docs/tasks`
  const entries = await $.fs.list(tasks).catch(() => [])

  const stamped = await Promise.all(
    entries.map(({ name }) => host.stat(`${tasks}/${name}/00-INDEX.md`).then(s => [{ slug: name, mtimeMs: s.mtimeMs }], () => [])),
  )

  const newest = stamped.flat().sort((a, b) => b.mtimeMs - a.mtimeMs)[0]

  if (newest === undefined) {
    return INACTIVE
  }

  const indexPath = `${tasks}/${newest.slug}/00-INDEX.md`
  const { mtimeMs, model } = await indexOf(host, held, root, indexPath, newest.slug)
  const phase = (await liveSentinel(host, root))?.phase ?? ''

  return { indexPath, mtimeMs, model, runActive: false, phase, hasRedTeam }
}

// An unasked open below the engine's width floor waits undrawn; withdrawn, a later widening cannot seat it mid-run.
async function openOnRunStart($: EngineInterface): Promise<void> {
  if (await isPaneOpen($)) {
    return
  }

  const opened = await $.ui.open(PANE).catch(() => null)

  if (opened?.isPlaced === false) {
    await $.ui.close({ id: PANE.id }).catch(() => undefined)
  }
}

// Every tool call refreshes the board, so a write is skipped when nothing in it changed.
async function save($: EngineInterface, held: Board | undefined, board: Board): Promise<void> {
  if (JSON.stringify(held) !== JSON.stringify(board)) {
    await $.state.set(BOARD, board)
  }
}

// Only the newest of overlapping refreshes writes or paints: an older one finishing last would revive an ended run's line.
async function refresh($: EngineInterface, refreshes: Refreshes, option: boolean): Promise<void> {
  const mine = ++refreshes.latest

  if (!isSupported((await $.session.version()).version)) {
    return
  }

  const host = hostOf($)
  const isOn = switchOn(await $.env.get('CC_TASK_BOARD'), option)
  const run = isOn ? await activeRun(host) : null
  const { value: held } = await $.state.get(BOARD)

  if (run === null) {
    const isShown = isOn && (refreshes.opening > 0 || (await isPaneOpen($)))
    const board = isShown ? await newestBoard($, host, held, refreshes.hasRedTeam) : INACTIVE

    if (mine !== refreshes.latest) {
      return
    }

    await save($, held, board)

    if (mine === refreshes.latest) {
      $.ui.status(undefined)
    }

    return
  }

  const listed = run.index_path ?? ''
  const indexPath = listed === '' ? null : listed.startsWith('/') ? listed : `${run.root}/${listed}`
  const { mtimeMs, model } = indexPath === null ? { mtimeMs: null, model: null } : await indexOf(host, held, run.root, indexPath, run.slug)
  const phase = (await liveSentinel(host, run.root))?.phase ?? 'build'
  const board = { indexPath, mtimeMs, model, runActive: true, phase, hasRedTeam: refreshes.hasRedTeam }

  if (mine !== refreshes.latest) {
    return
  }

  await save($, held, board)

  if (mine === refreshes.latest) {
    $.ui.status(model === null || 'error' in model ? `task-runner  ${phase}` : statusLine(model, phase))

    // Latched here, never cleared on a refresh that reads no run: one transient miss must not reopen a pane the person closed.
    const runKey = `${run.root}|${run.slug}|${run.branch}`

    if (runKey !== refreshes.paintedRun) {
      refreshes.paintedRun = runKey
      await openOnRunStart($)
    }
  }
}

// switchOn defaults an unset option to on; the pin is off unless /config or the variable turns it on.
export function isPinOn(env: string | undefined, option: PluginOptions[string] | undefined): boolean {
  return switchOn(env, option === true)
}

export function registerBoard(on: On, options: PluginOptions) {
  const refreshes: Refreshes = { latest: 0, opening: 0, paintedRun: '', hasRedTeam: false }
  const option = options.cc_task_board !== false

  on('session.start', async ($, e, next) => {
    const r = await next(e)
    const isOn = await isBoardOn($, option)

    if (isOn) {
      refreshes.hasRedTeam = await isRedTeamListed($)
    }

    await refresh($, refreshes, option)

    if (isOn) {
      await $.command.register({ name: 'task-board', description: "Show or hide the pane with the run's cards" })
    }

    return r
  }).catch(($, e, next) => next(e))

  on('tool.call', async ($, e, next) => {
    const r = await next(e)

    await refresh($, refreshes, option)

    return r
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'task-board' }, async ($, e, next) => {
    if (!(await isBoardOn($, option))) {
      return next(e)
    }

    if (await isPanePlaced($)) {
      await $.ui.close({ id: PANE.id })
    } else {
      refreshes.hasRedTeam = await isRedTeamListed($)
      refreshes.opening += 1

      // Written before the open: the engine draws the pane's first frame from the state as it stands.
      try {
        await refresh($, refreshes, option)
        await $.ui.open(PANE)
      } finally {
        refreshes.opening -= 1
      }
    }

    return {}
  }).catch(($, e, next) => next(e))

  // On CLI 2.1.294 a hook answering a person's close without next still closes the pane, so the pin lets it close and opens it again.
  on('ui.close', { id: 'task-board' }, async ($, e, next) => {
    if (e.origin.kind !== 'person') {
      return next(e)
    }

    const r = await next(e)

    const isPinned =
      isPinOn(await $.env.get('CC_TASK_BOARD_PIN'), options.cc_task_board_pin) &&
      (await isBoardOn($, option)) &&
      (await activeRun(hostOf($))) !== null

    if (isPinned) {
      $.clock.after(REOPEN_MS, () => void $.ui.open(PANE).catch(() => undefined))
    }

    return r
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: 'task-board' }, async ($, e, next) => {
    if (!isSupported((await $.session.version()).version)) {
      return next(e)
    }

    const { value: board } = await $.state.get(BOARD)
    const kit = { ui: $.ui.resolve(e), columns: e.props.bodyColumns, fill: (text: string) => $.prompt.fill({ text, mode: 'replace' }) }

    return boardView(kit, board ?? INACTIVE)
  }).catch(($, e, next) => next(e))
}
