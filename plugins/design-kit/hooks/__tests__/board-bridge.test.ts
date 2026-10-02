// board-bridge.test.ts — drives hooks/board-bridge.tsx through `claude plugin test`.
// The test's own hooks stand for the engine: a fake project at /proj (git root) with the
// session started in /proj/app, a decisions.jsonl the test rewrites as serve.py would, a
// mocked clock for the 2 s poll, and prompt.submit / ui.toast captured instead of shown.
import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const FILE = '/proj/.design-kit/decisions.jsonl'
const BAND = { hasSurvey: false, isWorking: false, maxRows: 6, bodyColumns: 100, scroll: { offset: 0, bodyRows: 6 }, view: {} }

type Row = { board: string; picked: number | null; ts: string; consumed?: boolean }
type World = { rows: Row[] | null; mtime: number; prompts: string[]; toasts: string[] }

function row(board: string, picked: number | null, ts: string, consumed = false): Row {
  return { board, picked, ts, consumed }
}

function world(on: On, env: Record<string, string> = {}): World {
  const w: World = { rows: null, mtime: 1, prompts: [], toasts: [] }
  mock.env(on, env)
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', ($, e) => ({ text: e.answer }))
  // The engine draws nothing of its own in the band: an empty Box stands for that.
  on('ui.render', { component: 'AbovePrompt' }, () => ({ type: 'Box', props: {} }))
  on('session.root', () => ({ value: '/proj/app' }))
  on('fs.exists', ($, e) => ({ value: e.path === '/proj/.git' }))
  on('fs.stat', ($, e) => {
    if (e.path !== FILE || w.rows === null) {
      return { deny: 'ENOENT' }
    }
    const text = body(w)
    return { value: { kind: 'file', size: text.length, mtimeMs: w.mtime, isLink: false } }
  })
  on('fs.read', ($, e) => (e.path === FILE && w.rows !== null ? { value: body(w) } : { deny: 'ENOENT' }))
  on('prompt.submit', ($, e) => {
    w.prompts.push(e.text)
    return { text: e.text }
  })
  on('ui.toast', ($, e) => {
    w.toasts.push(e.text)
    return { value: undefined }
  })

  return w
}

function body(w: World): string {
  return (w.rows ?? []).map(r => JSON.stringify(r)).join('\n') + '\n'
}

function write(w: World, rows: Row[]): void {
  w.rows = rows
  w.mtime += 1000
}

test('silent when no board has ever posted', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/proj/app', surface: 'terminal', isInteractive: true })
  await clock.advance(10_000)
  const band = await $.ui.mount({ plugin: 'design-kit', surface: 'terminal', component: 'AbovePrompt', props: BAND })
  expect(await band.find({ key: 'read' })).toBeUndefined()
  expect(w.toasts).toEqual([])
  expect(w.prompts).toEqual([])
})

test('a pick landing mid-session toasts once and draws the band on terminal and desktop', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/proj/app', surface: 'terminal', isInteractive: true })
  write(w, [row('checkout.html', 2, '2026-10-02T10:00:00Z')])
  await clock.advance(2_000)
  write(w, [row('checkout.html', 2, '2026-10-02T10:00:00Z'), row('checkout.html', 2, '2026-10-02T10:00:01Z')])
  await clock.advance(2_000)
  expect(w.toasts).toEqual(['checkout.html: artboard 2 picked. It is above the prompt.'])
  for (const surface of ['terminal', 'desktop'] as const) {
    const band = await $.ui.mount({ plugin: 'design-kit', surface, component: 'AbovePrompt', props: BAND })
    expect((await band.find({ type: 'Text', text: /checkout\.html: artboard 2 picked \(2 updates\)/ }))?.text).toBeDefined()
    expect(await band.find({ key: 'read' })).toBeDefined()
    await band.unmount()
  }
  expect(w.prompts).toEqual([])
})

test('Read it now submits one prompt naming dk.sh and the board, then hides the band', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/proj/app', surface: 'terminal', isInteractive: true })
  write(w, [row('checkout.html', 3, '2026-10-02T10:00:00Z')])
  await clock.advance(2_000)
  const band = await $.ui.mount({ plugin: 'design-kit', surface: 'terminal', component: 'AbovePrompt', props: BAND })
  await band.press({ key: 'read' })
  expect(w.prompts.length).toBe(1)
  expect(w.prompts[0]).toContain('decision --board checkout.html --consume')
  expect(w.prompts[0]).toContain('/scripts/dk.sh')
  expect(w.prompts[0]).toContain('artboard 3 picked')
  expect(await band.find({ key: 'read' })).toBeUndefined()
})

test('a consumed file takes the band down', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/proj/app', surface: 'terminal', isInteractive: true })
  write(w, [row('checkout.html', 1, '2026-10-02T10:00:00Z')])
  await clock.advance(2_000)
  write(w, [row('checkout.html', 1, '2026-10-02T10:00:00Z', true)])
  await clock.advance(2_000)
  const band = await $.ui.mount({ plugin: 'design-kit', surface: 'terminal', component: 'AbovePrompt', props: BAND })
  expect(await band.find({ key: 'read' })).toBeUndefined()
})

test('a board name outside [A-Za-z0-9._-] never reaches the prompt', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/proj/app', surface: 'terminal', isInteractive: true })
  write(w, [row('x`; rm -rf ~ #', 1, '2026-10-02T10:00:00Z')])
  await clock.advance(2_000)
  const band = await $.ui.mount({ plugin: 'design-kit', surface: 'terminal', component: 'AbovePrompt', props: BAND })
  await band.press({ key: 'read' })
  expect(w.prompts.length).toBe(1)
  expect(w.prompts[0]).toContain('decision --latest --consume')
  expect(w.prompts[0]).not.toContain('rm -rf')
})

test('auto-wake is off by default: a quiet board starts no turn', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/proj/app', surface: 'terminal', isInteractive: true })
  write(w, [row('checkout.html', 2, '2026-10-02T10:00:00Z')])
  await clock.advance(20_000)
  expect(w.prompts).toEqual([])
})

test('with cc_design_kit_wake on, a pick starts one turn after 5 s of quiet, not while working, not on a subagent\'s end', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on, { CC_DESIGN_KIT_WAKE: 'on' })
  await $.session.start({ cwd: '/proj/app', surface: 'terminal', isInteractive: true })
  await $.turn.start({ text: 'build the board', turnId: 't1' })
  write(w, [row('checkout.html', 2, '2026-10-02T10:00:00Z')])
  await clock.advance(10_000)
  expect(w.prompts).toEqual([])
  await $.turn.complete({ reason: 'answer', answer: 'drafted', durationMs: 1, isAborted: false, turnId: 'sub', agentId: 'a1' })
  await clock.advance(10_000)
  expect(w.prompts).toEqual([])
  await $.turn.complete({ reason: 'answer', answer: 'done', durationMs: 1, isAborted: false, turnId: 't1' })
  await clock.advance(2_000)
  expect(w.prompts.length).toBe(1)
  write(w, [row('checkout.html', 2, '2026-10-02T10:00:00Z'), row('checkout.html', 2, '2026-10-02T10:00:09Z')])
  await clock.advance(20_000)
  expect(w.prompts.length).toBe(1)
})

test('a pick already waiting at session start shows the band but never wakes the session', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on, { CC_DESIGN_KIT_WAKE: 'on' })
  write(w, [row('checkout.html', 4, '2026-10-01T09:00:00Z')])
  await $.session.start({ cwd: '/proj/app', surface: 'terminal', isInteractive: true })
  await clock.advance(20_000)
  expect(w.prompts).toEqual([])
  expect(w.toasts).toEqual([])
  const band = await $.ui.mount({ plugin: 'design-kit', surface: 'terminal', component: 'AbovePrompt', props: BAND })
  expect(await band.find({ key: 'read' })).toBeDefined()
})

test('CC_DESIGN_KIT_PICK=off silences everything', async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on, { CC_DESIGN_KIT_PICK: 'off' })
  await $.session.start({ cwd: '/proj/app', surface: 'terminal', isInteractive: true })
  write(w, [row('checkout.html', 2, '2026-10-02T10:00:00Z')])
  await clock.advance(10_000)
  const band = await $.ui.mount({ plugin: 'design-kit', surface: 'terminal', component: 'AbovePrompt', props: BAND })
  expect(await band.find({ key: 'read' })).toBeUndefined()
  expect(w.toasts).toEqual([])
})

test('the cc_design_kit_pick option off silences it when the variable is unset', { options: { cc_design_kit_pick: false } }, async ($, on) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/proj/app', surface: 'terminal', isInteractive: true })
  write(w, [row('checkout.html', 2, '2026-10-02T10:00:00Z')])
  await clock.advance(10_000)
  expect(w.toasts).toEqual([])
})
