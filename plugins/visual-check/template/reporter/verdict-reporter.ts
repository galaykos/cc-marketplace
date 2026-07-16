import type { Reporter, TestCase, TestResult, FullResult } from '@playwright/test/reporter';
import * as fs from 'fs';
import * as path from 'path';

// Emits the FROZEN verdict.json schema and classifies each per-viewport result into the
// 0/1/2 exit contract:
//   pass  → exitCode 0
//   fail  → exitCode 1  (real visual/functional mismatch)
//   error → exitCode 2  (goto unreachable, timeout, tooling/infra)
// The runner (bin/visual-check.mjs) reads verdict.exitCode and exits with it.

type Asserts = { dom: string[]; console: string[]; layout: string[]; network: string[] };
type Match = { viewport: string; ratio: number | null; diffPath: string; reasons: string[] };
type Step = { id: string; action: string; asserts: Asserts; match: Match; pass: boolean };
type Verdict = {
  status: 'pass' | 'fail' | 'error';
  engine: 'playwright';
  exitCode: 0 | 1 | 2;
  scenario: string;
  steps: Step[];
  reasons: string[];
  runDir: string;
};

function projectName(test: TestCase): string {
  try {
    const p = (test.parent as unknown as { project?: () => { name?: string } | undefined }).project?.();
    if (p?.name) return p.name;
  } catch {
    /* fall through to titlePath */
  }
  const tp = test.titlePath();
  return tp.length > 1 && tp[1] ? tp[1] : 'unknown';
}

function slug(url: string): string {
  try {
    const u = new URL(url);
    const p = (u.pathname || '/').replace(/\/+$/, '') || '/';
    const base = p === '/' ? 'root' : path.basename(p).replace(/\.[^.]+$/, '');
    return base.replace(/[^a-z0-9]+/gi, '-').replace(/^-+|-+$/g, '').toLowerCase() || 'root';
  } catch {
    return 'target';
  }
}

function firstLine(s: string): string {
  return (s || '').split('\n').map((l) => l.trim()).filter(Boolean)[0] || 'unknown error';
}

function parseRatio(msg: string): number | null {
  const m = /ratio\s+(\d*\.?\d+)/i.exec(msg || '');
  if (m) return Number(m[1]);
  const px = /(\d*\.?\d+)\s*%\s*of all image pixels/i.exec(msg || '');
  return px ? Number(px[1]) / 100 : null;
}

function copyDiff(result: TestResult, runDir: string, viewport: string): string {
  const att = (result.attachments || []).find(
    (a) => a.path && /diff/i.test(a.name || '') && (a.contentType || '').includes('png'),
  );
  if (!att || !att.path || !fs.existsSync(att.path)) return '';
  const dest = `${viewport}-diff.png`;
  try {
    fs.copyFileSync(att.path, path.join(runDir, dest));
    return dest;
  } catch {
    return '';
  }
}

class VerdictReporter implements Reporter {
  private records: { test: TestCase; result: TestResult }[] = [];

  onTestEnd(test: TestCase, result: TestResult): void {
    this.records.push({ test, result });
  }

  onEnd(_full: FullResult): void {
    const cwd = process.cwd();
    const runDir = process.env.VC_RUN_DIR || path.join(cwd, '.visual-check', 'results', `${process.pid}-selftest`);
    fs.mkdirSync(runDir, { recursive: true });

    const scenario = process.env.VC_SCENARIO || 'self-test';
    const url = process.env.VC_URL || 'fixture:hello';
    const route = slug(url);

    this.records.sort((a, b) => projectName(a.test).localeCompare(projectName(b.test)));

    const steps: Step[] = [];
    const reasons: string[] = [];
    let sawError = false;
    let sawFail = false;

    this.records.forEach(({ test, result }, idx) => {
      const viewport = projectName(test);
      const errParts = (result.errors || []).map((e) => e.message || '');
      if (result.error?.message) errParts.push(result.error.message);
      // De-dup (result.error usually repeats result.errors[0]) and keep one msg per line.
      const errMsg = [...new Set(errParts.filter(Boolean))].join('\n');
      const timedOut = result.status === 'timedOut';
      const passed = result.status === 'passed';
      const infra = timedOut || /VC_INFRA/.test(errMsg);

      const stepReasons: string[] = [];
      let ratio: number | null = passed ? 0 : null;
      let diffPath = '';

      if (passed) {
        // clean pass
      } else if (infra) {
        sawError = true;
        const reason = timedOut
          ? `${viewport}: timeout after ${result.duration}ms`
          : `${viewport}: ${firstLine(errMsg)}`;
        stepReasons.push(reason);
        reasons.push(reason);
      } else {
        sawFail = true;
        ratio = parseRatio(errMsg);
        diffPath = copyDiff(result, runDir, viewport);
        const reason = `${viewport}: screenshot mismatch${ratio != null ? ` ratio=${ratio}` : ''}`;
        stepReasons.push(reason);
        reasons.push(reason);
      }

      steps.push({
        id: `${route}__${idx}`,
        action: `goto ${url}`,
        asserts: { dom: [], console: [], layout: [], network: [] },
        match: { viewport, ratio, diffPath, reasons: stepReasons },
        pass: passed,
      });
    });

    const status: Verdict['status'] = sawError ? 'error' : sawFail ? 'fail' : 'pass';
    const exitCode: Verdict['exitCode'] = sawError ? 2 : sawFail ? 1 : 0;

    let displayRunDir = runDir;
    const rel = path.relative(cwd, runDir);
    if (rel && !rel.startsWith('..') && !path.isAbsolute(rel)) displayRunDir = rel;
    if (!displayRunDir.endsWith('/')) displayRunDir += '/';

    const verdict: Verdict = {
      status,
      engine: 'playwright',
      exitCode,
      scenario,
      steps,
      reasons,
      runDir: displayRunDir,
    };

    fs.writeFileSync(path.join(runDir, 'verdict.json'), JSON.stringify(verdict, null, 2) + '\n');
  }
}

export default VerdictReporter;
