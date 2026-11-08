"""Every python block in the organic-modeling skill and its recipes runs as written and yields sane meshes."""
import re
from pathlib import Path

from forge import blockout, util

SKILL = Path(__file__).resolve().parents[3] / "skills" / "organic-modeling"


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
