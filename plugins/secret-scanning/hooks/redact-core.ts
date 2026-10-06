export type Pattern = { kind: 'secret' | 'assigned' | 'placeholder'; label: string; re: RegExp }

type Span = { start: number; end: number; ranks: number[]; opensKey: boolean }

// Key blocks left open at the end of a value, by path inside it: '' the value itself, ."key" a field, [i] an element.
type Open = Map<string, number[]>

const NONE: Open = new Map()

// The rules and messages of scan.sh's load_patterns, read against the pattern with `\\` pairs dropped.
const DIALECT = /\[\[(:|\.|=)|\[:[A-Za-z]+:\]|(^|[^\\])\(\?|\\[1-9]/
const ESCAPE = /\\[^\].[+*?(){}|^$\/-]/

// scan.sh's probe: no placeholder word, and every character class an assigned value can carry.
const PROBE = 'Kq7Zt9_Wm2-Rp4/Lx8+Vn3=Bc6'

const OPERATOR = /^[^:=]*[:=]["' ]*/

const VALUE_STOPS = { '"': /"/g, "'": /'/g, ' ': /["'`\s]/g }

const KEY_END = /-----END ([A-Z]+ )?PRIVATE KEY-----/g

const LINE_BREAK = /\n|\\n/g
const PEM_LINE = /^(?:[A-Za-z0-9+\/=]*|(?:Proc-Type|DEK-Info):.*)$/
// The last base64 run of a key held in a quoted string literal, cut off by the closing quote rather than a line break.
const QUOTED_RUN = /^[ \t]*[A-Za-z0-9+\/=]+(?=["'])/

// The only characters grep -i folds into ASCII letters under C.UTF-8; JavaScript's i without the u flag folds neither.
const FOLDABLE = /[\u017f\u0131]/g
const FOLDS: Record<string, string> = { '\u017f': 's', '\u0131': 'i' }

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (typeof value !== 'object' || value === null) {
    return false
  }

  const proto: unknown = Object.getPrototypeOf(value)

  return proto === Object.prototype || proto === null
}

function compiled(source: string, flags: string, n: number): RegExp {
  try {
    return new RegExp(source, flags)
  } catch {
    throw new Error(`line ${n} has a pattern JavaScript cannot compile`)
  }
}

function parsedRow(line: string, n: number): Pattern | null {
  if (line.includes('\r')) {
    throw new Error(`line ${n} carries a carriage return`)
  }

  if (line === '' || line.startsWith('#')) {
    return null
  }

  const fields = line.split('\t')

  if (fields.length !== 4) {
    throw new Error(`line ${n} has ${fields.length} fields, not 4`)
  }

  const [kind = '', label = '', flags = '', source = ''] = fields

  if (label === '' || source === '') {
    throw new Error(`line ${n} has an empty label or pattern`)
  }

  if (source.startsWith(' ') || source.endsWith(' ')) {
    throw new Error(`line ${n} has a pattern that starts or ends with a space; write an edge space as [ ]`)
  }

  if (flags !== '-' && flags !== 'i') {
    throw new Error(`line ${n} has flags '${flags}', not - or i`)
  }

  if (kind !== 'secret' && kind !== 'assigned' && kind !== 'placeholder') {
    throw new Error(`line ${n} has kind '${kind}', not secret, assigned or placeholder`)
  }

  const bare = source.replaceAll('\\\\', '')

  if (DIALECT.test(bare)) {
    throw new Error(
      `line ${n} uses [[:, [[., [[=, a [:class:], (? or a backreference, which grep and JavaScript read differently`,
    )
  }

  if (ESCAPE.test(bare)) {
    throw new Error(
      `line ${n} escapes a character other than ] . [ + * ? ( ) { } | ^ $ / -, which grep and JavaScript read differently`,
    )
  }

  // s: a line never holds a newline, and grep's . matches CR, U+2028 and U+2029 as JavaScript's does only under s.
  const re = compiled(source, flags === 'i' ? 'gis' : 'gs', n)

  if (''.search(re) === 0) {
    throw new Error(`line ${n} has a pattern that matches the empty string`)
  }

  if (kind === 'placeholder' && PROBE.search(new RegExp(source, 'is')) !== -1) {
    throw new Error(`line ${n}: a placeholder row matches a secret-shaped value`)
  }

  return { kind, label, re }
}

export function parsePatterns(tsv: string): Pattern[] {
  const patterns: Pattern[] = []

  tsv.split('\n').forEach((line, index) => {
    const pattern = parsedRow(line, index + 1)

    if (pattern) {
      patterns.push(pattern)
    }
  })

  if (!patterns.some(pattern => pattern.kind === 'secret')) {
    throw new Error('no secret row')
  }

  return patterns
}

/** Reads `s` as one line: scan.sh's placeholder() only ever receives one grep -o match. */
export function isPlaceholder(s: string, pats: Pattern[]): boolean {
  if (pats.some(pattern => pattern.kind === 'placeholder' && s.search(pattern.re) !== -1)) {
    return true
  }

  return new Set(s).size <= 1
}

// grep matches line by line, so no match spans a newline; the masked span of a private key block can.
function spansOf(text: string, pats: Pattern[]): Span[] {
  const spans: Span[] = []
  let offset = 0

  for (const line of text.split('\n')) {
    const folded = line.replace(FOLDABLE, ch => FOLDS[ch] ?? ch)

    pats.forEach((pattern, rank) => {
      if (pattern.kind === 'placeholder') {
        return
      }

      const stops = { '"': -1, "'": -1, ' ': -1 }

      // matchAll starts at lastIndex, which a caller's exec() or test() on an exported Pattern may have moved.
      pattern.re.lastIndex = 0

      for (const found of (pattern.re.ignoreCase ? folded : line).matchAll(pattern.re)) {
        const end = found.index + found[0].length
        const match = line.slice(found.index, end)
        // A placeholder word in the variable name must not release a real value.
        const value = pattern.kind === 'assigned' ? match.replace(OPERATOR, '') : match

        if (isPlaceholder(value || match, pats)) {
          continue
        }

        if (pattern.kind === 'secret') {
          const opensKey = match.startsWith('-----BEGIN ') && match.endsWith('PRIVATE KEY-----')

          spans.push({ start: offset + found.index, end: offset + end, ranks: [rank], opensKey })
          continue
        }

        const quote = match.charAt(match.length - value.length - 1)
        const closer = quote === '"' || quote === "'" ? quote : ' '

        if (stops[closer] < end) {
          VALUE_STOPS[closer].lastIndex = end
          stops[closer] = VALUE_STOPS[closer].exec(line)?.index ?? line.length
        }

        spans.push({ start: offset + end - value.length, end: offset + stops[closer], ranks: [rank], opensKey: false })
      }
    })

    offset += line.length + 1
  }

  return spans
}

// Where a key block with no END after it in this string stops: after its last PEM-shaped line.
function pemBlockEnd(text: string, from: number): { end: number; open: boolean } {
  let end = from
  let at = from

  for (;;) {
    LINE_BREAK.lastIndex = at
    const lineBreak = LINE_BREAK.exec(text)
    const line = text.slice(at, lineBreak ? lineBreak.index : text.length)
    const kept = line.trimEnd()
    const content = kept.endsWith('\\r') ? kept.slice(0, -2).trimEnd() : kept

    if (!PEM_LINE.test(content.trimStart())) {
      const run = QUOTED_RUN.exec(line)

      return { end: run ? at + run[0].length : end, open: false }
    }

    if (content.trim() !== '') {
      end = at + content.length
    }

    if (!lineBreak) {
      return { end, open: true }
    }

    at = lineBreak.index + lineBreak[0].length
  }
}

// `carried` is a key block left open by an earlier value; `open` is one this string leaves open.
function merged(text: string, spans: Span[], carried: number[] | null): { spans: Span[]; open: number[] | null } {
  const out: Span[] = []
  const open = new Set<number>()
  const all = carried ? [{ start: 0, end: 0, ranks: carried, opensKey: true }, ...spans] : spans
  let searchedFrom = Infinity
  let keyEnd: { start: number; end: number } | null = null

  for (const span of [...all].sort((a, b) => a.start - b.start)) {
    let end = span.end

    if (span.opensKey) {
      if (span.end < searchedFrom || (keyEnd !== null && keyEnd.start < span.end)) {
        KEY_END.lastIndex = span.end
        const found = KEY_END.exec(text)

        searchedFrom = span.end
        keyEnd = found ? { start: found.index, end: found.index + found[0].length } : null
      }

      const block = keyEnd ? { end: keyEnd.end, open: false } : pemBlockEnd(text, span.end)

      end = block.end

      if (block.open) {
        span.ranks.forEach(rank => open.add(rank))
      }
    }

    if (end <= span.start) {
      continue
    }

    const last = out[out.length - 1]

    if (last && span.start <= last.end) {
      last.end = Math.max(last.end, end)
      last.ranks.push(...span.ranks)
    } else {
      out.push({ ...span, end, ranks: [...span.ranks] })
    }
  }

  return { spans: out, open: open.size > 0 ? [...open] : null }
}

function labelsOf(ranks: Iterable<number>, pats: Pattern[]): string[] {
  const ordered = [...new Set(ranks)].sort((a, b) => a - b)

  return [...new Set(ordered.flatMap(rank => pats[rank]?.label ?? []))]
}

function redactedText(
  text: string,
  pats: Pattern[],
  found: Set<number>,
  carried: number[] | null = null,
): { text: string; open: number[] | null } {
  const { spans, open } = merged(text, spansOf(text, pats), carried)
  let out = ''
  let at = 0

  for (const span of spans) {
    out += `${text.slice(at, span.start)}[REDACTED:${labelsOf(span.ranks, pats).join(', ')}]`
    at = span.end
    span.ranks.forEach(rank => found.add(rank))
  }

  return { text: spans.length === 0 ? text : out + text.slice(at), open }
}

function redactedError(error: Error, pats: Pattern[], found: Set<number>): Error {
  const copy: Error = Object.setPrototypeOf(new Error(), Object.getPrototypeOf(error))

  for (const key of new Set(['stack', ...Object.getOwnPropertyNames(error)])) {
    Object.defineProperty(copy, key, {
      value: walked(Reflect.get(error, key), pats, found, NONE).value,
      enumerable: Object.getOwnPropertyDescriptor(error, key)?.enumerable ?? false,
      writable: true,
      configurable: true,
    })
  }

  return copy
}

function under(carried: Open, segment: string): Open {
  if (carried.size === 0) {
    return NONE
  }

  const inside: Open = new Map()

  for (const [path, ranks] of carried) {
    if (path.startsWith(segment)) {
      inside.set(path.slice(segment.length), ranks)
    }
  }

  return inside
}

function joinedOpen(first: Open, second: Open): Open {
  if (first.size === 0 || second.size === 0) {
    return first.size === 0 ? second : first
  }

  const both: Open = new Map(first)

  for (const [path, ranks] of second) {
    both.set(path, [...(both.get(path) ?? []), ...ranks])
  }

  return both
}

// Returns the value with its strings masked, and the key blocks it leaves open; a carried path it holds no string at
// passes over it, still open.
function walked(value: unknown, pats: Pattern[], found: Set<number>, carried: Open): { value: unknown; open: Open } {
  if (typeof value === 'string') {
    const redacted = redactedText(value, pats, found, carried.get('') ?? null)

    if (carried.size === 0 && !redacted.open) {
      return { value: redacted.text, open: NONE }
    }

    const open: Open = new Map(carried)

    open.delete('')

    if (redacted.open) {
      open.set('', redacted.open)
    }

    return { value: redacted.text, open }
  }

  if (Array.isArray(value)) {
    const open: Open = new Map()
    let previous = NONE

    const items = value.map((item, index) => {
      const result = walked(item, pats, found, joinedOpen(under(carried, `[${index}]`), previous))

      previous = result.open

      return result.value
    })

    for (const [path, ranks] of previous) {
      open.set(`[${value.length - 1}]${path}`, ranks)
    }

    for (const [path, ranks] of carried) {
      const index = /^\[(\d+)\]/.exec(path)?.[1]

      if (index === undefined || Number(index) >= value.length) {
        open.set(path, ranks)
      }
    }

    return { value: items, open }
  }

  if (value instanceof Error) {
    return { value: redactedError(value, pats, found), open: carried }
  }

  if (!isPlainObject(value)) {
    return { value, open: carried }
  }

  const copy: Record<string, unknown> = Object.create(Object.getPrototypeOf(value))
  const open: Open = new Map()
  const segments: string[] = []

  for (const [key, item] of Object.entries(value)) {
    const segment = `.${JSON.stringify(key)}`
    const result = walked(item, pats, found, under(carried, segment))

    segments.push(segment)
    Object.defineProperty(copy, key, { value: result.value, enumerable: true, writable: true, configurable: true })

    for (const [path, ranks] of result.open) {
      open.set(segment + path, ranks)
    }
  }

  for (const [path, ranks] of carried) {
    if (!segments.some(segment => path.startsWith(segment))) {
      open.set(path, ranks)
    }
  }

  return { value: copy, open }
}

/**
 * Masks each non-placeholder match in the strings of `value` with `[REDACTED:<labels>]`; overlapping matches merge
 * into one mask naming every label. An assigned row keeps its name and operator and masks a quoted value up to its
 * closing quote, an unquoted one up to the next quote or whitespace, either at most to the line end.
 * A private key masks from BEGIN through the next END line in the same string. With no END there, it masks on only
 * over the lines after BEGIN that look like a PEM body (base64, Proc-Type: and DEK-Info: headers, blank lines; a `\n`
 * escape breaks a line), closing at the first line that does not, though a base64 run that a quote ends on that line
 * is still masked. A block still open at the end of an array element
 * carries into the next element at the same path only: a string into the next string, `.text` into the next object's
 * `.text`, `[j]` into the next nested array's `[j]`; it passes over an element with no string at that path. There it
 * masks through the END line if that string holds one, else over PEM-shaped lines as above. No other field is masked.
 * Walks arrays, plain objects (prototype Object.prototype or null) and Errors (every own property: message, stack,
 * cause); keys are never redacted, and a Map, Set or any other object comes back as received.
 * Labels come back in pattern-file order, so the first is the one scan.sh's deny would name.
 */
export function redact(value: unknown, pats: Pattern[]): { value: unknown; labels: string[] } {
  const found = new Set<number>()

  return { value: walked(value, pats, found, NONE).value, labels: labelsOf(found, pats) }
}
