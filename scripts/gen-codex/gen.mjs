// One-way generator entry point. Discovers all Claude Code plugins and runs every
// registered transform to emit a Codex tree OUTSIDE plugins/. Idempotent: clears the
// output roots and rewrites them, so a re-run with no source change is byte-identical.
//
// Guarantees enforced here:
//  - no transform may write under plugins/ (throws if attempted)
//  - --dry-run lists intended writes without touching disk
import { rmSync, mkdirSync, writeFileSync, copyFileSync, existsSync, chmodSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { discover } from './lib/discover.mjs'
import { getTransforms, makeContext } from './lib/registry.mjs'

// transforms self-register on import (cards 04-08 add these files)
await importIfPresent('./lib/transform-skill.mjs')
await importIfPresent('./lib/transform-command.mjs')
await importIfPresent('./lib/transform-agent.mjs')
await importIfPresent('./lib/transform-hook.mjs')
await importIfPresent('./lib/transform-manifest.mjs')
await importIfPresent('./lib/transform-installer.mjs')

const REPO_ROOT = resolve(import.meta.dirname, '..', '..')
const OUTPUT_ROOTS = ['.agents', 'codex']
// output base is the repo root, unless overridden (the gate regenerates to a temp dir to
// check freshness without touching the working tree). Source is ALWAYS read from REPO_ROOT.
const OUT_BASE = process.env.GEN_CODEX_OUT ? resolve(process.env.GEN_CODEX_OUT) : REPO_ROOT

export function generate({ dryRun = false } = {}) {
  const { plugins } = discover(REPO_ROOT)
  const ctx = makeContext(plugins)

  const writes = []
  for (const { fn } of getTransforms()) {
    for (const plugin of plugins) {
      const out = fn(plugin, ctx) || []
      for (const w of out) writes.push(w)
    }
  }

  // safety: no transform may target plugins/ (path-based, independent of output base)
  for (const w of writes) {
    const norm = w.path.replace(/\\/g, '/')
    if (norm === 'plugins' || norm.startsWith('plugins/')) {
      throw new Error(`transform tried to write under plugins/: ${w.path}`)
    }
  }

  if (dryRun) {
    console.log(`discovered ${plugins.length} plugins; ${writes.length} writes (dry-run, nothing written)`)
    return { plugins, writes }
  }

  for (const root of OUTPUT_ROOTS) rmSync(join(OUT_BASE, root), { recursive: true, force: true })
  for (const w of writes) applyWrite(w)

  console.log(`discovered ${plugins.length} plugins; wrote ${writes.length} files`)
  return { plugins, writes }
}

function applyWrite(w) {
  const abs = resolve(OUT_BASE, w.path)
  mkdirSync(dirname(abs), { recursive: true })
  if (w.copyFrom) copyFileSync(w.copyFrom, abs)
  else writeFileSync(abs, w.content)
  if (w.mode) chmodSync(abs, w.mode)
}

async function importIfPresent(rel) {
  const abs = join(import.meta.dirname, rel)
  if (existsSync(abs)) await import(abs)
}

// CLI
if (import.meta.filename === resolve(process.argv[1] || '')) {
  const dryRun = process.argv.includes('--dry-run')
  generate({ dryRun })
}
