export async function liveSentinel(host) {
  return host.read(`${await host.cwd()}/.claude/cc-phase.json`)
}

export function registerSuggestion(on, spec) {
  on('turn.complete', async ($, e, next) => next(e))
}
