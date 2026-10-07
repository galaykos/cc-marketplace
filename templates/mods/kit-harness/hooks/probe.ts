import type { On, PluginOptions } from 'claude-code'

import { registerSuggestion } from './cc-kit'
import type { Host } from './cc-kit'

async function markerAt(host: Host): Promise<string | null> {
  const marker = `${await host.cwd()}/PROBE.md`

  return host.stat(marker).then(() => marker, () => null)
}

export function register(on: On, options: PluginOptions) {
  if (options.probe_board === true) {
    on('tool.call', async ($, e, next) => {
      const r = await next(e)

      await $.store.set('board', e.tool)

      return r
    }).catch(($, e, next) => next(e))
  }

  registerSuggestion(on, {
    transition: 'probe',
    ...(options.probe_tool_key !== false && {
      tools: 'Write',
      onToolCall: async (host, e) => {
        const path = 'file_path' in e ? e.file_path : undefined

        return typeof path === 'string' && path.endsWith('.md') ? path : null
      },
    }),
    ...(options.probe_turn_end === true && { atTurnEnd: markerAt }),
    stillDue: (host, key) => host.stat(key).then(() => true, () => false),
    text: key => `/probe ${key}`,
  })
}
