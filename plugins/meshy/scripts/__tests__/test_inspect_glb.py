"""End-to-end tests of inspect_glb.py's CLI on GLB/glTF fixtures packed here with struct."""
import base64
import json
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "inspect_glb.py"


def png(width, height):
    return b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0) + b"\0" * 4


def jpeg(width, height):
    app0 = b"\xff\xe0" + struct.pack(">H", 16) + b"JFIF\0" + b"\x01\x01\0\0\x01\0\x01\0\0"
    sof0 = b"\xff\xc0" + struct.pack(">HBHHB", 17, 8, height, width, 3) + b"\x01\x11\0\x02\x11\x01\x03\x11\x01"
    return b"\xff\xd8" + app0 + sof0 + b"\xff\xd9"


def glb(doc, binary=b"", version=2):
    text = json.dumps(doc).encode()
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    chunks = struct.pack("<II", len(text), 0x4E4F534A) + text
    if binary:
        chunks += struct.pack("<II", len(binary), 0x004E4942) + binary
    return struct.pack("<4sII", b"glTF", version, 12 + len(chunks)) + chunks


def triangle_doc(**extra):
    """One mesh of 12 indexed triangles (36 indices, 24 vertices), POSITION spanning 1 x 2 x 0.5 m."""
    doc = {
        "asset": {"version": "2.0", "generator": "fixture"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1}]}],
        "accessors": [{"count": 24, "componentType": 5126, "type": "VEC3", "min": [-0.5, 0, -0.25], "max": [0.5, 2, 0.25]},
                      {"count": 36, "componentType": 5123, "type": "SCALAR"}],
    }
    doc.update(extra)
    return doc


class InspectGlbTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name) / "assets with spaces"
        self.root.mkdir()

    def write(self, name, data):
        path = self.root / name
        path.write_bytes(data if isinstance(data, bytes) else json.dumps(data).encode())
        return path

    def run_check(self, *args):
        return subprocess.run([sys.executable, "-I", str(SCRIPT), *map(str, args)], capture_output=True, text=True)

    def report(self, *args):
        result = self.run_check(*args, "--json")
        return result.returncode, json.loads(result.stdout)

    def test_counts_extents_and_never_writes(self):
        path = self.write("crate.glb", glb(triangle_doc()))
        before = path.read_bytes()
        code, out = self.report(path)
        self.assertEqual(code, 0)
        self.assertEqual((out["tool"], out["schema"], out["failed"], out["unreadable"]), ("inspect_glb", 1, 0, 0))
        file = out["files"][0]
        self.assertEqual((file["format"], file["generator"], file["triangles"], file["mesh_instances"]), ("glb", "fixture", 12, 1))
        self.assertEqual(file["extents_m"]["size"], [1.0, 2.0, 0.5])
        self.assertEqual(path.read_bytes(), before)
        self.assertEqual([p.name for p in self.root.iterdir()], ["crate.glb"])
        text = self.run_check(path)
        self.assertEqual(text.returncode, 0)
        self.assertIn("triangles 12 in 1 drawn mesh instances", text.stdout)
        self.assertIn("Summary: 0 failed, 0 unreadable, 1 files", text.stdout)

    def test_instances_strips_and_points_count_like_a_renderer(self):
        doc = triangle_doc(nodes=[{"children": [1, 2]}, {"mesh": 0}, {"mesh": 0, "translation": [10, 0, 0]}])
        doc["meshes"][0]["primitives"] += [{"attributes": {"POSITION": 0}, "mode": 5},
                                           {"attributes": {"POSITION": 0}, "mode": 0}]
        path = self.write("lod.glb", glb(doc))
        code, out = self.report(path, "--max-tris", 68)
        file = out["files"][0]
        self.assertEqual((code, file["triangles"], file["mesh_instances"], file["failures"]), (0, 2 * (12 + 22), 2, []))
        self.assertEqual(file["extents_m"]["size"][0], 11.0)
        code, out = self.report(path, "--max-tris", 67)
        self.assertEqual((code, out["files"][0]["failures"]), (1, ["triangles 68 > --max-tris 67"]))

    def test_node_transforms_compose_translation_rotation_scale(self):
        half_turn_about_x = [2 ** -0.5, 0, 0, 2 ** -0.5]  # +90 degrees: +Y height becomes +Z depth
        doc = triangle_doc(nodes=[{"mesh": 0, "rotation": half_turn_about_x, "scale": [1, 3, 1]}])
        code, out = self.report(self.write("rotated.glb", glb(doc)))
        self.assertEqual(code, 0)  # T * R * S: the 2 m height is scaled to 6 m, then turned onto Z
        self.assertEqual([round(v, 6) for v in out["files"][0]["extents_m"]["size"]], [1.0, 0.5, 6.0])
        doc = triangle_doc(nodes=[{"mesh": 0, "skin": 0, "scale": [100, 100, 100]}], skins=[{"joints": [0]}])
        code, out = self.report(self.write("skinned.glb", glb(doc)))
        self.assertEqual((out["files"][0]["extents_m"]["size"], out["files"][0]["skins"]), ([1.0, 2.0, 0.5], 1))

    def test_texture_budget_reads_png_in_the_bin_chunk_and_jpeg_in_a_data_uri(self):
        image = png(2048, 1024)
        doc = triangle_doc(buffers=[{"byteLength": len(image)}], bufferViews=[{"buffer": 0, "byteLength": len(image)}],
                           images=[{"bufferView": 0, "mimeType": "image/png"}], textures=[{"source": 0}])
        path = self.write("textured.glb", glb(doc, image))
        code, out = self.report(path, "--max-texture", 2048)
        self.assertEqual((code, out["files"][0]["images"]["largest_px"], out["files"][0]["images"]["embedded"]), (0, 2048, 1))
        code, out = self.report(path, "--max-texture", 1024)
        self.assertEqual((code, out["files"][0]["failures"]), (1, ["image 0 is 2048x1024 > --max-texture 1024"]))
        uri = "data:image/jpeg;base64," + base64.b64encode(jpeg(640, 4096)).decode()
        code, out = self.report(self.write("scan.gltf", triangle_doc(images=[{"uri": uri}])), "--max-texture", 4096)
        self.assertEqual((code, out["files"][0]["images"]["sizes"][0]["width"], out["files"][0]["format"]), (0, 640, "gltf"))

    def test_unmeasured_image_fails_only_a_texture_budget(self):
        doc = triangle_doc(images=[{"uri": "data:image/webp;base64," + base64.b64encode(b"RIFF\0\0\0\0WEBP").decode()}])
        path = self.write("webp.gltf", doc)
        self.assertEqual(self.report(path)[0], 0)
        code, out = self.report(path, "--max-texture", 4096)
        self.assertEqual(code, 1)
        self.assertIn("size unknown", out["files"][0]["failures"][0])

    def test_required_extension_fails_until_allowed(self):
        doc = triangle_doc(extensionsUsed=["KHR_draco_mesh_compression"], extensionsRequired=["KHR_draco_mesh_compression"])
        path = self.write("draco.glb", glb(doc))
        code, out = self.report(path)
        self.assertEqual(code, 1)
        self.assertEqual(out["files"][0]["failures"],
                         ["requires extension KHR_draco_mesh_compression; pass --allow-ext KHR_draco_mesh_compression if the importer supports it"])
        self.assertEqual(self.report(path, "--allow-ext", "KHR_draco_mesh_compression")[0], 0)

    def test_missing_external_files_fail_and_present_ones_are_read(self):
        self.write("albedo 1.png", png(512, 512))
        doc = triangle_doc(buffers=[{"uri": "geometry.bin", "byteLength": 4}],
                           images=[{"uri": "albedo%201.png"}, {"uri": "normal.png"}])
        code, out = self.report(self.write("kit.gltf", doc))
        file = out["files"][0]
        self.assertEqual(code, 1)
        self.assertEqual(sorted(file["failures"]), ["external file missing: geometry.bin", "external file missing: normal.png"])
        self.assertEqual((file["images"]["external"], file["images"]["sizes"][0]["width"]), (2, 512))

    def test_unreadable_input_exits_two_and_wins_over_a_failure(self):
        good = self.write("draco.glb", glb(triangle_doc(extensionsRequired=["KHR_draco_mesh_compression"])))
        cycle = triangle_doc(nodes=[{"mesh": 0, "children": [0]}])
        cases = {
            "missing.glb": None,
            "not-gltf.glb": b"PK\x03\x04 a zip",
            "v1.glb": glb(triangle_doc(), version=1),
            "truncated.glb": glb(triangle_doc())[:30],
            "old.gltf": {"asset": {"version": "1.0"}},
            "bad-index.glb": glb(triangle_doc(nodes=[{"mesh": 7}])),
            "cycle.glb": glb(cycle),
            "wrong-type.glb": glb(triangle_doc(accessors=[{"count": 24}, {"count": "36"}])),
            "odd-shape.glb": glb(triangle_doc(meshes=[{"primitives": {"not": "a list"}}])),
        }
        for name, data in cases.items():
            with self.subTest(name=name):
                path = self.root / name if data is None else self.write(name, data)
                code, out = self.report(path)
                self.assertEqual(code, 2, out)
                self.assertIn("error", out["files"][0])
        code, out = self.report(good, self.root / "missing.glb")
        self.assertEqual((code, out["failed"], out["unreadable"]), (2, 1, 1))

    def test_bad_arguments_exit_two(self):
        path = self.write("crate.glb", glb(triangle_doc()))
        for args in ((), (path, "--max-tris", "0"), (path, "--max-texture", "-1"), (path, "--max-tris", "many")):
            with self.subTest(args=args):
                self.assertEqual(self.run_check(*args).returncode, 2)
        self.assertEqual(self.run_check("--help").returncode, 0)


if __name__ == "__main__":
    unittest.main()
