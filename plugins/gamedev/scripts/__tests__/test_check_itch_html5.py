"""End-to-end tests for check_itch_html5.py on ZIPs built here with zipfile."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "check_itch_html5.py"
GAME = {"index.html": "<canvas></canvas>", "game.js": "start()", "assets/música.ogg": "ogg", "Build/game.wasm": "wasm"}


class ItchHtml5CheckerTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)

    def make_zip(self, name: str, files: dict[str, str] | None = None, sizes: dict[str, int] | None = None) -> Path:
        path = self.root / name
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as archive:
            for entry, text in (files or {}).items():
                archive.writestr(entry, text)
            chunk = bytes(1 << 20)
            for entry, size in (sizes or {}).items():
                with archive.open(entry, "w", force_zip64=True) as out:
                    while size:
                        step = min(size, len(chunk))
                        out.write(chunk[:step])
                        size -= step
        return path

    def run_tool(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([sys.executable, "-I", str(CHECKER), *map(str, args)], capture_output=True, text=True)

    def report(self, path: Path, *args: str) -> tuple[int, dict]:
        result = self.run_tool(path, "--json", *args)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return result.returncode, json.loads(result.stdout)

    @staticmethod
    def codes(payload: dict) -> list[str]:
        return [e["code"] for e in payload["errors"]]

    def test_clean_game_zip_passes_and_nothing_is_written(self) -> None:
        path = self.make_zip("web.zip", GAME)
        before = sorted(self.root.rglob("*"))
        code, payload = self.report(path)
        self.assertEqual((code, payload["errors"], payload["files"]), (0, [], 4))
        self.assertEqual((payload["tool"], payload["schema"], payload["truncated"]), ("check_itch_html5", 1, False))
        result = self.run_tool(path)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "Summary: 0 errors in web.zip: 4 files, 31 bytes extracted")
        self.assertEqual(sorted(self.root.rglob("*")), before)

    def test_index_html_inside_a_folder(self) -> None:
        files = {f"MyGame/{k}": v for k, v in GAME.items()}
        code, payload = self.report(self.make_zip("folder.zip", files))
        self.assertEqual((code, self.codes(payload)), (1, ["index-html-missing"]))
        self.assertIn("MyGame/index.html, inside a folder", payload["errors"][0]["message"])

    def test_index_html_in_the_wrong_case(self) -> None:
        files = dict(GAME)
        files["Index.html"] = files.pop("index.html")
        code, payload = self.report(self.make_zip("case.zip", files))
        self.assertEqual((code, self.codes(payload)), (1, ["index-html-missing"]))
        self.assertIn("Index.html differs only in letter case", payload["errors"][0]["message"])

    def test_no_index_html_at_all(self) -> None:
        code, payload = self.report(self.make_zip("none.zip", {"game.html": "x"}))
        self.assertEqual((code, self.codes(payload)), (1, ["index-html-missing"]))
        self.assertIn("anywhere", payload["errors"][0]["message"])

    def test_file_count_limit_is_1000(self) -> None:
        files = {"index.html": "x", **{f"a/{i}.png": "" for i in range(999)}}
        code, payload = self.report(self.make_zip("1000.zip", files))
        self.assertEqual((code, payload["files"], payload["errors"]), (0, 1000, []))
        files["a/extra.png"] = ""
        code, payload = self.report(self.make_zip("1001.zip", files))
        self.assertEqual((code, self.codes(payload)), (1, ["too-many-files"]))

    def test_size_limits_are_500_and_200_mb(self) -> None:
        index = "<html></html>"
        at_limit = {"a.pck": 200_000_000, "b.pck": 200_000_000, "c.pck": 100_000_000 - len(index)}
        code, payload = self.report(self.make_zip("at.zip", {"index.html": index}, at_limit))
        self.assertEqual((code, payload["bytes"], payload["errors"]), (0, 500_000_000, []))
        over = {"a.pck": 200_000_001, "b.pck": 200_000_000, "c.pck": 100_000_000}
        code, payload = self.report(self.make_zip("over.zip", {"index.html": index}, over))
        self.assertEqual((code, self.codes(payload)), (1, ["extracted-too-large", "file-too-large"]))
        self.assertEqual(payload["errors"][1]["file"], "a.pck")

    def test_path_length_limit_is_240_characters(self) -> None:
        long_240 = "assets/" + "é" * (240 - len("assets/") - len(".png")) + ".png"
        self.assertEqual(len(long_240), 240)
        code, payload = self.report(self.make_zip("240.zip", {"index.html": "x", long_240: ""}))
        self.assertEqual((code, payload["errors"]), (0, []))
        code, payload = self.report(self.make_zip("241.zip", {"index.html": "x", "a" + long_240: ""}))
        self.assertEqual((code, self.codes(payload)), (1, ["path-too-long"]))

    def test_a_legacy_code_page_name_fails_and_unflagged_utf8_passes(self) -> None:
        def patched(name: str, placeholder: bytes, stored: bytes) -> Path:
            path = self.make_zip(name, {"index.html": "x", placeholder.decode() + ".png": ""})
            data = path.read_bytes()
            self.assertEqual(data.count(placeholder), 2)
            path.write_bytes(data.replace(placeholder, stored))
            return path
        code, payload = self.report(patched("cp437.zip", b"caf?", b"caf\x82"))
        self.assertEqual((code, self.codes(payload)), (1, ["name-not-utf8"]))
        code, payload = self.report(patched("utf8.zip", b"caf??", "café".encode()))
        self.assertEqual((code, payload["errors"]), (0, []))

    def test_max_issues_caps_output(self) -> None:
        files = {f"x{i}/" + "n" * 240: "" for i in range(3)}
        path = self.make_zip("many.zip", files)
        result = self.run_tool(path, "--max-issues", "2")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout.count("ERROR "), 2)
        self.assertIn("... and 2 more", result.stdout)
        self.assertTrue(result.stdout.rstrip().splitlines()[-1].startswith("Summary: 4 errors in many.zip"))
        _, payload = self.report(path, "--max-issues", "2")
        self.assertEqual((payload["error_count"], len(payload["errors"]), payload["truncated"]), (4, 2, True))

    def test_unusable_input_exits_2(self) -> None:
        tarball = self.root / "web.tar.gz"
        tarball.write_bytes(b"\x1f\x8b\x08\x00 not a zip")
        result = self.run_tool(tarball)
        self.assertEqual(result.returncode, 2)
        self.assertIn("not a readable ZIP", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(self.run_tool(self.root / "missing.zip").returncode, 2)
        self.assertEqual(self.run_tool().returncode, 2)
        self.assertEqual(self.run_tool(self.make_zip("ok.zip", GAME), "--max-issues", "-1").returncode, 2)
        help_text = self.run_tool("--help")
        self.assertEqual(help_text.returncode, 0)
        self.assertIn("https://itch.io/docs/creators/html5", help_text.stdout)


if __name__ == "__main__":
    unittest.main()
