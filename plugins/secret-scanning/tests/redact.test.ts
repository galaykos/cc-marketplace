import type { Args, On, ResultOf, ToolCallArgs } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

import { failureReason } from '../hooks/redact'
import { parsePatterns } from '../hooks/redact-core'

// Assembled at runtime: the write guard denies a file holding these literally.
const AWS = 'AKIA' + 'ABCDEFGHIJKLMNOP'
const AWS_OLD = 'AKIA' + 'QRSTUVWXYZ234567'
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

describe('redact', () => {
  test('masks an AWS key in Bash stdout', async ($, on) => {
    const world = seat(on, () => stdout(`id=${AWS}\nold=${AWS_OLD}`))

    const r = await $.tool.call({ tool: 'Bash', command: 'env' })

    expect(r).toEqual({
      result: { stdout: `id=${AWS_MASK}\nold=${AWS_MASK}`, stderr: '', interrupted: false },
      context: [expect.stringContaining('redacted an AWS access key ID from this Bash result')],
    })
    expect(r.context?.[0]).toEqual(NOTE)
    expect(world.toasts, 'count and label, never the value').toEqual(['Redacted 2 secrets from Bash: an AWS access key ID'])
  })

  test('masks a secret in Read content and keeps the rest of the record', async ($, on) => {
    const file = { filePath: '/work/.env', numLines: 2, startLine: 1, totalLines: 2 }

    seat(on, () => ({ result: { type: 'text', file: { ...file, content: `A=1\nGITHUB_TOKEN=${GH}` } } }))

    const r = await $.tool.call({ tool: 'Read', file_path: '/work/.env' })

    expect(r.result).toEqual({ type: 'text', file: { ...file, content: `A=1\nGITHUB_TOKEN=${GH_MASK}` } })
  })

  test("masks secrets nested in an MCP tool's result, labels in pattern-file order", async ($, on) => {
    const world = seat(on, () => ({
      result: { content: [{ type: 'text', text: `token ${GH}` }], meta: { items: [{ note: `aws ${AWS}` }] } },
    }))

    const r = await $.tool.call({ tool: 'mcp__vault__fetch', id: 7 })

    expect(r.result).toEqual({
      content: [{ type: 'text', text: `token ${GH_MASK}` }],
      meta: { items: [{ note: `aws ${AWS_MASK}` }] },
    })
    expect(r.context).toEqual([expect.stringContaining('redacted an AWS access key ID, a GitHub token from')])
    expect(world.toasts).toEqual(['Redacted 2 secrets from mcp__vault__fetch: an AWS access key ID, a GitHub token'])
  })

  test('leaves base64 media bytes untouched beside masked text', async ($, on) => {
    const bytes = `iVBORw0KGgo${AWS}AAAA`
    const media = {
      blocks: [
        { type: 'image', data: bytes, mimeType: 'image/png' },
        { type: 'image', source: { type: 'base64', media_type: 'image/png', data: bytes } },
      ],
      file: { base64: `${bytes}\r\n${bytes}`, type: 'image/png' },
    }

    const world = seat(on, () => ({ result: { ...media, text: AWS } }))

    const r = await $.tool.call({ tool: 'mcp__browser__shot' })

    expect(r.result).toEqual({ ...media, text: AWS_MASK })
    expect(world.toasts).toEqual(['Redacted 1 secret from mcp__browser__shot: an AWS access key ID'])
  })

  test('scans a media-named field holding text or a textual mime type', async ($, on) => {
    seat(on, () => ({
      result: [
        { type: 'resource', mimeType: 'text/plain', data: `GITHUB_TOKEN=${GH}` },
        { type: 'resource', media_type: 'application/x-pem-file', data: PEM },
        { type: 'resource', mimeType: 'application/json', data: AWS },
        { type: 'image', mimeType: 'image/png', data: `note: ${AWS}` },
        { type: 'resource', mimeType: 'application/octet-stream', data: `export AWSKEY=${AWS}` },
        { type: 'resource', mimeType: 'application/octet-stream', data: `KEY=${AWS}` },
        { type: 'resource', mimeType: 'application/x-sh', data: `export AWS_ACCESS_KEY_ID=${AWS}\n` },
        { type: 'resource', mimeType: 'application/yaml', data: `aws:\n  key: ${AWS}` },
      ],
    }))

    const r = await $.tool.call({ tool: 'mcp__files__get' })

    expect(r.result).toEqual([
      { type: 'resource', mimeType: 'text/plain', data: `GITHUB_TOKEN=${GH_MASK}` },
      { type: 'resource', media_type: 'application/x-pem-file', data: '[REDACTED:a private key block]' },
      { type: 'resource', mimeType: 'application/json', data: AWS_MASK },
      { type: 'image', mimeType: 'image/png', data: `note: ${AWS_MASK}` },
      { type: 'resource', mimeType: 'application/octet-stream', data: `export AWSKEY=${AWS_MASK}` },
      { type: 'resource', mimeType: 'application/octet-stream', data: `KEY=${AWS_MASK}` },
      { type: 'resource', mimeType: 'application/x-sh', data: `export AWS_ACCESS_KEY_ID=${AWS_MASK}\n` },
      { type: 'resource', mimeType: 'application/yaml', data: `aws:\n  key: ${AWS_MASK}` },
    ])
  })

  test('carries a secret-free context from a hook beneath verbatim while redacting the result', async ($, on) => {
    const below = ['a reminder from below', 'another reminder']

    seat(on, () => ({ ...stdout(AWS), context: below }))

    const r = await $.tool.call({ tool: 'Bash', command: 'env' })

    expect(r.result).toEqual({ stdout: AWS_MASK, stderr: '', interrupted: false })
    expect(r.context).toEqual([...below, NOTE])
  })

  test('withholds a result whose context from a hook beneath holds a secret', async ($, on) => {
    const below = ['a reminder from below', `a reminder quoting ${GH}`]

    const world = seat(on, e =>
      e.tool === 'Bash'
        ? { ...stdout(AWS), text: `mapped ${AWS}`, context: below }
        : { result: { note: `aws ${AWS}` }, context: below },
    )

    const viaCore = await $.tool.call({ tool: 'Bash', command: 'env' })
    const viaHook = await $.tool.call({ tool: 'mcp__vault__fetch' })

    expect(viaCore.deny, 'the text the model would have read').toMatch(/^mapped \[REDACTED:an AWS access key ID\]\n/)
    expect(viaHook.deny, 'a result with no text, serialised').toMatch(/^\{"note":"aws \[REDACTED:an AWS access key ID\]"\}\n/)

    for (const deny of [viaCore.deny, viaHook.deny]) {
      expect(deny).toEqual(expect.stringContaining('holds a GitHub token'))
      expect(deny).toEqual(expect.stringContaining('CC_SECRET_REDACT=off'))
      expect(deny).toEqual(NOTE)
      expect(deny?.includes(AWS) || deny?.includes(GH), 'no raw secret').toBe(false)
    }

    expect(world.toasts[0]).toBe('Redacted 2 secrets from Bash: an AWS access key ID, a GitHub token')
  })

  test('answers an errored result holding a secret with a redacted deny', async ($, on) => {
    const clean = { isError: true, result: 'exit 1: nothing found', text: 'exit 1: nothing found' } as const

    const world = seat(on, e =>
      e.tool === 'Bash' ? { isError: true, result: `exit 1: ${AWS}`, text: `exit 1: ${AWS}` } : clean,
    )

    const r = await $.tool.call({ tool: 'Bash', command: 'aws sts' })

    expect(r.deny).toMatch(/^exit 1: \[REDACTED:an AWS access key ID\]\n/)
    expect(r.deny).toEqual(NOTE)
    expect(world.toasts).toEqual(['Redacted 1 secret from Bash: an AWS access key ID'])

    expect(await $.tool.call({ tool: 'WebFetch', url: 'https://example.invalid', prompt: 'x' }), 'no match: as received').toEqual(clean)
  })

  test('withholds an errored result whose context or stored result holds a secret', async ($, on) => {
    seat(on, e =>
      e.tool === 'Bash'
        ? { isError: true, result: 'exit 1', text: 'exit 1', context: [`token ${GH}`] }
        : { isError: true, result: `exit 1: ${AWS}`, text: 'exit 1' },
    )

    const fromContext = await $.tool.call({ tool: 'Bash', command: 'gh auth status' })
    const fromResult = await $.tool.call({ tool: 'WebFetch', url: 'https://example.invalid', prompt: 'x' })

    for (const r of [fromContext, fromResult]) {
      expect(r.deny).toMatch(/^exit 1\n/)
      expect(r.deny?.includes(AWS) || r.deny?.includes(GH), 'no raw secret').toBe(false)
      expect(r.context).toBeUndefined()
    }
  })

  test('refuses a write carrying a [REDACTED: token', async ($, on) => {
    const world = seat(on, () => ({ result: 'written' }))
    const placeholder = `KEY=${AWS_MASK}`

    // MultiEdit is not a built-in tool of CLI 2.1.291, so its input is typed loosely.
    const writes: readonly ToolCallArgs[] = [
      { tool: 'Write', file_path: '/work/.env', content: placeholder },
      { tool: 'Edit', file_path: '/work/.env', old_string: 'KEY=', new_string: placeholder },
      {
        tool: 'MultiEdit',
        file_path: '/work/.env',
        edits: [
          { old_string: 'A', new_string: 'B' },
          { old_string: 'KEY=', new_string: placeholder },
        ],
      } as unknown as ToolCallArgs,
      { tool: 'NotebookEdit', notebook_path: '/work/n.ipynb', new_source: placeholder },
    ]

    for (const write of writes) {
      const r = await $.tool.call(write)

      expect(r.deny, write.tool).toBe(
        `${write.tool} refused: the new text contains the redaction marker ${'[REDACTED' + ':'}…]. It may have come ` +
          'from a tool result secret-scanning redacted; if so, writing it would replace the real value on disk, so ' +
          'leave the value out of the edit. If the text quotes the marker on purpose, ask the user to set ' +
          'CC_SECRET_REDACT=off, which also stops redacting secrets in tool output, then read again any file whose ' +
          'result was redacted before writing its values.',
      )
    }

    expect(world.ran, 'no refused write ran').toEqual([])

    await $.tool.call({ tool: 'Write', file_path: '/work/.env', content: 'KEY=${AWS_KEY}' })

    expect(world.ran, 'a write without the token runs').toEqual(['Write'])
  })

  test('leaves a placeholder value alone', async ($, on) => {
    const received = { ...stdout(`documented key ${AWS_DOC}`), text: `documented key ${AWS_DOC}` } as const
    const world = seat(on, () => received)

    expect(await $.tool.call({ tool: 'Bash', command: 'cat README' })).toEqual(received)
    expect(world.toasts).toEqual([])
  })

  test('keeps the redaction when the toast is refused', async ($, on) => {
    const world = seat(on, () => stdout(AWS), { refuseToast: true })

    const r = await $.tool.call({ tool: 'Bash', command: 'env' })

    expect(world.toasts, 'the toast was asked for').toHaveLength(1)
    expect(r.result).toEqual({ stdout: AWS_MASK, stderr: '', interrupted: false })
  })

  test('passes everything through under CC_SECRET_REDACT=off', async ($, on) => {
    const world = seat(on, () => stdout(AWS), { env: { CC_SECRET_REDACT: 'off' } })

    expect(await $.tool.call({ tool: 'Bash', command: 'env' })).toEqual(stdout(AWS))

    await $.tool.call({ tool: 'Write', file_path: '/work/.env', content: `KEY=${AWS_MASK}` })

    expect(world.ran).toEqual(['Bash', 'Write'])
  })

  test('passes everything through with cc_secret_redact off in /config', { options: { cc_secret_redact: false } }, async ($, on) => {
    const world = seat(on, () => stdout(AWS))

    expect(await $.tool.call({ tool: 'Bash', command: 'env' })).toEqual(stdout(AWS))

    await $.tool.call({ tool: 'Write', file_path: '/work/.env', content: `KEY=${AWS_MASK}` })

    expect(world.ran).toEqual(['Bash', 'Write'])
  })

  test('returns a result with no secret as received', async ($, on) => {
    const received = { ...stdout('nothing to see'), text: 'nothing to see', context: ['from below'] } as const
    const world = seat(on, () => received)

    expect(await $.tool.call({ tool: 'Bash', command: 'ls' })).toEqual(received)
    expect(world.toasts).toEqual([])
  })

  test('passes everything through below CLI 2.1.291', async ($, on) => {
    const world = seat(on, () => stdout(AWS), { version: '2.1.290' })

    expect(await $.tool.call({ tool: 'Bash', command: 'env' })).toEqual(stdout(AWS))

    await $.tool.call({ tool: 'Write', file_path: '/work/.env', content: `KEY=${AWS_MASK}` })

    expect(world.ran).toEqual(['Bash', 'Write'])
    expect(world.reads, 'the pattern file is never read').toEqual([])
  })

  test("reads the plugin's pattern file once", async ($, on) => {
    const world = seat(on, () => stdout(AWS))

    await $.tool.call({ tool: 'Bash', command: 'env' })
    await $.tool.call({ tool: 'Bash', command: 'env' })

    expect(world.reads).toEqual([expect.stringMatching(/\/secret-scanning\/hooks\/patterns\.tsv$/)])
  })

  test('logs a pattern file that fails to load, once, and passes output through', async ($, on) => {
    const world = seat(on, () => stdout(AWS), { patterns: 'secret\tan AWS access key ID\t-' })

    expect(await $.tool.call({ tool: 'Bash', command: 'env' })).toEqual(stdout(AWS))
    expect(await $.tool.call({ tool: 'Bash', command: 'env' })).toEqual(stdout(AWS))
    expect(world.logs).toEqual([expect.stringContaining('patterns.tsv: line 1 has 3 fields, not 4')])
  })

  test('keeps the redaction when the toast count fails', async ($, on) => {
    const world = seat(on, () => ({ result: { rows: 10n, note: `aws ${AWS}` } }))

    const r = await $.tool.call({ tool: 'mcp__db__query' })

    expect(r.result).toEqual({ rows: 10n, note: `aws ${AWS_MASK}` })
    expect(world.toasts, 'a BigInt stops the count, so no toast').toEqual([])
  })

  test('withholds the output when redaction fails after the tool ran', async ($, on) => {
    const looped: Record<string, unknown> = { note: `aws ${AWS}` }

    looped.self = looped
    seat(on, () => ({ result: looped }))

    const r = await $.tool.call({ tool: 'mcp__db__query' })

    expect(r.deny).toBe(
      'secret-scanning withheld this mcp__db__query output: redaction failed (Maximum call stack size exceeded). ' +
        'CC_SECRET_REDACT=off turns redaction off.',
    )
    expect(r.deny?.includes(AWS), 'no raw secret').toBe(false)
  })

  test('a failed redaction names its message redacted, or only its kind while no patterns are loaded', () => {
    const pats = parsePatterns(PATTERNS)

    expect(failureReason({ kind: 'throw', message: `bad value ${AWS}.`, budget: 1000 }, pats)).toBe(`bad value ${AWS_MASK}`)
    expect(failureReason({ kind: 'throw', message: `bad value ${AWS}`, budget: 1000 }, null)).toBe('throw')
    expect(failureReason({ kind: 'timeout', budget: 1000 }, pats)).toBe('timeout')
  })

  test('passes the call through when the hook fails before the tool runs', async ($, on) => {
    const world = seat(on, () => stdout('ran'), { version: null })

    expect(await $.tool.call({ tool: 'Bash', command: 'ls' })).toEqual(stdout('ran'))
    expect(world.ran).toEqual(['Bash'])
  })
})

const ENV = '/work/.env'

const mention = (path: string, more: { offset?: number; limit?: number } = {}) => ({ mention: path.replace('/work/', ''), path, ...more })

describe('@-mentions', () => {
  test('refuses a mentioned file holding a secret and says why in a toast', async ($, on) => {
    const world = seat(on, () => stdout(''), { files: { [ENV]: `AWS_ACCESS_KEY_ID=${AWS}\n` } })

    expect(await $.prompt.mention(mention(ENV))).toEqual({ deny: 'holds an AWS access key ID' })
    expect(world.attached, 'nothing of the file is read for the prompt').toEqual([])
    expect(world.toasts).toEqual(['secret-scanning kept @.env out of your prompt: it holds an AWS access key ID. Claude can still Read it, with secrets masked.'])
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

  test('leaves a mention to the engine when the file cannot be read', async ($, on) => {
    const world = seat(on, () => stdout(''))

    expect(await $.prompt.mention(mention('/work/missing.txt'))).toEqual({ type: 'file' })
    expect(world.attached).toEqual(['/work/missing.txt'])
  })

  test('passes every mention through under CC_SECRET_REDACT=off', async ($, on) => {
    const world = seat(on, () => stdout(''), { env: { CC_SECRET_REDACT: 'off' }, files: { [ENV]: `KEY=${AWS}\n` } })

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
