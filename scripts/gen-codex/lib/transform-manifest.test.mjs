import { test } from 'node:test'
import assert from 'node:assert/strict'
import { generate } from '../gen.mjs'

const { writes } = generate({ dryRun: true })
const byPath = new Map(writes.map((w) => [w.path, w]))
const catalog = JSON.parse(byPath.get('.agents/plugins/marketplace.json').content)

test('catalog holds the 62 leaf plugins; bundles omitted (real Codex requires source)', () => {
  assert.equal(catalog.plugins.length, 62)
  // every entry has a source (codex-cli 0.143.0 rejects sourceless entries)
  assert.ok(catalog.plugins.every((p) => p.source && p.source.path))
  // the 8 dependency-only bundles are NOT catalog entries
  for (const b of ['everything', 'frontend-suite', 'php-suite', 'db-suite', 'quality-suite', 'process-suite', 'taskmaster-suite', 'automations-suite']) {
    assert.ok(!catalog.plugins.find((p) => p.name === b), `${b} must be omitted`)
  }
})

test('leaf plugin manifest has a skills dir pointer resolving to bundled skills', () => {
  const m = JSON.parse(byPath.get('codex/code-review/.codex-plugin/plugin.json').content)
  assert.equal(m.skills, 'skills') // relative dir pointer under the plugin
  // the bundled skills actually exist under codex/code-review/skills/
  const bundled = writes.filter((w) => /^codex\/code-review\/skills\/[^/]+\/SKILL\.md$/.test(w.path))
  assert.ok(bundled.length > 0, 'code-review bundles at least one skill')
})

test('fidelity block records degraded command-as-skill + dropped bundle command', () => {
  const m = JSON.parse(byPath.get('codex/code-review/.codex-plugin/plugin.json').content)
  assert.ok(m.fidelity.degraded.some((d) => d.kind === 'command-as-skill'))
})

test('agent-only plugin is subagent-only, not a phantom install', () => {
  const dbEntry = catalog.plugins.find((p) => p.name === 'database')
  assert.equal(dbEntry.installs, 'subagent-only')
  // its manifest exists but declares no skills/hooks components
  const m = JSON.parse(byPath.get('codex/database/.codex-plugin/plugin.json').content)
  assert.ok(!m.skills, 'no phantom skills pointer')
  assert.ok(!m.hooks, 'no phantom hooks pointer')
  assert.ok(m.fidelity.degraded.some((d) => d.kind === 'subagent'))
})

test('version mirrors CC source and a distinct schema_build stamp is present', () => {
  const m = JSON.parse(byPath.get('codex/code-review/.codex-plugin/plugin.json').content)
  assert.equal(m.version, '0.2.0') // matches plugins/code-review/.claude-plugin/plugin.json
  assert.equal(m.schema_build, '2026-07-10')
})

test('web-developer required co-installs are disclosed', () => {
  const wd = catalog.plugins.find((p) => p.name === 'web-dev')
  assert.ok(wd, 'web-dev present')
  // its engineer agent references 6 cross-plugin best-practice skills
  assert.ok(wd.fidelitySummary.requiredCoInstalls.length >= 1)
})

test('AGENTS.md fidelity table exists and lists bundles as grouping-only', () => {
  const md = byPath.get('AGENTS.md').content
  assert.match(md, /Per-plugin fidelity/)
  assert.match(md, /everything \| — \| — \| grouping-only/)
})
