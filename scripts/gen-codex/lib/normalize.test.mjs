import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { normalizeBody, normalizeShell, classifyPortability } from './normalize.mjs'

const REPO = resolve(import.meta.dirname, '..', '..', '..')
const read = (p) => readFileSync(resolve(REPO, p), 'utf8')

test('normalizeShell removes every CLAUDE_PLUGIN_ROOT form', () => {
  const src = read('plugins/skill-router/hooks/route.sh') + read('plugins/skill-router/hooks/prime.sh')
  assert.match(src, /CLAUDE_PLUGIN_ROOT/) // fixture actually contains the var
  const { text, remaining } = normalizeShell(src)
  assert.equal(remaining, 0)
  assert.doesNotMatch(text, /CLAUDE_PLUGIN_ROOT/)
  assert.match(text, /\$\{PLUGIN_ROOT\}\/rules\.tsv/) // route.sh's data path rewritten
  assert.match(text, /\$\{PLUGIN_ROOT:-\}/) // prime.sh's :- form rewritten
})

test('normalizeBody rewrites a resolved /plugin:command ref and records unresolved', () => {
  const resolve = (plugin, name) => (name === 'review' && plugin === 'security' ? 'security-review' : null)
  const { text, unresolvedRefs } = normalizeBody('run /security:review then /unknown:thing', resolve)
  assert.match(text, /the `security-review` skill/)
  assert.ok(!text.includes('/security:review'))
  assert.deepEqual(unresolvedRefs, ['/unknown:thing'])
})

test('classifyPortability flags CC-runtime-coupled skills, not plain ones', () => {
  const dc = classifyPortability(read('plugins/orchestration/skills/delegation-contracts/SKILL.md'))
  assert.equal(dc.degraded, true)
  assert.ok(dc.reasons.some((r) => /\.claude\/plugins/.test(r)))

  const harvest = classifyPortability(read('plugins/hindsight/skills/harvest/SKILL.md'))
  assert.equal(harvest.degraded, true)

  const plain = classifyPortability(read('plugins/security/skills/security-review/SKILL.md'))
  assert.equal(plain.degraded, false)
})

test('all three functions are idempotent', () => {
  const resolve = () => 'x-skill'
  const b = normalizeBody('/a:b and /c:d', resolve).text
  assert.equal(normalizeBody(b, resolve).text, b)
  const s = normalizeShell('${CLAUDE_PLUGIN_ROOT}/x').text
  assert.equal(normalizeShell(s).text, s)
  const t = 'has ~/.claude/plugins scan'
  assert.deepEqual(classifyPortability(classifyPortability(t) && t), classifyPortability(t))
})
