export function registerOrphan(on, options) {
  on('turn.complete', async ($, e, next) => next(e))
}
