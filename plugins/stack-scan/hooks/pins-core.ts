export type Stamp = { pkg: string; verified: string }

export type Pin = Stamp & { installed: string; source: 'installed' | 'locked' }

// The tail of a `Last verified:` stamp, as scripts/check-doc-staleness.sh reads it: npm:<pkg>@<major>[.<minor>].
const STAMP = /Last verified:[^\n]*?\bnpm:((?:@[\w.-]+\/)?[\w.-]+)@(\d+(?:\.\d+)?)/g

export function stampsOf(text: string): Stamp[] {
  const seen = new Map<string, Stamp>()

  for (const [, pkg, verified] of text.matchAll(STAMP)) {
    if (pkg !== undefined && verified !== undefined && !seen.has(pkg)) {
      seen.set(pkg, { pkg, verified })
    }
  }

  return [...seen.values()]
}

function versionOf(value: unknown): string | null {
  return typeof value === 'string' && /^\d+\.\d+/.test(value) ? value : null
}

function jsonOf(text: string): unknown {
  try {
    return JSON.parse(text) as unknown
  } catch {
    return null
  }
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

function pinLine(pin: Pin): string {
  const what = `${pin.pkg} ${pin.installed}${pin.source === 'locked' ? ' (lockfile; node_modules not read)' : ''}`

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
