import type { On, PluginOptions } from 'claude-code'

import { countOutcome, isSupported, switchOn } from './cc-kit'
import { atLeast, decideModel, parseRegistry, rank } from './floors-core'

const REGISTRY = '/skills/delegation-contracts/references/role-floors.md'

// 2.1.292 to 2.1.299 raise agent.spawn for a workflow agent but drop a hook's model for it.
const WORKFLOW_MODEL_FROM = '2.1.300'

export function registerFloors(on: On, options: PluginOptions) {
  let registry: Promise<Map<string, string> | null> | undefined

  // A workflow's agents each reach agent.spawn, so a fan-out of 20 toasted 20 times.
  const toastedRuns = new Set<string>()

  on('agent.spawn', async ($, e, next) => {
    const { version } = await $.session.version()
    const isOn = isSupported(version) && switchOn(await $.env.get('CC_SPAWN_FLOOR'), options.cc_spawn_floor !== false)

    // The host ignores a model rewrite on a resume: the agent keeps the model it started on.
    if (!isOn || e.fork || e.resume || (e.workflow && !atLeast(version, WORKFLOW_MODEL_FROM))) {
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

    const runId = e.workflow?.runId
    const isRaised = rank(model) !== rank(before)

    if (isRaised) {
      void countOutcome($, `floors.raised.${e.subagentType}`)
    }

    if (isRaised && (runId === undefined || !toastedRuns.has(runId))) {
      if (runId !== undefined) {
        toastedRuns.add(runId)
      }

      try {
        $.ui.toast(`${e.subagentType}: ${e.model || 'its pin'} raised to ${model} (role floor ${floor})`)
      } catch {
        // The toast is display only; the raised model stands.
      }
    }

    return next({ ...e, model })
  }).catch(($, e, next) => next(e))
}
