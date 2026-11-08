import bpy

import fixtures
from forge import naming
from forge.util import ForgeError


def test_nn_is_two_or_more_digits_and_n_any_digits():
    ucx = naming.pattern_regex("UCX_{name}_{nn}")
    assert ucx.fullmatch("UCX_SM_Crate_01")["name"] == "SM_Crate"
    assert ucx.fullmatch("UCX_SM_Crate_100")["nn"] == "100"
    assert ucx.fullmatch("UCX_SM_Crate_1") is None
    lod = naming.pattern_regex("{name}_LOD{n}")
    assert lod.fullmatch("SM_Crate_LOD1_LOD12").groupdict() == {"name": "SM_Crate_LOD1", "n": "12"}
    assert naming.format_name("UCX_{name}_{nn}", "SM_A", 3) == "UCX_SM_A_03"
    assert naming.format_name("{name}_LOD{n}", "SM_A", 12) == "SM_A_LOD12"
    assert naming.format_name("{name}_Collider", "SM_A{n}", 1) == "SM_A{n}_Collider"
    try:
        naming.format_name("{name}_LOD{n}", "SM_A")
    except ForgeError as exc:
        assert "{n}" in str(exc)
    else:
        raise AssertionError("filled {n} with nothing")


def test_fixed_names_are_literal():
    rx = naming.pattern_regex("{name}_LOD{n}", name="SM.Crate+1")
    assert rx.fullmatch("SM.Crate+1_LOD2") and not rx.fullmatch("SMxCrate+1_LOD2")


def test_lod_split_and_lod0_base():
    assert naming.split_lod("SM_Crate_LOD0", "{name}_LOD{n}") == ("SM_Crate", 0)
    assert naming.split_lod("SM_Crate", "{name}_LOD{n}") == ("SM_Crate", None)
    assert naming.split_lod("SM_Crate_LOD3", None) == ("SM_Crate_LOD3", None)
    assert naming.lod0_base("SM_Crate_LOD00", "{name}_LOD{n}") == "SM_Crate"
    try:
        naming.lod0_base("SM_Crate_LOD2", "{name}_LOD{n}")
    except ForgeError as exc:
        assert "LOD2" in str(exc)
    else:
        raise AssertionError("LOD2 accepted as a chain root")


def test_lod_and_collision_objects_match_the_exact_name():
    for name in ("SM_Crate_LOD0", "SM_Crate_LOD1", "SM_Crate_LOD1_LOD1", "UCX_SM_Crate_LOD0_01", "UCX_SM_Crate_01",
                 "SM_Crate_LOD0_Collider"):
        fixtures.crate(name)
    assert {n: o.name for n, o in naming.lod_objects("SM_Crate", "{name}_LOD{n}").items()} == {
        0: "SM_Crate_LOD0", 1: "SM_Crate_LOD1"}
    hulls = naming.collision_objects("SM_Crate_LOD0", ["UCX_{name}_{nn}", "{name}_Collider", "UCX_{name}_{nn}"])
    assert [o.name for o in hulls] == ["SM_Crate_LOD0_Collider", "UCX_SM_Crate_LOD0_01"]
    assert len(bpy.data.objects) == 6
