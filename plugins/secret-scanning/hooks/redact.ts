import type { EngineInterface, HookFailure, On, PluginOptions } from 'claude-code'

import { isSupported, switchOn } from './cc-kit'
import { parsePatterns, redact } from './redact-core'
import type { Pattern } from './redact-core'

const MASK = '[REDACTED:'

const BASE64 = /^[A-Za-z0-9+/]*={0,2}$/

const TEXT_MIME = /^text\/|json|xml|pem/i

const WRITE_BACK_BAN =
  'Never write a [REDACTED:…] placeholder back to a file: it would replace the real value, and Write, Edit, ' +
  'MultiEdit and NotebookEdit refuse it. Leave the value out of the edit instead.'

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (typeof value !== 'object' || value === null) {
    return false
  }

  const proto: unknown = Object.getPrototypeOf(value)

  return proto === Object.prototype || proto === null
}

function writtenTexts(input: Readonly<Record<string, unknown>>): unknown[] {
  switch (input.tool) {
    case 'Write':
      return [input.content]
    case 'Edit':
      return [input.new_string]
    case 'NotebookEdit':
      return [input.new_source]
    case 'MultiEdit':
      return Array.isArray(input.edits) ? input.edits.map(edit => (isPlainObject(edit) ? edit.new_string : null)) : []
    default:
      return []
  }
}

function isMediaBytes(holder: Record<string, unknown>, key: string, data: string): boolean {
  const mime = holder.media_type ?? holder.mimeType ?? holder.type
  const isNamed = key === 'base64' || (key === 'data' && ('media_type' in holder || 'mimeType' in holder))

  return isNamed && BASE64.test(data.replace(/[\r\n]/g, '')) && !(typeof mime === 'string' && TEXT_MIME.test(mime))
}

// Masking base64 bytes corrupts them; a mask is never base64-only, so the restore pass skips the same fields.
function swappedMedia(value: unknown, swap: (data: string) => string): unknown {
  if (Array.isArray(value)) {
    return value.map(item => swappedMedia(item, swap))
  }

  if (!isPlainObject(value)) {
    return value
  }

  const copy: Record<string, unknown> = Object.create(Object.getPrototypeOf(value))

  for (const [key, item] of Object.entries(value)) {
    const swapped = typeof item === 'string' && isMediaBytes(value, key, item) ? swap(item) : swappedMedia(item, swap)

    Object.defineProperty(copy, key, { value: swapped, enumerable: true, writable: true, configurable: true })
  }

  return copy
}

function maskCount(value: unknown): number {
  return (JSON.stringify(value) ?? '').split(MASK).length - 1
}

function toastOf(count: number, tool: string, labels: string[]): string {
  return `Redacted ${count} secret${count === 1 ? '' : 's'} from ${tool}: ${labels.join(', ')}`
}

function noteOf(tool: string, labels: string[]): string {
  return (
    `secret-scanning redacted ${labels.join(', ')} from this ${tool} result; each reads [REDACTED:<label>] here and ` +
    `is unchanged at its source. ${WRITE_BACK_BAN}`
  )
}

function withheldNoteOf(tool: string, labels: string[]): string {
  return (
    `secret-scanning withheld this ${tool} result as an error: context another plugin attached to the call holds ` +
    `${labels.join(', ')}, which cannot be redacted there. The text above is the result with its secrets masked. ` +
    `CC_SECRET_REDACT=off turns redaction off. ${WRITE_BACK_BAN}`
  )
}

export function failureReason(failure: HookFailure, pats: Pattern[] | null): string {
  return pats && failure.message !== undefined
    ? String(redact(failure.message, pats).value).replace(/\.$/, '')
    : failure.kind
}

function refusalOf(tool: string): string {
  return (
    `${tool} refused: the new text contains the redaction marker ${MASK}…]. It may have come from a tool result ` +
    'secret-scanning redacted; if so, writing it would replace the real value on disk, so leave the value out of the ' +
    'edit. If the text quotes the marker on purpose, ask the user to set CC_SECRET_REDACT=off, which also stops ' +
    'redacting secrets in tool output, then read again any file whose result was redacted before writing its values.'
  )
}

// The lines a mention names (#L10-20), or the whole file.
function mentionedText(text: string, offset: number | undefined, limit: number | undefined): string {
  if (offset === undefined) {
    return text
  }

  const lines = text.split('\n')

  return lines.slice(offset - 1, limit === undefined ? lines.length : offset - 1 + limit).join('\n')
}

function mentionToastOf(mention: string, labels: string[]): string {
  return `secret-scanning kept @${mention} out of your prompt: it holds ${labels.join(', ')}. Claude can still Read it, with secrets masked.`
}

let patterns: Promise<Pattern[] | null> | undefined

async function isOn($: EngineInterface, options: PluginOptions): Promise<boolean> {
  return isSupported((await $.session.version()).version) && switchOn(await $.env.get('CC_SECRET_REDACT'), options.cc_secret_redact !== false)
}

function patternsOf($: EngineInterface): Promise<Pattern[] | null> {
  const path = `${$.plugin.root}/hooks/patterns.tsv`

  patterns ??= $.fs
    .read(path)
    .then(parsePatterns)
    .catch((error: unknown) => {
      try {
        $.ui.log(`Output redaction is off: ${path}: ${error instanceof Error ? error.message : String(error)}`)
      } catch {
        // A refused log line changes nothing: output already passes through.
      }

      return null
    })

  return patterns
}

function toastQuietly($: EngineInterface, text: () => string): void {
  try {
    $.ui.toast(text())
  } catch {
    // A failed count or refused toast leaves the redaction standing; the toast is display only.
  }
}

export function register(on: On, options: PluginOptions) {
  // An @-mention is read with no tool.call, so the output redaction above never sees it; its text cannot be rewritten, only refused.
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

    toastQuietly($, () => `secret-scanning kept @${e.mention} out of your prompt: its scan failed. CC_SECRET_REDACT=off turns this off.`)

    return { deny: 'the secret scan failed' }
  })

  on('tool.call', async ($, e, next) => {
    if (!(await isOn($, options))) {
      return next(e)
    }

    if (writtenTexts(e).some(text => typeof text === 'string' && text.includes(MASK))) {
      return { deny: refusalOf(e.tool) }
    }

    const r = await next(e)

    if (r.deny !== undefined) {
      return r
    }

    const pats = await patternsOf($)

    if (!pats) {
      return r
    }

    if (r.isError) {
      const before = { text: r.text, result: r.result, context: r.context }
      const failure = redact(before, pats)

      if (failure.labels.length === 0) {
        return r
      }

      const after = failure.value as typeof before
      const maskedIn = (key: keyof typeof before) => maskCount(after[key]) - maskCount(before[key])

      // text and result usually carry one error twice, so its masks count once.
      toastQuietly($, () =>
        toastOf(Math.max(maskedIn('text'), maskedIn('result')) + maskedIn('context'), e.tool, failure.labels),
      )

      const errorText = after.text ?? (typeof after.result === 'string' ? after.result : '')

      return { deny: `${errorText}\n${noteOf(e.tool, failure.labels)}` }
    }

    const media: string[] = []

    const before = swappedMedia(r.result, data => {
      media.push(data)

      return ''
    })

    // CLI 2.1.291 skips a hook that changes a context entry from a hook beneath, so a secret there withholds the result.
    const below = redact(r.context ?? [], pats)

    if (below.labels.length > 0) {
      const text = r.text ?? (typeof before === 'string' ? before : (JSON.stringify(before) ?? ''))
      const shown = { text, context: r.context }
      const withheld = redact(shown, pats)

      toastQuietly($, () => toastOf(maskCount(withheld.value) - maskCount(shown), e.tool, withheld.labels))

      return { deny: `${(withheld.value as typeof shown).text}\n${withheldNoteOf(e.tool, below.labels)}` }
    }

    const found = redact(before, pats)

    if (found.labels.length === 0) {
      return r
    }

    toastQuietly($, () => toastOf(maskCount(found.value) - maskCount(before), e.tool, found.labels))

    return {
      result: swappedMedia(found.value, () => media.shift() ?? ''),
      context: [...(r.context ?? []), noteOf(e.tool, found.labels)],
    }
  }).catch(async ($, e, next) => {
    if (!next.called) {
      return next(e)
    }

    // The replay rejects as the call did when it failed beneath; only a failure in this hook's redaction withholds.
    await next(e)

    const reason = failureReason(next.error, patterns ? await patterns : null)

    return {
      deny:
        `secret-scanning withheld this ${e.tool} output: redaction failed (${reason}). ` +
        'CC_SECRET_REDACT=off turns redaction off.',
    }
  })
}
