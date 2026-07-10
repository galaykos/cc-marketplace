// Test runner: `node run-tests.mjs [substring]` runs every lib/*.test.mjs (and any
// *.test.mjs under the generator root), optionally filtered to files whose name
// contains <substring> — so `npm test -- serialize` runs only serialize.test.mjs.
import { readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'

const root = import.meta.dirname
const filter = process.argv[2] || ''

function findTests(dir) {
  const out = []
  for (const name of readdirSync(dir)) {
    if (name === 'node_modules' || name.startsWith('.')) continue
    const full = join(dir, name)
    if (statSync(full).isDirectory()) out.push(...findTests(full))
    else if (name.endsWith('.test.mjs')) out.push(full)
  }
  return out
}

const files = findTests(root)
  .filter((f) => (filter ? f.includes(filter) : true))
  .sort()

if (files.length === 0) {
  console.error(filter ? `no test files match "${filter}"` : 'no test files found')
  process.exit(1)
}

const res = spawnSync(process.execPath, ['--test', ...files], { stdio: 'inherit' })
process.exit(res.status ?? 1)
