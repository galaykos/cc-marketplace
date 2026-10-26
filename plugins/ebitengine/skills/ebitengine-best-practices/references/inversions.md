# Ebitengine: the advice that inverted

> Last verified: 2026-10-26 — https://ebitengine.org/en/documents/install.html

This file carries only facts where an answer given from the v2.5–v2.8-era corpus is now
wrong, plus footguns of headless and store builds. It is not an API tour. Read the engine
version from `go.mod` (and any `go.work`/`replace`) first: each item names the version it
starts at, and below that version the old advice may still be right.

Sources re-read on 2026-10-26: the v2.10 install page, the Go 1.24 release notes,
pkg.go.dev for `ebiten/v2@v2.10.5` (`ebiten`, `audio`, `audio/wav`, `vector`, `text/v2`), the
Ebitengine Steam and mobile pages, and the go-steamworks README. Anything not re-read is
labelled **unverified**.

## Builds

### Desktop is pure Go from v2.10

"As of Ebitengine v2.10, desktop builds (Windows, macOS, Linux, and FreeBSD) use pure Go" —
no C compiler, no development headers, no `pkg-config`. The Linux recipe still recited from
memory (`libc6-dev libgl1-mesa-dev libxcursor-dev libxi-dev libxinerama-dev libxrandr-dev
libxxf86vm-dev libasound2-dev pkg-config`, plus a C toolchain) is unnecessary on v2.10.

- One Linux runner can build every desktop target and the browser with `CGO_ENABLED=0`
  (recipe below).
- Linux still needs RUNTIME libraries to launch: X11 and OpenGL client libraries, a running X
  server or XWayland, a working graphics driver, and ALSA or PulseAudio for sound.
- Mobile builds still require cgo.
- v2.10 requires Go 1.25 or later.
- Below v2.10, read that release's install page; the cgo-free statement is v2.10's.

### `wasm_exec.js` moved in Go 1.24

Go 1.24 moved the WebAssembly support files from `misc/wasm` to `lib/wasm`. The copy step
everyone remembers fails with "no such file" on Go 1.24+:

```sh
GOOS=js GOARCH=wasm go build -trimpath -o dist/game.wasm .
cp "$(go env GOROOT)/lib/wasm/wasm_exec.js" dist/   # Go 1.24+; misc/wasm before
```

Take the file from the same Go toolchain that built the `.wasm`; a mismatched pair fails at
load in the browser.

## API calls a v2.8-era answer gets wrong

Each row is the `Deprecated:` line on pkg.go.dev for v2.10.5. The old calls still compile.

| Old call | Deprecated as of | Use instead |
|---|---|---|
| `vector.DrawFilledRect` | v2.9 | `vector.FillRect(dst, x, y, width, height float32, clr, antialias bool)` |
| `vector.DrawFilledCircle` | v2.9 | `vector.FillCircle(dst, cx, cy, r float32, clr, antialias bool)` |
| `Path.AppendVerticesAndIndicesForFilling` | v2.9 | `vector.FillPath(dst, &path, *FillOptions, *DrawPathOptions)` |
| `Path.AppendVerticesAndIndicesForStroke` | v2.9 | `vector.StrokePath(dst, &path, *StrokeOptions, *DrawPathOptions)` or `Path.AddStroke` |
| `audio.Resample` / `audio.ResampleF32` | v2.9 | `audio.ResampleReader` / `audio.ResampleReaderF32` |
| `text.GoTextFace.Script` | v2.9 | `Language` |
| `text.Advance` | v2.10 | `text.AdvanceAt(text string, indexInBytes int, face Face) float64` — first line only |
| `(*audio.Player).Close` | v2.10 | `PauseAndStopReading()` — semantics below |
| `ebiten.SetFPSMode`, `FPSMode*` | v2.5 | `ebiten.SetVsyncEnabled` — the v2.2-era advice ran the other way |
| `ebiten.SetScreenFilterEnabled` | v2.5 | implement `FinalScreenDrawer` |

`vector.StrokeRect` and `vector.StrokeLine` are NOT deprecated; do not "fix" them.

`PauseAndStopReading` pauses and stops reading the source. After it returns the source can
be closed safely; `Play`, `SetPosition` or `Rewind` resume reading, and buffered data is kept
so `Play` resumes without a gap. It does not destroy the player.

`(*ebiten.Image).DrawTriangles32` takes `[]uint32` indices. `DrawTriangles` takes `[]uint16`,
which caps one call at 65,536 addressable vertices; reach for the 32-bit form before
splitting a mesh by hand.

## Audio: the decoder and the player must agree

| Decoder | Output | Resamples? | Player |
|---|---|---|---|
| `wav.DecodeF32(r)` | 32-bit float stereo | **no**, the stream stays at the file's rate | `ctx.NewPlayerF32`, `NewPlayerF32FromBytes`, `audio.NewInfiniteLoopF32` |
| `wav.DecodeWithSampleRate(rate, r)` | signed 16-bit stereo | yes, to `rate` | `ctx.NewPlayer`, `NewPlayerFromBytes`, `audio.NewInfiniteLoop` |

- A 44.1 kHz file through `DecodeF32` into a 48 kHz context plays about 9% fast and sharp. At
  load, compare the stream's `SampleRate()` with `ctx.SampleRate()` and fail loudly, or convert
  the asset, or decode with `DecodeWithSampleRate`.
- A 16-bit stream handed to `NewPlayerF32` (or the reverse) is misread sample by sample and
  plays as noise.
- `audio.NewContext` panics when a context already exists: one per process, created at start.
- Verified on the `wav` package; `mp3` and `vorbis` expose the same pair and are assumed to
  behave the same — **unverified**.

## Windows Steam builds

- Go programs have frozen inside the Windows Steam environment (ebiten#3181, golang/go#71242).
  The Ebitengine Steam page's workaround is
  `-ldflags="-X=runtime.godebugDefault=asyncpreemptoff=1"`. It disables asynchronous
  preemption, so add it to the Windows Steam build only and recheck it on each Go upgrade.
- The Steamworks DLL is not bundled: download it from the SDK and ship it. With
  `go-steamworks`, `steam_api64.dll` (from the SDK's `redistribution_bin\win64`) goes in the
  working directory; 32-bit OSes are not supported.
- The go-steamworks README's sample calls `RestartAppIfNecessary` (then `os.Exit(1)`) and
  `Init` (panicking on failure) from `init()`. A binary that compiles that file cannot start
  outside Steam, so compile that file only under a build tag (a `steam` tag, say) and give
  other targets a no-op implementation.

## Mobile

- A mobile package registers the game with `mobile.SetGame(game)`. Never call `RunGame` there.
- gomobile does not compile a package with no exported function. Export one, even an empty
  `func Dummy() {}`.
- Bind with `ebitenmobile bind -target android -javapkg your.package -o game.aar ./mobile` or
  `ebitenmobile bind -target ios -o Game.xcframework ./mobile`. Install `ebitenmobile` at the
  engine version in `go.mod`, not `@latest`.
- The host must forward lifecycle calls: on Android, `suspendGame()` from `onPause` and
  `resumeGame()` from `onResume`; on iOS, the same pair from `applicationWillResignActive` /
  `applicationDidBecomeActive`.
- `ebiten.CursorPosition` always returns (0, 0) in mobile native apps, and on desktop and
  browsers before the main loop starts. Read touches (`AppendTouchIDs`, `TouchPosition`) on
  mobile.

## Headless tests and screenshots

### CI recipe

```sh
# ubuntu-24.04 runtime: xvfb libgl1 libglx-mesa0 libgl1-mesa-dri libasound2t64 (no -dev packages)
printf 'pcm.!default { type null }\n' > "$RUNNER_TEMP/alsa-null.conf"
export ALSA_CONFIG_PATH="$RUNNER_TEMP/alsa-null.conf"
xvfb-run -a go test ./...
go build -o smoke . && timeout 60 xvfb-run -a -s "-screen 0 1280x720x24" ./smoke -shot shot.png -shot-tick 240
test -s shot.png
for t in windows/amd64 darwin/amd64 darwin/arm64 linux/amd64 js/wasm; do
  CGO_ENABLED=0 GOOS=${t%/*} GOARCH=${t#*/} go build -o /dev/null .
done
```

- The null ALSA device stands in for a sound card. A game that creates an audio context on a
  runner without one fails audio initialization. Upstream reports the error coming back from
  `RunGame`; the exact text is **unverified**.
- Xvfb is a display, not a renderer. Mesa or the host GPU still draws, so pixels can differ
  across images and drivers. Pin the runner image when a stored reference frame must match.
- The package list in the first comment is upstream's for ubuntu-24.04 and was not re-run
  here; `libasound2t64` replaces `libasound2` on Ubuntu 24.04+ and Debian 13.
- Cross-compiling proves the build links. It does not prove the binary launches, takes input
  or plays sound on that platform.

### Deterministic capture harness

`SetTPS(ebiten.SyncWithFPS)` makes "TPS uncapped and the game updated per frame", so tick N is
the same frame on every run. `SetWindowVisible(false)` before `RunGame` runs desktop builds
without showing the window. Returning `ebiten.Termination` from `Update` ends `RunGame` with no
error.

```go
// main(), before RunGame, only when -shot is set:
ebiten.SetTPS(ebiten.SyncWithFPS) // one Update per Draw
ebiten.SetVsyncEnabled(false)
ebiten.SetWindowVisible(false)
ebiten.SetRunnableOnUnfocused(true)

func (g *Game) Update() error {
	if g.shotDone {
		if g.shotErr != nil {
			return g.shotErr
		}
		return ebiten.Termination
	}
	g.tick++
	return g.scene.Update(g)
}

func (g *Game) Draw(screen *ebiten.Image) {
	g.scene.Draw(screen)
	if g.shotPath != "" && !g.shotDone && g.tick >= g.shotTick {
		img := image.NewRGBA(screen.Bounds())
		screen.ReadPixels(img.Pix) // premultiplied; equals straight RGBA on an opaque screen
		g.shotErr = writePNG(g.shotPath, img)
		g.shotDone = true
	}
}
```

- Capture mode runs uncapped. It checks rules and rendered states; it does not measure frame
  pacing, audio sync or anything driven by the wall clock.
- `ReadPixels` cannot run before `RunGame` starts. The checker reports the `ReadPixels` in this
  `Draw` as a review item; it is intentional here.
- Drive the scripted run through the game's action layer, not raw keys, so the same harness
  replays a known input sequence.

### Opt-in VM guest (v2.10, experimental)

A game built with the `ebitenginevmguest` build tag and given `EBITENGINE_VM_ENDPOINT` (a
`unix://` socket path or a `tcp://` address with host and port) runs as a guest of a virtualization host instead of
opening a window. The same setting exists as `RunGameOptions.VMGuestEndpoint`. It is desktop
only and serves one guest session; the host side lives in the experimental `exp/vmhost`
package. Read that package's docs at the project's engine version before relying on it. Its
API was not re-read here.
