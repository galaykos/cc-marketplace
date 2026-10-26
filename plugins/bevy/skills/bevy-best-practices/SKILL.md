---
name: bevy-best-practices
description: Use when writing, upgrading or debugging a Bevy game in Rust — `Cargo.toml` depends on `bevy`, code calls `add_systems`, `Query`, `Commands`, `EventReader`, observers or `NextState`, or the compiler or a panic names `On<Add, T>`, `Pointer<Press>`, `set_if_neq`, `Name::new`, `iter_many`, `IsResource`, B0001 or B0002 — the 0.17–0.20 breaking changes a remembered answer still writes the old way.
---

> Last verified: 2026-10-26 — https://bevy.org/learn/migration-guides/0-19-to-0-20/
<!-- version-tail-ok: Bevy ships as a crate and check-doc-staleness reads no crates.io tail; the stamp points at bevy.org's migration guides, re-read for 0.17, 0.19 and 0.20 -->

## Read the version first

- Read the resolved `bevy` version from `Cargo.lock` before writing any Bevy code;
  `Cargo.toml` holds only the requirement. When lock, manifest and toolchain files
  disagree, `stack-scan:installed-versions` says which one wins.
- Every Bevy minor is a breaking release. Write to the locked minor, never paste a
  snippet from another one, and run a requested upgrade one minor at a time through
  https://bevy.org/learn/migration-guides/, kept apart from feature work.
- Everything below applies FROM the version in its row. On an older lock, keep the old
  form the project already uses.

## What changed, and what memory still writes

| Since | Memory writes | Write instead | The old form fails with |
|---|---|---|---|
| 0.17 | `EventReader`, `EventWriter`, `Events<E>`, `add_event` for buffered events | `#[derive(Message)]`, `MessageReader`, `MessageWriter` (`.write(..)`), `Messages<M>`, `app.add_message::<T>()` | unresolved import |
| 0.17 | `Event` for buffered and observed alike | `Event` is observer-only: `#[derive(Event)]` + `On<E>` + `commands.trigger(..)`; a targeted one derives `EntityEvent` and carries an `entity` field | trait bound not satisfied |
| 0.17 | `StateScoped(state)` | `DespawnOnExit(state)` | renamed — do not write the old name in new code |
| 0.19 | `#[derive(Resource, Component)]` on one type | `#[derive(Resource)]` alone — `Resource` is now a subtrait of `Component` | conflicting implementations of `Component` |
| 0.20 | `On<Add, Player>` | `On<Add<Player>>`; same for `Insert`, `Discard`, `Remove`, `Despawn` | struct takes 1 generic argument but 2 were supplied |
| 0.20 | `On<Pointer<Press>>`, `press.pointer_location.position` | `On<PointerPress>` (every `Pointer<E>` is flattened the same way), `press.pointer.position` — a `Vec2`; `pointer.location()` when a `Location` is needed | not found |
| 0.20 | `next.set_if_neq(state)` on `ResMut<NextState<_>>` | `next.set_if_different(state)` | can't compare `NextState` — the old name now resolves to the change-detection method |
| 0.20 | `Name::new(text.as_str())` | `Name::new(text.clone())` or `Name::new(format!(..))` — `From<&str>` became `From<&'static str>` | does not live long enough |
| 0.20 | `for item in q.iter_many(ids)` binding the item | each item is `Result<_, QueryEntityError>`; `.matched()` on `QueryManyIter`/`QueryManyUniqueIter` skips misses as before, `.flat_map(Result::ok)` on a sorted one, `let Ok(..) else { return }` in the `par_` variants | mismatched types |

`set_if_different` exists because `set` always runs `OnExit`/`OnEnter`, even when the
target is the current state.

## Footguns that compile, then panic or misbehave

- **Resources are entities (0.19).** Each resource sits on an entity tagged `IsResource`
  (`use bevy::ecs::resource::IsResource;` — not in the prelude). Broad queries match those
  entities: `Query<EntityMut>` next to any `Res<T>` panics at startup with B0001 or B0002
  (which one depends on parameter order), and a "despawn everything" loop over
  `Query<Entity>` despawns the resources too. Query a marker component of your own, or add
  `Without<IsResource>`.
- **Sprites render through `Mesh2d` (0.20).** The sprite backend moved to
  `Mesh2d`/`Material2d`, so overlapping sprites at equal `z` can swap draw order after the
  upgrade. Equal-z order was never guaranteed; give overlapping sprites distinct
  `Transform` z values.
- **Built-in sets are ordered weakly (0.20).** `RenderSystems` in `Render`, the
  `Core2d`/`Core3d` pass sets and `UiSystems` in `PostUpdate` moved from `.chain()` to
  `.chain_weak()`/`.after_weak()`/`.before_weak()`, which hold only between systems that
  share data access. A custom system in one of those sets that relied on an earlier one
  finishing first, with no data dependency, needs an explicit `.after(..)`.
- **`ScheduleBuildSettings` gained a field under the `debug` feature (0.20).** An
  exhaustive struct literal stops compiling; add `shuffle_seed: None` or end with
  `..default()`. `Some(seed)` shuffles the order of systems that have no ordering
  constraint — run tests over several seeds to flush out order that works by accident,
  and log the seed so a failing order replays.

## Who enforces what

| Rule | Standing |
|---|---|
| Read `Cargo.lock` before writing Bevy code | agent-graded — nothing reads the lockfile for you |
| The table above | recorded — true as of the stamp; no script re-reads it when the next minor lands |
| No double `Resource`/`Component` derive, no broad query beside `Res<T>` | enforced by rustc and by Bevy's startup panic, not by this plugin — the rule saves the round trip |
| Distinct z for overlapping sprites | unenforceable — nothing fails; the frame just draws in another order |

## Anti-patterns

- **Snippet from another minor.** A blog post or an answer for 0.15–0.19 pasted into a
  0.20 project — read the lock first, then the table.
- **`Query<Entity>` as "every game entity"** on 0.19+ — it includes resources.
- **Rescuing an old call with a shim.** Do not re-introduce `EventReader` aliases or a
  local `set_if_neq` wrapper; port to the current name.
