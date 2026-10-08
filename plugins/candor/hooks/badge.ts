import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { isSupported, switchOn } from './cc-kit'

const LEVELS = ['lite', 'full', 'ultra', 'wenyan-lite', 'wenyan-full', 'wenyan-ultra']

type Shown = { badge: string; latest: number; isRead: boolean }

// As scripts/level.sh reads the level file: the first word of its first line, within its first 1 KiB.
function firstWord(text: string): string {
  return (text.slice(0, 1024).split('\n')[0] ?? '').split(/[ \t]+/).find(word => word !== '') ?? ''
}

// scripts/statusline.sh's badge: CC_TERSE, then the level file, then cc_terse; a symlinked level file or a value out of vocabulary shows none.
async function badgeOf($: EngineInterface, options: PluginOptions): Promise<string> {
  if (!switchOn(await $.env.get('CC_TERSE_BADGE'), options.cc_terse_badge !== false)) {
    return ''
  }

  const dir = (await $.env.get('CLAUDE_CONFIG_DIR')) || `${(await $.env.get('HOME')) ?? ''}/.claude`
  const path = `${dir}/terse-mode`
  const stat = await $.fs.stat(path).catch(() => null)

  if (stat?.isLink) {
    return ''
  }

  const env = (await $.env.get('CC_TERSE')) ?? ''
  const file = env === '' && stat?.kind === 'file' ? firstWord(await $.fs.read(path).catch(() => '')) : ''
  const level = env || file || (typeof options.cc_terse === 'string' ? options.cc_terse : '')

  return LEVELS.includes(level) ? `[TERSE:${level.toUpperCase()}]` : ''
}

// Only the newest of overlapping refreshes paints: an older one finishing last would bring back a level since switched off.
async function refresh($: EngineInterface, shown: Shown, options: PluginOptions): Promise<void> {
  const mine = ++shown.latest

  if (!isSupported((await $.session.version()).version)) {
    return
  }

  const badge = await badgeOf($, options)

  if (mine !== shown.latest) {
    return
  }

  shown.isRead = true

  if (badge !== shown.badge) {
    shown.badge = badge
    $.ui.invalidate('ui.render')
  }
}

export function register(on: On, options: PluginOptions) {
  const shown: Shown = { badge: '', latest: 0, isRead: false }

  on('session.start', async ($, e, next) => {
    const r = await next(e)

    await refresh($, shown, options)

    return r
  }).catch(($, e, next) => next(e))

  // After the UserPromptSubmit hooks: hooks/mode.sh writes the level file there.
  on('turn.start', async ($, e, next) => {
    const r = await next(e)

    await refresh($, shown, options)

    return r
  }).catch(($, e, next) => next(e))

  on('tool.call', async ($, e, next) => {
    const r = await next(e)

    await refresh($, shown, options)

    return r
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    if (!isSupported((await $.session.version()).version)) {
      return next(e)
    }

    // A /config change reloads the plugin and draws again, but session.start fires again only for a changed module.
    if (!shown.isRead) {
      void refresh($, shown, options)
    }

    if (shown.badge === '') {
      return next(e)
    }

    const tail = e.props.tail ? `${e.props.tail} · ${shown.badge}` : shown.badge

    return next({ ...e, props: { ...e.props, tail } })
  }).catch(($, e, next) => next(e))
}
