import type { On } from 'claude-code'

import { registerSuggestion } from './cc-kit'

// The runner invocations the flake hunt resolves to; a path prefix (vendor/bin/phpunit, ./node_modules/.bin/jest) counts.
const TEST_COMMAND =
  /(?:^|[\s;&|(/])(?:(?:npm|pnpm|yarn|bun)\s+(?:run\s+)?test\b|vitest\b|jest\b|pytest\b|phpunit\b|pest\b|artisan\s+test\b|go\s+test\b|cargo\s+test\b|rspec\b|mocha\b|playwright\s+test\b|dotnet\s+test\b)/

const EDIT_TOOLS = new Set(['Write', 'Edit', 'MultiEdit', 'NotebookEdit'])

type Outcomes = { edits: number; passed: boolean; failed: boolean }

// Per session: edits made through the edit tools, and each test command's outcomes since the last of them.
const edits = new Map<string, number>()

const outcomes = new Map<string, Outcomes>()

const normalized = (command: string) => command.trim().replace(/\s+/g, ' ')

export function register(on: On) {
  registerSuggestion(on, {
    transition: 'flake-hunt',
    tools: 'Bash|Write|Edit|MultiEdit|NotebookEdit',
    onToolCall: async (host, e, r) => {
      if (r.deny !== undefined) {
        return null
      }

      const session = await host.sessionId()

      if (EDIT_TOOLS.has(e.tool)) {
        if (r.isError !== true) {
          edits.set(session, (edits.get(session) ?? 0) + 1)
        }

        return null
      }

      const isInterrupted = typeof r.result === 'object' && r.result !== null && 'interrupted' in r.result && r.result.interrupted === true

      if (e.tool !== 'Bash' || isInterrupted || !TEST_COMMAND.test(e.command)) {
        return null
      }

      const command = normalized(e.command)
      const key = `${session}|${command}`
      const now = edits.get(session) ?? 0
      const prior = outcomes.get(key)
      const since = prior?.edits === now ? prior : { edits: now, passed: false, failed: false }
      const seen = r.isError === true ? { ...since, failed: true } : { ...since, passed: true }

      outcomes.set(key, seen)

      // Passed and failed with no edit between: the code did not change, so the test did.
      return seen.passed && seen.failed ? command : null
    },
    text: () => '/testing:flake-hunt',
  })
}
