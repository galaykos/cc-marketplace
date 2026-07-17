// A genuine passing test so the suite is "covered" — this fixture isolates the
// dead-flag defect on the entrypoint, not a coverage gap. `node --test` reports
// `tests 1`, so the runner verdict is covered and the gate's only RED is the
// dead-affordance verdict from the --differential check.
const { test } = require('node:test');
const assert = require('node:assert');
const app = require('./app.js');

test('app returns done', () => {
  assert.strictEqual(app(), 'done');
});
