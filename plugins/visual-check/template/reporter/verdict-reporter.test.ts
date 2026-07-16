import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import type { TestCase, TestResult, FullResult } from '@playwright/test/reporter';
import VerdictReporter from './verdict-reporter.ts';

// The reporter's only runtime deps are fs/path; its @playwright/test/reporter import is
// type-only (erased), so it runs under `node --test` with no browser and no npm install.

type Verdict = {
  status: 'pass' | 'fail' | 'error';
  exitCode: 0 | 1 | 2;
  steps: { pass: boolean }[];
  reasons: string[];
};

function fakeTest(project: string): TestCase {
  return {
    parent: {}, // no `.project()` → projectName falls back to titlePath()[1]
    titlePath: () => ['file.spec.ts', project, 'renders'],
  } as unknown as TestCase;
}

function fakeResult(status: string, errMsg?: string): TestResult {
  return {
    status,
    errors: errMsg ? [{ message: errMsg }] : [],
    error: undefined,
    duration: 5,
    attachments: [],
  } as unknown as TestResult;
}

// Drive a reporter over `records`, close with `fullStatus`, and read back the verdict.
function runReporter(
  records: { test: TestCase; result: TestResult }[],
  fullStatus: string,
): Verdict {
  const runDir = fs.mkdtempSync(path.join(os.tmpdir(), 'vc-rep-'));
  const prev = process.env.VC_RUN_DIR;
  process.env.VC_RUN_DIR = runDir;
  try {
    const reporter = new VerdictReporter();
    for (const r of records) reporter.onTestEnd(r.test, r.result);
    reporter.onEnd({ status: fullStatus } as unknown as FullResult);
    return JSON.parse(fs.readFileSync(path.join(runDir, 'verdict.json'), 'utf8')) as Verdict;
  } finally {
    if (prev === undefined) delete process.env.VC_RUN_DIR;
    else process.env.VC_RUN_DIR = prev;
  }
}

test('zero records → status:error exitCode:2 (never a silent pass)', () => {
  const v = runReporter([], 'failed');
  assert.equal(v.status, 'error');
  assert.equal(v.exitCode, 2);
  assert.equal(v.steps.length, 0);
  assert.match(v.reasons[0], /no tests executed/i);
});

test('all-passing records but suite status !== passed → status:error exitCode:2', () => {
  const v = runReporter([{ test: fakeTest('desktop'), result: fakeResult('passed') }], 'interrupted');
  assert.equal(v.status, 'error');
  assert.equal(v.exitCode, 2);
  assert.match(v.reasons.join('\n'), /interrupted/);
});

test('all-passing records with suite status passed → status:pass exitCode:0', () => {
  const v = runReporter([{ test: fakeTest('desktop'), result: fakeResult('passed') }], 'passed');
  assert.equal(v.status, 'pass');
  assert.equal(v.exitCode, 0);
  assert.equal(v.steps.length, 1);
  assert.equal(v.steps[0].pass, true);
});

test('a real screenshot mismatch still classifies as fail (exit 1), not the new error', () => {
  const msg = 'Screenshot comparison failed: 3200 pixels (ratio 0.12) are different';
  const v = runReporter([{ test: fakeTest('mobile'), result: fakeResult('failed', msg) }], 'failed');
  assert.equal(v.status, 'fail');
  assert.equal(v.exitCode, 1);
});
