# ebitengine

Advice for Go games on [Ebitengine](https://ebitengine.org), covering only what changed under
the model's training data: the v2.9/v2.10 API renames, pure-Go desktop builds from v2.10, Go
1.24's `wasm_exec.js` move, the audio decoder/player pairing, the Windows Steam freeze
workaround, mobile binding rules, and a headless CI and screenshot recipe. Plus an advisory
checker for deprecated calls and for misuse inside `Update`/`Draw`.

## Install

```bash
claude plugin install ebitengine@cc-plugins-marketplace
```

Companion: install **gamedev** alongside it for engine-agnostic game design, feel and shipping
material. This plugin carries only Ebitengine/Go specifics. Nothing installs the pair for you:
no plugin here may declare `dependencies`.

## What ships

| Artifact | Reach for it when |
|---|---|
| `ebitengine-best-practices` skill | `go.mod` requires `github.com/hajimehoshi/ebiten/v2` or a file imports it — read the engine version first, then the rules table and `references/inversions.md` |
| `scripts/check_ebitengine.py` | After changing loop, input or audio code, or before upgrading the engine: `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_ebitengine.py" .` (`--json`, `--strict`, `--include-tests`) |

The checker is stdlib-only Python 3 and never writes to the project.

## What has teeth

| Rule | Standing |
|---|---|
| Deprecated v2 calls | **gate** only where the project's CI runs `staticcheck` (SA1019); otherwise the checker's warnings, which fail only under `--strict` |
| No image creation, font parsing, `inpututil`, audio context or `.Play()` inside a `Draw` method | checker warning (`--strict` exits 1); calls reached through helpers are agent-graded |
| Wall clock and GPU readback inside `Update`/`Draw` | checker warning; intent is agent-graded |
| Decoder/player format and sample-rate pairing; no cgo recipe on v2.10; `lib/wasm` on Go 1.24+; Steam and mobile rules | recorded — written in the skill, nothing reads it back |
| The checker's own contract (exit codes, masking, the `Update`/`Draw` rules) | **gate** — `scripts/__tests__/check_ebitengine.test.sh`, run by CI's plugin-harness step |

The checker is a regex scan, not a type checker. It still reports some `.Close()` calls that are
not audio players, `.At(x, y)` on any type, and `Draw` methods of non-game types, and it scans
files regardless of build tags. The skill lists the noise.

Measured: nothing — no control-arm eval.

Credit: Adapted from [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @184b72b (Apache-2.0, © 2026 Abhishek Barali and contributors); prose distilled and rewritten here, scripts copied and modified (see NOTICE).
