// Manifest transform (runs LAST): turns the surfaces cards 04-07 emitted into per-plugin
// .codex-plugin/plugin.json manifests, the .agents/plugins/marketplace.json catalog, and a
// contributor-facing root AGENTS.md — with a consumer-visible fidelity disclosure on each.
//
// SCHEMA CAVEAT: the exact component-pointer shape of a Codex plugin manifest and the
// marketplace entry schema are pinned in schema.mjs from live docs (card 01) but are a
// MEDIUM-confidence, evolving surface. Pointer semantics (id list vs path) are the most
// likely thing to need a tweak; card 13 verifies against a live Codex.
import { readFileSync } from 'node:fs'
import { register } from './registry.mjs'
import { stableJson } from './serialize.mjs'
import { SCHEMA_VERSION } from '../schema.mjs'

register('manifest', (plugin, ctx) => {
  ctx.__catalog = ctx.__catalog || []
  const writes = []
  const last = plugin.name === ctx.plugins[ctx.plugins.length - 1].name

  const fidelity = buildFidelity(plugin, ctx)
  const skillIds = [
    ...ctx.records.skills.filter((r) => r.plugin === plugin.name).map((r) => r.codexId),
    ...ctx.records.commandSkills.filter((r) => r.plugin === plugin.name).map((r) => r.id),
  ].sort()
  const hookRec = ctx.records.hooks.find((r) => r.plugin === plugin.name)
  const hasHooks = hookRec && hookRec.keptEvents.length > 0
  const agents = ctx.records.agents.filter((r) => r.plugin === plugin.name)
  const hasBundlable = skillIds.length > 0 || hasHooks

  if (plugin.isBundle) {
    // Dependency-only bundles have no installable Codex content and no valid `source`
    // (real Codex requires `source` on every catalog entry). They are a CC dependency
    // fan-out concept with no Codex equivalent, so they are OMITTED from the Codex catalog
    // and disclosed instead as grouping-only in AGENTS.md (contributor view). Verified
    // against codex-cli 0.143.0, which rejects a sourceless entry.
  } else {
    const manifest = {
      name: plugin.name,
      version: plugin.manifest.version,
      description: plugin.manifest.description,
      author: plugin.manifest.author,
      schema_build: SCHEMA_VERSION,
      interface: {
        displayName: titleCase(plugin.name),
        shortDescription: plugin.manifest.description,
        longDescription: (plugin.catalogDescription || plugin.manifest.description) + '\n\n' + fidelitySentence(fidelity),
      },
      fidelity,
    }
    if (skillIds.length) manifest.skills = 'skills' // relative dir under codex/<plugin>/ (bundled)
    if (hasHooks) manifest.hooks = 'hooks' // relative dir under codex/<plugin>/
    writes.push({ path: `codex/${plugin.name}/.codex-plugin/plugin.json`, content: stableJson(manifest) })

    // entry shape verified against codex-cli 0.143.0: source discriminator is `source:"local"`,
    // path needs a `./` prefix relative to the marketplace root, policy + category are required.
    ctx.__catalog.push({
      name: plugin.name,
      source: { source: 'local', path: `./codex/${plugin.name}` },
      policy: { installation: 'AVAILABLE', authentication: 'ON_INSTALL' },
      category: 'Development',
      interface: { displayName: titleCase(plugin.name) },
      installs: hasBundlable ? undefined : agents.length ? 'subagent-only' : 'nothing',
      fidelitySummary: {
        faithful: fidelity.faithful.length,
        degraded: fidelity.degraded.length,
        dropped: fidelity.dropped.length,
        requiredCoInstalls: fidelity.requiredCoInstalls,
      },
    })
  }

  if (last) {
    const marketplace = {
      name: 'cc-plugins-marketplace',
      interface: { displayName: 'CC Plugins (Codex)' },
      plugins: [...ctx.__catalog].sort((a, b) => (a.name < b.name ? -1 : 1)),
    }
    writes.push({ path: '.agents/plugins/marketplace.json', content: stableJson(marketplace) })
    writes.push({ path: 'AGENTS.md', content: buildAgentsMd(ctx) })
  }
  return writes
})

function buildFidelity(plugin, ctx) {
  const faithful = []
  const degraded = []
  const dropped = []
  const coInstalls = []
  for (const s of ctx.records.skills.filter((r) => r.plugin === plugin.name)) {
    if (s.degraded) degraded.push({ id: s.codexId, kind: 'skill', reasons: s.degradeReasons })
    else faithful.push({ id: s.codexId, kind: 'skill' })
  }
  for (const c of ctx.records.commandSkills.filter((r) => r.plugin === plugin.name)) {
    degraded.push({ id: c.id, kind: 'command-as-skill', reasons: [`auto-trigger/$-mention, not a typed /${plugin.name}:${c.cmd} verb`] })
  }
  for (const a of ctx.records.agents.filter((r) => r.plugin === plugin.name)) {
    degraded.push({ id: a.agent, kind: 'subagent', reasons: ['out-of-band: install via install-agents.sh (Codex plugins cannot bundle subagents); model omitted (inherits session model)'] })
    for (const ci of a.requiredCoInstalls) coInstalls.push(ci.skill)
  }
  const hookRec = ctx.records.hooks.find((r) => r.plugin === plugin.name)
  if (hookRec) {
    if (hookRec.keptEvents.length) faithful.push({ id: 'hooks', kind: 'hooks', events: hookRec.keptEvents })
    for (const d of hookRec.droppedEvents) dropped.push({ id: `hook:${d}`, reason: 'no Codex peer for this hook event' })
    if (hookRec.degradedReasons.length) degraded.push({ id: 'hooks', kind: 'hooks', reasons: hookRec.degradedReasons })
  }
  for (const d of ctx.records.dropped.filter((r) => r.plugin === plugin.name)) dropped.push({ id: d.id, reason: d.reason })
  return { faithful, degraded, dropped, requiredCoInstalls: [...new Set(coInstalls)].sort() }
}

function fidelitySentence(f) {
  return `Codex fidelity: ${f.faithful.length} faithful, ${f.degraded.length} degraded, ${f.dropped.length} dropped surface(s)` +
    (f.requiredCoInstalls.length ? `; requires co-install of: ${f.requiredCoInstalls.join(', ')}` : '') + '.'
}

function titleCase(name) {
  return name.split('-').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')
}

function buildAgentsMd(ctx) {
  const lines = []
  lines.push('# AGENTS.md — Codex conventions for this repo')
  lines.push('')
  lines.push('This repository is BOTH a Claude Code plugin marketplace (`plugins/`, canonical) and a')
  lines.push('Codex marketplace (`.agents/`, `codex/`, generated one-way by `scripts/gen-codex/`).')
  lines.push('Do not hand-edit anything under `.agents/` or `codex/` — regenerate with')
  lines.push('`node scripts/gen-codex/gen.mjs`; `scripts/validate-codex.sh` enforces freshness.')
  lines.push('')
  lines.push('## Codex install')
  lines.push('')
  lines.push('- `codex plugin marketplace add galaykos/cc-marketplace` — skills + hooks.')
  lines.push('- `git clone` this repo, then `bash codex/install-agents.sh` — the subagents')
  lines.push('  (Codex plugins cannot bundle subagents, so they install out-of-band).')
  lines.push('')
  lines.push('## Per-plugin fidelity (consumer authoritative copy lives in the catalog/manifests)')
  lines.push('')
  lines.push('| Plugin | Faithful | Degraded | Dropped | Co-installs |')
  lines.push('|--------|----------|----------|---------|-------------|')
  for (const p of ctx.plugins) {
    if (p.isBundle) {
      lines.push(`| ${p.name} | — | — | grouping-only (installs nothing) | — |`)
      continue
    }
    const f = buildFidelity(p, ctx)
    lines.push(`| ${p.name} | ${f.faithful.length} | ${f.degraded.length} | ${f.dropped.length} | ${f.requiredCoInstalls.join(', ') || '—'} |`)
  }
  lines.push('')
  return lines.join('\n')
}
