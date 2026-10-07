import type { On } from 'claude-code'

import { gitLine, registerSuggestion, stateRoot } from './cc-kit'
import type { Host } from './cc-kit'

function closedHead(text: string): string | null {
  let data: unknown

  try {
    data = JSON.parse(text)
  } catch {
    return null
  }

  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    return null
  }

  const { head, cards_total: total, cards_done: done, cards_parked: parked } = data as Record<string, unknown>
  const isPlain = total === undefined && done === undefined && parked === undefined

  const isClosed =
    typeof total === 'number' &&
    typeof done === 'number' &&
    typeof parked === 'number' &&
    done + parked === total

  return typeof head === 'string' && (isPlain || isClosed) ? head : null
}

async function greenHead(host: Host): Promise<string | null> {
  const text = await host.read(`${await stateRoot(host)}/.claude/task-runner/gate-pass.json`).catch(() => null)
  const head = text === null ? null : closedHead(text)

  if (head === null || head !== (await gitLine(host, ['rev-parse', 'HEAD']))) {
    return null
  }

  const branch = await gitLine(host, ['rev-parse', '--abbrev-ref', 'HEAD'])

  if (branch === null || branch === 'HEAD') {
    return null
  }

  const remoteDefault = await gitLine(host, ['symbolic-ref', '--short', 'refs/remotes/origin/HEAD'])

  const isDefault =
    remoteDefault === null
      ? branch === 'master' || branch === 'main'
      : branch === remoteDefault.replace(/^origin\//, '')

  // An upstream at the gate head is read as finish's PR path having run (a hand push reads the same).
  return isDefault || (await gitLine(host, ['rev-parse', '@{u}'])) === head ? null : head
}

export function register(on: On) {
  let green: string | null = null

  registerSuggestion(on, {
    transition: 'finish',
    atTurnEnd: async host => (green = await greenHead(host)),
    // The kit calls atTurnEnd and then stillDue within one turn end, so green is this turn's answer.
    stillDue: async (host, key) => key === green,
    text: () => '/git-workflow:finish',
  })
}
