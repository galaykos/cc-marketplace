# Changelog — bevy

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-26

- **New plugin: `bevy-best-practices`.** The Bevy changes from 0.17 to 0.20 that an answer from memory still writes the old way: buffered events renamed to messages (`MessageReader`/`MessageWriter`), `DespawnOnExit`, `Resource` as a subtrait of `Component` with resources stored on `IsResource` entities (and the B0001/B0002 panics a broad query now causes), `On<Add<T>>` lifecycle observers, flattened `PointerPress` events, `set_if_different`, `Name` taking `&'static str`, `iter_many` yielding `Result`, sprites on `Mesh2d`, weakly ordered built-in sets and the `shuffle_seed` field. Every row was re-read against bevy.org's 0.17, 0.19 and 0.20 migration guides on 2026-10-26.
- **Standing:** recorded. Nothing re-reads the table when Bevy 0.21 ships, and the staleness checker reads no crates.io version. Unmeasured: no eval with a control arm covers it.
- **Credit.** Adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b (Apache-2.0). The prose was distilled and rewritten; no code was copied.
