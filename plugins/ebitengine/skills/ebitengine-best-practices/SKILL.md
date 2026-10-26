---
name: ebitengine-best-practices
description: Use when writing, reviewing or building a Go game on Ebitengine — a go.mod requiring github.com/hajimehoshi/ebiten/v2, code importing its vector, text/v2, audio or inpututil packages, an ebitenmobile bind, copying wasm_exec.js, a Windows Steam build, or a headless xvfb CI run — and the v2.9/v2.10 renames such as vector.DrawFilledRect, text.Advance and audio Player.Close.
---

> Last verified: 2026-10-26 — https://pkg.go.dev/github.com/hajimehoshi/ebiten/v2@v2.10.5
<!-- version-tail-ok: Go module with no npm/composer/pypi package; the stamp points at the v2.10.5 API reference on pkg.go.dev -->

## Read the engine version first

- Take it from `go.mod` (`require github.com/hajimehoshi/ebiten/v2 vX.Y.Z`), then let `go.work` and any
  `replace` of that module override it: a replace to a fork or a local checkout is what actually builds.
- Advise for that version. Keep the project's engine version and `go` directive unless asked to upgrade;
  v2.10 needs Go 1.25 or later.
- Never mix snippets across v1 (`github.com/hajimehoshi/ebiten`) and v2, or across the old `text`
  package and `text/v2`.
- v2 keeps deprecated APIs compiling. A deprecated call is a review item, not a broken build; rewriting
  it is a change the user asks for.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| Replace calls deprecated in the project's engine version | **gate** only where the project's CI runs `staticcheck` (SA1019 reads each API's own `Deprecated:` line, so it is version-correct); otherwise the checker's `deprecated-api` warnings, from a table fixed at v2.10 |
| In a `Draw` method: no `ebiten.NewImage*`, `text.NewGoTextFaceSource`, `inpututil.*`, `audio.NewContext`, `.Play()` | checker `loop-review` warning (`--strict` exits 1); code reached through helpers is not scanned, so beyond that it is agent-graded |
| No `time.Now`/`time.Since` as simulation time and no repeated GPU readback in `Update`/`Draw` | checker warning; agent-graded for intent (profiling and screenshot capture are legitimate) |
| One `audio.Context` per process | recorded here; the engine panics on a second `audio.NewContext`, and the checker warns when a project has more than one call site |
| A `DecodeF32` stream must already be at the context's rate; a 16-bit stream goes only to `NewPlayer` | recorded — nothing static sees a file's sample rate; compare `SampleRate()` at load |
| No `-dev` packages or cgo for a v2.10 desktop build; `wasm_exec.js` comes from `lib/wasm` on Go 1.24+ | recorded — `references/inversions.md` |

## Run the checker

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_ebitengine.py" . [--strict] [--json] [--include-tests] [--max-issues N]
```

Exit 0 means warnings only, 1 means warnings under `--strict`, 2 means bad arguments or no
`ebiten/v2` in `go.mod` or any import. It masks comments and strings, then pattern-matches; it does
not type-check.

- **Noise it still reports:** a `.Close()` in an audio-importing file whose receiver did not come from
  `Open`/`Create` (reported as a possible `audio.Player`); `.At(x, y)` on any type inside
  `Update`/`Draw`; `Draw` methods of types that are not Ebitengine games.
- **What it misses:** dot imports, shadowed names, calls reached through helpers; it scans every file
  regardless of build tags.
- **Deprecations:** run `staticcheck ./...` first when it is available. It knows the version in
  `go.mod`; the checker's suggested replacement may not exist on an older one.

## What a from-memory answer gets wrong

`references/inversions.md` carries only facts that changed between the v2.5-era corpus and v2.10,
plus headless footguns. Read its section before acting on:

- a Linux or CI build setup, or a cross-compile — desktop is pure Go from v2.10;
- a WebAssembly build — Go 1.24 moved `wasm_exec.js`;
- a `vector`, `text/v2` or audio-player call — the v2.9/v2.10 renames;
- decoding audio — the decoder and player must agree on format and rate;
- a Windows Steam build — the freeze workaround and the DLL;
- a mobile binding — `mobile.SetGame`, the exported-function rule, lifecycle calls;
- headless tests or a screenshot run — xvfb, a null ALSA device, the deterministic capture harness.

## Anti-patterns

- **cgo recipe on v2.10** — installing `libgl1-mesa-dev … pkg-config` or forcing `CGO_ENABLED=1` for a desktop build.
- **`misc/wasm` path** — `cp "$(go env GOROOT)/misc/wasm/wasm_exec.js"` on Go 1.24+: the file is no longer there.
- **State in Draw** — advancing simulation, reading `inpututil` edges or starting sounds in `Draw`, which can run zero or several times per tick.
- **Rate mismatch** — a 44.1 kHz file through `DecodeF32` into a 48 kHz context plays fast and sharp.
- **Blanket preemption flag** — `asyncpreemptoff=1` on every build instead of only the Windows Steam one.
- **Blind replacement** — applying a suggested API on an engine version older than the one that added it.
