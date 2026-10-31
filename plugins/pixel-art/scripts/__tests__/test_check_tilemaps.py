"""End-to-end tests of the read-only Tiled/LDtk map checker CLI, on maps built in a temp dir."""
import base64
import gzip
import json
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check_tilemaps.py"
H, V, D, HEX = 0x80000000, 0x40000000, 0x20000000, 0x10000000


def png(path, width, height):
    """Write a valid RGBA PNG of the given size (the checker reads only its IHDR)."""
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    rows = b"".join(b"\x00" + b"\x00" * (4 * width) for _ in range(height))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


def b64(gids, compress=None):
    raw = struct.pack(f"<{len(gids)}I", *gids)
    raw = {"zlib": zlib.compress, "gzip": gzip.compress}.get(compress, lambda b: b)(raw)
    return base64.b64encode(raw).decode()


TSX = """<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.12.2" name="terrain" tilewidth="16" tileheight="16" tilecount="4" columns="2">
 <image source="terrain.png" width="32" height="32"/>
</tileset>
"""


def tmx(data, tileset='<tileset firstgid="1" source="tiles/terrain.tsx"/>', extra=""):
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="2" height="2" tilewidth="16" tileheight="16" infinite="0">
 {tileset}
 <layer id="1" name="ground" width="2" height="2">{data}</layer>
 {extra}
</map>
"""


class CheckTilemapsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "game maps"
        self.root.mkdir()

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def run_check(self, *args, target=None):
        return subprocess.run([sys.executable, "-I", "-B", str(SCRIPT), str(target or self.root), *args],
                              capture_output=True, text=True)

    def report(self, *args, target=None):
        result = self.run_check("--json", *args, target=target)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return result.returncode, json.loads(result.stdout)

    def messages(self, report, kind="errors"):
        return " | ".join(i["message"] for i in report[kind])

    def clean_map(self):
        png(self.root / "tiles/terrain.png", 32, 32)
        self.write("tiles/terrain.tsx", TSX)
        return self.write("level.tmx", tmx('<data encoding="csv">1,2,3,4</data>'))

    def test_clean_map_passes_strict_and_is_not_modified(self):
        level = self.clean_map()
        before = level.read_bytes()
        code, report = self.report("--strict")
        self.assertEqual(code, 0, report)
        self.assertEqual((report["tool"], report["schema"], report["files_checked"]), ("check_tilemaps", 1, 2))
        self.assertEqual((report["error_count"], report["warning_count"]), (0, 0))
        self.assertEqual(level.read_bytes(), before)

    def test_all_four_flip_bits_are_masked_before_lookup(self):
        self.clean_map()
        self.write("level.tmx", tmx(f'<data encoding="csv">{1 | H},{2 | V},{3 | D},{4 | HEX}</data>'))
        code, report = self.report()
        self.assertEqual((code, report["error_count"]), (0, 0), report)

    def test_gid_past_the_last_tile_is_an_error(self):
        self.clean_map()
        self.write("level.tmx", tmx(f'<data encoding="csv">1,2,3,{5 | H}</data>'))
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertIn("belong to no tile", self.messages(report))
        self.assertIn("-> 5", self.messages(report))

    def test_tileset_image_resolves_against_the_tsx_not_the_map(self):
        self.write("tiles/terrain.tsx", TSX)
        png(self.root / "terrain.png", 32, 32)
        self.write("level.tmx", tmx('<data encoding="csv">1,2,3,4</data>'))
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertIn("image 'terrain.png' not found", self.messages(report))

    def test_missing_external_tileset_and_template_are_errors(self):
        self.write("level.tmx", tmx('<data encoding="csv">0,0,0,0</data>',
                                    extra='<objectgroup id="2" name="things"><object id="1" template="door.tx" x="0" y="0"/></objectgroup>'))
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertIn("external tileset 'tiles/terrain.tsx' not found", self.messages(report))
        self.assertIn("template 'door.tx' not found", self.messages(report))

    def test_base64_zlib_and_gzip_layers_are_decoded_and_length_checked(self):
        self.clean_map()
        self.write("a.tmx", tmx(f'<data encoding="base64" compression="zlib">{b64([1, 2, 3, 4], "zlib")}</data>'))
        self.write("b.tmx", tmx(f'<data encoding="base64" compression="gzip">{b64([1, 2, 3], "gzip")}</data>'))
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertEqual([e["file"] for e in report["errors"]], ["b.tmx"])
        self.assertIn("3 tiles of data, expected 4", self.messages(report))

    def test_phaser_profile_fails_tmx_compression_and_external_tilesets(self):
        png(self.root / "terrain.png", 32, 32)
        self.write("terrain.tsj", json.dumps({"type": "tileset", "tilecount": 4, "image": "terrain.png",
                                              "imagewidth": 32, "imageheight": 32}))
        self.write("level.tmj", json.dumps({
            "type": "map", "infinite": False, "width": 2, "height": 2,
            "tilesets": [{"firstgid": 1, "source": "terrain.tsj"}],
            "layers": [{"type": "tilelayer", "name": "ground", "width": 2, "height": 2,
                        "encoding": "base64", "compression": "zlib", "data": b64([1, 2, 3, 4], "zlib")}]}))
        generic_code, generic = self.report()
        self.assertEqual((generic_code, generic["error_count"]), (0, 0), generic)
        code, report = self.report("--engine", "phaser")
        self.assertEqual(code, 1)
        text = self.messages(report)
        self.assertIn("Phaser skips compressed layers", text)
        self.assertIn("Phaser ignores external tilesets", text)
        self.clean_map()
        _, report = self.report("--engine", "phaser", target=self.root / "level.tmx")
        self.assertIn("reads Tiled JSON only", self.messages(report))

    def test_zstd_layer_warns_without_an_engine_and_is_checked_where_python_can_decode_it(self):
        self.clean_map()
        try:
            from compression import zstd
        except ImportError:
            zstd = None
        raw = struct.pack("<4I", 1, 2, 3, 9)
        payload = base64.b64encode(zstd.compress(raw) if zstd else raw).decode()
        self.write("level.tmx", tmx(f'<data encoding="base64" compression="zstd">{payload}</data>'))
        _, report = self.report()
        self.assertIn("zstd-compressed layer", self.messages(report, "warnings"))
        if zstd:
            self.assertIn("-> 9", self.messages(report))
        else:
            self.assertIn("not decoded", self.messages(report, "warnings"))

    def test_corrupt_compressed_data_is_an_error_not_a_crash(self):
        self.clean_map()
        self.write("level.tmx", tmx('<data encoding="base64" compression="zlib">AAAA</data>'))
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertIn("cannot be decompressed", self.messages(report))

    def test_infinite_json_map_checks_every_chunk_including_negative_ones(self):
        png(self.root / "terrain.png", 32, 32)
        self.write("world.json", json.dumps({
            "type": "map", "infinite": True, "width": 16, "height": 16,
            "tilesets": [{"firstgid": 1, "tilecount": 4, "image": "terrain.png", "imagewidth": 32, "imageheight": 32}],
            "layers": [{"type": "tilelayer", "name": "ground", "chunks": [
                {"x": 0, "y": 0, "width": 2, "height": 1, "data": [1, 2]},
                {"x": 0, "y": -16, "width": 2, "height": 1, "data": [4, 9]}]}]}))
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertIn("chunk (0,-16)", self.messages(report))
        self.assertIn("infinite map", self.messages(report, "warnings"))

    def test_image_collection_ids_are_looked_up_by_id_not_by_count(self):
        png(self.root / "a.png", 8, 8)
        png(self.root / "b.png", 8, 8)
        collection = ('<tileset firstgid="1" name="props" tilewidth="8" tileheight="8" tilecount="2" columns="0">'
                      '<tile id="0"><image source="a.png"/></tile><tile id="5"><image source="b.png"/></tile></tileset>')
        self.write("level.tmx", tmx('<data encoding="csv">1,6,0,0</data>', tileset=collection))
        code, report = self.report()
        self.assertEqual((code, report["error_count"]), (0, 0), report)
        self.write("level.tmx", tmx('<data encoding="csv">1,4,0,0</data>', tileset=collection))
        code, report = self.report()
        self.assertEqual(code, 1)

    def test_react_tsx_files_are_skipped_and_json_map_on_xml_tileset_warns(self):
        self.write("src/App.tsx", "export const App = () => <div />;\n")
        png(self.root / "tiles/terrain.png", 32, 32)
        self.write("tiles/terrain.tsx", TSX)
        self.write("level.tmj", json.dumps({
            "type": "map", "infinite": False, "width": 2, "height": 2,
            "tilesets": [{"firstgid": 1, "source": "tiles/terrain.tsx"}],
            "layers": [{"type": "tilelayer", "name": "ground", "width": 2, "height": 2, "data": [1, 2, 3, 4]}]}))
        self.write("package.json", '{"name": "game"}')
        code, report = self.report()
        self.assertEqual((code, report["files_checked"]), (0, 2), report)
        self.assertIn("JSON-only loader cannot read it", self.messages(report, "warnings"))
        self.assertNotIn("App.tsx", json.dumps(report))

    def test_refuses_xml_entity_declarations(self):
        self.write("level.tmx", '<?xml version="1.0"?><!DOCTYPE m [<!ENTITY a "aaaa">]><map>&a;</map>')
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertIn("entity declarations are not accepted", self.messages(report))

    def ldtk(self, levels, tilesets=None, layers=None, external=False):
        return json.dumps({"jsonVersion": "1.5.3", "externalLevels": external, "levels": levels, "worlds": [],
                           "defs": {"tilesets": tilesets or [], "layers": layers or []}})

    def test_ldtk_missing_tileset_external_level_and_bad_csv_are_errors(self):
        level_body = {"identifier": "Two", "layerInstances": [
            {"__identifier": "Walls", "layerDefUid": 1, "__cWid": 2, "__cHei": 2, "intGridCsv": [1, 0, 1]}]}
        self.write("world/Two.ldtkl", json.dumps(level_body))
        self.write("world.ldtk", self.ldtk(
            [{"identifier": "One", "layerInstances": None, "externalRelPath": "world/One.ldtkl"},
             {"identifier": "Two", "layerInstances": None, "externalRelPath": "world/Two.ldtkl"}],
            tilesets=[{"uid": 7, "identifier": "Cave", "relPath": "cave.png", "pxWid": 32, "pxHei": 32}],
            external=True))
        code, report = self.report()
        self.assertEqual(code, 1)
        text = self.messages(report)
        self.assertIn("image 'cave.png' not found", text)
        self.assertIn("external level file 'world/One.ldtkl' not found", text)
        self.assertIn("intGridCsv has 3 cells, __cWid x __cHei is 4", text)

    def test_ldtk_stale_auto_layer_and_aseprite_tileset_warn(self):
        self.write("cave.aseprite", "binary")
        self.write("world.ldtk", self.ldtk(
            [{"identifier": "One", "layerInstances": [
                {"__identifier": "Walls", "layerDefUid": 1, "__cWid": 2, "__cHei": 1, "intGridCsv": [1, 0],
                 "autoLayerTiles": [], "__tilesetDefUid": 7}]}],
            tilesets=[{"uid": 7, "identifier": "Cave", "relPath": "cave.aseprite", "pxWid": 32, "pxHei": 32}],
            layers=[{"uid": 1, "type": "IntGrid", "autoRuleGroups": [{"active": True, "rules": [
                {"active": True, "tileRectsIds": [[0]]}]}]}]))
        code, report = self.report()
        self.assertEqual((code, report["error_count"]), (0, 0), report)
        text = self.messages(report, "warnings")
        self.assertIn("no autoLayerTiles", text)
        self.assertIn("Aseprite file", text)
        self.assertEqual(self.run_check("--strict").returncode, 1)

    def test_ldtk_tile_reading_outside_its_tileset_is_an_error(self):
        png(self.root / "cave.png", 32, 32)
        self.write("world.ldtk", self.ldtk(
            [{"identifier": "One", "layerInstances": [
                {"__identifier": "Deco", "layerDefUid": 2, "__cWid": 1, "__cHei": 1, "__tilesetDefUid": 7,
                 "gridTiles": [{"px": [0, 0], "src": [32, 0], "f": 0, "t": 2}]}]}],
            tilesets=[{"uid": 7, "identifier": "Cave", "relPath": "cave.png", "pxWid": 32, "pxHei": 32, "tileGridSize": 16}]))
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertIn("read outside the 32x32", self.messages(report))

    def test_cli_exit_two_for_missing_path_or_no_maps_and_truncation_keeps_totals(self):
        self.assertEqual(self.run_check(target=self.root / "nope").returncode, 2)
        self.write("notes.txt", "nothing")
        empty = self.run_check()
        self.assertEqual(empty.returncode, 2)
        self.assertIn("no Tiled map", empty.stderr)
        self.write("level.tmx", tmx('<data encoding="csv">0,0,0,0</data>',
                                    extra='<imagelayer id="3" name="sky"><image source="sky.png"/></imagelayer>'))
        code, report = self.report("--max-issues", "1")
        self.assertEqual(code, 1)
        self.assertEqual((report["error_count"], len(report["errors"]), report["truncated"]), (2, 1, True))
        text = self.run_check()
        self.assertIn("ERROR level.tmx:", text.stdout)
        self.assertIn("Summary: 2 errors, 0 warnings in 1 files checked", text.stdout)


if __name__ == "__main__":
    unittest.main()
