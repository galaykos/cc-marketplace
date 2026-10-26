# Changelog — ebitengine

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-26

- New plugin. `ebitengine-best-practices` skill: read the engine version from `go.mod`/`go.work`/`replace` first, a rules table naming each rule's standing, and `references/inversions.md` with the v2.9/v2.10 renames, v2.10's pure-Go desktop builds, Go 1.24's `wasm_exec.js` move, the audio decoder/player pairing, Windows Steam and mobile footguns, and a headless CI and capture recipe.
- `scripts/check_ebitengine.py`: advisory scan for calls deprecated as of v2.10 and for loop misuse inside `Update`/`Draw` methods (`--json`, `--strict`). Adapted from upstream with fewer false positives on `.Close()` and `.At(`, and with tests for the `Update`/`Draw` rules.
