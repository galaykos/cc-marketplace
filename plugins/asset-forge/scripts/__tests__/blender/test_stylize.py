import colorsys
from pathlib import Path

import bpy
import numpy as np

import fixtures
from forge import bake, stylize, util
from test_bake import _band, _face_mask, _png, _tray


def _hue_gap(a, b):
    ha, hb = colorsys.rgb_to_hsv(*a)[0], colorsys.rgb_to_hsv(*b)[0]
    gap = abs(ha - hb) * 360
    return min(gap, 360 - gap)


def _chroma(rgb):
    rgb = np.asarray(rgb)
    return rgb / rgb.sum()


def test_crate_albedo_lit_top_hue_shifted_shadow_bright_edges(tmp):
    crate = fixtures.crate()
    out = stylize.stylize(crate, tmp, recipe="wood", resolution=256)
    assert out["baked_maps"] == ["ao", "curvature"] and all(Path(p).is_file() for p in out["maps"].values())
    albedo = _png(out["albedo"])[..., :3]
    polys = crate.data.polygons
    top = next(p for p in polys if p.normal.z > 0.9)
    bottom = next(p for p in polys if p.normal.z < -0.9)
    top_rgb = albedo[_face_mask(crate, top, 256, 0.4)].mean(0)
    bottom_rgb = albedo[_face_mask(crate, bottom, 256, 0.4)].mean(0)
    assert top_rgb.max() > 1.3 * bottom_rgb.max(), (top_rgb, bottom_rgb)
    assert _hue_gap(top_rgb, bottom_rgb) > 8, (top_rgb, bottom_rgb, _hue_gap(top_rgb, bottom_rgb))
    for side in [p for p in polys if abs(p.normal.z) < 0.1]:
        edge = albedo[_band(crate, side, 256, 0.1)].mean()
        centre = albedo[_face_mask(crate, side, 256, 0.5)].mean()
        assert edge > centre + 0.03, (tuple(side.normal), edge, centre)
    mat = bpy.data.materials[out["material"]]
    assert out["material"] == "M_Crate_Stylized" and [s.material for s in crate.material_slots] == [mat]
    tex = mat.node_tree.nodes["forge_albedo"]
    assert Path(bpy.path.abspath(tex.image.filepath)) == Path(out["albedo"])
    assert not [m.name for m in bpy.data.materials if m.name.startswith("forge_")]
    assert [i.name for i in bpy.data.images] == [tex.image.name]


def test_ao_shadow_shifts_hue_not_only_value(tmp):
    tray = _tray()
    out = stylize.stylize(tray, tmp, palette={"base": [[0.8, 0.35, 0.2]]}, recipe="stone", resolution=256)
    assert out["palette"]["shadow"] == stylize.RECIPES["stone"]["palette"]["shadow"]
    albedo = _png(out["albedo"])[..., :3]
    ao = _png(out["maps"]["ao"])[..., 0]
    up = np.any([_face_mask(tray, p, 256, 0.05) for p in tray.data.polygons if p.normal.z > 0.9], axis=0)
    shadowed, lit = up & (ao < 0.6), up & (ao > 0.97)
    assert shadowed.sum() > 200 and lit.sum() > 200, (shadowed.sum(), lit.sum())
    dark, light = albedo[shadowed].mean(0), albedo[lit].mean(0)
    assert dark.max() < light.max()
    assert _hue_gap(dark, light) > 10, (dark, light)
    assert np.abs(_chroma(dark) - _chroma(light)).max() > 0.05, (dark, light)


def test_every_recipe_paints_from_given_maps_and_reruns_in_place(tmp):
    crate = fixtures.crate()
    maps = bake.bake_maps(crate, tmp / "maps", maps=("ao", "curvature"), resolution=64)["paths"]
    assert set(stylize.RECIPES) == {"wood", "stone", "metal", "cloth", "foliage"}
    means = {}
    for recipe in stylize.RECIPES:
        out = stylize.stylize(crate, tmp / recipe, recipe=recipe, resolution=64, maps=maps)
        assert out["baked_maps"] == [] and out["maps"] == maps
        means[recipe] = _png(out["albedo"])[..., :3].mean((0, 1))
    assert min(np.abs(means[a] - means[b]).max() for a in means for b in means if a < b) > 0.02, means
    counts = (len(bpy.data.materials), len(bpy.data.images), len(crate.material_slots))
    again = stylize.stylize(crate, tmp / "foliage", recipe="foliage", resolution=64, maps=maps)
    assert (len(bpy.data.materials), len(bpy.data.images), len(crate.material_slots)) == counts
    assert np.abs(_png(again["albedo"])[..., :3].mean((0, 1)) - means["foliage"]).max() < 1e-3


def test_stylize_refuses_bad_input(tmp):
    crate = fixtures.crate()
    rock = fixtures.rock_blockout()
    cases = [(lambda: stylize.stylize(crate, tmp, recipe="marble"), "unknown recipe"),
             (lambda: stylize.stylize(crate, tmp, palette={"base": [[2.0, 0, 0]]}), "palette base"),
             (lambda: stylize.stylize(crate, tmp, palette={"base": []}), "non-empty"),
             (lambda: stylize.stylize(crate, tmp, palette={"rim": [1, 1, 1]}), "unknown palette keys"),
             (lambda: stylize.stylize(crate, tmp, maps={"ao": str(tmp / "none.png")}), "not found"),
             (lambda: stylize.stylize(rock, tmp), "no UV map")]
    for call, words in cases:
        try:
            call()
        except util.ForgeError as exc:
            assert words in str(exc), (words, str(exc))
        else:
            raise AssertionError(f"accepted: {words}")
    assert not list(tmp.iterdir()) and crate.material_slots[0].material.name == "M_Crate"
