#!/usr/bin/env python3
"""Catches translation drift against a base locale: keys and files missing or extra, and placeholder sets that differ, in Laravel lang/ (PHP, JSON), i18next and vue-i18n JSON.
PHP is parsed, never executed; a file outside the literal `return [...]` shape is reported unparsed, not guessed. Misses untranslated or empty values, plural form counts, YAML, runtime keys.
Exit 0 parity, 1 findings or an unparsed file, 2 usage or no base locale in any layout, 3 no locale files found."""
# Why, limits, history: rationale/derivations/plugin-laravel.md § plugins/laravel/scripts/i18n_parity.py
# TWIN: plugins/web-dev/scripts/i18n_parity.py is an identical copy save this line.
import argparse
import json
import os
import re
import sys

LAYOUTS = (
    ('lang', 'laravel'),
    ('resources/lang', 'laravel'),
    ('locales', 'i18next'),
    ('public/locales', 'i18next'),
    ('src/locales', 'vue-i18n'),
    ('src/i18n', 'vue-i18n'),
    ('src/i18n/locales', 'vue-i18n'),
)
LOCALE_RE = re.compile(r'^[a-z]{2,3}(?:[_-][A-Za-z0-9]{2,8})*$')
FILE_UNIT = '<locale>.json'
PLURAL_RE = re.compile(r'^(.*)_(ordinal_)?(zero|one|two|few|many|other)$')
PLURAL_ORDER = ('zero', 'one', 'two', 'few', 'many', 'other')

LARAVEL_PH = re.compile(r'(?<![A-Za-z0-9_]):([A-Za-z][A-Za-z0-9_]*)')
I18NEXT_PH = re.compile(r'\{\{\s*-?\s*([^{}\s,]+)[^{}]*\}\}')
I18NEXT_NEST = re.compile(r'\$t\(\s*([^,)\s]+)')
VUE_PH = re.compile(r'\{\s*([A-Za-z_$][\w$]*|\d+)\s*\}')
VUE_LINK = re.compile(r"@(?:\.[A-Za-z]+)?:(?:\{\s*'([^']*)'\s*\}|\(([^)]*)\)|([\w-]+(?:\.[\w-]+)*))")


def placeholders(fmt, text):
    if fmt == 'laravel':
        # Laravel fills :name, :Name and :NAME from one replacement, so case is not a mismatch.
        return {':' + m.lower() for m in LARAVEL_PH.findall(text)}
    if fmt == 'i18next':
        found = {'{{%s}}' % m for m in I18NEXT_PH.findall(text)}
        found.update('$t(%s)' % m.strip('\'"') for m in I18NEXT_NEST.findall(text))
        return found
    found = {'{%s}' % m for m in VUE_PH.findall(text)}
    found.update('@:' + (a or b or c) for a, b, c in VUE_LINK.findall(text))
    return found


class PhpError(Exception):
    def __init__(self, line, msg):
        Exception.__init__(self, msg)
        self.line = line
        self.msg = msg


_WS = re.compile(r'\s+')
_WORD = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
_NUM = re.compile(r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?![\w.])')
_INTKEY = re.compile(r'^(?:0|[1-9][0-9]*)$')
_DQ_ESC = {'n': '\n', 't': '\t', 'r': '\r', 'v': '\v', 'e': '\x1b', 'f': '\f', '\\': '\\', '$': '$', '"': '"'}
_DQ_NUM = re.compile(r'\\(?:([0-7]{1,3})|x([0-9A-Fa-f]{1,2})|u\{([0-9A-Fa-f]+)\})')


class PhpArrayFile(object):
    """Reads `<?php return [ ... ];` built only from literal strings, numbers, true/false/null and arrays."""

    def __init__(self, text):
        self.s = text
        self.i = 0

    def fail(self, msg):
        raise PhpError(self.s.count('\n', 0, self.i) + 1, msg)

    def snippet(self):
        return self.s[self.i:self.i + 30].split('\n')[0]

    def skip(self):
        s = self.s
        while self.i < len(s):
            m = _WS.match(s, self.i)
            if m:
                self.i = m.end()
            elif s.startswith('//', self.i) or (s[self.i] == '#' and not s.startswith('#[', self.i)):
                j = s.find('\n', self.i)
                self.i = len(s) if j < 0 else j + 1
            elif s.startswith('/*', self.i):
                j = s.find('*/', self.i + 2)
                if j < 0:
                    self.fail('unterminated /* comment')
                self.i = j + 2
            else:
                return

    def word(self):
        m = _WORD.match(self.s, self.i)
        return m.group(0) if m else ''

    def parse(self):
        s = self.s
        self.i = len(s) - len(s.lstrip())
        if s[self.i:self.i + 5].lower() != '<?php':
            self.fail('no <?php open tag')
        self.i += 5
        while True:
            self.skip()
            w = self.word().lower()
            if w not in ('declare', 'namespace', 'use'):
                break
            j = s.find(';', self.i)
            if j < 0:
                self.fail('unterminated %s statement' % w)
            self.i = j + 1
        if w != 'return':
            self.fail('expected `return [...]`, found %r' % self.snippet())
        self.i += len('return')
        tree = self.value()
        if not isinstance(tree, dict):
            self.fail('the file returns a scalar, not an array')
        self.skip()
        if not s.startswith(';', self.i):
            self.fail("expected ';' after the returned array, found %r" % self.snippet())
        self.i += 1
        self.skip()
        if s.startswith('?>', self.i):
            self.i += 2
            if s[self.i:].strip():
                self.fail('content after ?>')
        elif self.i < len(s):
            self.fail('code after the return statement: %r' % self.snippet())
        return tree

    def value(self):
        self.skip()
        s = self.s
        if self.i >= len(s):
            self.fail('unexpected end of file')
        c = s[self.i]
        w = self.word()
        if c == '[':
            self.i += 1
            return self.array(']')
        if w.lower() == 'array':
            self.i += len(w)
            self.skip()
            if s.startswith('(', self.i):
                self.i += 1
                return self.array(')')
            self.fail("expected '(' after array")
        if c in '\'"':
            out = self.string()
            while True:
                save = self.i
                self.skip()
                if s.startswith('.', self.i) and not s.startswith('.=', self.i) and not s.startswith('...', self.i):
                    self.i += 1
                    self.skip()
                    if self.i < len(s) and s[self.i] in '\'"':
                        out += self.string()
                        continue
                    self.fail('concatenation with a non-literal: %r' % self.snippet())
                self.i = save
                return out
        m = _NUM.match(s, self.i)
        if m:
            self.i = m.end()
            return m.group(0)
        if w.lower() in ('true', 'false', 'null'):
            self.i += len(w)
            return None if w.lower() == 'null' else w.lower()
        self.fail('unsupported expression %r: only literal strings, numbers and arrays are read' % self.snippet())

    def array(self, close):
        s = self.s
        out = {}
        nxt = 0
        while True:
            self.skip()
            if self.i >= len(s):
                self.fail('unterminated array')
            if s[self.i] == close:
                self.i += 1
                return out
            first = self.value()
            self.skip()
            if s.startswith('=>', self.i):
                if isinstance(first, dict):
                    self.fail('an array used as a key')
                self.i += 2
                key, val = ('' if first is None else first), self.value()
            else:
                key, val = str(nxt), first
            if _INTKEY.match(key):
                nxt = max(nxt, int(key) + 1)
            out[key] = val
            self.skip()
            if s.startswith(',', self.i):
                self.i += 1
            elif not s.startswith(close, self.i):
                self.fail("expected ',' or '%s', found %r" % (close, self.snippet()))

    def string(self):
        s = self.s
        q = s[self.i]
        j = self.i + 1
        buf = []
        while True:
            if j >= len(s):
                self.fail('unterminated string')
            c = s[j]
            if c == q:
                self.i = j + 1
                return ''.join(buf)
            if c == '\\' and j + 1 < len(s):
                n = s[j + 1]
                if q == "'":
                    buf.append(n if n in "\\'" else c + n)
                    j += 2
                    continue
                if n in _DQ_ESC:
                    buf.append(_DQ_ESC[n])
                    j += 2
                    continue
                m = _DQ_NUM.match(s, j)
                if m:
                    o, x, u = m.groups()
                    buf.append(chr(int(o, 8) if o else int(x, 16) if x else int(u, 16)))
                    j = m.end()
                    continue
            if q == '"' and ((c == '$' and j + 1 < len(s) and (s[j + 1] == '_' or s[j + 1] == '{' or s[j + 1].isalpha()))
                             or s.startswith('{$', j)):
                self.i = j
                self.fail('variable interpolation in a double-quoted string')
            buf.append(c)
            j += 1


def flatten(node, prefix, out):
    if isinstance(node, dict):
        for k, v in node.items():
            flatten(v, '%s.%s' % (prefix, k) if prefix else str(k), out)
    elif isinstance(node, list):
        for k, v in enumerate(node):
            flatten(v, '%s.%s' % (prefix, k) if prefix else str(k), out)
    elif node is None:
        out[prefix] = ''
    else:
        out[prefix] = node if isinstance(node, str) else json.dumps(node)
    return out


def load_unit(path):
    """(flat entries, None) or (None, (line, reason))."""
    try:
        with open(path, encoding='utf-8-sig') as fh:
            text = fh.read()
    except UnicodeDecodeError:
        return None, (0, 'not UTF-8')
    except OSError as e:
        return None, (0, 'unreadable: %s' % (e.strerror or e))
    if path.endswith('.php'):
        try:
            tree = PhpArrayFile(text).parse()
        except PhpError as e:
            return None, (e.line, e.msg)
    else:
        try:
            tree = json.loads(text)
        except ValueError as e:
            return None, (getattr(e, 'lineno', 0), 'invalid JSON: %s' % getattr(e, 'msg', e))
        if not isinstance(tree, dict):
            return None, (1, 'top level is not an object')
    return flatten(tree, '', {}), None


def families(entries, fmt):
    """comparison key -> [(plural suffix or None, value)]; an i18next `<k>_other` makes its `<k>_<form>` siblings one family."""
    out = {}
    for k in sorted(entries):
        m = PLURAL_RE.match(k) if fmt == 'i18next' else None
        if m and '%s_%sother' % (m.group(1), m.group(2) or '') in entries:
            out.setdefault('%s_%s*' % (m.group(1), m.group(2) or ''), []).append((m.group(3), entries[k]))
        else:
            out.setdefault(k, []).append((None, entries[k]))
    return out


def scan(root, rel, fmt):
    """locale -> unit -> path, or {} when the dir holds no locale file."""
    d = os.path.join(root, rel)
    ext = '.php' if fmt == 'laravel' else '.json'
    found = {}
    try:
        names = sorted(os.listdir(d))
    except OSError:
        return {}
    for name in names:
        p = os.path.join(d, name)
        if os.path.isdir(p) and LOCALE_RE.match(name):
            units = {}
            for dirpath, dirnames, filenames in os.walk(p):
                dirnames.sort()
                for fn in sorted(filenames):
                    if fn.endswith(ext):
                        full = os.path.join(dirpath, fn)
                        units[os.path.relpath(full, p).replace(os.sep, '/')] = full
            found[name] = units
        elif os.path.isfile(p) and name.endswith('.json') and LOCALE_RE.match(name[:-5]):
            found.setdefault(name[:-5], {})[FILE_UNIT] = p
    return found if any(found.values()) else {}


def package_format(root):
    try:
        with open(os.path.join(root, 'package.json'), encoding='utf-8-sig') as fh:
            pkg = json.load(fh)
    except (OSError, ValueError):
        return None
    names = set()
    for section in ('dependencies', 'devDependencies', 'peerDependencies'):
        if isinstance(pkg, dict) and isinstance(pkg.get(section), dict):
            names.update(pkg[section])
    nxt = any('i18next' in n for n in names)
    vue = any(n in ('vue-i18n', 'petite-vue-i18n', '@nuxtjs/i18n') or n.startswith('@intlify/') for n in names)
    return ('i18next' if nxt else 'vue-i18n') if nxt != vue else None


def show_key(fmt, unit, ck, members):
    if members[0][0] is not None:
        forms = sorted({sfx for sfx, _ in members}, key=PLURAL_ORDER.index)
        ck = '%s{%s}' % (ck[:-1], ','.join(forms))
    ck = ck.replace('\n', '\\n').replace('\t', '\\t')
    if unit == FILE_UNIT:
        return '"%s"' % ck if fmt == 'laravel' else ck
    if unit.endswith('.php'):
        return '%s.%s' % (unit[:-4], ck)
    return '%s:%s' % (unit[:-5], ck)


def union(fmt, members):
    out = set()
    for _, v in members:
        out |= placeholders(fmt, v)
    return out


def unit_path(rel, loc, unit):
    return '%s/%s.json' % (rel, loc) if unit == FILE_UNIT else '%s/%s/%s' % (rel, loc, unit)


def compare(rel, fmt, files, base):
    findings = []
    data = {}
    for loc in sorted(files):
        for unit, path in sorted(files[loc].items()):
            entries, err = load_unit(path)
            data[(loc, unit)] = None if err else families(entries, fmt)
            if err:
                findings.append({'kind': 'unparsed', 'locale': loc, 'unit': unit, 'file': unit_path(rel, loc, unit),
                                 'line': err[0], 'error': err[1]})
    base_units = files.get(base, {})
    others = [loc for loc in sorted(files) if loc != base]

    def add(kind, loc, unit, ck, members, **extra):
        f = {'kind': kind, 'locale': loc, 'unit': unit, 'key': ck, 'display': show_key(fmt, unit, ck, members)}
        f.update(extra)
        findings.append(f)

    for loc in others:
        for unit in sorted(set(base_units) | set(files[loc])):
            if fmt == 'laravel' and unit == FILE_UNIT:
                continue
            if unit not in files[loc]:
                b = data[(base, unit)]
                findings.append({'kind': 'missing-file', 'locale': loc, 'unit': unit, 'file': unit_path(rel, loc, unit),
                                 'keys': None if b is None else len(b)})
                continue
            if unit not in base_units:
                findings.append({'kind': 'extra-file', 'locale': loc, 'unit': unit, 'file': unit_path(rel, loc, unit)})
                continue
            b, t = data[(base, unit)], data[(loc, unit)]
            if b is None or t is None:
                continue
            for ck in sorted(set(b) - set(t)):
                add('missing', loc, unit, ck, b[ck])
            for ck in sorted(set(t) - set(b)):
                add('extra', loc, unit, ck, t[ck])
            for ck in sorted(set(b) & set(t)):
                pb, pt = union(fmt, b[ck]), union(fmt, t[ck])
                if pb != pt:
                    add('placeholder', loc, unit, ck, b[ck], base=sorted(pb), translation=sorted(pt))

    json_locs = [loc for loc in sorted(files) if FILE_UNIT in files[loc]]
    if fmt == 'laravel' and json_locs and not (FILE_UNIT in base_units and data[(base, FILE_UNIT)] is None):
        # A Laravel JSON key is its own base-language string, so the reference set is every locale's keys.
        ref = {}
        for loc in json_locs:
            for ck in data[(loc, FILE_UNIT)] or {}:
                ref.setdefault(ck, ck)
        for ck, members in (data.get((base, FILE_UNIT)) or {}).items():
            ref[ck] = members[0][1]
        for loc in others:
            if FILE_UNIT not in files[loc]:
                findings.append({'kind': 'missing-file', 'locale': loc, 'unit': FILE_UNIT,
                                 'file': unit_path(rel, loc, FILE_UNIT), 'keys': len(ref)})
                continue
            t = data[(loc, FILE_UNIT)]
            if t is None:
                continue
            for ck in sorted(set(ref) - set(t)):
                add('missing', loc, FILE_UNIT, ck, [(None, ck)])
            for ck in sorted(set(ref) & set(t)):
                pb, pt = placeholders(fmt, ref[ck]), union(fmt, t[ck])
                if pb != pt:
                    add('placeholder', loc, FILE_UNIT, ck, t[ck], base=sorted(pb), translation=sorted(pt))
    return findings


def render(report):
    base = report['base_locale']
    lines = []
    for lay in report['layouts']:
        lines.append('%s  %s/  base %s  locales: %s%s' % (
            lay['format'], lay['dir'], base, ', '.join(lay['locales']),
            '  (format from package.json)' if lay['format_source'] == 'package.json' else ''))
        if not lay['findings']:
            lines.append('  parity')
        for f in lay['findings']:
            k = f['kind']
            if k == 'base-missing':
                lines.append("  base-missing  no '%s' locale here; pass --base-locale with one of: %s"
                             % (base, ', '.join(lay['locales'])))
            elif k == 'unparsed':
                lines.append('  %s  unparsed  %s:%s: %s' % (f['locale'], f['file'], f['line'], f['error']))
            elif k == 'missing-file':
                n = '?' if f['keys'] is None else f['keys']
                lines.append('  %s  missing-file  %s (%s keys)' % (f['locale'], f['file'], n))
            elif k == 'extra-file':
                lines.append('  %s  extra-file  %s (%s has no such file)' % (f['locale'], f['file'], base))
            elif k == 'placeholder':
                lines.append('  %s  placeholder  %s  %s: %s  %s: %s' % (
                    f['locale'], f['display'], base, ' '.join(f['base']) or '(none)',
                    f['locale'], ' '.join(f['translation']) or '(none)'))
            else:
                lines.append('  %s  %s  %s' % (f['locale'], k, f['display']))
    n = sum(len(lay['findings']) for lay in report['layouts'])
    lines.append('i18n_parity: %d finding(s) in %d layout(s); exit %d' % (n, len(report['layouts']), report['exit']))
    return '\n'.join(lines)


def main(argv):
    ap = argparse.ArgumentParser(prog='i18n_parity.py',
                                 description='Compare each locale against the base locale: missing and extra keys, placeholder sets.')
    ap.add_argument('root', nargs='?', default='.', help='project root (default: .)')
    ap.add_argument('--base-locale', default='en', help='locale the others are compared to (default: en)')
    ap.add_argument('--json', action='store_true', help='print the report as JSON')
    args = ap.parse_args(argv)
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(errors='backslashreplace')
    root, base = args.root, args.base_locale
    if not os.path.isdir(root):
        print('i18n_parity.py: not a directory: %s' % root, file=sys.stderr)
        return 2
    override = package_format(root)
    layouts, seen = [], set()
    for rel, fmt in LAYOUTS:
        d = os.path.join(root, rel)
        if not os.path.isdir(d) or os.path.realpath(d) in seen:
            continue
        seen.add(os.path.realpath(d))
        files = scan(root, rel, fmt)
        if not files:
            continue
        source = 'path'
        if fmt != 'laravel' and override and override != fmt:
            fmt, source = override, 'package.json'
        lay = {'dir': rel, 'format': fmt, 'format_source': source, 'locales': sorted(files)}
        has_base = base in files or (fmt == 'laravel' and any(FILE_UNIT in u for u in files.values()))
        lay['findings'] = compare(rel, fmt, files, base) if has_base else [{'kind': 'base-missing'}]
        layouts.append(lay)
    report = {'root': root, 'base_locale': base, 'layouts': layouts}
    if not layouts:
        report['exit'] = 3
        report['looked_in'] = [rel + '/' for rel, _ in LAYOUTS]
        if args.json:
            print(json.dumps(report, indent=2))
        else:
            print('i18n_parity: no locale files under %s (looked in %s); exit 3' % (root, ', '.join(report['looked_in'])))
        return 3
    if all(lay['findings'] == [{'kind': 'base-missing'}] for lay in layouts):
        report['exit'] = 2
    else:
        report['exit'] = 1 if any(lay['findings'] for lay in layouts) else 0
    print(json.dumps(report, indent=2) if args.json else render(report))
    return report['exit']


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
