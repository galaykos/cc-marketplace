import { registerSuggestion } from './cc-kit'

export function register(on, options) {
  registerSuggestion(on, { transition: 'review', text: key => key })
}
