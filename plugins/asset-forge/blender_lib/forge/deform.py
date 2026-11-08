"""Sculpt-like edits by vertex math on a mesh object's base data (no sculpt mode, no modifiers), live or in
`blender -b`.

Centres, radii, offsets, depths and returned displacements are WORLD-space metres; results are written back into the
object's local coordinates. Every op returns ok(verts_moved=int, max_displacement=float metres).

Falloff kernels, with t = distance / radius; the weight is 0 wherever t >= 1:
    smooth    1 - (3t^2 - 2t^3)    smoothstep; 0.5 at t = 0.5
    sphere    sqrt(1 - t^2)
    sharp     (1 - t)^2
    linear    1 - t
    constant  1
symmetry "X" / "Y" / "Z" mirrors the edit across the object's local YZ / XZ / XY plane: each vertex takes the edit from
its own side (the original on the centre's side, the mirrored one on the other, their mean on the plane), so an edit
at the plane moves vertices as far as without symmetry, and a symmetric mesh stays symmetric. mask names a vertex group
whose weights multiply the effect; vertices outside the group do not move."""
import random

import bpy
import numpy as np
from mathutils import Vector, noise

from .util import ForgeError, ensure_object_mode, get_object, ok, positive

FALLOFFS = {
    "smooth": lambda t: 1.0 - t * t * (3.0 - 2.0 * t),
    "sphere": lambda t: np.sqrt(np.clip(1.0 - t * t, 0.0, None)),
    "sharp": lambda t: (1.0 - t) ** 2,
    "linear": lambda t: 1.0 - t,
    "constant": lambda t: np.ones_like(t),
}
SYMMETRY_AXES = {"X": 0, "Y": 1, "Z": 2}
MAX_DABS = 1000


class _Mesh:
    """A mesh object's vertex positions as numpy arrays, local and world, with the transform both ways."""

    def __init__(self, obj, mask=None):
        self.obj = get_object(obj, "MESH")
        ensure_object_mode()
        self.mesh = self.obj.data
        if self.mesh.shape_keys is not None:
            raise ForgeError(f"{self.obj.name} has shape keys; deform edits the base mesh, which they would override")
        if self.mesh.users > 1:
            raise ForgeError(f"{self.obj.name}'s mesh is shared by {self.mesh.users} users; make it single-user first")
        n = len(self.mesh.vertices)
        if n == 0:
            raise ForgeError(f"{self.obj.name} has no vertices")
        co = np.empty(n * 3)
        self.mesh.vertices.foreach_get("co", co)
        self.local = co.reshape(n, 3)
        bpy.context.view_layer.update()
        matrix = np.array(self.obj.matrix_world)
        self.lin, self.trans = matrix[:3, :3], matrix[:3, 3]
        if abs(np.linalg.det(self.lin)) < 1e-12:
            raise ForgeError(f"{self.obj.name} has a zero scale on some axis")
        self.inv = np.linalg.inv(self.lin)
        self.world = self.local @ self.lin.T + self.trans
        self.mask = self._mask_weights(mask)
        self._normals = None

    def _mask_weights(self, mask):
        if mask is None:
            return np.ones(len(self.local))
        group = self.obj.vertex_groups.get(mask)
        if group is None:
            raise ForgeError(f"{self.obj.name} has no vertex group {mask!r}")
        weights = np.zeros(len(self.local))
        for v in self.mesh.vertices:
            for g in v.groups:
                if g.group == group.index:
                    weights[v.index] = g.weight
        return weights

    @property
    def normals(self):
        """Unit vertex normals in world space."""
        if self._normals is None:
            n = np.empty(len(self.local) * 3)
            self.mesh.vertex_normals.foreach_get("vector", n)
            world = n.reshape(-1, 3) @ self.inv
            length = np.linalg.norm(world, axis=1, keepdims=True)
            self._normals = np.divide(world, length, out=np.zeros_like(world), where=length > 0)
        return self._normals

    def mirror_point(self, p, axis):
        local = self.inv @ (np.asarray(p, float) - self.trans)
        local[axis] = -local[axis]
        return self.lin @ local + self.trans

    def mirror_vector(self, v, axis):
        local = self.inv @ np.asarray(v, float)
        local[axis] = -local[axis]
        return self.lin @ local

    def mirror_normal(self, n, axis):
        local = self.lin.T @ np.asarray(n, float)
        local[axis] = -local[axis]
        return self.inv.T @ local

    def commit(self, disp_world, masked=False):
        """Add a world-space displacement per vertex and write it to the mesh; masked=True means the mask is applied."""
        if not masked:
            disp_world = disp_world * self.mask[:, None]
        touched = np.any(disp_world != 0.0, axis=1)
        stored = self.local.astype(np.float32)
        if touched.any():
            self.local[touched] += disp_world[touched] @ self.inv.T
            self.mesh.vertices.foreach_set("co", self.local.ravel())
            self.mesh.update()
        moved = np.any(self.local.astype(np.float32) != stored, axis=1)
        length = np.linalg.norm(disp_world, axis=1)
        return ok(verts_moved=int(moved.sum()), max_displacement=float(length.max()))


def _vec3(value, what):
    try:
        arr = np.asarray(value, float).reshape(3)
    except (TypeError, ValueError) as exc:
        raise ForgeError(f"{what} must be three numbers, got {value!r}") from exc
    if not np.all(np.isfinite(arr)):
        raise ForgeError(f"{what} must be finite, got {value!r}")
    return arr


def _points(value, what, minimum=2):
    try:
        arr = np.asarray(value, float).reshape(-1, 3)
    except (TypeError, ValueError) as exc:
        raise ForgeError(f"{what} must be a list of [x, y, z] points") from exc
    if len(arr) < minimum:
        raise ForgeError(f"{what} needs at least {minimum} points, got {len(arr)}")
    if np.linalg.norm(np.diff(arr, axis=0), axis=1).sum() <= 0.0 and minimum > 1:
        raise ForgeError(f"{what} has zero length")
    return arr


def _check_shared(falloff, symmetry):
    if falloff not in FALLOFFS:
        raise ForgeError(f"falloff {falloff!r} is not one of {sorted(FALLOFFS)}")
    if symmetry is not None and symmetry not in SYMMETRY_AXES:
        raise ForgeError(f"symmetry {symmetry!r} is not None or one of {sorted(SYMMETRY_AXES)}")
    return SYMMETRY_AXES.get(symmetry)


def _kernel(distance, radius, falloff):
    t = distance / radius
    w = np.zeros_like(t)
    inside = t < 1.0
    w[inside] = FALLOFFS[falloff](t[inside])
    return w


def _point_weights(state, center, radius, falloff):
    return _kernel(np.linalg.norm(state.world - center, axis=1), radius, falloff)


def _mirrored(state, axis, value, kind):
    if kind == "point":
        return state.mirror_point(value, axis)
    if kind == "vector":
        return state.mirror_vector(value, axis)
    if kind == "normal":
        return None if value is None else state.mirror_normal(value, axis)
    if kind == "points":
        return np.array([state.mirror_point(p, axis) for p in value])
    return None if value is None else (state.mirror_point(value[0], axis), state.mirror_normal(value[1], axis))


def _symmetric(state, axis, anchor, field, *args):
    """field(*values), or with symmetry one field per vertex: field on the values for vertices on world point
    `anchor`'s side of the local plane, field on the mirrored values on the other side, their mean on the plane.
    Each arg is (value, kind), kind one of point / vector / normal / points / plane."""
    direct = field(*(value for value, _ in args))
    if axis is None:
        return direct
    mirrored = field(*(_mirrored(state, axis, value, kind) for value, kind in args))
    side = 1.0 if (state.inv @ (np.asarray(anchor, float) - state.trans))[axis] >= 0 else -1.0
    offset = state.local[:, axis] * side
    tolerance = 1e-6 * float(np.abs(state.local).max())
    own = (offset > tolerance)[:, None]
    other = (offset < -tolerance)[:, None]
    return np.where(own, direct, np.where(other, mirrored, 0.5 * (direct + mirrored)))


def grab(obj, center, radius, offset, falloff="smooth", symmetry=None, mask=None):
    """Move vertices within `radius` metres of world `center` by world `offset` (metres) scaled by the falloff.
    Returns ok(verts_moved, max_displacement)."""
    axis = _check_shared(falloff, symmetry)
    center, offset, radius = _vec3(center, "center"), _vec3(offset, "offset"), positive(radius, "radius")
    state = _Mesh(obj, mask)

    def field(c, off):
        return _point_weights(state, c, radius, falloff)[:, None] * off

    return state.commit(_symmetric(state, axis, center, field, (center, "point"), (offset, "vector")))


def inflate(obj, center, radius, amount, falloff="smooth", symmetry=None, mask=None):
    """Push vertices within `radius` metres of world `center` along their normals by `amount` metres (negative
    deflates) scaled by the falloff. Returns ok(verts_moved, max_displacement)."""
    axis = _check_shared(falloff, symmetry)
    center, radius = _vec3(center, "center"), positive(radius, "radius")
    state = _Mesh(obj, mask)

    def field(c):
        return (_point_weights(state, c, radius, falloff) * float(amount))[:, None] * state.normals

    return state.commit(_symmetric(state, axis, center, field, (center, "point")))


def pinch(obj, center, radius, strength, falloff="smooth", symmetry=None, mask=None):
    """Pull vertices within `radius` metres of world `center` toward it along the surface (the part of the pull along
    the vertex normal is dropped). strength in [-1, 1]: the fraction of the tangential distance covered at full
    weight; negative pushes away. Returns ok(verts_moved, max_displacement)."""
    axis = _check_shared(falloff, symmetry)
    center, radius = _vec3(center, "center"), positive(radius, "radius")
    if not -1.0 <= strength <= 1.0:
        raise ForgeError(f"strength must be in [-1, 1], got {strength!r}")
    state = _Mesh(obj, mask)

    def field(c):
        pull = c - state.world
        n = state.normals
        tangent = pull - np.sum(pull * n, axis=1)[:, None] * n
        return (_point_weights(state, c, radius, falloff) * float(strength))[:, None] * tangent

    return state.commit(_symmetric(state, axis, center, field, (center, "point")))


def flatten(obj, center, radius, plane=None, strength=1.0, falloff="smooth", symmetry=None, mask=None):
    """Move vertices within `radius` metres of world `center` toward a plane by `strength` (0..1) of their distance,
    scaled by the falloff. plane: (point, normal) in world space; None fits it to the affected vertices (weighted mean
    position, weighted mean normal). Returns ok(verts_moved, max_displacement)."""
    axis = _check_shared(falloff, symmetry)
    center, radius = _vec3(center, "center"), positive(radius, "radius")
    if not 0.0 <= strength <= 1.0:
        raise ForgeError(f"strength must be in [0, 1], got {strength!r}")
    if plane is not None:
        normal = _vec3(plane[1], "plane normal")
        if np.linalg.norm(normal) == 0:
            raise ForgeError("plane normal has zero length")
        plane = (_vec3(plane[0], "plane point"), normal / np.linalg.norm(normal))
    state = _Mesh(obj, mask)

    def field(c, pl):
        w = _point_weights(state, c, radius, falloff)
        if w.sum() == 0:
            return np.zeros_like(state.world)
        if pl is None:
            co = (state.world * w[:, None]).sum(axis=0) / w.sum()
            no = (state.normals * w[:, None]).sum(axis=0)
            if np.linalg.norm(no) == 0:
                return np.zeros_like(state.world)
            pl = (co, no)
        co, no = pl[0], pl[1] / np.linalg.norm(pl[1])
        height = (state.world - co) @ no
        return -(w * float(strength) * height)[:, None] * no

    return state.commit(_symmetric(state, axis, center, field, (center, "point"), (plane, "plane")))


def _polyline(points, world):
    """Per vertex: distance (metres) to the polyline and the arc-length fraction 0..1 of the nearest point on it."""
    best = np.full(len(world), np.inf)
    arc = np.zeros(len(world))
    seg = np.diff(points, axis=0)
    seg_len = np.linalg.norm(seg, axis=1)
    start = np.concatenate([[0.0], np.cumsum(seg_len)])
    for i, (a, d, length) in enumerate(zip(points[:-1], seg, seg_len)):
        u = np.clip((world - a) @ d / (length * length), 0.0, 1.0) if length > 0 else np.zeros(len(world))
        dist = np.linalg.norm(world - (a + u[:, None] * d), axis=1)
        closer = dist < best
        best[closer] = dist[closer]
        arc[closer] = start[i] + u[closer] * length
    return best, arc / start[-1]


def _profile(values, s, what):
    values = np.asarray(values, float).ravel()
    if values.size == 0:
        raise ForgeError(f"{what} is empty")
    return np.interp(s, np.linspace(0.0, 1.0, values.size), values) if values.size > 1 else np.full_like(s, values[0])


def crease_along_curve(obj, curve_points, width, depth, sharpness=2.0, falloff="smooth", symmetry=None, mask=None):
    """Cut a groove along a world-space polyline: vertices within `width` metres of it move inward along their normals
    by `depth` metres (negative raises a ridge) times falloff(t) ** sharpness, t = distance / width. Higher sharpness
    narrows the V. Returns ok(verts_moved, max_displacement)."""
    axis = _check_shared(falloff, symmetry)
    points = _points(curve_points, "curve_points")
    width, sharpness = positive(width, "width"), positive(sharpness, "sharpness")
    state = _Mesh(obj, mask)

    def field(pts):
        dist, _ = _polyline(pts, state.world)
        w = _kernel(dist, width, falloff) ** sharpness
        return -(w * float(depth))[:, None] * state.normals

    return state.commit(_symmetric(state, axis, points.mean(axis=0), field, (points, "points")))


def bulge_along_curve(obj, curve_points, radius_profile, amount, falloff="smooth", symmetry=None, mask=None):
    """Raise a ridge along a world-space polyline (muscles, veins, roots): vertices move along their normals by `amount`
    metres times falloff(distance / R), where R (metres) is `radius_profile` interpolated by arc length (its values are
    spaced evenly from the first point to the last). Returns ok(verts_moved, max_displacement)."""
    axis = _check_shared(falloff, symmetry)
    points = _points(curve_points, "curve_points")
    radii = np.asarray(radius_profile, float).ravel()
    if radii.size == 0 or np.any(radii <= 0):
        raise ForgeError(f"radius_profile must be one or more radii > 0, got {radius_profile!r}")
    state = _Mesh(obj, mask)

    def field(pts):
        dist, s = _polyline(pts, state.world)
        w = _kernel(dist, _profile(radii, s, "radius_profile"), falloff)
        return (w * float(amount))[:, None] * state.normals

    return state.commit(_symmetric(state, axis, points.mean(axis=0), field, (points, "points")))


def smooth(obj, iterations=1, factor=0.5, mask=None):
    """Laplacian smoothing over edge neighbours: each pass moves a vertex `factor` (0..1] of the way to the mean of its
    neighbours. Vertices without edges stay. Returns ok(verts_moved, max_displacement) with displacement in metres."""
    if int(iterations) != iterations or iterations < 1:
        raise ForgeError(f"iterations must be a whole number >= 1, got {iterations!r}")
    if not 0.0 < factor <= 1.0:
        raise ForgeError(f"factor must be in (0, 1], got {factor!r}")
    state = _Mesh(obj, mask)
    edges = np.empty(len(state.mesh.edges) * 2, dtype=np.int64)
    state.mesh.edges.foreach_get("vertices", edges)
    a, b = edges[0::2], edges[1::2]
    degree = np.bincount(np.concatenate([a, b]), minlength=len(state.local)).astype(float)
    has = degree > 0
    start = state.local.copy()
    co = state.local.copy()
    for _ in range(int(iterations)):
        total = np.zeros_like(co)
        np.add.at(total, a, co[b])
        np.add.at(total, b, co[a])
        step = np.zeros_like(co)
        step[has] = (total[has] / degree[has, None] - co[has]) * (factor * state.mask[has])[:, None]
        co = co + step
    return state.commit((co - start) @ state.lin.T, masked=True)


def noise_displace(obj, scale, strength, octaves=3, seed=0, mask=None):
    """Displace every vertex along its normal by fractal Perlin noise (mathutils.noise.fractal) sampled at its world
    position. scale: feature size in metres; strength: metres at a noise value of 1 (the sum is normalised by its
    octave weights, so values stay near [-1, 1]). Same seed, same result. Returns ok(verts_moved, max_displacement)."""
    scale = positive(scale, "scale")
    if int(octaves) != octaves or octaves < 1:
        raise ForgeError(f"octaves must be a whole number >= 1, got {octaves!r}")
    state = _Mesh(obj, mask)
    rng = random.Random(seed)
    shift = Vector([rng.uniform(-1000.0, 1000.0) for _ in range(3)])
    h, lacunarity = 1.0, 2.0
    norm = sum(lacunarity ** (-h * i) for i in range(int(octaves)))
    values = np.array([noise.fractal(Vector(p / scale) + shift, h, lacunarity, int(octaves)) for p in state.world])
    return state.commit((values * float(strength) / norm)[:, None] * state.normals)


STROKE_OPS = {"grab": (grab, "offset"), "inflate": (inflate, "amount"), "pinch": (pinch, "strength"),
              "flatten": (flatten, "strength")}
STROKE_LIMITS = {"pinch": (-1.0, 1.0), "flatten": (0.0, 1.0)}


def stroke(obj, path_points, op, radius_profile, strength_profile, spacing=None, **op_kwargs):
    """Apply op ("grab", "inflate", "pinch" or "flatten") as dabs every `spacing` metres along a world-space path,
    like a sculpt stroke. radius_profile (metres) and strength_profile are interpolated by arc length; the strength
    value becomes inflate's amount (metres), pinch's or flatten's strength, or scales grab's `offset` (pass offset in
    op_kwargs). spacing None: a quarter of the smallest radius. Dabs accumulate, so a tighter spacing gives a stronger
    stroke; more than MAX_DABS dabs is refused. Other op_kwargs (falloff, symmetry, mask, plane) pass through. Returns
    ok(verts_moved, max_displacement, dabs) measured over the whole stroke."""
    if op not in STROKE_OPS:
        raise ForgeError(f"op {op!r} is not one of {sorted(STROKE_OPS)}")
    fn, strength_key = STROKE_OPS[op]
    for key in {"center", "radius"} | ({strength_key} if op != "grab" else set()):
        if key in op_kwargs:
            raise ForgeError(f"stroke sets {key!r} per dab; do not pass it")
    if op == "grab" and "offset" not in op_kwargs:
        raise ForgeError("a grab stroke needs offset=[x, y, z] in op_kwargs")
    points = _points(path_points, "path_points", minimum=1)
    radii = np.asarray(radius_profile, float).ravel()
    if radii.size == 0 or np.any(radii <= 0):
        raise ForgeError(f"radius_profile must be one or more radii > 0, got {radius_profile!r}")
    strengths = np.asarray(strength_profile, float).ravel()
    if strengths.size == 0:
        raise ForgeError("strength_profile is empty")
    low, high = STROKE_LIMITS.get(op, (-np.inf, np.inf))
    if strengths.min() < low or strengths.max() > high:
        raise ForgeError(f"{op} strength_profile values must be in [{low}, {high}]")
    spacing = positive(spacing, "spacing") if spacing is not None else 0.25 * float(radii.min())
    seg_len = np.linalg.norm(np.diff(points, axis=0), axis=1)
    start = np.concatenate([[0.0], np.cumsum(seg_len)])
    total = start[-1]
    n_dabs = int(np.floor(total / spacing)) + 1 if total > 0 else 1
    if n_dabs > MAX_DABS:
        raise ForgeError(f"a {total:.3g} m path at {spacing:.3g} m spacing needs {n_dabs} dabs (limit {MAX_DABS}); "
                         f"pass a larger spacing or radius")
    distances = np.linspace(0.0, total, n_dabs) if n_dabs > 1 else np.zeros(1)
    s = distances / total if total > 0 else distances
    centers = np.stack([np.interp(distances, start, points[:, k]) for k in range(3)], axis=1)
    before = _Mesh(obj)
    offset = _vec3(op_kwargs.pop("offset"), "offset") if op == "grab" else None
    for c, r, value in zip(centers, _profile(radii, s, "radius_profile"), _profile(strengths, s, "strength_profile")):
        if op == "grab":
            fn(obj, c, r, offset * value, **op_kwargs)
        else:
            fn(obj, c, r, **{strength_key: float(value)}, **op_kwargs)
    after = np.empty(len(before.local) * 3)
    before.mesh.vertices.foreach_get("co", after)
    delta = np.linalg.norm((after.reshape(-1, 3) - before.local) @ before.lin.T, axis=1)
    return ok(verts_moved=int((delta > 0).sum()), max_displacement=float(delta.max()), dabs=n_dabs)


def experimental_brush_stroke(obj, path_points, pressure=1.0, mode="NORMAL"):
    """EXPERIMENTAL: run the active sculpt brush along a world-space path with a real sculpt-mode stroke
    (bpy.ops.sculpt.brush_stroke) in the first visible 3D View, then give the active object back its mode from before
    the call. mode: the operator's stroke mode ("NORMAL" or "INVERT", checked against the operator at run time).
    Needs a UI: raises ForgeError(stage="headless") under `blender -b`; use stroke() there.
    Returns ok(verts_moved, max_displacement)."""
    if bpy.app.background:
        raise ForgeError("sculpt brush strokes need a 3D View; use deform.stroke() under blender -b", stage="headless")
    from bpy_extras import view3d_utils

    points = _points(path_points, "path_points", minimum=1)
    modes = {i.identifier for i in bpy.ops.sculpt.brush_stroke.get_rna_type().properties["mode"].enum_items}
    if mode not in modes:
        raise ForgeError(f"mode {mode!r} is not one of {sorted(modes)}")
    view = next(((w, a) for w in bpy.context.window_manager.windows for a in w.screen.areas if a.type == "VIEW_3D"),
                None)
    if view is None:
        raise ForgeError("no 3D View is open", stage="headless")
    window, area = view
    region = next(r for r in area.regions if r.type == "WINDOW")
    rv3d = area.spaces.active.region_3d
    view_layer = bpy.context.view_layer
    previous_active = view_layer.objects.active
    previous_mode = previous_active.mode if previous_active is not None else "OBJECT"
    state = _Mesh(obj)
    try:
        elements = []
        for i, p in enumerate(points):
            xy = view3d_utils.location_3d_to_region_2d(region, rv3d, Vector(p))
            if xy is None:
                raise ForgeError(f"path point {list(p)} is behind the view")
            elements.append({"name": "", "location": tuple(p), "mouse": tuple(xy), "mouse_event": tuple(xy),
                             "pressure": float(pressure), "x_tilt": 0.0, "y_tilt": 0.0, "time": float(i),
                             "is_start": i == 0})
        view_layer.objects.active = state.obj
        with bpy.context.temp_override(window=window, area=area, region=region, object=state.obj,
                                       active_object=state.obj):
            bpy.ops.object.mode_set(mode="SCULPT")
            try:
                bpy.ops.sculpt.brush_stroke(stroke=elements, mode=mode)
            finally:
                bpy.ops.object.mode_set(mode="OBJECT")
        after = np.empty(len(state.local) * 3)
        state.mesh.vertices.foreach_get("co", after)
        delta = np.linalg.norm((after.reshape(-1, 3) - state.local) @ state.lin.T, axis=1)
    finally:
        view_layer.objects.active = previous_active
        if previous_active is not None and previous_mode != "OBJECT":
            with bpy.context.temp_override(window=window, area=area, region=region, object=previous_active,
                                           active_object=previous_active):
                bpy.ops.object.mode_set(mode=previous_mode)
    return ok(verts_moved=int((delta > 0).sum()), max_displacement=float(delta.max()))
