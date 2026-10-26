# Jolt Physics 3D: what changes when a project runs it

> Last verified: 2026-10-26 — https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html

Godot 4.6 made Jolt the default 3D engine for NEW projects. Most Godot 3D advice in circulation
was written for GodotPhysics3D, and the API is identical, so the wrong answer compiles and runs.
Everything here applies to 3D only; 2D always runs Godot's own engine.

## Which engine is running

- Read `physics/3d/physics_engine` (in `project.godot`: `3d/physics_engine=` under `[physics]`).
  `"Jolt Physics"` means Jolt; absent or `DEFAULT` means GodotPhysics3D.
- A project created with 4.6 or later gets Jolt. A project upgraded from an older minor keeps
  whatever it had — upgrading the editor does not switch engines.

## Symptom → cause → remedy under Jolt

| Symptom | Cause | Remedy |
|---|---|---|
| `face_index` is always `-1` in `intersect_ray()` / `RayCast3D` results | Face indices are off by default | Physics > Jolt Physics 3D > Queries > Enable Ray Cast Face Index — costs about 25% more memory per `ConcavePolygonShape3D` |
| A one-body joint's limits come out inverted after switching engines | Jolt treats the lone body as `node_b`, with `node_a` as the world; GodotPhysics3D treats it as `node_a` | Assign the body to `node_b`, or set Physics > Jolt Physics 3D > Joints > World Node for an existing project |
| Joint softness/bias settings change nothing, and Godot warns about non-default values | Soft limits are unsupported: `bias`/`damping`/`impulse_clamp` on `PinJoint3D`; `bias`/`softness`/`relaxation` on `HingeJoint3D` and `ConeTwistJoint3D`; `angular_*` and limit softness/restitution/damping on `SliderJoint3D`; limit softness/restitution/damping/erp on `Generic6DOFJoint3D` | Design for hard limits, or stay on GodotPhysics3D for that mechanism |
| A frozen kinematic `RigidBody3D` reports no contacts with static or kinematic bodies, even with `max_contacts_reported > 0` | Skipped for performance | Physics > Jolt Physics 3D > Simulation > Generate All Kinematic Contacts |
| Shape queries on small shapes return odd normals | `margin` first shrinks the shape, then a shell is added; the real margin is Collision Margin Fraction × the shape's smallest AABB axis, with `margin` only an upper bound | Tune Physics > Jolt Physics 3D > Collisions > Collision Margin Fraction |
| Bodies far from the origin fall through a `WorldBoundaryShape3D` floor | Jolt caps the "infinite" plane's size to avoid precision loss | Raise Physics > Jolt Physics 3D > Limits > World Boundary Shape Size |

## Changed in 4.7 (Jolt only)

From the 4.7 migration guide, "Behavior changes > Physics":

- `WorldBoundaryShape3D.plane.d` now follows Godot's sign convention, the opposite of 4.6 under
  Jolt. A floor tuned on 4.6 sits at the wrong height on 4.7: flip the sign of `d`.
- `SoftBody3D` mass now defaults to 1 kg for the whole body (it was 1 kg per point, a very heavy
  body), and `linear_stiffness` is applied differently. Re-tune `linear_stiffness` and
  `damping_coefficient` on every soft body.
- `Area3D` now reports overlaps with `SoftBody3D` through its signals and methods. Filter with
  collision layers and masks if the old silence was relied on.
