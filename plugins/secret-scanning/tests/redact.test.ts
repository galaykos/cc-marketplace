import type { Args, On, ResultOf } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

import { parsePatterns, secretSpans } from '../hooks/redact-core'

// Assembled at runtime: the write guard denies a file holding these literally.
const AWS = 'AKIA' + 'ABCDEFGHIJKLMNOP'
const AWS_DOC = 'AKIA' + 'IOSFODNN7EXAMPLE'
const GH = 'ghp' + '_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij'
const PEM = [
  '-----BEGIN RSA PRIVATE ' + 'KEY-----',
  'MIIBOgIBAAJBAKj34GkxFhD90vcNLYLInFEX6Ppy1tPf9Cnzj4p4',
  '-----END RSA PRIVATE ' + 'KEY-----',
].join('\n')

const AWS_MASK = '[REDACTED:an AWS access key ID]'
const GH_MASK = '[REDACTED:a GitHub token]'

// The rows of hooks/patterns.tsv these cases need: a test has no file system, so the module's read is answered here.
const PATTERNS = [
  ['secret', 'an AWS access key ID', '-', 'AKIA[0-9A-Z]{16}'],
  ['secret', 'a private key block', '-', '-----BEGIN ([A-Z]+ )?PRIVATE ' + 'KEY-----'],
  ['secret', 'a GitHub token', '-', 'gh[pousr]_[A-Za-z0-9]{36,}'],
  ['placeholder', 'a placeholder word', 'i', 'example|placeholder|changeme|change-me|your[_-]|dummy|redacted|sample|fake|todo|xxxx'],
  ['placeholder', 'an EXAMPLE suffix', 'i', 'example$'],
]
  .map(row => row.join('\t'))
  .join('\n')

type Answer = (e: Args<'tool.call'>) => ResultOf['tool.call']

type Live = {
  version?: string | null
  env?: Record<string, string>
  patterns?: string
  refuseToast?: boolean
  files?: Record<string, string>
}

function seat(on: On, answer: Answer, live: Live = {}) {
  const world = { ran: [] as string[], reads: [] as string[], toasts: [] as string[], logs: [] as string[], attached: [] as string[] }

  mock.env(on, live.env ?? {})

  if (live.version !== null) {
    on('session.version', () => ({ value: { version: live.version ?? '2.1.291' } }))
  }

  on('fs.read', ($, e) => {
    world.reads.push(e.path)

    if (e.path.endsWith('/hooks/patterns.tsv')) {
      return { value: live.patterns ?? PATTERNS }
    }

    const text = live.files?.[e.path]

    return text === undefined ? { deny: `ENOENT: ${e.path}` } : { value: text }
  })

  on('prompt.mention', ($, e) => {
    world.attached.push(e.path)

    return { type: 'file' }
  })

  on('prompt.attachment', ($, e) => ({ text: e.text }))

  on('ui.toast', ($, e) => {
    world.toasts.push(e.text)

    return live.refuseToast ? { deny: 'toasts are off' } : { value: undefined }
  })

  on('ui.log', ($, e) => {
    world.logs.push(e.text)

    return { value: undefined }
  })

  on('tool.call', ($, e) => {
    world.ran.push(e.tool)

    return answer(e)
  })

  return world
}

const stdout = (text: string) => ({ result: { stdout: text, stderr: '', interrupted: false } })

const NOTE = expect.stringContaining('Never write a [REDACTED:')

// Code Mode refuses to start with a mod that hooks tool calls (since 0.19.0 tool output is flagged by hooks/output-scan.sh).
describe('tool calls', () => {
  test('pass through untouched: no output masking, no write refusal', async ($, on) => {
    const world = seat(on, e => (e.tool === 'Bash' ? stdout(`key ${AWS}`) : { result: 'written' }))

    expect(await $.tool.call({ tool: 'Bash', command: 'cat .env' })).toEqual(stdout(`key ${AWS}`))
    expect(await $.tool.call({ tool: 'Write', file_path: '/work/a.env', content: `KEY=${AWS_MASK}` })).toEqual({ result: 'written' })
    expect([world.ran, world.toasts, world.reads]).toEqual([['Bash', 'Write'], [], []])
  })
})

const ENV = '/work/.env'

const mention = (path: string, more: { offset?: number; limit?: number } = {}) => ({ mention: path.replace('/work/', ''), path, ...more })

describe('@-mentions', () => {
  test('refuses a mentioned file holding a secret and says why in a toast', async ($, on) => {
    const world = seat(on, () => stdout(''), { files: { [ENV]: `AWS_ACCESS_KEY_ID=${AWS}\n` } })

    expect(await $.prompt.mention(mention(ENV))).toEqual({ deny: 'holds an AWS access key ID' })
    expect(world.attached, 'nothing of the file is read for the prompt').toEqual([])
    expect(world.toasts).toEqual(['secret-scanning kept @.env out of your prompt: it holds an AWS access key ID. Claude can still Read it, unmasked; secret-scanning then flags the secret by its label.'])
  })

  test('attaches a file with no secret, or only a placeholder', async ($, on) => {
    const world = seat(on, () => stdout(''), { files: { '/work/a.ts': 'export const x = 1\n', '/work/b.env': `KEY=${AWS_DOC}\n` } })

    expect(await $.prompt.mention(mention('/work/a.ts'))).toEqual({ type: 'file' })
    expect(await $.prompt.mention(mention('/work/b.env'))).toEqual({ type: 'file' })
    expect([world.attached, world.toasts]).toEqual([['/work/a.ts', '/work/b.env'], []])
  })

  test('judges only the lines a mention names', async ($, on) => {
    const world = seat(on, () => stdout(''), { files: { [ENV]: ['# keys', 'REGION=eu-west-1', `TOKEN=${GH}`, ''].join('\n') } })

    expect(await $.prompt.mention(mention(ENV, { offset: 1, limit: 2 })), 'the secret sits on line 3').toEqual({ type: 'file' })
    expect(await $.prompt.mention(mention(ENV, { offset: 3, limit: 1 }))).toEqual({ deny: 'holds a GitHub token' })
    expect(world.attached).toEqual([ENV])
  })

  test('an offset or limit below 1 widens the scan instead of narrowing it', async ($, on) => {
    const world = seat(on, () => stdout(''), { files: { [ENV]: [`KEY=${AWS}`, 'REGION=eu-west-1', ''].join('\n') } })

    expect(await $.prompt.mention(mention(ENV, { offset: 0 }))).toEqual({ deny: 'holds an AWS access key ID' })
    expect(await $.prompt.mention(mention(ENV, { offset: 1, limit: 0 }))).toEqual({ deny: 'holds an AWS access key ID' })
    expect(world.attached).toEqual([])
  })

  test('leaves a mention to the engine when the file cannot be read', async ($, on) => {
    const world = seat(on, () => stdout(''))

    expect(await $.prompt.mention(mention('/work/missing.txt'))).toEqual({ type: 'file' })
    expect(world.attached).toEqual(['/work/missing.txt'])
  })

  test('passes every mention through under CC_SECRET_PROMPT=off', async ($, on) => {
    const world = seat(on, () => stdout(''), { env: { CC_SECRET_PROMPT: 'off' }, files: { [ENV]: `KEY=${AWS}\n` } })

    expect(await $.prompt.mention(mention(ENV))).toEqual({ type: 'file' })
    expect(world.toasts).toEqual([])
  })

  test('refuses the mention when the scan itself fails', async ($, on) => {
    const world = seat(on, () => stdout(''), { files: { [ENV]: `KEY=${AWS}\n` }, version: null })

    on('session.version', () => {
      throw new Error('version unreadable')
    })

    expect(await $.prompt.mention(mention(ENV))).toEqual({ deny: 'the secret scan failed' })
    expect(world.attached).toEqual([])
  })
})

const attach = (text: string, type = 'file') => ({ type, text, origin: { kind: 'engine' as const } })

describe('attached files', () => {
  test('masks a secret in a mentioned file the engine attached', async ($, on) => {
    const world = seat(on, () => stdout(''))
    const r = await $.prompt.attachment(attach(`Contents of /work/big.log:\nline 12 token ${GH}\n`))

    expect(r.text).toContain(`line 12 token ${GH_MASK}`)
    expect(r.text).not.toContain(GH)
    expect(r.text).toEqual(NOTE)
    expect(world.toasts).toEqual(['Redacted 1 secret from an attached file: a GitHub token'])
  })

  test('masks a file changed outside the session', async ($, on) => {
    seat(on, () => stdout(''))

    expect((await $.prompt.attachment(attach(`+AWS_ACCESS_KEY_ID=${AWS}`, 'edited_text_file'))).text).toContain(AWS_MASK)
  })

  test('leaves a clean file, a placeholder and other attachment kinds as they are', async ($, on) => {
    const world = seat(on, () => stdout(''))

    expect((await $.prompt.attachment(attach('export const x = 1'))).text).toBe('export const x = 1')
    expect((await $.prompt.attachment(attach(`KEY=${AWS_DOC}`))).text).toBe(`KEY=${AWS_DOC}`)
    expect((await $.prompt.attachment(attach(`echo ${AWS}`, 'todo_reminder'))).text, 'not a file').toBe(`echo ${AWS}`)
    expect(world.toasts).toEqual([])
  })

  test('leaves the attachment out when its redaction fails after the read', async ($, on) => {
    const world = seat(on, () => stdout(''), { version: null })

    on('session.version', () => {
      throw new Error('version unreadable')
    })

    expect((await $.prompt.attachment(attach(`KEY=${AWS}`))).text).toBeNull()
    expect(world.toasts).toEqual(['secret-scanning left an attached file out: its redaction failed. CC_SECRET_PROMPT=off turns this off.'])
  })

  test('passes attachments through under CC_SECRET_PROMPT=off', async ($, on) => {
    seat(on, () => stdout(''), { env: { CC_SECRET_PROMPT: 'off' } })

    expect((await $.prompt.attachment(attach(`KEY=${AWS}`))).text).toBe(`KEY=${AWS}`)
  })
})


const MASK_AND_SEND = 'Mask and send'
const KEPT_BACK = 'secret-scanning kept your prompt back: it holds a GitHub token. Press Up to edit it.'
const STYLE = { color: 'error', underline: true }

type Asked = { question: string; options: string[] }

// What the person picks in the AskUserQuestion dialog $.ui.ask raises, or null when the dialog is dismissed.
function seatPrompt(on: On, pick: string | null, live: Live = {}) {
  const asked: Asked[] = []
  const sent: Args<'prompt.submit'>[] = []

  const world = seat(
    on,
    e => {
      if (e.tool !== 'AskUserQuestion') {
        return stdout('')
      }

      const [q] = (e as unknown as { questions: { question: string; options: { label: string }[] }[] }).questions

      asked.push({ question: q?.question ?? '', options: (q?.options ?? []).map(option => option.label) })

      return pick === null ? { deny: 'dismissed' } : { result: { answers: { [q?.question ?? '']: pick } } }
    },
    live,
  )

  on('session.start', () => ({ cwd: '/work' }))

  on('prompt.edit', ($, e) => {
    const text = e.text.slice(0, e.start) + e.inputText + e.text.slice(e.end)

    return { text, cursor: e.start + e.inputText.length }
  })

  on('prompt.submit', ($, e) => {
    sent.push(e)

    return { text: e.text }
  })

  return { ...world, asked, sent }
}

const paste = (text: string, inputText: string) => ({
  origin: { kind: 'composer' as const },
  text,
  cursor: text.length,
  start: text.length,
  end: text.length,
  inputText,
})

const typed = (text: string, kind: 'composer' | 'sdk' = 'composer') => ({ text, wait: false, origin: { kind } })

const start = { surface: 'terminal' as const, isInteractive: true, cwd: '/work' }

describe('prompt box', () => {
  test('paints each secret in the draft, and nothing in a clean draft or a placeholder', async ($, on) => {
    seatPrompt(on, MASK_AND_SEND)

    await $.session.start(start)

    const r = await $.prompt.edit(paste('deploy with ', `${GH} and ${AWS}`))
    const awsAt = `deploy with ${GH} and `.length

    expect(r.text).toBe(`deploy with ${GH} and ${AWS}`)
    expect(r.decorations).toEqual([
      { start: 12, end: 12 + GH.length, ...STYLE },
      { start: awsAt, end: awsAt + AWS.length, ...STYLE },
    ])
    expect((await $.prompt.edit(paste('nothing ', 'here'))).decorations).toBeUndefined()
    expect((await $.prompt.edit(paste('key ', AWS_DOC))).decorations, 'a placeholder').toBeUndefined()
  })

  test('paints a draft past the scan cap only up to it', async ($, on) => {
    seatPrompt(on, MASK_AND_SEND)

    await $.session.start(start)

    const filler = 'x '.repeat(50_005)
    const r = await $.prompt.edit(paste(`${GH} `, `${filler}${GH}`))

    expect(r.text.length).toBeGreaterThan(100_000)
    expect(r.decorations, 'the second token starts past 100,000 characters').toEqual([{ start: 0, end: GH.length, ...STYLE }])
  })

  test('Mask and send replaces each secret with its marker', async ($, on) => {
    const world = seatPrompt(on, MASK_AND_SEND)

    const r = await $.prompt.submit(typed(`deploy with ${GH} and ${AWS}`))

    expect(world.sent.map(e => e.text)).toEqual([`deploy with ${GH_MASK} and ${AWS_MASK}`])
    expect(r.text).toBe(`deploy with ${GH_MASK} and ${AWS_MASK}`)
    expect(world.asked).toEqual([
      {
        question:
          'Your prompt holds an AWS access key ID, a GitHub token. Mask it as [REDACTED:<label>] before it is sent, so Claude never reads the value?',
        options: ['Mask and send', 'Send as typed', 'Cancel'],
      },
    ])
  })

  test('Send as typed sends the text unchanged', async ($, on) => {
    const world = seatPrompt(on, 'Send as typed')

    await $.prompt.submit(typed(`token ${GH}`))

    expect(world.sent.map(e => e.text)).toEqual([`token ${GH}`])
  })

  test('Cancel drops the prompt and sends nothing', async ($, on) => {
    const world = seatPrompt(on, 'Cancel')

    expect(await $.prompt.submit(typed(`token ${GH}`))).toEqual({ drop: KEPT_BACK })
    expect(world.sent).toEqual([])
  })

  test('a dismissed question, free text, or a -p run with nobody to ask sends the masked text', async ($, on) => {
    const world = seatPrompt(on, null)

    await $.prompt.submit(typed(`token ${GH}`))
    await $.prompt.submit(typed(`token ${GH}`, 'sdk'))

    expect(world.asked, 'both were asked').toHaveLength(2)
    expect(world.sent.map(e => e.text)).toEqual([`token ${GH_MASK}`, `token ${GH_MASK}`])
  })

  test('an answer typed under Other is not a label, so the mask stands', async ($, on) => {
    const world = seatPrompt(on, 'just send it')

    await $.prompt.submit(typed(`token ${GH}`))

    expect(world.sent.map(e => e.text)).toEqual([`token ${GH_MASK}`])
  })

  test('a command holding a secret is offered only Send as typed or Cancel, and sent unchanged on Send', async ($, on) => {
    const world = seatPrompt(on, 'Send as typed')

    await $.prompt.submit(typed(`/deploy --token ${GH}`))

    expect(world.asked).toEqual([
      {
        question: "This command's arguments hold a GitHub token, and command arguments cannot be masked. Send it as typed?",
        options: ['Send as typed', 'Cancel'],
      },
    ])
    expect(world.sent.map(e => e.text)).toEqual([`/deploy --token ${GH}`])
  })

  test('a command holding a secret is dropped on Cancel, never masked', async ($, on) => {
    const cancelled = seatPrompt(on, 'Cancel')

    expect(await $.prompt.submit(typed(`/deploy --token ${GH}`))).toEqual({ drop: KEPT_BACK })
    expect(cancelled.asked[0]?.options, 'no Mask option is offered for a command').toEqual(['Send as typed', 'Cancel'])
    expect(cancelled.sent).toEqual([])
  })

  test('a dismissed question drops a command holding a secret', async ($, on) => {
    const world = seatPrompt(on, null)

    expect(await $.prompt.submit(typed(`/deploy --token ${GH}`, 'sdk'))).toEqual({ drop: KEPT_BACK })
    expect(world.sent).toEqual([])
  })

  test('a prompt opening with a path is a plain prompt, so its secret is masked', async ($, on) => {
    const world = seatPrompt(on, MASK_AND_SEND)

    await $.prompt.submit(typed(`/tmp/notes has ${GH}`))

    expect(world.asked[0]?.options).toEqual(['Mask and send', 'Send as typed', 'Cancel'])
    expect(world.sent.map(e => e.text)).toEqual([`/tmp/notes has ${GH_MASK}`])
  })

  test('a Remote Control message is checked like one typed here', async ($, on) => {
    const world = seatPrompt(on, MASK_AND_SEND)

    await $.prompt.submit({ text: `token ${GH}`, wait: false, origin: { kind: 'bridge' } })

    expect(world.sent.map(e => e.text)).toEqual([`token ${GH_MASK}`])
  })

  test('a clean prompt is sent without a question', async ($, on) => {
    const world = seatPrompt(on, 'Cancel')

    await $.prompt.submit(typed(`key ${AWS_DOC}, nothing else`))

    expect([world.asked, world.sent.map(e => e.text)]).toEqual([[], [`key ${AWS_DOC}, nothing else`]])
  })

  test('a prompt the person did not type passes untouched', async ($, on) => {
    const world = seatPrompt(on, 'Cancel')

    await $.prompt.submit({ text: `token ${GH}`, wait: false, origin: { kind: 'plugin', name: 'other' } })
    await $.prompt.submit({ text: `token ${GH}`, wait: false, origin: { kind: 'task-notification' } })

    expect([world.asked, world.sent.map(e => e.text)]).toEqual([[], [`token ${GH}`, `token ${GH}`]])
  })

  test('CC_SECRET_PROMPT=off leaves the draft and the prompt alone', async ($, on) => {
    const world = seatPrompt(on, 'Cancel', { env: { CC_SECRET_PROMPT: 'off' } })

    await $.session.start(start)

    expect((await $.prompt.edit(paste('token ', GH))).decorations).toBeUndefined()

    await $.prompt.submit(typed(`token ${GH}`))

    expect([world.asked, world.sent.map(e => e.text)]).toEqual([[], [`token ${GH}`]])
  })

  test('cc_secret_prompt off in /config leaves the draft and the prompt alone', { options: { cc_secret_prompt: false } }, async ($, on) => {
    const world = seatPrompt(on, 'Cancel')

    await $.session.start(start)

    expect((await $.prompt.edit(paste('token ', GH))).decorations).toBeUndefined()

    await $.prompt.submit(typed(`token ${GH}`))

    expect([world.asked, world.sent.map(e => e.text)]).toEqual([[], [`token ${GH}`]])
  })

  test('CC_SECRET_PROMPT=on overrides cc_secret_prompt off', { options: { cc_secret_prompt: false } }, async ($, on) => {
    const world = seatPrompt(on, 'Cancel', { env: { CC_SECRET_PROMPT: 'on' } })

    expect(await $.prompt.submit(typed(`token ${GH}`))).toEqual({ drop: KEPT_BACK })
    expect(world.sent).toEqual([])
  })

  test('below CLI 2.1.291 the prompt box is untouched', async ($, on) => {
    const world = seatPrompt(on, 'Cancel', { version: '2.1.290' })

    await $.session.start(start)

    expect((await $.prompt.edit(paste('token ', GH))).decorations).toBeUndefined()

    await $.prompt.submit(typed(`token ${GH}`))

    expect([world.asked, world.sent.map(e => e.text), world.reads]).toEqual([[], [`token ${GH}`], []])
  })

  test('a failed check keeps back a prompt holding a secret and sends a clean one', async ($, on) => {
    let versions = 0

    const world = seatPrompt(on, MASK_AND_SEND, { version: null })

    on('session.version', () => {
      versions++

      if (versions > 1) {
        throw new Error('version unreadable')
      }

      return { value: { version: '2.1.291' } }
    })

    await $.session.start(start)

    const r = await $.prompt.submit(typed(`token ${GH}`))

    expect(r.drop).toBe(`${KEPT_BACK} Its secret check failed (throw); CC_SECRET_PROMPT=off sends prompts unchecked.`)

    await $.prompt.submit(typed('nothing secret'))

    expect([world.asked, world.sent.map(e => e.text)]).toEqual([[], ['nothing secret']])
  })

  test('a failed check with no session start still keeps the secret back, from the patterns an attached file loaded', async ($, on) => {
    let versions = 0

    const world = seatPrompt(on, MASK_AND_SEND, { version: null })

    on('session.version', () => {
      versions++

      if (versions > 1) {
        throw new Error('version unreadable')
      }

      return { value: { version: '2.1.291' } }
    })

    await $.prompt.attachment(attach('nothing secret'))

    const r = await $.prompt.submit(typed(`token ${GH}`))

    expect(r.drop).toBe(`${KEPT_BACK} Its secret check failed (throw); CC_SECRET_PROMPT=off sends prompts unchecked.`)
    expect(world.sent).toEqual([])
  })
})

describe('prompt box cost', () => {
  test('a 100 KB draft is scanned well inside the 50 ms prompt.edit budget', () => {
    const pats = parsePatterns(PATTERNS)
    const kinds = [
      (i: number) => `const value${i} = compute(${i}, "a string literal", { retries: 3, timeout: 1000 })`,
      (i: number) => `Paragraph ${i}: the api_key_name, secret_thing and password_field words appear without values.`,
      (i: number) => `2026-10-08T12:00:00Z INFO id=${'abc123'.repeat(4)} path=/v1/items/${i} status=200`,
      (i: number) => `export SECRET_${i}=\${SECRET_${i}}  # api-key token password https://user@host.invalid/path`,
    ]
    const lines: string[] = []

    for (let i = 0, size = 0; size < 100_000; i++) {
      const line = kinds[i % kinds.length]?.(i) ?? ''

      lines.push(line)
      size += line.length + 1
    }

    lines.splice(lines.length >> 1, 0, `GITHUB_TOKEN=${GH}`)

    const begin = PEM.split('\n')[0] ?? ''
    const drafts = { mixed: lines.join('\n'), 'key blocks without END': `${begin}\nMIIBOgIBAAJBAKj34GkxFhD9\n`.repeat(2500) }

    for (const [name, draft] of Object.entries(drafts)) {
      const runs: number[] = []

      for (let run = 0; run < 21; run++) {
        const at = performance.now()

        secretSpans(draft.slice(0, 100_000), pats)
        runs.push(performance.now() - at)
      }

      const median = runs.sort((a, b) => a - b)[10] ?? Infinity

      console.log(`prompt.edit scan, ${name}, ${draft.length} chars: median ${median.toFixed(2)} ms, max ${runs[20]?.toFixed(2)} ms`)
      expect(median, name).toBeLessThan(50)
    }

    expect(secretSpans(drafts.mixed, pats)).toHaveLength(1)
  })
})
