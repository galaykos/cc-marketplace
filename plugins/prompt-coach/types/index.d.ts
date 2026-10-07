/**
 * Session-only, and readable by every plugin, so `pass` holds hashes of the texts
 * the person marked to pass, never a prompt, reason or rewrite. `backoffUntil` is epoch
 * milliseconds on the `Date.now()` clock.
 */
export type PromptCoachState = {
  pass: string[]
  escalations: number
  muted: boolean
  backoffUntil: number | null
  failures: number
}

declare module 'claude-code' {
  interface PluginState {
    'prompt-coach': PromptCoachState
  }
}
