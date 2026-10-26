# Physics, navigation and 2D colliders — Unity 6

> Last verified: 2026-10-26 — https://docs.unity3d.com/6000.3/Documentation/Manual/UpgradeGuideUnity6.html

Read `ProjectSettings/ProjectVersion.txt` first: the renames and the torque change apply from
Unity 6 (6000.x); the navigation items apply from AI Navigation 2.x (`com.unity.ai.navigation`
in `Packages/packages-lock.json`). Re-read against Unity's docs on the stamp date: the torque
table and the `PhysicsMaterial` class name. Carried from the upstream source without a re-read:
everything else in this file.

## Renamed in Unity 6 — write the new names

| 2022 LTS and earlier | Unity 6 |
|---|---|
| `Rigidbody.velocity` | `Rigidbody.linearVelocity` |
| `Rigidbody.drag` | `Rigidbody.linearDamping` |
| `Rigidbody.angularDrag` | `Rigidbody.angularDamping` |
| `PhysicMaterial` | `PhysicsMaterial` |

`angularVelocity` is unchanged. The old Rigidbody names still compile with obsolete warnings
(the API Updater offers the rename), so a clean build is no evidence the code is current.

## Torque changed under two force modes

From Unity 6, `AddForceAtPosition` and `AddExplosionForce` with `ForceMode.Acceleration` or
`ForceMode.VelocityChange` apply a different torque than 2022 LTS. The old code multiplied the
angular part by the body's mass, which was a maths error; Unity 6 scales it by the inertia
tensor. An upgraded project whose explosions or hit reactions now spin differently has hit
this. To reproduce the old result exactly:

| 2022 LTS call | Unity 6 equivalent |
|---|---|
| `AddForceAtPosition(f, p, ForceMode.Acceleration)` | `AddForceAtPosition(f * rb.mass, p, ForceMode.Force)` |
| `AddForceAtPosition(f, p, ForceMode.VelocityChange)` | `AddForceAtPosition(f * rb.mass, p, ForceMode.Impulse)` |
| `AddExplosionForce(f, p, r, up, ForceMode.Acceleration)` | `AddExplosionForce(f * rb.mass, p, r, up, ForceMode.Force)` |
| `AddExplosionForce(f, p, r, up, ForceMode.VelocityChange)` | `AddExplosionForce(f * rb.mass, p, r, up, ForceMode.Impulse)` |

## Footguns that hold in every version

- Collision detection: `Continuous` sweeps against static colliders only; `ContinuousDynamic`
  also against other continuous-dynamic bodies; `ContinuousSpeculative` against everything, more
  cheaply. A fast body on `Continuous` still tunnels through moving ones.
- Raycasts hit trigger colliders by default (`Physics.queriesHitTriggers`, Project Settings →
  Physics). A ground or line-of-sight ray that stops on a trigger volume needs
  `QueryTriggerInteraction.Ignore`.
- After writing `transform.position` on a physics body, queries see the old pose until the next
  simulation step. Call `Physics.SyncTransforms()` once before a same-frame query, not every
  frame.
- Kinematic-vs-kinematic and kinematic-vs-static pairs send no `OnCollision*` messages under the
  default Contact Pairs Mode.
- A concave `MeshCollider` (the default) can only be static or kinematic, and two concave
  colliders never collide. A dynamic body needs Convex enabled, or primitive colliders.

## Navigation (AI Navigation 2.x)

- There is no Bake tab and no "Navigation Static" flag. Bake with a `NavMeshSurface` component
  (namespace `Unity.AI.Navigation`), and call `surface.BuildNavMesh()` to rebake at runtime.
  Window → AI → Navigation only edits agent types and areas. `NavMeshAgent`, `NavMesh` and
  `NavMeshPath` stay in `UnityEngine.AI`.
- `OffMeshLink` is deprecated and gone from the Add Component menu. Use `NavMeshLink` from the
  same package: Transform endpoints, `Width` 0 for point-to-point, `activated` at runtime.
- A `NavMeshAgent` and a `NavMeshObstacle` enabled on the same GameObject make the agent avoid
  itself. Enable one at a time, e.g. switch to the obstacle when the NPC stops for good.

## 2D colliders and tiles

- `Collider2D.usedByComposite` is obsolete in Unity 6. Write
  `compositeOperation = Collider2D.CompositeOperation.Merge` instead.
- `RuleTile`, animated tiles and the extra brushes ship in `com.unity.2d.tilemap.extras`, not in
  the built-in Tilemap. A "type not found" on `RuleTile` means that package is missing.
