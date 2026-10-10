import type { Args, FsStat, On, RenderSurface, SessionMessage } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const NOW = Date.UTC(2026, 9, 7, 12)
const ROOT = '/work'
const RUN = '/work/.claude/task-runner/active-run.json'
const INDEX = '/work/taskmaster-docs/tasks/login/00-INDEX.md'
const SPEC = '/work/taskmaster-docs/specs/login.md'
const SENTINEL = '/work/.claude/cc-phase.json'

const ZERO = { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }

const PROMPT = 'fix the bug we talked about'

const INDEX_MD = [
  'Spec: taskmaster-docs/specs/login.md',
  '',
  '| card | title | depends-on | agent | parallel group | status |',
  '|---|---|---|---|---|---|',
  '| 01 | Build the login form | none | generic | A | done (abc1234) |',
  '| 02 | Wire the session cookie | 01 | backend | B | in_progress (delegated) |',
  '',
  '### Milestone M1 — login',
  'Files: src/auth.ts, src/login.tsx',
  'Cards: 01, 02',
  '',
].join('\n')

const SPEC_MD = [
  '# Login',
  '',
  '## Goal',
  '',
  'People sign in with email and stay signed in.',
  '',
  '## Decisions',
  '',
  '| # | Decision | Source |',
  '|---|---|---|',
  '| D1 | Sessions live in an httpOnly cookie, never localStorage. | user |',
  '',
].join('\n')

const RUN_HERE = JSON.stringify({ slug: 'login', branch: 'feat/login', index_path: 'taskmaster-docs/tasks/login/00-INDEX.md' })
const RUN_ELSEWHERE = JSON.stringify({ slug: 'login', branch: 'master', index_path: 'taskmaster-docs/tasks/login/00-INDEX.md' })
const IN_RUN = { [RUN]: RUN_HERE, [INDEX]: INDEX_MD, [SPEC]: SPEC_MD }

const TURNS: SessionMessage[] = [
  { role: 'user', text: 'Keep the session in an httpOnly cookie.', toolUses: [] },
  { role: 'assistant', text: '', toolUses: [] },
  { role: 'user', text: '  ', toolUses: [] },
  { role: 'assistant', text: 'Done: the session cookie is httpOnly now.', toolUses: [] },
]

type Reply = { text: string; afterMs?: number } | { fail: 'api-error' | 'aborted' | 'empty-reply' } | { refuse: string } | { hang: true }

type Call = { model: string; system: string; prompt: string; maxTokens?: number; effort?: string; timeoutMs?: number }

type Live = { version?: string; env?: Record<string, string>; files?: Record<string, string>; messages?: SessionMessage[] }

const answer = (text: string, afterMs?: number): Reply => ({ text, afterMs })

const verdict = (kind: string, confidence = 'high', decision?: string) =>
  JSON.stringify({
    verdict: kind === 'unclear' ? 'unclear' : 'conflict',
    kind,
    ...(decision !== undefined && { decision }),
    confidence,
    reason: 'Nothing here says which bug.',
    rewrite: 'Fix the null check in src/auth.ts login().',
  })

const UNCLEAR = verdict('unclear')

const dropOf = (kind: string) => ({ drop: `prompt-coach held this prompt (${kind}); set CC_PROMPT_COACH=off to stop` })

const UNMASKED =
  'prompt-coach runs before secret-scanning, so a secret typed into a prompt reaches the judge before it is masked. CC_PROMPT_COACH=off turns the coach off.'

const START = { cwd: ROOT, surface: 'terminal', isInteractive: true } as const

// prepend sits outside the coach's user tier and append beneath it, as list order places an installed plugin either way.
const secretScanning = (tier: 'prepend' | 'append') => ({
  name: 'secret-scanning',
  tier,
  register: (on: On) => {
    on('session.start', ($, e, next) => next(e))
  },
})

const composer = (text: string, more: Partial<Args<'prompt.submit'>> = {}): Args<'prompt.submit'> => ({
  text,
  wait: false,
  origin: { kind: 'composer' },
  ...more,
})

function seat(on: On, live: Live = {}) {
  const world = {
    clock: mock.clock(on, { now: NOW }),
    version: live.version ?? '2.1.291',
    versionDelayMs: 0,
    env: { ...live.env } as Record<string, string | undefined>,
    surfaces: ['terminal'] as RenderSurface[],
    files: new Map(Object.entries(live.files ?? {})),
    stats: new Map<string, Partial<FsStat>>(),
    lsFilesExit: 1,
    gitDelayMs: 0,
    replies: { haiku: [answer('clear')], standby: [answer(UNCLEAR)] } as Record<'haiku' | 'standby', Reply[]>,
    calls: [] as Call[],
    aborted: [] as string[],
    submitted: [] as Args<'prompt.submit'>[],
    toasts: [] as string[],
    fills: [] as string[],
  }

  on('session.version', async () => {
    if (world.versionDelayMs > 0) {
      await world.clock.sleep(world.versionDelayMs)
    }

    return { value: { version: world.version } }
  })

  on('env.get', ($, e) => ({ value: world.env[e.name] }))
  on('session.cwd', () => ({ value: ROOT }))
  on('session.surfaces', () => ({ value: world.surfaces }))
  on('session.messages', () => ({ value: live.messages ?? [] }))
  on('session.start', ($, e) => ({ cwd: e.cwd }))

  on('process.run', async ($, e) => {
    if (world.gitDelayMs > 0) {
      await world.clock.sleep(world.gitDelayMs)
    }

    const answers: Record<string, [number, string]> = {
      'git rev-parse --show-cdup': [0, '\n'],
      'git rev-parse --abbrev-ref HEAD': [0, 'feat/login\n'],
      'git ls-files --error-unmatch -- .claude/task-runner/active-run.json': [world.lsFilesExit, ''],
    }
    const ran = answers[e.argv.join(' ')]

    return ran === undefined
      ? { deny: `unexpected command: ${e.argv.join(' ')}` }
      : { value: { exitCode: ran[0], stdout: ran[1], stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  on('fs.stat', ($, e) => {
    const text = world.files.get(e.path)
    const isDir = e.path === ROOT

    if (text === undefined && !isDir) {
      return { deny: `ENOENT: ${e.path}` }
    }

    const stat: FsStat = { kind: isDir ? 'dir' : 'file', size: text?.length ?? 0, mtimeMs: NOW, isLink: false, ...(e.resolve && { realPath: e.path }) }

    return { value: { ...stat, ...world.stats.get(e.path) } }
  })

  on('fs.read', ($, e) => {
    const text = world.files.get(e.path)

    return text === undefined ? { deny: `ENOENT: ${e.path}` } : { value: text }
  })

  on('ui.toast', ($, e) => {
    world.toasts.push(e.text)

    return { value: undefined }
  })

  on('prompt.fill', ($, e) => {
    world.fills.push(e.text)

    return { isFilled: true }
  })

  on('prompt.submit', ($, e) => {
    world.submitted.push(e)

    return { text: e.text }
  })

  // The engine's own band beneath the coach's, and every blit taken: a drop needs the band to show.
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => $.ui.resolve(e).Box({}))
  on('ui.blit', () => ({ value: {} }))

  on('model.complete', async ($, e, next) => {
    const stage = e.model === 'haiku' ? 'haiku' : 'standby'
    const asked = world.calls.filter(call => (call.model === 'haiku') === (stage === 'haiku')).length
    const replies = world.replies[stage]
    const reply = replies[asked % replies.length] ?? answer('clear')

    world.calls.push({ model: e.model, system: e.system ?? '', prompt: e.prompt, maxTokens: e.maxTokens, effort: e.effort, timeoutMs: e.timeoutMs })

    if ('refuse' in reply) {
      return { deny: reply.refuse }
    }

    if ('hang' in reply) {
      await new Promise<void>(resolve => next.signal.addEventListener('abort', () => resolve(), { once: true }))
      world.aborted.push(e.model)

      return { value: { isAnswered: false, reason: 'aborted', usage: ZERO } }
    }

    // `aborted` answered while the coach's own signal stands is the dispatch cut beneath it: Esc, not the deadline.
    if ('fail' in reply) {
      return {
        value:
          reply.fail === 'api-error'
            ? { isAnswered: false, reason: 'api-error', status: 529, error: 'overloaded', usage: ZERO }
            : { isAnswered: false, reason: reply.fail, usage: ZERO },
      }
    }

    if (reply.afterMs !== undefined) {
      await world.clock.sleep(reply.afterMs)
    } else {
      // A live judge takes long enough for the band to draw; the kit draws it once the clock settles.
      await world.clock.settle()
    }

    return { value: { isAnswered: true, text: reply.text, usage: ZERO } }
  })

  return world
}

const BAND = { hasSurvey: false, isWorking: false, maxRows: 17, bodyColumns: 75, scroll: { offset: 0, bodyRows: 16 }, view: {} } as const

const mount = ($: Engine) => $.ui.mount({ plugin: 'prompt-coach', surface: 'terminal', component: 'AbovePrompt', requestId: 'above-prompt', props: BAND })

// Starts the submit, moves the clock past the deadline, then reads its result: how a hanging judge is answered.
async function pastDeadline($: Engine, world: ReturnType<typeof seat>, prompt = composer(PROMPT)) {
  const submitted = $.prompt.submit(prompt)

  await world.clock.advance(5000)

  return submitted
}

describe('coach', () => {
  test('passes a clear prompt untouched', async ($, on) => {
    const world = seat(on)

    const r = await $.prompt.submit(composer(PROMPT))

    expect(r).toEqual({ text: PROMPT })
    expect(world.submitted.map(e => e.text)).toEqual([PROMPT])
    expect(world.calls.map(c => [c.model, c.maxTokens, c.effort])).toEqual([['haiku', 8, 'low']])
  })

  test('drops a confidently unclear prompt and leaves the box empty', async ($, on) => {
    const world = seat(on)

    await mount($)

    world.replies.haiku = [answer('unclear')]

    const r = await $.prompt.submit(composer(PROMPT))

    expect(r).toEqual(dropOf('unclear'))
    expect(world.submitted, 'nothing entered the session').toEqual([])
    expect(world.fills, 'the coach never refills the box').toEqual([])
    expect(world.calls.map(c => [c.model, c.maxTokens, c.effort])).toEqual([
      ['haiku', 8, 'low'],
      ['sonnet', 400, 'low'],
    ])
  })

  test('names off-card only while a run is active', async ($, on) => {
    const world = seat(on, { files: IN_RUN })

    await mount($)

    world.replies = { haiku: [answer('conflict')], standby: [answer(verdict('off-card'))] }

    const offered = () => world.calls.splice(0).map(c => [c.model, c.system.includes('off-card'), c.prompt.includes('<cards>')])

    expect(await $.prompt.submit(composer(PROMPT))).toEqual(dropOf('off-card'))
    expect(world.calls[0]?.prompt).toContain('<cards>\n02 Wire the session cookie\nfiles: src/auth.ts, src/login.tsx\n</cards>')
    expect(offered()).toEqual([
      ['haiku', true, true],
      ['sonnet', true, true],
    ])

    world.files.delete(INDEX)

    expect(await $.prompt.submit(composer(PROMPT)), 'the run index cannot be read').toEqual({ text: PROMPT })
    expect(offered()).toEqual([
      ['haiku', false, false],
      ['sonnet', false, false],
    ])

    world.files.set(INDEX, INDEX_MD)
    world.files.set(RUN, RUN_ELSEWHERE)

    expect(await $.prompt.submit(composer(PROMPT)), 'the run is on another branch').toEqual({ text: PROMPT })
    expect(offered()).toEqual([
      ['haiku', false, false],
      ['sonnet', false, false],
    ])
  })

  test('passes on timeout, error, blocked model and malformed output', async ($, on) => {
    const world = seat(on)

    await mount($)

    // Each malformed answer follows two failures: counted as a third, the case after it would be skipped by the back-off.
    const cases: [string, Reply, Reply][] = [
      ['the standby runs past the deadline', answer('unclear'), { hang: true }],
      ['haiku answers an API error', { fail: 'api-error' }, answer(UNCLEAR)],
      ['the standby answers no text', answer('unclear'), { fail: 'empty-reply' }],
      ['the organization blocks haiku', { refuse: 'haiku is not on the model allowlist' }, answer(UNCLEAR)],
      ['the standby answers an API error', answer('unclear'), { fail: 'api-error' }],
      ['the standby answers prose', answer('unclear'), answer('This prompt is unclear: which bug?')],
      ['haiku runs past the deadline', { hang: true }, answer(UNCLEAR)],
    ]

    for (const [why, haiku, standby] of cases) {
      const before = world.calls.length

      world.replies = { haiku: [haiku], standby: [standby] }

      expect(await pastDeadline($, world), why).toEqual({ text: PROMPT })
      expect(world.calls.length, `${why}: judged, not skipped`).toBeGreaterThan(before)
    }

    expect(world.aborted).toEqual(['sonnet', 'haiku'])
    expect(world.submitted.length).toBe(cases.length)
    expect(world.toasts.filter(toast => toast.startsWith('Flagged')), 'passed as not flagged, with the band up').toEqual([])
  })

  test('skips ineligible prompts without a model call', async ($, on) => {
    const world = seat(on)
    const named = 'rename the parse helper in src/utils.ts'

    await mount($)

    world.replies.haiku = [answer('unclear')]

    const prompts = [
      composer('/review the whole auth module please'),
      composer('!ls -la the src directory tree'),
      composer('# always use pnpm in this repository'),
      composer(named, { attachments: [{ type: 'image', mediaType: 'image/png' }] }),
      composer('fix it'),
      composer(named, { origin: { kind: 'bridge' } }),
      composer(named, { origin: { kind: 'sdk' } }),
    ]

    for (const prompt of prompts) {
      expect(await $.prompt.submit(prompt)).toEqual({ text: prompt.text })
    }

    expect(world.calls).toEqual([])

    expect(await $.prompt.submit(composer(named)), 'the same text from the composer is judged').toEqual(dropOf('unclear'))
  })

  const flagTwelveTimes = async ($: Engine, world: ReturnType<typeof seat>) => {
    world.replies = { haiku: [answer('unclear')], standby: [answer(UNCLEAR), { fail: 'api-error' }] }

    const results: unknown[] = []

    for (let i = 0; i < 12; i += 1) {
      results.push(await $.prompt.submit(composer(PROMPT)))
    }

    return results
  }

  test('stops escalating after the cap', async ($, on) => {
    const world = seat(on)

    await mount($)

    const results = await flagTwelveTimes($, world)

    expect(world.calls.filter(c => c.model === 'haiku').length).toBe(12)
    expect(world.calls.filter(c => c.model === 'sonnet').length, 'failed escalations count toward the cap').toBe(10)
    expect(results.filter(r => JSON.stringify(r) === JSON.stringify(dropOf('unclear'))).length).toBe(5)
    expect(results.slice(10), 'a flag past the cap is not held').toEqual([{ text: PROMPT }, { text: PROMPT }])
  })

  test('backs off after three failures', async ($, on) => {
    const world = seat(on)

    world.replies = { haiku: [{ fail: 'api-error' }, answer('unclear'), { refuse: 'haiku is not on the model allowlist' }], standby: [{ hang: true }] }

    expect(await $.prompt.submit(composer(PROMPT))).toEqual({ text: PROMPT })
    expect(await pastDeadline($, world)).toEqual({ text: PROMPT })
    expect(await $.prompt.submit(composer(PROMPT))).toEqual({ text: PROMPT })
    expect(await $.prompt.submit(composer(PROMPT))).toEqual({ text: PROMPT })

    expect(world.calls.map(c => c.model), 'a haiku error, a standby timeout, a refused haiku, then no call').toEqual(['haiku', 'haiku', 'sonnet', 'haiku'])

    await world.clock.advance(10 * 60_000 - 1)
    await $.prompt.submit(composer(PROMPT))

    expect(world.calls.length, 'still backing off a millisecond early').toBe(4)

    await world.clock.advance(1)
    await $.prompt.submit(composer(PROMPT))

    expect(world.calls.length, 'judging again after 10 minutes').toBe(5)
  })

  test('passes everything below the floor or when switched off', async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    await mount($)

    world.replies.haiku = [answer('unclear')]

    expect(await $.prompt.submit(composer(PROMPT)), 'below the floor').toEqual({ text: PROMPT })

    world.version = '2.1.291'
    world.env.CC_PROMPT_COACH = 'off'

    expect(await $.prompt.submit(composer(PROMPT)), 'CC_PROMPT_COACH=off').toEqual({ text: PROMPT })
    expect(world.calls).toEqual([])

    world.env.CC_PROMPT_COACH = undefined

    expect(await $.prompt.submit(composer(PROMPT)), 'on at the floor').toEqual(dropOf('unclear'))
  })

  test('passes every prompt untouched off the terminal, the desktop included', async ($, on) => {
    const world = seat(on)

    await mount($)

    world.replies.haiku = [answer('unclear')]

    for (const surfaces of [['desktop'], ['terminal', 'desktop'], ['vscode']] as RenderSurface[][]) {
      world.surfaces = surfaces

      expect(await $.prompt.submit(composer(PROMPT)), surfaces.join(' and ')).toEqual({ text: PROMPT })
    }

    expect(world.calls).toEqual([])

    world.surfaces = ['terminal', 'mobile']

    expect(await $.prompt.submit(composer(PROMPT)), 'a phone beside the terminal').toEqual(dropOf('unclear'))
  })

  test('uses opus when cc_coach_model is opus', { options: { cc_coach_model: 'opus' } }, async ($, on) => {
    const world = seat(on)

    await mount($)

    world.replies.haiku = [answer('unclear')]

    expect(await $.prompt.submit(composer(PROMPT))).toEqual(dropOf('unclear'))

    world.env.CC_COACH_MODEL = 'sonnet'
    await $.prompt.submit(composer(PROMPT))

    expect(world.calls.map(c => c.model), 'CC_COACH_MODEL beats /config').toEqual(['haiku', 'opus', 'haiku', 'sonnet'])
  })

  test('judges under a live build sentinel', async ($, on) => {
    const world = seat(on, { files: { ...IN_RUN, [SENTINEL]: JSON.stringify({ phase: 'build', owner: 'task-runner:run' }) } })

    await mount($)

    world.replies.haiku = [answer('unclear')]

    expect(await $.prompt.submit(composer(PROMPT))).toEqual(dropOf('unclear'))
    expect(world.calls.map(c => c.model)).toEqual(['haiku', 'sonnet'])
  })

  test('a passed prompt reaches next unchanged', async ($, on) => {
    const world = seat(on)
    const e = composer(PROMPT, { wait: true, turnId: 'turn-1', context: ['context another plugin attached'] })

    world.replies = { haiku: [answer('unclear')], standby: [answer(verdict('unclear', 'low'))] }
    await mount($)

    const r = await $.prompt.submit(e)

    expect(world.calls.length, 'judged, and the standby was not confident').toBe(2)
    expect(world.submitted).toEqual([e])
    expect(r).toEqual({ text: PROMPT })
    expect(world.toasts, 'passed as not confident, with the band up').toEqual([])
  })

  test('names reopens and contradicts', async ($, on) => {
    const world = seat(on, { files: IN_RUN, messages: TURNS })

    await mount($)

    world.replies = { haiku: [answer('conflict')], standby: [answer(verdict('reopens', 'high', 'D1')), answer(verdict('contradicts'))] }

    expect(await $.prompt.submit(composer(PROMPT))).toEqual(dropOf('reopens'))
    expect(world.calls[1]?.system).toContain('- reopens:')
    expect(world.calls[1]?.prompt).toContain(
      '<spec>\nGoal: People sign in with email and stay signed in.\nD1 Sessions live in an httpOnly cookie, never localStorage.\n</spec>',
    )

    expect(await $.prompt.submit(composer(PROMPT))).toEqual(dropOf('contradicts'))
    expect(world.calls[3]?.prompt, 'only text turns reach the judge').toContain(
      '<turns>\nuser: Keep the session in an httpOnly cookie.\nassistant: Done: the session cookie is httpOnly now.\n</turns>',
    )

    world.files.delete(RUN)
    world.replies.standby = [answer(verdict('reopens', 'high', 'D1'))]

    expect(await $.prompt.submit(composer(PROMPT)), 'reopens with no run on this branch').toEqual({ text: PROMPT })
  })

  test('holds off-card only with a card in progress, and reopens only for a decision its spec lists', async ($, on) => {
    const world = seat(on, { files: { ...IN_RUN, [INDEX]: INDEX_MD.replace('in_progress (delegated)', 'done (def5678)') } })

    world.replies = { haiku: [answer('conflict')], standby: [answer(verdict('off-card'))] }
    await mount($)

    expect(await $.prompt.submit(composer(PROMPT)), 'off-card with no card in progress').toEqual({ text: PROMPT })
    expect(world.calls.map(c => [c.system.includes('off-card'), c.system.includes('- reopens:')]), 'nor is off-card offered').toEqual([
      [false, true],
      [false, true],
    ])

    world.replies.standby = [answer(verdict('reopens', 'high', 'D1'))]
    world.files.set(INDEX, INDEX_MD.replace('Spec: taskmaster-docs/specs/login.md', ''))

    expect(await $.prompt.submit(composer(PROMPT)), 'reopens from an index naming no spec').toEqual({ text: PROMPT })
    expect(world.calls.slice(2).map(c => [c.system.includes('off-card'), c.system.includes('- reopens:')]), 'nor is reopens offered').toEqual([
      [true, false],
      [true, false],
    ])

    world.files.set(INDEX, INDEX_MD)
    world.files.delete(SPEC)

    expect(await $.prompt.submit(composer(PROMPT)), 'reopens with the spec unreadable').toEqual({ text: PROMPT })

    world.files.set(SPEC, SPEC_MD)
    world.replies.standby = [answer(verdict('reopens', 'high', 'D7'))]

    expect(await $.prompt.submit(composer(PROMPT)), 'reopens a decision the spec does not list').toEqual({ text: PROMPT })
    expect(world.calls.filter(c => c.model === 'sonnet').length, 'every one reached the standby').toBe(4)
    expect(world.toasts, 'passed as not offered, with the band up').toEqual([])
  })

  test('ignores the run of a committed active-run.json', async ($, on) => {
    const world = seat(on, { files: IN_RUN })

    await mount($)

    world.replies = { haiku: [answer('conflict')], standby: [answer(verdict('off-card'))] }

    for (const [exit, why] of [[0, 'tracked'], [128, 'git cannot tell']] as const) {
      world.lsFilesExit = exit

      expect(await $.prompt.submit(composer(PROMPT)), why).toEqual({ text: PROMPT })
      expect(world.calls.splice(0).map(c => c.prompt.includes('<cards>') || c.prompt.includes('<spec>')), why).toEqual([false, false])
    }

    world.lsFilesExit = 1

    expect(await $.prompt.submit(composer(PROMPT)), 'the same run, untracked').toEqual(dropOf('off-card'))
  })

  test('reads run context only from a small regular file under the state root', async ($, on) => {
    const world = seat(on, { files: IN_RUN })
    const cardsSent = async () => {
      world.calls.length = 0
      await $.prompt.submit(composer(PROMPT))

      return [world.calls[0]?.prompt.includes('<cards>'), world.calls[0]?.prompt.includes('<spec>')]
    }

    world.replies.haiku = [answer('clear')]

    world.stats.set(INDEX, { size: 256 * 1024 })
    expect(await cardsSent(), 'an index of 256 KiB').toEqual([true, true])

    world.stats.set(INDEX, { size: 256 * 1024 + 1 })
    expect(await cardsSent(), 'an index one byte over').toEqual([false, false])

    world.files.set('/home/someone/.ssh/00-INDEX.md', INDEX_MD)
    world.files.set('/etc/login.md', SPEC_MD)
    world.stats.set(INDEX, { realPath: '/home/someone/.ssh/00-INDEX.md' })
    expect(await cardsSent(), 'an index linked outside the state root').toEqual([false, false])

    world.stats.set(INDEX, { kind: 'other' })
    expect(await cardsSent(), 'an index that is not a regular file').toEqual([false, false])

    world.stats.delete(INDEX)
    world.stats.set(SPEC, { realPath: '/etc/login.md' })
    expect(await cardsSent(), 'a spec linked outside the state root').toEqual([true, false])

    world.stats.set(ROOT, { realPath: '/mnt/work' })
    world.stats.set(INDEX, { realPath: '/mnt/work/taskmaster-docs/tasks/login/00-INDEX.md' })
    world.stats.set(SPEC, { realPath: '/mnt/work/taskmaster-docs/specs/login.md' })
    world.files.set('/mnt/work/taskmaster-docs/tasks/login/00-INDEX.md', INDEX_MD)
    world.files.set('/mnt/work/taskmaster-docs/specs/login.md', SPEC_MD)
    expect(await cardsSent(), 'a state root reached through a link').toEqual([true, true])
  })

  test('a clear first pass makes no standby call', async ($, on) => {
    const world = seat(on)

    world.replies = { haiku: [answer('clear')], standby: [answer(UNCLEAR)] }

    expect(await $.prompt.submit(composer(PROMPT))).toEqual({ text: PROMPT })
    expect(world.calls.map(c => c.model)).toEqual(['haiku'])
  })

  test('aborts calls still running at the deadline', async ($, on) => {
    const world = seat(on)

    world.replies = { haiku: [answer('unclear', 1200)], standby: [{ hang: true }] }

    const submitted = $.prompt.submit(composer(PROMPT))

    await world.clock.advance(1200)

    expect(world.calls.map(c => [c.model, c.timeoutMs]), 'each call gets what is left of 5 s').toEqual([
      ['haiku', 5000],
      ['sonnet', 3800],
    ])
    expect(world.aborted).toEqual([])

    await world.clock.advance(3800)

    expect(await submitted).toEqual({ text: PROMPT })
    expect(world.aborted).toEqual(['sonnet'])
  })

  test('a deadline timer a hook refuses still lets the prompt through', async ($, on) => {
    // Registered above the seat's, so they answer first: the timer is refused, and the run is read after it ended the judgment.
    on('clock.sleep', { ms: 5000 }, () => ({ deny: 'timers are off here' }))
    on('env.get', { name: 'CC_COACH_SENSITIVITY' }, async () => {
      await world.clock.sleep(1)

      return { value: undefined }
    })

    const world = seat(on)

    world.gitDelayMs = 60_000

    for (let i = 0; i < 3; i += 1) {
      const held = $.prompt.submit(composer(PROMPT))

      await world.clock.advance(1)

      expect(await held).toEqual({ text: PROMPT })
    }

    expect(world.calls, 'the stalled read was not waited for').toEqual([])
    expect(world.toasts, 'each ended as a judgment past the deadline').toEqual([
      '3 judgments failed in a row (last: the run and recent turns took over 5 s to read); prompts go through unjudged for 10 minutes.',
    ])
  })

  test('a context read past the deadline passes at 5 s and counts as a failure', async ($, on) => {
    const world = seat(on)

    world.gitDelayMs = 60_000

    for (let i = 0; i < 3; i += 1) {
      const startedAt = world.clock.now()
      let passedAt: number | null = null

      const stalled = $.prompt.submit(composer(PROMPT)).then(r => {
        passedAt = world.clock.now()

        return r
      })

      await world.clock.advance(4999)

      expect(passedAt, 'still held a millisecond before the deadline').toBe(null)

      await world.clock.advance(1)

      expect(passedAt).toBe(startedAt + 5000)
      expect(await stalled).toEqual({ text: PROMPT })
    }

    expect(world.calls, 'no judge was asked').toEqual([])
    expect(world.toasts).toEqual([
      '3 judgments failed in a row (last: the run and recent turns took over 5 s to read); prompts go through unjudged for 10 minutes.',
    ])
  })

  test('says once that the cap was reached', async ($, on) => {
    const world = seat(on)

    await mount($)

    await flagTwelveTimes($, world)

    expect(world.toasts).toEqual(['The standby judge reached its cap of 10 checks this session: a flagged prompt now gets a hint and is sent.'])
  })

  test('CC_PROMPT_COACH on beats cc_prompt_coach off', { options: { cc_prompt_coach: false } }, async ($, on) => {
    const world = seat(on)

    await mount($)

    world.replies.haiku = [answer('unclear')]

    expect(await $.prompt.submit(composer(PROMPT)), 'off in /config').toEqual({ text: PROMPT })
    expect(world.calls).toEqual([])

    world.env.CC_PROMPT_COACH = 'on'

    expect(await $.prompt.submit(composer(PROMPT))).toEqual(dropOf('unclear'))
  })

  test('ambiguous sensitivity reaches both system prompts', { options: { cc_coach_sensitivity: 'ambiguous' } }, async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [answer('unclear')]

    await $.prompt.submit(composer(PROMPT))

    world.env.CC_COACH_SENSITIVITY = 'unactionable'
    await $.prompt.submit(composer(PROMPT))

    expect(
      world.calls.map(c => [c.model, c.system.includes('its scope is ambiguous')]),
      'CC_COACH_SENSITIVITY beats /config',
    ).toEqual([
      ['haiku', true],
      ['sonnet', true],
      ['haiku', false],
      ['sonnet', false],
    ])
  })

  test('says once that it is backing off', async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [{ fail: 'api-error' }, { fail: 'api-error' }, { refuse: 'haiku is not on the model allowlist' }]

    for (let i = 0; i < 5; i += 1) {
      await $.prompt.submit(composer(PROMPT))
    }

    await world.clock.advance(10 * 60_000)
    await $.prompt.submit(composer(PROMPT))

    expect(world.calls.length, 'a fourth failure after the back-off ended').toBe(4)
    expect(world.toasts).toEqual([
      expect.stringMatching(/^3 judgments failed in a row \(last: haiku refused: .*allowlist.*\); prompts go through unjudged for 10 minutes\.$/),
    ])
  })

  test('an interrupted judgment passes without counting a failure', async ($, on) => {
    const world = seat(on)

    world.replies.haiku = [{ fail: 'api-error' }, { fail: 'api-error' }, { fail: 'aborted' }, { fail: 'api-error' }]

    for (let i = 0; i < 5; i += 1) {
      expect(await $.prompt.submit(composer(PROMPT))).toEqual({ text: PROMPT })
    }

    expect(world.calls.length, 'the back-off began at the fourth prompt, not the third').toBe(4)
    expect(world.toasts).toEqual([expect.stringMatching(/\(last: haiku API error 529 \(overloaded\)\)/)])
  })

  test('a muted coach makes no model call', async ($, on) => {
    const world = seat(on)
    let isMuted = true

    on('state.get', ($, e) => ({ value: { value: e.key === 'muted' ? isMuted : undefined, version: 0 } }))

    await mount($)

    world.replies.haiku = [answer('unclear')]

    expect(await $.prompt.submit(composer(PROMPT))).toEqual({ text: PROMPT })
    expect(world.calls).toEqual([])

    isMuted = false

    expect(await $.prompt.submit(composer(PROMPT)), 'unmuted').toEqual(dropOf('unclear'))
  })

  test('a submit during an in-flight judgment passes unjudged', async ($, on) => {
    const world = seat(on)
    const second = composer('rename the parse helper in src/utils.ts')

    world.replies.haiku = [{ fail: 'api-error' }, { fail: 'api-error' }, { hang: true }]

    await $.prompt.submit(composer(PROMPT))
    await $.prompt.submit(composer(PROMPT))

    const first = $.prompt.submit(composer(PROMPT))

    await world.clock.settle()

    // A version read that stalls would let a late in-flight check see the first judgment already over.
    world.versionDelayMs = 2000

    let passedAt: number | null = null

    const during = $.prompt.submit(second).then(r => {
      passedAt = world.clock.now()

      return r
    })

    await world.clock.settle()

    expect(passedAt, 'passed while the first was still judged').toBe(NOW)
    expect(await during).toEqual({ text: second.text })

    world.versionDelayMs = 0
    await world.clock.advance(5000)

    expect(await first, 'the first ran out of time: a third failure').toEqual({ text: PROMPT })
    expect(world.calls.map(c => c.model), 'the second never reached the judge').toEqual(['haiku', 'haiku', 'haiku'])

    expect(await $.prompt.submit(composer(PROMPT))).toEqual({ text: PROMPT })
    expect(world.calls.length, "the first judgment's back-off stands").toBe(3)
    expect(world.toasts).toEqual([expect.stringMatching(/^3 judgments failed in a row \(last: haiku gave no answer within 5 s\)/)])
  })

  test('warns at start when secret-scanning masks a prompt only after the judge', { plugins: [secretScanning('append')] }, async ($, on) => {
    const world = seat(on)

    await $.session.start(START)

    expect(world.toasts).toEqual([UNMASKED])
  })

  test('says nothing when secret-scanning masks first', { plugins: [secretScanning('prepend')] }, async ($, on) => {
    const world = seat(on)

    await $.session.start(START)

    expect(world.toasts).toEqual([])
  })

  test('says nothing without secret-scanning', async ($, on) => {
    const world = seat(on)

    await $.session.start(START)

    expect(world.toasts).toEqual([])
  })

  test('says nothing when the coach is off, below the floor or off the terminal', { plugins: [secretScanning('append')] }, async ($, on) => {
    const world = seat(on, { env: { CC_PROMPT_COACH: 'off' } })

    await $.session.start(START)

    world.env.CC_PROMPT_COACH = undefined
    world.version = '2.1.290'

    await $.session.start(START)

    world.version = '2.1.291'
    world.surfaces = ['desktop']

    await $.session.start(START)

    expect(world.toasts).toEqual([])
  })
})
