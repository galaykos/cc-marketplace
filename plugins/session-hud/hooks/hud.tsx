import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { gitLine, isSupported, switchOn } from './cc-kit'
import type { Host } from './cc-kit'
import { appendTail, hudLine, paneRows, parseSegments, turnLine } from './hud-core'
import type { Breakdown, Figures, Segment } from './hud-core'
import { hudView } from './hud-view'

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

export const PANE = { id: 'hud', title: 'HUD' } as const

const TICK_MS = 30_000

const TOOL_GAP_MS = 2_000

const REOPEN_DELAY_MS = 100

const KEPT_TURNS = 200

// A footer drawn within this of a turn's own duration is that turn's, when its requestId is not yet bound.
const DURATION_SLACK_MS = 1_000

type Switches = { hint: boolean; status: boolean; turn: boolean; pin: boolean; segments: Segment[] }

type Snapshot = { costUsd?: number; contextPercent?: number }

type Hud = {
  latest: number
  lastAt: number
  isSupported: boolean
  isTicking: boolean
  switches: Switches
  figures: Figures | null
  breakdown: Breakdown | null
  line: string
  base: Snapshot | null
  pending: { durationMs: number; line: string } | null
  turns: Map<string, string>
  drawn: Set<string>
  stale: Set<string>
}

const OFF: Switches = { hint: false, status: false, turn: false, pin: false, segments: [] }

async function switchesOf($: EngineInterface, options: PluginOptions): Promise<Switches> {
  const segments = (await $.env.get('CC_HUD_SEGMENTS')) || (typeof options.cc_hud_segments === 'string' ? options.cc_hud_segments : undefined)

  return {
    hint: switchOn(await $.env.get('CC_HUD_HINT'), options.cc_hud_hint !== false),
    status: switchOn(await $.env.get('CC_HUD_STATUS'), options.cc_hud_status === true),
    turn: switchOn(await $.env.get('CC_HUD_TURN'), options.cc_hud_turn !== false),
    pin: switchOn(await $.env.get('CC_HUD_PIN'), options.cc_hud_pin === true),
    segments: parseSegments(segments),
  }
}

// The pane calls answer a safe default rather than throw: a throw inside a tool.call hook fails the person's call closed.
async function hudPane($: EngineInterface) {
  return $.ui.panes().then(panes => panes.find(pane => pane.id === PANE.id), () => undefined)
}

async function gitOf(host: Host): Promise<Pick<Figures, 'branch' | 'isDirty'>> {
  const branch = await gitLine(host, ['rev-parse', '--abbrev-ref', 'HEAD'])

  if (branch === null) {
    return {}
  }

  const changes = await gitLine(host, ['status', '--porcelain', '--untracked-files=no'])

  return { branch, isDirty: changes !== null && changes !== '' }
}

async function breakdownOf($: EngineInterface, columns: number): Promise<Breakdown | null> {
  const usage = await $.session.usage({ breakdown: 'summary', columns }).catch(() => null)
  const detail = usage?.context.breakdown

  if (detail === undefined) {
    return null
  }

  return {
    categories: detail.categories.filter(c => c.kind === 'used' && !c.isDeferred).map(c => ({ name: c.name, tokens: c.tokens })),
    maxTokens: detail.rawMaxTokens,
    ...(detail.autoCompactThreshold !== undefined && { compactAt: detail.autoCompactThreshold }),
  }
}

async function figuresOf($: EngineInterface, wantsGit: boolean): Promise<Figures> {
  const now = await $.clock.now()
  const usage = await $.session.usage().catch(() => null)
  const git = wantsGit ? await gitOf(hostOf($)) : {}

  return {
    now,
    limits: usage?.rateLimits ?? [],
    ...(usage !== null && { startedAt: usage.startedAt, window: usage.context.window }),
    ...(usage?.context.percent !== undefined && { contextPercent: usage.context.percent }),
    ...(usage?.context.tokens !== undefined && { contextTokens: usage.context.tokens }),
    ...(usage?.cost !== undefined && { costUsd: usage.cost.usd }),
    ...git,
  }
}

function snapshotOf(figures: Figures | null): Snapshot {
  return {
    ...(figures?.costUsd !== undefined && { costUsd: figures.costUsd }),
    ...(figures?.contextPercent !== undefined && { contextPercent: figures.contextPercent }),
  }
}

// Only the newest of overlapping refreshes stores or paints: an older one finishing last would paint stale figures.
// Returns what it read either way, so a turn's end measures its own reading even when a timer tick superseded it.
async function refresh($: EngineInterface, hud: Hud, options: PluginOptions): Promise<Figures | null> {
  const mine = ++hud.latest

  hud.isSupported = isSupported((await $.session.version()).version)

  if (!hud.isSupported) {
    return null
  }

  const switches = await switchesOf($, options)
  const pane = await hudPane($)
  const isShowing = switches.hint || switches.status
  const wantsGit = (isShowing && switches.segments.includes('git')) || pane !== undefined
  const figures = isShowing || switches.turn || pane !== undefined ? await figuresOf($, wantsGit) : null
  const breakdown = pane !== undefined ? await breakdownOf($, 80) : null

  if (mine !== hud.latest) {
    return figures
  }

  const line = figures !== null && isShowing ? hudLine(switches.segments, figures) : ''
  const isRedrawn = line !== hud.line || switches.hint !== hud.switches.hint || switches.turn !== hud.switches.turn || pane !== undefined

  hud.switches = switches
  hud.figures = figures
  hud.breakdown = breakdown
  hud.line = line
  hud.lastAt = figures?.now ?? (await $.clock.now())

  $.ui.status(switches.status && line !== '' ? line : undefined)

  if (isRedrawn) {
    $.ui.invalidate('ui.render')
  }

  if (!hud.isTicking && (isShowing || pane !== undefined)) {
    hud.isTicking = true
    $.clock.every(TICK_MS, () => refresh($, hud, options).catch(() => undefined))
  }

  return figures
}

// A /config change reloads the module without a session.start, so the first hook to run after it starts the HUD.
async function started($: EngineInterface, hud: Hud, options: PluginOptions): Promise<void> {
  await refresh($, hud, options)
  hud.base ??= snapshotOf(hud.figures)

  if (hud.isSupported) {
    await pointRowsHere($)
    await $.command.register({ name: 'hud', description: 'Show or hide the session HUD pane: context, rate limits, cost' }).catch(() => undefined)
  }
}

async function ensureStarted($: EngineInterface, hud: Hud, options: PluginOptions): Promise<void> {
  if (hud.latest === 0) {
    await started($, hud, options)
  }
}

// The subagentStatusLine command runs with no CLAUDE_PLUGIN_ROOT, substituted or exported (measured on 2.1.294), so it reads this file.
async function pointRowsHere($: EngineInterface): Promise<void> {
  const configDir = (await $.env.get('CLAUDE_CONFIG_DIR')) || `${(await $.env.get('HOME')) ?? ''}/.claude`
  const pointer = `${configDir.replace(/\/$/, '')}/plugins/session-hud-root`
  const held = await $.fs.read(pointer).catch(() => null)

  if (held?.trim() !== $.plugin.root) {
    await $.fs.write(pointer, `${$.plugin.root}\n`).catch(() => undefined)
  }
}

function trimmed<T>(items: { size: number; keys: () => IterableIterator<T>; delete: (key: T) => boolean }): void {
  for (const key of items.keys()) {
    if (items.size <= KEPT_TURNS) {
      break
    }

    items.delete(key)
  }
}

function footerOf(hud: Hud, requestId: string, durationMs: number): string | undefined {
  const bound = hud.turns.get(requestId)

  hud.drawn.add(requestId)
  trimmed(hud.drawn)

  if (
    bound !== undefined ||
    hud.pending === null ||
    hud.stale.has(requestId) ||
    Math.abs(hud.pending.durationMs - durationMs) > DURATION_SLACK_MS
  ) {
    return bound
  }

  const line = hud.pending.line

  hud.pending = null
  hud.turns.set(requestId, line)
  trimmed(hud.turns)

  return line
}

export function register(on: On, options: PluginOptions) {
  const hud: Hud = {
    latest: 0,
    lastAt: 0,
    isSupported: false,
    isTicking: false,
    switches: OFF,
    figures: null,
    breakdown: null,
    line: '',
    base: null,
    pending: null,
    turns: new Map(),
    drawn: new Set(),
    stale: new Set(),
  }

  on('session.start', async ($, e, next) => {
    const r = await next(e)

    hud.base = null
    await started($, hud, options)

    return r
  }).catch(($, e, next) => next(e))

  on('tool.call', async ($, e, next) => {
    const r = await next(e)

    if (e.agentId === undefined && (await $.clock.now()) - hud.lastAt >= TOOL_GAP_MS) {
      await refresh($, hud, options)
    }

    return r
  }).catch(($, e, next) => next(e))

  // Every footer drawn so far closes an earlier turn: none of them may take the line of the turn starting now.
  on('turn.start', async ($, e, next) => {
    hud.base = snapshotOf(hud.figures)
    hud.stale = new Set(hud.drawn)

    return next(e)
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const r = await next(e)

    if (e.agentId !== undefined) {
      return r
    }

    const base = hud.base
    const read = await refresh($, hud, options)
    const after = snapshotOf(read ?? hud.figures)
    const line = turnLine({
      ...(e.usage !== undefined && { outputTokens: e.usage.output_tokens }),
      ...(after.costUsd !== undefined && base?.costUsd !== undefined && { costUsd: after.costUsd - base.costUsd }),
      ...(after.contextPercent !== undefined &&
        base?.contextPercent !== undefined && { contextDelta: Math.round(after.contextPercent - base.contextPercent) }),
    })

    hud.base = after
    hud.pending = line === '' ? null : { durationMs: e.durationMs, line }

    if (hud.pending !== null && hud.switches.turn) {
      $.ui.invalidate('ui.render')
    }

    return r
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    if (hud.latest === 0) {
      void ensureStarted($, hud, options).catch(() => undefined)
    }

    if (!hud.isSupported || !hud.switches.hint || hud.line === '') {
      return next(e)
    }

    return next({ ...e, props: { ...e.props, tail: appendTail(e.props.tail, hud.line) } })
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'TurnDuration', surface: 'terminal' }, async ($, e, next) => {
    if (hud.latest === 0) {
      void ensureStarted($, hud, options).catch(() => undefined)
    }

    const footer = hud.isSupported && hud.switches.turn ? footerOf(hud, e.requestId, e.props.durationMs) : undefined

    if (footer === undefined) {
      return next(e)
    }

    const { Box, Text } = $.ui.resolve(e)

    // A line of its own: the engine's footer takes the row's full width, so a sibling beside it is pushed to the edge (seen live).
    return (
      <Box flexDirection="column">
        {await next(e)}
        <Text dimColor>{`  ${footer}`}</Text>
      </Box>
    )
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'hud' }, async ($, e, next) => {
    await ensureStarted($, hud, options)

    if (!hud.isSupported) {
      return next(e)
    }

    const pane = await hudPane($)

    if (pane?.isShown && pane.isPlaced) {
      await $.ui.close({ id: PANE.id })

      return {}
    }

    // Opened first so the refresh sees the pane and reads the breakdown; the first frame draws what the last refresh stored.
    await $.ui.open(PANE)
    await refresh($, hud, options)

    return {}
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: 'hud' }, async ($, e, next) => {
    if (hud.latest === 0) {
      void ensureStarted($, hud, options).catch(() => undefined)
    }

    if (!hud.isSupported || hud.figures === null) {
      return next(e)
    }

    return hudView($.ui.resolve(e), paneRows(hud.figures, hud.breakdown, e.props.bodyColumns))
  }).catch(($, e, next) => next(e))

  // Measured on 2.1.294: answering a person's close without next does not keep the pane, so the pin lets it close and reopens it.
  on('ui.close', async ($, e, next) => {
    const r = await next(e)

    if (e.id === PANE.id && e.origin.kind === 'person') {
      await ensureStarted($, hud, options)
    }

    if (e.id === PANE.id && e.origin.kind === 'person' && hud.isSupported && (await switchesOf($, options)).pin) {
      $.clock.after(REOPEN_DELAY_MS, () => $.ui.open(PANE).then(() => undefined, () => undefined))
    }

    return r
  }).catch(($, e, next) => next(e))
}
