#!/bin/bash
# scaffold.sh — writes, in the case's sandbox cwd, a stdlib-only Python package whose chunk() drops a short last chunk, so two existing
#   tests fail, and commits it so the run's whole diff is `git diff`. Writes only the files below.
set -e
mkdir -p listutil tests
cat > README.md <<'MD'
# listutil

Small list helpers. Tests: `python3 -m unittest`
MD
printf '__pycache__/\n' > .gitignore
: > listutil/__init__.py
cat > listutil/chunks.py <<'PY'
def chunk(items, size):
    """Split items into consecutive lists of at most `size` elements, keeping order."""
    if size < 1:
        raise ValueError("size must be at least 1")
    return [items[i:i + size] for i in range(0, len(items) - size + 1, size)]


def pairwise(items):
    return list(zip(items, items[1:]))
PY
: > tests/__init__.py
cat > tests/test_chunks.py <<'PY'
import unittest

from listutil.chunks import chunk, pairwise


class ChunkTest(unittest.TestCase):
    def test_even_split(self):
        self.assertEqual(chunk([1, 2, 3, 4], 2), [[1, 2], [3, 4]])

    def test_keeps_a_short_last_chunk(self):
        self.assertEqual(chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]])

    def test_size_larger_than_the_list(self):
        self.assertEqual(chunk([1, 2], 5), [[1, 2]])

    def test_rejects_a_zero_size(self):
        with self.assertRaises(ValueError):
            chunk([1], 0)


class PairwiseTest(unittest.TestCase):
    def test_adjacent_pairs(self):
        self.assertEqual(pairwise([1, 2, 3]), [(1, 2), (2, 3)])


if __name__ == "__main__":
    unittest.main()
PY
git init -q
git add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm 'list helpers'
