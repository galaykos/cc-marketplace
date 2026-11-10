import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { activeRun, hostOf, isSupported, switchOn } from './cc-kit'
import { REASONS, STATUSES, applyStatus } from './status-core'

const NAME = 'card_status'

const TOOL = `mcp__task-runner__${NAME}`

const SPEC = {
  name: NAME,
  description:
    "Sets one card's status in the active task-runner run's index, in place of editing the status cell by hand. Refuses a parked status with no reason, a split whose child cards have no row, and a split parent reopened before its children are done.",
  inputSchema: {
    type: 'object',
    properties: {
      card: { type: 'string', description: 'The card number as the index shows it, e.g. "07".' },
      status: { type: 'string', enum: [...STATUSES] },
      reason: {
        type: 'string',
        enum: [...REASONS],
        description:
          'Required when parked. evidence: a real attempt failed. misspec: the card does not match the code. needs-user: a decision only the user holds. split: too big, child cards appended. guard: a refused call with no named fix.',
      },
      detail: { type: 'string', description: 'One line: the failing output, the mismatch, the question or the refusal text; for done, the commit sha.' },
      children: { type: 'array', items: { type: 'string' }, description: 'With reason split: the numbers of the child cards, already appended to the index.' },
    },
    required: ['card', 'status'],
  },
  isDeferred: false,
}

const text = (value: unknown) => (typeof value === 'string' ? value : undefined)

const isOn = async ($: EngineInterface, option: boolean) =>
  isSupported((await $.session.version()).version) && switchOn(await $.env.get('CC_CARD_STATUS'), option)

async function indexPath($: EngineInterface): Promise<string | null> {
  const run = await activeRun(hostOf($))
  const path = run?.index_path

  if (run === null || path === undefined) {
    return null
  }

  return path.startsWith('/') ? path : `${run.root}/${path}`
}

type Listing = { isListed: boolean }

// Listed only while a run with a card index is registered on this branch: no schema in a session that runs no cards.
async function list($: EngineInterface, listing: Listing, option: boolean): Promise<void> {
  const isDue = !listing.isListed && (await isOn($, option).catch(() => false)) && (await indexPath($).catch(() => null)) !== null

  if (!isDue) {
    return
  }

  try {
    await $.tool.register(SPEC)
    listing.isListed = true
  } catch {
    // A tool that cannot be listed changes nothing else: the index is still edited by hand.
  }
}

export function registerStatus(on: On, options: PluginOptions) {
  const option = options.cc_card_status !== false
  const listing: Listing = { isListed: false }

  // Matched on every cwd: hooks/board.ts holds this module's one unmatched session.start hook.
  on('session.start', { cwd: /^/ }, async ($, e, next) => {
    const r = await next(e)

    listing.isListed = false
    await list($, listing, option)

    return r
  }).catch(($, e, next) => next(e))

  // register-run.sh is the one writer of active-run.json, and it runs through the main loop's Bash.
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const r = await next(e)

    if (e.agentId === undefined && e.command.includes('register-run.sh')) {
      await list($, listing, option)
    }

    return r
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: TOOL }, async ($, e) => {
    if (e.agentId !== undefined) {
      return { deny: 'Only the orchestrator writes the card index. Return the status, and the evidence for it, in your report.' }
    }

    const path = await indexPath($)

    if (path === null) {
      return { deny: 'No task-runner run with a card index is registered on this branch.' }
    }

    const input = e as Record<string, unknown>
    const children = Array.isArray(input.children) ? input.children.filter((child): child is string => typeof child === 'string') : undefined

    const index = await $.fs.read(path).catch(() => null)

    if (index === null) {
      return { deny: `The card index cannot be read: ${path}` }
    }

    const outcome = applyStatus(index, {
      card: text(input.card) ?? '',
      status: text(input.status) ?? '',
      reason: text(input.reason),
      detail: text(input.detail),
      children,
    })

    if ('error' in outcome) {
      return { deny: outcome.error }
    }

    const isWritten = await $.fs.write(path, outcome.index).then(
      () => true,
      () => false,
    )

    if (!isWritten) {
      return { deny: `The card index cannot be written: ${path}` }
    }

    return { result: `card ${text(input.card)}: ${outcome.from || '(empty)'} → ${outcome.to}` }
  }).catch(() => ({ deny: 'The card_status tool failed; edit the status cell by hand.' }))
}
