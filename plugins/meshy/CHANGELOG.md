# Changelog — meshy

Consumer-facing changes only. Newest first.

## 0.3.0 — 2026-11-09

- **`inspect_glb.py` sizes KTX2 and WebP textures.** It reads the KTX2 header
  (`KHR_texture_basisu`) and the WebP `VP8 `, `VP8L` and `VP8X` chunks (`EXT_texture_webp`), so
  these images now count toward `--max-texture` instead of failing as unmeasured. Checked on real
  files: Khronos sample KTX2 textures, and WebP files written by libwebp and Pillow. Standing: gate
  for what it checks.
- **A pointer to Khronos glTF-Validator** for the schema check `inspect_glb.py` does not do: the
  2.0.0-dev.3.10 release binaries, `gltf_validator -o model.glb`, or the web page. Read on
  2026-11-09. Standing: recorded.
- **`meshy-generation` names its near misses.** Hand modelling and rigging go to `blender`, 2D art
  to `gamedev:game-assets` or `pixel-art`. Standing: recorded.

## 0.2.1 — 2026-11-02

- **Control-arm eval.** `evals/no-resubmit-unknown-create` covers a client timeout on create
  followed by a resubmit. On 2026-11-02 it scored 5/5 with the plugin and 5/5 without, so it is a
  regression guard. Spend was $1.06. Results are in `rationale/gamedev-evals-2026-11-02.md`.
- **Review fix.** The hook's PreToolUse now tests the command text before doing any git or jq work.
  A non-matching Bash call took about 7 ms instead of about 15 ms, over 20 runs (relayed from the
  fix run).

## 0.2.0 — 2026-11-02

- **Models are measured when they land.** A new hook, `hooks/glb-check.sh`, runs `inspect_glb.py`
  at 15,000 triangles and 2,048 px on these:
  - a `.glb`/`.gltf` a Write names;
  - one that lands during a Bash call naming glb, gltf or meshy;
  - one that lands during a Meshy MCP download.

  PreToolUse marks the call and PostToolUse finds model files whose ctime moved during it, so
  `curl -o` and the MCP's `meshy_output/` are seen. It adds any broken budget, required extension,
  missing file or unreadable download once per context, and never blocks. Off: `CC_GLB_CHECK=off`,
  or `/config`.
- **Measured.** The cheap exit took 15 ms median and 16 ms max over 20 runs. A bracketed scan of a
  1,360-file repository took 23 ms median.
- **Standing.** Running the checker on a landed model moves from agent-graded to **gate** where the
  hook fires (`scripts/smoke/game-checker-hooks-tests.sh`, in CI). Another budget, or a model landed by a command naming none, is still
  agent-graded.

## 0.1.0 — 2026-10-30

- New plugin. `meshy-generation` skill: the API's paid-task rules (reconcile an unknown create, never resubmit; a running task cannot be cancelled; the two kinds of `429`), the 3-day file and signed-URL expiry, Smart Topology and remesh polycount ranges, rigging and animation limits, the plan-tier licence from Meshy's Terms of Use, and the meshy-cli 0.7 exit codes — each re-checked against docs.meshy.ai on 2026-10-30.
- `scripts/inspect_glb.py`: stdlib Python 3 check of `.glb`/`.gltf` files — drawn triangles, PNG/JPEG image sizes, required extensions, world extents in metres — exiting 1 on `--max-tris`, `--max-texture`, a required extension not passed to `--allow-ext`, or a missing external file, and 2 on a file that is not readable glTF 2.0.
