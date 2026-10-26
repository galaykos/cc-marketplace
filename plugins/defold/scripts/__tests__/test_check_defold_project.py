"""End-to-end tests for check_defold_project.py: each case builds a Defold project in a temp dir."""
# Derived from gamedev-skills/awesome-gamedev-agent-skills@184b72b (Apache-2.0, see NOTICE); modified.

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "check_defold_project.py"

GAME_PROJECT = """\
[project]
title = Test

[bootstrap]
main_collection = /main/main.collectionc

[input]
game_binding = /input/game.input_bindingc
"""

MAIN_COLLECTION = """\
name: "main"
instances {
  id: "player"
  prototype: "/main/player.go"
  component_properties {
    id: "player"
    properties {
      id: "target"
      value: "/enemy"
      type: PROPERTY_TYPE_HASH
    }
  }
}
collection_instances {
  id: "wave"
  collection: "/main/wave.collection"
}
scale_along_z: 0
"""

PLAYER_GO = """\
components {
  id: "player"
  component: "/main/player.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \\"blob\\"\\n"
  "material: \\"/builtins/materials/sprite.material\\"\\n"
  "textures {\\n"
  "  sampler: \\"texture_sampler\\"\\n"
  "  texture: \\"/main/main.atlas\\"\\n"
  "}\\n"
  ""
}
embedded_components {
  id: "bulletfactory"
  type: "factory"
  data: "prototype: \\"/main/bullet.go\\"\\n"
  ""
}
"""

PLAYER_SCRIPT = """\
local util = require "modules.util"
local socket = require "socket"
local sock = require("builtins.scripts.socket")
-- require "commented.out"
--[[ require "block.comment" ]]
go.property("art", resource.atlas("/main/main.atlas"))

function init(self)
\tmsg.post(".", "acquire_input_focus")
\tmsg.post("main:/player#player", "hello")
\tgo.set_position(vmath.vector3(), "/player")
\tprint("not a require: require 'x.y'")
end
"""

ATLAS = """\
images {
  image: "/images/blob.png"
}
"""

WAVE = """\
name: "wave"
instances {
  id: "a"
  prototype: "/main/bullet.go"
}
"""

BULLET_GO = """\
components {
  id: "bullet"
  component: "/main/bullet.script"
}
"""

UNUSED_GO = 'components {\n  id: "x"\n  component: "/nothing.script"\n}\n'


class DefoldProjectCheckerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name) / "my game"
        self.make_clean_project()

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    # -- helpers

    def write(self, rel: str, text: str, newline: str = "\n") -> Path:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8", newline=newline) as handle:
            handle.write(text)
        return path

    def edit(self, rel: str, old: str, new: str) -> None:
        path = self.root / rel
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, f"fixture text not found in {rel}")
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def make_clean_project(self) -> None:
        self.write("game.project", GAME_PROJECT)
        self.write("input/game.input_binding", 'key_trigger {\n  input: KEY_SPACE\n  action: "jump"\n}\n')
        self.write("main/main.collection", MAIN_COLLECTION)
        self.write("main/player.go", PLAYER_GO)
        self.write("main/player.script", PLAYER_SCRIPT)
        self.write("main/main.atlas", ATLAS)
        self.write("main/wave.collection", WAVE)
        self.write("main/bullet.go", BULLET_GO)
        self.write("main/bullet.script", "function update(self, dt)\nend\n")
        self.write("modules/util.lua", "return {}\n")
        self.write("images/blob.png", "png")

    def run_checker(self, *args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run([sys.executable, str(CHECKER), *args], check=False, capture_output=True,
                              text=True, cwd=cwd)

    def report(self, *args: str) -> tuple[int, dict]:
        result = self.run_checker(str(self.root), "--json", "--max-issues", "500", *args)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return result.returncode, json.loads(result.stdout)

    def codes(self, payload: dict, kind: str) -> list[str]:
        return [issue["code"] for issue in payload[kind]]

    def assert_only(self, payload: dict, kind: str, code: str) -> dict:
        self.assertEqual(self.codes(payload, kind), [code], payload)
        other = "warnings" if kind == "errors" else "errors"
        self.assertEqual(payload[other], [], payload)
        return payload[kind][0]

    # -- clean project and CLI contract

    def test_clean_project_passes_and_is_read_only(self) -> None:
        before = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        result = self.run_checker(str(self.root))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Summary: 0 errors, 0 warnings in 10 files checked", result.stdout)
        after = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(before, after)

    def test_defaults_to_current_directory(self) -> None:
        self.assertEqual(self.run_checker(cwd=self.root).returncode, 0)

    def test_json_schema(self) -> None:
        self.edit("main/main.atlas", "/images/blob.png", "/images/gone.png")
        code, payload = self.report()
        self.assertEqual(code, 1)
        self.assertEqual(set(payload), {"tool", "schema", "root", "files_checked", "error_count",
                                        "warning_count", "errors", "warnings", "truncated"})
        self.assertEqual((payload["tool"], payload["schema"]), ("check_defold_project", 1))
        self.assertEqual(payload["root"], self.root.resolve().as_posix())
        self.assertFalse(payload["truncated"])
        issue = payload["errors"][0]
        self.assertEqual(set(issue), {"code", "file", "line", "message", "fix"})
        self.assertEqual((issue["file"], issue["line"]), ("main/main.atlas", 2))

    def test_text_output_format_and_cap(self) -> None:
        self.edit("main/main.atlas", "/images/blob.png", "/images/gone.png")
        for name in ("a", "b", "c"):
            self.write(f"unused/{name}.go", f'components {{\n  id: "x"\n  component: "/missing_{name}.script"\n}}\n')
        result = self.run_checker(str(self.root), "--max-issues", "2")
        self.assertEqual(result.returncode, 1)
        lines = result.stdout.splitlines()
        self.assertTrue(lines[0].startswith("ERROR main/main.atlas:2: "), lines)
        self.assertTrue(lines[1].startswith("  fix: "), lines)
        self.assertTrue(lines[2].startswith("WARNING unused/a.go:3: "), lines)
        self.assertIn("... and 2 more", result.stdout)
        self.assertIn("Summary: 1 errors, 3 warnings", result.stdout)
        unlimited = self.run_checker(str(self.root), "--max-issues", "0")
        self.assertNotIn("more", unlimited.stdout)
        self.assertEqual(unlimited.stdout.count("  fix: "), 4)
        _, payload = self.report("--max-issues", "1")
        self.assertTrue(payload["truncated"])
        self.assertEqual((payload["error_count"], payload["warning_count"]), (1, 3))

    def test_strict_fails_on_warnings(self) -> None:
        self.write("unused.go", UNUSED_GO)
        self.assertEqual(self.run_checker(str(self.root)).returncode, 0)
        self.assertEqual(self.run_checker(str(self.root), "--strict").returncode, 1)

    def test_not_a_project_exits_2(self) -> None:
        empty = Path(self.temp_dir.name) / "empty"
        empty.mkdir()
        result = self.run_checker(str(empty))
        self.assertEqual(result.returncode, 2)
        self.assertIn("not a Defold project", result.stderr)
        self.assertEqual(self.run_checker(str(empty / "missing")).returncode, 2)

    def test_help_has_example(self) -> None:
        result = self.run_checker("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("example:", result.stdout)

    # -- game.project

    def test_main_collection_without_compiled_suffix(self) -> None:
        self.edit("game.project", "/main/main.collectionc", "/main/main.collection")
        _, payload = self.report()
        issue = self.assert_only(payload, "errors", "setting-suffix")
        self.assertEqual((issue["file"], issue["line"]), ("game.project", 5))
        self.assertIn("/main/main.collectionc", issue["fix"])

    def test_main_collection_missing(self) -> None:
        self.edit("game.project", "/main/main.collectionc", "/main/start.collectionc")
        _, payload = self.report()
        self.assertEqual(self.codes(payload, "errors"), ["setting-missing"])
        self.assertIn("/main/start.collection", payload["errors"][0]["message"])

    def test_absent_keys_fall_back_to_defaults(self) -> None:
        self.write("game.project", "[project]\ntitle = Test\n")
        _, payload = self.report()
        self.assertEqual(self.codes(payload, "errors"), ["setting-missing"])
        self.assertIn("/logic/main.collection", payload["errors"][0]["message"])
        self.assertIn("is not set", payload["errors"][0]["message"])
        self.write("logic/main.collection", 'name: "main"\n')
        _, payload = self.report()
        self.assertEqual(payload["errors"], [])

    def test_missing_game_binding(self) -> None:
        self.edit("game.project", "/input/game.input_bindingc", "/input/other.input_bindingc")
        _, payload = self.report()
        issue = payload["errors"][0]
        self.assertEqual((issue["code"], issue["line"]), ("setting-missing", 8))

    def test_other_settings_are_warnings(self) -> None:
        self.write("game.project", GAME_PROJECT + "\n[windows]\napp_icon = /icons/app.ico\n"
                   "\n[project]\ncustom_resources = /data,levels.json\n"
                   "\n[display]\ndisplay_profiles = /builtins/render/default.display_profilesc\n")
        self.write("data/save.json", "{}")
        _, payload = self.report()
        self.assertEqual(payload["errors"], [])
        messages = [w["message"] for w in payload["warnings"]]
        self.assertEqual(len(messages), 2, messages)
        self.assertTrue(any("/icons/app.ico" in m for m in messages))
        self.assertTrue(any("levels.json" in m for m in messages))

    # -- resource references

    def test_missing_prototype_inside_embedded_data(self) -> None:
        self.edit("main/player.go", '\\"/main/bullet.go\\"', '\\"/main/missing.go\\"')
        _, payload = self.report()
        issue = self.assert_only(payload, "errors", "path-missing")
        self.assertEqual((issue["file"], issue["line"]), ("main/player.go", 19))
        self.assertIn("/main/missing.go", issue["message"])

    def test_case_mismatch_is_error(self) -> None:
        self.edit("main/main.atlas", "/images/blob.png", "/images/Blob.png")
        _, payload = self.report()
        issue = self.assert_only(payload, "errors", "path-case")
        self.assertIn("/images/blob.png", issue["message"])

    def test_similar_file_is_suggested(self) -> None:
        self.edit("main/main.atlas", "/images/blob.png", "/art/blob.png")
        _, payload = self.report()
        self.assertIn("/images/blob.png", payload["errors"][0]["fix"])

    def test_ids_and_urls_are_not_paths(self) -> None:
        self.write("main/extra.script", 'function init(self)\n\tmsg.post("/enemy#ai", "go")\n'
                   '\tlocal u = msg.url("level:/door#script")\n\tgo.delete("/wave/a")\nend\n')
        self.edit("main/player.go", '  component: "/main/player.script"\n',
                  '  component: "/main/player.script"\n}\ncomponents {\n  id: "extra"\n'
                  '  component: "/main/extra.script"\n')
        code, payload = self.report()
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["warnings"], [])

    def test_unused_file_is_only_warning(self) -> None:
        self.write("old/enemy.go", 'components {\n  id: "x"\n  component: "/old/enemy.script"\n}\n')
        code, payload = self.report()
        self.assertEqual(code, 0)
        issue = self.assert_only(payload, "warnings", "path-missing")
        self.assertIn("not used by the build", issue["message"])

    # -- scripts

    def test_missing_dotted_require_is_error(self) -> None:
        self.edit("main/player.script", '"modules.util"', '"modules.utils"')
        _, payload = self.report()
        issue = self.assert_only(payload, "errors", "path-missing")
        self.assertEqual((issue["file"], issue["line"]), ("main/player.script", 1))
        self.assertIn("/modules/utils.lua", issue["message"])

    def test_single_name_require_is_warning(self) -> None:
        self.edit("main/player.script", '"modules.util"', '"helpers"')
        code, payload = self.report()
        self.assertEqual(code, 0)
        self.assert_only(payload, "warnings", "path-missing")
        self.write("helpers.lua", "return {}\n")
        _, payload = self.report()
        self.assertEqual(payload["warnings"], [])

    def test_resource_property_and_load_resource(self) -> None:
        self.edit("main/player.script", 'resource.atlas("/main/main.atlas")', 'resource.atlas("/main/gone.atlas")')
        self.edit("main/player.script", "function init(self)\n",
                  'function init(self)\n\tlocal data = sys.load_resource("/data/levels.json")\n')
        _, payload = self.report()
        self.assertEqual(self.codes(payload, "errors"), ["path-missing"])
        self.assertEqual(payload["errors"][0]["line"], 6)
        self.assertEqual(self.codes(payload, "warnings"), ["path-missing"])
        self.assertIn("custom_resources", payload["warnings"][0]["fix"])

    # -- skipped folders and .defignore

    def test_build_and_hidden_folders_are_skipped(self) -> None:
        for rel in ("build/default/x.go", ".internal/x.go", ".git/x.go", "main/.hidden/x.go"):
            self.write(rel, UNUSED_GO)
        self.write(".editor_settings", "[x]\n")
        _, payload = self.report()
        self.assertEqual((payload["errors"], payload["warnings"]), ([], []))

    def test_defignore(self) -> None:
        self.write("tools/gen.go", 'package main\nimport "/not/defold.go"\n')
        self.write(".defignore", "/tools\n/**/raw\n")
        self.write("art/raw/big.png", "png")
        _, payload = self.report()
        self.assertEqual((payload["errors"], payload["warnings"]), ([], []))
        self.edit("main/main.atlas", "/images/blob.png", "/art/raw/big.png")
        _, payload = self.report()
        self.assert_only(payload, "errors", "path-ignored")

    # -- library dependencies

    def add_dependency(self, url: str) -> None:
        self.edit("game.project", "title = Test\n", f"title = Test\ndependencies#0 = {url}\n")

    def test_unfetched_dependency_downgrades_to_warnings(self) -> None:
        self.add_dependency("https://example.com/lib.zip")
        self.edit("main/player.script", '"modules.util"', '"mylib.api"')
        code, payload = self.report()
        self.assertEqual(code, 0)
        self.assertEqual(sorted(self.codes(payload, "warnings")), ["dependencies-unfetched", "path-unverified"])

    def test_fetched_dependency_is_checked(self) -> None:
        url = "https://example.com/lib.zip"
        self.add_dependency(url)
        lib = self.root / ".internal" / "lib"
        lib.mkdir(parents=True)
        archive = lib / f"{hashlib.sha1(url.encode()).hexdigest()}-ImV0YWci.zip"
        with zipfile.ZipFile(archive, "w") as zf:
            zf.writestr("lib-main/game.project", "[library]\ninclude_dirs = mylib\n")
            zf.writestr("lib-main/mylib/api.lua", "return {}\n")
            zf.writestr("lib-main/example/main.collection", 'name: "x"\n')
        self.edit("main/player.script", '"modules.util"', '"mylib.api"')
        _, payload = self.report()
        self.assertEqual((payload["errors"], payload["warnings"]), ([], []))
        self.edit("main/player.script", '"mylib.api"', '"mylib.nope"')
        _, payload = self.report()
        self.assert_only(payload, "errors", "path-missing")

    # -- text encodings

    def test_crlf_and_bom_files(self) -> None:
        self.write("game.project", "\ufeff" + GAME_PROJECT, newline="\r\n")
        self.write("main/main.atlas", "\ufeff" + ATLAS.replace("blob", "gone"), newline="\r\n")
        _, payload = self.report()
        issue = self.assert_only(payload, "errors", "path-missing")
        self.assertEqual(issue["line"], 2)


if __name__ == "__main__":
    unittest.main()
