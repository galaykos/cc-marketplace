// Discover every marketplace plugin and its artifacts from directory convention
// (artifact dirs are never listed in plugin.json). Returns a name-sorted array so
// downstream output order is deterministic.
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { join, resolve } from 'node:path'

const STD_ROOT_MD = new Set(['README.md', 'CHANGELOG.md', 'ROADMAP.md'])
const STD_DIRS = new Set(['skills', 'commands', 'agents', 'hooks', '.claude-plugin'])

/** @param {string} repoRoot */
export function discover(repoRoot) {
  const mpPath = join(repoRoot, '.claude-plugin', 'marketplace.json')
  const mp = JSON.parse(readFileSync(mpPath, 'utf8'))
  const plugins = mp.plugins
    .map((entry) => describePlugin(repoRoot, entry))
    .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0))
  return { marketplace: mp, plugins }
}

function describePlugin(repoRoot, entry) {
  const dir = resolve(repoRoot, entry.source.replace(/^\.\//, ''))
  const manifest = JSON.parse(readFileSync(join(dir, '.claude-plugin', 'plugin.json'), 'utf8'))

  const skills = lsDirs(join(dir, 'skills')).map((skill) => ({
    name: skill,
    dir: join(dir, 'skills', skill),
  }))
  const commands = lsFiles(join(dir, 'commands'), '.md').map((f) => ({
    name: f.replace(/\.md$/, ''),
    file: join(dir, 'commands', f),
  }))
  const agents = lsFiles(join(dir, 'agents'), '.md').map((f) => ({
    name: f.replace(/\.md$/, ''),
    file: join(dir, 'agents', f),
  }))
  const hooksJson = join(dir, 'hooks', 'hooks.json')
  const hooks = existsSync(hooksJson)
    ? { jsonPath: hooksJson, scripts: lsFiles(join(dir, 'hooks'), null).filter((f) => f !== 'hooks.json') }
    : null
  const readme = existsSync(join(dir, 'README.md')) ? join(dir, 'README.md') : null

  // plugin-root data files that are not standard docs and not the manifest dir —
  // e.g. skill-router/rules.tsv, which hooks read via ${CLAUDE_PLUGIN_ROOT}/rules.tsv
  const rootData = readdirSync(dir)
    .filter((n) => {
      const full = join(dir, n)
      return statSync(full).isFile() && !STD_ROOT_MD.has(n) && !n.startsWith('.')
    })
    .sort()
    .map((n) => ({ name: n, file: join(dir, n) }))

  return {
    name: entry.name,
    catalogDescription: entry.description,
    dir,
    isBundle: Array.isArray(manifest.dependencies),
    manifest,
    skills,
    commands,
    agents,
    hooks,
    readme,
    rootData,
  }
}

function lsDirs(dir) {
  if (!existsSync(dir)) return []
  return readdirSync(dir)
    .filter((n) => statSync(join(dir, n)).isDirectory())
    .sort()
}

function lsFiles(dir, ext) {
  if (!existsSync(dir)) return []
  return readdirSync(dir)
    .filter((n) => statSync(join(dir, n)).isFile() && (ext ? n.endsWith(ext) : true))
    .sort()
}

// re-export so callers don't reimplement the "not a standard dir" test
export const STANDARD_DIRS = STD_DIRS
