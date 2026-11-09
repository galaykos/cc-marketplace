# meshy: derivations (2026-11-02)

Standing: `recorded`. No gate reads this file.

## plugins/meshy/hooks/glb-check.sh

Added 2026-11-02 (meshy 0.2.0). Until then `inspect_glb.py` was a **gate** only for whoever ran it.
The README said no hook ran it, so whether a 300k-triangle model reached the engine depended on
the agent remembering to measure it. The user asked for it to run when a `.glb`/`.gltf` lands,
with default budgets. The script has no defaults, so on 2026-11-02 the user picked the figures the
README and skill already use as their example: 15,000 triangles and 2,048 px.

**The bracket.** A model lands three ways:

- a Write of a `.gltf`, whose path the payload names;
- a Bash command (`curl -o`, `wget`, a download script, `unzip`);
- Meshy's MCP `meshy_download_model`, which saves under `meshy_output/` or `save_to` and names no
  path in its input.

`cc_bash_write_targets` sees none of the last two, and `cc_bash_write_effects` sees neither curl
nor an MCP tool, and nothing gitignored. So the hook reads the effect of this one call:

- PreToolUse writes a marker named for the call's `tool_use_id`. The host sends the same id to
  PreToolUse and PostToolUse (hooks doc, "PreToolUse input", read 2026-11-02).
- PostToolUse lists the model files under the project root whose **ctime** is newer than the
  marker, then deletes the marker.
- ctime, not mtime: `mv` and `cp -p` keep the source mtime, but a rename or a copy moves the ctime.
- A per-call marker, not a per-session one. It cannot read an earlier call's writes, it has no
  first-call blind spot, and two parallel calls do not share one window. They can still see each
  other's files, which the once-per-context rule absorbs.
- The marker is written only when the command names `glb`, `gltf` or `meshy`, or the tool is a
  Meshy MCP download. Every other Bash call costs a cheap exit: 15 ms median, 16 ms max, over 20
  runs, PreToolUse and PostToolUse alike.
- A bracketed scan of this repository (1,360 tracked files) took 23 ms median and 34 ms max over
  10 runs.

**What is said.** A broken budget, a required extension, a missing external file, or a file that
is not readable glTF 2.0, which is usually a truncated download. Each is said once per context,
keyed on the report line and the file size, so a re-download that still fails is said again.

**Limits** (also in the header):

- a command that lands a model without naming one, such as `unzip` or a script;
- files outside the project root, unless the MCP `save_to` names them;
- more than `MAX_FILES` files;
- a call whose PreToolUse did not run, such as a permission denial (its marker is swept after 2 h).

Standing: firing and silence are a **gate** in `scripts/smoke/game-checker-hooks-tests.sh`, which
CI runs.

**Live host check, 2026-11-02.** One headless `claude -p` session (CLI 2.1.316, haiku), with unity-traps and meshy loaded by `--plugin-dir`, ran `mv` of an `Assets/` script without its `.meta`, then `cp` of a 60,000-triangle `.glb`. Its final reply named both findings: the `.meta` left behind, and "60,000 triangles, over the 15,000 budget". So the host delivered both hooks' context, and the PreToolUse/PostToolUse `tool_use_id` bracket held. blender and pixel-art were driven only through the harness. Acting on a finding is **agent-graded**.

## plugins/meshy/scripts/inspect_glb.py

KTX2 and WebP sizing added 2026-11-09 (meshy 0.3.0, roadmap row GD9). Until then only PNG and JPEG
headers were read, so a `KHR_texture_basisu` or `EXT_texture_webp` texture failed `--max-texture`
as "size unknown". That forced either no texture budget or a false failure on every compressed
asset.

Header layouts, all verified on 2026-11-09:

- **KTX2.** A 12-byte identifier `«KTX 20»\r\n\x1A\n`, then little-endian `vkFormat`, `typeSize`,
  `pixelWidth` and `pixelHeight`, so width sits at byte 20 and height at byte 24. `pixelWidth` must
  not be 0. Source: KTX File Format Specification 2.0, Revision 4,
  https://registry.khronos.org/KTX/specs/2.0/ktxspec.v2.html, §2 and §3.4. A height of 0 (a 1D
  texture) is reported as 1.
- **WebP.** RFC 9649, https://www.rfc-editor.org/rfc/rfc9649.txt:
  - `VP8X` holds a 24-bit canvas width − 1 and height − 1 after its flag and reserved bytes;
  - `VP8L` holds the signature 0x2F, then 14-bit width − 1 and height − 1, read LSB first.
- **`VP8 `.** RFC 6386 §9.1 and §19.1, https://www.rfc-editor.org/rfc/rfc6386.txt: a 3-byte frame
  tag, the start code `9d 01 2a`, then 16-bit little-endian sizes whose top 2 bits are the scale,
  so the size is masked with 0x3FFF.

**Checked on real files, not only the harness's hand-packed headers.**

- WebP files written by libwebp (through ffmpeg 8.0.1) and by Pillow 12.1.1:
  - lossy 3000x2000, as `VP8 `;
  - lossless 640x480 and 17x5, as `VP8L`;
  - RGBA 4096x16, as `VP8X`;
  - 16383x3, as `VP8 `.

  Each read back at its encoded size.
- KTX2 files read back at their header sizes:
  - Khronos glTF-Sample-Assets `FlightHelmet_Materials_LensesMat_Normal.ktx2`, 1024x1024. Its PNG
    twin is 1024x1024 by Pillow.
  - `CarConcept/Rib_N.ktx2`, 32x32.
  - KTX-Software `tests/resources/ktx2/alpha_simple_blze.ktx2`, 8x8.

**The validator pointer**, verified on 2026-11-09:

- KhronosGroup/glTF-Validator's README gives the CLI as
  `gltf_validator [<options>] <input>`, with `-o` printing the JSON report to stdout and a
  non-zero exit "if at least one error was found".
- The latest release is 2.0.0-dev.3.10 (2024-10-22, a pre-release). It ships
  `gltf_validator-2.0.0-dev.3.10-{linux64,macos64}.tar.xz` and `-win64.zip`.
- The npm package `gltf-validator` 2.0.0-dev.3.10 declares no `bin`, so `npx` gives no CLI.
- The README's list of validated extensions includes `EXT_texture_webp` but not
  `KHR_texture_basisu`.

Standing: recorded. Nothing runs the validator.

Limits: only the image's first 256 KiB is read, as before. An animated WebP reports its canvas. A
KTX2 cube map or array reports its base level's width and height.
