import type { On, PluginOptions } from 'claude-code'

import { registerCompact } from './compact'

export function register(on: On, options: PluginOptions) {
  registerCompact(on, options)
}
