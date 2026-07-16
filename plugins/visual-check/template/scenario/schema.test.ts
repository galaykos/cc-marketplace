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

// --- #2: id / viewport names are filename-safe (no path traversal) ----------
test('a scenario id with ../ is rejected (becomes a baseline filename)', () => {
  assert.throws(
    () => parseScenario('id: ../evil\nurl: http://x/\nsteps:\n  - goto: /\n'),
    (err: unknown) => err instanceof ScenarioError && /id/.test((err as Error).message) && /baseline key/.test((err as Error).message),
  );
  // A bare `..` id is refused too, and a plain slash.
  assert.throws(() => parseScenario('id: ..\nurl: http://x/\nsteps:\n  - goto: /\n'), ScenarioError);
  assert.throws(() => parseScenario('id: a/b\nurl: http://x/\nsteps:\n  - goto: /\n'), ScenarioError);
  // A normal id still parses.
  assert.equal(parseScenario('id: home.login-v2\nurl: http://x/\nsteps:\n  - goto: /\n').id, 'home.login-v2');
});

test('a viewport name with a path separator is rejected', () => {
  assert.throws(
    () => parseScenario('id: safe\nurl: http://x/\nviewports:\n  - { name: "../bad", width: 100, height: 100 }\nsteps:\n  - goto: /\n'),
    (err: unknown) => err instanceof ScenarioError && /viewport 0 name/.test((err as Error).message),
  );
});

test('duplicate viewport names are rejected', () => {
  assert.throws(
    () => parseScenario('id: dup\nurl: http://x/\nviewports:\n  - { name: desktop, width: 100, height: 100 }\n  - { name: desktop, width: 200, height: 200 }\nsteps:\n  - goto: /\n'),
    (err: unknown) => err instanceof ScenarioError && /duplicate viewport name 'desktop'/.test((err as Error).message),
  );
});

// --- #6: non-canonical booleans must not fail the mutation gate OPEN ---------
test('`mutates: yes` closes the read-only gate (does not read as a false string)', () => {
  // Before normalization `yes` parsed as a string, so `mutates === true` was false
  // and this destructive click ran UNGUARDED. It must now be refused like `true`.
  assert.throws(
    () => parseScenario('id: noncanon\nurl: http://x/\nsteps:\n  - goto: /\n  - click: "[data-testid=delete]"\n    mutates: yes\n'),
    (err: unknown) => err instanceof ScenarioError && /allowMutations/.test((err as Error).message),
  );
  // With opt-in it parses and is flagged as mutating.
  const ok = parseScenario('id: noncanon\nurl: http://x/\nallowMutations: yes\nsteps:\n  - goto: /\n  - click: "[data-testid=delete]"\n    mutates: on\n');
  assert.equal(ok.mutating, true);
  assert.equal(ok.allowMutations, true);
});

test('a non-boolean `mutates` value is rejected outright (no silent fail-open)', () => {
  assert.throws(
    () => parseScenario('id: quoted\nurl: http://x/\nsteps:\n  - goto: /\n  - click: "[data-testid=delete]"\n    mutates: "yes"\n'),
    (err: unknown) => err instanceof ScenarioError && /'mutates' must be a boolean/.test((err as Error).message),
  );
});

// --- #16: an unquoted attribute selector must not reach page.click(null) -----
test('a click with a non-string (list) target is rejected with a clear message', () => {
  assert.throws(
    () => parseScenario('id: nulltarget\nurl: http://x/\nsteps:\n  - click: [data-testid=x]\n'),
    (err: unknown) => err instanceof ScenarioError && /'click' needs a selector string/.test((err as Error).message),
  );
});

// --- type-step text: dedicated field, decoupled from label ------------------
test('a type step reads its input from `text`, leaving `label` as a description', () => {
  const scn = parseScenario(
    'id: typetext\nurl: http://x/\nallowMutations: true\nsteps:\n  - goto: /\n  - type: "input#email"\n    text: "hello@example.com"\n    label: "fill the email field"\n    mutates: true\n',
  );
  assert.equal(scn.steps[1].text, 'hello@example.com');
  assert.equal(scn.steps[1].label, 'fill the email field');
});

// --- resolveSettings returns copies, never the shared DEFAULT arrays --------
test('resolveSettings does not leak DEFAULT viewports/mask by reference', () => {
  const a = resolveSettings({});
  a.viewports.push({ name: 'injected', width: 1, height: 1 });
  a.mask.push('injected');
  const b = resolveSettings({});
  assert.equal(b.viewports.length, 2, 'default viewports unmutated');
  assert.equal(b.mask.length, 0, 'default mask unmutated');
});
