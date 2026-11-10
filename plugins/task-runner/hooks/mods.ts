import type { On, PluginOptions } from 'claude-code'

import { registerBoard } from './board'
import { registerFloors } from './floors'

export function register(on: On, options: PluginOptions) {
  registerFloors(on, options)
  registerBoard(on, options)
}
