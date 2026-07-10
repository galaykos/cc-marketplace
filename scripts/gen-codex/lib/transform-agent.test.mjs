import { test } from 'node:test'
import assert from 'node:assert/strict'
import { generate } from '../gen.mjs'
import { parseToml } from './toml-parse.mjs'
import { AGENT_TOML } from '../schema.mjs'

const { writes } = generate({ dryRun: true })
const agentWrites = writes.filter((w) => /^codex\/agents\/.*\.toml$/.test(w.path))
const byPath = new Map(agentWrites.map((w) => [w.path, w]))

test('every agent produces a valid, parseable TOML with required keys', () => {
  assert.ok(agentWrites.length >= 17)
  for (const w of agentWrites) {
    const t = parseToml(w.content)
    for (const k of AGENT_TOML.required) assert.ok(k in t, `${w.path} missing ${k}`)
  }
})

test('no emitted agent carries a CC model slug', () => {
  for (const w of agentWrites) {
    assert.doesNotMatch(w.content, /^model = "(opus|sonnet|haiku|fable)"/m, `${w.path} leaked a CC model`)
    assert.ok(!('model' in parseToml(w.content)), `${w.path} should omit model`)
  }
})

test('model_reasoning_effort is always a valid Codex enum value', () => {
  for (const w of agentWrites) {
    const t = parseToml(w.content)
    if (t.model_reasoning_effort !== undefined) {
      assert.ok(AGENT_TOML.reasoningEffortEnum.includes(t.model_reasoning_effort), `${w.path}: bad effort ${t.model_reasoning_effort}`)
    }
  }
})

test('read-only reviewer/adversary agents get sandbox_mode=read-only', () => {
  for (const name of ['code-reviewer', 'spec-adversary', 'context-scout', 'architecture-reviewer', 'ui-ux-reviewer', 'opinion-lens']) {
    const w = byPath.get(`codex/agents/${name}.toml`)
    if (!w) continue // agent may not exist in every checkout; assert when present
    assert.equal(parseToml(w.content).sandbox_mode, 'read-only', `${name} must be read-only`)
  }
})

test('developer_instructions round-trips a body with many code fences (brain indexer)', () => {
  const w = byPath.get('codex/agents/indexer.toml')
  assert.ok(w, 'indexer agent present')
  const t = parseToml(w.content)
  assert.match(t.developer_instructions, /```/) // fences survived the TOML round-trip
})

test('bestpractices-skill resolves to a [skills.config] reference', () => {
  const w = byPath.get('codex/agents/database-engineer.toml')
  assert.ok(w, 'database-engineer present')
  const t = parseToml(w.content)
  assert.ok(t['skills.config'], 'has [skills.config]')
  assert.ok(t['skills.config'].skills.includes('sql-best-practices'))
})
