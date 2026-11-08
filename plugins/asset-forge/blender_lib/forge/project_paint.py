"""Tier-2 support for AI texturing, with no provider calls: view cameras, guide renders (normal, depth, AO) to
condition an image generator, and projection of the generated views back onto the mesh's own UVs.
Distances are metres; resolutions are pixels per side."""
import math
import time
from contextlib import ExitStack
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

from . import bake
from .util import ForgeError, get_object, link_to_scene, ok, world_bbox

VIEWS = {"front": ((0, 1, 0), (0, 0, 1)), "back": ((0, -1, 0), (0, 0, 1)), "left": ((1, 0, 0), (0, 0, 1)),
         "right": ((-1, 0, 0), (0, 0, 1)), "top": ((0, 0, -1), (0, 1, 0)), "bottom": ((0, 0, 1), (0, -1, 0))}
GUIDES = ("normal", "depth", "ao")
MIN_FACING = 0.1
NOTES = [
    "seams: views meet where their facing ratios cross; seam_blend widens the cross-fade but cannot reconcile views "
    "that disagree",
    "view inconsistency: each generated view is independent, so colour and detail can differ across a seam; "
    "generate all views from the same guides, prompt and seed",
    "occlusion is a point-splat depth test at reduced resolution: parts thinner than one cell can leak colour",
    "texels no view saw (undersides, deep cavities) take the nearest seen texel in UV space, which may belong to "
    "another island",
    "lighting and shadows painted into the generated images are baked in",
]


def setup_views(obj, views=("front", "back", "left", "right", "top"), resolution=1024):
    """Create or update one orthographic camera per view, framing `obj` (object or name) with a 10% margin.
    Views follow Blender's viewpoints: front looks along +Y at the -Y side, right looks along -X, top looks down.
    Cameras are named `forge_view_<obj>_<view>` and carry `forge_resolution` (px) for render_guides.
    Returns the camera names and each camera's ortho scale (metres)."""
    obj = get_object(obj, "MESH")
    views = list(dict.fromkeys([views] if isinstance(views, str) else views))
    unknown = [v for v in views if v not in VIEWS]
    if not views or unknown:
        raise ForgeError(f"unknown views {unknown or views}; choose from {list(VIEWS)}")
    if int(resolution) < 1:
        raise ForgeError("resolution must be >= 1")
    lo, hi = world_bbox(obj)
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2
    if radius < 1e-6:
        raise ForgeError(f"{obj.name} has no extent to frame")
    corners = [Vector((x, y, z)) - centre for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    distance = 3.0 * radius
    names, scales = [], {}
    for view in views:
        forward, up = Vector(VIEWS[view][0]), Vector(VIEWS[view][1])
        back = -forward
        right = up.cross(back)
        extent = max(max(abs(c.dot(right)), abs(c.dot(up))) for c in corners) * 2
        name = f"forge_view_{obj.name}_{view}"
        cam = bpy.data.objects.get(name)
        if cam is not None and cam.type != "CAMERA":
            raise ForgeError(f"{name} exists and is a {cam.type}, not a camera")
        if cam is None:
            cam = link_to_scene(bpy.data.objects.new(name, bpy.data.cameras.new(name)))
        elif cam.name not in bpy.context.scene.objects:
            link_to_scene(cam)
        bake._enum(cam.data, "type", "ORTHO")
        cam.data.ortho_scale = 1.1 * extent
        cam.data.clip_start = max(distance - 1.5 * radius, 1e-3)
        cam.data.clip_end = distance + 1.5 * radius
        basis = Matrix((right, up, back)).transposed().to_4x4()
        basis.translation = centre - forward * distance
        cam.matrix_world = basis
        cam["forge_resolution"] = int(resolution)
        cam["forge_view"] = view
        cam["forge_target"] = obj.name
        names.append(cam.name)
        scales[cam.name] = round(cam.data.ortho_scale, 4)
    return ok(object=obj.name, cameras=names, resolution=int(resolution), ortho_scale_m=scales)


def _guide_material(diag):
    mat = bpy.data.materials.new("forge_guides")
    nt = mat.node_tree
    for n in [n for n in nt.nodes if n.type != "OUTPUT_MATERIAL"]:
        nt.nodes.remove(n)
    out = nt.get_output_node("CYCLES") or bake._node(nt, "ShaderNodeOutputMaterial")
    emission = bake._node(nt, "ShaderNodeEmission", {"Strength": 1.0})
    nt.links.new(emission.outputs["Emission"], out.inputs["Surface"])
    node = bake._node
    geo = node(nt, "ShaderNodeNewGeometry")
    in_camera = node(nt, "ShaderNodeVectorTransform", {"Vector": geo.outputs["Normal"]}, vector_type="NORMAL",
                     convert_from="WORLD", convert_to="CAMERA")
    # Cycles camera space looks down +Z; flipping Z gives the usual guide convention (facing the camera = blue).
    normal = node(nt, "ShaderNodeVectorMath", {"Vector": in_camera.outputs["Vector"], "Vector_001": (0.5, 0.5, -0.5),
                                               "Vector_002": (0.5, 0.5, 0.5)}, operation="MULTIPLY_ADD")
    depth = node(nt, "ShaderNodeMapRange", {"Value": node(nt, "ShaderNodeCameraData").outputs["View Z Depth"],
                                            "To Min": 1.0, "To Max": 0.0})
    ao = node(nt, "ShaderNodeAmbientOcclusion", {"Distance": 0.2 * diag}, only_local=True, samples=16)
    sockets = {"normal": normal.outputs["Vector"], "depth": depth.outputs["Result"], "ao": ao.outputs["AO"]}
    return mat, emission, depth, sockets


def render_guides(obj, out_dir, cameras):
    """Render normal, depth and AO guides of `obj` alone from each camera into `<out_dir>/<obj>_<view>_<guide>.png`
    (RGBA, transparent background, `forge_resolution` px square, else 1024). normal: camera-space, facing the camera
    = (0.5, 0.5, 1). depth: 1 at the object's nearest bbox depth, 0 at its farthest. ao: AO of the object alone,
    distance 0.2 x bbox diagonal. Other objects are hidden for the render; every setting is restored.
    Returns {camera: {guide: path}}, each camera's depth range (metres), seconds."""
    obj = get_object(obj, "MESH")
    cams = [get_object(c, "CAMERA") for c in ([cameras] if isinstance(cameras, str) else cameras)]
    if not cams:
        raise ForgeError("no cameras given; run setup_views first")
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    lo, hi = world_bbox(obj)
    diag = max((hi - lo).length, 1e-6)
    corners = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    scene = bpy.context.scene
    render = scene.render
    settings = render.image_settings
    view = scene.view_settings
    guides, depth_range = {}, {}
    start = time.perf_counter()
    with ExitStack() as stack:
        stack.enter_context(bake._cycles_session(scene, 4))
        stack.enter_context(bake._temp_attrs(scene.cycles, use_denoising=False))
        stack.enter_context(bake._temp_attrs(
            render, film_transparent=True, resolution_percentage=100, use_border=False, pixel_aspect_x=1.0,
            pixel_aspect_y=1.0, use_compositing=False, use_sequencer=False, filepath=render.filepath,
            resolution_x=render.resolution_x, resolution_y=render.resolution_y))
        image_enums = {"media_type": ("IMAGE",)} if hasattr(settings, "media_type") else {}
        image_enums.update(file_format=("PNG",), color_mode=("RGBA",), color_depth=("8",))
        if hasattr(settings, "color_management"):
            image_enums["color_management"] = ("FOLLOW_SCENE",)
        stack.enter_context(bake._temp_enums(settings, **image_enums))
        stack.enter_context(bake._temp_enums(view, view_transform=("Raw", "Standard"), look=("None",)))
        stack.enter_context(bake._temp_attrs(view, exposure=0.0, gamma=1.0, use_curve_mapping=False))
        stack.enter_context(bake._temp_attrs(scene, camera=scene.camera))
        hidden = [o for o in scene.objects if o is not obj and not o.hide_render]
        for o in hidden:
            o.hide_render = True
        stack.callback(lambda: [setattr(o, "hide_render", False) for o in hidden])
        stack.enter_context(bake._temp_attrs(obj, hide_render=False))
        mat, emission, depth_node, sockets = _guide_material(diag)
        stack.callback(bpy.data.materials.remove, mat)
        stack.enter_context(bake._temp_attrs(bpy.context.view_layer, material_override=mat))
        nt = mat.node_tree
        for cam in cams:
            res = int(cam.get("forge_resolution", 1024))
            render.resolution_x = render.resolution_y = res
            scene.camera = cam
            to_cam = cam.matrix_world.inverted()
            depths = [-(to_cam @ c).z for c in corners]
            near, far = min(depths), max(depths)
            depth_node.inputs["From Min"].default_value = near
            depth_node.inputs["From Max"].default_value = far if far > near else near + 1e-6
            label = bake._safe(str(cam.get("forge_view", cam.name)))
            files = {}
            for guide in GUIDES:
                nt.links.new(sockets[guide], emission.inputs["Color"])
                scene.cycles.samples = 16 if guide == "ao" else 4
                path = out / f"{bake._safe(obj.name)}_{label}_{guide}.png"
                render.filepath = str(path)
                bpy.ops.render.render(write_still=True)
                files[guide] = str(path)
            guides[cam.name] = files
            depth_range[cam.name] = [round(near, 4), round(far, 4)]
    return ok(object=obj.name, guides=guides, depth_range_m=depth_range,
              seconds=round(time.perf_counter() - start, 3))


def _texel_geometry(obj, uv_name, resolution):
    """World position and normal per texel of the UV layout, and which texels the mesh covers."""
    scene = bpy.context.scene
    result = {}
    with ExitStack() as stack:
        stack.enter_context(bake._keep_selection())
        stack.enter_context(bake._cycles_session(scene, 1))
        mats = stack.enter_context(bake._slot_materials(obj))
        for key in ("Position", "Normal"):
            image = bake._new_image(f"forge_texel_{key}", resolution, data=True, fill=(0.0, 0.0, 0.0, 0.0),
                                    float_buffer=True, alpha=True)
            try:
                def build(nt, _index, key=key):
                    return bake._emission(nt, bake._node(nt, "ShaderNodeNewGeometry").outputs[key])
                with bake._surface(mats, build), bake._target_image(mats, image):
                    bake._bake(obj, "EMIT", uv_name, margin=0)
                result[key] = bake._pixels(image)
            finally:
                bpy.data.images.remove(image)
    covered = result["Position"][..., 3] > 0.5
    normals = result["Normal"][..., :3][covered]
    normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)
    return result["Position"][..., :3][covered], normals, covered


def _bilinear(img, x, y):
    h, w = img.shape[:2]
    x = np.clip(x, 0, w - 1)
    y = np.clip(y, 0, h - 1)
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    fx = (x - x0)[:, None]
    fy = (y - y0)[:, None]
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x1] * fx * (1 - fy)
            + img[y1, x0] * (1 - fx) * fy + img[y1, x1] * fx * fy)


def _project(cam, rgba, points, normals, diag):
    """Per texel: facing ratio toward `cam`, whether the camera sees it, and the image colour (RGBA) there."""
    h, w = rgba.shape[:2]
    depsgraph = bpy.context.evaluated_depsgraph_get()
    to_view = np.array(cam.matrix_world.inverted())
    to_clip = np.array(cam.calc_matrix_camera(depsgraph, x=w, y=h))
    in_view = np.c_[points, np.ones(len(points))] @ to_view.T
    clip = in_view @ to_clip.T
    wc = clip[:, 3]
    safe = np.where(np.abs(wc) > 1e-12, wc, 1e-12)
    u = clip[:, 0] / safe * 0.5 + 0.5
    v = clip[:, 1] / safe * 0.5 + 0.5
    depth = -in_view[:, 2]
    inside = (wc > 1e-12) & (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
    ortho = cam.data.type == "ORTHO"
    if ortho:
        toward = np.array(cam.matrix_world.col[2][:3])
        facing = normals @ (toward / np.linalg.norm(toward))
    else:
        toward = np.array(cam.matrix_world.translation) - points
        facing = (normals * toward).sum(1) / np.maximum(np.linalg.norm(toward, axis=1), 1e-9)
    visible = np.zeros(len(points), bool)
    if inside.any():
        cells = int(np.clip(math.sqrt(inside.sum() / 8.0), 8, max(w, h)))
        cell = (np.minimum((v[inside] * cells).astype(np.int64), cells - 1) * cells
                + np.minimum((u[inside] * cells).astype(np.int64), cells - 1))
        zbuf = np.full(cells * cells, np.inf)
        np.minimum.at(zbuf, cell, depth[inside])
        frame = cam.data.ortho_scale if ortho else 2 * float(np.median(depth[inside])) * math.tan(cam.data.angle / 2)
        visible[inside] = depth[inside] <= zbuf[cell] + 2.0 * frame / cells + 1e-4 * diag
    color = _bilinear(rgba, u * w - 0.5, v * h - 0.5)
    seen = inside & visible & (facing > MIN_FACING) & (color[:, 3] > 0.01)
    return facing, seen, color


def _nearest_fill(rgb, known):
    """Every texel takes the colour of its nearest known texel (jump flooding, log2(size) passes)."""
    h, w = known.shape
    ys, xs = np.indices((h, w))
    sy = np.where(known, ys, -1)
    sx = np.where(known, xs, -1)
    step = 1 << max(0, (max(h, w) - 1).bit_length() - 1)
    while step >= 1:
        for dy in (-step, 0, step):
            for dx in (-step, 0, step):
                if not dy and not dx:
                    continue
                cy = np.full_like(sy, -1)
                cx = np.full_like(sx, -1)
                dst = (slice(max(0, -dy), h - max(0, dy)), slice(max(0, -dx), w - max(0, dx)))
                src = (slice(max(0, dy), h - max(0, -dy)), slice(max(0, dx), w - max(0, -dx)))
                cy[dst] = sy[src]
                cx[dst] = sx[src]
                old = np.where(sy >= 0, (ys - sy) ** 2 + (xs - sx) ** 2, np.iinfo(np.int64).max)
                better = (cy >= 0) & ((ys - cy) ** 2 + (xs - cx) ** 2 < old)
                sy = np.where(better, cy, sy)
                sx = np.where(better, cx, sx)
        step //= 2
    return rgb[sy, sx]


def _load_rgba(path):
    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        return bake._pixels(image).astype(np.float64)
    finally:
        bpy.data.images.remove(image)


def project_and_bake(obj, view_images, out_dir, resolution=1024, seam_blend=0.2):
    """Project each view image from its camera onto `obj` (object or name) and bake the blend into its own UVs as
    `<out_dir>/<obj>_projected.png` (`resolution` px square, RGBA, alpha 1).

    view_images: {camera name: png path}, cameras as setup_views made them (any camera works). Per texel, each view
    whose camera sees it (in frame, facing ratio above MIN_FACING, i.e. under ~84 degrees, not occluded, image
    alpha > 0) weighs facing * exp((facing - best) / seam_blend): 0 takes only the best-facing view, 0.2
    cross-fades views whose facing ratios are within about 0.2.
    Texels no view sees, and the gutter, take the nearest seen texel's colour. Blending happens in the images' own
    encoding (sRGB PNGs stay sRGB). Returns the path, texel counts (covered, seen, filled), texels each view won,
    and `notes` on limitations."""
    obj = get_object(obj, "MESH")
    if not isinstance(view_images, dict) or not view_images:
        raise ForgeError("view_images must be a non-empty {camera name: png path} dict")
    views = []
    for cam_name, path in view_images.items():
        cam = get_object(cam_name, "CAMERA")
        if not Path(path).is_file():
            raise ForgeError(f"view image for {cam.name} not found: {path}")
        views.append((cam, Path(path)))
    if int(resolution) < 1 or seam_blend < 0:
        raise ForgeError("resolution must be >= 1 and seam_blend >= 0")
    resolution = int(resolution)
    uv_name = bake._render_uv(obj)
    bake._texel_size(obj, uv_name, resolution)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    start = time.perf_counter()
    points, normals, covered = _texel_geometry(obj, uv_name, resolution)
    lo, hi = world_bbox(obj)
    diag = max((hi - lo).length, 1e-6)
    facing, seen, colors = [], [], []
    for cam, path in views:
        f, s, c = _project(cam, _load_rgba(path), points, normals, diag)
        facing.append(f)
        seen.append(s)
        colors.append(c[:, :3])
    facing, seen, colors = np.array(facing), np.array(seen), np.array(colors)
    best = np.where(seen, facing, 0.0).max(axis=0)
    weight = np.where(seen, facing * np.exp(np.minimum(facing - best, 0.0) / max(seam_blend, 1e-4)), 0.0)
    total = weight.sum(axis=0)
    hit = total > 1e-9
    if not hit.any():
        raise ForgeError(f"no view sees {obj.name}; check that the cameras frame it", stage="project")
    blended = (weight[..., None] * colors).sum(axis=0) / np.maximum(total, 1e-9)[:, None]
    rgb = np.zeros((resolution, resolution, 3))
    known = np.zeros((resolution, resolution), bool)
    rows, cols = np.nonzero(covered)
    rgb[rows[hit], cols[hit]] = blended[hit]
    known[rows[hit], cols[hit]] = True
    filled = _nearest_fill(rgb, known)
    pixels = np.concatenate([filled, np.ones((resolution, resolution, 1))], axis=2).astype(np.float32)
    path = out / f"{bake._safe(obj.name)}_projected.png"
    image = bpy.data.images.new("forge_projected", resolution, resolution, alpha=True)
    try:
        image.pixels.foreach_set(pixels.ravel())
        bake._save_png(image, path)
    finally:
        bpy.data.images.remove(image)
    winner = np.where(hit, weight.argmax(axis=0), -1)
    return ok(object=obj.name, path=str(path), resolution=resolution, seam_blend=seam_blend,
              texels_covered=int(covered.sum()), texels_seen=int(hit.sum()), texels_filled=int((~hit).sum()),
              view_texels={cam.name: int((winner == i).sum()) for i, (cam, _) in enumerate(views)},
              seconds=round(time.perf_counter() - start, 3), notes=NOTES)


def prepare_views(obj, out_dir, views=("front", "back", "left", "right", "top"), resolution=1024):
    """setup_views then render_guides in one call, for a headless job that saves the cameras with a copy of the file.
    Returns the cameras, {camera: {guide: path}} and the depth ranges (metres)."""
    cams = setup_views(obj, views=views, resolution=resolution)
    guides = render_guides(obj, out_dir, cams["cameras"])
    return ok(object=cams["object"], cameras=cams["cameras"], resolution=cams["resolution"],
              guides=guides["guides"], depth_range_m=guides["depth_range_m"])
