---
name: seeded-generation
description: Use when game content comes from a seed — procedural levels or worlds, a daily challenge, shareable or leaderboard seeds, saves that store only the seed, deterministic replays — or when a seed stopped reproducing after an engine, runtime or library update, or when Perlin noise sampled at tile coordinates comes out flat — keeps seeded output identical across versions and runs.
---

> Last verified: 2026-10-26 — https://docs.python.org/3/library/random.html

## Read the runtime first

Read the runtime and engine that generate content (`project.godot`,
`ProjectSettings/ProjectVersion.txt`, the `TargetFramework` in the `.csproj`,
`.python-version` or `pyproject.toml`). A library RNG repeats a seed's sequence only on
the runtime that produced it; an upgrade is where shared seeds break.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| A seed that must outlive an update runs through a PRNG the project owns, its first outputs pinned in a test | **gate** in the project once that test exists (it fails when the sequence moves); **recorded** here |
| Never make a seeded pick from a hash-ordered collection | **agent-graded** |
| Never sample gradient noise at integer coordinates | **agent-graded** |

## Library RNGs do not promise cross-version sequences

- **Python** guarantees only that `random()` repeats across versions with a compatible
  seeder. `randint`, `randrange`, `choice`, `shuffle` and `sample` may change.
- **.NET** documents that the same `System.Random` seed "may produce different sequences"
  on different versions of .NET.
- **Godot** `RandomNumberGenerator` "currently uses PCG32"; the docs call the algorithm
  "an implementation detail" that "should not be depended upon". Its `state` may only be
  restored from a value that `state` itself produced.
- **Noise libraries** likewise: switching library, or upgrading one, changes the field
  for the same seed.

When a seed must survive an update (shared world seeds, daily challenges, leaderboard
seeds, seed-only saves, deterministic replays), do one of two things:

1. **Own the generator.** A small PRNG in project code (SplitMix64, PCG32, xorshift),
   with bounded integers, choices and shuffles derived by your own code rather than the
   library's helpers, and its first outputs for a fixed seed pinned in a unit test.
2. **Save the result, not the seed.**

A seed that only has to repeat within one build, such as a debug repro, can use the
library RNG.

## Example: SplitMix64 with a pinned test

```python
MASK = (1 << 64) - 1


class SplitMix64:
    def __init__(self, seed: int) -> None:
        self.state = seed & MASK

    def next_u64(self) -> int:
        self.state = (self.state + 0x9E3779B97F4A7C15) & MASK
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        return z ^ (z >> 31)

    def below(self, n: int) -> int:  # unbiased 0..n-1: reject the uneven tail
        limit = (MASK + 1) - ((MASK + 1) % n)
        while (x := self.next_u64()) >= limit:
            pass
        return x % n


def test_sequence_is_pinned() -> None:
    rng = SplitMix64(1234567)
    assert [rng.next_u64() for _ in range(3)] == [
        6457827717110365317, 3203168211198807973, 9817491932198370423]
```

Check a port to C#, GDScript or Rust against the same three numbers: 64-bit wrap-around
multiplication and unsigned right shifts are where ports go wrong. `x % n` on raw output
is biased; `below` rejects the uneven tail instead.

## Iteration order leaks into the seed

- Python randomises `str` hashing per process (`PYTHONHASHSEED`), so a `set` of strings
  iterates in a different order on each run, and `rng.choice(list(names))` picks
  differently under the same seed. Sort first: `rng.choice(sorted(names))`.
- .NET leaves the enumeration order of `Dictionary<TKey,TValue>` and `HashSet<T>`
  unspecified; sort, or keep an ordered list, before any seeded pick.
- Wall-clock time, frame timing and thread completion order break a seed the same way.

## Gradient noise is zero on the lattice

Perlin-type gradient noise is 0 at every integer lattice point, so sampling it at whole
tile coordinates returns one constant: Unity's `Mathf.PerlinNoise(x, y)` gives the same
value for every integer tile. Scale coordinates by a non-integer frequency before
sampling (`x * 0.07`, or `x / width * f`). Libraries with a frequency setting, such as
FastNoiseLite, apply one for you.

## Anti-patterns

- **Library-helper seeds** — shareable seeds drawn through `random.randint`,
  `System.Random.Next` or `RandomNumberGenerator.randi_range`.
- **Unpinned generator** — an owned PRNG with no test on its outputs; a refactor moves
  the sequence as silently as an upgrade does.
- **Set-order picks** — a seeded choice over a set or hash map.
- **Lattice sampling** — gradient noise read at integer coordinates.
