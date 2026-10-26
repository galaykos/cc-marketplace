---
name: godot-best-practices
description: Use when writing, reviewing or debugging Godot 4 code or project files — `.gd`, `.tscn`, `.tres`, `.gdshader`, `project.godot`, `export_presets.cfg`, a `Godot.NET.Sdk` C# project — or when a 4.6/4.7 upgrade changed behaviour: Jolt Physics 3D, `@rpc` "not allowed" errors, MultiplayerSynchronizer visibility, web export COOP/COEP, PCK encryption, `duplicate()` sharing sub-resources, `.uid` files, JSON integers coming back as floats.
---

> Last verified: 2026-10-26 — https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html
<!-- version-tail-ok: the stamp points at Godot's own migration guide; the engine ships as a binary
     with no npm/composer/pypi package, so check-doc-staleness --live has nothing to compare.
     What goes unchecked, stated: nothing machine-reads the guide either. -->

## Read the version first

- Read the engine minor from `project.godot` — `config/features=PackedStringArray("4.7", …)`
  under `[application]` — and, for C#, `Sdk="Godot.NET.Sdk/4.7.x"` in the `.csproj`. Advise
  for that minor. An upgrade is a separate task the user asks for, never a side effect.
- Never mix Godot 3 and Godot 4 snippets. A 3.x form (`export var`, `yield`,
  `connect("sig", self, "m")`, `move_and_slide(velocity)`, `instance()`, `SCREEN_TEXTURE`)
  does not parse in 4.x; write the 4.x form instead of patching around it.
- Before debugging 3D physics, read `physics/3d/physics_engine`: Jolt and GodotPhysics3D
  share one API and behave differently.

## Where the inverted advice lives

| Area | What a 2024–early-2026 answer gets wrong | Read |
|---|---|---|
| 3D physics | Assumes GodotPhysics3D; a project created in 4.6+ runs Jolt, which handles joints, margins, ray face indices and kinematic contacts differently | `references/jolt-physics.md` |
| Multiplayer | Reads `"authority"` as "the server"; grants `set_visibility_for` on a public synchronizer; sets up auth on one side only | `references/multiplayer.md` |
| Export, web, C# | Demands COOP/COEP for every web build; expects official templates to load an encrypted PCK; expects C# to export to Web | `references/export-and-dotnet.md` |
| Upgrades 4.3 → 4.7 | Code that parsed on 4.6 and fails on 4.7; defaults that flipped (glow, `area_mask`, input device ids, `MeshInstance3D.skeleton`) | `references/version-changes.md` |

## Traps that need no reference

### Data and resources

- `duplicate(true)` copies nested arrays, dictionaries and sub-resources that have no path of
  their own. A sub-resource saved as its own `.tres` stays SHARED, so editing the "copy" edits
  every user of that file. Use `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` where your minor
  has it.
- Since 4.4 every script and shader has a `<file>.uid` sidecar. Commit it (never `*.uid` in
  `.gitignore`) and move or delete it with its file outside the editor; without it, uid
  references fall back to paths and print warnings.
- `JSON.parse_string()` reads every number as a float: `3` comes back `3.0`, and an integer
  above 2^53 loses digits. Cast with `int()`, keep ids as strings, or round-trip engine types
  with `JSON.from_native()` / `JSON.to_native()`. Those drop Objects unless `full_objects` /
  `allow_objects` is true; keep it false for anything a player can edit.
- `Array.shuffle()` and `pick_random()` use the global seed, not your `RandomNumberGenerator`.
  A seeded RNG does not make them reproducible: call `seed()` first, or shuffle with your RNG.
- A typed `Dictionary[K, V]` still returns Variant from `get()`, so `var x := d.get(k, 0)`
  fails to parse. Write `var x: int = d.get(k, 0)`.
- `ResourceLoader.load_threaded_get(path)` consumes the request: afterwards the status for
  `path` is `THREAD_LOAD_INVALID_RESOURCE`. Stop polling before you fetch.

### Physics queries and movement

- `PhysicsRayQueryParameters3D` ignores Areas (`collide_with_areas = false`) and skips a shape
  the ray starts inside (`hit_from_inside = false`; when enabled the hit normal is zero).
  `exclude` takes RIDs — `[get_rid()]` — not nodes.
- `CharacterBody2D.move_and_slide()` already carries a moving floor's velocity
  (`platform_floor_layers` covers every layer) and adds the last platform velocity when the
  body leaves it (`platform_on_leave = PLATFORM_ON_LEAVE_ADD_VELOCITY`). Adding
  `get_platform_velocity()` in script counts it twice. Move platforms as `AnimatableBody2D`.

### Text, UI and 2D rendering

- `RichTextLabel.visible_characters_behavior` defaults to `TextServer.VC_CHARS_BEFORE_SHAPING`:
  hidden characters are left out of line breaking, so a typewriter reveal re-wraps words as
  they appear. Set `TextServer.VC_CHARS_AFTER_SHAPING`.
- 2D texture filter and repeat stopped being import options in 4.0. Set
  `CanvasItem.texture_filter` / `texture_repeat` (a node inherits its parent's; the root falls
  back to a project setting), the material in 3D, or the `sampler2D` hint in a shader.
  Re-importing a pixel-art texture changes nothing.
- To switch off a whole screen behind a modal, set its root Control's
  `focus_behavior_recursive = FOCUS_BEHAVIOR_DISABLED` and
  `mouse_behavior_recursive = MOUSE_BEHAVIOR_DISABLED`; children inherit both. Both are in the
  4.7 class reference — confirm your minor has them.

### Audio

- `AudioEffectCompressor.attack_us` is in MICROseconds (20–2000, default 20), so the slowest
  attack is 2 ms; `release_ms` is in milliseconds (20–2000, default 250).
- `AudioEffectLimiter` is deprecated; use `AudioEffectHardLimiter`.

### Shaders

- A spatial shader that reads or writes `ALPHA` moves to the transparent pipeline even when
  the value is always 1.0: no shadows, no SSAO, depth-sorted. Leave `ALPHA` alone in opaque
  shaders; for cut-outs also set `ALPHA_SCISSOR_THRESHOLD`.
- `TIME` wraps every `rendering/limits/time/time_rollover_secs` (3600 by default), so a
  long-period effect jumps once an hour. Pick periods that divide the rollover, or pass your
  own time in a uniform.

### Signals

- A connected lambda belongs to the script that created it, not to the nodes it captures. When
  a captured node is freed, the connection stays and errors ("Lambda capture at index 0 was
  freed"). Every `func():` is a new Callable, so `is_connected()` cannot see a repeat. Connect
  a method on the listener, or keep the lambda in a variable and disconnect it.

## Who enforces what

| Rule | Standing |
|---|---|
| Read the minor before advising; never mix majors | **recorded** — nothing checks which version an answer targets |
| Every trap above and in `references/` | **recorded** — nothing in this plugin runs Godot or lints `.gd`; **agent-graded** only when a reviewer applies them to a diff |
| Broken `res://` paths, uids and scene parent paths after a move or rename | a script with an exit code — `godot:godot-project-check`; nothing runs it unless someone does |

## Anti-patterns

- **3.x muscle memory** — a `yield`, string `connect` or `move_and_slide(velocity)` in a 4.x
  project. Rewrite it; do not shim it.
- **Debugging the wrong engine** — tuning joints or margins without reading
  `physics/3d/physics_engine` first.
- **Trusting a JSON number** — passing a parsed number on as an int without `int()`, or
  storing a 64-bit id as a JSON number.
- **The shared "copy"** — `duplicate(true)` on a resource whose sub-resources live in their
  own files, then mutating the copy.
