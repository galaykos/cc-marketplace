import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseScenario, resolveSettings, captureKey, ScenarioError, VERBS } from './schema.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const fixture = (name: string): string => fs.readFileSync(path.join(here, '__fixtures__', name), 'utf8');

test('valid sidebar scenario parses with stable stepIndex capture keys', () => {
  const scn = parseScenario(fixture('sidebar.valid.yaml'));

  assert.equal(scn.id, 'sidebar-toggle');
  assert.equal(scn.engine, 'deterministic');
  assert.equal(scn.steps.length, 4);

  // stepIndex is sequential and stable.
  assert.deepEqual(scn.steps.map((s) => s.stepIndex), [0, 1, 2, 3]);
  // verbs are drawn from the frozen vocabulary.
  assert.deepEqual(scn.steps.map((s) => s.verb), ['goto', 'click', 'hover', 'click']);
  for (const s of scn.steps) assert.ok((VERBS as readonly string[]).includes(s.verb));

  // Capture keys follow `<route>__<stepIndex>__<viewport>` for every viewport.
  assert.equal(scn.steps[1].keys.desktop, 'sidebar-toggle__1__desktop');
  assert.equal(scn.steps[1].keys.mobile, 'sidebar-toggle__1__mobile');
  assert.equal(scn.steps[3].keys.desktop, 'sidebar-toggle__3__desktop');
  assert.equal(scn.steps[3].keys.desktop, captureKey(scn.id, 3, 'desktop'));

  // A read-only flow: no mutation, no announcement.
  assert.equal(scn.mutating, false);
  assert.equal(scn.announcement, null);

  // Scenario-level settings are captured; expect/match blocks are preserved.
  assert.equal(scn.threshold, 0.01);
  assert.deepEqual(scn.mask, ['[data-testid=clock]']);
  assert.equal(scn.steps[0].match?.ref, 'baselines/sidebar-closed.png');
  assert.ok(Array.isArray(scn.steps[1].expect?.dom));
});

test('bad-verb scenario is rejected', () => {
  assert.throws(
    () => parseScenario(fixture('bad-verb.yaml')),
    (err: unknown) => err instanceof ScenarioError && /unknown step verb 'scroll'/.test((err as Error).message),
  );
});

test('unflagged-mutation scenario is rejected by the read-only gate', () => {
  assert.throws(
    () => parseScenario(fixture('unflagged-mutation.yaml')),
    (err: unknown) => err instanceof ScenarioError && /allowMutations/.test((err as Error).message),
  );
});

test('a flagged mutation scenario parses and announces state-changing actions', () => {
  const scn = parseScenario(fixture('unflagged-mutation.yaml').replace('id: unflagged-mutation', 'id: flagged\nallowMutations: true'));
  assert.equal(scn.mutating, true);
  assert.equal(scn.allowMutations, true);
  assert.equal(scn.announcement, 'this scenario performs state-changing actions');
});

test('setting precedence is CLI > scenario > config > default', () => {
  assert.equal(resolveSettings({}, {}, {}).threshold, 0.01); // built-in default
  assert.equal(resolveSettings({ threshold: 0.05 }, { threshold: 0.2 }).threshold, 0.05); // scenario over config
  assert.equal(resolveSettings({ threshold: 0.05 }, {}, { threshold: 0.001 }).threshold, 0.001); // CLI over scenario
  assert.equal(resolveSettings({}, { threshold: 0.2 }).threshold, 0.2); // config over default
});
