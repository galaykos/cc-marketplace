// Minimal, dependency-free YAML reader — just the subset the scenario schema uses:
// block mappings, block sequences, nested indentation, `# comments`, and single-line
// flow collections (`{ a: b }`, `[a, b]`). It is deliberately NOT a general YAML
// parser; the harness ships no runtime deps, so this covers exactly what
// scenario/__fixtures__ and the annotated example in scenario-schema.md require.

export type YamlValue = string | number | boolean | null | YamlValue[] | { [k: string]: YamlValue };

type Line = { indent: number; text: string };

// Strip a trailing `# comment` that is not inside quotes. A `#` only starts a
// comment when it is at column 0 or preceded by whitespace (so `foo#bar` and URLs
// survive).
function stripComment(raw: string): string {
  let q: string | null = null;
  for (let i = 0; i < raw.length; i++) {
    const c = raw[i];
    if (q) {
      if (c === q) q = null;
      continue;
    }
    if (c === '"' || c === "'") {
      q = c;
      continue;
    }
    if (c === '#' && (i === 0 || raw[i - 1] === ' ' || raw[i - 1] === '\t')) {
      return raw.slice(0, i);
    }
  }
  return raw;
}

function toLines(text: string): Line[] {
  const out: Line[] = [];
  for (const rawLine of text.replace(/\r\n?/g, '\n').split('\n')) {
    const indent = rawLine.length - rawLine.replace(/^ +/, '').length;
    const body = stripComment(rawLine).replace(/\s+$/, '');
    const trimmed = body.trim();
    if (trimmed === '' || trimmed === '---' || trimmed === '...') continue;
    out.push({ indent, text: trimmed });
  }
  return out;
}

// Split a string at top-level occurrences of `sep`, honouring quotes and nested
// `{}` / `[]`. Used for flow collections.
function splitTopLevel(s: string, sep: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let q: string | null = null;
  let cur = '';
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (q) {
      if (c === q) q = null;
      cur += c;
      continue;
    }
    if (c === '"' || c === "'") {
      q = c;
      cur += c;
      continue;
    }
    if (c === '{' || c === '[') depth++;
    else if (c === '}' || c === ']') depth--;
    if (c === sep && depth === 0) {
      parts.push(cur);
      cur = '';
      continue;
    }
    cur += c;
  }
  if (cur.trim() !== '' || parts.length > 0) parts.push(cur);
  return parts;
}

// Split a mapping line into [key, value] at the first top-level `:` that is followed
// by whitespace or end-of-line. `value` is '' when the key opens a nested block.
function splitKeyValue(line: string): [string, string] {
  let depth = 0;
  let q: string | null = null;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (q) {
      if (c === q) q = null;
      continue;
    }
    if (c === '"' || c === "'") {
      q = c;
      continue;
    }
    if (c === '{' || c === '[') depth++;
    else if (c === '}' || c === ']') depth--;
    else if (c === ':' && depth === 0) {
      const next = line[i + 1];
      if (next === undefined || next === ' ' || next === '\t') {
        return [line.slice(0, i).trim(), line.slice(i + 1).trim()];
      }
    }
  }
  return [line.trim(), ''];
}

function unquote(s: string): string {
  if (s.length >= 2) {
    const a = s[0];
    const b = s[s.length - 1];
    if ((a === '"' && b === '"') || (a === "'" && b === "'")) return s.slice(1, -1);
  }
  return s;
}

// Canonical YAML 1.1 boolean tokens (case-insensitive). Normalizing these to real
// booleans is a safety requirement, not a nicety: a schema gate that keys off
// `mutates === true` would read `mutates: yes`/`True`/`on` as a *string* and fail
// OPEN, letting a destructive step run unguarded.
const TRUE_TOKENS = new Set(['true', 'yes', 'on']);
const FALSE_TOKENS = new Set(['false', 'no', 'off']);

function parseScalar(raw: string): YamlValue {
  const s = raw.trim();
  if (s === '') return null;
  // Only treat a leading `{`/`[` as a flow collection when it also closes on the
  // same line — this reader supports single-line flow only. An unclosed `[…` stays a
  // plain string rather than silently becoming a truncated sequence.
  if (s[0] === '{' && s[s.length - 1] === '}') return parseFlowMap(s);
  if (s[0] === '[' && s[s.length - 1] === ']') return parseFlowSeq(s);
  if ((s[0] === '"' && s.endsWith('"')) || (s[0] === "'" && s.endsWith("'"))) return unquote(s);
  const lower = s.toLowerCase();
  if (TRUE_TOKENS.has(lower)) return true;
  if (FALSE_TOKENS.has(lower)) return false;
  if (s === 'null' || s === '~') return null;
  if (/^-?\d+(\.\d+)?$/.test(s)) return Number(s);
  return s;
}

function parseFlowMap(s: string): { [k: string]: YamlValue } {
  const inner = s.trim().replace(/^\{/, '').replace(/\}$/, '');
  const map: { [k: string]: YamlValue } = {};
  for (const entry of splitTopLevel(inner, ',')) {
    if (entry.trim() === '') continue;
    const [k, v] = splitKeyValue(entry.trim());
    map[unquote(k)] = parseScalar(v);
  }
  return map;
}

function parseFlowSeq(s: string): YamlValue[] {
  const inner = s.trim().replace(/^\[/, '').replace(/\]$/, '');
  const out: YamlValue[] = [];
  for (const entry of splitTopLevel(inner, ',')) {
    if (entry.trim() === '') continue;
    out.push(parseScalar(entry.trim()));
  }
  return out;
}

// Detect whether a `- ` item's remainder is a mapping entry (`key: value`) rather
// than a plain/flow scalar.
function isMapEntry(rest: string): boolean {
  const t = rest.trim();
  if (t === '' || t[0] === '{' || t[0] === '[' || t[0] === '"' || t[0] === "'") return false;
  const [key] = splitKeyValue(t);
  return key !== t; // splitKeyValue only shortens the string when a top-level `: ` exists
}

function parseNode(lines: Line[], start: number, indent: number): [YamlValue, number] {
  if (start >= lines.length) return [null, start];
  const isSeq = lines[start].text.startsWith('- ') || lines[start].text === '-';
  return isSeq ? parseSeq(lines, start, indent) : parseMap(lines, start, indent);
}

function parseSeq(lines: Line[], start: number, indent: number): [YamlValue[], number] {
  const items: YamlValue[] = [];
  let i = start;
  while (i < lines.length && lines[i].indent === indent && (lines[i].text.startsWith('- ') || lines[i].text === '-')) {
    const rest = lines[i].text === '-' ? '' : lines[i].text.slice(2).trim();
    if (rest === '') {
      i++;
      if (i < lines.length && lines[i].indent > indent) {
        const [val, next] = parseNode(lines, i, lines[i].indent);
        items.push(val);
        i = next;
      } else {
        items.push(null);
      }
    } else if (isMapEntry(rest)) {
      // Re-seat the inline `key: value` as a mapping line at indent+2 and let
      // parseMap absorb any deeper sibling keys of this item.
      lines[i] = { indent: indent + 2, text: rest };
      const [val, next] = parseNode(lines, i, indent + 2);
      items.push(val);
      i = next;
    } else {
      items.push(parseScalar(rest));
      i++;
    }
  }
  return [items, i];
}

function parseMap(lines: Line[], start: number, indent: number): [{ [k: string]: YamlValue }, number] {
  const map: { [k: string]: YamlValue } = {};
  let i = start;
  while (i < lines.length && lines[i].indent === indent && !(lines[i].text.startsWith('- ') || lines[i].text === '-')) {
    const [key, value] = splitKeyValue(lines[i].text);
    const k = unquote(key);
    if (value !== '') {
      map[k] = parseScalar(value);
      i++;
    } else {
      i++;
      if (i < lines.length && lines[i].indent > indent) {
        const [val, next] = parseNode(lines, i, lines[i].indent);
        map[k] = val;
        i = next;
      } else {
        map[k] = null;
      }
    }
  }
  return [map, i];
}

export function parseYaml(text: string): YamlValue {
  const lines = toLines(text);
  if (lines.length === 0) return null;
  const [value] = parseNode(lines, 0, lines[0].indent);
  return value;
}
