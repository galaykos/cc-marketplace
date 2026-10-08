import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

import { hiddenOf, scoped } from '../hooks/listing'

const ROOT = '/work'

const HEAD = 'The following skills are available for use with the Skill tool:'

// Entries as the 2.1.294 listing rendered them in the live probe, one description wrapped onto two more lines.
const LISTING = [
  HEAD,
  '',
  '- ui-ux:audit: Audit UI code against WCAG 2.2 AA.',
  '- laravel:laravel-best-practices: Use when writing or reviewing Laravel code.',
  '- web-dev:nextjs-best-practices: Use when writing or reviewing Next.js App Router code.',
  '- web-dev:vite-best-practices: Use when writing or reviewing Vite config.',
  '- ui-ux:a11y-audit: Use when writing or reviewing UI markup.',
  '- other:vite-best-practices: A same-named skill from another plugin.',
  '- claude-api: Reference for the Claude API.',
  'TRIGGER — read BEFORE opening the target file.',
  'SKIP only when another provider is being worked on.',
  '- deploy: A project skill.',
].join('\n')

const KNOWN = ['ui-ux:a11y-audit', 'laravel:laravel-best-practices', 'web-dev:nextjs-best-practices', 'web-dev:vite-best-practices', 'database:mariadb-best-practices']

const TAIL = 'Listed by name only, as this repository shows no evidence of their stack (skill-router); the Skill tool still loads each:'

type Live = { version?: string; env?: Record<string, string>; held?: string[]; known?: string[]; failBash?: boolean }

function seat(on: On, live: Live = {}) {
  const world = { runs: [] as string[][] }

  mock.env(on, live.env ?? {})
  on('session.version', () => ({ value: { version: live.version ?? '2.1.294' } }))
  on('session.cwd', () => ({ value: ROOT }))

  on('process.run', ($, e) => {
    world.runs.push([...e.argv])

    if (e.argv.join(' ') === 'git rev-parse --show-cdup') {
      return { value: { exitCode: 0, stdout: '\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
    }

    if (e.argv[0] === 'bash' && e.argv[1]?.endsWith('/hooks/stack-evidence.sh') && e.argv[2]?.endsWith('/hooks/prime.sh') && e.argv[3] === ROOT) {
      const stdout = [...(live.known ?? KNOWN).map(id => `D ${id}`), ...(live.held ?? []).map(id => `E ${id}`)].join('\n')

      return live.failBash
        ? { value: { exitCode: 3, stdout: `${stdout}\n`, stderr: 'prime.sh: sr_repo_skills missing', isStdoutTruncated: false, isStderrTruncated: false } }
        : { value: { exitCode: 0, stdout: `${stdout}\n`, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
    }

    return { deny: `unexpected command: ${e.argv.join(' ')}` }
  })

  on('prompt.attachment', ($, e) => ({ text: e.text }))

  return world
}

const listed = async ($: Parameters<Parameters<typeof test>[1]>[0], text = LISTING, type = 'skill_listing') =>
  (await $.prompt.attachment({ type, text, origin: { kind: 'engine' } })).text

const bashRuns = (world: { runs: string[][] }) => world.runs.filter(argv => argv[0] === 'bash').length

describe('scope', () => {
  test('hides only the product skills prime.sh rows and finds no evidence for', () => {
    expect(hiddenOf(['D ui-ux:a11y-audit', 'D laravel:laravel-best-practices', 'D web-dev:vite-best-practices', 'E web-dev:vite-best-practices'].join('\n'))).toEqual([
      'laravel:laravel-best-practices',
    ])
  })

  test('no rows read from prime.sh hides nothing', () => {
    expect([hiddenOf('E laravel:laravel-best-practices\n'), hiddenOf('')]).toEqual([null, null])
  })

  test('the same listing and evidence give the same bytes, whatever order the rows came in', () => {
    const a = scoped(LISTING, hiddenOf(KNOWN.map(id => `D ${id}`).join('\n')) ?? [])
    const b = scoped(LISTING, hiddenOf([...KNOWN].reverse().map(id => `D ${id}`).join('\n')) ?? [])

    expect(a).toBe(b)
  })
})

describe('stack-scoped listing', () => {
  test('drops the off-stack marketplace skills with their wrapped lines and names them once', { options: { cc_route_scope: true } }, async ($, on) => {
    seat(on, { held: ['laravel:laravel-best-practices'] })

    expect(await listed($)).toBe(
      [
        HEAD,
        '',
        '- ui-ux:audit: Audit UI code against WCAG 2.2 AA.',
        '- laravel:laravel-best-practices: Use when writing or reviewing Laravel code.',
        '- ui-ux:a11y-audit: Use when writing or reviewing UI markup.',
        '- other:vite-best-practices: A same-named skill from another plugin.',
        '- claude-api: Reference for the Claude API.',
        'TRIGGER — read BEFORE opening the target file.',
        'SKIP only when another provider is being worked on.',
        '- deploy: A project skill.',
        '',
        `${TAIL} web-dev:nextjs-best-practices, web-dev:vite-best-practices.`,
      ].join('\n'),
    )
  })

  test('keeps the listing byte for byte when every product skill has evidence', { options: { cc_route_scope: true } }, async ($, on) => {
    seat(on, { held: ['laravel:laravel-best-practices', 'web-dev:nextjs-best-practices', 'web-dev:vite-best-practices'] })

    expect(await listed($)).toBe(LISTING)
  })

  test('passes a listing of another format through without running prime.sh', { options: { cc_route_scope: true } }, async ($, on) => {
    const world = seat(on)
    const other = `Skills you can use:\n- laravel:laravel-best-practices: Laravel.`

    expect([await listed($, other), bashRuns(world)]).toEqual([other, 0])
  })

  test('passes the listing through when prime.sh cannot be run', { options: { cc_route_scope: true } }, async ($, on) => {
    seat(on, { failBash: true })

    expect(await listed($)).toBe(LISTING)
  })

  test('is off by default and runs nothing', async ($, on) => {
    const world = seat(on)

    expect([await listed($), bashRuns(world)]).toEqual([LISTING, 0])
  })

  test('CC_ROUTE_SCOPE=on turns it on over the default', async ($, on) => {
    seat(on, { env: { CC_ROUTE_SCOPE: 'on' }, held: ['laravel:laravel-best-practices'] })

    expect(await listed($)).toContain(`${TAIL} web-dev:nextjs-best-practices, web-dev:vite-best-practices.`)
  })

  test('CC_ROUTE_SCOPE=off turns it off over cc_route_scope on', { options: { cc_route_scope: true } }, async ($, on) => {
    seat(on, { env: { CC_ROUTE_SCOPE: 'off' } })

    expect(await listed($)).toBe(LISTING)
  })

  test('changes nothing below the mods floor', { options: { cc_route_scope: true } }, async ($, on) => {
    const world = seat(on, { version: '2.1.290' })

    expect([await listed($), bashRuns(world)]).toEqual([LISTING, 0])
  })

  test('leaves other attachment kinds alone', { options: { cc_route_scope: true } }, async ($, on) => {
    const world = seat(on)

    expect([await listed($, LISTING, 'todo_reminder'), bashRuns(world)]).toEqual([LISTING, 0])
  })
})
