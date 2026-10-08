import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { isSupported, stateRoot, switchOn } from './cc-kit'
import type { Host } from './cc-kit'
import { fromPackageJson, fromPackageLock, lookupDirs, pinsNote, stampsOf } from './pins-core'
import type { Pin, Stamp } from './pins-core'

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

async function installedOf($: EngineInterface, dirs: readonly string[], stamp: Stamp): Promise<Pin | null> {
  for (const dir of dirs) {
    const installed = fromPackageJson(await $.fs.read(`${dir}/node_modules/${stamp.pkg}/package.json`).catch(() => ''))

    if (installed !== null) {
      return { ...stamp, installed, source: 'installed' }
    }
  }

  return null
}

// node_modules first, as what runs; a lockfile is read once per directory, and only for a package node_modules lacks.
async function pinsOf($: EngineInterface, dirs: readonly string[], stamps: readonly Stamp[]): Promise<Pin[]> {
  const pins = await Promise.all(stamps.map(stamp => installedOf($, dirs, stamp)))
  const locks = pins.includes(null) ? await Promise.all(dirs.map(dir => $.fs.read(`${dir}/package-lock.json`).catch(() => ''))) : []

  return stamps.flatMap((stamp, i) => {
    const pin = pins[i] ?? null

    if (pin !== null) {
      return [pin]
    }

    const locked = locks.map(lock => fromPackageLock(lock, stamp.pkg)).find(version => version !== null)

    return locked === undefined ? [] : [{ ...stamp, installed: locked, source: 'locked' as const }]
  })
}

export function register(on: On, options: PluginOptions) {
  on('skill.prompt', async ($, e, next) => {
    const r = await next(e)

    const isOn =
      isSupported((await $.session.version()).version) && switchOn(await $.env.get('CC_VERSION_PINS'), options.cc_version_pins !== false)
    const stamps = isOn ? stampsOf(r.text) : []

    if (stamps.length === 0) {
      return r
    }

    const dirs = lookupDirs(await $.session.cwd(), await stateRoot(hostOf($)))
    const pins = await pinsOf($, dirs, stamps)

    return pins.length === 0 ? r : { ...r, text: `${pinsNote(pins)}\n\n${r.text}` }
  }).catch(($, e, next) => next(e))
}
