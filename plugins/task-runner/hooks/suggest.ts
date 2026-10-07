import type { On, PluginOptions } from 'claude-code'

import { activeRun, registerSuggestion, stateRoot } from './cc-kit'
import type { Host } from './cc-kit'

const INDEX = /^taskmaster-docs\/tasks\/[^/]+\/00-INDEX\.md$/

const CARD_ROW = /^\s*\|\s*\d\d\s*\|/

// Reads the status column as hooks/announce.sh does; an index with no card rows, or none readable, counts as open.
function hasOpenCard(index: string): boolean {
  const rows = index.split('\n').filter(line => CARD_ROW.test(line))

  return (
    rows.length === 0 ||
    rows.some(row => {
      const cells = row.split('|')
      const status = (cells.at(-1)?.trim() || cells.at(-2)?.trim() || '').toLowerCase()

      return !/^(done|parked|skipped)/.test(status)
    })
  )
}

async function isDue(host: Host, path: string): Promise<boolean> {
  if ((await activeRun(host)) !== null) {
    return false
  }

  const root = await stateRoot(host)

  const passed: unknown = await host
    .read(`${root}/.claude/task-runner/gate-pass.json`)
    .then(text => JSON.parse(text)?.index_path)
    .catch(() => undefined)

  if (typeof passed === 'string' && (passed.startsWith('/') ? passed : `${root}/${passed}`) === path) {
    return false
  }

  return hasOpenCard(await host.read(path).catch(() => ''))
}

export function registerSuggest(on: On, options: PluginOptions) {
  // Held here, not armed through the kit: the kit will not arm under the `shape` sentinel /taskmaster:task writes the index under.
  let pending: { session: string; path: string } | null = null

  registerSuggestion(on, {
    transition: 'run',
    tools: 'Write',
    onToolCall: async (host, e, r) => {
      const isWritten = e.tool === 'Write' && r.deny === undefined && r.isError !== true

      if (!isWritten || !e.file_path.includes('/taskmaster-docs/tasks/')) {
        return null
      }

      const root = `${await stateRoot(host)}/`
      const isIndex = e.file_path.startsWith(root) && INDEX.test(e.file_path.slice(root.length))

      if (isIndex && (await activeRun(host)) === null) {
        pending = { session: await host.sessionId(), path: e.file_path }
      }

      return null
    },
    atTurnEnd: async host => {
      const session = await host.sessionId()
      const path = pending?.session === session ? pending.path : null

      pending = null

      return path !== null && (await isDue(host, path)) ? path : null
    },
    stillDue: isDue,
    text: key => `/task-runner:run ${key}`,
  })
}
