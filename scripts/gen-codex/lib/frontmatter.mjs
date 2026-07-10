// Parse `---`-fenced YAML frontmatter + body from a Markdown string. This repo's
// frontmatter is only simple single-line `key: value` pairs (verified: no block
// scalars, no nested maps); some values are double- or single-quoted. A focused
// parser is correct here and avoids a YAML dependency.

/**
 * @param {string} text
 * @returns {{ frontmatter: Record<string,string>, body: string }}
 */
export function parseFrontmatter(text) {
  const norm = text.replace(/\r\n/g, '\n')
  const lines = norm.split('\n')
  if (lines[0] !== '---') return { frontmatter: {}, body: norm }

  const frontmatter = {}
  let i = 1
  for (; i < lines.length; i++) {
    if (lines[i] === '---') {
      i++
      break
    }
    const line = lines[i]
    if (line.trim() === '') continue
    const idx = line.indexOf(':')
    if (idx === -1) continue
    const key = line.slice(0, idx).trim()
    frontmatter[key] = unquote(line.slice(idx + 1).trim())
  }
  // body is everything after the closing fence; drop a single leading blank line
  let body = lines.slice(i).join('\n')
  if (body.startsWith('\n')) body = body.slice(1)
  return { frontmatter, body }
}

function unquote(v) {
  if (v.length >= 2) {
    const q = v[0]
    if ((q === '"' || q === "'") && v[v.length - 1] === q) {
      return v.slice(1, -1)
    }
  }
  return v
}
