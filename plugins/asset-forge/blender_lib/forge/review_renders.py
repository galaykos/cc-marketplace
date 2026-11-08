"""Review renders for one asset: turntable, silhouette, game distance, wireframe, UV checker and matcap, tiled into a
contact sheet. Everything renders in a temporary scene deleted before returning, so the user's scenes and render
settings stay as they were. Units: metres, degrees, pixels."""
import math
import re
import time
from pathlib import Path

import bpy
import numpy as np
from mathutils import Euler, Vector

from . import util

KINDS = ("beauty", "silhouette", "game_distance", "wireframe", "uv_checker", "matcap")
SILHOUETTE_VIEWS = (("front", 0.0), ("side", 90.0), ("three_quarter", 45.0))
DETAIL_VIEWS = (("three_quarter", 45.0), ("back_three_quarter", 225.0))
VIEW_ELEVATION_DEG = 20.0
GAME_ELEVATION_DEG = 30.0
GAME_AZIMUTH_DEG = 45.0
FRAMING_FOV_DEG = 40.0
MARGIN = 1.15
MIN_GAME_PX = 8
EEVEE_SAMPLES = 16
WIRE_PX = 2.0
GAP_PX = 4
WORLD_GREY = 0.18
# (azimuth offset from the camera, elevation, sun strength in W/m^2) for key, fill and rim
LIGHT_RIG = ((-45.0, 45.0, 4.0), (60.0, 15.0, 1.5), (180.0, 50.0, 3.0))
MATCAP_PREFERENCE = ("clay_studio.exr", "basic_grey.exr", "basic_1.exr")


def render_review_set(obj, out_dir, angles=8, include=KINDS, game_camera=None, tile_px=512):
    """Render the review set of a mesh object into out_dir as PNGs and tile them into out_dir/contact_sheet.png.

    angles: turntable views spaced evenly around Z. tile_px: edge of every square tile, in pixels.
    game_camera (metres, degrees, pixels): {"type": "perspective", "distance_m", "fov_deg" (vertical),
    "screen_height_px"} or {"type": "ortho", "ortho_height_m", "screen_height_px"}; both take optional
    "elevation_deg" (default 30, 90 is top-down) and "azimuth_deg" (default 45). Without it game_distance is skipped.
    Returns images {kind: [paths]}, contact_sheet (path), layout ([kind, view] per tile, row-major, `columns` wide),
    notes, seconds, and game_distance {screen_px_height, render_px, raw} when that view was rendered."""
    started = time.monotonic()
    obj = util.get_object(obj, "MESH")
    kinds = _check_args(obj, include, angles, tile_px)
    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector(map(min, *corners))
    hi = Vector(map(max, *corners))
    centre = (lo + hi) / 2
    radius = max((c - centre).length for c in corners)
    if radius < 1e-6:
        raise util.ForgeError(f"{obj.name} has no extent to frame")
    notes = []
    game = None
    if "game_distance" in kinds:
        if game_camera is None:
            kinds.remove("game_distance")
            notes.append("game_distance skipped: no game_camera given")
        else:
            game = _game_spec(game_camera, radius, notes)
    out = Path(out_dir).resolve()
    out.mkdir(parents=True, exist_ok=True)
    render_results = {i.name for i in bpy.data.images if i.type == "RENDER_RESULT"}
    stage = _Stage(obj, centre, radius, tile_px)
    images, tiles, extra = {}, [], {}
    try:
        stage.build()
        for kind in kinds:
            skipped = stage.prepare(kind)
            if skipped:
                notes.append(skipped)
                continue
            if kind == "game_distance":
                path, extra["game_distance"] = _game_distance(stage, game, corners, out, notes)
                shots = [("game_camera", path)]
            else:
                if kind == "beauty":
                    views = [(f"az{round(360.0 * i / angles):03d}", 360.0 * i / angles) for i in range(angles)]
                else:
                    views = SILHOUETTE_VIEWS if kind == "silhouette" else DETAIL_VIEWS
                elevation = 0.0 if kind == "silhouette" else VIEW_ELEVATION_DEG
                shots = []
                for view, azimuth in views:
                    stage.frame(azimuth, elevation)
                    shots.append((view, stage.render(out / f"{kind}_{view}.png")))
            images[kind] = [p for _, p in shots]
            tiles += [(kind, view, p) for view, p in shots]
        if not tiles:
            raise util.ForgeError("nothing rendered: " + "; ".join(notes), stage="render")
        sheet = out / "contact_sheet.png"
        columns = _contact_sheet([p for _, _, p in tiles], tile_px, sheet)
    finally:
        stage.remove()
        for image in [i for i in bpy.data.images if i.type == "RENDER_RESULT" and i.name not in render_results]:
            bpy.data.images.remove(image)
    return util.ok(object=obj.name, images=images, contact_sheet=str(sheet), layout=[[k, v] for k, v, _ in tiles],
                   columns=columns, notes=notes, seconds=round(time.monotonic() - started, 2), **extra)


def _check_args(obj, include, angles, tile_px):
    include = [include] if isinstance(include, str) else list(include)
    unknown = sorted(set(include) - set(KINDS))
    if unknown:
        raise util.ForgeError(f"unknown review kinds {unknown}; known: {list(KINDS)}")
    kinds = [k for k in KINDS if k in include]
    if not kinds:
        raise util.ForgeError(f"include names no review kind; known: {list(KINDS)}")
    if not isinstance(angles, int) or not 1 <= angles <= 72:
        raise util.ForgeError(f"angles must be an integer from 1 to 72, got {angles!r}")
    if not isinstance(tile_px, int) or not 64 <= tile_px <= 4096:
        raise util.ForgeError(f"tile_px must be an integer from 64 to 4096, got {tile_px!r}")
    if obj.hide_render:
        raise util.ForgeError(f"{obj.name} is hidden from render (hide_render); nothing would show")
    return kinds


def _game_spec(game_camera, radius, notes):
    if not isinstance(game_camera, dict):
        raise util.ForgeError(f"game_camera must be a dict, got {type(game_camera).__name__}")
    required = {"perspective": ("distance_m", "fov_deg", "screen_height_px"),
                "ortho": ("ortho_height_m", "screen_height_px")}.get(game_camera.get("type"))
    if required is None:
        raise util.ForgeError(f"game_camera type {game_camera.get('type')!r}; expected 'perspective' or 'ortho'")
    bad = [k for k in required if not isinstance(game_camera.get(k), (int, float)) or game_camera[k] <= 0]
    if bad:
        raise util.ForgeError(f"game_camera needs positive numbers for {bad}")
    spec = dict(game_camera)
    if spec["type"] == "perspective":
        if spec["fov_deg"] >= 180:
            raise util.ForgeError(f"game_camera fov_deg must be under 180, got {spec['fov_deg']}")
        if spec["distance_m"] <= radius:
            raise util.ForgeError(f"game camera at {spec['distance_m']} m is inside the object's bounding sphere "
                                  f"({radius:.3f} m)")
    defaulted = [k for k in ("elevation_deg", "azimuth_deg") if k not in spec]
    spec.setdefault("elevation_deg", GAME_ELEVATION_DEG)
    spec.setdefault("azimuth_deg", GAME_AZIMUTH_DEG)
    if defaulted:
        notes.append(f"game_camera has no {' or '.join(defaulted)}; used elevation {spec['elevation_deg']}°, "
                     f"azimuth {spec['azimuth_deg']}°")
    return spec


def _game_distance(stage, game, corners, out, notes):
    azimuth, elevation = game["azimuth_deg"], game["elevation_deg"]
    if game["type"] == "perspective":
        distance = game["distance_m"]
        focal_px = game["screen_height_px"] / 2 / math.tan(math.radians(game["fov_deg"]) / 2)
    else:
        distance = stage.radius * 3
        px_per_m = game["screen_height_px"] / game["ortho_height_m"]
    location = stage.centre + _direction(azimuth, elevation) * distance
    inverse = _view_rotation(azimuth, elevation).to_quaternion().inverted()
    xs, ys = [], []
    for corner in corners:
        p = inverse @ (corner - location)
        scale = focal_px / -p.z if game["type"] == "perspective" else px_per_m
        xs.append(p.x * scale)
        ys.append(p.y * scale)
    frame_px = 2 * max(map(abs, xs + ys)) * MARGIN
    size = max(MIN_GAME_PX, math.ceil(frame_px))
    if size > stage.tile_px:
        notes.append(f"game_distance: the object spans ~{round(frame_px)} px on screen, more than the "
                     f"{stage.tile_px} px tile; the tile is downscaled, so it shows no detail loss")
        size, frame = stage.tile_px, frame_px
    else:
        frame = size
    if game["type"] == "perspective":
        stage.aim(azimuth, elevation, distance, angle=2 * math.atan(frame / 2 / focal_px))
    else:
        stage.aim(azimuth, elevation, distance, ortho_scale=frame / px_per_m)
    raw = stage.render(out / "game_distance_raw.png", size=size)
    path = out / "game_distance_game_camera.png"
    _write_png(_nearest(_read_png(raw), stage.tile_px), path)
    return str(path), {"screen_px_height": round(max(ys) - min(ys), 1), "render_px": size, "raw": raw}


def _direction(azimuth_deg, elevation_deg):
    """Unit vector from the target toward a viewer; azimuth 0 looks from -Y (front), 90 from +X (side)."""
    az, el = math.radians(azimuth_deg), math.radians(elevation_deg)
    return Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))


def _view_rotation(azimuth_deg, elevation_deg):
    """Rotation pointing a camera's (or sun's) -Z from _direction() back at the target, with its up toward the
    azimuth even when looking straight down, where a track-to rotation has no defined roll."""
    return Euler((math.radians(90.0 - elevation_deg), 0.0, math.radians(azimuth_deg)))


def _set_enum(owner, prop, *wanted):
    ident = util.settable_enum(owner, prop, wanted)
    if ident is None:
        raise util.ForgeError(f"{owner.bl_rna.identifier}.{prop} accepts none of {list(wanted)}", stage="render")
    setattr(owner, prop, ident)
    return ident


def _engine_ids(render):
    ids = [item.identifier for item in render.bl_rna.properties["engine"].enum_items]
    ids += [cls.bl_idname for cls in bpy.types.RenderEngine.__subclasses__() if getattr(cls, "bl_idname", "")]
    # The static enum omits built-in engines such as Workbench; the refusal message lists the live set.
    try:
        render.engine = "__forge_probe__"
    except TypeError as exc:
        ids += re.findall(r"'([A-Z0-9_]+)'", str(exc))
    return list(dict.fromkeys(ids))


class _Stage:
    """The temporary scene: the object (plus its armature parent), a camera, a three-sun rig and a world.
    remove() deletes every datablock it made, newest first."""

    def __init__(self, obj, centre, radius, tile_px):
        self.obj, self.centre, self.radius, self.tile_px = obj, centre, radius, tile_px
        self.made = []
        self.wire = None
        self.distance = radius * MARGIN / math.sin(math.radians(FRAMING_FOV_DEG) / 2)

    def _keep(self, collection, datablock):
        self.made.append((collection, datablock))
        return datablock

    def _object(self, name, data, collection):
        obj = self._keep(bpy.data.objects, bpy.data.objects.new(name, data))
        collection.objects.link(obj)
        return obj

    def _collection(self, name):
        collection = self._keep(bpy.data.collections, bpy.data.collections.new(name))
        self.scene.collection.children.link(collection)
        return collection

    def build(self):
        scene = self.scene = self._keep(bpy.data.scenes, bpy.data.scenes.new("forge_review"))
        render = scene.render
        render.resolution_x = render.resolution_y = self.tile_px
        render.resolution_percentage = 100
        render.dither_intensity = 0.0
        render.film_transparent = False
        _set_enum(render.image_settings, "file_format", "PNG")
        _set_enum(render.image_settings, "color_mode", "RGB")
        engines = _engine_ids(render)
        self.eevee = util.settable_enum(render, "engine", [e for e in engines if "EEVEE" in e])
        self.workbench = util.settable_enum(render, "engine", [e for e in engines if "WORKBENCH" in e])
        self.default_view = scene.view_settings.view_transform
        self.flat_view = util.settable_enum(scene.view_settings, "view_transform", ["Standard"])
        world = self.world = scene.world = self._keep(bpy.data.worlds, bpy.data.worlds.new("forge_review"))
        nodes = world.node_tree.nodes if world.node_tree else ()
        background = next((n for n in nodes if n.type == "BACKGROUND"), None)
        if background is not None:
            background.inputs["Color"].default_value = (WORLD_GREY, WORLD_GREY, WORLD_GREY, 1.0)
            background.inputs["Strength"].default_value = 1.0
        self.subject = self._collection("forge_review_subject")
        self.subject.objects.link(self.obj)
        if self.obj.parent is not None and self.obj.parent.type == "ARMATURE":
            self.subject.objects.link(self.obj.parent)
        camera = bpy.data.cameras.new("forge_review_camera")
        scene.camera = self._object(camera.name, self._keep(bpy.data.cameras, camera), scene.collection)
        self.lights = []
        for i, (_, _, strength) in enumerate(LIGHT_RIG):
            light = self._keep(bpy.data.lights, bpy.data.lights.new(f"forge_review_light{i}", "SUN"))
            light.energy = strength
            self.lights.append(self._object(light.name, light, scene.collection))

    def remove(self):
        for collection, datablock in reversed(self.made):
            collection.remove(datablock)
        self.made.clear()

    def prepare(self, kind):
        """Set engine, shading, world and visibility for one kind; return a reason string when it cannot render."""
        scene = self.scene
        scene.view_layers[0].material_override = None
        self.subject.hide_render = kind == "wireframe"
        if self.wire is not None:
            self.wire.hide_render = kind != "wireframe"
        if kind in ("beauty", "game_distance", "uv_checker"):
            if self.eevee is None:
                raise util.ForgeError("no EEVEE-family render engine is settable in this Blender", stage="render")
            scene.render.engine = self.eevee
            scene.view_settings.view_transform = self.default_view
            if hasattr(scene.eevee, "taa_render_samples"):
                scene.eevee.taa_render_samples = EEVEE_SAMPLES
            if kind == "uv_checker":
                if not self.obj.data.uv_layers:
                    return "uv_checker skipped: the object has no UV map"
                scene.view_layers[0].material_override = self._checker()
            return None
        if self.workbench is None:
            raise util.ForgeError("no Workbench render engine is settable in this Blender", stage="render")
        scene.render.engine = self.workbench
        if self.flat_view:
            scene.view_settings.view_transform = self.flat_view
        shading = scene.display.shading
        shading.show_cavity = shading.show_shadows = shading.show_object_outline = False
        shading.show_specular_highlight = False
        if kind == "silhouette":
            _set_enum(shading, "light", "FLAT")
            _set_enum(shading, "color_type", "SINGLE")
            shading.single_color = (0.0, 0.0, 0.0)
            self.world.color = (1.0, 1.0, 1.0)
        elif kind == "matcap":
            _set_enum(shading, "light", "MATCAP")
            names = [s.name for s in bpy.context.preferences.studio_lights if s.type == "MATCAP"]
            pick = util.settable_enum(shading, "studio_light", [n for n in MATCAP_PREFERENCE if n in names] + names)
            if pick is None:
                return "matcap skipped: Blender lists no matcap studio light"
            shading.studio_light = pick
            _set_enum(shading, "color_type", "SINGLE")
            shading.single_color = (0.8, 0.8, 0.8)
            self.world.color = (0.3, 0.3, 0.3)
        else:
            _set_enum(shading, "light", "STUDIO")
            _set_enum(shading, "color_type", "OBJECT")
            self.world.color = (0.85, 0.85, 0.85)
            if self.wire is None:
                self._wire_copies()
        return None

    def _checker(self):
        image = self._keep(bpy.data.images, bpy.data.images.new("forge_review_checker", 1024, 1024))
        _set_enum(image, "generated_type", "COLOR_GRID", "UV_GRID")
        mat = self._keep(bpy.data.materials, bpy.data.materials.new("forge_review_checker"))
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            raise util.ForgeError("a new material has no Principled BSDF to carry the checker", stage="render")
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        return mat

    def _wire_copies(self):
        """A grey copy and a black Wireframe-modifier copy sharing the object's mesh: overlays do not render headless."""
        self.wire = self._collection("forge_review_wire")
        base = self._keep(bpy.data.objects, self.obj.copy())
        wire = self._keep(bpy.data.objects, self.obj.copy())
        base.color, wire.color = (0.55, 0.55, 0.55, 1.0), (0.0, 0.0, 0.0, 1.0)
        pixel_m = 2 * self.distance * math.tan(math.radians(FRAMING_FOV_DEG) / 2) / self.tile_px
        mean_scale = sum(map(abs, self.obj.matrix_world.to_scale())) / 3
        modifier = wire.modifiers.new("forge_review_wire", "WIREFRAME")
        modifier.thickness = WIRE_PX * pixel_m / max(mean_scale, 1e-9)
        modifier.offset = 1.0
        modifier.use_replace = True
        for copy in (base, wire):
            self.wire.objects.link(copy)

    def frame(self, azimuth, elevation):
        """Aim the camera at the bounding sphere from (azimuth, elevation) degrees; the light rig turns with it."""
        self.aim(azimuth, elevation, self.distance, angle=math.radians(FRAMING_FOV_DEG))

    def aim(self, azimuth, elevation, distance, angle=None, ortho_scale=None):
        camera = self.scene.camera
        camera.location = self.centre + _direction(azimuth, elevation) * distance
        camera.rotation_euler = _view_rotation(azimuth, elevation)
        if ortho_scale is None:
            _set_enum(camera.data, "type", "PERSP")
            camera.data.angle = angle
        else:
            _set_enum(camera.data, "type", "ORTHO")
            camera.data.ortho_scale = ortho_scale
        camera.data.clip_start = max(1e-4, (distance - self.radius) * 0.5)
        camera.data.clip_end = distance + self.radius * 2
        for light, (offset, light_elevation, _) in zip(self.lights, LIGHT_RIG):
            light.rotation_euler = _view_rotation(azimuth + offset, light_elevation)

    def render(self, path, size=None):
        render = self.scene.render
        render.resolution_x = render.resolution_y = size or self.tile_px
        render.filepath = str(path)
        path.unlink(missing_ok=True)
        result = bpy.ops.render.render(write_still=True, scene=self.scene.name)
        if "FINISHED" not in result or not path.is_file() or path.stat().st_size == 0:
            raise util.ForgeError(f"the render wrote nothing to {path} ({result})", stage="render")
        return str(path)


def _read_png(path):
    """Pixels of an image file as a float32 (height, width, 4) array, top row first."""
    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        width, height = image.size
        pixels = np.empty(width * height * 4, np.float32)
        image.pixels.foreach_get(pixels)
    finally:
        bpy.data.images.remove(image)
    return pixels.reshape(height, width, 4)[::-1]


def _write_png(pixels, path):
    """Write a (height, width, 4) top-row-first array as an RGB PNG, byte for byte (save_render would colour-manage)."""
    height, width = pixels.shape[:2]
    image = bpy.data.images.new("forge_review_write", width, height, alpha=False)
    try:
        image.pixels.foreach_set(np.ascontiguousarray(pixels[::-1], dtype=np.float32).ravel())
        image.filepath_raw = str(path)
        _set_enum(image, "file_format", "PNG")
        image.save()
    finally:
        bpy.data.images.remove(image)


def _nearest(pixels, size):
    rows = np.arange(size) * pixels.shape[0] // size
    cols = np.arange(size) * pixels.shape[1] // size
    return pixels[rows][:, cols]


def _contact_sheet(paths, tile_px, path):
    columns = math.ceil(math.sqrt(len(paths)))
    rows = math.ceil(len(paths) / columns)
    step = tile_px + GAP_PX
    sheet = np.full((rows * step - GAP_PX, columns * step - GAP_PX, 4), 0.1, np.float32)
    sheet[..., 3] = 1.0
    for i, tile in enumerate(paths):
        row, col = divmod(i, columns)
        pixels = _read_png(tile)
        if pixels.shape[:2] != (tile_px, tile_px):
            pixels = _nearest(pixels, tile_px)
        sheet[row * step:row * step + tile_px, col * step:col * step + tile_px] = pixels
    _write_png(sheet, path)
    return columns
