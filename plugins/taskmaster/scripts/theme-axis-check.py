#!/usr/bin/env python3
"""theme-axis-check.py — machine gate for a visual-decisions theme-axis pass.

python3 theme-axis-check.py <mockup.html> — diffs every frame's `.vd-content` inner HTML against the first (the token preset sits outside it); exit 0 all identical, 1 a frame differs, 2 usage error / unreadable file.
Misses: whether the token preset is a single axis — "one axis per pass" stays author judgment.
Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/theme-axis-check.py
"""
import sys
from html.parser import HTMLParser

VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
        'link', 'meta', 'param', 'source', 'track', 'wbr'}


class Content(HTMLParser):
    # convert_charrefs (default True) resolves entities into handle_data, so &mdash; vs &ndash; still diffs.
    def __init__(self):
        super().__init__()
        self.depth = 0
        self.parts = []
        self.blocks = []

    def handle_starttag(self, tag, attrs):
        if self.depth:
            self.parts.append(self.get_starttag_text())
            if tag not in VOID:
                self.depth += 1
        elif 'vd-content' in dict(attrs).get('class', '').split():
            self.depth = 1
            self.parts = []

    def handle_startendtag(self, tag, attrs):
        if self.depth:
            self.parts.append(self.get_starttag_text())

    def handle_endtag(self, tag):
        if not self.depth:
            return
        self.depth -= 1
        if self.depth == 0:
            self.blocks.append(''.join(self.parts).strip())
        else:
            self.parts.append('</%s>' % tag)

    def handle_data(self, data):
        if self.depth:
            self.parts.append(data)

    def handle_comment(self, data):
        if self.depth:
            self.parts.append('<!--%s-->' % data)


def main(argv):
    if len(argv) != 2:
        print('theme-axis-check: usage: theme-axis-check.py <mockup.html>',
              file=sys.stderr)
        return 2
    try:
        src = open(argv[1], encoding='utf-8').read()
    except OSError as exc:
        print('theme-axis-check: %s' % exc, file=sys.stderr)
        return 2
    p = Content()
    p.feed(src)
    if not p.blocks:
        print('theme-axis-check: no .vd-content block found', file=sys.stderr)
        return 2
    for i, b in enumerate(p.blocks[1:], 1):
        if b != p.blocks[0]:
            print('vd-content[%d] differs from vd-content[0]' % i)
            return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
