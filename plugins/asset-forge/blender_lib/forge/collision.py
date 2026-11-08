"""Collision meshes for game engines: an oriented box, a convex hull, or an approximate convex decomposition, named
per the engine preset. Built in the render mesh's object space from its evaluated mesh; volumes are object-space
cubic units (m³ when the object is unscaled)."""
import bmesh
import bpy
import numpy as np
from mathutils import Matrix

from .naming import format_name, pattern_regex
from .util import ForgeError, evaluated_bmesh, get_object, load_preset, ok

# PhysX (Unity, UE4) caps a convex mesh at 255 vertices and faces: https://nvidia-omniverse.github.io/PhysX/physx/5.4.1/docs/Geometry.html
HULL_VERT_CAP = 255
HULL_FACE_CAP = 255
KINDS = ("box", "convex", "multi")
FIT_TOLERANCE = 0.1
# dissolve_limit merges hull faces up to 1e-3 rad apart (its float32 cosine cannot go finer), which can bend a face
PLANAR_EPS = 1e-6


def _hull(points):
    """(bmesh, volume) of the convex hull of an (N, 3) array. Caller frees the bmesh."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    out = bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
    junk = {g for g in out["geom_interior"] + out["geom_unused"] if isinstance(g, bmesh.types.BMVert)}
    bmesh.ops.delete(bm, geom=list(junk), context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=1e-3, verts=bm.verts[:], edges=bm.edges[:], delimit=set())
    bm.normal_update()
    eps = PLANAR_EPS * max((max(c) - min(c) for c in zip(*(v.co for v in bm.verts))), default=0.0)
    bent = [f for f in bm.faces if len(f.verts) > 3
            and max(abs((v.co - f.verts[0].co).dot(f.normal)) for v in f.verts) > eps]
    if bent:
        bmesh.ops.triangulate(bm, faces=bent)
    return bm, bm.calc_volume(signed=False) if bm.faces else 0.0


def _hull_volume(points):
    bm, volume = _hull(points)
    bm.free()
    return volume


def _farthest_points(points, count):
    """Greedy farthest-point subset: keeps the spread of the cloud with `count` of its points."""
    chosen = [int(np.argmax(np.linalg.norm(points - points.mean(axis=0), axis=1)))]
    dist = np.linalg.norm(points - points[chosen[0]], axis=1)
    while len(chosen) < count:
        nxt = int(np.argmax(dist))
        chosen.append(nxt)
        dist = np.minimum(dist, np.linalg.norm(points - points[nxt], axis=1))
    return points[chosen]


def _capped_hull(points, vert_cap, face_cap):
    """Hull of points with at most vert_cap vertices and face_cap faces (None: no limit). Returns (bmesh, volume,
    uncapped vertex count or None)."""
    bm, volume = _hull(points)
    before = len(bm.verts)
    if (not vert_cap or before <= vert_cap) and (not face_cap or len(bm.faces) <= face_cap):
        return bm, volume, None
    hull_points = np.array([v.co[:] for v in bm.verts])
    bm.free()
    # Euler's formula: a convex hull of V points has at most 2V - 4 faces.
    keep = min(vert_cap or before, (face_cap + 4) // 2 if face_cap else before)
    bm, volume = _hull(_farthest_points(hull_points, keep))
    return bm, volume, before


def _mesh_arrays(obj):
    """Evaluated mesh in object space: points (N, 3), edges (E, 2), loose-part label per point, closed volume or None."""
    bm = evaluated_bmesh(obj)
    points = np.array([v.co[:] for v in bm.verts], dtype=np.float64).reshape(-1, 3)
    bm.verts.index_update()
    edges = np.array([(e.verts[0].index, e.verts[1].index) for e in bm.edges], dtype=np.int64).reshape(-1, 2)
    closed = bool(bm.faces) and all(len(e.link_faces) == 2 for e in bm.edges)
    volume = None
    if closed:
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        volume = bm.calc_volume(signed=False)
    bm.free()
    parent = list(range(len(points)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for a, b in edges:
        parent[find(a)] = find(b)
    labels = np.array([find(i) for i in range(len(points))], dtype=np.int64)
    return points, edges, labels, volume


def _slab(points, edges, axis, a, b, eps):
    """Points of the mesh surface between planes axis=a and axis=b: vertices inside, edge crossings of both planes,
    and vertices on a plane only when one of their edges leads into the slab (a wall lying on the plane belongs to
    the solid on its other side)."""
    coord = points[:, axis]
    keep = (coord > a + eps) & (coord < b - eps)
    c0, c1 = coord[edges[:, 0]], coord[edges[:, 1]]
    for plane, inward in ((a, 1.0), (b, -1.0)):
        on = np.abs(coord - plane) <= eps
        keep[edges[on[edges[:, 0]] & (inward * (c1 - plane) > eps), 0]] = True
        keep[edges[on[edges[:, 1]] & (inward * (c0 - plane) > eps), 1]] = True
    parts = [points[keep]]
    p0, p1 = points[edges[:, 0]], points[edges[:, 1]]
    for plane in (a, b):
        d0, d1 = c0 - plane, c1 - plane
        cross = (np.abs(d0) > eps) & (np.abs(d1) > eps) & (d0 * d1 < 0)
        t = (d0[cross] / (d0[cross] - d1[cross]))[:, None]
        parts.append(p0[cross] + (p1[cross] - p0[cross]) * t)
    return np.vstack(parts)


def _slices(points, edges, mesh_volume, max_hulls):
    """Fewest equal slabs (along the best axis) whose hulls fit the mesh volume within FIT_TOLERANCE, else max_hulls.
    Returns (list of point arrays, axis index)."""
    lo, hi = points.min(axis=0), points.max(axis=0)
    eps = 1e-6 * float((hi - lo).max())
    best = None
    for n in range(2, max_hulls + 1):
        best = None
        for axis in range(3):
            if hi[axis] - lo[axis] <= eps:
                continue
            cuts = np.linspace(lo[axis], hi[axis], n + 1)
            pieces = [_slab(points, edges, axis, cuts[i], cuts[i + 1], eps) for i in range(n)]
            pieces = [p for p in pieces if len(p) >= 4]
            total = sum(_hull_volume(p) for p in pieces)
            if best is None or total < best[0]:
                best = (total, pieces, axis)
        if mesh_volume is not None and best[0] <= mesh_volume * (1 + FIT_TOLERANCE):
            break
    return best[1], best[2]


def make_collision(obj, kind="convex", engine="unity", max_hulls=8, max_hull_verts=HULL_VERT_CAP, parent=True,
                   max_hull_faces=HULL_FACE_CAP):
    """Build collision for a render mesh from its evaluated geometry, in its object space.
    kind: 'box' (object-space bounding box), 'convex' (one hull) or 'multi' (one hull per loose part, else the fewest
    equal axis slabs up to max_hulls whose hulls fit the mesh volume within 10%). A hull over max_hull_verts vertices
    or max_hull_faces faces is rebuilt from fewer spread-out hull points so it fits both (None: no cap). Names follow
    the engine preset's naming.collision[kind]; parent=True parents to the render mesh, False places them beside it
    with its transform. No material, wire display; re-running replaces this kind's objects. Returns per-hull vertex
    and face counts and volumes."""
    obj = get_object(obj, "MESH")
    if kind not in KINDS:
        raise ForgeError(f"kind must be one of {KINDS}, got {kind!r}")
    if max_hulls < 1:
        raise ForgeError("max_hulls must be >= 1")
    if max_hull_verts is not None and max_hull_verts < 4:
        raise ForgeError("max_hull_verts must be >= 4 or None")
    if max_hull_faces is not None and max_hull_faces < 4:
        raise ForgeError("max_hull_faces must be >= 4 or None")
    preset = load_preset("engines", engine)
    pattern = preset["naming"].get("collision", {}).get(kind)
    if pattern is None:
        raise ForgeError(f"the {engine} preset names no {kind!r} collision")
    points, edges, labels, mesh_volume = _mesh_arrays(obj)
    if len(points) < 4:
        raise ForgeError(f"{obj.name} has too few vertices for a collision shape")
    method = kind
    if kind == "box":
        lo, hi = points.min(axis=0), points.max(axis=0)
        pieces = [np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])]
    elif kind == "convex":
        pieces = [points]
    else:
        parts = np.unique(labels)
        if len(parts) > 1:
            if len(parts) > max_hulls:
                raise ForgeError(f"{obj.name} has {len(parts)} loose parts, more than max_hulls={max_hulls}: raise "
                                 "max_hulls or use kind='convex'")
            pieces, method = [points[labels == p] for p in parts], "loose_parts"
        elif mesh_volume is not None and _hull_volume(points) <= mesh_volume * (1 + FIT_TOLERANCE):
            pieces, method = [points], "single_hull_fits"
        elif max_hulls == 1:
            pieces, method = [points], "single_hull"
        else:
            pieces, axis = _slices(points, edges, mesh_volume, max_hulls)
            method = f"slices_{'XYZ'[axis]}"
    if len(pieces) > 1 and "{nn}" not in pattern:
        raise ForgeError(f"the {engine} preset's {kind!r} collision name {pattern!r} has no {{nn}} for several hulls")
    caps = (None, None) if kind == "box" else (max_hull_verts, max_hull_faces)
    built = [_capped_hull(piece, *caps) for piece in pieces]
    if any(volume <= 1e-12 for _, volume, _ in built):
        for bm, _, _ in built:
            bm.free()
        raise ForgeError(f"{obj.name}'s {kind} collision would be flat (zero volume)")
    stale = pattern_regex(pattern, name=obj.name)
    removed = []
    for other in [o for o in bpy.data.objects if stale.fullmatch(o.name)]:
        data = other.data
        removed.append(other.name)
        bpy.data.objects.remove(other)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)
    hulls = []
    for i, (bm, volume, capped_from) in enumerate(built, start=1):
        name = format_name(pattern, obj.name, i)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        col = bpy.data.objects.new(name, mesh)
        for collection in obj.users_collection:
            collection.objects.link(col)
        if parent:
            col.parent = obj
            col.matrix_parent_inverse = Matrix.Identity(4)
        else:
            col.matrix_world = obj.matrix_world.copy()
        col.display_type = "WIRE"
        hulls.append({"name": col.name, "verts": len(mesh.vertices), "faces": len(mesh.polygons),
                      "volume": round(volume, 6), "capped_from": capped_from})
    return ok(object=obj.name, kind=kind, engine=engine, method=method, hulls=hulls,
              total_volume=round(sum(h["volume"] for h in hulls), 6),
              mesh_volume=None if mesh_volume is None else round(mesh_volume, 6),
              parented=bool(parent), removed=removed, engine_note=preset.get("collision_import"))
