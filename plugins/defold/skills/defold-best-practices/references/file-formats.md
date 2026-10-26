# Defold editor files that Bob accepts

> Last verified: 2026-10-26 — https://defold.com/manuals/bob/

Every shape below comes from one small project that Bob 1.14.0 built (`--variant headless`)
and the 1.14.0 headless engine ran. When the editor is available, let it write these files.
Copy these shapes only when you must write them by hand. The escaped embedded `data:`
strings are where hand-written files break.

Editor files are protobuf text format. Omitted fields keep their defaults, `#` starts a
comment, and the field order does not matter to Bob. The schemas are the `*_ddf.proto`
files in the Defold engine source.

## game.project

An INI file, required, in the project root, named exactly `game.project`. Paths name the
compiled file, with a trailing `c`.

```ini
[project]
title = Defold Core Example

[bootstrap]
main_collection = /main/main.collectionc

[input]
game_binding = /input/game.input_bindingc

[physics]
use_fixed_timestep = 1

[engine]
fixed_update_frequency = 60
```

- Library dependencies are `dependencies#0 = https://…/archive.zip`, `dependencies#1 = …`.
  Bob's `resolve` fetches them into `.internal/lib/`.
- Read any setting at runtime with `sys.get_config_string("project.title")`.

## .collection

Game-object instances, an embedded instance, a nested collection, and a per-instance
override of a script property:

```text
name: "main"
instances {
  id: "player"
  prototype: "/main/player.go"
  position {
    x: 480.0
    y: 120.0
  }
  component_properties {
    id: "player"                 # the id of the script component inside player.go
    properties { id: "speed" value: "250.0" type: PROPERTY_TYPE_NUMBER }
  }
}
embedded_instances {
  id: "check"
  data: "components {\n  id: \"check\"\n  component: \"/main/check.script\"\n}\n"
}
collection_instances {
  id: "decor"
  collection: "/main/wave.collection"
  position {
    x: 100.0
    y: 400.0
  }
}
scale_along_z: 0
```

- `name` becomes the socket when the collection loads through a proxy, so no two loaded
  collections may share it.
- Ids inside a nested collection are prefixed with its id: the `leader` object in `decor`
  is `/decor/leader`. Attach a child with `children: "child_id"` on the parent instance.
- `collectionfactory.create` returns a table keyed by the collection's ids. The new ids
  look like `hash: [/collection0/leader]`, and per-instance properties are keyed the same
  way: `{ [hash("/leader")] = { hp = 5 } }`.

## .go

`components` reference component files. `embedded_components` carry the component's own
file as an escaped string, split across adjacent quoted lines:

```text
components {
  id: "player"
  component: "/main/player.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"blob\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/main/main.atlas\"\n"
  "}\n"
  ""
}
embedded_components {
  id: "bulletfactory"
  type: "factory"
  data: "prototype: \"/main/bullet.go\"\n"
  ""
}
embedded_components {
  id: "levelproxy"
  type: "collectionproxy"
  data: "collection: \"/levels/level1.collection\"\n"
  ""
}
```

Older sprite data uses `tile_set: "/main/main.atlas"` instead of the `textures` block. Keep
whichever form the project already uses.

## .input_binding

```text
key_trigger {
  input: KEY_LEFT
  action: "left"
}
mouse_trigger {
  input: MOUSE_BUTTON_LEFT
  action: "touch"
}
```

`/builtins/input/all.input_binding` exists for quick tests. A game should own its bindings.

## Where a build error points

Bob names the source file, at line 0, for most reference errors:

```text
ERROR: game.project:0: '…the bootstrap.main_collection '/main/main.collectio' can't be found'
ERROR: main/probe.script:0: '…the Lua module '/modules/nothere.lua' can't be found'
ERROR main/main.atlas:0 Resource 'main/images/missing.png' is not created
```

For an embedded component it names a generated file that exists in no source folder:

```text
ERROR: build/default/_generated_c1d664c47a440ab4.factory:0: '…the prototype '/main/missing.go' can't be found'
```

Search the sources for the quoted path, which is escaped (`\"/main/missing.go\"`) inside
embedded data, or run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_defold_project.py" .`,
which reports the owning `.go` file and line.
