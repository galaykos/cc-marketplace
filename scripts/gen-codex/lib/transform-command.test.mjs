import { test } from 'node:test'
import assert from 'node:assert/strict'
import { generate } from '../gen.mjs'

const { writes } = generate({ dryRun: true })
const byPath = new Map(writes.map((w) => [w.path, w]))
const skillMd = /^codex\/[^/]+\/skills\/([^/]+)\/SKILL\.md$/
const allSkillNames = writes.map((w) => w.path.match(skillMd)).filter(Boolean).map((m) => m[1])

test('a portable command becomes cmd-<plugin>-<cmd> bundled under its plugin, name==dir, Use-when trigger', () => {
  const w = byPath.get('codex/a11y/skills/cmd-a11y-audit/SKILL.md')
  assert.ok(w, 'cmd-a11y-audit emitted')
  assert.match(w.content, /\nname: cmd-a11y-audit\n/)
  assert.match(w.content, /description: "Use when the user asks to /)
})

test('cmd-* namespace never collides with a real skill basename', () => {
  const set = new Set(allSkillNames)
  assert.ok(set.has('a11y-audit')) // the skill
  assert.ok(set.has('cmd-a11y-audit')) // the command-skill
  assert.equal(set.size, allSkillNames.length, 'all skill names globally unique')
})

test('bundle uninstall commands are skipped, not emitted', () => {
  assert.equal(allSkillNames.filter((n) => /uninstall/.test(n)).length, 0)
})

test('same-intent command is marked a shorthand alias', () => {
  const w = byPath.get('codex/hindsight/skills/cmd-hindsight-harvest/SKILL.md')
  assert.ok(w, 'cmd-hindsight-harvest emitted')
  assert.match(w.content, /shorthand for the `harvest` skill/)
})

test('command-skill descriptions are deterministic (regenerate identical)', () => {
  const again = new Map(generate({ dryRun: true }).writes.map((w) => [w.path, w]))
  const a = byPath.get('codex/a11y/skills/cmd-a11y-audit/SKILL.md').content
  const b = again.get('codex/a11y/skills/cmd-a11y-audit/SKILL.md').content
  assert.equal(a, b)
})
