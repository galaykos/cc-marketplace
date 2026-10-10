import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { isSupported, stateRoot, switchOn } from './cc-kit'
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

export const CAP = 1200

const PHASE_TTL_MS = 120 * 60 * 1000

const ASK =
  'Pipeline state is open on disk (skill-router read it). In the summary keep, word for word where the conversation states them: the current arc phase; the active run slug, branch and card index path; the id of the card in progress and its success criteria; the scope lock; and the list of cards already done. Never mark a card done that the conversation does not show done.'

// Only path-like characters reach the summarizer's instructions: a field or a file name cannot carry a sentence into them.
function cleaned(value: string): string {
  return value.replace(/[^\w./@:+-]/g, '').slice(0, 80)
}

function fieldOf(text: string | null, key: string): string {
  try {
    const value: unknown = text === null ? null : JSON.parse(text)?.[key]

    return typeof value === 'string' ? cleaned(value) : ''
  } catch {
    return ''
  }
}

// A summary keeps what it is told word for word, so a sentinel past its writer's TTL is left out (taskmaster scripts/phase-sentinel.sh).
async function freshSentinel($: EngineInterface, root: string): Promise<string | null> {
  const path = `${root}/.claude/cc-phase.json`
  const stat = await $.fs.stat(path).catch(() => null)

  if (stat === null || (await $.clock.now()) - stat.mtimeMs > PHASE_TTL_MS) {
    return null
  }

  return $.fs.read(path).catch(() => null)
}

// The paths hooks/compact-capsule.sh reads; it still names a stale sentinel, since its notice has the model re-read each file.
export async function stateLines($: EngineInterface, root: string): Promise<string[]> {
  const read = (path: string) => $.fs.read(`${root}/.claude/${path}`).catch(() => null)
  const [sentinel, run, scope, names] = await Promise.all([
    freshSentinel($, root),
    read('task-runner/active-run.json'),
    $.fs.exists(`${root}/.claude/task-runner/scope.json`).catch(() => false),
    $.fs
      .list(`${root}/.claude/taskmaster`)
      .then(entries => entries.map(entry => entry.name).sort())
      .catch(() => [] as string[]),
  ])
  const lines: string[] = []
  const phase = fieldOf(sentinel, 'phase')

  if (phase !== '') {
    const owner = fieldOf(sentinel, 'owner')
    const writer = fieldOf(sentinel, 'session_id')
    const who = writer !== '' && writer === (await $.session.id()) ? 'this session' : 'another session'

    lines.push(`arc phase ${phase}${owner === '' ? '' : ` owned by ${owner}`}, declared by ${who} (.claude/cc-phase.json)`)
  }

  if (run !== null) {
    const slug = fieldOf(run, 'slug')
    const branch = fieldOf(run, 'branch')
    const index = fieldOf(run, 'index_path')

    lines.push(`task-runner run${slug === '' ? '' : ` ${slug}`}${branch === '' ? '' : ` on branch ${branch}`}${index === '' ? '' : `, cards at ${index}`} (.claude/task-runner/active-run.json)`)
  }

  if (scope) {
    lines.push('scope lock active (.claude/task-runner/scope.json)')
  }

  const ledgers = names.filter(name => /^ledger-.+\.md$/.test(name)).map(cleaned)
  const goals = names.filter(name => /^goal-ledger-.+\.md$/.test(name)).map(cleaned)

  if (ledgers.length > 0) {
    lines.push(`open taskmaster ledger(s): ${ledgers.join(', ')} (.claude/taskmaster/)`)
  }

  if (goals.length > 0) {
    lines.push(`goal ledger(s): ${goals.join(', ')} (.claude/taskmaster/)`)
  }

  return lines
}

export function steer(instructions: string | undefined, lines: readonly string[]): string {
  const facts = ` State found: ${lines.join('; ')}.`
  const added = `${ASK}${facts}`.length <= CAP ? `${ASK}${facts}` : `${`${ASK}${facts}`.slice(0, CAP - 1)}…`

  return instructions === undefined || instructions.trim() === '' ? added : `${instructions}\n\n${added}`
}

export function registerCompact(on: On, options: PluginOptions) {
  on('session.compact', async ($, e, next) => {
    if (e.agentId !== undefined) {
      return next(e)
    }

    const isOn =
      isSupported((await $.session.version()).version) &&
      switchOn(await $.env.get('CC_COMPACT_STEER'), options.cc_compact_steer !== false)
    const lines = isOn ? await stateLines($, await stateRoot(hostOf($))) : []

    return lines.length === 0 ? next(e) : next({ ...e, instructions: steer(e.instructions, lines) })
  }).catch(($, e, next) => next(e))
}
