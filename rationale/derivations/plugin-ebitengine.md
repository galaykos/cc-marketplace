# ebitengine: the comment text moved out of the code (2026-10-26)

The text below was moved verbatim on 2026-10-26 from the upstream docstring of the file named in the `##` heading (gamedev-skills/awesome-gamedev-agent-skills@184b72b, Apache-2.0); the three lines the file kept are not repeated here. A pointer by name was left in the file, `# Why, limits, history: rationale/derivations/plugin-ebitengine.md § <heading>`. Standing: `recorded` — no gate reads this file.

## plugins/ebitengine/scripts/check_ebitengine.py

### Upstream docstring: scope and limits

```text
Scan an Ebitengine (v2) Go project for deprecated APIs and common game-loop mistakes.

This is a heuristic source scan, not a Go type checker or a quality verdict.
It recognises named/aliased imports, but not dot imports or variable shadowing;
it scans every selected file regardless of build constraints. Review warnings.
Reads Go sources and go.mod only and never modifies them. All heuristic findings
are warnings: deprecated does not mean broken. Use go build/vet for errors.
The deprecation table matches
Ebitengine v2.10; on an older pinned version some replacements may not exist yet
(each finding names the version that deprecated the API).

Exit status: 0 = no errors, 1 = errors found (or warnings with --strict),
2 = bad arguments, unreadable target, or no Ebitengine v2 project signal.

Examples:
  python3 check_ebitengine.py .
  python3 check_ebitengine.py ./cmd/mygame --strict
```

### What changed on import

- The exit-status line above says `1 = errors found`; the scanner never emits an error
  (`error_count` is always 0), so `--help` now says 1 means warnings with `--strict`.
- `.At(` in an Update/Draw body now needs two arguments (`ebiten.Image.At(x, y)`), so
  one-argument `At` calls on lists and custom types stop matching.
- `.Close()` in a file importing the audio package is skipped when its receiver was
  assigned from `Open`/`OpenFile`/`Create`/`CreateTemp` in the same file (a file, not a
  player). Any other `Close()` there is still reported as a possible `audio.Player`.
- The Update/Draw-body rules had no positive test upstream; three cases now cover them,
  and each fails when its rule is removed (checked by mutation on 2026-10-26).
