// `--update` safety guards (spec D16 — non-negotiable). Blessing a baseline commits
// a screenshot of a real, possibly authenticated app to git, so `--update` is gated:
//   1. Refuse on a DIRTY git tree unless acknowledged (blessing a WIP state is how
//      baselines get silently poisoned).
//   2. WARN explicitly that images are committed to git and may embed rendered data
//      (auth tokens / PII); require an ack before anything is written.
//   3. PRE-CAPTURE masking of config `mask` selectors — enforced in `capture.ts`, which
//      paints masked regions before the PNG is ever blessed (not only at diff time).
// This module owns guards 1 + 2 (pure, git runner injectable so tests are hermetic).

import { spawnSync } from 'node:child_process';

export type GitStatus = { available: boolean; clean: boolean; dirty: string[] };

/** Runner shape so tests can inject a fake `git` without a real repo. */
export type GitRunner = (args: string[], cwd: string) => { status: number | null; stdout: string };

const realGit: GitRunner = (args, cwd) => {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8' });
  return { status: r.status, stdout: r.stdout ?? '' };
};

/** Porcelain working-tree status for `baseDir`. A genuine non-repo (or absent git)
 * — `rev-parse` itself fails — yields `available:false`; the dirty guard then cannot
 * fire and only guard 2 applies. But once we have CONFIRMED this IS a work tree, a
 * failing `git status --porcelain` (index lock, perms, corrupt repo) must FAIL CLOSED:
 * we cannot prove the tree is clean, so we treat it as dirty/unknown (`available:true,
 * clean:false`) and force `--ack-dirty`. Reporting `available:false` here would let the
 * dirty guard be skipped and `--update` proceed on an unverified tree — a fail-OPEN. */
export function gitStatus(baseDir: string, run: GitRunner = realGit): GitStatus {
  const inside = run(['rev-parse', '--is-inside-work-tree'], baseDir);
  if (inside.status !== 0 || inside.stdout.trim() !== 'true') {
    return { available: false, clean: true, dirty: [] };
  }
  const st = run(['status', '--porcelain'], baseDir);
  if (st.status !== 0) return { available: true, clean: false, dirty: ['<status unavailable>'] };
  const dirty = st.stdout.split('\n').map((l) => l.trimEnd()).filter((l) => l.length > 0);
  return { available: true, clean: dirty.length === 0, dirty };
}

export const COMMIT_WARNING =
  'visual-check: --update writes screenshot PNGs into .visual-check/baselines/ which are ' +
  'COMMITTED TO GIT. A rendered page can embed authenticated or personal data (auth tokens, ' +
  'PII, account details). Config `mask` selectors are painted out before blessing, but you ' +
  'own what remains. Re-run with --ack-commit once you have confirmed the captures are safe.';

export type GuardInput = { git: GitStatus; ackCommit: boolean; ackDirty: boolean };
export type GuardResult = { ok: boolean; reason?: string; warnings: string[] };

/** Evaluate guards 1 + 2. Always surfaces the commit warning; returns `ok:false` with
 * a specific reason when a required acknowledgement is missing. Order: dirty tree first
 * (the more dangerous poisoning), then the blanket commit/PII ack. */
export function checkUpdateGuards(i: GuardInput): GuardResult {
  const warnings = [COMMIT_WARNING];
  if (i.git.available && !i.git.clean && !i.ackDirty) {
    return {
      ok: false,
      warnings,
      reason:
        `refusing --update on a dirty git tree (${i.git.dirty.length} uncommitted change(s)); ` +
        'blessing a WIP state poisons the baseline. Commit or stash first, or re-run with --ack-dirty.',
    };
  }
  if (!i.ackCommit) {
    return {
      ok: false,
      warnings,
      reason:
        '--update writes committed screenshots that may contain rendered auth/PII data; ' +
        're-run with --ack-commit to acknowledge before any baseline is written.',
    };
  }
  return { ok: true, warnings };
}
