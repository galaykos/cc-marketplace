import type { EngineInterface, ModelCompleteRequest, ModelCompleteResult, On, PluginOptions, Timer } from 'claude-code'

import { activeRun, isSupported, switchOn } from './cc-kit'
import type { Host } from './cc-kit'
import {
  LIMITS,
  afterJudge,
  canEscalate,
  dropReason,
  isBackingOff,
  isEligible,
  judgeInput,
  parseLabel,
  parseVerdict,
  runContext,
  shouldHold,
  systemPrompt,
  textHash,
} from './coach-core'
import type { Gate, Label, RunContext, Sensitivity, Verdict } from './coach-core'
import { coachView, frameOf, markerBlit, mascotSpriteFor, mascotView, poseOf, restOf, spriteBlit, spriteFor, statusText } from './coach-view'
import type { Renderer } from './coach-view'
import { BLINK, FRAMES, rendererFor } from './sprite'

// Shared block templates/mods/host-block.ts — re-paste byte-for-byte.
function hostOf($: EngineInterface): Host {
  return {
    run: (argv, init) => $.process.run(argv, init),
    read: path => $.fs.read(path),
    stat: path => $.fs.stat(path),
    now: () => $.clock.now(),
    sessionId: () => $.session.id(),
    cwd: () => $.session.cwd(),
    projectDir: () => $.env.get('CLAUDE_PROJECT_DIR'),
  }
}

export type CoachView =
  | { mode: 'idle' }
  | { mode: 'thinking' }
  | { mode: 'speaking'; text: string; verdict: Verdict }
  | { mode: 'hint'; label: Exclude<Label, 'clear'> }

const IDLE: CoachView = { mode: 'idle' }

type Coach = {
  view: CoachView
  isJudging: boolean
}

// Module memory, never $.state: every plugin can read $.state, and the bubble holds the person's own text.
export const coach: Coach = { view: IDLE, isJudging: false }

type Drawn = { requestId: string; sprite: Renderer | null }

type Band = {
  // Where the band last drew the coach, and the sprite it drew there; null while it draws none of the coach.
  drawn: Drawn | null
  hasSurvey: boolean
  isImageDenied: boolean
  loop: Timer | null
  ticks: number
}

const band: Band = { drawn: null, hasSurvey: false, isImageDenied: false, loop: null, ticks: 0 }

type Display = 'pane' | 'statusline' | 'off'

type Mascot = {
  // Read once a session, at the first draw of the band.
  display: Display | null
  isStarting: boolean
  // The pane opened or the status line set, once a session.
  isShown: boolean
  drawn: Drawn | null
  blink: Timer | null
  isStill: boolean
}

const mascot: Mascot = { display: null, isStarting: false, isShown: false, drawn: null, blink: null, isStill: false }

const MASCOT_PANE = { id: 'prompt-coach', title: 'coach', columns: 18 } as const

const DISPLAYS = ['pane', 'statusline', 'off'] as const

const STAYS_NOTE = 'The coach stays: set cc_coach_mascot in /config, or CC_COACH_MASCOT, to statusline or off'

const BLINK_EVERY_MS = 4000

const BLINK_SHUT_MS = 150

const FRAME_MS = 250

// Thinking and talking together stop within 5 s, so the animation needs no pause control (WCAG 2.2.2).
const ANIMATION_TICKS = 20

// Deny reasons as CLI 2.1.291-2.1.292 word them (rationale/2026-10-07-prompt-coach-probe.md, band-unavailable and image-terminals).
const ALT = /the Image draws its alt/

const NOT_MOUNTED = /no Raster of its own is mounted/

const COLLAPSED = 'the plugin panel above the prompt is hidden'

const SURVEY = 'a survey holds the plugin panel above the prompt'

const UNDRAWN = 'the plugin panel above the prompt is not showing the coach'

const MUTED_NOTE = 'prompt-coach muted for this session — a new session turns it back on'

const PASS = { plugin: 'prompt-coach', key: 'pass' } as const

const MUTED = { plugin: 'prompt-coach', key: 'muted' } as const

const ESCALATIONS = { plugin: 'prompt-coach', key: 'escalations' } as const

const FAILURES = { plugin: 'prompt-coach', key: 'failures' } as const

const BACKOFF_UNTIL = { plugin: 'prompt-coach', key: 'backoffUntil' } as const

const STANDBY_MODELS = ['sonnet', 'opus'] as const

const SENSITIVITIES = ['unactionable', 'ambiguous'] as const

const SPEC_LINE = /^Spec:.*?(taskmaster-docs\/specs\/[\w.-]+\.md)/m

const MAX_CONTEXT_BYTES = 256 * 1024

const SECONDS = LIMITS.deadlineMs / 1000

type Prompt = { text: string; origin: string; attachments: number }

// null: the dispatch itself was abandoned (Esc), which is neither an answer nor the judge's failure.
type Answer = { text: string } | { failure: string } | null

type Judgment = { gate: Gate; signal: AbortSignal; deadline: number }

function choiceOf<T extends string>(value: string | undefined, option: unknown, choices: readonly T[], fallback: T): T {
  const pick = (candidate: unknown) => choices.find(choice => typeof candidate === 'string' && candidate.trim().toLowerCase() === choice)

  return pick(value) ?? pick(option) ?? fallback
}

// The judge names off-card, or reopens a decision, only from context it was given, which parseVerdict cannot see.
function isOffered(verdict: Verdict, run: RunContext | null): boolean {
  if (verdict.kind === 'off-card') {
    return (run?.cards.length ?? 0) > 0
  }

  if (verdict.kind === 'reopens') {
    return run?.spec?.decisions.some(row => row.split(' ', 1)[0] === verdict.decision) ?? false
  }

  return true
}

function say($: EngineInterface, text: string): void {
  try {
    $.ui.toast(text)
  } catch {
    // A refused toast changes nothing: the prompt's fate is already decided.
  }
}

function stopLoop(): void {
  band.loop?.cancel()
  band.loop = null
}

function show($: EngineInterface, view: CoachView): void {
  coach.view = view

  if (view.mode === 'thinking') {
    band.ticks = 0
  }

  if (view.mode === 'idle') {
    stopLoop()
    band.drawn = null
  } else {
    band.loop ??= $.clock.every(FRAME_MS, () => void tick($))
  }

  $.ui.invalidate('ui.render')

  if (mascot.isShown && mascot.display === 'statusline') {
    $.ui.status(statusText(view))
  }
}

// An Image the terminal can draw only as its alt falls back to Raster for the session. True when the frame was drawn.
async function blitSprite($: EngineInterface, requestId: string, renderer: Renderer, frame: readonly string[]): Promise<boolean> {
  const blitted = await $.ui.blit(spriteBlit(requestId, renderer, frame)).catch(() => null)

  if (renderer === 'image' && ALT.test(blitted?.deny ?? '')) {
    band.isImageDenied = true
    $.ui.invalidate('ui.render')
  }

  return blitted !== null && blitted.deny === undefined
}

// Every drawn pose gets one blit, a looping one a frame each tick until the cap, ending on its rest frame.
async function tick($: EngineInterface): Promise<void> {
  const pose = poseOf(coach.view)

  band.ticks += 1

  const isLast = FRAMES[pose].length === 1 || band.ticks >= ANIMATION_TICKS

  if (isLast) {
    stopLoop()
  }

  const frame = isLast ? restOf(pose) : frameOf(pose, band.ticks - 1)

  for (const drawn of [band.drawn, mascot.drawn]) {
    if (drawn !== null && drawn.sprite !== null) {
      await blitSprite($, drawn.requestId, drawn.sprite, frame)
    }
  }
}

function stopBlink(): void {
  mascot.blink?.cancel()
  mascot.blink = null
}

// Only at rest; a pane that refuses the blit (closed, or behind another tab) stops it until the pane draws again.
async function blink($: EngineInterface): Promise<void> {
  const drawn = mascot.drawn
  const sprite = drawn?.sprite ?? null

  if (drawn === null || sprite === null || poseOf(coach.view) !== 'idle') {
    return
  }

  if (!(await blitSprite($, drawn.requestId, sprite, BLINK))) {
    stopBlink()
    mascot.drawn = null

    return
  }

  $.clock.after(BLINK_SHUT_MS, () => {
    if (poseOf(coach.view) === 'idle') {
      void blitSprite($, drawn.requestId, sprite, restOf('idle'))
    }
  })
}

function still($: EngineInterface): void {
  mascot.isStill = true
  stopBlink()
  $.ui.invalidate('ui.render')
}

// The variable's 0 and false mean off too, as every switch of this plugin's does.
async function displayOf($: EngineInterface, options: PluginOptions): Promise<Display> {
  const value = await $.env.get('CC_COACH_MASCOT')

  if (!switchOn(await $.env.get('CC_PROMPT_COACH'), options.cc_prompt_coach !== false) || !switchOn(value)) {
    return 'off'
  }

  return choiceOf(value, options.cc_coach_mascot, DISPLAYS, 'pane')
}

// The pane docks beside the transcript only under the fullscreen renderer: anywhere else an unasked pane would take rows above the prompt.
async function startMascot($: EngineInterface, isFullscreen: boolean | undefined, options: PluginOptions): Promise<void> {
  if (mascot.isShown || mascot.isStarting) {
    return
  }

  mascot.isStarting = true

  try {
    mascot.display ??= await displayOf($, options)

    if (mascot.display === 'off' || (mascot.display === 'pane' && isFullscreen !== true)) {
      return
    }

    mascot.isShown = true

    if (!(await isTerminalSession($))) {
      return
    }

    // A pane too wide for the terminal now waits unplaced, and the engine seats it once the terminal is widened.
    if (mascot.display === 'pane') {
      await $.ui.open(MASCOT_PANE)
    } else {
      $.ui.status(statusText(coach.view))
    }
  } finally {
    mascot.isStarting = false
  }
}

// Why the bubble would not show if the prompt dropped now, from a blit the band answers now; null when it would.
async function unshown($: EngineInterface, signal: AbortSignal): Promise<string | null> {
  const drawn = band.drawn

  if (drawn === null) {
    return band.hasSurvey ? SURVEY : UNDRAWN
  }

  // Always the Raster marker: its not-mounted deny is the collapse the probe measured, on every terminal.
  const blitted = await beforeDeadline($.ui.blit(markerBlit(drawn.requestId)).catch(() => null), signal)

  if (blitted === null) {
    return UNDRAWN
  }

  if (blitted.deny === undefined) {
    return null
  }

  return NOT_MOUNTED.test(blitted.deny) ? COLLAPSED : UNDRAWN
}

async function rendererOf($: EngineInterface): Promise<Renderer> {
  if (band.isImageDenied) {
    return 'raster'
  }

  return rendererFor({ TERM: await $.env.get('TERM'), TERM_PROGRAM: await $.env.get('TERM_PROGRAM'), TMUX: await $.env.get('TMUX') })
}

// Never over a draft the person typed since the drop; a refused fill leaves the bubble up with the text in it.
async function fill($: EngineInterface, text: string): Promise<void> {
  if ((await $.prompt.read()).text !== '') {
    say($, 'Clear the prompt box, then press 1 or 2 again')

    return
  }

  const filled = await $.prompt.fill({ text, mode: 'replace' })

  if (!filled.isFilled) {
    return
  }

  // The box drops the code points a terminal draws as nothing, so Enter sends what it holds, not what was given.
  const hash = textHash(filled.text === '' ? text : filled.text)
  const { value: passed = [] } = await $.state.get(PASS)

  if (!passed.includes(hash)) {
    await $.state.set(PASS, [...passed, hash])
  }

  show($, IDLE)
}

async function mute($: EngineInterface): Promise<void> {
  await $.state.set(MUTED, true)
  say($, MUTED_NOTE)
  show($, IDLE)
}

// Settles null at the deadline, at once when it has passed: no read or blit may hold the prompt past it.
function beforeDeadline<T>(work: Promise<T>, signal: AbortSignal): Promise<T | null> {
  if (signal.aborted) {
    return Promise.resolve(null)
  }

  return new Promise((resolve, reject) => {
    const expire = () => resolve(null)

    signal.addEventListener('abort', expire, { once: true })
    work.then(resolve, reject).finally(() => signal.removeEventListener('abort', expire))
  })
}

// v1 draws its bubble in the terminal alone, so a session the desktop draws on passes every prompt.
async function isTerminalSession($: EngineInterface): Promise<boolean> {
  const surfaces = await $.session.surfaces()

  return surfaces.includes('terminal') && !surfaces.includes('desktop')
}

// task-runner writes active-run.json untracked: a committed one came with a clone, and so may the index and spec it names.
async function isCommittedRun(host: Host, root: string): Promise<boolean> {
  const ran = await host
    .run(['git', 'ls-files', '--error-unmatch', '--', '.claude/task-runner/active-run.json'], { cwd: root, timeoutMs: 2000 })
    .catch(() => null)

  return ran?.exitCode !== 1
}

// Only a regular file of at most 256 KiB whose real path lies under the state root's.
async function contextFile($: EngineInterface, realRoot: string, path: string): Promise<string | null> {
  const stat = await $.fs.stat(path, { resolve: true }).catch(() => null)
  const real = stat?.realPath

  if (stat === null || stat.kind !== 'file' || stat.size > MAX_CONTEXT_BYTES || real === undefined || !real.startsWith(`${realRoot}/`)) {
    return null
  }

  return $.fs.read(real).catch(() => null)
}

// Any doubt about the run, its index or its spec leaves that context out of the judgment, never the judgment itself.
async function runOf($: EngineInterface): Promise<RunContext | null> {
  const host = hostOf($)
  const run = await activeRun(host)
  const listed = run?.index_path ?? ''

  if (run === null || listed === '' || (await isCommittedRun(host, run.root))) {
    return null
  }

  const realRoot = (await $.fs.stat(run.root, { resolve: true }).catch(() => null))?.realPath

  if (realRoot === undefined) {
    return null
  }

  const index = await contextFile($, realRoot, listed.startsWith('/') ? listed : `${run.root}/${listed}`)

  if (index === null) {
    return null
  }

  const specPath = SPEC_LINE.exec(index)?.[1]
  const spec = specPath === undefined ? null : await contextFile($, realRoot, `${run.root}/${specPath}`)

  return runContext(index, spec)
}

async function gateOf($: EngineInterface): Promise<Gate> {
  const { value: escalations = 0 } = await $.state.get(ESCALATIONS)
  const { value: failures = 0 } = await $.state.get(FAILURES)
  const { value: backoffUntil = null } = await $.state.get(BACKOFF_UNTIL)

  return { escalations, failures, backoffUntil }
}

async function ask($: EngineInterface, request: ModelCompleteRequest, judgment: Judgment): Promise<Answer> {
  const timeoutMs = Math.floor(judgment.deadline - (await $.clock.now()))

  // timeoutMs can reach 0 a moment before the deadline timer fires, and the engine refuses a 0.
  if (judgment.signal.aborted || timeoutMs <= 0) {
    return { failure: `${request.model} was not asked: ${SECONDS} s had passed` }
  }

  let r: ModelCompleteResult

  try {
    r = await $.model.complete({ ...request, effort: 'low', timeoutMs }, { signal: judgment.signal })
  } catch (error) {
    return { failure: `${request.model} refused: ${error instanceof Error ? error.message : String(error)}` }
  }

  if (r.isAnswered) {
    return { text: r.text }
  }

  switch (r.reason) {
    // The model answered with no text: malformed output, which passes the prompt without counting as a failure.
    case 'empty-reply':
      return { text: '' }
    case 'aborted':
      return judgment.signal.aborted ? { failure: `${request.model} gave no answer within ${SECONDS} s` } : null
    case 'api-error':
      return { failure: `${request.model} API error ${r.status ?? 'with no response'} (${r.error})` }
  }
}

async function settle($: EngineInterface, before: Gate, escalated: boolean, failure: string | null): Promise<void> {
  const after = afterJudge(before, failure === null ? 'ok' : 'failed', escalated, await $.clock.now())

  await $.state.set(ESCALATIONS, after.escalations)
  await $.state.set(FAILURES, after.failures)
  await $.state.set(BACKOFF_UNTIL, after.backoffUntil)

  if (canEscalate(before) && !canEscalate(after)) {
    say($, `The standby judge reached its cap of ${LIMITS.cap} checks this session: a flagged prompt now gets a hint and is sent.`)
  }

  if (after.backoffUntil !== before.backoffUntil) {
    say(
      $,
      `${LIMITS.backoffFailures} judgments failed in a row (last: ${failure}); prompts go through unjudged for ${LIMITS.backoffMs / 60_000} minutes.`,
    )
  }
}

async function verdictOf($: EngineInterface, text: string, judgment: Judgment, options: PluginOptions): Promise<Verdict | null> {
  const sensitivity = choiceOf(await $.env.get('CC_COACH_SENSITIVITY'), options.cc_coach_sensitivity, SENSITIVITIES, 'unactionable')
  const read = await beforeDeadline(Promise.all([runOf($), $.session.messages()]), judgment.signal)

  if (read === null) {
    await settle($, judgment.gate, false, `the run and recent turns took over ${SECONDS} s to read`)

    return null
  }

  const [run, messages] = read
  const turns = messages.filter(m => m.text.trim() !== '').map(({ role, text }) => ({ role, text }))
  const prompt = judgeInput({ prompt: text, run, turns })

  const first = await ask($, { model: 'haiku', system: systemPrompt('first', sensitivity, run !== null, run), prompt, maxTokens: 8 }, judgment)

  if (first === null) {
    return null
  }

  if ('failure' in first) {
    await settle($, judgment.gate, false, first.failure)

    return null
  }

  const label = parseLabel(first.text)

  if (label === 'clear' || !canEscalate(judgment.gate)) {
    await settle($, judgment.gate, false, null)

    if (label !== 'clear') {
      show($, { mode: 'hint', label })
    }

    return null
  }

  const model = choiceOf(await $.env.get('CC_COACH_MODEL'), options.cc_coach_model, STANDBY_MODELS, 'sonnet')
  const standby = await ask($, { model, system: systemPrompt('standby', sensitivity, run !== null, run), prompt, maxTokens: 400 }, judgment)

  if (standby === null) {
    return null
  }

  await settle($, judgment.gate, true, 'failure' in standby ? standby.failure : null)

  const verdict = 'failure' in standby ? null : parseVerdict(standby.text, text)

  return verdict !== null && shouldHold(verdict) && isOffered(verdict, run) ? verdict : null
}

async function heldVerdict($: EngineInterface, prompt: Prompt, options: PluginOptions): Promise<Verdict | null> {
  if (!isSupported((await $.session.version()).version)) {
    return null
  }

  // Only the person's own next prompt ends the bubble: a notification, a schedule or a peer may arrive while it is read.
  if (prompt.origin === 'composer' && (coach.view.mode === 'speaking' || coach.view.mode === 'hint')) {
    show($, IDLE)
  }

  if (!switchOn(await $.env.get('CC_PROMPT_COACH'), options.cc_prompt_coach !== false) || !(await isTerminalSession($))) {
    return null
  }

  const { value: passed = [] } = await $.state.get(PASS)
  const { value: muted = false } = await $.state.get(MUTED)

  if (!isEligible({ ...prompt, passed, muted })) {
    return null
  }

  const gate = await gateOf($)
  const startedAt = await $.clock.now()

  if (isBackingOff(gate, startedAt)) {
    return null
  }

  show($, { mode: 'thinking' })

  const stop = new AbortController()
  const judged = new AbortController()

  // A sleep refused, failed or cut short is the deadline too: no timer a hook refuses may hold the prompt.
  void $.clock.sleep(LIMITS.deadlineMs, { signal: judged.signal }).then(
    () => stop.abort(),
    () => stop.abort(),
  )

  try {
    const verdict = await verdictOf($, prompt.text, { gate, signal: stop.signal, deadline: startedAt + LIMITS.deadlineMs }, options)

    // The deadline can pass while a late answer is still being counted.
    if (verdict === null || stop.signal.aborted) {
      return null
    }

    const unavailable = await unshown($, stop.signal)

    if (unavailable !== null) {
      say($, `Flagged (${verdict.kind}) but sent: ${unavailable}.`)

      return null
    }

    show($, { mode: 'speaking', text: prompt.text, verdict })

    return verdict
  } finally {
    judged.abort()

    if (coach.view.mode === 'thinking') {
      show($, IDLE)
    }
  }
}

export function register(on: On, options: PluginOptions) {
  on('prompt.submit', async ($, e, next) => {
    // Claimed before any await: a submit during a judgment passes at once, and never reads state that judgment will write.
    if (coach.isJudging) {
      return next(e)
    }

    coach.isJudging = true

    let verdict: Verdict | null

    try {
      verdict = await heldVerdict($, { text: e.text, origin: e.origin.kind, attachments: e.attachments?.length ?? 0 }, options)
    } finally {
      coach.isJudging = false
    }

    return verdict === null ? next(e) : { drop: dropReason(verdict) }
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'AbovePrompt', surface: 'terminal' }, async ($, e, next) => {
    if (!isSupported((await $.session.version()).version)) {
      return next(e)
    }

    // Not awaited: the band draws now, whatever the open does to the layout.
    void startMascot($, e.viewport?.isFullscreen, options).catch(() => undefined)

    band.hasSurvey = e.props.hasSurvey

    const view = coach.view

    if (view.mode === 'idle' || e.props.hasSurvey) {
      band.drawn = null

      return next(e)
    }

    const bodyRows = e.props.scroll.bodyRows
    const sprite = spriteFor(await rendererOf($), e.props.bodyColumns, bodyRows)

    band.drawn = { requestId: e.requestId, sprite }

    const kit = { ui: $.ui.resolve(e), sprite, bodyRows, fill: (text: string) => fill($, text), mute: () => mute($) }

    return coachView(kit, view)
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: MASCOT_PANE.id }, async ($, e, next) => {
    if (!isSupported((await $.session.version()).version)) {
      return next(e)
    }

    const sprite = mascotSpriteFor(await rendererOf($), e.props.bodyColumns, e.props.scroll.bodyRows)

    mascot.drawn = { requestId: e.requestId, sprite }

    if (sprite !== null && !mascot.isStill) {
      mascot.blink ??= $.clock.every(BLINK_EVERY_MS, () => void blink($))
    }

    const kit = { ui: $.ui.resolve(e), sprite, still: mascot.isStill ? null : () => still($) }

    return mascotView(kit, coach.view)
  }).catch(($, e, next) => next(e))

  // Answering without next keeps the pane open; an unload still closes it.
  on('ui.close', async ($, e, next) => {
    if (e.id !== MASCOT_PANE.id || e.origin.kind !== 'person') {
      return next(e)
    }

    say($, STAYS_NOTE)
  }).catch(($, e, next) => next(e))
}
