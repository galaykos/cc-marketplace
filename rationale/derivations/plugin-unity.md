# unity: the docstring text moved out of the code (2026-10-26)

The text below is the module docstring of `check_unity_project.py` as shipped upstream at gamedev-skills/awesome-gamedev-agent-skills@184b72b (Apache-2.0), moved verbatim on 2026-10-26 when the script was ported; the file now opens with a three-line summary in its place. A pointer by name was left in the file, `# Why, limits, history: rationale/derivations/plugin-unity.md § <heading>`. Standing: `recorded` — no gate reads this file.

## plugins/unity/scripts/check_unity_project.py

### Header: what it checks and why

```text
Check a Unity 6 project for broken .meta files and missing script references.

Run it after creating, moving, renaming or deleting files outside the Unity
Editor. Unity has not imported those changes yet, so this looks for the edits
that will break the project on the next import:

ERRORS (the project will really break)
  duplicate-guid       Two .meta files share a GUID (usually a copied .meta).
  moved-without-meta   A .meta was left behind while its asset moved or was
                       renamed. Unity would give the asset a new GUID and every
                       reference to it would break ("Missing script").
  malformed-meta       A .meta has no valid 32-hex-digit `guid:` line.
  missing-script       A text-serialized scene/prefab/asset has an
                       `m_Script: {fileID: 11500000, guid: X, type: 3}` reference
                       and no .meta in Assets/, Packages/ or the package cache
                       has GUID X. Reported as a warning instead when some
                       packages could not be read (for example when
                       Library/PackageCache does not exist yet).

WARNINGS
  missing-meta         An asset or folder has no .meta yet. This is normal for
                       a new file: Unity creates the .meta on the next import.
                       It does not make --strict fail.
  orphan-meta          A .meta whose asset or folder is gone.
  meta-name-case       A .meta matches its asset only when case is ignored.
  class-name-mismatch  A file declares a MonoBehaviour/ScriptableObject subclass
                       whose name differs from the file name, so Unity cannot
                       attach it.

Only Assets/ and the embedded packages in Packages/ are checked. Library/,
Temp/, Logs/ and similar folders are never walked, except that .meta GUIDs are
read from Library/PackageCache and from local `file:` packages so their scripts
count as present. Files Unity ignores during import (names starting with `.`
outside Assets/StreamingAssets, names ending with `~`, files and folders named
`cvs`, `.tmp` files, hidden folders) are skipped. Binary-serialized files (not
starting with `%YAML`) are skipped.

Standard library only. Read-only: nothing is ever written.
```
