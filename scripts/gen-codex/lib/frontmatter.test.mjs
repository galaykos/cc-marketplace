import { test } from 'node:test'
import assert from 'node:assert/strict'
import { parseFrontmatter } from './frontmatter.mjs'

test('parses simple frontmatter and body', () => {
  const { frontmatter, body } = parseFrontmatter('---\nname: foo\ndescription: bar\n---\n\nBody line\n')
  assert.equal(frontmatter.name, 'foo')
  assert.equal(frontmatter.description, 'bar')
  assert.equal(body, 'Body line\n')
})

test('strips surrounding double quotes from a value with colons and dashes', () => {
  const { frontmatter } = parseFrontmatter('---\ndescription: "Audit UI: contrast — focus"\n---\nx')
  assert.equal(frontmatter.description, 'Audit UI: contrast — focus')
})

test('keeps a value that merely contains a colon', () => {
  const { frontmatter } = parseFrontmatter('---\nargument-hint: [area | index]\n---\nx')
  assert.equal(frontmatter['argument-hint'], '[area | index]')
})

test('no frontmatter returns whole text as body', () => {
  const { frontmatter, body } = parseFrontmatter('# just markdown\n')
  assert.deepEqual(frontmatter, {})
  assert.equal(body, '# just markdown\n')
})

test('parses a real agent frontmatter shape', () => {
  const src = '---\nname: context-scout\ndescription: Use PROACTIVELY ...\ntools: Read, Grep, Glob\nmodel: sonnet\neffort: high\n---\nYou are a scout.'
  const { frontmatter, body } = parseFrontmatter(src)
  assert.equal(frontmatter.model, 'sonnet')
  assert.equal(frontmatter.effort, 'high')
  assert.equal(frontmatter.tools, 'Read, Grep, Glob')
  assert.equal(body, 'You are a scout.')
})
