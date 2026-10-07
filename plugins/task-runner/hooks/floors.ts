import type { On, PluginOptions } from 'claude-code'

import { isSupported, switchOn } from './cc-kit'
import { decideModel, parseRegistry, rank } from './floors-core'

const REGISTRY = '/skills/delegation-contracts/references/role-floors.md'

export function registerFloors(on: On, options: PluginOptions) {
  let registry: Promise<Map<string, string> | null> | undefined

  on('agent.spawn', async ($, e, next) => {
    const isOn =
      isSupported((await $.session.version()).version) &&
      switchOn(await $.env.get('CC_SPAWN_FLOOR'), options.cc_spawn_floor !== false)

    if (!isOn || e.fork) {
      return next(e)
    }

    const path = $.plugin.root + REGISTRY

    registry ??= $.fs
      .read(path)
      .then(md => {
        const floors = parseRegistry(md)

        if (floors.size === 0) {
          throw new Error('no registry rows parsed')
        }

        return floors
      })
      .catch((error: unknown) => {
        try {
          $.ui.log(`Subagent model floors are off: ${path}: ${error instanceof Error ? error.message : String(error)}`)
        } catch {
          // A refused log line changes nothing: every spawn already passes through.
        }

        return null
      })

    const floor = (await registry)?.get(e.subagentType)

    if (floor === undefined) {
      return next(e)
    }

    // floors-core treats a null, "" or "inherit" model as one given, which can leave the spawn below its floor.
    const isInherit = e.model?.toLowerCase() === 'inherit'
    const explicit = e.model && !isInherit ? e.model : undefined

    // A parent at the floor's tier needs no raise, and an older id of that family must not override the pin.
    if (explicit === undefined && rank(e.parentModel) === rank(floor)) {
      return next(e)
    }

    const model = decideModel({ explicit, parentModel: e.parentModel, floor })

    if (model === undefined) {
      return next(e)
    }

    // pc_role_floors holds each registry floor equal to the agent's pin, so the floor is what a spawn naming no model runs on.
    const before = explicit ?? (isInherit ? e.parentModel : floor)

    if (rank(model) !== rank(before)) {
      try {
        $.ui.toast(`${e.subagentType}: ${e.model || 'its pin'} raised to ${model} (role floor ${floor})`)
      } catch {
        // The toast is display only; the raised model stands.
      }
    }

    return next({ ...e, model })
  }).catch(($, e, next) => next(e))
}
