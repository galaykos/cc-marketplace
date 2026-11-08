# Blockout recipes

Every spec below runs as written through `blockout.skin_from_skeleton(spec, name=…, subdivisions=1)` (checked by
`scripts/__tests__/blender/test_recipes.py`). Metres, Z up, the asset facing -Y. Mirror side joints yourself.

## Biped, stylized, about 1.05 m (5 H)

Limbs branch straight from the torso joints. A separate hip or shoulder joint inside the torso's radius makes
overlapping skin and a non-manifold result (measured: the first version of this recipe did exactly that).

```python
biped = {"joints": {
    "pelvis": {"co": [0, 0, 0.55], "radius": 0.13}, "chest": {"co": [0, 0, 0.8], "radius": 0.15},
    "neck": {"co": [0, 0, 0.92], "radius": 0.06}, "head": {"co": [0, -0.02, 1.07], "radius": 0.14},
    "l_elbow": {"co": [0.24, 0.02, 0.66], "radius": 0.045}, "l_hand": {"co": [0.26, -0.02, 0.48], "radius": 0.06},
    "l_knee": {"co": [0.1, -0.02, 0.28], "radius": 0.06}, "l_foot": {"co": [0.1, -0.06, 0.05], "radius": 0.07},
    "r_elbow": {"co": [-0.24, 0.02, 0.66], "radius": 0.045}, "r_hand": {"co": [-0.26, -0.02, 0.48], "radius": 0.06},
    "r_knee": {"co": [-0.1, -0.02, 0.28], "radius": 0.06}, "r_foot": {"co": [-0.1, -0.06, 0.05], "radius": 0.07}},
  "bones": [["pelvis", "chest"], ["chest", "neck"], ["neck", "head"],
            ["chest", "l_elbow"], ["l_elbow", "l_hand"], ["pelvis", "l_knee"], ["l_knee", "l_foot"],
            ["chest", "r_elbow"], ["r_elbow", "r_hand"], ["pelvis", "r_knee"], ["r_knee", "r_foot"]]}
```

## Tree, stylized, 4 m

```python
tree = {"joints": {
    "root": {"co": [0, 0, 0], "radius": 0.35}, "trunk": {"co": [0, 0, 1.6], "radius": 0.22},
    "fork": {"co": [0.1, 0, 2.4], "radius": 0.17}, "b1": {"co": [0.9, 0.2, 3.3], "radius": 0.07},
    "b2": {"co": [-0.6, -0.4, 3.6], "radius": 0.08}, "b3": {"co": [0.2, 0.5, 3.9], "radius": 0.06},
    "r1": {"co": [0.6, 0.2, -0.05], "radius": 0.1}, "r2": {"co": [-0.5, 0.4, -0.05], "radius": 0.09}},
  "bones": [["root", "trunk"], ["trunk", "fork"], ["fork", "b1"], ["fork", "b2"], ["fork", "b3"],
            ["root", "r1"], ["root", "r2"]]}
```

Then `deform.noise_displace(obj, scale=0.4, strength=0.03)` for bark breakup, `bulge_along_curve` along each root,
and foliage as separate cards or blobs (`blockout.metaball_blob`).

## Rock cluster

```python
from forge import blockout
rocks = [blockout.rock(seed=s, size=z, style=st, name=f"SM_Rock_{i:02d}")["object"]
         for i, (s, z, st) in enumerate([(3, 1.2, "boulder"), (7, 0.7, "boulder"), (11, 0.5, "shard"), (5, 0.9, "slab")])]
```

Place them overlapping by 10–20% so the cluster reads as one silhouette, sink each 5–15% into the ground, rotate
the slab to lean on the boulder. Join only when they share a material and LOD together.
