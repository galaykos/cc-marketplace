# blender

Blender Python and asset export, covering only what changed under the model's training data or fails
silently: the 4.x→5.2 Python API removals and renames, the 5.x `.blend` header and its default zstd
compression, the headless exit-code traps, and the FBX/glTF settings that break Unreal, Unity and Godot imports.
Plus two mechanisms with exit codes: a stdlib checker for removed bpy calls, and a mesh QA script run inside Blender.

## Install

```bash
claude plugin install blender@cc-plugins-marketplace
```

Companion: install **gamedev** alongside it for asset licences, AI-generation records and store disclosure
(its `game-assets` skill) and the engine-agnostic shipping material. This plugin carries Blender only. Nothing
installs the pair for you: no plugin here may declare `dependencies`.

```bash
claude plugin install gamedev@cc-plugins-marketplace
```

## What ships

| Artifact | Reach for it when |
|---|---|
| `blender-best-practices` skill | A `.py` imports `bpy`, a task opens or exports a `.blend`, or a command runs `blender -b` — read the version first, then the rules table, `references/api-5x.md` and `references/export.md` |
| `scripts/check_bpy_scripts.py` | Before running or merging Blender Python, or before moving a project to a newer Blender: `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_bpy_scripts.py" . --blender 5.2` (`--json`, `--strict`; `--blend-version FILE` prints the version that saved a file) |
| `scripts/blender_qa.py` | Before calling a generated or edited mesh done: `blender -b f.blend --factory-startup --python-exit-code 2 --python "${CLAUDE_PLUGIN_ROOT}/scripts/blender_qa.py" -- --objects A B` |

The checker is stdlib-only Python 3 (tested on 3.13 and 3.14) and never writes to the project; reading a zstd-compressed `.blend` (the
5.0+ default) needs Python 3.14, and older Pythons say so instead of guessing. The QA script only reads the
scene; it was run on Blender 5.2.3 only.

## What has teeth

| Rule | Standing |
|---|---|
| No bpy call the target version removed or renamed | **gate** for whoever runs `check_bpy_scripts.py` (exit 1); running it is **recorded** — no hook runs it |
| The checker's contract: exit codes, version windows, header decoding, both zstd branches | **gate** — `scripts/__tests__/check_bpy_scripts.test.sh`, run by CI's plugin-harness step |
| Each checker rule is true of a real Blender: the old API gone, the named replacement present | **gate** only where `BLENDER_EXE` names a binary (`test_rules_in_blender.py`); CI has no Blender and skips it. Last run 2026-10-30 on 5.2.3: 29 of 29 |
| A mesh passes QA before it is called done | **gate** when `blender_qa.py` runs (exit 1); whether it runs is **agent-graded** |
| `blender_qa.py`'s own behaviour | CI exercises only its pure parts (argument parsing, island grouping, exit status, refusing to run outside Blender); its geometry checks run only with `BLENDER_EXE` — last run 2026-10-30 on 5.2.3, passing |
| `--python-exit-code` before `--python`; FBX/glTF export settings; Unity and glTF packing; Godot suffixes | **recorded** — written in the skill, nothing reads it back |

Residual limits: the checker judges an attribute by its name and its receiver's spelling, not its type, so a
renamed variable, an aliased import or a `getattr` call hides a break, and a non-Blender object with a matching
attribute is reported (`# bpy-check: ok` silences a line). The QA script cannot judge silhouette, deformation,
shading or material intent. The FBX unit and shape-key facts were measured on exported files; what Unreal does
with them comes from Epic's docs or from an upstream's measurement, and each is labelled in `references/export.md`.

## MCP servers (install lines only; none is bundled)

By default both run Python the model writes inside your Blender session with no sandbox. Save your work first,
and prefer a machine without sensitive data. Both name their server command `blender-mcp`: `uvx blender-mcp` runs the
third-party project below (its old PyPI name), not Blender Lab's.

- **Blender Lab MCP** — the Blender Foundation's own, at <https://projects.blender.org/lab/blender_mcp>. GPL-3.0,
  so this plugin points at it and copies nothing. The add-on needs Blender 5.1 or later: drag the release's
  `mcp-1.0.3.zip` link from <https://www.blender.org/lab/mcp-server/> into Blender (twice: once to add the
  repository, once to install). The server, per the project's Setup wiki:

  ```bash
  git clone https://projects.blender.org/lab/blender_mcp.git "$HOME/blender_mcp"
  claude mcp add blender -- uv --directory "$HOME/blender_mcp/mcp" run blender-mcp
  ```

  The wiki gives the second line as client JSON (`"command": "uv"`, `"args": ["--directory", "…/blender_mcp/mcp",
  "run", "blender-mcp"]`); the `claude mcp add` form is that JSON translated.
- **MCP for Blender** (<https://github.com/ahujasid/mcp-for-blender>, MIT, PyPI `mcp-for-blender`), from its README:

  ```bash
  claude mcp add blender uvx mcp-for-blender
  uvx mcp-for-blender install-addon
  ```

  Then enable **Interface: MCP for Blender** in Blender's add-on preferences. Its `TERMS_AND_CONDITIONS.md`: sending
  your prompts, code, screenshots or scene data is opt-in, but a minimal anonymous usage record (install ID, session
  ID, tool name, success, duration, versions, OS, timestamp) is sent by default; only `DISABLE_TELEMETRY=true` in
  the server's environment stops it. `BLENDER_MCP_SAFE_MODE=1` makes it check each script before running it.

Measured: nothing — no control-arm eval.

Credit: Adapted from [EL4CTEO/blender-skills](https://github.com/EL4CTEO/blender-skills) @71d031d (MIT, © 2026 EL4CTEO; `blender_qa.py` copied and modified, see NOTICE), with facts also drawn from [ra100/blender-claude-plugin](https://github.com/ra100/blender-claude-plugin) @78e9151, [MartinRapcan/blender-claude-skill](https://github.com/MartinRapcan/blender-claude-skill) @70f45e3 and [AiverReaver/blender-unreal-pipeline-skill](https://github.com/AiverReaver/blender-unreal-pipeline-skill) @b590525 (all MIT); prose rewritten and re-verified here.
