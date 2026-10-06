import type { On, PluginOptions } from 'claude-code'

import { registerBoard } from './board'
import { registerFloors } from './floors'
import { registerSuggest } from './suggest'

export function register(on: On, options: PluginOptions) {
  registerFloors(on, options)
  registerSuggest(on, options)
  registerBoard(on, options)
}
