# Arcade Physics — categories, ground checks, drag

Read on demand from the phaser-best-practices SKILL. Each rule below was read from Phaser
4.2.1's Arcade source (`World#canCollide`, `World#separate`, `ProcessY`, `World#computeVelocity`)
on 2026-10-26. By the source's `@since` tags, collision categories date from 3.70 and the
other two paths are older.

## Collision categories and masks

`World#canCollide` and `World#separate` both require
`(a.collisionMask & b.collisionCategory) !== 0` AND `(b.collisionMask & a.collisionCategory) !== 0`.

| Object | Starting category | Starting mask |
|---|---|---|
| `Body` (dynamic) | `1` | `1` |
| `StaticBody` | `1` | `1` |
| `physics.add.group()` (dynamic group) | `1` | every bit (`2147483647`) |
| `physics.add.staticGroup()` | `1` | `1` |
| after `resetCollisionCategory()` | `1` | every bit |

```js
const WORLD  = 1;                               // what every untouched body is in
const PLAYER = this.physics.nextCategory();     // 2, then 4, 8, ...
const ENEMY  = this.physics.nextCategory();

player.setCollisionCategory(PLAYER).setCollidesWith([WORLD, ENEMY]);
// The ground still has mask 1 and now ignores PLAYER: widen it too.
ground.setCollidesWith([WORLD, PLAYER, ENEMY]);

// Sprite-vs-group: the GROUP's category/mask is checked first, then each member's.
enemies.setCollisionCategory(ENEMY).setCollidesWith([WORLD, PLAYER]);
enemies.getChildren().forEach((e) => e.setCollisionCategory(ENEMY).setCollidesWith([WORLD, PLAYER]));
```

To skip a few pairs, a `processCallback` that returns `false` is simpler than categories:
`this.physics.add.collider(a, b, onHit, (x, y) => x.team !== y.team)`.

## Ground checks: `blocked` vs `touching`

- `touching.*` is set for any contact. `blocked.*` (and `onFloor()`, which reads
  `blocked.down`) is set only when the other side cannot move: world bounds, a colliding
  tile, a static body, an immovable or non-pushable body, or a body that is itself blocked
  that way.
- Two ordinary dynamic bodies push each other apart with mass impact and set neither
  `blocked` flag. A player landing on a moving dynamic platform therefore never sees
  `onFloor()` true. Fix the platform: `platform.body.setImmovable(true)` or
  `platform.setPushable(false)`, or use `staticGroup()` for platforms that never move.
- A static body does not follow its game object. After moving one, call
  `body.updateFromGameObject()` or `gameObject.refreshBody()`.

## Drag

Velocity integration applies acceleration if the axis has any, and only otherwise applies
drag (`else if (allowDrag && drag)`). With input held, acceleration is non-zero and drag is
skipped:

```js
update() {
  const ax = this.cursors.left.isDown ? -600 : this.cursors.right.isDown ? 600 : 0;
  this.player.setAccelerationX(ax);   // 0 when no key is held: drag can now act
}
```

With `body.setDamping(true)`, drag becomes the fraction of velocity kept per second
(`0.05` keeps 5%), not a px/s² deceleration.
