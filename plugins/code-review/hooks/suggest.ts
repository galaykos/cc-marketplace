import type { On } from 'claude-code'

import { activeRun, gitLine, registerSuggestion, stateRoot } from './cc-kit'

const DOC_EXT = /\.(md|mdx|txt|rst)$/i

const DOCS_DIR = /(^|\/)docs\//

// The two reviews typed in real sessions followed turns that edited 7 and 5 code files; 1- and 2-file turns drew none.
const MIN_FILES = 3

// Per session: the code files edited through the edit tools in this main-loop turn (a subagent's run raises no turn.start).
const edited = new Map<string, Set<string>>()

export function register(on: On) {
  on('turn.start', async ($, e, next) => {
    edited.delete(await $.session.id())

    return next(e)
  }).catch(($, e, next) => next(e))

  registerSuggestion(on, {
    transition: 'review',
    tools: 'Write|Edit|MultiEdit|NotebookEdit',
    onToolCall: async (host, e, r) => {
      const path = 'notebook_path' in e ? e.notebook_path : 'file_path' in e ? e.file_path : undefined
      const isWritten = r.deny === undefined && r.isError !== true

      if (!isWritten || typeof path !== 'string' || DOC_EXT.test(path)) {
        return null
      }

      const root = await stateRoot(host)

      if (!path.startsWith(`${root}/`)) {
        return null
      }

      // Repo-relative, so a repository cloned beneath a `docs` directory still counts its code.
      if (DOCS_DIR.test(path.slice(root.length + 1)) || (await activeRun(host)) !== null) {
        return null
      }

      const session = await host.sessionId()
      const files = (edited.get(session) ?? new Set<string>()).add(path)

      edited.set(session, files)

      return files.size >= MIN_FILES ? gitLine(host, ['rev-parse', 'HEAD']) : null
    },
    stillDue: async host => (await activeRun(host)) === null,
    text: () => '/code-review:review',
  })
}
