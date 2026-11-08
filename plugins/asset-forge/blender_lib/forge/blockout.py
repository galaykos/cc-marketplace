"""Organic starting shapes built from data, live or in `blender -b`: skin skeletons, metaball blobs, procedural rocks,
lathes and lofts. Coordinates and sizes are metres in the new object's local space (the object sits at the world
origin). Each function creates one mesh object, named `name` or Blender's suffixed variant, and returns its real
name."""
import math
import random
import uuid

import bmesh
import bpy
from mathutils import Vector, noise

from .retopo import bake_modifier
from .util import ForgeError, new_mesh_object, ok, positive, settable_enum

ROCK_STYLES = {
    "boulder": {"shape": (1.0, 0.9, 0.75), "cuts": 6, "cut_depth": (0.55, 0.85), "bumps": 0.12, "taper": 0.0},
    "slab": {"shape": (1.0, 0.75, 0.3), "cuts": 5, "cut_depth": (0.6, 0.9), "bumps": 0.06, "taper": 0.0},
    "shard": {"shape": (0.35, 0.3, 1.0), "cuts": 6, "cut_depth": (0.5, 0.8), "bumps": 0.05, "taper": 0.6},
}


def _vec3(value, what):
    try:
        co = Vector([float(c) for c in value])
    except (TypeError, ValueError) as exc:
        raise ForgeError(f"{what} must be three numbers, got {value!r}") from exc
    if len(co) != 3 or not all(math.isfinite(c) for c in co):
        raise ForgeError(f"{what} must be three finite numbers, got {value!r}")
    return co


def _summary(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    manifold = bool(bm.edges) and all(e.is_manifold for e in bm.edges) and all(v.is_manifold for v in bm.verts)
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    bm.free()
    lo = [min(v.co[k] for v in obj.data.vertices) for k in range(3)] if obj.data.vertices else [0.0] * 3
    hi = [max(v.co[k] for v in obj.data.vertices) for k in range(3)] if obj.data.vertices else [0.0] * 3
    return {"object": obj.name, "verts": len(obj.data.vertices), "faces": len(obj.data.polygons), "tris": tris,
            "manifold": manifold, "bbox_min": [round(c, 6) for c in lo], "bbox_max": [round(c, 6) for c in hi]}


def skin_from_skeleton(spec, name="Blockout", subdivisions=1):
    """Skin a joint graph into a closed tube mesh. spec: {"joints": {name: {"co": [x, y, z], "radius": r}},
    "bones": [[a, b], ...]} in metres. Builds vertices + edges, sets the Skin modifier radius per joint (one root per
    connected part), bakes the Skin modifier, then bakes a Subdivision Surface modifier at `subdivisions` levels (0
    skips it). Returns ok(object, verts, faces, tris, manifold, bbox_min, bbox_max, parts)."""
    if not isinstance(spec, dict):
        raise ForgeError("spec must be a dict with 'joints' and 'bones'")
    joints, bones = spec.get("joints"), spec.get("bones")
    if not isinstance(joints, dict) or not joints:
        raise ForgeError("spec['joints'] must be a non-empty {name: {'co': [x, y, z], 'radius': r}} dict")
    if not isinstance(bones, (list, tuple)) or not bones:
        raise ForgeError("spec['bones'] must be a non-empty list of [joint_a, joint_b] pairs")
    if int(subdivisions) != subdivisions or not 0 <= subdivisions <= 4:
        raise ForgeError(f"subdivisions must be a whole number 0..4, got {subdivisions!r}")
    placed = {}
    for key, joint in joints.items():
        if not isinstance(joint, dict):
            raise ForgeError(f"joint {key!r} must be {{'co': [x, y, z], 'radius': r}}")
        placed[key] = (_vec3(joint.get("co"), f"joint {key!r} co"),
                       positive(joint.get("radius"), f"joint {key!r} radius"))
    pairs = set()
    for bone in bones:
        if not isinstance(bone, (list, tuple)) or len(bone) != 2 or bone[0] == bone[1]:
            raise ForgeError(f"bone {bone!r} must be a pair of two different joint names")
        for joint in bone:
            if joint not in joints:
                raise ForgeError(f"bone {list(bone)} names unknown joint {joint!r}")
        if frozenset(bone) in pairs:
            raise ForgeError(f"bone {list(bone)} is listed twice")
        pairs.add(frozenset(bone))
    unused = sorted(set(joints) - {j for pair in pairs for j in pair})
    if unused:
        raise ForgeError(f"joints {unused} are in no bone; the Skin modifier ignores loose joints")
    bm = bmesh.new()
    skin = bm.verts.layers.skin.verify()
    verts = {}
    for key, (co, r) in placed.items():
        verts[key] = bm.verts.new(co)
        verts[key][skin].radius = (r, r)
    for a, b in bones:
        bm.edges.new((verts[a], verts[b]))
    roots, reached = 0, set()
    for v in bm.verts:
        if v in reached:
            continue
        v[skin].use_root = True
        roots += 1
        reached.add(v)
        stack = [v]
        while stack:
            current = stack.pop()
            for edge in current.link_edges:
                other = edge.other_vert(current)
                if other not in reached:
                    reached.add(other)
                    stack.append(other)
    obj = new_mesh_object(name, bm)
    bm.free()
    bake_modifier(obj, "SKIN")
    if subdivisions:
        bake_modifier(obj, "SUBSURF", levels=int(subdivisions))
    return ok(**_summary(obj), parts=roots)


def metaball_blob(spec, name="Blob", resolution=0.1):
    """Fuse metaball elements into one mesh. spec: [{"co": [x, y, z], "radius": r, "type": "BALL"}, ...]; type is
    optional (BALL), checked against the element enum at run time. radius is the element's influence radius: a lone
    BALL's surface lands at about 0.575 * radius (threshold 0.6, stiffness 2). resolution: polygonisation cell size,
    metres. The temporary metaball is removed. Returns ok(object, verts, faces, tris, manifold, bbox_min, bbox_max)."""
    if not isinstance(spec, (list, tuple)) or not spec:
        raise ForgeError("spec must be a non-empty list of {'co': [x, y, z], 'radius': r, 'type': ...} elements")
    resolution = positive(resolution, "resolution")
    temp = f"forgemball{uuid.uuid4().hex}"
    data = bpy.data.metaballs.new(temp)
    ball = None
    try:
        data.resolution = resolution
        for i, element in enumerate(spec):
            if not isinstance(element, dict):
                raise ForgeError(f"element {i} must be a dict, got {element!r}")
            item = data.elements.new()
            kind = element.get("type", "BALL")
            if settable_enum(item, "type", [kind]) is None:
                choices = [e.identifier for e in item.bl_rna.properties["type"].enum_items]
                raise ForgeError(f"element {i} type {kind!r} is not one of {choices}")
            item.type = kind
            item.co = _vec3(element.get("co"), f"element {i} co")
            item.radius = positive(element.get("radius"), f"element {i} radius")
        ball = bpy.data.objects.new(temp, data)
        bpy.context.scene.collection.objects.link(ball)
        depsgraph = bpy.context.evaluated_depsgraph_get()
        mesh = bpy.data.meshes.new_from_object(ball.evaluated_get(depsgraph))
    finally:
        if ball is not None:
            bpy.data.objects.remove(ball)
        bpy.data.metaballs.remove(data)
    if not mesh.polygons:
        bpy.data.meshes.remove(mesh)
        raise ForgeError("the metaball produced no surface; are the radii larger than the resolution?",
                         stage="metaball")
    mesh.name = name
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return ok(**_summary(obj))


def rock(seed=0, size=1.0, style="boulder", name="SM_Rock"):
    """A procedural rock: a noise-bumped, stretched icosphere cut by random planes (capped and triangulated).
    style: boulder (rounded), slab (flat, wide) or shard (tall, tapered). size: metres along the longest axis. The
    origin is the bottom centre. Deterministic: the same seed and style give identical vertex positions. Returns
    ok(object, seed, style, verts, faces, tris, manifold, bbox_min, bbox_max)."""
    if style not in ROCK_STYLES:
        raise ForgeError(f"style {style!r} is not one of {sorted(ROCK_STYLES)}")
    size = positive(size, "size")
    params = ROCK_STYLES[style]
    rng = random.Random(seed)
    stretch = [axis * rng.uniform(0.85, 1.15) for axis in params["shape"]]
    shift = Vector([rng.uniform(-100.0, 100.0) for _ in range(3)])
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    for v in bm.verts:
        direction = v.co.normalized()
        co = direction * (1.0 + params["bumps"] * noise.fractal(direction * 1.5 + shift, 1.0, 2.0, 3))
        taper = 1.0 - params["taper"] * (co.z + 1.0) / 2.0
        v.co = Vector((co.x * stretch[0] * taper, co.y * stretch[1] * taper, co.z * stretch[2]))
    for _ in range(params["cuts"]):
        normal = Vector([rng.gauss(0.0, 1.0) for _ in range(3)]).normalized()
        reach = max(v.co.dot(normal) for v in bm.verts)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                               plane_co=normal * reach * rng.uniform(*params["cut_depth"]), plane_no=normal,
                               clear_outer=True)
        caps = bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)["faces"]
        bmesh.ops.triangulate(bm, faces=caps)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    lo = Vector([min(v.co[k] for v in bm.verts) for k in range(3)])
    hi = Vector([max(v.co[k] for v in bm.verts) for k in range(3)])
    factor = size / max(hi - lo)
    bottom = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in bm.verts:
        v.co = (v.co - bottom) * factor
    obj = new_mesh_object(name, bm)
    bm.free()
    return ok(**_summary(obj), seed=seed, style=style)


def _profile_point(p, i):
    try:
        values = [float(c) for c in p]
    except (TypeError, ValueError) as exc:
        raise ForgeError(f"profile point {i} must be (x, z) or (x, y, z), got {p!r}") from exc
    if len(values) not in (2, 3):
        raise ForgeError(f"profile point {i} must be (x, z) or (x, y, z), got {p!r}")
    x, z = values[0], values[-1]
    if x < 0:
        raise ForgeError(f"profile point {i} has x = {x} < 0; the profile is a radius and must be >= 0")
    return x, z


def lathe(profile_points, segments=16, name="Lathe"):
    """Revolve a profile in the XZ plane about the Z axis. profile_points: (x, z) pairs, or (x, y, z) with y ignored;
    x is the radius in metres and must be >= 0. An end point with x = 0 becomes a single pole vertex, so a profile
    whose ends both touch the axis gives a closed solid; only the ends may touch it. Returns ok(object, verts, faces,
    tris, manifold, closed, volume, bbox_min, bbox_max); volume (cubic metres) is None unless closed."""
    if int(segments) != segments or segments < 3:
        raise ForgeError(f"segments must be a whole number >= 3, got {segments!r}")
    if not isinstance(profile_points, (list, tuple)) or len(profile_points) < 2:
        raise ForgeError("profile_points needs at least 2 points")
    profile = [_profile_point(p, i) for i, p in enumerate(profile_points)]
    on_axis = [x <= 1e-9 for x, _ in profile]
    if any(on_axis[1:-1]):
        raise ForgeError("only the first and last profile points may lie on the axis (x = 0)")
    for i in range(len(profile) - 1):
        if profile[i] == profile[i + 1]:
            raise ForgeError(f"profile points {i} and {i + 1} are the same point")
    if len(profile) == 2 and all(on_axis):
        raise ForgeError("a profile lying on the axis revolves to nothing")
    segments = int(segments)
    angles = [2.0 * math.pi * k / segments for k in range(segments)]
    bm = bmesh.new()
    rings = [[bm.verts.new((0.0, 0.0, z))] if pole else
             [bm.verts.new((x * math.cos(a), x * math.sin(a), z)) for a in angles]
             for (x, z), pole in zip(profile, on_axis)]
    for ring, nxt in zip(rings, rings[1:]):
        for k in range(segments):
            k1 = (k + 1) % segments
            if len(ring) == 1:
                bm.faces.new((ring[0], nxt[k], nxt[k1]))
            elif len(nxt) == 1:
                bm.faces.new((ring[k], ring[k1], nxt[0]))
            else:
                bm.faces.new((ring[k], ring[k1], nxt[k1], nxt[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    closed = on_axis[0] and on_axis[-1]
    volume = bm.calc_volume() if closed else None
    obj = new_mesh_object(name, bm)
    bm.free()
    return ok(**_summary(obj), closed=closed, volume=volume)


def loft(cross_sections, name="Loft", closed=True):
    """Skin quads between consecutive cross-sections, each a list of [x, y, z] points (metres) of the same length.
    closed=True treats every section as a loop (its last point joins its first) and needs 3+ points per section;
    False treats sections as open strips. The first and last sections are not capped. Returns ok(object, verts, faces,
    tris, manifold, bbox_min, bbox_max)."""
    if not isinstance(cross_sections, (list, tuple)) or len(cross_sections) < 2:
        raise ForgeError("cross_sections needs at least 2 sections")
    sections = [[_vec3(p, f"section {i} point {j}") for j, p in enumerate(section)]
                for i, section in enumerate(cross_sections)]
    count = len(sections[0])
    if any(len(s) != count for s in sections):
        raise ForgeError(f"every section needs the same number of points; got {[len(s) for s in sections]}")
    if count < (3 if closed else 2):
        raise ForgeError(f"{'closed' if closed else 'open'} sections need at least {3 if closed else 2} points")
    bm = bmesh.new()
    rows = [[bm.verts.new(p) for p in section] for section in sections]
    span = count if closed else count - 1
    for row, nxt in zip(rows, rows[1:]):
        for k in range(span):
            k1 = (k + 1) % count
            bm.faces.new((row[k], row[k1], nxt[k1], nxt[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    obj = new_mesh_object(name, bm)
    bm.free()
    return ok(**_summary(obj))
