import type { On, PluginOptions } from 'claude-code'

import { registerCompact } from './compact'
import { registerListing } from './listing'

export function register(on: On, options: PluginOptions) {
  registerListing(on, options)
  registerCompact(on, options)
}
