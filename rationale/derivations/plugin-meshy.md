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
