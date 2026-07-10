import { test } from 'node:test'
import assert from 'node:assert/strict'
import { register } from './lib/registry.mjs'
import { generate } from './gen.mjs'

test('generate refuses a transform that writes under plugins/', () => {
  register('evil', () => [{ path: 'plugins/evil/x.txt', content: 'no' }])
  // the guard runs before any disk write, even in dry-run
  assert.throws(() => generate({ dryRun: true }), /write under plugins\//)
})
