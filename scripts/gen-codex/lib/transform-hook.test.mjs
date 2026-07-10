import { test } from 'node:test'
import assert from 'node:assert/strict'
import { generate } from '../gen.mjs'

const { writes } = generate({ dryRun: true })
const byPath = new Map(writes.map((w) => [w.path, w]))
const hookFiles = writes.filter((w) => /^codex\/[^/]+\/hooks\//.test(w.path))

test('no emitted hooks.json or script contains CLAUDE_PLUGIN_ROOT', () => {
  for (const w of hookFiles) {
    if (w.content !== undefined) assert.doesNotMatch(w.content, /CLAUDE_PLUGIN_ROOT/, `${w.path}`)
  }
})

test('no emitted hooks.json has a SessionEnd key', () => {
  for (const w of writes.filter((w) => w.path.endsWith('/hooks.json'))) {
    assert.doesNotMatch(w.content, /"SessionEnd"/, `${w.path}`)
  }
})

test('hindsight (SessionEnd-only) emits NO hooks.json', () => {
  assert.equal(byPath.has('codex/hindsight/hooks/hooks.json'), false)
})

test('skill-router rules.tsv is copied and route.sh reads ${PLUGIN_ROOT}/rules.tsv', () => {
  assert.ok(byPath.get('codex/skill-router/rules.tsv'), 'rules.tsv copied')
  const route = byPath.get('codex/skill-router/hooks/route.sh')
  assert.ok(route)
  assert.match(route.content, /\$\{PLUGIN_ROOT\}\/rules\.tsv/)
})

test('skill-router matcher Edit|Write|MultiEdit remaps to valid Codex tools', () => {
  const hj = byPath.get('codex/skill-router/hooks/hooks.json')
  assert.ok(hj)
  // MultiEdit -> apply_patch; Edit/Write kept
  assert.match(hj.content, /apply_patch/)
  assert.doesNotMatch(hj.content, /MultiEdit/)
})

test('scripts are marked executable', () => {
  for (const w of writes.filter((w) => w.path.endsWith('.sh'))) {
    assert.equal(w.mode, 0o755, `${w.path} not +x`)
  }
})
