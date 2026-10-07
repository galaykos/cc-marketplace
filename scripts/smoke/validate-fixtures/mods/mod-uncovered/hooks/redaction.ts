export function registerRedaction(on, options) {
  on('tool.call', async ($, e, next) => next(e))
}
