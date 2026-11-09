#!/usr/bin/env python3
"""Catches, for the engine version in the .uproject (or --engine-version), Zen and DDC keys in Config/*.ini that UE 5.8 renamed,
deprecated or asks CI to set, and C++ names in Source/**/*.cpp|h that Epic's release notes deprecate or remove (each rule cites them).
Does NOT compile or resolve types: a name is matched as written outside comments and strings, so an alias or macro hides it."""
# Why, limits, history: rationale/derivations/plugin-unreal.md § plugins/unreal/scripts/check_unreal_project.py

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

TOOL = "check_unreal_project"
SCHEMA = 1
FOREVER = None

RN = "https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-{}-release-notes?application_version={}"
RN51 = RN.format("5.1", "5.1")
RN53 = RN.format("5-3", "5.3")
RN55 = RN.format("5-5", "5.5")
RN56 = RN.format("5-6", "5.6")
RN57 = RN.format("5-7", "5.7")
RN58 = RN.format("5-8", "5.8")

# deprecated: first version that warns; removed: first version that errors.
RULES = [
    dict(id="any-package", pattern=r"\bANY_PACKAGE\b", deprecated=(5, 1), removed=FOREVER, source=RN51,
         msg="ANY_PACKAGE object lookup is deprecated since 5.1",
         fix='pass the Outer or a full path, e.g. FindObject<UClass>(nullptr, TEXT("/Script/Engine.Actor")); FindFirstObject where neither is known'),
    dict(id="player-mappable-input-config", pattern=r"\bUPlayerMappableInputConfig\b", deprecated=(5, 3), removed=FOREVER, source=RN53,
         msg="UPlayerMappableInputConfig is deprecated since 5.3",
         fix="rebind through UEnhancedInputUserSettings, with Player Mappable Key Settings on the Input Action or Mapping Context"),
    dict(id="player-mappable-key-slot", pattern=r"\bFPlayerMappableKeySlot\b", deprecated=(5, 3), removed=FOREVER, source=RN53,
         msg="FPlayerMappableKeySlot and its player-mapped key functions are deprecated since 5.3",
         fix="rebind through UEnhancedInputUserSettings"),
    dict(id="template-requires", pattern=r"\bTEMPLATE_REQUIRES\b", deprecated=(5, 5), removed=FOREVER, source=RN55,
         msg="TEMPLATE_REQUIRES is deprecated since 5.5",
         fix="UE_REQUIRES (the syntax differs: read the macro's comment)"),
    dict(id="is-allowed-to-tick", pattern=r"\bIsAllowedToTick\s*\(", deprecated=(5, 5), removed=FOREVER, source=RN55,
         msg="FTickableObjectBase::IsAllowedToTick is deprecated since 5.5",
         fix="override IsTickable, or switch ticking with SetTickableTickType"),
    dict(id="non-instanced-ability", pattern=r"::\s*NonInstanced\b", deprecated=(5, 5), removed=FOREVER, source=RN55,
         msg="NonInstanced Gameplay Abilities are deprecated since 5.5",
         fix="InstancedPerActor or InstancedPerExecution"),
    dict(id="ftext-findtext", pattern=r"\bFText\s*::\s*FindText\s*\(", deprecated=(5, 5), removed=FOREVER, source=RN55,
         msg="FText::FindText is deprecated since 5.5: it can no longer find untranslated text",
         fix="FText::FindTextInLiveTable_Advanced or FText::AsLocalizable_Advanced (argument order differs)"),
    dict(id="motion-controller-data", pattern=r"\b(?:GetMotionControllerData|FXRMotionControllerData)\b", deprecated=(5, 5), removed=(5, 7),
         source=RN57, msg="GetMotionControllerData and FXRMotionControllerData were deprecated in 5.5 and removed in 5.7",
         fix="GetMotionControllerState and/or GetHandTrackingState"),
    dict(id="fcstring-strncat", pattern=r"\bFCString\s*::\s*Strncat\b", deprecated=(5, 6), removed=FOREVER, source=RN56,
         msg="FCString::Strncat is deprecated since 5.6: it means something else than C++ strncat",
         fix="FPlatformString::Strncat, which takes the source length as CRT strncat does"),
    dict(id="compute-angular-velocity", pattern=r"\bUMovementUtils\s*::\s*ComputeAngularVelocity\b", deprecated=(5, 7), removed=FOREVER,
         source=RN57, msg="UMovementUtils::ComputeAngularVelocity is deprecated since 5.7",
         fix="UMovementUtils::ComputeAngularVelocityDegrees"),
    dict(id="input-device-scope", pattern=r"\bFInputDeviceScope\b", deprecated=(5, 8), removed=FOREVER, source=RN58,
         msg="FInputDeviceScope is deprecated in 5.8 and a no-op unless the Target.cs defines UE_USE_LEGACY_INPUT_DEVICE_SCOPE=1",
         fix="FInputDeviceRegistry"),
    dict(id="game-window-type", pattern=r"\bEWindowType\s*::\s*GameWindow\b", deprecated=(5, 8), removed=FOREVER, source=RN58,
         msg="EWindowType::GameWindow is deprecated in 5.8",
         fix="EWindowType::Normal"),
    dict(id="on-post-engine-init", pattern=r"\bFCoreDelegates\s*::\s*OnPostEngineInit\b", deprecated=(5, 8), removed=FOREVER, source=RN58,
         msg="FCoreDelegates::OnPostEngineInit is deprecated in 5.8: registrations made during static initialization went missing",
         fix="FCoreDelegates::GetOnPostEngineInit()"),
    dict(id="ren-force-no-reset-loaders", pattern=r"\bREN_ForceNoResetLoaders\b", deprecated=(5, 8), removed=FOREVER, source=RN58,
         msg="REN_ForceNoResetLoaders is deprecated in 5.8: UObject::Rename no longer resets loaders",
         fix="drop the flag"),
    dict(id="editor-key-pressed", pattern=r"\bEditorKeyPressed\s*\(", deprecated=FOREVER, removed=(5, 8), source=RN58,
         msg="AActor::EditorKeyPressed was removed in 5.8: an override of it no longer compiles",
         fix="delete the override"),
]
for _rule in RULES:
    _rule["regex"] = re.compile(_rule["pattern"])

ZEN_SECTION = "zen.autolaunch"
REMOTE_VALUES = {"none", "unsecured", "generatedstatickey"}
FALSE_VALUES = {"false", "0", "no", "off"}
DDC_LEGACY_SECTION = "deriveddatabackendgraph"
DDC_DEPRECATED_NODE = re.compile(r"\bType\s*=\s*(KeyLength|AsyncPut|Verify)\b", re.I)
INI_KEY = re.compile(r"^[+\-.!@*]?([A-Za-z0-9_.]+)\s*=\s*(.*)$")
CPP_SUFFIXES = {".cpp", ".h"}


@dataclass
class Issue:
    severity: str  # "error" or "warning"
    code: str
    file: str
    line: int | None
    message: str
    fix: str
    source: str

    def as_dict(self) -> dict:
        return {"code": self.code, "file": self.file, "line": self.line, "message": self.message,
                "fix": self.fix, "source": self.source}


def read_text(path: Path) -> str:
    text = path.read_bytes().decode("utf-8", errors="replace")
    if text.startswith("\ufeff"):
        text = text[1:]
    return text.replace("\r\n", "\n").replace("\r", "\n")


def parse_version(text: str) -> tuple[int, int] | None:
    m = re.fullmatch(r"\s*(\d+)\.(\d+)(?:\.\d+)?\s*", text or "")
    return (int(m.group(1)), int(m.group(2))) if m else None


def blank_cpp(text: str) -> str:
    """Replace C++ comments, string and char literals with spaces, keeping every newline."""
    out = list(text)
    n = len(text)
    i = 0

    def blank(a: int, b: int) -> None:
        for k in range(a, min(b, n)):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        c = text[i]
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            blank(i, j)
            i = j
        elif c == '"':
            raw = re.search(r'(?:^|[^A-Za-z0-9_])(?:u8|u|U|L)?R$', text[max(0, i - 4):i])
            if raw:
                m = re.match(r'"([^()\\\s]{0,16})\(', text[i:])
                if m:
                    end = text.find(")" + m.group(1) + '"', i + m.end())
                    j = n if end < 0 else end + len(m.group(1)) + 2
                    blank(i, j)
                    i = j
                    continue
            j = i + 1
            while j < n and text[j] not in '"\n':
                j += 2 if text[j] == "\\" else 1
            blank(i, j + 1)
            i = j + 1
        elif c == "'":
            if i > 0 and (text[i - 1].isalnum() or text[i - 1] == "_"):
                i += 1  # digit separator, as in 1'000'000
                continue
            j = i + 1
            while j < n and text[j] not in "'\n":
                j += 2 if text[j] == "\\" else 1
            blank(i, j + 1)
            i = j + 1
        else:
            i += 1
    return "".join(out)


def parse_ini(text: str):
    """Yield (line, section, key, value) for each key line; section and key lower-cased."""
    section = ""
    for lineno, raw in enumerate(text.split("\n"), start=1):
        line = raw.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip().lower()
            yield lineno, section, None, None
            continue
        m = INI_KEY.match(line)
        if m:
            yield lineno, section, m.group(1).lower(), m.group(2).strip()


class Project:
    def __init__(self, root: Path, version: tuple[int, int]):
        self.root = root
        self.version = version
        self.issues: list[Issue] = []
        self.files_checked = 0

    def rel(self, path: Path) -> str:
        return path.relative_to(self.root).as_posix()

    def add(self, severity: str, code: str, file: str, line: int | None, message: str, fix: str, source: str) -> None:
        self.issues.append(Issue(severity, code, file, line, message, fix, source))

    def load(self, path: Path) -> str | None:
        try:
            text = read_text(path)
        except OSError as exc:
            self.add("warning", "unreadable", self.rel(path), None, f"could not read the file: {exc.strerror or exc}",
                     "check the file's permissions; it was skipped", "")
            return None
        self.files_checked += 1
        return text

    def check_config(self) -> None:
        if self.version < (5, 8):
            return
        config = self.root / "Config"
        inis = sorted(p for p in config.rglob("*") if p.is_file() and p.suffix.lower() == ".ini") if config.is_dir() else []
        zen_store_off = False
        lifetime_seen: list[tuple[str, int, str]] = []
        for path in inis:
            text = self.load(path)
            if text is None:
                continue
            rel = self.rel(path)
            for lineno, section, key, value in parse_ini(text):
                if key is None:
                    if section == DDC_LEGACY_SECTION:
                        self.add("warning", "ddc-legacy-graph", rel, lineno,
                                 "UE 5.8 configures DDC graphs in [DerivedDataCacheGraphs] and stores in [DerivedDataCacheStores]; "
                                 "this [DerivedDataBackendGraph] section is the pre-5.8 layout",
                                 "move the graph and its stores to the 5.8 sections; LogDerivedDataCache at editor start shows "
                                 "which graph loaded", RN58)
                    continue
                if key == "allowremotenetworkservice":
                    self.add("warning", "zen-remote-key-renamed", rel, lineno,
                             "AllowRemoteNetworkService was renamed RemoteNetworkService in 5.8 and no longer takes true/false",
                             "RemoteNetworkService=None, Unsecured or GeneratedStaticKey (the default)", RN58)
                elif key == "remotenetworkservice" and value.lower() not in REMOTE_VALUES:
                    self.add("warning", "zen-remote-value", rel, lineno,
                             f"RemoteNetworkService={value} is not one of None, Unsecured, GeneratedStaticKey",
                             "set one of those three values", RN58)
                elif key == "limitprocesslifetime" and section == ZEN_SECTION:
                    lifetime_seen.append((rel, lineno, value))
                elif key == "busezenstore" and section.endswith("projectpackagingsettings") and rel == "Config/DefaultGame.ini":
                    zen_store_off = value.lower() in FALSE_VALUES
                if DDC_DEPRECATED_NODE.search(value or ""):
                    node = DDC_DEPRECATED_NODE.search(value).group(1)
                    self.add("warning", "ddc-deprecated-node", rel, lineno,
                             f"the {node} DDC graph node is deprecated in 5.8",
                             "drop it: AsyncPut is created automatically, Verify comes from the -DDC-Verify argument", RN58)
        if zen_store_off:
            return
        if not any(v.lower() in FALSE_VALUES for _, _, v in lifetime_seen):
            where, line = (lifetime_seen[-1][0], lifetime_seen[-1][1]) if lifetime_seen else ("Config/DefaultEngine.ini", None)
            self.add("warning", "zen-process-lifetime", where, line,
                     "Zenserver is the cooked output store by default in 5.8, and [Zen.AutoLaunch] LimitProcessLifetime=false "
                     "is not set, so zenserver starts and stops frequently",
                     "for team and CI machines add LimitProcessLifetime=false under [Zen.AutoLaunch] in DefaultEngine.ini",
                     RN58)

    def check_source(self) -> None:
        active = []
        for rule in RULES:
            if rule["removed"] is not FOREVER and self.version >= rule["removed"]:
                active.append((rule, "error"))
            elif rule["deprecated"] is not FOREVER and self.version >= rule["deprecated"]:
                active.append((rule, "warning"))
        source = self.root / "Source"
        if not source.is_dir():
            return
        files = sorted(p for p in source.rglob("*") if p.is_file() and p.suffix.lower() in CPP_SUFFIXES)
        for path in files:
            text = self.load(path)
            if text is None or not active:
                continue
            rel = self.rel(path)
            for lineno, line in enumerate(blank_cpp(text).split("\n"), start=1):
                for rule, severity in active:
                    if rule["regex"].search(line):
                        self.add(severity, rule["id"], rel, lineno, rule["msg"], rule["fix"], rule["source"])


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="check_unreal_project.py",
        description=(
            "Read-only check of an Unreal Engine 5 project for the engine version in its .uproject:\n"
            "Zen and DDC keys in Config/*.ini that 5.8 renamed, deprecated or asks CI to set, and C++ names\n"
            "in Source/**/*.cpp|h that Epic's release notes deprecate (warning) or remove (error)."
        ),
        epilog=(
            "example:\n"
            '  python3 "$CLAUDE_PLUGIN_ROOT/scripts/check_unreal_project.py" path/to/MyGame\n'
            '  python3 "$CLAUDE_PLUGIN_ROOT/scripts/check_unreal_project.py" . --json --engine-version 5.8\n\n'
            "exit codes: 0 no errors, 1 errors found (or warnings with --strict),\n"
            "            2 usage problem, no single .uproject, or an engine version it cannot read"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("project_dir", nargs="?", default=".", metavar="PROJECT_DIR",
                        help="folder that holds the .uproject (default: current folder)")
    parser.add_argument("--engine-version", metavar="X.Y",
                        help="engine version to check against; needed when EngineAssociation is a source-build GUID")
    parser.add_argument("--json", action="store_true", help="print one JSON object instead of text")
    parser.add_argument("--strict", action="store_true", help="exit 1 when there are warnings too")
    parser.add_argument("--max-issues", type=int, default=50, metavar="N",
                        help="print at most N issues, errors first (default: 50; 0 = no limit)")
    return parser


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="backslashreplace")
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.max_issues < 0:
        parser.error("--max-issues must be 0 or more")
    root = Path(args.project_dir).expanduser()
    if not root.is_dir():
        print(f"error: {args.project_dir} is not a folder", file=sys.stderr)
        return 2
    root = root.resolve()
    uprojects = sorted(p for p in root.glob("*.uproject") if p.is_file())
    if len(uprojects) != 1:
        found = "no .uproject" if not uprojects else f"{len(uprojects)} .uproject files"
        print(f"error: {args.project_dir} holds {found}; point at the folder with exactly one", file=sys.stderr)
        return 2
    association = ""
    try:
        data = json.loads(read_text(uprojects[0]))
        association = str(data.get("EngineAssociation", "")) if isinstance(data, dict) else ""
    except (OSError, ValueError) as exc:
        if not args.engine_version:
            print(f"error: cannot read {uprojects[0].name} as JSON ({exc}); pass --engine-version X.Y", file=sys.stderr)
            return 2
    if args.engine_version:
        version, origin = parse_version(args.engine_version), "--engine-version"
        if version is None:
            parser.error(f"--engine-version must look like 5.8, not {args.engine_version!r}")
    else:
        version, origin = parse_version(association), "EngineAssociation"
        if version is None:
            print(f"error: EngineAssociation {association!r} in {uprojects[0].name} is not a version (a GUID or empty "
                  "value means a source build); read that engine's Engine/Build/Build.version and pass "
                  "--engine-version X.Y", file=sys.stderr)
            return 2

    project = Project(root, version)
    project.check_config()
    project.check_source()

    def sort_key(issue: Issue) -> tuple:
        return (issue.file, issue.line or 0, issue.code)

    errors = sorted((i for i in project.issues if i.severity == "error"), key=sort_key)
    warnings = sorted((i for i in project.issues if i.severity == "warning"), key=sort_key)
    ordered = errors + warnings
    shown = ordered[: args.max_issues] if args.max_issues else ordered
    truncated = len(ordered) > len(shown)
    engine = f"{version[0]}.{version[1]}"

    if args.json:
        payload = {
            "tool": TOOL,
            "schema": SCHEMA,
            "root": root.as_posix(),
            "engine_version": engine,
            "engine_version_from": origin,
            "files_checked": project.files_checked,
            "error_count": len(errors),
            "warning_count": len(warnings),
            "errors": [i.as_dict() for i in shown if i.severity == "error"],
            "warnings": [i.as_dict() for i in shown if i.severity == "warning"],
            "truncated": truncated,
        }
        print(json.dumps(payload, indent=2))
    else:
        for issue in shown:
            where = f"{issue.file}:{issue.line}" if issue.line else issue.file
            print(f"{issue.severity.upper()} {where}: {issue.message}")
            print(f"  fix: {issue.fix}")
        if truncated:
            print(f"... and {len(ordered) - len(shown)} more")
        print(f"Summary: {len(errors)} errors, {len(warnings)} warnings in {project.files_checked} files checked "
              f"(engine {engine} from {origin})")

    if errors or (args.strict and warnings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
