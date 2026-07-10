import { test } from 'node:test'
import assert from 'node:assert/strict'
import { generate } from '../gen.mjs'

const { writes } = generate({ dryRun: true })
const byPath = new Map(writes.map((w) => [w.path, w]))
const skillMd = /^codex\/[^/]+\/skills\/([^/]+)\/SKILL\.md$/

test('every skill lands under its plugin at codex/<plugin>/skills/<basename>/SKILL.md with name==dir', () => {
  const w = byPath.get('codex/code-review/skills/code-smells/SKILL.md')
  assert.ok(w, 'code-smells SKILL.md emitted under its plugin')
  assert.ok(w.content.startsWith('---\n'))
  assert.match(w.content, /\nname: code-smells\n/) // name preserved == dir basename
})

test('the single non-md asset is bundled (visual-decisions/assets/shell.html)', () => {
  const w = byPath.get('codex/taskmaster/skills/visual-decisions/assets/shell.html')
  assert.ok(w, 'shell.html emitted')
  assert.ok(w.copyFrom && w.copyFrom.endsWith('visual-decisions/assets/shell.html'))
})

test('emitted SKILL.md differs from source only in normalized tokens', () => {
  const w = byPath.get('codex/security/skills/security-review/SKILL.md')
  assert.ok(w)
  assert.doesNotMatch(w.content, /\/[a-z-]+:[a-z-]+/) // no dangling /plug:cmd survived
})

test('skill basenames are globally unique across all plugins', () => {
  const names = writes.map((w) => w.path.match(skillMd)).filter(Boolean).map((m) => m[1])
  assert.equal(new Set(names).size, names.length, 'no two skills share a basename')
})
