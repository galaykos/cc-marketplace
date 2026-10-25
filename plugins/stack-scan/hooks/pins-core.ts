export type Registry = 'npm' | 'composer'

export type Stamp = { pkg: string; verified: string }

export type Pin = Stamp & { registry: Registry; installed: string; source: 'installed' | 'locked' }

// The tails of a `Last verified:` stamp: npm:<pkg>@<major>[.<minor>], as scripts/check-doc-staleness.sh reads it, and
// composer:<vendor>/<package>@<major>[.<minor>] in the same grammar, which that script does not read.
const NPM_STAMP = /Last verified:[^\n]*?\bnpm:((?:@[\w.-]+\/)?[\w.-]+)@(\d+(?:\.\d+)?)/g
const COMPOSER_STAMP = /Last verified:[^\n]*?\bcomposer:([\w.-]+\/[\w.-]+)@(\d+(?:\.\d+)?)/g

function stampsBy(stamp: RegExp, text: string): Stamp[] {
  const seen = new Map<string, Stamp>()

  for (const [, pkg, verified] of text.matchAll(stamp)) {
    if (pkg !== undefined && verified !== undefined && !seen.has(pkg)) {
      seen.set(pkg, { pkg, verified })
    }
  }

  return [...seen.values()]
}

export function stampsOf(text: string): Stamp[] {
  return stampsBy(NPM_STAMP, text)
}

export function composerStampsOf(text: string): Stamp[] {
  return stampsBy(COMPOSER_STAMP, text)
}

// Whole semver or nothing, and only its major.minor.patch is kept: the version is pasted into a skill's text, so a lockfile from a cloned repository must carry no words in.
const SEMVER = /^(\d+\.\d+\.\d+)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/

function versionOf(value: unknown): string | null {
  return typeof value === 'string' ? (SEMVER.exec(value)?.[1] ?? null) : null
}

// The session's directory up to the repository root, as Node resolves node_modules; a cwd outside the root reads both alone.
export function lookupDirs(cwd: string, root: string): string[] {
  if (cwd !== root && !cwd.startsWith(root.endsWith('/') ? root : `${root}/`)) {
    return [cwd, root]
  }

  const dirs = [cwd]

  for (let dir = cwd; dir !== root; ) {
    dir = dir.slice(0, dir.lastIndexOf('/')) || '/'
    dirs.push(dir)
  }

  return dirs
}

function jsonOf(text: string): unknown {
  try {
    return JSON.parse(text) as unknown
  } catch {
    return null
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

export function fromPackageJson(text: string): string | null {
  const json = jsonOf(text)

  return typeof json === 'object' && json !== null && 'version' in json ? versionOf(json.version) : null
}

// lockfileVersion 2 and 3 key every installed package as `node_modules/<name>`; version 1 has no such map.
export function fromPackageLock(text: string, pkg: string): string | null {
  const json = jsonOf(text)

  if (typeof json !== 'object' || json === null || !('packages' in json) || typeof json.packages !== 'object' || json.packages === null) {
    return null
  }

  const entry: unknown = (json.packages as Record<string, unknown>)[`node_modules/${pkg}`]

  return typeof entry === 'object' && entry !== null && 'version' in entry ? versionOf(entry.version) : null
}

// `next@15.2.1(react@19.0.0)` (v9), `/next@15.2.1(react@19.0.0)` (v6) or `next@npm:^15.0.0` (yarn berry) → [name, rest]; a scoped name keeps its leading `@`.
function nameAndRest(key: string): [string, string] | null {
  const at = key.indexOf('@', 1)

  return at < 1 ? null : [key.slice(0, at), key.slice(at + 1)]
}

// One unambiguous version or none; a non-semver entry counts as a version of its own, so it makes the name ambiguous.
function onlyOf(versions: ReadonlySet<string>): string | null {
  const [only, ...more] = versions

  return more.length === 0 ? versionOf(only) : null
}

const PNPM_SECTIONS = new Set(['dependencies', 'devDependencies', 'optionalDependencies'])

const YAML_ENTRY = /^( *)(?:'([^']*)'|"([^"]*)"|([^\s'"#][^\s]*?)):(?: +(.*))?$/

const unquoted = (value: string) => value.replace(/^'(.*)'$|^"(.*)"$/, '$1$2')

// pnpm-lock.yaml, read line by line — no YAML library loads inside a mod. Only block-mapping lines (`key:` or
// `key: value`, two-space indents, a key plain or quoted) are read, and only these paths:
//   importers: / .: / dependencies|devDependencies|optionalDependencies: / <name>: / version: 15.2.1(peer@x)   v9, v6 workspace
//   dependencies|devDependencies|optionalDependencies: / <name>: / version: …                                  v6 without importers
//   packages: or snapshots: / /next@15.2.1(…): (v6) or next@15.2.1(…): (v9), a scoped key quoted
// The root importer decides when it names the package; otherwise the packages keys must agree on one version. Flow
// mappings, list items and block scalars match no rule; v5's `/next/15.2.1` keys name nothing, so v5 reads as none.
export function fromPnpmLock(text: string, pkg: string): string | null {
  const parents: { indent: number; key: string }[] = []
  const keys = new Set<string>()
  let root: string | null = null

  for (const line of text.split(/\r?\n/)) {
    const entry = YAML_ENTRY.exec(line)

    if (entry === null) {
      continue
    }

    const indent = entry[1]?.length ?? 0
    const key = entry[2] ?? entry[3] ?? entry[4] ?? ''
    const value = unquoted((entry[5] ?? '').trim())

    while ((parents.at(-1)?.indent ?? -1) >= indent) {
      parents.pop()
    }

    const path = [...parents.map(parent => parent.key), key]
    const [first = '', second = '', third = ''] = path

    if (value === '') {
      parents.push({ indent, key })
    }

    const isRootVersion =
      key === 'version' &&
      path.at(-2) === pkg &&
      ((path.length === 3 && PNPM_SECTIONS.has(first)) || (path.length === 5 && first === 'importers' && second === '.' && PNPM_SECTIONS.has(third)))

    if (isRootVersion && value !== '') {
      root = value
    } else if (path.length === 2 && (first === 'packages' || first === 'snapshots')) {
      const named = nameAndRest(key.replace(/^\//, ''))

      if (named?.[0] === pkg) {
        keys.add(named[1].split('(')[0] ?? '')
      }
    }
  }

  return root !== null ? versionOf(root.split('(')[0]) : onlyOf(keys)
}

// A registry range: a semver range or a dist-tag. `workspace:*`, `file:`, `link:`, a git URL, `user/repo` and an npm alias are not.
const REGISTRY_RANGE = /^[\w.*^~<>=|+\s-]*$/

const YARN_VERSION = /^ {2}version:? +"?([^"\s]+)"?\s*$/

// Does this entry header name pkg, through a registry range or another kind? A berry `patch:` descriptor wraps an npm entry read on its own, so it is skipped.
function headerKind(header: string, pkg: string): 'registry' | 'other' | null {
  let kind: 'registry' | null = null

  for (const descriptor of header.replace(/:\s*$/, '').replaceAll('"', '').split(/,\s*/)) {
    const named = nameAndRest(descriptor)

    if (named?.[0] !== pkg) {
      continue
    }

    const range = named[1].replace(/^npm:/, '')

    if (range.startsWith('patch:')) {
      continue
    }

    if (!REGISTRY_RANGE.test(range)) {
      return 'other'
    }

    kind = 'registry'
  }

  return kind
}

// yarn.lock, read line by line. An entry is a header at column 0 — v1 `"next@^15.0.0", next@^15.1:`, berry
// `"next@npm:^15.0.0, next@npm:^15.1.0":` — then its fields two spaces in: v1 `version "15.2.1"`, berry
// `version: 15.2.1`. Every entry naming the package must agree on one version; an entry through a non-registry range
// (workspace, git, file, link, alias) makes it ambiguous. Berry's `__metadata` names no package.
export function fromYarnLock(text: string, pkg: string): string | null {
  const versions = new Set<string>()
  let kind: 'registry' | 'other' | null = null

  for (const line of text.split(/\r?\n/)) {
    if (/^[^\s#]/.test(line)) {
      kind = headerKind(line, pkg)

      if (kind === 'other') {
        versions.add('')
      }
    } else if (kind === 'registry') {
      const version = YARN_VERSION.exec(line)?.[1]

      if (version !== undefined) {
        versions.add(version)
      }
    }
  }

  return onlyOf(versions)
}

// Composer writes `v12.3.1` or `12.3.1`; one leading `v` is dropped, then the same whole-semver rule.
function composerVersionOf(packages: unknown[], pkg: string): string | null {
  const entry = packages.find(item => isRecord(item) && item.name === pkg)

  return isRecord(entry) && typeof entry.version === 'string' ? versionOf(entry.version.replace(/^v/, '')) : null
}

const listOf = (value: unknown): unknown[] => (Array.isArray(value) ? value : [])

// vendor/composer/installed.json: composer 2 `{"packages": [...]}`, composer 1 a top-level array.
export function fromComposerInstalled(text: string, pkg: string): string | null {
  const json = jsonOf(text)

  return composerVersionOf(Array.isArray(json) ? json : isRecord(json) ? listOf(json.packages) : [], pkg)
}

export function fromComposerLock(text: string, pkg: string): string | null {
  const json = jsonOf(text)

  return isRecord(json) ? composerVersionOf([...listOf(json.packages), ...listOf(json['packages-dev'])], pkg) : null
}

function partsOf(version: string): [number, number | null] {
  const [major = '0', minor] = version.split('.')

  return [Number(major), minor === undefined ? null : Number(minor)]
}

// Older or newer than the stamp at the precision the stamp names: a stamp of 16 ignores minors, 16.3 does not.
export function driftOf(installed: string, verified: string): 'older' | 'newer' | null {
  const [im, iminor] = partsOf(installed)
  const [vm, vminor] = partsOf(verified)

  if (im !== vm) {
    return im < vm ? 'older' : 'newer'
  }

  if (vminor === null || iminor === null || iminor === vminor) {
    return null
  }

  return iminor < vminor ? 'older' : 'newer'
}

const INSTALL_DIR: Record<Registry, string> = { npm: 'node_modules', composer: 'vendor' }

function pinLine(pin: Pin): string {
  const what = `${pin.pkg} ${pin.installed}${pin.source === 'locked' ? ` (lockfile; ${INSTALL_DIR[pin.registry]} not read)` : ''}`

  switch (driftOf(pin.installed, pin.verified)) {
    case 'older':
      return `${what}: older than the ${pin.verified} this skill was checked against, so advice for ${pin.verified} may name APIs this project does not have.`
    case 'newer':
      return `${what}: newer than the ${pin.verified} this skill was checked against, so check its advice against the ${pin.pkg} docs before applying it.`
    case null:
      return `${what}: the line this skill was checked against.`
  }
}

export function pinsNote(pins: readonly Pin[]): string {
  return ['Installed in this project, read by stack-scan when this skill loaded:', ...pins.map(pin => `- ${pinLine(pin)}`)].join('\n')
}
