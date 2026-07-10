// Minimal TOML parser for validating THIS generator's own output (the bounded grammar
// serialize.mjs emits: top-level scalars, string arrays, one level of [table], and
// basic/literal single- and multi-line strings). Not a general TOML parser — it exists
// so the freshness/round-trip gate can prove our emitted TOML is well-formed and lossless.

/** @param {string} text @returns {Record<string, any>} */
export function parseToml(text) {
  const arr = text.replace(/\r\n/g, '\n').split('\n')
  const root = {}
  let cur = root
  let j = 0
  while (j < arr.length) {
    const line = arr[j]
    j++
    const t = line.trim()
    if (t === '') continue
    if (t.startsWith('[') && t.endsWith(']')) {
      const name = t.slice(1, -1)
      root[name] = {}
      cur = root[name]
      continue
    }
    const m = line.match(/^(\S+)\s*=\s*(.*)$/)
    if (!m) continue
    const key = m[1]
    let rest = m[2]

    if (rest === "'''") {
      const buf = []
      while (j < arr.length) {
        const l = arr[j]
        j++
        if (l.endsWith("'''")) {
          buf.push(l.slice(0, -3))
          break
        }
        buf.push(l)
      }
      cur[key] = buf.join('\n')
    } else if (rest === '"""') {
      const buf = []
      while (j < arr.length) {
        const l = arr[j]
        j++
        if (l.endsWith('"""')) {
          buf.push(l.slice(0, -3))
          break
        }
        buf.push(l)
      }
      cur[key] = unescapeBasic(buf.join('\n'))
    } else if (rest.startsWith('"')) {
      cur[key] = parseBasic(rest)
    } else if (rest.startsWith('[')) {
      cur[key] = parseArray(rest)
    } else {
      cur[key] = rest === 'true' ? true : rest === 'false' ? false : isNaN(+rest) ? rest : +rest
    }
  }
  return root
}

function parseBasic(s) {
  // s is a "..."-quoted single-line basic string
  return unescapeBasic(s.slice(1, -1))
}

function unescapeBasic(s) {
  return s.replace(/\\"/g, '"').replace(/\\\\/g, '\\')
}

function parseArray(s) {
  const inner = s.trim().replace(/^\[/, '').replace(/\]$/, '').trim()
  if (inner === '') return []
  return inner.split(/,\s*/).map((tok) => (tok.startsWith('"') ? parseBasic(tok) : tok))
}
