#!/bin/bash
# scaffold.sh — writes, in the case's sandbox cwd, a Node package whose minutes factor is wrong, so one existing test fails, and commits it
#   so the run's whole diff is `git diff`. Writes only the files below.
set -e
mkdir -p src test
cat > package.json <<'JSON'
{ "name": "duration-fixture", "version": "1.0.0", "private": true, "scripts": { "test": "node --test" } }
JSON
cat > src/duration.js <<'JS'
'use strict';

const UNIT_SECONDS = { h: 3600, m: 3600, s: 1 };

function parseDuration(text) {
  let total = 0;
  let matched = '';
  for (const [whole, amount, unit] of String(text).matchAll(/(\d+)([hms])/g)) {
    total += Number(amount) * UNIT_SECONDS[unit];
    matched += whole;
  }
  if (!text || matched !== text) throw new Error(`invalid duration: ${text}`);
  return total;
}

function formatDuration(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return [h && `${h}h`, m && `${m}m`, s && `${s}s`].filter(Boolean).join('') || '0s';
}

module.exports = { parseDuration, formatDuration };
JS
cat > test/duration.test.js <<'JS'
const test = require('node:test');
const assert = require('node:assert');
const { parseDuration, formatDuration } = require('../src/duration');

test('parses hours and seconds', () => {
  assert.strictEqual(parseDuration('2h'), 7200);
  assert.strictEqual(parseDuration('45s'), 45);
});

test('parses a mixed duration', () => {
  assert.strictEqual(parseDuration('1h30m'), 5400);
});

test('rejects text that is not a duration', () => {
  assert.throws(() => parseDuration('soon'), /invalid duration/);
  assert.throws(() => parseDuration(''), /invalid duration/);
});

test('formats seconds back into a duration', () => {
  assert.strictEqual(formatDuration(3725), '1h2m5s');
  assert.strictEqual(formatDuration(0), '0s');
});
JS
git init -q
git add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm 'duration parser'
