import { stateRoot } from './cc-kit'

export function registerWatch(on, options) {
  on('turn.complete', async ($, e, next) => next(e))
}
