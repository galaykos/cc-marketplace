import { readdirSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'

/** Recursively list files under `dir` as { rel, abs }, sorted by rel for determinism. */
export function walkFiles(dir) {
  const out = []
  function rec(d) {
    for (const name of readdirSync(d).sort()) {
      const abs = join(d, name)
      if (statSync(abs).isDirectory()) rec(abs)
      else out.push({ rel: relative(dir, abs), abs })
    }
  }
  rec(dir)
  return out.sort((a, b) => (a.rel < b.rel ? -1 : a.rel > b.rel ? 1 : 0))
}

const FM_BLOCK = /^---\n[\s\S]*?\n---\n?/

/** Split a Markdown doc into its verbatim frontmatter block and the body after it. */
export function splitFrontmatterBlock(raw) {
  const norm = raw.replace(/\r\n/g, '\n')
  const m = norm.match(FM_BLOCK)
  const block = m ? m[0] : ''
  return { block, body: norm.slice(block.length) }
}
