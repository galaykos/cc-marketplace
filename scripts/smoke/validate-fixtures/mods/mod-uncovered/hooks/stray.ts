export function registerStray(on, options) {
  on('turn.complete', async ($, e, next) => next(e))
}
