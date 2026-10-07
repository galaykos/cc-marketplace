import type { Args, On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

const FABLE = 'claude-fable-5-1'
const SONNET = 'claude-sonnet-5-5'
const OLD_OPUS = 'claude-opus-4-1'

// The module's read of role-floors.md is answered here: a test has no file system.
const REGISTRY = ['# Role-tier floors', '', '```', 'code-review:code-reviewer   opus', 'ultra-deep-research:verifier   sonnet', '```', ''].join('\n')

type Live = {
  version?: string | null
  env?: Record<string, string>
  registry?: string | null
}

function seat(on: On, live: Live = {}) {
  const world = { models: [] as (string | undefined)[], reads: [] as string[], toasts: [] as string[], logs: [] as string[] }

  mock.env(on, live.env ?? {})

  if (live.version !== null) {
    on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  }

  on('fs.read', ($, e) => {
    world.reads.push(e.path)

    if (live.registry === null) {
      throw new Error(`ENOENT: ${e.path}`)
    }

    return { value: live.registry ?? REGISTRY }
  })

  on('ui.toast', ($, e) => {
    world.toasts.push(e.text)

    return { value: undefined }
  })

  on('ui.log', ($, e) => {
    world.logs.push(e.text)

    return { value: undefined }
  })

  on('agent.spawn', ($, e) => {
    world.models.push(e.model)

    return { model: e.model ?? 'the agent pin', agentId: `a${world.models.length}` }
  })

  return world
}

function spawnOf(subagentType: string, parentModel: string, more: Partial<Args<'agent.spawn'>> = {}): Args<'agent.spawn'> {
  return {
    tool_use_id: 'toolu_1',
    prompt: 'Review the diff.',
    description: 'review',
    subagentType,
    provider: { plugin: subagentType.split(':')[0], tier: 'user' },
    parentModel,
    background: false,
    fork: false,
    ...more,
  }
}

describe('floors', () => {
  test('raises a no-model dispatch to the parent model', async ($, on) => {
    const world = seat(on)

    const r = await $.agent.spawn(spawnOf('code-review:code-reviewer', FABLE))

    expect(world.models).toEqual([FABLE])
    expect(r.model).toBe(FABLE)
    expect(world.toasts).toEqual([`code-review:code-reviewer: its pin raised to ${FABLE} (role floor opus)`])
  })

  test('leaves the pin standing under a parent at the floor tier', async ($, on) => {
    const world = seat(on)

    await $.agent.spawn(spawnOf('code-review:code-reviewer', OLD_OPUS))
    await $.agent.spawn(spawnOf('code-review:code-reviewer', OLD_OPUS, { model: 'inherit' }))

    expect(world.models).toEqual([undefined, 'inherit'])
    expect(world.toasts).toEqual([])
  })

  test('raises a no-model dispatch from a session below the floor to the floor, without a toast', async ($, on) => {
    const world = seat(on)

    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET))

    expect(world.models).toEqual(['opus'])
    expect(world.toasts, 'the floor equals the agent pin, so nothing visible changed').toEqual([])
  })

  test('raises an explicit model below the floor, whatever the parent', async ($, on) => {
    const world = seat(on)

    await $.agent.spawn(spawnOf('code-review:code-reviewer', FABLE, { model: 'haiku' }))
    await $.agent.spawn(spawnOf('code-review:code-reviewer', 'an unreadable parent', { model: 'haiku' }))

    expect(world.models).toEqual(['opus', 'opus'])
    expect(world.toasts).toEqual([
      'code-review:code-reviewer: haiku raised to opus (role floor opus)',
      'code-review:code-reviewer: haiku raised to opus (role floor opus)',
    ])
  })

  test('reads an inherit, empty or null model as none given', async ($, on) => {
    const world = seat(on)

    for (const parent of [SONNET, FABLE]) {
      for (const model of ['inherit', 'Inherit', '', null]) {
        await $.agent.spawn(spawnOf('code-review:code-reviewer', parent, { model } as Partial<Args<'agent.spawn'>>))
      }
    }

    expect(world.models).toEqual(['opus', 'opus', 'opus', 'opus', FABLE, FABLE, FABLE, FABLE])
  })

  test('toasts an inherit dispatch raised to the floor', async ($, on) => {
    const world = seat(on)

    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET, { model: 'inherit' }))

    expect(world.models).toEqual(['opus'])
    expect(world.toasts).toEqual(['code-review:code-reviewer: inherit raised to opus (role floor opus)'])
  })

  test('keeps an explicit model above the floor', async ($, on) => {
    const world = seat(on)

    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET, { model: 'fable' }))
    await $.agent.spawn(spawnOf('ultra-deep-research:verifier', FABLE, { model: 'claude-sonnet-5-5' }))

    expect(world.models, 'above, then at, the floor').toEqual(['fable', 'claude-sonnet-5-5'])
    expect(world.toasts).toEqual([])
  })

  test('leaves a fork untouched', async ($, on) => {
    const world = seat(on)

    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET, { fork: true }))

    expect(world.models).toEqual([undefined])
    expect(world.reads, 'a fork never reads the registry').toEqual([])
  })

  test('leaves an agent outside the registry untouched', async ($, on) => {
    const world = seat(on)

    await $.agent.spawn(spawnOf('general-purpose', FABLE))
    await $.agent.spawn(spawnOf('brain:indexer', FABLE, { model: 'haiku' }))

    expect(world.models).toEqual([undefined, 'haiku'])
    expect(world.toasts).toEqual([])
  })

  test('leaves a model of unknown family untouched', async ($, on) => {
    const world = seat(on)

    await $.agent.spawn(spawnOf('code-review:code-reviewer', 'gpt-5'))
    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET, { model: 'gpt-5' }))

    expect(world.models).toEqual([undefined, 'gpt-5'])
    expect(world.toasts).toEqual([])
  })

  test('changes nothing under CC_SPAWN_FLOOR=off', async ($, on) => {
    const world = seat(on, { env: { CC_SPAWN_FLOOR: 'off' } })

    await $.agent.spawn(spawnOf('code-review:code-reviewer', FABLE))
    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET, { model: 'haiku' }))

    expect(world.models).toEqual([undefined, 'haiku'])
    expect(world.reads).toEqual([])
  })

  test('changes nothing with cc_spawn_floor off in /config', { options: { cc_spawn_floor: false } }, async ($, on) => {
    const world = seat(on)

    await $.agent.spawn(spawnOf('code-review:code-reviewer', FABLE))

    expect(world.models).toEqual([undefined])
  })

  test('lets CC_SPAWN_FLOOR=on override cc_spawn_floor off in /config', { options: { cc_spawn_floor: false } }, async ($, on) => {
    const world = seat(on, { env: { CC_SPAWN_FLOOR: 'on' } })

    await $.agent.spawn(spawnOf('code-review:code-reviewer', FABLE))

    expect(world.models).toEqual([FABLE])
  })

  test('reads role-floors.md from the plugin once', async ($, on) => {
    const world = seat(on)

    await $.agent.spawn(spawnOf('code-review:code-reviewer', FABLE))
    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET))

    expect(world.reads).toEqual([
      expect.stringMatching(/\/task-runner\/skills\/delegation-contracts\/references\/role-floors\.md$/),
    ])
  })

  test('logs an unreadable registry once and passes every spawn through', async ($, on) => {
    const world = seat(on, { registry: null })

    await $.agent.spawn(spawnOf('code-review:code-reviewer', FABLE))
    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET, { model: 'haiku' }))

    expect(world.models).toEqual([undefined, 'haiku'])
    expect(world.logs).toEqual([expect.stringContaining('Subagent model floors are off')])
    expect(world.logs[0]).toEqual(expect.stringContaining('role-floors.md'))
  })

  test('logs a registry with no parseable rows once and passes every spawn through', async ($, on) => {
    const world = seat(on, { registry: REGISTRY.replace('verifier   sonnet', 'verifier') })

    await $.agent.spawn(spawnOf('code-review:code-reviewer', FABLE))
    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET, { model: 'haiku' }))

    expect(world.models).toEqual([undefined, 'haiku'])
    expect(world.logs).toEqual([expect.stringContaining('role-floors.md: no registry rows parsed')])
  })

  test('changes nothing below CLI 2.1.291', async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    await $.agent.spawn(spawnOf('code-review:code-reviewer', FABLE))
    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET, { model: 'haiku' }))

    expect(world.models).toEqual([undefined, 'haiku'])
    expect(world.reads, 'the registry is never read').toEqual([])
  })

  test('passes the spawn through when the hook fails', async ($, on) => {
    const world = seat(on, { version: null })

    await $.agent.spawn(spawnOf('code-review:code-reviewer', SONNET))

    expect(world.models).toEqual([undefined])
  })
})
