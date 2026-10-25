// Prepends to a loading skill the installed version of each npm or composer package its Last verified stamp names.
// Not read: Yarn Plug'n'Play, bun.lockb, pnpm lockfile v5, a workspace's own importer or non-hoisted entry, references/.
import type { EngineInterface, On, PluginOptions } from 'claude-code'

import { hostOf, isSupported, stateRoot, switchOn } from './cc-kit'
import {
  composerStampsOf,
  fromComposerInstalled,
  fromComposerLock,
  fromPackageJson,
  fromPackageLock,
  fromPnpmLock,
  fromYarnLock,
  lookupDirs,
  pinsNote,
  stampsOf,
} from './pins-core'
import type { Pin, Registry, Stamp } from './pins-core'

type Read = (path: string) => Promise<string>

// Each path is read at most once per skill load, whichever stamps ask for it; a missing or unreadable file reads as ''.
function readerOf($: EngineInterface): Read {
  const held = new Map<string, Promise<string>>()

  return path => {
    const text = held.get(path) ?? $.fs.read(path).catch(() => '')

    held.set(path, text)

    return text
  }
}

async function firstIn(dirs: readonly string[], find: (dir: string) => Promise<string | null>): Promise<string | null> {
  for (const dir of dirs) {
    const version = await find(dir)

    if (version !== null) {
      return version
    }
  }

  return null
}

const NPM_LOCKS = [
  ['package-lock.json', fromPackageLock],
  ['pnpm-lock.yaml', fromPnpmLock],
  ['yarn.lock', fromYarnLock],
] as const

// The first of the three present in a directory is that directory's lockfile; the others there are not read.
async function npmLocked(read: Read, dir: string, pkg: string): Promise<string | null> {
  for (const [name, versionIn] of NPM_LOCKS) {
    const text = await read(`${dir}/${name}`)

    if (text !== '') {
      return versionIn(text, pkg)
    }
  }

  return null
}

type Sources = {
  installed: (read: Read, dir: string, pkg: string) => Promise<string | null>
  locked: (read: Read, dir: string, pkg: string) => Promise<string | null>
}

const SOURCES: Record<Registry, Sources> = {
  npm: {
    installed: async (read, dir, pkg) => fromPackageJson(await read(`${dir}/node_modules/${pkg}/package.json`)),
    locked: npmLocked,
  },
  composer: {
    installed: async (read, dir, pkg) => fromComposerInstalled(await read(`${dir}/vendor/composer/installed.json`), pkg),
    locked: async (read, dir, pkg) => fromComposerLock(await read(`${dir}/composer.lock`), pkg),
  },
}

// What is installed first, as what runs; a lockfile only for a package no directory has installed.
async function pinOf(read: Read, dirs: readonly string[], registry: Registry, stamp: Stamp): Promise<Pin | null> {
  const { installed, locked } = SOURCES[registry]
  const fromInstall = await firstIn(dirs, dir => installed(read, dir, stamp.pkg))

  if (fromInstall !== null) {
    return { ...stamp, registry, installed: fromInstall, source: 'installed' }
  }

  const fromLock = await firstIn(dirs, dir => locked(read, dir, stamp.pkg))

  return fromLock === null ? null : { ...stamp, registry, installed: fromLock, source: 'locked' }
}

export function register(on: On, options: PluginOptions) {
  on('skill.prompt', async ($, e, next) => {
    const r = await next(e)

    const isOn =
      isSupported((await $.session.version()).version) && switchOn(await $.env.get('CC_VERSION_PINS'), options.cc_version_pins !== false)
    const stamps = isOn
      ? [...stampsOf(r.text).map(stamp => ['npm', stamp] as const), ...composerStampsOf(r.text).map(stamp => ['composer', stamp] as const)]
      : []

    if (stamps.length === 0) {
      return r
    }

    const dirs = lookupDirs(await $.session.cwd(), await stateRoot(hostOf($)))
    const read = readerOf($)
    const pins = (await Promise.all(stamps.map(([registry, stamp]) => pinOf(read, dirs, registry, stamp)))).filter((pin): pin is Pin => pin !== null)

    return pins.length === 0 ? r : { ...r, text: `${pinsNote(pins)}\n\n${r.text}` }
  }).catch(($, e, next) => next(e))
}
