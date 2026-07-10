// Deterministic serializers. Both MUST be byte-stable across runs so the freshness
// gate (card 09) never sees a spurious diff.

/** JSON with recursively sorted object keys, 2-space indent, trailing newline. */
export function stableJson(value) {
  return JSON.stringify(sortKeys(value), null, 2) + '\n'
}

function sortKeys(v) {
  if (Array.isArray(v)) return v.map(sortKeys)
  if (v && typeof v === 'object') {
    const out = {}
    for (const k of Object.keys(v).sort()) out[k] = sortKeys(v[k])
    return out
  }
  return v
}

/**
 * Minimal deterministic TOML writer for the shapes the agent transform needs:
 * top-level scalars (string), string arrays, and one level of sub-tables (e.g.
 * `[skills.config]`). Scalars/arrays are emitted first in sorted-key order, then
 * sub-tables in sorted-key order — deterministic regardless of insertion order.
 *
 * @param {Record<string, any>} obj
 * @returns {string}
 */
export function toml(obj) {
  const scalarKeys = []
  const tableKeys = []
  for (const k of Object.keys(obj)) {
    const val = obj[k]
    if (val && typeof val === 'object' && !Array.isArray(val)) tableKeys.push(k)
    else scalarKeys.push(k)
  }
  const lines = []
  for (const k of scalarKeys.sort()) lines.push(`${k} = ${tomlValue(obj[k])}`)
  for (const k of tableKeys.sort()) {
    lines.push('')
    lines.push(`[${k}]`)
    const t = obj[k]
    for (const tk of Object.keys(t).sort()) lines.push(`${tk} = ${tomlValue(t[tk])}`)
  }
  return lines.join('\n') + '\n'
}

function tomlValue(v) {
  if (Array.isArray(v)) return '[' + v.map(tomlValue).join(', ') + ']'
  if (typeof v === 'boolean' || typeof v === 'number') return String(v)
  return tomlString(String(v))
}

/**
 * Choose a lossless TOML string form:
 * - single line, no special chars -> basic "..."
 * - multi-line and contains no ''' -> literal ''' (no escaping needed)
 * - otherwise -> multi-line basic """ with escaping (handles embedded ''')
 * A newline immediately after an opening ''' / """ is trimmed by TOML, so we add a
 * leading newline for readability only when the value does not start with one and
 * account for it by NOT trimming meaningful content.
 */
export function tomlString(s) {
  const isMultiline = s.includes('\n')
  if (!isMultiline && !/["\\\t]/.test(s)) {
    return '"' + s.replace(/(["\\])/g, '\\$1') + '"'
  }
  if (!s.includes("'''")) {
    // literal multi-line: leading newline after ''' is stripped by TOML, so prefix one
    return "'''\n" + s + "'''"
  }
  // fallback: multi-line basic string with escaping
  const esc = s
    .replace(/\\/g, '\\\\')
    .replace(/"""/g, '\\"\\"\\"')
  return '"""\n' + esc + '"""'
}
