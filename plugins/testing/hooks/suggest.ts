import type { On } from 'claude-code'

import { registerSuggestion } from './cc-kit'

// The runner invocations the flake hunt resolves to; a path prefix (vendor/bin/phpunit, ./node_modules/.bin/jest) counts.
const TEST_COMMAND =
  /(?:^|[\s;&|(/])(?:(?:npm|pnpm|yarn|bun)\s+(?:run\s+)?test\b|vitest\b|jest\b|pytest\b|phpunit\b|pest\b|artisan\s+test\b|go\s+test\b|cargo\s+test\b|rspec\b|mocha\b|playwright\s+test\b|dotnet\s+test\b)/

// Tools that change nothing a test reads. Every other main-loop call may: a Bash write, an MCP tool, an Agent dispatch
// whose subagent edits out of this module's sight.
const READ_ONLY = new Set(['Read', 'Grep', 'Glob', 'LS', 'NotebookRead', 'WebFetch', 'WebSearch', 'TodoWrite', 'ToolSearch', 'AskUserQuestion', 'Skill'])

const EDIT_TOOLS = new Set(['Write', 'Edit', 'MultiEdit', 'NotebookEdit'])

// A step beside the run that changes nothing: `cd app && npm test` is still a run on unchanged code.
const IDLE_STEP = /^(?:cd|pushd|export|echo|true|clear)\b/

type Outcomes = { changes: number; passed: boolean; failed: boolean }

// Per session: main-loop calls that may have changed the code, and each test command's outcomes since the last of them.
const changes = new Map<string, number>()

const outcomes = new Map<string, Outcomes>()

const normalized = (command: string) => command.trim().replace(/\s+/g, ' ')

// The steps of a Bash command that are neither a test run nor idle: `sed -i … && npm test` fixed the code before running it.
const hasChangingStep = (command: string) =>
  command
    .split(/&&|\|\||;|\n/)
    .map(step => step.trim())
    .some(step => step !== '' && !TEST_COMMAND.test(step) && !IDLE_STEP.test(step))

export function register(on: On) {
  registerSuggestion(on, {
    transition: 'flake-hunt',
    onToolCall: async (host, e, r) => {
      if (r.deny !== undefined || READ_ONLY.has(e.tool)) {
        return null
      }

      const session = await host.sessionId()
      const run = e.tool === 'Bash' && TEST_COMMAND.test(e.command) ? e.command : null
      // An edit tool that errored wrote nothing; a Bash command that errored may have written before it failed.
      const isChange = run !== null ? hasChangingStep(run) : !(EDIT_TOOLS.has(e.tool) && r.isError === true)

      if (isChange) {
        changes.set(session, (changes.get(session) ?? 0) + 1)
      }

      const isInterrupted = typeof r.result === 'object' && r.result !== null && 'interrupted' in r.result && r.result.interrupted === true

      if (run === null || isInterrupted) {
        return null
      }

      const command = normalized(run)
      const key = `${session}|${command}`
      const now = changes.get(session) ?? 0
      const prior = outcomes.get(key)
      const since = prior?.changes === now ? prior : { changes: now, passed: false, failed: false }
      const seen = r.isError === true ? { ...since, failed: true } : { ...since, passed: true }

      outcomes.set(key, seen)

      // Passed and failed with nothing between that could change the code: the code did not change, so the test did.
      return seen.passed && seen.failed ? command : null
    },
    text: () => '/testing:flake-hunt',
  })
}
