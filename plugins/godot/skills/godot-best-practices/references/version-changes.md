# Godot 4.3 → 4.7: changes that break or silently alter working code

> Last verified: 2026-10-26 — https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html

Only changes where code or settings that were right on the previous minor are now wrong.
Apply an entry when the project's `config/features` minor is at or above its heading; below
it, the older behaviour still holds. New features are deliberately absent — the old way of
doing those things still works.

## 4.7 — from the 4.6 → 4.7 migration guide

**Code that stops parsing or behaves differently**

- An override of a method with a typed return now inherits that return type, so every path
  must return a value. Overrides that parsed on 4.6 fail; add `return null` at the end.
- Setting one element of a packed-array property (`points[0] = v`) no longer calls the
  property's setter. Reassign the whole array when the setter must run.
- Mouse and keyboard events no longer carry `device == 0` (some joypads use 0). Compare
  `InputEvent.device` with `InputEvent.DEVICE_ID_MOUSE` / `InputEvent.DEVICE_ID_KEYBOARD`, or
  check the event type.
- `AudioEffectSpectrumAnalyzer.tap_back_pos` was removed.
- C#: `Animation.length` is now `double`; `Control.accessibility_live` takes
  `AccessibilityServer.AccessibilityLiveMode`; `RichTextLabel.add_image()` / `update_image()`
  take float sizes and `width_unit` / `height_unit` (`RichTextLabel.ImageUnit`) in place of
  `width_in_percent` / `height_in_percent`.

**Defaults and behaviour that changed**

- `AudioStreamPlayer` `area_mask` default changed from layer 1 to 0 (disabled). A project that
  uses an Area's `audio_bus_override` with the old default mask loses the override; set the
  mask back to layer 1.
- Jolt only: `WorldBoundaryShape3D.plane.d` sign flipped, `SoftBody3D` mass and stiffness
  changed, `Area3D` reports `SoftBody3D` overlaps — see `jolt-physics.md`.
- `CanvasItem` line drawing no longer adds the antialiasing feather, so lines look thinner;
  raise the width if the old look was intended.
- The `LinearToSRGB` visual shader node no longer clamps to [0, 1] on Forward+ and Mobile.
- `LookAtModifier3D.relative` default changed from true to false.
- `ResourceImporterDynamicFont` `hinting` default changed from 1 to 3.

## 4.6 — from the 4.5 → 4.6 migration guide

- New projects default to Jolt for 3D physics; existing projects keep their engine
  (`jolt-physics.md`).
- Scene files now store a `unique_id` per node; re-saving a 4.5 scene in 4.6 produces large but
  expected diffs. Upgrade every file at once with Project > Tools > Upgrade Project Files.
- Glow defaults changed: blend mode Screen (was Soft Light), `glow_intensity` 0.3 (was 0.8),
  and the `glow_levels` weights moved — glow looks much brighter; re-tune it. Mobile's glow was
  rewritten and looks different. Volumetric fog blends more physically and looks brighter.
- `MeshInstance3D.skeleton` default changed from `NodePath("..")` to `NodePath("")`. A skinned
  mesh that relied on its parent skeleton needs the path set, or enable
  `animation/compatibility/default_parent_skeleton_in_mesh_instance_3d`.
- New Windows projects default to the D3D12 driver (`rendering/rendering_device/driver.windows`).
- `AStar2D` / `AStar3D.get_point_path()` and `AStarGrid2D.get_id_path()` / `get_point_path()`
  return an empty path when the start point is disabled or solid.
- The Android build template follows Android Studio's layout: sources in
  `android/build/src/main/java/`, manifest and assets under `src/main/`.

## 4.4

- Scripts and shaders get `.uid` sidecar files — commit them (SKILL.md, "Data and resources").
- `@export_tool_button` works only in a `@tool` script.

## 4.3

- The `TileMap` node is deprecated: one `TileMapLayer` node per layer. The TileMap toolbar's
  "Extract TileMap layers as individual TileMapLayer nodes" converts a scene; then drop the
  leading `layer` argument from cell calls (`set_cell(layer, …)` becomes `set_cell(…)` on the
  right layer node).
- Web export Thread Support is off by default (`export-and-dotnet.md`).
