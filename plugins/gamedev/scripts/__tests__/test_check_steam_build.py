"""End-to-end tests for the steam-publish SteamPipe build-script checker."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check_steam_build.py"

# Valve's SDK ContentBuilder layout: scripts/ next to content/ and output/.
GAME_FILES = {
    "content/game.exe": "exe!",
    "content/bin/game.exe": "bin-exe",
    "content/bin/server.exe": "srv",
    "content/bin/game.pdb": "symbols",
    "content/bin/setup.cfg": "cfg",
    "content/bin/tools/tool.exe": "tool",
    "content/bin/plugins/a.dll": "dll-a",
    "content/bin/plugins/deep/b.dll": "dll-b",
    "content/localization/german/audio/hello.wav": "wav",
    "content/localization/german/german_installscript.vdf": '"InstallScript" { }',
}

SIMPLE_APP = r'''"AppBuild"
{
	"AppID" "1000" // your AppID
	"Desc" "This is a simple build script" // internal description for this build

	"ContentRoot" "..\content\" // root content folder, relative to location of this file
	"BuildOutput" "..\output\" // build output folder for build logs and build cache files

	"Depots"
	{
		"1001" // your DepotID
		{
			"FileMapping"
			{
				"LocalPath" "*" // all files from contentroot folder
				"DepotPath" "." // mapped into the root of the depot
				"recursive" "1" // include all subfolders
			}
		}
	}
}
'''

ADVANCED_APP = r'''"AppBuild"
{
	"AppID" "1000" // Your AppID
	"Desc" "Your build description here" // internal description for this build
	"ContentRoot" "..\content\" // content root folder relative to this script file
	"BuildOutput" "..\output\"
	"Depots"
	{
		// file mapping instructions for each depot are in separate script files
		"1001" "depot_build_1001.vdf"
		"1002" "depot_build_1002.vdf"
	}
}
'''

DEPOT_1001 = r'''"DepotBuildConfig"
{
	// Set your assigned depot ID here
	"DepotID" "1001"
	//"ContentRoot"	"..\thiswilloverridetheoneinappsettings\"
  "FileMapping"
  {
    "LocalPath" "*"
    "DepotPath" "."
    "recursive" "1"
  }
  "FileExclusion" "*.pdb"
}
'''

DEPOT_1002 = r'''"DepotBuild"
{
	"DepotID" "1002"

	"FileMapping"
	{
		// all source files and folders in ".\bin" will be mapped into folder ".\executables" in depot
		"LocalPath" "bin\*"
		"DepotPath" "executables\"
		"Recursive" "1" // include all subfolders
	}

	"FileMapping"
	{
		"LocalPath" "localization\german\audio\*"
		"DepotPath" "audio\"
	}

	"FileMapping"
	{
		"LocalPath" "localization\german\german_installscript.vdf"
		"DepotPath" "."
	}

	"FileExclusion" "bin\server.exe" // exclude this file
	"FileExclusion" "*.pdb" // exclude all .PDB files everywhere
	"FileExclusion" "bin\tools*" // exclude all files under bin\tools\

	"InstallScript" "localization\german\german_installscript.vdf"

	"FileProperties"
	{
		"LocalPath" "bin\setup.cfg"
		"Attributes" "userconfig" // this file will be modified during runtime
	}
}
'''


def inline_app(depot_body: str, extra: str = "", app_id: str = "1000") -> str:
    return (
        '"AppBuild"\n{\n'
        f'  "AppID" "{app_id}"\n  "Desc" "test"\n'
        '  "ContentRoot" "..\\content\\"\n  "BuildOutput" "..\\output\\"\n'
        f"{extra}"
        '  "Depots"\n  {\n    "1001"\n    {\n'
        f"{depot_body}"
        "    }\n  }\n}\n"
    )


ALL_FILES = '      "FileMapping" { "LocalPath" "*" "DepotPath" "." "Recursive" "1" }\n'


class SteamBuildCheckerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.write_files(GAME_FILES)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def write_files(self, files: dict[str, str]) -> None:
        for name, text in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")

    def write_script(self, name: str, text: str, *, newline: str = "\n", bom: bool = False) -> Path:
        path = self.root / "scripts" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        data = text.replace("\n", newline).encode("utf-8")
        path.write_bytes((b"\xef\xbb\xbf" if bom else b"") + data)
        return path

    def run_tool(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(CHECKER), *args], check=False, capture_output=True, text=True
        )

    def run_json(self, script: Path, *args: str) -> tuple[int, dict]:
        result = self.run_tool(str(script), "--json", *args)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return result.returncode, json.loads(result.stdout)

    @staticmethod
    def codes(payload: dict, kind: str = "errors") -> list[str]:
        return [issue["code"] for issue in payload[kind]]

    def depot(self, payload: dict, depot_id: str) -> dict:
        return next(d for d in payload["depots"] if d["depot_id"] == depot_id)


    def test_simple_valve_sample_counts_every_file(self) -> None:
        code, payload = self.run_json(self.write_script("simple_app_build.vdf", SIMPLE_APP))
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["errors"], [])
        self.assertEqual(payload["warnings"], [])
        depot = self.depot(payload, "1001")
        self.assertEqual(depot["files"], len(GAME_FILES))
        self.assertEqual(depot["bytes"], sum(len(t) for t in GAME_FILES.values()))
        self.assertIsNone(depot["script"])
        self.assertEqual(payload["tool"], "check_steam_build")
        self.assertEqual(payload["schema"], 1)
        self.assertEqual(payload["files_checked"], 1)
        self.assertEqual(Path(payload["root"]), (self.root / "scripts").resolve())

    def test_separate_depot_scripts_resolve_like_the_docs(self) -> None:
        app = self.write_script("app_build_1000.vdf", ADVANCED_APP)
        self.write_script("depot_build_1001.vdf", DEPOT_1001)
        self.write_script("depot_build_1002.vdf", DEPOT_1002)
        code, payload = self.run_json(app)
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["files_checked"], 3)
        self.assertEqual(payload["warnings"], [])
        # 1001: everything except the one .pdb.
        self.assertEqual(self.depot(payload, "1001")["files"], len(GAME_FILES) - 1)
        self.assertEqual(self.depot(payload, "1001")["excluded"], 1)
        # 1002: bin\* recursive (6 files) minus server.exe, game.pdb and bin\tools\*,
        # plus one audio file and the install script.
        depot = self.depot(payload, "1002")
        self.assertEqual(depot["excluded"], 3)
        self.assertEqual([m["files"] for m in depot["mappings"]], [4, 1, 1])
        self.assertEqual(depot["files"], 6)
        self.assertEqual(depot["script"], "depot_build_1002.vdf")

    def test_text_output_has_depot_summary(self) -> None:
        result = self.run_tool(str(self.write_script("simple_app_build.vdf", SIMPLE_APP)))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("1001 [inline]: 10 files", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("Summary: 0 errors, 0 warnings in 1 files checked"))

    def test_preview_build_is_labelled_and_setlive_is_quiet(self) -> None:
        script = self.write_script(
            "app.vdf", inline_app(ALL_FILES, '  "Preview" "1"\n  "SetLive" "beta"\n')
        )
        result = self.run_tool(str(script))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Preview: nothing is uploaded", result.stdout)
        self.assertNotIn("setlive", result.stdout.lower().replace("SetLive", ""))
        self.assertIn("Summary: 0 errors, 0 warnings", result.stdout)

    def test_game_ci_steam_deploy_v3_files(self) -> None:
        # Shape written by game-ci/steam-deploy v3 (steam_deploy.sh): lowercase keys,
        # absolute paths, DepotBuildConfig, './dir/*' mappings, keys on one line.
        self.write_files({
            "build/StandaloneWindows64/Game.exe": "exe",
            "build/StandaloneWindows64/Game_Data/level0": "lvl",
            "build/StandaloneWindows64/Game.pdb": "pdb",
            "build/StandaloneWindows64/Game_BurstDebugInformation_DoNotShip/x.txt": "x",
            "build/StandaloneWindows64/install_script.vdf": '"InstallScript" {}',
            "build/StandaloneLinux64/Game.x86_64": "elf",
        })
        work = self.root / "tmp" / "steam-deploy.ABC123"
        (work / "BuildOutput").mkdir(parents=True)
        content = (self.root / "build").as_posix()
        for depot_id, folder, extra in (
            ("1234561", "StandaloneWindows64", '"InstallScript" "StandaloneWindows64/install_script.vdf"'),
            ("1234562", "StandaloneLinux64", ""),
        ):
            (work / f"depot{depot_id}.vdf").write_text(
                '"DepotBuildConfig"\n{\n'
                f'  "DepotID" "{depot_id}"\n'
                '  "FileMapping"\n  {\n'
                f'    "LocalPath" "./{folder}/*"\n    "DepotPath" "."\n    "recursive" "1"\n  }}\n'
                '  "FileExclusion" "*.pdb"  "FileExclusion" "**/*_BurstDebugInformation_DoNotShip*"'
                '  "FileExclusion" "**/*_BackUpThisFolder_ButDontShipItWithYourGame*"\n\n'
                f"  {extra}\n}}\n",
                encoding="utf-8",
            )
        manifest = work / "manifest.vdf"
        manifest.write_text(
            '"appbuild"\n{\n  "appid" "1234560"\n  "desc" "v1.2.3"\n'
            f'  "buildoutput" "{(work / "BuildOutput").as_posix()}"\n'
            f'  "contentroot" "{content}"\n  "setlive" ""\n\n  "depots"\n'
            f'  {{    "1234561" "{(work / "depot1234561.vdf").as_posix()}"'
            f'    "1234562" "{(work / "depot1234562.vdf").as_posix()}"  }}\n}}\n',
            encoding="utf-8",
        )
        code, payload = self.run_json(manifest)
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["warnings"], [])
        self.assertEqual(self.depot(payload, "1234561")["files"], 3)
        self.assertEqual(self.depot(payload, "1234561")["excluded"], 2)
        self.assertEqual(self.depot(payload, "1234562")["files"], 1)

    def test_game_ci_cli_files(self) -> None:
        # Shape written by game-ci/cli `deploy steam` (vdf-generator.ts): manifest.vdf
        # and depot_build_<id>.vdf inside the build folder, buildoutput == contentroot,
        # setlive "default", and *.vdf excluded.
        build = self.root / "build"
        self.write_files({
            "build/StandaloneWindows64/Game.exe": "exe",
            "build/StandaloneWindows64/install_script.vdf": '"InstallScript" {}',
            "build/StandaloneWindows64/Player.log": "log",
        })
        (build / "depot_build_1234561.vdf").write_text(
            '"DepotBuildConfig"\n{\n    "depotid" "1234561"\n    "FileMapping"\n    {\n'
            '        "LocalPath"\t"./StandaloneWindows64/*"\n        "DepotPath"\t"."\n'
            '        "recursive"\t"1"\n    }\n'
            '    "FileExclusion"\t"*.log"\n    "FileExclusion"\t"*.vdf"\n    "FileExclusion"\t"*.pdb"\n'
            '    "FileExclusion"\t"*_BurstDebugInformation_DoNotShip*"\n'
            '    "FileExclusion"\t"*_BackUpThisFolder_ButDontShipItWithYourGame*"\n'
            '    "InstallScript" "StandaloneWindows64/install_script.vdf"\n}',
            encoding="utf-8",
        )
        manifest = build / "manifest.vdf"
        manifest.write_text(
            '"appbuild"\n{\n    "appid" "1234560"\n    "desc" "default build 2026-10-22T00:00:00.000Z"\n'
            f'    "contentroot" "{build.as_posix()}"\n    "buildoutput" "{build.as_posix()}"\n'
            '    "setlive" "default"\n    "depots"\n    {\n'
            '        "1234561" "depot_build_1234561.vdf"\n    }\n}',
            encoding="utf-8",
        )
        code, payload = self.run_json(manifest)
        self.assertEqual(code, 0, payload)
        self.assertEqual(
            sorted(self.codes(payload, "warnings")),
            ["buildoutput-in-contentroot", "installscript-not-mapped", "setlive-default"],
        )
        self.assertEqual(self.depot(payload, "1234561")["files"], 1)


    def test_backslashes_comments_crlf_and_bom(self) -> None:
        script = self.write_script("app.vdf", SIMPLE_APP, newline="\r\n", bom=True)
        code, payload = self.run_json(script)
        self.assertEqual(code, 0, payload)
        self.assertEqual(self.depot(payload, "1001")["files"], len(GAME_FILES))

    def test_unquoted_tokens_and_case_insensitive_keys(self) -> None:
        text = (
            "APPBUILD\n{\n  appid 1000\n  DESC test\n  contentroot ../content\n"
            "  DEPOTS { 1001 { filemapping { localpath * depotpath . RECURSIVE 1 } } }\n}\n"
        )
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual(code, 0, payload)
        self.assertEqual(self.depot(payload, "1001")["files"], len(GAME_FILES))

    def test_platform_conditionals_drop_keys_that_do_not_apply(self) -> None:
        # [$X360] is never true on a PC and [$WIN32] means any PC, as in KeyValues.
        text = (
            '"AppBuild"\n{\n  "AppID" "1000"\n  "Desc" "x"\n'
            '  "ContentRoot" "..\\nope\\" [$X360]\n'
            '  "ContentRoot" "..\\content\\" [$WIN32]\n'
            '  "Depots"\n  {\n'
            '    "1001" { "FileMapping" { "LocalPath" "*" "DepotPath" "." "Recursive" "1" } }\n'
            '    "1002" [$X360] { "FileMapping" { "LocalPath" "nothing\\*" "DepotPath" "." } }\n'
            "  }\n}\n"
        )
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["warnings"], [])
        self.assertEqual([d["depot_id"] for d in payload["depots"]], ["1001"])
        self.assertEqual(self.depot(payload, "1001")["files"], len(GAME_FILES))

    @unittest.skipIf(sys.platform.startswith("win") or os.geteuid() == 0, "needs POSIX permissions as non-root")
    def test_unreadable_depot_script_exits_2(self) -> None:
        app = self.write_script("app_build_1000.vdf", ADVANCED_APP)
        self.write_script("depot_build_1001.vdf", DEPOT_1001)
        blocked = self.write_script("depot_build_1002.vdf", DEPOT_1002)
        blocked.chmod(0)
        try:
            result = self.run_tool(str(app))
        finally:
            blocked.chmod(0o644)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("cannot read file", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_parse_error_reports_line(self) -> None:
        text = SIMPLE_APP.replace('"Desc" "This is a simple build script"', '"Desc" "unterminated')
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual(code, 1)
        issue = payload["errors"][0]
        self.assertEqual(issue["code"], "vdf-parse")
        self.assertEqual(issue["file"], "app.vdf")
        self.assertEqual(issue["line"], 4)
        self.assertIn("line 4", issue["message"])

    def test_unclosed_brace_is_a_parse_error(self) -> None:
        code, payload = self.run_json(self.write_script("app.vdf", SIMPLE_APP.rstrip().rstrip("}")))
        self.assertEqual(code, 1)
        self.assertEqual(self.codes(payload), ["vdf-parse"])

    def test_depot_script_parse_error_names_that_file(self) -> None:
        app = self.write_script("app_build_1000.vdf", ADVANCED_APP)
        self.write_script("depot_build_1001.vdf", DEPOT_1001)
        self.write_script("depot_build_1002.vdf", '"DepotBuild"\n{\n  "DepotID" "1002"\n  "FileMapping" {\n')
        code, payload = self.run_json(app)
        self.assertEqual(code, 1)
        self.assertEqual(payload["errors"][0]["code"], "vdf-parse")
        self.assertEqual(payload["errors"][0]["file"], "depot_build_1002.vdf")


    def test_appid_missing(self) -> None:
        text = SIMPLE_APP.replace('"AppID" "1000" // your AppID', "")
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual((code, self.codes(payload)), (1, ["appid-missing"]))

    def test_appid_not_numeric(self) -> None:
        text = SIMPLE_APP.replace('"AppID" "1000"', '"AppID" "my-game"')
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual((code, self.codes(payload)), (1, ["appid-not-numeric"]))

    def test_depots_missing(self) -> None:
        text = '"AppBuild"\n{\n  "AppID" "1000"\n  "Desc" "x"\n  "ContentRoot" "..\\content\\"\n  "Depots" { }\n}\n'
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual((code, self.codes(payload)), (1, ["depots-missing"]))

    def test_depot_id_not_numeric(self) -> None:
        text = SIMPLE_APP.replace('"1001" // your DepotID', '"windows" // your DepotID')
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual((code, self.codes(payload)), (1, ["depotid-not-numeric"]))

    def test_inner_depot_id_not_numeric(self) -> None:
        app = self.write_script("app_build_1000.vdf", ADVANCED_APP)
        self.write_script("depot_build_1001.vdf", DEPOT_1001.replace('"DepotID" "1001"', '"DepotID" "abc"'))
        self.write_script("depot_build_1002.vdf", DEPOT_1002)
        code, payload = self.run_json(app)
        self.assertEqual((code, self.codes(payload)), (1, ["depotid-not-numeric"]))
        self.assertEqual(payload["errors"][0]["file"], "depot_build_1001.vdf")

    def test_depot_duplicate(self) -> None:
        app = self.write_script(
            "app_build_1000.vdf", ADVANCED_APP.replace('"1002" "depot_build_1002.vdf"', '"1001" "depot_build_1002.vdf"')
        )
        self.write_script("depot_build_1001.vdf", DEPOT_1001)
        self.write_script("depot_build_1002.vdf", DEPOT_1002)
        code, payload = self.run_json(app)
        self.assertEqual((code, self.codes(payload)), (1, ["depot-duplicate"]))
        self.assertEqual(payload["errors"][0]["line"], 11)

    def test_depot_script_missing(self) -> None:
        app = self.write_script("app_build_1000.vdf", ADVANCED_APP)
        self.write_script("depot_build_1001.vdf", DEPOT_1001)
        code, payload = self.run_json(app)
        self.assertEqual((code, self.codes(payload)), (1, ["depot-script-missing"]))
        self.assertEqual(payload["errors"][0]["line"], 11)

    def test_contentroot_missing(self) -> None:
        text = SIMPLE_APP.replace("..\\content\\", "..\\contnet\\")
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual((code, self.codes(payload)), (1, ["contentroot-missing"]))
        self.assertEqual(payload["errors"][0]["line"], 6)

    def test_contentroot_missing_reported_once_for_many_depots(self) -> None:
        app = self.write_script("app_build_1000.vdf", ADVANCED_APP.replace("..\\content\\", "..\\nope\\"))
        self.write_script("depot_build_1001.vdf", DEPOT_1001)
        self.write_script("depot_build_1002.vdf", DEPOT_1002)
        code, payload = self.run_json(app)
        self.assertEqual((code, self.codes(payload)), (1, ["contentroot-missing"]))

    def test_depot_contentroot_override_missing(self) -> None:
        app = self.write_script("app_build_1000.vdf", ADVANCED_APP)
        self.write_script("depot_build_1001.vdf", DEPOT_1001)
        self.write_script(
            "depot_build_1002.vdf",
            DEPOT_1002.replace('"DepotID" "1002"', '"DepotID" "1002"\n\t"ContentRoot" "..\\content\\depot1002"'),
        )
        code, payload = self.run_json(app)
        self.assertEqual((code, self.codes(payload)), (1, ["contentroot-missing"]))
        self.assertEqual(payload["errors"][0]["file"], "depot_build_1002.vdf")

    def test_filemapping_without_localpath(self) -> None:
        body = '      "FileMapping" { "DepotPath" "." "Recursive" "1" }\n' + ALL_FILES
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(body)))
        self.assertEqual((code, self.codes(payload)), (1, ["filemapping-no-localpath"]))

    def test_localpath_no_match(self) -> None:
        body = '      "FileMapping" { "LocalPath" "StandaloneWindows64\\*" "DepotPath" "." "Recursive" "1" }\n'
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(body)))
        self.assertEqual((code, self.codes(payload)), (1, ["localpath-no-match"]))
        self.assertEqual(self.depot(payload, "1001")["files"], 0)

    def test_localpath_naming_a_folder(self) -> None:
        body = '      "FileMapping" { "LocalPath" ".\\bin" "DepotPath" "." "Recursive" "1" }\n'
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(body)))
        self.assertEqual((code, self.codes(payload)), (1, ["localpath-is-folder"]))
        self.assertIn(".\\bin\\*", payload["errors"][0]["fix"])

    def test_exclusions_that_remove_everything(self) -> None:
        body = ALL_FILES + '      "FileExclusion" "*"\n'
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(body)))
        self.assertEqual((code, self.codes(payload)), (1, ["depot-empty"]))

    def test_depot_without_filemapping(self) -> None:
        code, payload = self.run_json(self.write_script("app.vdf", inline_app('      "FileExclusion" "*.pdb"\n')))
        self.assertEqual((code, self.codes(payload)), (1, ["depot-empty"]))

    def test_installscript_missing(self) -> None:
        body = ALL_FILES + '      "InstallScript" "installscript.vdf"\n'
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(body)))
        self.assertEqual((code, self.codes(payload)), (1, ["installscript-missing"]))


    def test_wildcard_mapping_recursive_and_not(self) -> None:
        recursive = '      "FileMapping" { "LocalPath" "bin\\*.dll" "DepotPath" "plugins" "Recursive" "1" }\n'
        _, payload = self.run_json(self.write_script("a.vdf", inline_app(recursive)))
        self.assertEqual(self.depot(payload, "1001")["files"], 2)
        flat = '      "FileMapping" { "LocalPath" "bin\\plugins\\?.dll" "DepotPath" "." }\n'
        _, payload = self.run_json(self.write_script("b.vdf", inline_app(flat)))
        self.assertEqual(self.depot(payload, "1001")["files"], 1)
        folders = '      "FileMapping" { "LocalPath" "*\\german\\audio\\*.wav" "DepotPath" "." }\n'
        _, payload = self.run_json(self.write_script("c.vdf", inline_app(folders)))
        self.assertEqual(self.depot(payload, "1001")["files"], 1)

    def test_non_recursive_star_takes_only_top_level_files(self) -> None:
        body = '      "FileMapping" { "LocalPath" "*" "DepotPath" "." "Recursive" "0" }\n'
        _, payload = self.run_json(self.write_script("app.vdf", inline_app(body)))
        self.assertEqual(self.depot(payload, "1001")["files"], 1)

    def test_exclusions_reduce_counts(self) -> None:
        body = ALL_FILES + '      "FileExclusion" "*.pdb"\n      "FileExclusion" "bin\\tools*"\n'
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(body)))
        self.assertEqual(code, 0, payload)
        depot = self.depot(payload, "1001")
        self.assertEqual(depot["files"], len(GAME_FILES) - 2)
        self.assertEqual(depot["excluded"], 2)
        self.assertEqual(depot["bytes"], sum(len(t) for t in GAME_FILES.values()) - len("symbols") - len("tool"))

    def test_absolute_paths(self) -> None:
        content = (self.root / "content").as_posix()
        text = SIMPLE_APP.replace("..\\content\\", content + "/")
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual(code, 0, payload)
        self.assertEqual(self.depot(payload, "1001")["files"], len(GAME_FILES))

    @unittest.skipIf(sys.platform.startswith(("win", "darwin", "cygwin")), "file names ignore case here")
    def test_case_mismatch_warns(self) -> None:
        body = '      "FileMapping" { "LocalPath" "BIN\\*" "DepotPath" "." "Recursive" "1" }\n'
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(body)))
        self.assertEqual(code, 0, payload)
        self.assertEqual(self.codes(payload, "warnings"), ["case-mismatch"])

    def test_recursive_plain_name_matches_in_subfolders(self) -> None:
        # game.exe exists at the root and in bin\.
        body = '      "FileMapping" { "LocalPath" "game.exe" "DepotPath" "." "Recursive" "1" }\n'
        code, payload = self.run_json(self.write_script("a.vdf", inline_app(body)))
        self.assertEqual(code, 0, payload)
        self.assertEqual(self.depot(payload, "1001")["files"], 2)
        # Only in a subfolder: not an error when Recursive is on.
        body = '      "FileMapping" { "LocalPath" "server.exe" "DepotPath" "." "Recursive" "1" }\n'
        code, payload = self.run_json(self.write_script("b.vdf", inline_app(body)))
        self.assertEqual(code, 0, payload)
        self.assertEqual(self.depot(payload, "1001")["files"], 1)

    def test_windows_drive_localpath_says_so(self) -> None:
        if sys.platform.startswith("win"):
            self.skipTest("drive paths exist here")
        body = '      "FileMapping" { "LocalPath" "C:\\game\\*" "DepotPath" "." "Recursive" "1" }\n'
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(body)))
        self.assertEqual((code, self.codes(payload)), (1, ["localpath-no-match"]))
        self.assertIn("Windows drive path", payload["errors"][0]["message"])


    def test_setlive_on_a_branch_warns(self) -> None:
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(ALL_FILES, '  "SetLive" "beta-qa"\n')))
        self.assertEqual(code, 0)
        self.assertEqual(self.codes(payload, "warnings"), ["setlive-immediate"])
        self.assertIn("goes live", payload["warnings"][0]["message"])

    def test_setlive_default_warns_harder(self) -> None:
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(ALL_FILES, '  "SetLive" "Default"\n')))
        self.assertEqual(code, 0)
        self.assertEqual(self.codes(payload, "warnings"), ["setlive-default"])
        self.assertIn("all players", payload["warnings"][0]["message"])

    def test_desc_missing_warns(self) -> None:
        text = SIMPLE_APP.replace('"Desc" "This is a simple build script"', '"Desc" ""')
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual((code, self.codes(payload, "warnings")), (0, ["desc-missing"]))

    def test_buildoutput_inside_contentroot_warns(self) -> None:
        text = SIMPLE_APP.replace('"..\\output\\"', '"..\\content\\output\\"')
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual((code, self.codes(payload, "warnings")), (0, ["buildoutput-in-contentroot"]))

    def test_other_warnings(self) -> None:
        body = (
            '      "DepotID" "1009"\n'
            '      "FileMapping" { "LocalPath" "*" "DepotPath" "." "Recursive" "yes" }\n'
            '      "Exclude" "*.pdb"\n'
        )
        extra = '  "Local" "..\\..\\ContentServer\\htdocs"\n  "Desc" "again"\n'
        code, payload = self.run_json(self.write_script("app.vdf", inline_app(body, extra)))
        self.assertEqual(code, 0, payload)
        self.assertEqual(
            sorted(self.codes(payload, "warnings")),
            ["depotid-mismatch", "duplicate-key", "flag-not-numeric", "local-content-server", "unknown-key"],
        )
        # "Recursive" "yes" reads as off, so only the top-level file counts.
        self.assertEqual(self.depot(payload, "1001")["files"], 1)

    def test_no_contentroot_uses_script_folder(self) -> None:
        self.write_files({"scripts/readme.txt": "hi"})
        text = SIMPLE_APP.replace('"ContentRoot" "..\\content\\"', "")
        code, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual(code, 0, payload)
        self.assertEqual(self.codes(payload, "warnings"), ["contentroot-not-set"])
        self.assertEqual(self.depot(payload, "1001")["files"], 2)  # app.vdf + readme.txt

    def test_include_directive_is_reported(self) -> None:
        code, payload = self.run_json(self.write_script("app.vdf", '#base "shared.vdf"\n' + SIMPLE_APP))
        self.assertEqual(code, 0, payload)
        self.assertEqual(self.codes(payload, "warnings"), ["include-not-followed"])


    def test_strict_fails_on_warnings(self) -> None:
        script = self.write_script("app.vdf", inline_app(ALL_FILES, '  "SetLive" "beta"\n'))
        self.assertEqual(self.run_tool(str(script)).returncode, 0)
        self.assertEqual(self.run_tool(str(script), "--strict").returncode, 1)

    def test_errors_print_before_warnings_with_fix_lines(self) -> None:
        body = '      "FileMapping" { "LocalPath" "missing\\*" "DepotPath" "." }\n'
        script = self.write_script("app.vdf", inline_app(body, '  "SetLive" "beta"\n'))
        result = self.run_tool(str(script))
        self.assertEqual(result.returncode, 1)
        lines = result.stdout.splitlines()
        self.assertTrue(lines[0].startswith("ERROR app.vdf:"), lines)
        self.assertTrue(lines[1].startswith("  fix: "), lines)
        self.assertTrue(lines[2].startswith("WARNING app.vdf:"), lines)
        self.assertEqual(lines[-1], "Summary: 1 errors, 1 warnings in 1 files checked")

    def test_max_issues_caps_output(self) -> None:
        body = "".join(
            f'      "FileMapping" {{ "LocalPath" "nothing{i}\\*" "DepotPath" "." }}\n' for i in range(5)
        )
        script = self.write_script("app.vdf", inline_app(body))
        result = self.run_tool(str(script), "--max-issues", "2")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout.count("ERROR "), 2)
        self.assertIn("... and 3 more", result.stdout)
        self.assertIn("Summary: 5 errors, 0 warnings", result.stdout)
        _, payload = self.run_json(script, "--max-issues", "2")
        self.assertTrue(payload["truncated"])
        self.assertEqual(len(payload["errors"]), 2)
        _, payload = self.run_json(script)
        self.assertFalse(payload["truncated"])
        self.assertEqual(len(payload["errors"]), 5)

    def test_issue_shape(self) -> None:
        text = SIMPLE_APP.replace("..\\content\\", "..\\contnet\\")
        _, payload = self.run_json(self.write_script("app.vdf", text))
        self.assertEqual(set(payload), {"tool", "schema", "root", "files_checked", "error_count", "warning_count", "errors", "warnings", "truncated", "depots"})
        self.assertEqual(set(payload["errors"][0]), {"code", "file", "line", "message", "fix"})

    def test_missing_file_exits_2(self) -> None:
        result = self.run_tool(str(self.root / "scripts" / "nope.vdf"))
        self.assertEqual(result.returncode, 2)
        self.assertIn("file not found", result.stderr)

    def test_depot_script_passed_instead_of_app_script_exits_2(self) -> None:
        result = self.run_tool(str(self.write_script("depot_build_1001.vdf", DEPOT_1001)))
        self.assertEqual(result.returncode, 2)
        self.assertIn("not an AppBuild script", result.stderr)

    def test_help_has_example(self) -> None:
        result = self.run_tool("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("example:", result.stdout)
        self.assertIn("--max-issues", result.stdout)

    def test_never_writes_files(self) -> None:
        script = self.write_script("simple_app_build.vdf", SIMPLE_APP)
        before = sorted(p.relative_to(self.root) for p in self.root.rglob("*"))
        self.run_tool(str(script), "--json")
        after = sorted(p.relative_to(self.root) for p in self.root.rglob("*"))
        self.assertEqual(before, after)
        self.assertFalse((self.root / "output").exists())


if __name__ == "__main__":
    unittest.main()
