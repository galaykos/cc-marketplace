export type Pattern = { kind: 'secret' | 'assigned' | 'placeholder'; label: string; re: RegExp }

type Span = { start: number; end: number; ranks: number[]; opensKey: boolean }

// The break-delimited lines of one string, built once when a BEGIN there has no END after it. contentEnd drops trailing
// blanks and a `\r` escape; lastNonBase64 and lastTerminator are the last content positions holding a non-base64
// character and one `.` does not match (start - 1 when none). The rest fields describe a scan that starts on the next
// line: where its last non-blank PEM line ends and where its closing line's quoted base64 run ends (-1 when none), and
// whether it reaches the end of the string still open.
type Lines = {
  start: Int32Array
  end: Int32Array
  contentEnd: Int32Array
  lastNonBase64: Int32Array
  lastTerminator: Int32Array
  restEnd: Int32Array
  restQuoted: Int32Array
  restOpen: Uint8Array
}

type Shape = 'blank' | 'filled' | 'closed'

// The rules and messages of patterns.sh's load_patterns, read against the pattern with `\\` pairs dropped.
const DIALECT = /\[\[(:|\.|=)|\[:[A-Za-z]+:\]|(^|[^\\])\(\?|\\[1-9]/
const ESCAPE = /\\[^\].[+*?(){}|^$\/-]/

// patterns.sh's probe: no placeholder word, and every character class an assigned value can carry.
const PROBE = 'Kq7Zt9_Wm2-Rp4/Lx8+Vn3=Bc6'

const OPERATOR = /^[^:=]*[:=]["' ]*/

const VALUE_STOPS = { '"': /"/g, "'": /'/g, ' ': /["'`\s]/g }

const KEY_END = /-----END ([A-Z]+ )?PRIVATE KEY-----/g

const LINE_BREAK = /\n|\\n/g
const BASE64_CHAR = /[A-Za-z0-9+\/=]/
const TERMINATOR = /[\r\u2028\u2029]/
const BLANK = /\s/

// The only characters grep -i folds into ASCII letters under C.UTF-8; JavaScript's i without the u flag folds neither.
const FOLDABLE = /[\u017f\u0131]/g
const FOLDS: Record<string, string> = { '\u017f': 's', '\u0131': 'i' }

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

/** Reads `s` as one line: patterns.sh's placeholder() only ever receives one grep -o match. */
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

// Read from `at`, a line is PEM-shaped when, trimmed, it is base64 only, a Proc-Type: or DEK-Info: header, or blank.
function shapeOf(text: string, lines: Lines, k: number, at: number): Shape {
  const contentEnd = lines.contentEnd[k] ?? at
  let content = at

  while (content < contentEnd && BLANK.test(text.charAt(content))) {
    content++
  }

  if (content >= contentEnd) {
    return 'blank'
  }

  const header = text.startsWith('Proc-Type:', content) || text.startsWith('DEK-Info:', content)
  const last = (header ? lines.lastTerminator[k] : lines.lastNonBase64[k]) ?? content

  return last < content ? 'filled' : 'closed'
}

// Where the last base64 run of a key held in a quoted string literal ends, cut off by the closing quote; -1 when none.
function quotedRunEnd(text: string, lines: Lines, k: number, at: number): number {
  const end = lines.end[k] ?? at
  let run = at

  while (run < end && (text.charAt(run) === ' ' || text.charAt(run) === '\t')) {
    run++
  }

  const runStart = run

  while (run < end && BASE64_CHAR.test(text.charAt(run))) {
    run++
  }

  return run > runStart && /["']/.test(text.charAt(run)) ? run : -1
}

function lineIndex(text: string): Lines {
  let count = 1

  for (LINE_BREAK.lastIndex = 0; LINE_BREAK.exec(text); ) {
    count++
  }

  const lines: Lines = {
    start: new Int32Array(count),
    end: new Int32Array(count),
    contentEnd: new Int32Array(count),
    lastNonBase64: new Int32Array(count),
    lastTerminator: new Int32Array(count),
    restEnd: new Int32Array(count),
    restQuoted: new Int32Array(count),
    restOpen: new Uint8Array(count),
  }
  let at = 0

  for (let k = 0; k < count; k++) {
    LINE_BREAK.lastIndex = at
    const lineBreak = LINE_BREAK.exec(text)
    const end = lineBreak ? lineBreak.index : text.length
    const kept = text.slice(at, end).trimEnd()
    const contentEnd = at + (kept.endsWith('\\r') ? kept.slice(0, -2).trimEnd() : kept).length
    let lastNonBase64 = contentEnd - 1
    let lastTerminator = contentEnd - 1

    while (lastNonBase64 >= at && BASE64_CHAR.test(text.charAt(lastNonBase64))) {
      lastNonBase64--
    }

    while (lastTerminator >= at && !TERMINATOR.test(text.charAt(lastTerminator))) {
      lastTerminator--
    }

    lines.start[k] = at
    lines.end[k] = end
    lines.contentEnd[k] = contentEnd
    lines.lastNonBase64[k] = lastNonBase64
    lines.lastTerminator[k] = lastTerminator
    at = lineBreak ? lineBreak.index + lineBreak[0].length : end
  }

  let restEnd = -1
  let restQuoted = -1
  let restOpen = 1

  for (let k = count - 1; k >= 0; k--) {
    const start = lines.start[k] ?? 0
    const shape = shapeOf(text, lines, k, start)

    lines.restEnd[k] = restEnd
    lines.restQuoted[k] = restQuoted
    lines.restOpen[k] = restOpen

    if (shape === 'closed') {
      restEnd = -1
      restQuoted = quotedRunEnd(text, lines, k, start)
      restOpen = 0
    } else if (shape === 'filled' && restEnd === -1) {
      restEnd = lines.contentEnd[k] ?? -1
    }
  }

  return lines
}

function lineAt(lines: Lines, at: number): number {
  let low = 0
  let high = lines.start.length - 1

  while (low < high) {
    const mid = (low + high + 1) >> 1

    if ((lines.start[mid] ?? Infinity) <= at) {
      low = mid
    } else {
      high = mid - 1
    }
  }

  return low
}

// Where a key block with no END after it in this string stops: after its last PEM-shaped line. `from` is a line start
// or the end of a BEGIN marker, never inside a line's trailing blanks; the rest of the scan is read from `lines`.
function pemBlockEnd(text: string, lines: Lines, from: number): { end: number; open: boolean } {
  const k = lineAt(lines, from)
  const shape = shapeOf(text, lines, k, from)

  if (shape === 'closed') {
    const quoted = quotedRunEnd(text, lines, k, from)

    return { end: quoted === -1 ? from : quoted, open: false }
  }

  const quoted = lines.restQuoted[k] ?? -1
  const last = lines.restEnd[k] ?? -1
  const own = shape === 'filled' ? (lines.contentEnd[k] ?? from) : from

  return { end: quoted !== -1 ? quoted : last !== -1 ? last : own, open: lines.restOpen[k] === 1 }
}

function merged(text: string, spans: Span[]): Span[] {
  const out: Span[] = []
  let searchedFrom = Infinity
  let keyEnd: { start: number; end: number } | null = null
  let lines: Lines | null = null

  for (const span of [...spans].sort((a, b) => a.start - b.start)) {
    let end = span.end

    if (span.opensKey) {
      if (span.end < searchedFrom || (keyEnd !== null && keyEnd.start < span.end)) {
        KEY_END.lastIndex = span.end
        const found = KEY_END.exec(text)

        searchedFrom = span.end
        keyEnd = found ? { start: found.index, end: found.index + found[0].length } : null
      }

      const block = keyEnd ? { end: keyEnd.end, open: false } : pemBlockEnd(text, (lines ??= lineIndex(text)), span.end)

      end = block.end
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

  return out
}

function labelsOf(ranks: Iterable<number>, pats: Pattern[]): string[] {
  const ordered = [...new Set(ranks)].sort((a, b) => a - b)

  return [...new Set(ordered.flatMap(rank => pats[rank]?.label ?? []))]
}

/**
 * Masks each non-placeholder match in `text` with `[REDACTED:<labels>]`; overlapping matches merge into one mask
 * naming every label. An assigned row keeps its name and operator and masks a quoted value up to its closing quote, an
 * unquoted one up to the next quote or whitespace, either at most to the line end.
 * A private key masks from BEGIN through the next END line. With no END, it masks on only over the lines after BEGIN
 * that look like a PEM body (base64, Proc-Type: and DEK-Info: headers, blank lines; a `\n` escape breaks a line),
 * closing at the first line that does not, though a base64 run that a quote ends on that line is still masked.
 * Labels come back in pattern-file order, so the first is the one scan.sh's deny would name.
 */
export function redact(text: string, pats: Pattern[]): { value: string; labels: string[] } {
  const spans = merged(text, spansOf(text, pats))
  const found = new Set<number>()
  let out = ''
  let at = 0

  for (const span of spans) {
    out += `${text.slice(at, span.start)}[REDACTED:${labelsOf(span.ranks, pats).join(', ')}]`
    at = span.end
    span.ranks.forEach(rank => found.add(rank))
  }

  return { value: spans.length === 0 ? text : out + text.slice(at), labels: labelsOf(found, pats) }
}

/** The `[start, end)` ranges of one string that `redact` would mask, in order and merged. */
export function secretSpans(text: string, pats: Pattern[]): { start: number; end: number }[] {
  return merged(text, spansOf(text, pats)).map(({ start, end }) => ({ start, end }))
}
