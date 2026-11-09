"""End-to-end tests for check_unreal_project.py: each case builds a throwaway UE project in a temp dir."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "check_unreal_project.py"

CLEAN_ENGINE_INI = """\
[Zen.AutoLaunch]
LimitProcessLifetime=false
RemoteNetworkService=Unsecured
"""

DEPRECATED_CPP = """\
#include "MyActor.h"
UObject* A = FindObject<UEnum>(ANY_PACKAGE, TEXT("EMyEnum"));
UPlayerMappableInputConfig* Config = nullptr;
FPlayerMappableKeySlot Slot;
template <typename T TEMPLATE_REQUIRES(TIsArithmetic<T>::Value)> void F(T);
bool FMyTickable::IsAllowedToTick() const { return true; }
InstancingPolicy = EGameplayAbilityInstancingPolicy::NonInstanced;
FText Found; FText::FindText(TEXT("Ns"), TEXT("Key"), Found);
FXRMotionControllerData Data; Sys->GetMotionControllerData(World, Hand, Data);
FCString::Strncat(Dest, Src, 16);
const FVector W = UMovementUtils::ComputeAngularVelocity(A, B, Dt, Turn);
FInputDeviceScope Scope(nullptr, TEXT("Pad"), 0, TEXT("Hw"));
Window->SetType(EWindowType::GameWindow);
FCoreDelegates::OnPostEngineInit.AddRaw(this, &FMyModule::OnInit);
Obj->Rename(nullptr, Outer, REN_ForceNoResetLoaders);
virtual void EditorKeyPressed(FKey Key, EInputEvent Event) override;
"""

ALL_SOURCE_CODES = {
    "any-package", "player-mappable-input-config", "player-mappable-key-slot", "template-requires",
    "is-allowed-to-tick", "non-instanced-ability", "ftext-findtext", "motion-controller-data", "fcstring-strncat",
    "compute-angular-velocity", "input-device-scope", "game-window-type", "on-post-engine-init",
    "ren-force-no-reset-loaders", "editor-key-pressed",
}

SILENT_CPP = """\
// ANY_PACKAGE and FInputDeviceScope in a line comment
/* UPlayerMappableInputConfig
   EWindowType::GameWindow across a block comment */
const TCHAR* A = TEXT("FCoreDelegates::OnPostEngineInit and REN_ForceNoResetLoaders");
const char* B = R"raw(" TEMPLATE_REQUIRES ")raw";
const TCHAR C = '"';
FText Found; FText::FindTextInLiveTable_Advanced(TEXT("Ns"), TEXT("Key"), Found);
const FVector W = UMovementUtils::ComputeAngularVelocityDegrees(A, B, Dt, Turn);
FCoreDelegates::GetOnPostEngineInit().AddRaw(this, &FMyModule::OnInit);
Sys->GetMotionControllerState(World, Hand, State);
const int32 Big = 1'000'000;
"""


class CheckerCase(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "MyGame"
        self.root.mkdir()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def write(self, rel: str, text: str) -> Path:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def uproject(self, association: str = "5.8") -> None:
        self.write("MyGame.uproject", json.dumps({"FileVersion": 3, "EngineAssociation": association}))

    def run_checker(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, "-I", str(CHECKER), str(self.root), *args],
                              capture_output=True, text=True, timeout=60)

    def run_json(self, *args: str) -> tuple[int, dict]:
        proc = self.run_checker("--json", "--max-issues", "0", *args)
        self.assertIn(proc.returncode, (0, 1), proc.stderr)
        return proc.returncode, json.loads(proc.stdout)

    @staticmethod
    def codes(payload: dict, kind: str) -> set[str]:
        return {i["code"] for i in payload[kind]}


class VersionAndUsage(CheckerCase):
    def test_launcher_version_is_read(self) -> None:
        self.uproject("5.8")
        self.write("Config/DefaultEngine.ini", CLEAN_ENGINE_INI)
        rc, data = self.run_json()
        self.assertEqual(rc, 0)
        self.assertEqual(data["engine_version"], "5.8")
        self.assertEqual(data["engine_version_from"], "EngineAssociation")
        self.assertEqual((data["error_count"], data["warning_count"]), (0, 0))

    def test_guid_association_needs_override(self) -> None:
        self.uproject("{0A1B2C3D-0000-1111-2222-333344445555}")
        proc = self.run_checker()
        self.assertEqual(proc.returncode, 2)
        self.assertIn("--engine-version", proc.stderr)
        rc, data = self.run_json("--engine-version", "5.8")
        self.assertEqual(data["engine_version_from"], "--engine-version")

    def test_bad_override_is_usage_error(self) -> None:
        self.uproject("5.8")
        self.assertEqual(self.run_checker("--engine-version", "five").returncode, 2)

    def test_no_or_two_uprojects(self) -> None:
        self.assertEqual(self.run_checker().returncode, 2)
        self.uproject("5.8")
        self.write("Other.uproject", json.dumps({"EngineAssociation": "5.8"}))
        self.assertEqual(self.run_checker().returncode, 2)

    def test_unparseable_uproject(self) -> None:
        self.write("MyGame.uproject", "{not json")
        self.assertEqual(self.run_checker().returncode, 2)

    def test_text_summary_and_strict(self) -> None:
        self.uproject("5.8")
        proc = self.run_checker()
        self.assertEqual(proc.returncode, 0, proc.stdout)
        self.assertIn("zen-process-lifetime", self.run_json()[1]["warnings"][0]["code"])
        self.assertIn("(engine 5.8 from EngineAssociation)", proc.stdout.splitlines()[-1])
        self.assertEqual(self.run_checker("--strict").returncode, 1)

    def test_nothing_is_written(self) -> None:
        self.uproject("5.8")
        self.write("Source/MyGame/A.cpp", DEPRECATED_CPP)
        self.write("Config/DefaultEngine.ini", "[DerivedDataBackendGraph]\nRoot=(Type=KeyLength, Inner=AsyncPut)\n")
        before = sorted((p.as_posix(), p.stat().st_mtime_ns) for p in self.root.rglob("*"))
        self.run_checker("--json")
        after = sorted((p.as_posix(), p.stat().st_mtime_ns) for p in self.root.rglob("*"))
        self.assertEqual(before, after)


class SourceRules(CheckerCase):
    def test_every_rule_fires_on_58(self) -> None:
        self.uproject("5.8")
        self.write("Config/DefaultEngine.ini", CLEAN_ENGINE_INI)
        self.write("Source/MyGame/Private/MyActor.cpp", DEPRECATED_CPP)
        rc, data = self.run_json()
        self.assertEqual(rc, 1)
        self.assertEqual(self.codes(data, "errors"), {"editor-key-pressed", "motion-controller-data"})
        self.assertEqual(self.codes(data, "errors") | self.codes(data, "warnings"), ALL_SOURCE_CODES)
        for issue in data["errors"] + data["warnings"]:
            self.assertTrue(issue["source"].startswith("https://dev.epicgames.com/"), issue)
        any_package = [i for i in data["warnings"] if i["code"] == "any-package"][0]
        self.assertEqual((any_package["file"], any_package["line"]), ("Source/MyGame/Private/MyActor.cpp", 2))

    def test_window_on_54_keeps_only_older_rules(self) -> None:
        self.uproject("5.4")
        self.write("Source/MyGame/MyActor.h", DEPRECATED_CPP)
        rc, data = self.run_json()
        self.assertEqual(rc, 0)
        self.assertEqual(data["errors"], [])
        self.assertEqual(self.codes(data, "warnings"),
                         {"any-package", "player-mappable-input-config", "player-mappable-key-slot"})

    def test_motion_controller_data_deprecated_then_removed(self) -> None:
        self.write("Source/MyGame/Xr.cpp", "FXRMotionControllerData Data;\n")
        self.uproject("5.6")
        self.assertEqual(self.codes(self.run_json()[1], "warnings"), {"motion-controller-data"})
        self.uproject("5.7")
        rc, data = self.run_json()
        self.assertEqual((rc, self.codes(data, "errors")), (1, {"motion-controller-data"}))

    def test_comments_strings_and_successor_names_stay_silent(self) -> None:
        self.uproject("5.8")
        self.write("Config/DefaultEngine.ini", CLEAN_ENGINE_INI)
        self.write("Source/MyGame/Silent.cpp", SILENT_CPP + "UObject* Late = FindObject<UEnum>(ANY_PACKAGE, TEXT(\"E\"));\n")
        rc, data = self.run_json()
        self.assertEqual(data["errors"], [])
        self.assertEqual([(i["code"], i["line"]) for i in data["warnings"]],
                         [("any-package", SILENT_CPP.count("\n") + 1)])

    def test_dead_and_version_guarded_branches_stay_silent(self) -> None:
        self.uproject("5.7")
        self.write("Source/MyGame/Xr.cpp",
                   "#if ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION < 7\n"
                   "FXRMotionControllerData Data;\n"
                   "#else\n"
                   "FXRMotionControllerState State;\n"
                   "#endif\n"
                   "#if !UE_VERSION_NEWER_THAN(5, 6, 0)\n"
                   "#ifdef WITH_XR\n"
                   "Sys->GetMotionControllerData(World, Hand, Data);\n"
                   "#endif\n"
                   "#endif\n"
                   "#if 0 // kept for reference\n"
                   "FXRMotionControllerData Old;\n"
                   "#endif\n")
        rc, data = self.run_json()
        self.assertEqual((rc, data["errors"], data["warnings"]), (0, [], []))

    def test_live_branches_around_guards_still_fire(self) -> None:
        self.uproject("5.7")
        self.write("Source/MyGame/Xr.cpp",
                   "#if WITH_EDITOR\n"
                   "FXRMotionControllerData A;\n"
                   "#endif\n"
                   "#if 0\n"
                   "FXRMotionControllerData B;\n"
                   "#else\n"
                   "FXRMotionControllerData C;\n"
                   "#endif\n"
                   "#ifdef WITH_XR\n"
                   "#if ENGINE_MINOR_VERSION < 7\n"
                   "FXRMotionControllerData D;\n"
                   "#endif\n"
                   "FXRMotionControllerData E;\n"
                   "#endif\n"
                   "FXRMotionControllerData F;\n")
        rc, data = self.run_json()
        self.assertEqual((rc, [(i["code"], i["line"]) for i in data["errors"]]),
                         (1, [("motion-controller-data", n) for n in (2, 7, 13, 15)]))

    def test_other_suffixes_and_plugins_are_not_scanned(self) -> None:
        self.uproject("5.8")
        self.write("Config/DefaultEngine.ini", CLEAN_ENGINE_INI)
        self.write("Source/MyGame/Notes.txt", "ANY_PACKAGE\n")
        self.write("Plugins/Other/Source/Other/Other.cpp", "ANY_PACKAGE\n")
        rc, data = self.run_json()
        self.assertEqual((data["error_count"], data["warning_count"]), (0, 0))


class ConfigRules(CheckerCase):
    def test_zen_and_ddc_findings_on_58(self) -> None:
        self.uproject("5.8")
        self.write("Config/DefaultEngine.ini",
                   "[Zen.AutoLaunch]\nLimitProcessLifetime=true\nAllowRemoteNetworkService=true\n"
                   "\n[DerivedDataBackendGraph]\nRoot=(Type=KeyLength, Length=120, Inner=AsyncPut)\n"
                   "AsyncPut=(Type=AsyncPut, Inner=Hierarchy)\n")
        self.write("Config/Windows/WindowsEngine.ini", "[Zen.AutoLaunch]\nRemoteNetworkService=true\n")
        rc, data = self.run_json()
        self.assertEqual(rc, 0)
        found = sorted((i["code"], i["file"], i["line"]) for i in data["warnings"])
        self.assertEqual(found, [
            ("ddc-deprecated-node", "Config/DefaultEngine.ini", 6),
            ("ddc-deprecated-node", "Config/DefaultEngine.ini", 7),
            ("ddc-legacy-graph", "Config/DefaultEngine.ini", 5),
            ("zen-process-lifetime", "Config/DefaultEngine.ini", 2),
            ("zen-remote-key-renamed", "Config/DefaultEngine.ini", 3),
            ("zen-remote-value", "Config/Windows/WindowsEngine.ini", 2),
        ])

    def test_missing_lifetime_points_at_default_engine(self) -> None:
        self.uproject("5.8")
        rc, data = self.run_json()
        self.assertEqual([(i["code"], i["file"], i["line"]) for i in data["warnings"]],
                         [("zen-process-lifetime", "Config/DefaultEngine.ini", None)])

    def test_zen_store_disabled_silences_lifetime(self) -> None:
        self.uproject("5.8")
        self.write("Config/DefaultGame.ini", "[/Script/UnrealEd.ProjectPackagingSettings]\nbUseZenStore=False\n")
        self.assertEqual(self.run_json()[1]["warnings"], [])

    def test_57_config_stays_silent(self) -> None:
        self.uproject("5.7")
        self.write("Config/DefaultEngine.ini",
                   "[Zen.AutoLaunch]\nAllowRemoteNetworkService=true\n[DerivedDataBackendGraph]\nRoot=(Type=KeyLength)\n")
        rc, data = self.run_json()
        self.assertEqual((rc, data["warning_count"], data["error_count"]), (0, 0, 0))

    def test_commented_keys_stay_silent(self) -> None:
        self.uproject("5.8")
        self.write("Config/DefaultEngine.ini",
                   "[Zen.AutoLaunch]\nLimitProcessLifetime=false\n;AllowRemoteNetworkService=true\n"
                   "; [DerivedDataBackendGraph]\n;Root=(Type=KeyLength)\n")
        self.assertEqual(self.run_json()[1]["warnings"], [])


if __name__ == "__main__":
    unittest.main()
