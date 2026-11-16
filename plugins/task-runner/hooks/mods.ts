import type { On, PluginOptions } from 'claude-code'

import { registerFloors } from './floors'

export function register(on: On, options: PluginOptions) {
  registerFloors(on, options)
}
