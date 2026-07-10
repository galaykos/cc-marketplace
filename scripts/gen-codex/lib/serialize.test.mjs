import { test } from 'node:test'
import assert from 'node:assert/strict'
import { stableJson, toml, tomlString } from './serialize.mjs'
import { parseToml } from './toml-parse.mjs'

test('stableJson sorts keys recursively and is idempotent', () => {
  const a = stableJson({ b: 1, a: { d: 4, c: 3 } })
  const b = stableJson({ a: { c: 3, d: 4 }, b: 1 })
  assert.equal(a, b) // key order in the input must not matter
  assert.equal(a, stableJson(JSON.parse(a))) // round-trip stable
  assert.match(a, /\n$/) // trailing newline
})

test('toml emits scalars then sub-tables, deterministically', () => {
  const out = toml({ name: 'x', description: 'hi', 'skills.config': { foo: 'bar' } })
  assert.equal(out, toml({ 'skills.config': { foo: 'bar' }, description: 'hi', name: 'x' }))
  assert.match(out, /\[skills\.config\]/)
  // scalar lines come before the table
  assert.ok(out.indexOf('name =') < out.indexOf('[skills.config]'))
})

test('tomlString handles code fences, quotes, and a leading newline losslessly', () => {
  const body = '\n# Title\n```js\nconst s = "x";\n```\nend'
  const emitted = tomlString(body)
  assert.ok(emitted.startsWith("'''\n") && emitted.endsWith("'''"))
  // model the TOML parser exactly: drop the opening ''', trim ONE leading newline, drop the closing '''
  const content = emitted.slice(3).replace(/^\n/, '').slice(0, -3)
  assert.equal(content, body)
})

test('tomlString falls back to basic """ for a MULTILINE value containing triple single-quote', () => {
  const s = "line1\n''' embedded\nline2" // multiline AND contains ''' (can't use a ''' literal)
  const emitted = tomlString(s)
  assert.ok(emitted.startsWith('"""') && emitted.endsWith('"""')) // switched to basic multi-line
  // s has no backslash or ", so the escaped content equals s; model the TOML trim + read
  const content = emitted.slice(3).replace(/^\n/, '').slice(0, -3)
  assert.equal(content, s)
})

test('toml output round-trips through parseToml losslessly', () => {
  const obj = {
    name: 'code-reviewer',
    description: 'Reviews code — one line per finding',
    developer_instructions: '# Role\n```js\nconst s = "x";\n```\nReview `foo` then done.',
    model_reasoning_effort: 'xhigh',
    sandbox_mode: 'read-only',
    'skills.config': { skills: ['sql-best-practices', 'code-smells'] },
  }
  assert.deepEqual(parseToml(toml(obj)), obj)
})

test('serializers are byte-stable across repeated calls', () => {
  const obj = { z: [3, 1, 2], a: 'x' }
  assert.equal(stableJson(obj), stableJson(obj))
  const t = { name: 'a', body: 'line1\nline2' }
  assert.equal(toml(t), toml(t))
})
