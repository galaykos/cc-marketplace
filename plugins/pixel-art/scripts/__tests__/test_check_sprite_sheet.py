"""End-to-end tests of the read-only sprite-sheet JSON checker CLI, on Aseprite-shaped exports built in a temp dir."""
import json
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "check_sprite_sheet.py"


def png(path, width, height):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    rows = b"".join(b"\x00" + b"\x00" * (4 * width) for _ in range(height))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


def frame(x, duration=100, trim=(0, 0, 16, 16), source=(16, 16)):
    return {"frame": {"x": x, "y": 0, "w": trim[2], "h": trim[3]}, "rotated": False, "trimmed": trim != (0, 0, *source),
            "spriteSourceSize": dict(zip("xywh", trim)), "sourceSize": {"w": source[0], "h": source[1]},
            "duration": duration}


def sheet(frames, tags=None, size=(64, 16), image="hero.png"):
    meta = {"app": "https://www.aseprite.org/", "version": "1.3.15", "format": "RGBA8888",
            "size": {"w": size[0], "h": size[1]}, "scale": "1"}
    if image:
        meta["image"] = image
    if tags is not None:
        meta["frameTags"] = tags
    return {"frames": frames, "meta": meta}


class CheckSpriteSheetTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "art dir"
        self.root.mkdir()
        png(self.root / "hero.png", 64, 16)

    def write(self, name, doc):
        path = self.root / name
        path.write_text(doc if isinstance(doc, str) else json.dumps(doc), encoding="utf-8")
        return path

    def run_check(self, *args, target=None):
        return subprocess.run([sys.executable, "-I", "-B", str(SCRIPT), str(target or self.root), *args],
                              capture_output=True, text=True)

    def report(self, *args, target=None):
        result = self.run_check("--json", *args, target=target)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return result.returncode, json.loads(result.stdout)

    def text(self, report, kind="errors"):
        return " | ".join(i["message"] for i in report[kind])

    def frames(self, count=4):
        return [dict(frame(16 * i), filename=f"hero {i}.aseprite") for i in range(count)]

    def test_clean_array_export_with_tags_passes_strict(self):
        path = self.write("hero.json", sheet(self.frames(), [
            {"name": "walk", "from": 0, "to": 3, "direction": "pingpong", "repeat": "2"}]))
        before = path.read_bytes()
        code, report = self.report("--strict")
        self.assertEqual(code, 0, report)
        self.assertEqual((report["tool"], report["files_checked"], report["error_count"]), ("check_sprite_sheet", 1, 0))
        self.assertEqual(path.read_bytes(), before)

    def test_tag_past_the_frames_array_is_an_error(self):
        self.write("hero.json", sheet(self.frames(3), [{"name": "walk", "from": 0, "to": 3, "direction": "forward"},
                                                       {"name": "back", "from": 2, "to": 1, "direction": "forward"}]))
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertIn("frames 0-3 but the frames array has 3 entries", self.text(report))
        self.assertIn("from 2 is after to 1", self.text(report))

    def test_duplicate_hash_keys_are_reported_even_though_json_keeps_one(self):
        entry = json.dumps(frame(0))
        raw = ('{"frames": {"0": ' + entry + ', "0": ' + entry + '}, '
               '"meta": {"app": "aseprite", "image": "hero.png", "size": {"w": 64, "h": 16}}}')
        self.write("hero.json", raw)
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertIn("frame key '0' repeats", self.text(report))

    def test_stale_image_and_frames_outside_it_are_errors(self):
        png(self.root / "hero.png", 48, 16)
        self.write("hero.json", sheet(self.frames(), [{"name": "walk", "from": 0, "to": 3}]))
        code, report = self.report()
        self.assertEqual(code, 1)
        self.assertIn("is 48x16 but meta.size says 64x16", self.text(report))
        self.assertIn("reaches outside the 48x16 sheet", self.text(report))

    def test_missing_image_bad_duration_and_trim_outside_source_are_errors(self):
        frames = self.frames(2)
        frames[0]["duration"] = 0
        frames[1]["spriteSourceSize"] = {"x": 10, "y": 0, "w": 10, "h": 16}
        self.write("hero.json", sheet(frames, [], image="gone.png"))
        code, report = self.report()
        self.assertEqual(code, 1)
        text = self.text(report)
        self.assertIn("meta.image 'gone.png' not found", text)
        self.assertIn("positive duration", text)
        self.assertIn("lies outside sourceSize", text)

    def test_untagged_multi_frame_aseprite_export_warns_and_fails_strict(self):
        self.write("hero.json", sheet(self.frames()))
        code, report = self.report()
        self.assertEqual((code, report["warning_count"]), (0, 1), report)
        self.assertIn("without --list-tags", self.text(report, "warnings"))
        self.assertEqual(self.run_check("--strict").returncode, 1)

    def test_mixed_source_sizes_inside_a_tag_and_odd_repeat_warn(self):
        frames = self.frames(2)
        frames[1]["sourceSize"] = {"w": 24, "h": 16}
        self.write("hero.json", sheet(frames, [{"name": "hit", "from": 0, "to": 1, "repeat": "twice"}]))
        _, report = self.report()
        text = self.text(report, "warnings")
        self.assertIn("different sourceSize", text)
        self.assertIn("not a whole number", text)

    def test_non_sheet_json_is_skipped_in_a_scan_and_refused_by_name(self):
        self.write("hero.json", sheet(self.frames(), [{"name": "walk", "from": 0, "to": 3}]))
        other = self.write("package.json", {"name": "game"})
        code, report = self.report()
        self.assertEqual((code, report["files_checked"]), (0, 1), report)
        refused = self.run_check(target=other)
        self.assertEqual(refused.returncode, 2)
        self.assertIn("not a sprite-sheet JSON", refused.stderr)
        self.assertEqual(self.run_check(target=self.root / "missing.json").returncode, 2)

    def test_text_output_names_file_and_summary(self):
        self.write("hero.json", sheet(self.frames(3), [{"name": "walk", "from": 0, "to": 5}]))
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("ERROR hero.json: tag 'walk'", result.stdout)
        self.assertIn("Summary: 1 errors, 0 warnings in 1 files checked", result.stdout)


if __name__ == "__main__":
    unittest.main()
