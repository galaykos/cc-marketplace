# unity-traps: the docstring text moved out of the code (2026-10-26)

The text below is the module docstring of `check_unity_project.py` as shipped upstream at gamedev-skills/awesome-gamedev-agent-skills@184b72b (Apache-2.0), moved verbatim on 2026-10-26 when the script was ported; the file now opens with a three-line summary in its place. A pointer by name was left in the file, `# Why, limits, history: rationale/derivations/plugin-unity-traps.md § <heading>`. On 2026-11-02 the plugin was renamed from `unity` to `unity-traps`; this file (then `plugin-unity.md`) and its heading moved with it. Standing: `recorded` — no gate reads this file.

## plugins/unity-traps/scripts/check_unity_project.py

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

### Version-windowed API names (2026-11-09, unity-traps 0.6.0)

Roadmap row GD4. The checker reads `m_EditorVersion` from `ProjectSettings/ProjectVersion.txt` and the
`com.unity.cinemachine` version as Unity resolves it: an embedded `Packages/<dir>/package.json` first, then a version
the manifest pins, then, for a package the manifest does not list, a `registry` or `builtin` entry of
`packages-lock.json`, else the `package.json` of the `file:` folder or of `Library/PackageCache/com.unity.cinemachine@*`
(none when cache copies disagree). It then scans each C# file it already reads for class names, in the same pass
(`check_cs_files`), for names in that version's window. Every boundary below was read from the page named, on 2026-11-09:

| Name | Deprecated (warning) | Removed (error) | Read from |
|---|---|---|---|
| `GetInstanceID()` | 6000.4 | 6000.5 | `docs.unity3d.com/6000.4/Documentation/ScriptReference/Object.GetInstanceID.html` ("GetInstanceID is deprecated"); 6000.3 page carries no notice; `docs.unity.com/en-us/engine/6000.5/script-reference/unityengine/object/getinstanceid` ("Removed. Use GetEntityId instead.") |
| `Resources`/`EditorUtility.InstanceIDToObject`, `Selection.activeInstanceID`, `Selection.instanceIDs` | 6000.3 | 6000.5 | 6000.2 pages carry no notice; 6000.3 pages say "Deprecated."; 6000.5 pages say "Removed."; the 6.5 upgrade guide says "a large number of InstanceID APIs have been marked obsolete and will cause errors" |
| `UxmlFactory`, `UxmlTraits` | 6000.0 | 6000.6 | 2023.2 page carries no notice; 6000.0–6000.5 pages say "deprecated and will be removed"; the 6.6 upgrade guide, "Removed UXML Factory/Traits" |
| `using Cinemachine;`, `Cinemachine.Utility`, `Cinemachine.Editor` | — | 3.0 | `com.unity.cinemachine@3.0` CHANGELOG: "All namespaces changed from "Cinemachine" to "Unity.Cinemachine"" |
| `CinemachineBlendListCamera` | — | 3.0 | 3.0 CHANGELOG ("renamed to CinemachineSequencerCamera"), 3.1 What's new ("simply renamed"); no class of that name in the package source at `Unity-Technologies/com.unity.cinemachine@45728f3` |
| `CinemachineCore.Instance` | — | 3.0 | 3.1 What's new, "Removed CinemachineCore.Instance"; 3.0 CHANGELOG, "CinemchineCore refactored to remove singleton" |
| 16 Cinemachine 2 components (`CinemachineVirtualCamera`, `CinemachineFreeLook`, `CinemachinePath`, `CinemachineSmoothPath`, `CinemachineDollyCart`, `CinemachineTransposer`, `CinemachineOrbitalTransposer`, `CinemachineFramingTransposer`, `CinemachineComposer`, `CinemachinePOV`, `CinemachineTrackedDolly`, `CinemachineGroupComposer`, `CinemachineCollider`, `CinemachineConfiner`, `Cinemachine3rdPersonFollow`, `CinemachineSameAsFollowTarget`) | 3.0 | — | each `com.unity.cinemachine@3.1/api/Unity.Cinemachine.<Name>.html` carries `[Obsolete(...)]`; `CinemachineVirtualCamera` checked on the 3.0 API too |

**Unverified, not gated:** `Cinemachine3rdPersonAim`. The 3.0 CHANGELOG calls it deprecated, but it has no API page
in 3.0 or 3.1 and no class in the package source. Whether it was removed in 3.0 or later could not be settled.

The roadmap row named 6.5 for InstanceID. The docs show the deprecation earlier, so 6000.3 and 6000.4 get warnings
and 6000.5 gets errors.

- **What is skipped.** Comments and strings, with the class-name check's own stripper. A `GetInstanceID()` preceded on
  its line by a type word (`int GetInstanceID()`), which is a declaration. Any line inside an `#if`/`#elif` group whose
  condition names `UNITY_<digit>` or `CINEMACHINE`, in both branches: code that already guards on the version handled
  it. One finding per file and rule, with a use count.
- **Misses.** A call inside an interpolated string's braces, because the stripper blanks the whole string. A name
  reached through `using static`, an alias or a variable. Files over 2 MB. A project whose versions cannot be read,
  which includes a git Cinemachine before Unity has filled `Library/PackageCache` (a fresh clone or CI runner).
  `Uxml*AttributeDescription` fields are not scanned on their own: they sit inside a `UxmlTraits` class the scan
  already reports.
- **Cost.** Each rule runs only on a file holding its literal needles (`InstanceID`, `Uxml`, `Cinemachine` and the
  name itself). The namespace regex starts with its literal, because a lookbehind first made it 60 times slower. On a
  synthetic project of 24,202 files with 12,000 scripts, every one naming `Unity.Cinemachine`, on Unity 6000.6 with
  Cinemachine 3.1.2, the checker went from 1.22 s to 1.33 s (three runs each, 2026-11-09).

**Review fix, 2026-11-09: the git Cinemachine version.** The first cut fell back to `packages-lock.json` when the
manifest held a URL, and its test wrote a lock entry `{"version": "3.1.2", "source": "git"}`. UPM never writes
that. A real lock (`Haruma-K/UnityDebugSheet` `Packages/packages-lock.json`, blob `791ba554`, read 2026-11-09)
holds the URL in a git entry's `version` and the commit in `hash`, for example `com.tayx.graphy`:
`{"version": "https://github.com/Tayx94/graphy.git", "depth": 0, "source": "git", "hash": "e571e3a…"}`;
its `builtin` entries hold numbers. Unity's "Lock files" page (`docs.unity3d.com/6000.0/Documentation/Manual/upm-conflicts-auto.html`)
shows only a `registry` entry. So a git Cinemachine was never version-checked while the test passed. The version now
comes from the package's own `package.json`, and the lock is read only for a transitive `registry`/`builtin` entry.
Tests: git with and without a cache copy, two disagreeing copies, embedded, `file:` folder, transitive registry
entry, and a manifest-listed package whose lock entry is not read; three of them failed on the first cut.

## plugins/unity-traps/hooks/meta-check.sh

Added 2026-11-02 (unity-traps 0.4.0). Until then `check_unity_project.py` was **recorded** only: the
README said no hook or CI step ran it, so a `.meta` an agent left behind on a `mv` surfaced only
when Unity reimported the asset with a new GUID and every scene reference to it went missing. The
user asked for the checkers to run on their own, warning and never blocking.

Design:

- **Trigger.** A Bash command that holds a move/copy/delete verb (`mv cp rm rmdir rsync ln install
  unlink`, `git mv|rm`, `find … -delete`, Python `shutil`/`os`/`Path.rename`, Node `fs.*Sync`,
  .NET `File|Directory.Move|Copy|Delete`) and the string `Assets`. A Write/Edit qualifies only when
  it writes an `Assets/*.meta`. A hand-written `.meta` is how a copy duplicates a GUID; any other
  Write is a new file, which the checker already calls normal.
- **Which project.** It walks up from each touched path, then from `cwd`, looking for
  `ProjectSettings/ProjectVersion.txt`. That covers a monorepo with the Unity project in a
  subfolder, and a shell that is already inside it.
- **What is said.** Errors are reported wherever they are, because each one is a broken reference.
  Warnings are reported only on a touched path, its `.meta`, or below a touched folder. A legacy
  project with fifty class/file name mismatches would otherwise answer every `mv` with fifty lines.
  `missing-meta` is kept only after a move or rename (`mv`, `git mv`, `shutil.move`, `os.rename`,
  `.rename(`, `File.Move`). A copy into `Assets/` should arrive without a `.meta`, so Unity gives it
  a fresh GUID; that warning is noise there. After a move it is the only sign of a deleted `.meta`.
  Each finding is said once per context (transcript, hashed), in `meta-seen-<ctx>` under the
  plugin's state directory.
- **Cost.** The checker took 0.74 s on a synthetic 40,201-file project (200 folders, 12,000
  scripts, 8,000 prefabs, 158 MB), on three warm runs on 2026-11-02. `CHECK_TIMEOUT=20` per run, and
  hooks.json allows 45 s. A cheap exit on a Bash call that is not a move: 9 ms median, 10 ms max,
  over 20 runs.
- **Limits** (also in the header): a path held in a variable, a relative path after an in-command
  `cd` (its warnings filter out; errors still show), a move by the Editor, an IDE or `make`. A verb
  inside a heredoc body triggers a run, which costs one checker pass and prints only on a finding.

Standing: the firing and silence cases are a **gate** in
`scripts/smoke/game-checker-hooks-tests.sh`, run in CI.

**2026-11-09 (0.6.0): `api-*` findings are filtered out.** The checker's version-windowed name scan reports errors
that are not move damage, and this hook's closing advice is about `.meta` files. Verified by hand on 2026-11-09: a
6000.5 project with a `GetInstanceID()` use and a `.cs` moved without its `.meta` reported `moved-without-meta` and
not `api-removed`. No harness case pins it, because the smoke harness is outside this plugin.

**Live host check, 2026-11-02.** One headless `claude -p` session (CLI 2.1.316, haiku), with unity-traps and meshy loaded by `--plugin-dir`, ran `mv` of an `Assets/` script without its `.meta`, then `cp` of a 60,000-triangle `.glb`. Its final reply named both findings: the `.meta` left behind, and "60,000 triangles, over the 15,000 budget". So the host delivered both hooks' context, and the PreToolUse/PostToolUse `tool_use_id` bracket held. blender and pixel-art were driven only through the harness. What the agent does with a finding is
**agent-graded**.

## scripts/smoke/game-checker-hooks-tests.sh

One harness for the four checker hooks added on 2026-11-02: unity-traps `meta-check.sh`, meshy
`glb-check.sh`, blender `bpy-check.sh` and pixel-art `sheet-check.sh`. Each hook gets cases that
must fire on a broken fixture and cases that must stay silent on its nearest neighbour:

- unity-traps: `ls` and `grep` of `Assets`, a `git mv` of an asset with its `.meta`, a project
  with no `ProjectVersion.txt`, a written `.cs`;
- meshy: a model within budget, a call naming no model, a PostToolUse with no PreToolUse marker;
- blender: a non-write command, a `.py` named only inside a heredoc body, a `.py` without `bpy`, no
  version source, a 4.2 `.blend` beating a 5.2 Blender on PATH, a file outside the project;
- pixel-art: a written `package.json`, a bracketed `cat package.json`.

Every case asserts exit 0 and the payload's own `hookEventName`. One case also proves that the
repo-fallback state directory is invisible to git. The payloads carry `transcript_path`, the key
the hooks use. Blender is a PATH stub that prints a version, so the harness runs without Blender,
as CI does. 48 cases on 2026-11-02.
