import { isSupported } from './cc-kit'
import { registerRedaction } from './redaction'

export function register(on, options) {
  registerRedaction(on, options)
}
