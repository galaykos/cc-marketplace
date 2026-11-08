"""Every python block in the organic-modeling skill and its recipes runs as written and yields sane meshes; the
stylized-texturing recipe table states stylize.RECIPES' numbers."""
import re
from pathlib import Path

from forge import blockout, stylize, util

SKILL = Path(__file__).resolve().parents[3] / "skills" / "organic-modeling"
TEXTURING = SKILL.parent / "stylized-texturing" / "SKILL.md"


def _blocks(path):
    return re.findall(r"```python\n(.*?)```", path.read_text(encoding="utf-8"), re.S)


def _check(spec, name, height_range):
    out = blockout.skin_from_skeleton(spec, name=name, subdivisions=1)
    assert out["ok"] and out["manifold"], out
    lo, hi = util.world_bbox(util.get_object(name))
    assert height_range[0] <= hi.z - lo.z <= height_range[1], (name, hi.z - lo.z)


def test_quadruped_spec_in_skill():
    ns = {}
    exec(_blocks(SKILL / "SKILL.md")[0], ns)
    _check(ns["spec"], "SK_Wolf", (1.0, 1.35))


def test_biped_and_tree_recipes():
    blocks = _blocks(SKILL / "references" / "recipes.md")
    ns = {}
    exec(blocks[0], ns)
    _check(ns["biped"], "SK_Kid", (0.95, 1.2))
    exec(blocks[1], ns)
    _check(ns["tree"], "SM_Tree", (3.6, 4.6))


def test_rock_cluster_recipe():
    ns = {}
    exec(_blocks(SKILL / "references" / "recipes.md")[2], ns)
    assert ns["rocks"] == [f"SM_Rock_{i:02d}" for i in range(4)]


def test_stylized_recipe_table_matches_the_recipes():
    knobs = ("edge_strength", "cavity_strength", "stroke_stretch")
    table = {}
    for line in TEXTURING.read_text(encoding="utf-8").splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells[0] in stylize.RECIPES:
            table[cells[0]] = [float(re.match(r"[\d.]+", c).group()) for c in cells[3:6]]
    assert table == {name: [r[k] for k in knobs] for name, r in stylize.RECIPES.items()}, table
