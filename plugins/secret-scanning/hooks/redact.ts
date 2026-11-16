import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { isSupported, switchOn } from './cc-kit'
import { parsePatterns, redact, secretSpans } from './redact-core'
import type { Pattern } from './redact-core'

const MASK = '[REDACTED:'

const MASK_AND_SEND = 'Mask and send'
const SEND_AS_TYPED = 'Send as typed'
const CANCEL = 'Cancel'

// The person's own words: Enter at the composer, a Remote Control message (`bridge`), or a `claude -p` / SDK prompt
// (`sdk`, measured on CLI 2.1.294), where ui.ask rejects and the mask stands. A plugin's, a peer's or a notification's is not.
const TYPED = new Set(['composer', 'bridge', 'sdk'])

// prompt.edit runs on every key within 50 ms; a 100 KB draft measured 16 ms median and 24 ms on the worst input found,
// so a longer one is painted up to here and the rest is left to the check at submit.
const DRAFT_SCAN_MAX = 100_000

const DRAFT_STYLE = { color: 'error', underline: true } as const

// A command name with no second slash: a path such as /tmp/x is sent as a plain prompt, an unknown /name raises no submit.
const COMMAND = /^\/[^\s/]+(?:\s|$)/

const WRITE_BACK_BAN =
  'Never write a [REDACTED:…] placeholder back to a file: it would replace the real value, and Write, Edit, ' +
  'MultiEdit and NotebookEdit refuse it. Leave the value out of the edit instead.'

function maskCount(text: string): number {
  return text.split(MASK).length - 1
}

function toastOf(count: number, tool: string, labels: string[]): string {
  return `Redacted ${count} secret${count === 1 ? '' : 's'} from ${tool}: ${labels.join(', ')}`
}

// The lines a mention names (#L10-20), or the whole file; an offset below 1 or a limit below 1 widens the scan, never narrows it.
function mentionedText(text: string, offset: number | undefined, limit: number | undefined): string {
  if (offset === undefined) {
    return text
  }

  const lines = text.split('\n')
  const from = Math.max(1, offset) - 1

  return lines.slice(from, limit === undefined || limit < 1 ? lines.length : from + limit).join('\n')
}

function attachedNoteOf(labels: string[]): string {
  return `secret-scanning redacted ${labels.join(', ')} from this attached file; each reads [REDACTED:<label>] here and is unchanged at its source. ${WRITE_BACK_BAN}`
}

function mentionToastOf(mention: string, labels: string[]): string {
  return `secret-scanning kept @${mention} out of your prompt: it holds ${labels.join(', ')}. Claude can still Read it, unmasked; secret-scanning then flags the secret by its label.`
}

let patterns: Promise<Pattern[] | null> | undefined

// The prompt guard's patterns as last resolved, null while it is off: prompt.edit may make no $ call inside its budget.
let draftPatterns: Pattern[] | null = null

async function isOn($: EngineInterface, options: PluginOptions): Promise<boolean> {
  return isSupported((await $.session.version()).version) && switchOn(await $.env.get('CC_SECRET_PROMPT'), options.cc_secret_prompt !== false)
}

function patternsOf($: EngineInterface): Promise<Pattern[] | null> {
  const path = `${$.plugin.root}/hooks/patterns.tsv`

  patterns ??= $.fs
    .read(path)
    .then(parsePatterns)
    .catch((error: unknown) => {
      try {
        $.ui.log(`The prompt guard is off: ${path}: ${error instanceof Error ? error.message : String(error)}`)
      } catch {
        // A refused log line changes nothing: prompts already pass through.
      }

      return null
    })

  return patterns
}

async function promptPatterns($: EngineInterface, options: PluginOptions): Promise<Pattern[] | null> {
  draftPatterns = (await isOn($, options)) ? await patternsOf($) : null

  return draftPatterns
}

function questionOf(labels: string[]): string {
  return `Your prompt holds ${labels.join(', ')}. Mask it as [REDACTED:<label>] before it is sent, so Claude never reads the value?`
}

function commandQuestionOf(labels: string[]): string {
  return `This command's arguments hold ${labels.join(', ')}, and command arguments cannot be masked. Send it as typed?`
}

function keptBackOf(labels: string[]): string {
  return `secret-scanning kept your prompt back: it holds ${labels.join(', ')}. Press Up to edit it.`
}

function toastQuietly($: EngineInterface, text: () => string): void {
  try {
    $.ui.toast(text())
  } catch {
    // A failed count or refused toast leaves the redaction standing; the toast is display only.
  }
}

export function register(on: On, options: PluginOptions) {
  // prompt-coach finds this hook in its session.start trace to tell whether a prompt is masked before its judge reads it.
  on('session.start', async ($, e, next) => {
    await promptPatterns($, options)

    return next(e)
  }).catch(($, e, next) => next(e))

  // Paint only: a span the editor shows marked is still sent unless the check at submit masks it. A recalled draft stays
  // unpainted: prompt.change (CLI 2.1.300) only observes, and naming it stops this module loading on older CLIs.
  on('prompt.edit', async ($, e, next) => {
    const r = await next(e)
    const pats = draftPatterns
    const spans = pats === null ? [] : secretSpans(r.text.slice(0, DRAFT_SCAN_MAX), pats)

    if (spans.length === 0) {
      return r
    }

    return { ...r, decorations: [...(r.decorations ?? []), ...spans.map(span => ({ ...span, ...DRAFT_STYLE }))] }
  }).catch(($, e, next) => next(e))

  // A classic UserPromptSubmit hook can refuse a prompt but not rewrite it; this one masks it on the way in.
  // The host leaks around it below its fixes: before CLI 2.1.295 a masked or dropped prompt is still saved as typed to history
  // and the transcript queue, before 2.1.296 Esc mid-check sends it unchecked, before 2.1.299 an image can drop the mask, before
  // 2.1.300 the session title and the OpenTelemetry user_prompt get it as typed. Kept on from MODS_FLOOR: off below each fix,
  // every path would leak instead of one.
  on('prompt.submit', async ($, e, next) => {
    if (!TYPED.has(e.origin.kind)) {
      return next(e)
    }

    const pats = await promptPatterns($, options)
    const found = pats === null ? null : redact(e.text, pats)

    if (found === null || found.labels.length === 0) {
      return next(e)
    }

    // command.run expanded the arguments before this hook, so a rewrite here never reaches the model; a drop still does.
    if (COMMAND.test(e.text)) {
      const sent = await $.ui.ask(commandQuestionOf(found.labels), [SEND_AS_TYPED, CANCEL]).catch(() => CANCEL)

      return sent === SEND_AS_TYPED ? next(e) : { drop: keptBackOf(found.labels) }
    }

    // Dismissed, "Chat about this", free text, or nobody to ask (-p): the mask stands, never the secret.
    const choice = await $.ui.ask(questionOf(found.labels), [MASK_AND_SEND, SEND_AS_TYPED, CANCEL]).catch(() => MASK_AND_SEND)

    if (choice === SEND_AS_TYPED) {
      return next(e)
    }

    if (choice === CANCEL) {
      return { drop: keptBackOf(found.labels) }
    }

    return next({ ...e, text: found.value })
  }).catch(async ($, e, next) => {
    // The draft cache is null when the session.start load failed; the shared load may still hold the patterns.
    const pats = draftPatterns ?? (patterns === undefined ? null : await patterns)

    if (next.called || pats === null || !TYPED.has(e.origin.kind)) {
      return next(e)
    }

    let labels = ['text the check could not read']

    try {
      labels = redact(e.text, pats).labels
    } catch {
      // A prompt the scan throws on is kept back rather than sent unread.
    }

    return labels.length === 0
      ? next(e)
      : { drop: `${keptBackOf(labels)} Its secret check failed (${next.error.kind}); CC_SECRET_PROMPT=off sends prompts unchecked.` }
  })

  // An @-mention is read with no tool call, so no tool hook sees it: a secret in the file refuses the mention.
  on('prompt.mention', async ($, e, next) => {
    if (!(await isOn($, options))) {
      return next(e)
    }

    const pats = await patternsOf($)
    const text = pats === null ? null : await $.fs.read(e.path).catch(() => null)

    if (pats === null || text === null) {
      return next(e)
    }

    const found = redact(mentionedText(text, e.offset, e.limit), pats)

    if (found.labels.length === 0) {
      return next(e)
    }

    // The deny reason reaches only the debug log, so the person learns of the refusal from the toast.
    toastQuietly($, () => mentionToastOf(e.mention, found.labels))

    return { deny: `holds ${found.labels.join(', ')}` }
  }).catch(($, e, next) => {
    if (next.called) {
      return next(e)
    }

    toastQuietly($, () => `secret-scanning kept @${e.mention} out of your prompt: its scan failed. CC_SECRET_PROMPT=off turns this off.`)

    return { deny: 'the secret scan failed' }
  })

  // The text the engine attached, which the mention check above cannot always read (over 4 MiB, a notebook's decoded cells), and a file changed outside the session.
  on('prompt.attachment', { type: /^(?:file|already_read_file|edited_text_file)$/ }, async ($, e, next) => {
    const r = await next(e)

    if (r.text === null || !(await isOn($, options))) {
      return r
    }

    const pats = await patternsOf($)
    const found = pats === null ? null : redact(r.text, pats)

    if (found === null || found.labels.length === 0) {
      return r
    }

    const count = maskCount(found.value) - maskCount(r.text)

    toastQuietly($, () => toastOf(count, 'an attached file', found.labels))

    return { text: `${found.value}\n${attachedNoteOf(found.labels)}` }
  }).catch(($, e, next) => {
    // Once the file was read, an unredacted attachment is worse than none.
    if (!next.called) {
      return next(e)
    }

    toastQuietly($, () => 'secret-scanning left an attached file out: its redaction failed. CC_SECRET_PROMPT=off turns this off.')

    return { text: null }
  })
}
