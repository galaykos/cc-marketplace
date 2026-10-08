import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { isSupported, stateRoot, switchOn } from './cc-kit'
import type { Host } from './cc-kit'

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

// Skills that name a product the repository must depend on. Process skills prime.sh also rows (a11y-audit, testing, sql,
// docker, devops, package-hygiene) stay listed: their rows are file-shape guesses, and the skill is wanted to create that shape.
export const SCOPED = new Set([
  'inertia-best-practices',
  'laravel-best-practices',
  'mariadb-best-practices',
  'nextjs-best-practices',
  'react-native-best-practices',
  'shadcn-best-practices',
  'tailwind-best-practices',
  'vite-best-practices',
])

const HEAD = 'The following skills are available for use with the Skill tool:'

const ENTRY = /^- ([a-z0-9][a-z0-9._-]*:[a-z0-9][a-z0-9._-]*)(?=[:\s(])/

export function hiddenOf(stdout: string): string[] | null {
  const rows = stdout.split('\n').map(line => line.split(' '))
  const held = new Set(rows.filter(([kind]) => kind === 'E').map(([, id]) => id))
  const known = rows.filter(([kind, id]) => kind === 'D' && id !== undefined).map(([, id]) => id as string)

  if (known.length === 0) {
    return null
  }

  return [...new Set(known)].filter(id => SCOPED.has(id.slice(id.indexOf(':') + 1)) && !held.has(id)).sort()
}

// The format probed on 2.1.294: the head line, a blank line, then `- name: description` entries, a description free to wrap.
export function isListing(text: string): boolean {
  const lines = text.split('\n', 3)

  return lines[0] === HEAD && lines[1] === '' && lines[2]?.startsWith('- ') === true
}

// Byte-stable for one listing and one hidden set.
export function scoped(text: string, hidden: readonly string[]): string {
  const lines = text.split('\n')
  const dropped: string[] = []
  let isDropping = false

  const kept = lines.filter(line => {
    if (line.startsWith('- ')) {
      const id = ENTRY.exec(line)?.[1]

      isDropping = id !== undefined && hidden.includes(id)

      if (isDropping && id !== undefined) {
        dropped.push(id)
      }
    }

    return !isDropping
  })

  if (dropped.length === 0) {
    return text
  }

  return `${kept.join('\n')}\n\nListed by name only, as this repository shows no evidence of their stack (skill-router); the Skill tool still loads each: ${dropped.join(', ')}.`
}

async function hiddenHere($: EngineInterface): Promise<string[] | null> {
  const root = await stateRoot(hostOf($))
  const ran = await $.process.run(['bash', `${$.plugin.root}/hooks/stack-evidence.sh`, `${$.plugin.root}/hooks/prime.sh`, root], {
    cwd: root,
    timeoutMs: 5000,
  })

  return ran.exitCode === 0 ? hiddenOf(ran.stdout) : null
}

export function registerListing(on: On, options: PluginOptions) {
  on('prompt.attachment', { type: 'skill_listing' }, async ($, e, next) => {
    const r = await next(e)

    const isOn =
      isSupported((await $.session.version()).version) &&
      switchOn(await $.env.get('CC_ROUTE_SCOPE'), options.cc_route_scope === true)

    if (!isOn || r.text === null || !isListing(r.text)) {
      return r
    }

    const hidden = await hiddenHere($)
    const text = hidden === null ? r.text : scoped(r.text, hidden)

    return text === r.text ? r : { ...r, text }
  }).catch(($, e, next) => next(e))
}
