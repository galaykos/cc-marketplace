"""End-to-end tests for plugins/unity/scripts/check_unity_project.py."""
# Derived from gamedev-skills/awesome-gamedev-agent-skills@184b72b (Apache-2.0, see NOTICE); modified.

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check_unity_project.py"

GUID_PLAYER = "a79441f348de89743a2939f4d699eac1"
GUID_ENEMY = "0f5a4c1e2b3d4e5f60718293a4b5c6d7"
GUID_SPRITE = "11112222333344445555666677778888"
GUID_FOLDER = "99990000aaaabbbbccccddddeeeeffff"
GUID_GONE = "deadbeefdeadbeefdeadbeefdeadbeef"
GUID_PACKAGE = "c0ffee00c0ffee00c0ffee00c0ffee00"

MODULES_ONLY = {"dependencies": {"com.unity.modules.physics": "1.0.0"}}


def meta_text(guid: str, folder: bool = False) -> str:
    if folder:
        return f"fileFormatVersion: 2\nguid: {guid}\nfolderAsset: yes\nDefaultImporter:\n  externalObjects: {{}}\n"
    return (
        f"fileFormatVersion: 2\nguid: {guid}\nMonoImporter:\n  externalObjects: {{}}\n"
        "  serializedVersion: 2\n  defaultReferences: []\n  executionOrder: 0\n"
    )


def behaviour(name: str) -> str:
    return f"using UnityEngine;\n\npublic class {name} : MonoBehaviour\n{{\n    private void Update() {{ }}\n}}\n"


def scene(script_guid: str, file_id: str = "11500000", object_name: str = "Player") -> str:
    return (
        "%YAML 1.1\n%TAG !u! tag:unity3d.com,2011:\n"
        "--- !u!1 &100\nGameObject:\n  m_ObjectHideFlags: 0\n"
        f"  m_Name: {object_name}\n"
        "--- !u!114 &200\nMonoBehaviour:\n  m_ObjectHideFlags: 0\n"
        "  m_GameObject: {fileID: 100}\n  m_Enabled: 1\n"
        f"  m_Script: {{fileID: {file_id}, guid: {script_guid}, type: 3}}\n"
    )


class CheckUnityProjectTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name) / "MyGame"
        (self.root / "Assets").mkdir(parents=True)
        (self.root / "ProjectSettings").mkdir()
        self.write("Packages/manifest.json", json.dumps(MODULES_ONLY))
        # A small clean project: one folder, one script, one scene using it.
        self.write("Assets/Scripts.meta", meta_text(GUID_FOLDER, folder=True))
        self.write("Assets/Scripts/Player.cs", behaviour("Player"))
        self.write("Assets/Scripts/Player.cs.meta", meta_text(GUID_PLAYER))
        self.write("Assets/Main.unity", scene(GUID_PLAYER))
        self.write("Assets/Main.unity.meta", meta_text("1234567890abcdef1234567890abcdef"))

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    # helpers

    def write(self, rel: str, text: str, newline: str = "\n", bom: bool = False) -> Path:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        data = text.replace("\n", newline).encode("utf-8")
        path.write_bytes((b"\xef\xbb\xbf" if bom else b"") + data)
        return path

    def run_tool(self, *args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(CHECKER), *args],
            check=False,
            capture_output=True,
            text=True,
            cwd=cwd,
        )

    def check(self, *args: str) -> tuple[int, dict]:
        result = self.run_tool(str(self.root), "--json", "--max-issues", "0", *args)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return result.returncode, json.loads(result.stdout)

    def codes(self, payload: dict, kind: str) -> list[str]:
        return [issue["code"] for issue in payload[kind]]

    # clean project and CLI

    def test_clean_project_passes(self) -> None:
        result = self.run_tool(str(self.root))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Summary: 0 errors, 0 warnings in 5 files checked", result.stdout)

    def test_json_shape(self) -> None:
        self.write("Assets/New.txt", "hello")
        code, payload = self.check()
        self.assertEqual(code, 0)
        self.assertEqual(
            set(payload), {"tool", "schema", "root", "files_checked", "error_count", "warning_count", "errors", "warnings", "truncated"}
        )
        self.assertEqual(payload["tool"], "check_unity_project")
        self.assertEqual(payload["schema"], 1)
        self.assertFalse(payload["truncated"])
        issue = payload["warnings"][0]
        self.assertEqual(set(issue), {"code", "file", "line", "message", "fix"})
        self.assertEqual(issue["file"], "Assets/New.txt")
        self.assertIsNone(issue["line"])

    def test_not_a_unity_project_exits_2(self) -> None:
        other = Path(self.temp_dir.name) / "plain"
        other.mkdir()
        result = self.run_tool(str(other))
        self.assertEqual(result.returncode, 2)
        self.assertIn("not inside a Unity project", result.stderr)
        self.assertEqual(self.run_tool(str(other / "missing")).returncode, 2)

    def test_finds_root_from_a_subfolder_and_defaults_to_cwd(self) -> None:
        result = self.run_tool(str(self.root / "Assets" / "Scripts"))
        self.assertEqual(result.returncode, 0, result.stdout)
        result = self.run_tool(cwd=self.root)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Summary: 0 errors", result.stdout)

    def test_help_has_an_example(self) -> None:
        result = self.run_tool("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("check_unity_project.py path/to/MyGame", result.stdout)

    def test_never_writes_anything(self) -> None:
        self.write("Assets/New.cs", behaviour("New"))
        self.write("Assets/Old.cs.meta", meta_text(GUID_GONE))
        before = sorted((p.as_posix(), p.stat().st_mtime_ns) for p in self.root.rglob("*"))
        self.run_tool(str(self.root))
        after = sorted((p.as_posix(), p.stat().st_mtime_ns) for p in self.root.rglob("*"))
        self.assertEqual(before, after)

    def test_max_issues_truncates(self) -> None:
        for index in range(5):
            self.write(f"Assets/new_{index}.txt", "x")
        result = self.run_tool(str(self.root), "--max-issues", "2")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.count("WARNING "), 2)
        self.assertIn("... and 3 more", result.stdout)
        self.assertIn("Summary: 0 errors, 5 warnings", result.stdout)
        payload = json.loads(self.run_tool(str(self.root), "--json", "--max-issues", "2").stdout)
        self.assertTrue(payload["truncated"])
        self.assertEqual(len(payload["warnings"]), 2)

    def test_errors_print_before_warnings(self) -> None:
        self.write("Assets/aaa.txt", "new file")
        self.write("Assets/zzz.txt.meta", "fileFormatVersion: 2\n")
        result = self.run_tool(str(self.root))
        self.assertEqual(result.returncode, 1)
        lines = [line for line in result.stdout.splitlines() if line.startswith(("ERROR", "WARNING"))]
        self.assertTrue(lines[0].startswith("ERROR Assets/zzz.txt.meta: "), lines)
        self.assertTrue(lines[1].startswith("WARNING Assets/aaa.txt: "), lines)
        self.assertIn("  fix: ", result.stdout)

    # missing .meta and moves

    def test_new_file_without_meta_is_only_a_warning(self) -> None:
        self.write("Assets/Scripts/Enemy.cs", behaviour("Enemy"))
        code, payload = self.check()
        self.assertEqual(code, 0)
        self.assertEqual(payload["errors"], [])
        self.assertEqual(self.codes(payload, "warnings"), ["missing-meta"])
        self.assertIn("normal for a new file", payload["warnings"][0]["message"])
        # Nothing to do for a new file, so --strict does not fail on it ...
        strict = self.run_tool(str(self.root), "--strict")
        self.assertEqual(strict.returncode, 0, strict.stdout)
        # ... but it still fails on any other warning.
        self.write("Assets/Old.png.meta", meta_text(GUID_GONE))
        strict = self.run_tool(str(self.root), "--strict")
        self.assertEqual(strict.returncode, 1, strict.stdout)

    def test_new_folder_is_reported_once(self) -> None:
        self.write("Assets/Art/Hero.png", "png")
        self.write("Assets/Art/Sub/Tile.png", "png")
        code, payload = self.check()
        self.assertEqual(code, 0)
        self.assertEqual([w["file"] for w in payload["warnings"]], ["Assets/Art"])
        self.assertIn("2 files inside", payload["warnings"][0]["message"])

    def test_rename_without_meta_is_an_error(self) -> None:
        (self.root / "Assets/Scripts/Player.cs").rename(self.root / "Assets/Scripts/Hero.cs")
        code, payload = self.check()
        self.assertEqual(code, 1)
        moved = [e for e in payload["errors"] if e["code"] == "moved-without-meta"]
        self.assertEqual(len(moved), 1)
        self.assertEqual(moved[0]["file"], "Assets/Scripts/Hero.cs")
        self.assertIn("Assets/Scripts/Player.cs.meta", moved[0]["fix"])
        self.assertIn("Assets/Scripts/Hero.cs.meta", moved[0]["fix"])
        # The scene still points at the old GUID, whose .meta is now a leftover.
        missing = [e for e in payload["errors"] if e["code"] == "missing-script"]
        self.assertEqual(len(missing), 1)
        self.assertIn("Player.cs.meta", missing[0]["message"])
        # The renamed file is not also reported as an ordinary new file.
        self.assertNotIn("missing-meta", self.codes(payload, "warnings"))

    def test_move_to_another_folder_without_meta_is_an_error(self) -> None:
        self.write("Assets/Gameplay.meta", meta_text("abababababababababababababababab", folder=True))
        (self.root / "Assets/Gameplay").mkdir()
        (self.root / "Assets/Scripts/Player.cs").rename(self.root / "Assets/Gameplay/Player.cs")
        code, payload = self.check()
        self.assertEqual(code, 1)
        moved = [e for e in payload["errors"] if e["code"] == "moved-without-meta"]
        self.assertEqual([e["file"] for e in moved], ["Assets/Gameplay/Player.cs"])

    def test_folder_renamed_without_meta_is_an_error(self) -> None:
        (self.root / "Assets/Scripts").rename(self.root / "Assets/Code")
        code, payload = self.check()
        self.assertEqual(code, 1)
        moved = [e for e in payload["errors"] if e["code"] == "moved-without-meta"]
        self.assertEqual([e["file"] for e in moved], ["Assets/Code"])
        self.assertIn("Assets/Scripts.meta", moved[0]["fix"])

    def test_orphan_meta_alone_is_a_warning(self) -> None:
        self.write("Assets/Old.png.meta", meta_text(GUID_GONE))
        self.write("Assets/OldFolder.meta", meta_text(GUID_SPRITE, folder=True))
        code, payload = self.check()
        self.assertEqual(code, 0)
        self.assertEqual(payload["errors"], [])
        by_file = {w["file"]: w for w in payload["warnings"]}
        self.assertEqual(by_file["Assets/Old.png.meta"]["code"], "orphan-meta")
        self.assertIn("recreate the folder", by_file["Assets/OldFolder.meta"]["message"])

    def test_new_file_of_other_type_is_not_paired_with_orphan(self) -> None:
        self.write("Assets/Old.png.meta", meta_text(GUID_GONE))
        self.write("Assets/Notes.txt", "new")
        code, payload = self.check()
        self.assertEqual(code, 0)
        self.assertEqual(sorted(self.codes(payload, "warnings")), ["missing-meta", "orphan-meta"])

    def test_meta_name_case_mismatch_is_a_warning(self) -> None:
        self.write("Assets/Sprite.png", "png")
        self.write("Assets/sprite.png.meta", meta_text(GUID_SPRITE))
        code, payload = self.check()
        self.assertEqual(code, 0)
        self.assertEqual(self.codes(payload, "warnings"), ["meta-name-case"])

    # meta contents

    def test_duplicate_guid_is_an_error(self) -> None:
        self.write("Assets/Scripts/PlayerCopy.cs", behaviour("PlayerCopy"))
        self.write("Assets/Scripts/PlayerCopy.cs.meta", meta_text(GUID_PLAYER))
        code, payload = self.check()
        self.assertEqual(code, 1)
        self.assertEqual(self.codes(payload, "errors"), ["duplicate-guid"])
        self.assertEqual(payload["errors"][0]["line"], 2)

    def test_meta_copied_from_a_package_is_a_duplicate(self) -> None:
        self.write("Library/PackageCache/com.example.tools@1a2b3c/Runtime/Tool.cs", behaviour("Tool"))
        self.write("Library/PackageCache/com.example.tools@1a2b3c/Runtime/Tool.cs.meta", meta_text(GUID_PACKAGE))
        self.write("Assets/Tool.cs", behaviour("Tool"))
        self.write("Assets/Tool.cs.meta", meta_text(GUID_PACKAGE))
        code, payload = self.check()
        self.assertEqual(code, 1)
        self.assertEqual(self.codes(payload, "errors"), ["duplicate-guid"])
        self.assertIn("Library/PackageCache/com.example.tools@1a2b3c", payload["errors"][0]["message"])

    def test_malformed_meta_is_an_error(self) -> None:
        self.write("Assets/Broken.txt", "x")
        self.write("Assets/Broken.txt.meta", "fileFormatVersion: 2\nguid: not-a-guid\n")
        self.write("Assets/NoGuid.txt", "x")
        self.write("Assets/NoGuid.txt.meta", "fileFormatVersion: 2\n")
        code, payload = self.check()
        self.assertEqual(code, 1)
        errors = {e["file"]: e for e in payload["errors"]}
        self.assertEqual(errors["Assets/Broken.txt.meta"]["code"], "malformed-meta")
        self.assertEqual(errors["Assets/Broken.txt.meta"]["line"], 2)
        self.assertEqual(errors["Assets/NoGuid.txt.meta"]["code"], "malformed-meta")

    def test_crlf_and_bom_metas_are_read(self) -> None:
        self.write("Assets/Scripts/Player.cs.meta", meta_text(GUID_PLAYER), newline="\r\n", bom=True)
        self.write("Assets/Main.unity", scene(GUID_PLAYER), newline="\r\n", bom=True)
        code, payload = self.check()
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["warnings"], [])

    # script references

    def test_missing_script_is_an_error(self) -> None:
        self.write("Assets/Level.unity", scene(GUID_ENEMY, object_name="Goblin"))
        self.write("Assets/Level.unity.meta", meta_text("abcdefabcdefabcdefabcdefabcdefab"))
        code, payload = self.check()
        self.assertEqual(code, 1)
        self.assertEqual(self.codes(payload, "errors"), ["missing-script"])
        error = payload["errors"][0]
        self.assertEqual(error["file"], "Assets/Level.unity")
        self.assertEqual(error["line"], 12)
        self.assertIn("'Goblin'", error["message"])
        self.assertIn(GUID_ENEMY, error["fix"])

    def test_script_in_embedded_package_or_cache_is_found(self) -> None:
        self.write("Packages/com.me.combat/package.json", json.dumps({"name": "com.me.combat"}))
        self.write("Packages/com.me.combat/package.json.meta", meta_text("12121212121212121212121212121212"))
        self.write("Packages/com.me.combat/Enemy.cs", behaviour("Enemy"))
        self.write("Packages/com.me.combat/Enemy.cs.meta", meta_text(GUID_ENEMY))
        self.write("Library/PackageCache/com.example.ui@abc/Button.cs", behaviour("Button"))
        self.write("Library/PackageCache/com.example.ui@abc/Button.cs.meta", meta_text(GUID_PACKAGE))
        manifest = {"dependencies": {"com.example.ui": "1.0.0", "com.unity.modules.ui": "1.0.0"}}
        self.write("Packages/manifest.json", json.dumps(manifest))
        self.write("Assets/Level.prefab", scene(GUID_ENEMY) + scene(GUID_PACKAGE).split("\n", 2)[2])
        self.write("Assets/Level.prefab.meta", meta_text("abcdefabcdefabcdefabcdefabcdefab"))
        code, payload = self.check()
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["warnings"], [])

    def test_tarball_and_nested_local_packages_are_read(self) -> None:
        self.write("Library/PackageCache/com.me.tar@1a2b3c4d/Tool.cs.meta", meta_text(GUID_PACKAGE))
        self.write("Packages/Local/com.me.local/package.json", json.dumps({"name": "com.me.local"}))
        self.write("Packages/Local/com.me.local/Enemy.cs.meta", meta_text(GUID_ENEMY))
        manifest = {
            "dependencies": {
                "com.me.tar": "file:../Tarballs/com.me.tar-1.0.0.tgz",
                "com.me.local": "file:Local/com.me.local",
            }
        }
        self.write("Packages/manifest.json", json.dumps(manifest))
        self.write("Assets/Level.prefab", scene(GUID_ENEMY) + scene(GUID_PACKAGE).split("\n", 2)[2])
        self.write("Assets/Level.prefab.meta", meta_text("abcdefabcdefabcdefabcdefabcdefab"))
        code, payload = self.check()
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["warnings"], [])

    def test_very_long_lines_are_streamed(self) -> None:
        blob = "ab" * (8 * 1024 * 1024)  # one 16 MB line, like text-serialized mesh data
        text = scene(GUID_PLAYER).replace("--- !u!114", f"  _typelessdata: {blob}\n--- !u!114")
        text += scene(GUID_ENEMY).split("\n", 2)[2]
        self.write("Assets/Main.unity", text)
        del blob, text  # so the child process does not start out sharing them
        code, payload = self.check()
        self.assertEqual(code, 1)
        self.assertEqual(self.codes(payload, "errors"), ["missing-script"])
        self.assertEqual(payload["errors"][0]["line"], 23)
        self.assertIn(GUID_ENEMY, payload["errors"][0]["message"])
        if not Path("/proc/self/status").is_file():
            return
        # Peak memory of the checker itself (VmHWM is reset when the process starts).
        probe = (
            "import runpy, sys\n"
            f"sys.argv = [{str(CHECKER)!r}, {str(self.root)!r}]\n"
            "try:\n    runpy.run_path(sys.argv[0], run_name='__main__')\nexcept SystemExit:\n    pass\n"
            "peak = [l for l in open('/proc/self/status') if l.startswith('VmHWM:')][0].split()[1]\n"
            "print('PEAK', peak)\n"
        )
        result = subprocess.run([sys.executable, "-c", probe], capture_output=True, text=True, check=False)
        peak_kb = int(result.stdout.rsplit("PEAK", 1)[1])
        self.assertLess(peak_kb, 40 * 1024, "the long line was read into memory at once")

    def test_missing_script_is_a_warning_when_packages_are_unread(self) -> None:
        self.write("Packages/manifest.json", json.dumps({"dependencies": {"com.unity.ugui": "2.0.0"}}))
        self.write("Assets/Level.unity", scene(GUID_ENEMY))
        self.write("Assets/Level.unity.meta", meta_text("abcdefabcdefabcdefabcdefabcdefab"))
        code, payload = self.check()
        self.assertEqual(code, 0)
        self.assertEqual(self.codes(payload, "warnings"), ["missing-script"])
        self.assertIn("Library/PackageCache is missing", payload["warnings"][0]["message"])

    def test_builtin_and_dll_script_references_are_ignored(self) -> None:
        text = scene("0000000000000000e000000000000000") + scene(GUID_ENEMY, file_id="-765806418").split("\n", 2)[2]
        self.write("Assets/Level.unity", text)
        self.write("Assets/Level.unity.meta", meta_text("abcdefabcdefabcdefabcdefabcdefab"))
        code, payload = self.check()
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["warnings"], [])

    def test_binary_scene_is_skipped(self) -> None:
        path = self.root / "Assets/Binary.unity"
        path.write_bytes(b"\x00\x00\x00\x10" + f"m_Script: {{fileID: 11500000, guid: {GUID_ENEMY}, type: 3}}".encode())
        self.write("Assets/Binary.unity.meta", meta_text("abcdefabcdefabcdefabcdefabcdefab"))
        code, payload = self.check()
        self.assertEqual(code, 0, payload)

    # what is and is not scanned

    def test_hidden_assets_are_ignored(self) -> None:
        self.write("Assets/.hidden.txt", "x")
        self.write("Assets/Docs~/readme.md", "x")
        self.write("Assets/cvs/entries", "x")
        self.write("Assets/build.tmp", "x")
        self.write("Assets/Docs~/Old.cs.meta", meta_text(GUID_GONE))
        code, payload = self.check()
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["warnings"], [])

    def test_dot_files_in_streaming_assets_are_not_hidden(self) -> None:
        self.write("Assets/StreamingAssets.meta", meta_text(GUID_SPRITE, folder=True))
        self.write("Assets/StreamingAssets/.config", "x")
        code, payload = self.check()
        self.assertEqual([w["file"] for w in payload["warnings"]], ["Assets/StreamingAssets/.config"])

    def test_library_and_temp_are_not_walked(self) -> None:
        self.write("Library/Stuff/file.txt", "x")
        self.write("Temp/scene.unity", scene(GUID_ENEMY))
        self.write("Logs/Editor.log", "x")
        code, payload = self.check()
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["warnings"], [])

    # class names

    def test_class_name_mismatch_is_a_warning(self) -> None:
        self.write("Assets/Scripts/Player.cs", behaviour("PlayerController"))
        code, payload = self.check()
        self.assertEqual(code, 0)
        self.assertEqual(self.codes(payload, "warnings"), ["class-name-mismatch"])
        warning = payload["warnings"][0]
        self.assertEqual(warning["line"], 3)
        self.assertIn("PlayerController.cs", warning["fix"])

    def test_class_name_check_avoids_false_positives(self) -> None:
        cases = {
            "Matching.cs": "namespace Game { public class Matching : UnityEngine.MonoBehaviour { } }",
            "Data.cs": "using UnityEngine;\npublic class Data : ScriptableObject { }\nclass Helper : MonoBehaviour { }",
            "Base.cs": "using UnityEngine;\npublic abstract class EnemyBase : MonoBehaviour { }",
            "Gen.cs": "using UnityEngine;\npublic class Pool<T> : MonoBehaviour { }",
            "Part.Generated.cs": "using UnityEngine;\npublic partial class Part : MonoBehaviour { }",
            "Outer.cs": "using UnityEngine;\npublic class Outer\n{\n    public class Inner : MonoBehaviour { }\n}",
            "Comment.cs": "// class Wrong : MonoBehaviour\nvar s = \"class Wrong : MonoBehaviour\";\n",
            "Indirect.cs": "public class Boss : EnemyBase { }",
            "Scoped.cs": "namespace Game;\nusing UnityEngine;\npublic sealed class Scoped : MonoBehaviour { }",
        }
        for index, (name, text) in enumerate(cases.items()):
            self.write(f"Assets/Scripts/{name}", text)
            self.write(f"Assets/Scripts/{name}.meta", meta_text(f"{index + 1:x}".rjust(32, "a")))
        code, payload = self.check()
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["warnings"], [])


if __name__ == "__main__":
    unittest.main()
