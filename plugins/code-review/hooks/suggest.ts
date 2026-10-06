import type { On } from 'claude-code'

import { activeRun, gitLine, registerSuggestion, stateRoot } from './cc-kit'

const DOC_EXT = /\.(md|mdx|txt|rst)$/i

const DOCS_DIR = /(^|\/)docs\//

export function register(on: On) {
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

      return gitLine(host, ['rev-parse', 'HEAD'])
    },
    stillDue: async host => (await activeRun(host)) === null,
    text: () => '/code-review:review',
  })
}
