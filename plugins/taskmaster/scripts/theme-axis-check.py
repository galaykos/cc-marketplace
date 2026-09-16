#!/usr/bin/env python3
"""theme-axis-check.py — machine gate for a visual-decisions theme-axis pass.

A theme-axis pass (aesthetic / density / type family) is only honest if the
CONTENT is identical across frames and only the token preset differs. This
extracts each frame's `.vd-content` inner HTML and diffs every frame against
the first. The per-frame preset lives in the shell's `SLOT: custom-css` style
block, OUTSIDE `.vd-content`, so it is stripped by construction.

WHY A FILE AND NOT A HEREDOC. It shipped pasted into
skills/visual-decisions/references/shell-authoring.md, where its 1.5 KB was
counted against the plugin's on-invoke prose corpus (pc_plugin_corpus,
scripts/plugin-corpus-baseline.json) every time an author read the reference —
and a reader had to paste it correctly to run it. Executable code belongs in
scripts/; the reference now cites this path.

Usage:
    python3 theme-axis-check.py taskmaster-docs/mockups/<file>.html

Exit codes:
    0  every frame's .vd-content is byte-identical (honest theme-axis pass)
    1  a frame differs — the pass is varying content as well as tokens
    2  usage error / unreadable file

LIMITATION: proves the CONTENT matched, never that the token preset is a
single axis. "One axis per pass" stays author judgment.
"""
import sys
from html.parser import HTMLParser

VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
        'link', 'meta', 'param', 'source', 'track', 'wbr'}


class Content(HTMLParser):
    # convert_charrefs defaults to True: entities resolve into handle_data,
    # so a frame differing only by &mdash; vs &ndash; still shows up as a diff.
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
