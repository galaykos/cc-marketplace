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
} from './coach-core'
import type { Gate, Label, RunContext, Sensitivity, Verdict } from './coach-core'

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
  // Why the band cannot show a bubble now, set by the band; a confident flag then passes with it as a toast.
  bandUnavailable: string | null
  isJudging: boolean
}

// Module memory, never $.state: every plugin can read $.state, and the bubble holds the person's own text.
export const coach: Coach = { view: IDLE, bandUnavailable: null, isJudging: false }

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

// Settles null once the signal aborts: a stalled read must not hold the prompt past the deadline.
function beforeDeadline<T>(work: Promise<T>, signal: AbortSignal): Promise<T | null> {
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
      coach.view = { mode: 'hint', label }
    }

    return null
  }

  const model = choiceOf(await $.env.get('CC_COACH_MODEL'), options.cc_coach_model, STANDBY_MODELS, 'sonnet')
  const standby = await ask($, { model, system: systemPrompt('standby', sensitivity, run !== null, run), prompt, maxTokens: 400 }, judgment)

  if (standby === null) {
    return null
  }

  await settle($, judgment.gate, true, 'failure' in standby ? standby.failure : null)

  const verdict = 'failure' in standby ? null : parseVerdict(standby.text)

  return verdict !== null && shouldHold(verdict) && isOffered(verdict, run) ? verdict : null
}

async function heldVerdict($: EngineInterface, prompt: Prompt, options: PluginOptions): Promise<Verdict | null> {
  if (!isSupported((await $.session.version()).version)) {
    return null
  }

  // Only the person's own next prompt ends the bubble: a notification, a schedule or a peer may arrive while it is read.
  if (prompt.origin === 'composer' && (coach.view.mode === 'speaking' || coach.view.mode === 'hint')) {
    coach.view = IDLE
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

  coach.view = { mode: 'thinking' }

  const stop = new AbortController()
  let timer: Timer | undefined

  try {
    timer = $.clock.after(LIMITS.deadlineMs, () => stop.abort())

    const verdict = await verdictOf($, prompt.text, { gate, signal: stop.signal, deadline: startedAt + LIMITS.deadlineMs }, options)

    if (verdict === null) {
      return null
    }

    if (coach.bandUnavailable !== null) {
      say($, `Flagged (${verdict.kind}) but sent: ${coach.bandUnavailable}.`)

      return null
    }

    coach.view = { mode: 'speaking', text: prompt.text, verdict }

    return verdict
  } finally {
    timer?.cancel()

    if (coach.view.mode === 'thinking') {
      coach.view = IDLE
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
}
