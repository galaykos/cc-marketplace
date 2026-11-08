# asset-forge.json

Lives at the game project's root (`${CLAUDE_PROJECT_DIR}/asset-forge.json`), never in the plugin. Write it on
first use from the user's answers; ask for every field marked **ask** in one batched question.

```json
{
  "engine": "unity",
  "platforms": ["pc", "mobile"],
  "primary_platform": "pc",
  "style": {
    "description": "stylized low-poly, chunky proportions, warm palette",
    "palette": {"base": [[0.55, 0.33, 0.16], [0.72, 0.55, 0.2]], "shadow": [0.23, 0.18, 0.35], "highlight": [1.0, 0.92, 0.7]}
  },
  "game_camera": {"type": "perspective", "distance_m": 6, "fov_deg": 60, "screen_height_px": 1080},
  "folders": {
    "export_dir": "Assets/Art/Models",
    "references": "art/references",
    "snapshots": "/tmp/asset-forge/snapshots",
    "renders": "/tmp/asset-forge/renders"
  },
  "budget_overrides": {"pc": {"tris": {"prop_medium": 6000}}},
  "naming_overrides": {}
}
```

| Field | Ask? | Notes |
|---|---|---|
| `engine` | **ask** — never guess | `unity`, `unreal`, `godot` or `generic` (glTF). Drives `presets/engines/<engine>.json` |
| `platforms` | **ask** | Any of `pc`, `console`, `mobile`. A game shipping on several tiers lists them all: author for `primary_platform`, then validate each tier and scale down (LOD ratios, texture size) for the lower ones |
| `primary_platform` | **ask** when `platforms` has several | The tier the source asset is authored for, normally the highest |
| `style.description` | **ask** | Free text; the art-reviewer judges "style match" against it and the references |
| `style.palette` | offer the stylize recipe default | sRGB 0–1. `base` colours cycle over material slots; a shadow tint (not grey) and a highlight |
| `game_camera` | **ask** | `perspective` (`distance_m`, `fov_deg`, `screen_height_px`), or `ortho` (`ortho_height_m`, `screen_height_px`, `elevation_deg`: 45 isometric, 90 top-down). Feeds the game-distance review render |
| `folders.export_dir` | **ask**, offer the engine's usual | Unity `Assets/…`, Godot `res://` folder on disk, Unreal a source-art folder outside `Content/` |
| `folders.references` | ask if the user has references | Images the art-reviewer compares against |
| `budget_overrides`, `naming_overrides` | no | Deep-merged over the presets; pass `budget_overrides[tier]` as `validate_asset`'s `overrides` |

## Preset summary (read the JSON for the full set)

| Engine | Format | Mesh name | LOD | Collision | Pivot | Packed map |
|---|---|---|---|---|---|---|
| unity | FBX, `FBX_SCALE_ALL` | `SM_`/`SK_` + PascalCase | `_LOD0…` in one file (LODGroup) | `{name}_Collider` (Unity reads no FBX convention: add a MeshCollider on import) | bottom centre | MaskMap R metal, G AO, B detail, A smoothness |
| unreal | FBX, `FBX_SCALE_UNITS` | `SM_`/`SK_` | separate files | `UCX_{name}_01`, `UBX_`, `USP_`, `UCP_`; one custom-collision mesh per file | world origin | ORM |
| godot | GLB | free | engine generates on import | `{name}-colonly`, `-convcolonly` | bottom centre | ORM |
| generic | GLB | free | `_LOD0…` | `{name}_COL` | bottom centre | glTF metallicRoughness + occlusion |

| Budget (tris) | prop_small | prop_medium | prop_large | hero_prop | character | environment_piece |
|---|---|---|---|---|---|---|
| pc | 1,500 | 5,000 | 15,000 | 30,000 | 60,000 | 10,000 |
| console | 1,000 | 4,000 | 12,000 | 25,000 | 45,000 | 8,000 |
| mobile | 300 | 1,000 | 3,000 | 8,000 | 15,000 | 2,500 |

Texel density: 512 px/m on pc and console, 256 on mobile, ±25%. LOD ratios 1 / 0.5 / 0.25 / 0.1 (mobile stops
at 0.25). These are starting defaults, not engine limits.
