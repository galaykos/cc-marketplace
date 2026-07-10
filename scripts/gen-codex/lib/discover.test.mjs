import { test } from 'node:test'
import assert from 'node:assert/strict'
import { resolve } from 'node:path'
import { discover } from './discover.mjs'

const REPO_ROOT = resolve(import.meta.dirname, '..', '..', '..')

test('discovers all 70 marketplace plugins, name-sorted', () => {
  const { plugins } = discover(REPO_ROOT)
  assert.equal(plugins.length, 70)
  const names = plugins.map((p) => p.name)
  assert.deepEqual(names, [...names].sort())
})

test('splits leaf vs bundle plugins', () => {
  const { plugins } = discover(REPO_ROOT)
  const bundles = plugins.filter((p) => p.isBundle)
  const leaves = plugins.filter((p) => !p.isBundle)
  assert.equal(bundles.length, 8)
  assert.equal(leaves.length, 62)
  assert.ok(bundles.some((p) => p.name === 'everything'))
})

test('captures plugin-root data files (skill-router/rules.tsv)', () => {
  const { plugins } = discover(REPO_ROOT)
  const sr = plugins.find((p) => p.name === 'skill-router')
  assert.ok(sr, 'skill-router present')
  assert.ok(sr.rootData.some((d) => d.name === 'rules.tsv'), 'rules.tsv captured as root data')
  assert.ok(sr.hooks, 'skill-router has hooks')
})

test('enumerates skills/commands/agents for a known plugin', () => {
  const { plugins } = discover(REPO_ROOT)
  const cr = plugins.find((p) => p.name === 'code-review')
  assert.ok(cr.skills.some((s) => s.name === 'code-smells'))
  assert.ok(cr.commands.some((c) => c.name === 'review'))
  assert.ok(cr.agents.some((a) => a.name === 'code-reviewer'))
})
