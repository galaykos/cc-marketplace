// Structural half of the Codex parity gate (called by scripts/validate-codex.sh after it
// regenerates the tree). Asserts correspondence, name==dir, skill-name uniqueness, valid
// agent TOML, and that every manifest/catalog pointer resolves to an emitted artifact.
// Reads the committed generated tree + the canonical source. Exits non-zero on any failure.
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { discover } from './lib/discover.mjs'
import { parseFrontmatter } from './lib/frontmatter.mjs'
import { parseToml } from './lib/toml-parse.mjs'
import { AGENT_TOML } from './schema.mjs'

const REPO = resolve(import.meta.dirname, '..', '..')
const p = (...a) => join(REPO, ...a)
let fail = 0
const err = (m) => {
  console.error(`FAIL: ${m}`)
  fail = 1
}

const { plugins } = discover(REPO)

// --- skills: bundled per-plugin under codex/<plugin>/skills/<name>; name==dir; globally unique ---
const seenSkillNames = new Set()
for (const plugin of plugins) {
  const sdir = p('codex', plugin.name, 'skills')
  if (!existsSync(sdir)) continue
  for (const dir of readdirSync(sdir)) {
    const skillMd = join(sdir, dir, 'SKILL.md')
    if (!existsSync(skillMd)) {
      err(`codex/${plugin.name}/skills/${dir} has no SKILL.md`)
      continue
    }
    const { frontmatter } = parseFrontmatter(readFileSync(skillMd, 'utf8'))
    if (frontmatter.name !== dir) err(`skill ${dir}: frontmatter name "${frontmatter.name}" != dir`)
    if (seenSkillNames.has(dir)) err(`duplicate skill name ${dir} (must be globally unique)`)
    seenSkillNames.add(dir)
  }
}
for (const plugin of plugins) {
  for (const s of plugin.skills) {
    if (!seenSkillNames.has(s.name)) err(`source skill ${plugin.name}/${s.name} has no emitted skill`)
  }
}

// --- agents: every source agent -> valid TOML, no CC model, valid effort ---
for (const plugin of plugins) {
  for (const a of plugin.agents) {
    const tomlPath = p('codex/agents', `${a.name}.toml`)
    if (!existsSync(tomlPath)) {
      err(`agent ${a.name} has no codex/agents/${a.name}.toml`)
      continue
    }
    const raw = readFileSync(tomlPath, 'utf8')
    if (/^model = "(opus|sonnet|haiku|fable)"/m.test(raw)) err(`agent ${a.name}: leaked CC model slug`)
    let t
    try {
      t = parseToml(raw)
    } catch (e) {
      err(`agent ${a.name}: TOML parse failed (${e.message})`)
      continue
    }
    for (const k of AGENT_TOML.required) if (!(k in t)) err(`agent ${a.name}: missing required key ${k}`)
    if ('model' in t) err(`agent ${a.name}: model must be omitted`)
    if (t.model_reasoning_effort && !AGENT_TOML.reasoningEffortEnum.includes(t.model_reasoning_effort)) {
      err(`agent ${a.name}: invalid model_reasoning_effort ${t.model_reasoning_effort}`)
    }
    if (t['skills.config']) {
      for (const id of t['skills.config'].skills || []) {
        if (!seenSkillNames.has(id)) err(`agent ${a.name}: [skills.config] references unknown skill ${id}`)
      }
    }
  }
}

// --- catalog + manifests ---
const catalogPath = p('.agents/plugins/marketplace.json')
if (!existsSync(catalogPath)) {
  err('.agents/plugins/marketplace.json missing')
} else {
  const catalog = JSON.parse(readFileSync(catalogPath, 'utf8'))
  // dependency-only bundles are omitted from the Codex catalog (no installable content,
  // no valid source); every non-bundle plugin must have exactly one entry, each with a source.
  const installable = plugins.filter((pl) => !pl.isBundle)
  if (catalog.plugins.length !== installable.length) err(`catalog has ${catalog.plugins.length} entries, expected ${installable.length} (leaf plugins)`)
  const catalogNames = new Set(catalog.plugins.map((e) => e.name))
  for (const plugin of installable) if (!catalogNames.has(plugin.name)) err(`catalog missing entry for ${plugin.name}`)
  for (const plugin of plugins) if (plugin.isBundle && catalogNames.has(plugin.name)) err(`bundle ${plugin.name} must not be in the Codex catalog`)
  for (const entry of catalog.plugins) {
    if (!entry.source) {
      err(`catalog ${entry.name}: missing required field 'source'`)
      continue
    }
    const manifestPath = p(entry.source.path, '.codex-plugin', 'plugin.json')
    if (!existsSync(manifestPath)) {
      err(`catalog ${entry.name}: manifest ${entry.source.path}/.codex-plugin/plugin.json missing`)
      continue
    }
    const m = JSON.parse(readFileSync(manifestPath, 'utf8'))
    if (m.skills && !existsSync(p(entry.source.path, m.skills))) err(`manifest ${entry.name}: skills pointer '${m.skills}' resolves to no dir`)
    if (m.hooks && !existsSync(p(entry.source.path, m.hooks, 'hooks.json'))) err(`manifest ${entry.name}: hooks pointer resolves to no hooks.json`)
  }
}

// --- no CLAUDE_PLUGIN_ROOT / SessionEnd anywhere in the generated tree (defense in depth; .sh greps too) ---
function walk(dir, cb) {
  if (!existsSync(dir)) return
  for (const n of readdirSync(dir)) {
    const full = join(dir, n)
    if (readdirSync(dir, { withFileTypes: true }).find((d) => d.name === n)?.isDirectory()) walk(full, cb)
    else cb(full)
  }
}
for (const root of ['.agents', 'codex']) {
  walk(p(root), (file) => {
    const txt = readFileSync(file, 'utf8')
    if (txt.includes('CLAUDE_PLUGIN_ROOT')) err(`${file}: contains CLAUDE_PLUGIN_ROOT`)
    if (file.endsWith('hooks.json') && txt.includes('"SessionEnd"')) err(`${file}: contains SessionEnd`)
  })
}

if (fail) process.exit(1)
console.log('OK: codex structural checks passed')
