# Export, web builds and C#: the traps

> Last verified: 2026-10-26 — https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html

## Web

- **Thread Support (`variant/thread_support`) is off by default since 4.3.** A single-threaded
  web build runs on any static host. Cross-origin isolation —
  `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` —
  is needed only when Thread Support is on. Advice that every Godot 4 web build needs those
  headers predates 4.3.
- A host that cannot set headers (GitHub Pages) with threads on: enable the preset's PWA option
  *Ensure Cross Origin Isolation Headers*, whose service worker adds them, or turn threads off.
  itch.io has its own SharedArrayBuffer toggle.
- Serve over HTTP(S). Opening `index.html` from `file://` does not run.

## Packaging

- **Non-resource files are not exported.** A `.json`, `.txt` or `.csv` read with `FileAccess`
  is missing from the build unless the preset's Resources tab lists it under *Filters to export
  non-resource files* (e.g. `*.json`). It works in the editor and fails only in the export.
- **PCK encryption does not work with the official templates** — the game fails to load its data
  at startup. Build custom export templates with the key in `SCRIPT_AES256_ENCRYPTION_KEY`,
  select them as custom templates, set the same 64-hex-character key in the preset (or
  `GODOT_SCRIPT_ENCRYPTION_KEY` for CLI exports), enable encryption AND add include filters —
  with empty filters nothing is encrypted. It deters casual unpacking; it protects no secret.
- `res://` is read-only in an export. Write saves and settings to `user://`.

## Command-line export in CI

- `godot --headless --export-release "<preset name>" <out>` — the preset name is matched
  exactly, case and spaces included; quote it. `<out>` includes the file name, and its
  directory must already exist — create it in the CI step first. `--export-debug` and
  `--export-pack` take the same arguments; `--export-pack`'s extension picks PCK or ZIP.
- After the export step, check that the output file exists and is non-empty before uploading
  it; do not treat the step's exit status as proof of a build.
- `--quit-after N` counts main-loop iterations, not seconds.
- Export templates must match the editor version exactly, including beta/rc suffixes;
  "No export template found" after an upgrade means re-download them.

## C# (.NET)

- Godot's C# needs the .NET editor build and a .NET SDK: **.NET 8 or later**, and **.NET 9 or
  later to export to Android**. If the generated `.csproj` carries an Android-only `net9.0`
  target, keep that condition when editing the file.
- **C# projects cannot export to the Web in Godot 4.** Desktop (Windows, Linux, macOS) is
  supported; Android and iOS are experimental, and iOS exports only from macOS. A project that
  needs a web build keeps that code in GDScript.
- 4.7 changed `Animation.length` from float to double and retyped `Control.accessibility_live`
  and several `RichTextLabel.add_image()` / `update_image()` parameters; GDScript keeps
  working, C# call sites need edits. See `version-changes.md`.
