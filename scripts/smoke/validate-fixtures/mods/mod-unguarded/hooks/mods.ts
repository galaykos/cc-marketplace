import { isSupported } from './cc-kit'
import { registerWatch } from "./watch"

export function register(on, options) {
  registerWatch(on, options)
}
