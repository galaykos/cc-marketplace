import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { hostOf, isSupported, phaseFile, stateRoot, switchOn } from './cc-kit'

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

// Plugins kept this state under .claude/ before 2026-11-14: each read below falls back to it while the new path holds none.
const LEGACY = '.claude'

// A summary keeps what it is told word for word, so a sentinel past its writer's TTL is left out (taskmaster scripts/phase-sentinel.sh).
// Only this session's sentinel: another session's phase is not this conversation's state.
async function freshSentinel($: EngineInterface, root: string): Promise<{ dir: string; text: string | null } | null> {
  const id = await $.session.id()

  for (const base of ['.cc-artifacts', LEGACY]) {
    const path = phaseFile(root, id, base)
    const stat = path === null ? null : await $.fs.stat(path).catch(() => null)

    if (path !== null && stat !== null) {
      return (await $.clock.now()) - stat.mtimeMs > PHASE_TTL_MS ? null : { dir: `${base}/cc-phase/`, text: await $.fs.read(path).catch(() => null) }
    }
  }

  return null
}

// The ledgers of one kind in the first directory holding any.
function ledgersOf(lists: readonly (readonly [string, string[]])[], shape: RegExp): { dir: string; names: string[] } | null {
  for (const [dir, names] of lists) {
    const hits = names.filter(name => shape.test(name)).map(cleaned)

    if (hits.length > 0) {
      return { dir, names: hits }
    }
  }

  return null
}

// The paths hooks/compact-capsule.sh reads; it still names a stale sentinel, since its notice has the model re-read each file.
export async function stateLines($: EngineInterface, root: string): Promise<string[]> {
  const listed = (dir: string) =>
    $.fs
      .list(`${root}/${dir}`)
      .then(entries => entries.map(entry => entry.name).sort())
      .catch(() => [] as string[])
  // task-runner copies its old directory into the new one once, so the old one counts only until the new one exists.
  const runDir = (await $.fs.exists(`${root}/.cc-artifacts/task-runner`).catch(() => false)) ? '.cc-artifacts/task-runner' : `${LEGACY}/task-runner`
  const [sentinel, run, scope, fresh, old] = await Promise.all([
    freshSentinel($, root),
    $.fs.read(`${root}/${runDir}/active-run.json`).catch(() => null),
    $.fs.exists(`${root}/${runDir}/scope.json`).catch(() => false),
    listed('.cc-artifacts/taskmaster'),
    listed(`${LEGACY}/taskmaster`),
  ])
  const lines: string[] = []
  const phase = fieldOf(sentinel?.text ?? null, 'phase')

  if (phase !== '') {
    const owner = fieldOf(sentinel?.text ?? null, 'owner')

    lines.push(`arc phase ${phase}${owner === '' ? '' : ` owned by ${owner}`}, declared by this session (${sentinel?.dir})`)
  }

  if (run !== null) {
    const slug = fieldOf(run, 'slug')
    const branch = fieldOf(run, 'branch')
    const index = fieldOf(run, 'index_path')

    lines.push(`task-runner run${slug === '' ? '' : ` ${slug}`}${branch === '' ? '' : ` on branch ${branch}`}${index === '' ? '' : `, cards at ${index}`} (${runDir}/active-run.json)`)
  }

  if (scope) {
    lines.push(`scope lock active (${runDir}/scope.json)`)
  }

  const lists = [
    ['.cc-artifacts/taskmaster/', fresh],
    [`${LEGACY}/taskmaster/`, old],
  ] as const
  const ledgers = ledgersOf(lists, /^ledger-.+\.md$/)
  const goals = ledgersOf(lists, /^goal-ledger-.+\.md$/)

  if (ledgers !== null) {
    lines.push(`open taskmaster ledger(s): ${ledgers.names.join(', ')} (${ledgers.dir})`)
  }

  if (goals !== null) {
    lines.push(`goal ledger(s): ${goals.names.join(', ')} (${goals.dir})`)
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
