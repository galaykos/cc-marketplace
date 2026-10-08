import type { On } from 'claude-code'

import { registerSuggestion } from './cc-kit'

const SHOWN_CHARS = 80

// Per session and command: a fix that did not hold shows as the same command failing again.
const failures = new Map<string, number>()

const normalized = (command: string) => command.trim().replace(/\s+/g, ' ')

const shortened = (command: string) => (command.length <= SHOWN_CHARS ? command : `${command.slice(0, SHOWN_CHARS - 1)}…`)

export function register(on: On) {
  registerSuggestion(on, {
    transition: 'debug',
    tools: 'Bash',
    onToolCall: async (host, e, r) => {
      if (e.tool !== 'Bash' || r.deny !== undefined) {
        return null
      }

      const isInterrupted = typeof r.result === 'object' && r.result !== null && 'interrupted' in r.result && r.result.interrupted === true

      if (isInterrupted) {
        return null
      }

      const command = normalized(e.command)
      const key = `${await host.sessionId()}|${command}`

      if (r.isError !== true) {
        failures.delete(key)

        return null
      }

      const count = (failures.get(key) ?? 0) + 1

      failures.set(key, count)

      return count === 2 ? command : null
    },
    text: command => `/debugging:debug \`${shortened(command)}\` failed twice`,
  })
}
