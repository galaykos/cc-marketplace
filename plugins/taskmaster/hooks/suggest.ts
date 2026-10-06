import type { On } from 'claude-code'

import { registerSuggestion, stateRoot } from './cc-kit'

// brainstorm writes `<date>-<slug>-design.md` here too; its next step is /taskmaster:task, not a red-team.
const SPEC = /(?:^|\/)taskmaster-docs\/specs\/(?![^/]*-design\.md$)[^/]+\.md$/

export function register(on: On) {
  registerSuggestion(on, {
    transition: 'spec-redteam',
    tools: 'Write',
    onToolCall: async (host, e, r) => {
      const isWritten = e.tool === 'Write' && r.deny === undefined && r.isError !== true

      if (!isWritten || !e.file_path.includes('/taskmaster-docs/specs/')) {
        return null
      }

      const root = `${await stateRoot(host)}/`

      return e.file_path.startsWith(root) && SPEC.test(e.file_path.slice(root.length)) ? e.file_path : null
    },
    text: key => `/taskmaster:redteam ${key}`,
  })
}
