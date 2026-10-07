import type {
  Args,
  EngineInterface,
  FsStat,
  On,
  ProcessRunInit,
  ProcessRunResult,
  ResultOf,
} from 'claude-code'

export type Host = {
  run: (argv: readonly string[], init?: ProcessRunInit) => Promise<ProcessRunResult>
  read: (path: string) => Promise<string>
  stat: (path: string) => Promise<FsStat>
  now: () => Promise<number>
  sessionId: () => Promise<string>
  cwd: () => Promise<string>
  projectDir: () => Promise<string | undefined>
}

export const MODS_FLOOR = '2.1.291'

const PHASE_TTL_MS = 120 * 60 * 1000

const GIT_TIMEOUT_MS = 2000

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

function partsOf(version: string): [number, number, number] | null {
  const match = /^(\d+)\.(\d+)\.(\d+)/.exec(version)

  return match ? [Number(match[1]), Number(match[2]), Number(match[3])] : null
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function parsed(text: string): unknown {
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

// Folds `..` without resolving symlinks, as `cd -- "$1/$up" && pwd` does in cc_state_root.
function joined(dir: string, relative: string): string {
  const parts = dir.split('/').filter(part => part !== '')

  for (const part of relative.split('/')) {
    if (part === '..') {
      parts.pop()
    } else if (part !== '' && part !== '.') {
      parts.push(part)
    }
  }

  return `/${parts.join('/')}`
}

export function isSupported(version: string): boolean {
  const seen = partsOf(version)
  const floor = partsOf(MODS_FLOOR)

  if (!seen || !floor) {
    return false
  }

  const [major, minor, patch] = seen
  const [floorMajor, floorMinor, floorPatch] = floor

  if (major !== floorMajor) {
    return major > floorMajor
  }

  return minor !== floorMinor ? minor > floorMinor : patch >= floorPatch
}

export function switchOn(value: string | undefined, option?: boolean): boolean {
  if (value === undefined || value === '') {
    return option ?? true
  }

  return !/^(off|0|false)$/i.test(value)
}

export async function gitLine(host: Host, args: string[]): Promise<string | null> {
  const ran = await host
    .run(['git', ...args], { cwd: await host.cwd(), timeoutMs: GIT_TIMEOUT_MS })
    .catch(() => null)

  return ran?.exitCode === 0 ? ran.stdout.trim() : null
}

export async function stateRoot(host: Host): Promise<string> {
  const cwd = await host.cwd()
  const up = await gitLine(host, ['rev-parse', '--show-cdup'])

  if (up !== null) {
    return up === '' ? cwd : joined(cwd, up)
  }

  const projectDir = ((await host.projectDir()) ?? '').replace(/\/$/, '')

  return projectDir !== '' && `${cwd}/`.startsWith(`${projectDir}/`) ? projectDir : cwd
}

export async function liveSentinel(host: Host, root?: string): Promise<{ phase: string } | null> {
  const path = `${root ?? (await stateRoot(host))}/.claude/cc-phase.json`
  const stat = await host.stat(path).catch(() => null)
  const text = stat ? await host.read(path).catch(() => null) : null

  if (!stat || text === null || (await host.now()) - stat.mtimeMs > PHASE_TTL_MS) {
    return null
  }

  const data = parsed(text)

  if (!isRecord(data) || typeof data.phase !== 'string' || data.phase === '') {
    return null
  }

  const writer = typeof data.session_id === 'string' ? data.session_id : ''

  if (writer !== '' && writer !== (await host.sessionId())) {
    return null
  }

  return { phase: data.phase }
}

export async function activeRun(
  host: Host,
): Promise<{ slug: string; branch: string; index_path?: string; root: string } | null> {
  const root = await stateRoot(host)
  const text = await host.read(`${root}/.claude/task-runner/active-run.json`).catch(() => null)
  const data = text === null ? null : parsed(text)

  if (!isRecord(data) || typeof data.slug !== 'string' || typeof data.branch !== 'string') {
    return null
  }

  const current = await gitLine(host, ['rev-parse', '--abbrev-ref', 'HEAD'])

  if (current === null || current === 'HEAD' || current !== data.branch) {
    return null
  }

  return {
    slug: data.slug,
    branch: data.branch,
    ...(typeof data.index_path === 'string' && { index_path: data.index_path }),
    root,
  }
}

export function registerSuggestion(
  on: On,
  spec: {
    transition: string
    tools?: string
    onToolCall?: (
      host: Host,
      e: Args<'tool.call'>,
      r: ResultOf['tool.call'],
    ) => Promise<string | null>
    atTurnEnd?: (host: Host) => Promise<string | null>
    stillDue?: (host: Host, key: string) => Promise<boolean>
    text: (key: string) => string
  },
): void {
  let armed: { session: string; keys: string[] } = { session: '', keys: [] }
  const shown = new Set<string>()

  const armedIn = (session: string) => (armed.session === session ? armed.keys : [])

  const onToolCall = spec.onToolCall
  const tools = new RegExp(`^(?:${spec.tools ?? '.*'})$`)

  if (onToolCall) {
    on('tool.call', { tool: tools }, async ($, e, next) => {
      const r = await next(e)

      if (e.agentId !== undefined) {
        return r
      }

      const isOn =
        switchOn(await $.env.get('CC_SUGGEST')) &&
        isSupported((await $.session.version()).version)

      if (!isOn) {
        return r
      }

      const host = hostOf($)
      const key = await onToolCall(host, e, r)

      if (key === null || (await liveSentinel(host)) !== null) {
        return r
      }

      const session = await host.sessionId()

      armed = { session, keys: [...armedIn(session), key] }

      return r
    }).catch(($, e, next) => next(e))
  }

  on('turn.complete', async ($, e, next) => {
    const r = await next(e)

    if (e.agentId !== undefined) {
      return r
    }

    const host = hostOf($)
    const session = await host.sessionId()
    const candidates = armedIn(session)
    const isIdle = candidates.length === 0 && !spec.atTurnEnd

    if (isIdle || !isSupported((await $.session.version()).version)) {
      return r
    }

    armed = { session, keys: [] }

    if (!switchOn(await $.env.get('CC_SUGGEST')) || (await liveSentinel(host)) !== null) {
      return r
    }

    const atEnd = spec.atTurnEnd ? await spec.atTurnEnd(host) : null
    const dedupeOf = (key: string) => `${session}|${spec.transition}|${key}`

    const key = [...candidates, ...(atEnd === null ? [] : [atEnd])]
      .filter(candidate => !shown.has(dedupeOf(candidate)))
      .at(-1)

    if (key === undefined || (spec.stillDue && !(await spec.stillDue(host, key)))) {
      return r
    }

    const { isShown } = await $.prompt.suggest({ text: spec.text(key) })

    if (isShown) {
      shown.add(dedupeOf(key))
    } else {
      armed = { session, keys: [key, ...armedIn(session)] }
    }

    return r
  }).catch(($, e, next) => next(e))
}
