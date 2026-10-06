# Compressed glTF — decoders, where they load from, and the encode step

> Last verified: 2026-10-06 — https://threejs.org/docs/pages/GLTFLoader.html — npm:three@0.186

Read on demand from the threejs-best-practices SKILL when a model is Draco-, Meshopt- or
KTX2-compressed. Versions read that day: three 0.186.1, @react-three/drei 10.7.9 (on
three-stdlib 2.36.1), @gltf-transform/cli 4.5.1 — each fact below was read from those
packages' source, not from a render.

## The decoder must match the file

Compression is a property of the file; the loader decodes only what it was given a
decoder for. GLTFLoader throws on the mismatch:

| The file uses | Wire before loading | Without it, GLTFLoader throws |
| --- | --- | --- |
| Meshopt (`EXT_meshopt_compression`) | `loader.setMeshoptDecoder(MeshoptDecoder)` | `setMeshoptDecoder must be called before loading compressed files` |
| Draco (`KHR_draco_mesh_compression`) | `loader.setDRACOLoader(dracoLoader)` | `No DRACOLoader instance provided.` |
| KTX2 textures (`KHR_texture_basisu`) | `loader.setKTX2Loader(ktx2Loader)` after `detectSupport(renderer)` | `setKTX2Loader must be called before loading KTX2 textures` |

- Read which extensions the file requires (`gltf-transform inspect model.glb`) before
  wiring; do not infer it from the pipeline someone remembers running.
- `gltf-transform optimize` compresses geometry with **Meshopt** unless told otherwise
  (`--compress` defaults to `meshopt`; `draco`, `quantize` and `false` are the others). A
  loader wired for Draco alone throws on its output.

## Where the decoder files come from

- **three r185+:** `DRACOLoader` and `KTX2Loader` resolve their decoder and transcoder
  files from three's own `examples/jsm/libs/` through `import.meta.url`, so
  `setDecoderPath` / `setTranscoderPath` are only overrides. Below r185 both paths default
  to empty and must be set. Either way, confirm the built output serves the `.wasm` — that
  depends on the bundler, not on three.
- **drei `useGLTF`** builds three-stdlib's loaders, not three's, so the r185 resolution does
  not reach it. It wires Draco and Meshopt for you and, by default, fetches the Draco
  decoder from `https://www.gstatic.com/draco/versioned/decoders/1.5.5/` — a third-party
  host: a CSP `connect-src` entry, a runtime dependency on Google's availability, and a
  request from every visitor. Self-host the decoder files and pass the path:
  `useGLTF(url, '/draco/')`, or once for the app with `useGLTF.setDecoderPath('/draco/')`.
- `useGLTF` does **not** wire KTX2. Its fourth argument, `extendLoader`, receives the loader:
  call `loader.setKTX2Loader(ktx2Loader)` there, with a KTX2Loader that has already run
  `detectSupport(gl)`.

## KTX2 under WebGPURenderer

`detectSupport(renderer)` reads the renderer's compressed-texture features, which exist only
once the backend has initialised: `await renderer.init()` first, then
`ktx2Loader.detectSupport(renderer)`. Called earlier it throws (`.hasFeature() called before
the backend is initialized`). `detectSupportAsync()` is deprecated since r181 — it warns,
then does exactly those two steps.

## Encoding KTX2 with gltf-transform

- `--texture-compress` defaults to `auto`, which re-encodes each texture in its original
  format. KTX2 happens only when asked: `--texture-compress ktx2`.
- With `ktx2`, normal, occlusion and metallic-roughness maps are encoded as UASTC (the
  higher-quality mode, for data maps); every other texture as ETC1S (smaller).
- Encoding shells out to KTX-Software's `ktx` command, version 4.4.0 or newer; a machine
  with only the older `toktx` binary fails the run. Install it wherever `optimize` runs,
  CI included. `sharp` comes with the CLI as a dependency and does the resizing.
- `--texture-size` defaults to 2048: anything larger is downscaled to fit. Pass the size on
  purpose for a hero texture that needs more, or a mobile build that needs less.

Standing: recorded — no gate reads this file. GLTFLoader's thrown errors catch a missing
decoder at runtime; nothing catches a gstatic fetch, a missing `.wasm` in the build, or an
oversized texture.
