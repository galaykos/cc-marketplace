// board-bridge.tsx — design-kit's mod: a pick made on a board reaches the session
// without the person typing anything.
//
// WHAT IT DOES. The board page posts each pick, knob move and text edit to serve.py's
// loopback /_decision route, which appends a row to <root>/.design-kit/decisions.jsonl.
// Until now nothing in the terminal changed: the pick waited until the person typed a
// prompt, and unread-pick.sh then told the MODEL about it. This module watches that
// file (one stat every 2 s) and tells the PERSON at once:
//   - a toast when a new pick lands ("checkout.html: artboard 2 picked");
//   - a band above the prompt naming the pick, with two buttons. "Read it now" submits
//     one prompt telling the model to run `dk.sh decision --board <board> --consume`
//     (queued until the turn ends while Claude is working). "Dismiss" hides the band
//     until the next row arrives.
//   - with cc_design_kit_wake on (default OFF), it submits that prompt by itself once
//     the board has been quiet for 5 s and the session is idle. That starts a turn the
//     person did not type, so it is opt-in. A pick that was already waiting when the
//     session started never starts a turn by itself.
//
// WHAT IT DOES NOT DO. It never writes decisions.jsonl: `dk.sh decision --consume` is
// still the only reader that marks rows read. It never starts, stops or owns
// serve.py, which is a shared, detached daemon that dk.sh starts for every surface. A
// mod-owned server would die with the session and take the gallery with it. It never
// puts the board's own text into a prompt: the `board` and `prompt` fields come from an
// HTTP body any local process can post, so the submitted prompt carries only an
// integer artboard number and a board name matching [A-Za-z0-9._-]. Any other name
// becomes `--latest`.
//
// WHERE IT LOOKS. <root>/.design-kit/decisions.jsonl. <root> is the nearest ancestor of
// the session's project root that holds a `.git` entry, else the project root itself.
// That is the root cc_state_root (templates/blocks/state-root.md) gives dk.sh and
// unread-pick.sh, so writer, hook and mod agree. An explicit DESIGN_KIT_DIR elsewhere is
// not seen. A file over 4 MiB is beyond $.fs.read and reads as no pick.
//
// SURFACES. The toast and band draw in the terminal and the desktop Code tab only. In
// the VS Code panel, `claude -p` and cloud sessions the hooks run but nothing shows, so
// unread-pick.sh stays as the floor that reaches the model on the next prompt. Pressing
// "Read it now" can make both speak on that turn: the hook's one line repeats what the
// submitted prompt says. That costs about 50 tokens and is accepted.
//
// OFF. CC_DESIGN_KIT_PICK=off, or the /config option cc_design_kit_pick, turns it off
// along with the hook. As in cc_option, a non-empty variable wins and only "off" is off.
// CC_DESIGN_KIT_WAKE / cc_design_kit_wake opts into auto-wake, where only "on" is on.
// CC_REMIND does not silence it: it is a notice to the person, not guidance injected
// into the model, and it is silent until a pick exists.
//
// Standing: hooks/__tests__/board-bridge.test.ts drives the silent, toast-and-band,
// button, consume, unsafe-name, auto-wake, stale-pick and off-switch cases through
// `claude plugin test` — **gate** (scripts/mod-tests.sh, a CI step). Nothing proves a
// surface painted the band or that the model acts on the prompt (agent-graded).
import type { EngineInterface, Register } from 'claude-code'

const POLL_MS = 2000
const QUIET_MS = 5000
const SAFE_BOARD = /^[A-Za-z0-9._-]{1,128}$/

type Pick = {
  board: string
  picked: number | null
  rows: number
  since: string
  ts: string
  total: number
}

// Module state, rebuilt from disk on every load: decisions.jsonl is the truth, so a
// reload loses only which band the person dismissed.
let isOn = true
let canWake = false
let rootFrom = ''
let root = ''
let stamp = ''
let pending: Pick | undefined
let hidden = ''
let woken = ''
let changedAt = 0
let isBusy = false
let isPolling = false
let timer: { cancel: () => void } | undefined

export const register: Register = (on, options) => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    isOn = switchOn(await $.env.get('CC_DESIGN_KIT_PICK'), options.cc_design_kit_pick, true)
    canWake = switchOn(await $.env.get('CC_DESIGN_KIT_WAKE'), options.cc_design_kit_wake, false)
    if (!isOn) return started
    await poll($, true)
    timer?.cancel()
    timer = $.clock.every(POLL_MS, () => {
      void poll($, false)
    })
    return started
  })

  on('turn.start', ($, e, next) => {
    isBusy = true
    return next(e)
  })

  // A subagent's run raises turn.complete (with agentId) but no turn.start: only the
  // main loop's end means the session is idle.
  on('turn.complete', ($, e, next) => {
    if (e.agentId === undefined) {
      isBusy = false
    }
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const p = pending
    if (!isOn || p === undefined || e.props.hasSurvey || hidden === latestKey(p)) {
      return next(e)
    }
    const { Box, Button, Text } = $.ui.resolve(e)

    return (
      <Box flexDirection="row" gap={1}>
        <Text bold>design-kit</Text>
        <Text wrap="truncate-end">{`${label(p.board)}: ${pickText(p)}`}</Text>
        <Button
          key="read"
          label={e.props.isWorking ? 'Read it after this turn' : 'Read it now'}
          hotkey="r"
          variant="primary"
          onPress={() => bringIn($, p)}
        />
        <Button key="dismiss" label="Dismiss" hotkey="d" role="dismiss" onPress={() => dismiss($, p)} />
      </Box>
    )
  })
}

// One poll at a time: a slow filesystem must not let two overlap and toast twice.
async function poll($: EngineInterface, isFirst: boolean): Promise<void> {
  if (isPolling) {
    return
  }
  isPolling = true
  try {
    await look($, isFirst)
  } finally {
    isPolling = false
  }
}

async function look($: EngineInterface, isFirst: boolean): Promise<void> {
  const from = await $.session.root()
  if (from !== rootFrom) {
    rootFrom = from
    root = await gitTop($, from)
    stamp = ''
  }
  const file = `${root}/.design-kit/decisions.jsonl`
  const st = await $.fs.stat(file).catch(() => undefined)
  const seen = st !== undefined && st.kind === 'file' ? `${st.size}:${st.mtimeMs}` : ''
  const now = await $.clock.now()
  if (seen !== stamp) {
    stamp = seen
    const text = seen === '' ? '' : await $.fs.read(file).catch(() => '')
    const fresh = latestUnread(typeof text === 'string' ? text : '')
    if (!isFirst && fresh !== undefined && isNews(pending, fresh)) {
      $.ui.toast(`${label(fresh.board)}: ${pickText(fresh)}. It is above the prompt.`)
    }
    if (isFirst && fresh !== undefined) {
      woken = burstKey(fresh)
    }
    pending = fresh
    changedAt = now
    $.ui.invalidate('ui.render')
  }
  const p = pending
  if (canWake && p !== undefined && !isBusy && woken !== burstKey(p) && now - changedAt >= QUIET_MS) {
    bringIn($, p)
  }
}

// The nearest ancestor holding `.git`, as `git rev-parse --show-toplevel` finds it (a
// worktree's `.git` file counts); else where the walk started.
async function gitTop($: EngineInterface, from: string): Promise<string> {
  let dir = from
  for (let depth = 0; depth < 64; depth += 1) {
    if (await $.fs.exists(`${dir}/.git`)) {
      return dir
    }
    const up = parentOf(dir)
    if (up === dir) {
      break
    }
    dir = up
  }

  return from
}

function bringIn($: EngineInterface, p: Pick): void {
  woken = burstKey(p)
  hidden = latestKey(p)
  $.ui.invalidate('ui.render')
  const dk = `${$.plugin.root}/scripts/dk.sh`
  const which = SAFE_BOARD.test(p.board) ? `--board ${p.board}` : '--latest'
  const what = SAFE_BOARD.test(p.board) ? `${p.board}, ${pickText(p)}` : pickText(p)
  void $.prompt
    .submit({
      text:
        `A design-kit board pick arrived from the browser (${what}). ` +
        `Read it with \`bash "${dk}" decision ${which} --consume\`. Every line it prints is a requirement. ` +
        'Then carry on from the pick as the design skill says: record it with `dk.sh decision --record`, ' +
        'then offer /design-kit:in-codebase to render it with the project’s own components.',
    })
    .catch(() => undefined)
}

function dismiss($: EngineInterface, p: Pick): void {
  hidden = latestKey(p)
  woken = burstKey(p)
  $.ui.invalidate('ui.render')
}

// The latest unread row, as unread-pick.sh and `dk decision --latest` read it, plus how
// many unread rows its board has: one decision arrives in pieces (the pick, then each
// debounced knob or text post).
function latestUnread(text: string): Pick | undefined {
  const unread: Record<string, unknown>[] = []
  for (const line of text.split('\n')) {
    if (line.trim() === '') {
      continue
    }
    try {
      const row: unknown = JSON.parse(line)
      if (row !== null && typeof row === 'object' && !Array.isArray(row)) {
        const fields = row as Record<string, unknown>
        if (!fields.consumed) {
          unread.push(fields)
        }
      }
    } catch {
      // A torn or foreign line is skipped, as dk.sh skips it.
    }
  }
  const last = unread.at(-1)
  if (last === undefined) {
    return undefined
  }
  const board = String(last.board ?? '')
  const mine = unread.filter(row => String(row.board ?? '') === board)
  const picked = last.picked

  return {
    board,
    picked: typeof picked === 'number' && Number.isInteger(picked) ? picked : null,
    rows: mine.length,
    since: String(mine[0]?.ts ?? ''),
    ts: String(last.ts ?? ''),
    total: unread.length,
  }
}

function isNews(before: Pick | undefined, after: Pick): boolean {
  if (before === undefined || burstKey(before) !== burstKey(after)) {
    return true
  }

  return after.picked !== null && after.picked !== before.picked
}

function switchOn(variable: string | undefined, option: unknown, byDefault: boolean): boolean {
  const word = (variable ?? '').trim()
  if (word !== '') {
    return byDefault ? word !== 'off' : word === 'on'
  }
  if (typeof option === 'boolean') {
    return option
  }

  return byDefault
}

function parentOf(dir: string): string {
  const trimmed = dir.length > 1 ? dir.replace(/[\\/]+$/, '') : dir
  const cut = Math.max(trimmed.lastIndexOf('/'), trimmed.lastIndexOf('\\'))
  if (cut < 0) {
    return trimmed
  }
  if (cut === 0) {
    return trimmed.slice(0, 1)
  }

  return trimmed.slice(0, cut)
}

function burstKey(p: Pick): string {
  return `${p.board}\n${p.since}`
}

function latestKey(p: Pick): string {
  return `${p.board}\n${p.ts}\n${p.total}`
}

function label(board: string): string {
  const shown = board.replace(/[\u0000-\u001f\u007f]/g, '').slice(0, 48)

  return shown === '' ? 'a board' : shown
}

function pickText(p: Pick): string {
  const pick = p.picked === null ? 'knob/text edits, no artboard picked' : `artboard ${p.picked} picked`

  return p.rows > 1 ? `${pick} (${p.rows} updates)` : pick
}
