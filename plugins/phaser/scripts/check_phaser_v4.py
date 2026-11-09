#!/usr/bin/env python3
"""Catches, in a Phaser 4 project (major from package.json, or --major), Math.PI2 (removed), type: Phaser.CANVAS (deprecated renderer),
and a RenderTexture/DynamicTexture created and drawn to in one src file whose render() is never called there. Phaser 3 stays silent.
Does NOT run the game or follow values across files: a texture rendered elsewhere, an aliased Math or a destructured PI2 go unseen."""
# Why, limits, history: rationale/derivations/plugin-phaser.md § plugins/phaser/scripts/check_phaser_v4.py

from __future__ import annotations

import argparse
import bisect
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

TOOL = "check_phaser_v4"
SCHEMA = 1
GUIDE = "https://github.com/phaserjs/phaser/blob/master/changelog/v4/4.0/MIGRATION-GUIDE.md"
SUFFIXES = {".js", ".mjs", ".cjs", ".jsx", ".ts", ".mts", ".cts", ".tsx"}
SKIP_DIRS = {"node_modules", ".git", "dist", "build"}
DEP_KEYS = ("dependencies", "devDependencies", "peerDependencies", "optionalDependencies")
DRAW_METHODS = {"draw", "fill", "stamp", "erase", "capture", "repeat"}

PI2_RE = re.compile(r"\bMath\s*\.\s*PI2\b")
CANVAS_RE = re.compile(r"\btype\s*:\s*Phaser\s*\.\s*CANVAS\b")
CREATE_RE = re.compile(
    r"(?:\.\s*(?:add|make)\s*\.\s*renderTexture"
    r"|\.\s*textures\s*\.\s*addDynamicTexture"
    r"|\bnew\s+(?:Phaser\s*\.\s*GameObjects\s*\.\s*)?RenderTexture"
    r"|\bnew\s+(?:Phaser\s*\.\s*Textures\s*\.\s*)?DynamicTexture)\s*\("
)
ASSIGN_RE = re.compile(
    r"(?:\b(?:const|let|var)\s+)?(?<![\w$.])((?:[A-Za-z_$][\w$]*\s*\.\s*)*[A-Za-z_$][\w$]*)\s*(?::\s*[\w$.<>\[\]|\s]+?)?\s*"
    r"(?<![=!<>])=(?!=)\s*"
    r"(?:[A-Za-z_$][\w$]*(?:\s*\.\s*[A-Za-z_$][\w$]*)*)?\s*$"
)
IDENT_RE = re.compile(r"[A-Za-z_$][\w$]*")
REGEX_PREV = set("(,=:[!&|?{};+-*%<>~^")
REGEX_WORDS = {"return", "typeof", "case", "do", "else", "in", "of", "new", "delete", "void", "throw", "yield", "await"}


@dataclass
class Issue:
    severity: str  # "error" or "warning"
    code: str
    file: str
    line: int | None
    message: str
    fix: str

    def as_dict(self) -> dict:
        return {"code": self.code, "file": self.file, "line": self.line, "message": self.message, "fix": self.fix,
                "source": GUIDE}


def read_text(path: Path) -> str:
    text = path.read_bytes().decode("utf-8", errors="replace")
    if text.startswith("\ufeff"):
        text = text[1:]
    return text.replace("\r\n", "\n").replace("\r", "\n")


def blank_js(text: str) -> tuple[str, str]:
    """Return (code, code_with_strings): comments blanked in both, string/template/regex literal bodies blanked in code."""
    code = list(text)
    keep = list(text)
    n = len(text)

    def blank(buf: list[str], a: int, b: int) -> None:
        for k in range(a, min(b, n)):
            if buf[k] != "\n":
                buf[k] = " "

    def string_end(i: int, quote: str) -> int:
        j = i + 1
        while j < n and text[j] != quote and text[j] != "\n":
            j += 2 if text[j] == "\\" else 1
        return min(j + 1, n)

    def template_end(i: int) -> int:
        j = i + 1
        while j < n:
            c = text[j]
            if c == "\\":
                j += 2
            elif c == "`":
                return j + 1
            elif c == "$" and j + 1 < n and text[j + 1] == "{":
                j = code_end(j + 2, "}")
            else:
                j += 1
        return n

    def code_end(i: int, closer: str) -> int:
        depth = 0
        j = i
        while j < n:
            c = text[j]
            if c in "'\"":
                j = string_end(j, c)
            elif c == "`":
                j = template_end(j)
            elif c == "{":
                depth += 1
                j += 1
            elif c == "}":
                if depth == 0:
                    return j + 1
                depth -= 1
                j += 1
            else:
                j += 1
        return n

    def regex_end(i: int) -> int | None:
        j = i + 1
        in_class = False
        while j < n:
            c = text[j]
            if c == "\n":
                return None
            if c == "\\":
                j += 2
                continue
            if c == "[":
                in_class = True
            elif c == "]":
                in_class = False
            elif c == "/" and not in_class:
                j += 1
                while j < n and (text[j].isalnum() or text[j] == "_"):
                    j += 1
                return j
            j += 1
        return None

    def regex_allowed(i: int) -> bool:
        k = i - 1
        while k >= 0 and text[k] in " \t\n":
            k -= 1
        if k < 0 or text[k] in REGEX_PREV:
            return True
        m = re.search(r"[A-Za-z_$][\w$]*$", text[max(0, k - 12):k + 1])
        return bool(m and m.group(0) in REGEX_WORDS)

    i = 0
    while i < n:
        c = text[i]
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            j = n if j < 0 else j
            blank(code, i, j)
            blank(keep, i, j)
            i = j
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            blank(code, i, j)
            blank(keep, i, j)
            i = j
        elif c in "'\"":
            j = string_end(i, c)
            blank(code, i + 1, j - 1)
            i = j
        elif c == "`":
            j = template_end(i)
            blank(code, i + 1, j - 1)
            i = j
        elif c == "/" and regex_allowed(i):
            j = regex_end(i)
            if j is None:
                i += 1
                continue
            blank(code, i + 1, j)
            i = j
        else:
            i += 1
    return "".join(code), "".join(keep)


def skip_ws(code: str, i: int) -> int:
    while i < len(code) and code[i] in " \t\n":
        i += 1
    return i


def skip_parens(code: str, i: int) -> int:
    """i is at an opening bracket; return the index after its partner (strings are already blanked)."""
    depth = 0
    for j in range(i, len(code)):
        if code[j] in "([{":
            depth += 1
        elif code[j] in ")]}":
            depth -= 1
            if depth == 0:
                return j + 1
    return len(code)


def walk_chain(code: str, i: int) -> list[tuple[str, int, int | None]]:
    """From i, collect each `.name` / `.name(...)` link as (name, position, index of its '(' or None)."""
    links = []
    while True:
        j = skip_ws(code, i)
        if code.startswith("?.", j):
            j += 1
        if j >= len(code) or code[j] != ".":
            return links
        m = IDENT_RE.match(code, skip_ws(code, j + 1))
        if not m:
            return links
        k = skip_ws(code, m.end())
        if k < len(code) and code[k] == "(":
            links.append((m.group(0), m.start(), k))
            i = skip_parens(code, k)
        else:
            links.append((m.group(0), m.start(), None))
            i = m.end()


def first_string_arg(code_str: str, paren: int) -> str | None:
    m = re.match(r"\(\s*(['\"`])([^'\"`\n]*)\1", code_str[paren:])
    return m.group(2) if m else None


def parse_major(spec: str) -> int | None:
    """The major a package.json range pins, or None when it does not pin exactly one."""
    s = spec.strip()
    if s.startswith("npm:"):
        s = s.rpartition("@")[2]
    if "||" in s or " - " in s or re.search(r"[<>*]|^x$|\s", s):
        return None
    m = re.fullmatch(r"[\^~=v]*\s*(\d+)(?:\.(?:\d+|x|\*)){0,2}(?:-[0-9A-Za-z.-]+)?", s)
    return int(m.group(1)) if m else None


class Scan:
    def __init__(self, root: Path, src: Path):
        self.root = root
        self.src = src
        self.issues: list[Issue] = []
        self.files_checked = 0

    def add(self, severity: str, code: str, rel: str, line: int | None, message: str, fix: str) -> None:
        self.issues.append(Issue(severity, code, rel, line, message, fix))

    def files(self) -> list[Path]:
        out = []
        for path in sorted(self.src.rglob("*")):
            if any(part in SKIP_DIRS for part in path.relative_to(self.src).parts[:-1]):
                continue
            if path.is_file() and path.suffix.lower() in SUFFIXES and not path.name.endswith(".d.ts"):
                out.append(path)
        return out

    def run(self) -> None:
        for path in self.files():
            rel = path.relative_to(self.root).as_posix()
            try:
                text = read_text(path)
            except OSError as exc:
                self.add("warning", "unreadable", rel, None, f"could not read the file: {exc.strerror or exc}",
                         "check the file's permissions; it was skipped")
                continue
            self.files_checked += 1
            self.check_file(rel, text)

    def check_file(self, rel: str, text: str) -> None:
        code, code_str = blank_js(text)
        starts = [0] + [m.end() for m in re.finditer(r"\n", code)]

        def line_of(pos: int) -> int:
            return bisect.bisect_right(starts, pos)

        for m in PI2_RE.finditer(code):
            self.add("error", "pi2-removed", rel, line_of(m.start()),
                     "Math.PI2 was removed in Phaser 4: it reads undefined, so angle maths built on it gives NaN",
                     "use Phaser.Math.TAU, which is 2 * Math.PI in Phaser 4")
        for m in CANVAS_RE.finditer(code):
            self.add("warning", "canvas-renderer", rel, line_of(m.start()),
                     "the Canvas renderer is deprecated in Phaser 4 and supports none of its WebGL rendering features",
                     "type: Phaser.AUTO or Phaser.WEBGL; keep CANVAS only for a Canvas blend mode, which the Blend filter "
                     "can recreate in WebGL")

        targets: dict[str, dict] = {}
        for m in CREATE_RE.finditer(code):
            prefix = code[max(0, m.start() - 200):m.start()]
            prefix = prefix[max(prefix.rfind(";"), prefix.rfind("{"), prefix.rfind("}")) + 1:]
            am = ASSIGN_RE.search(prefix)
            name = re.sub(r"\s+", "", am.group(1)) if am else f"<line {line_of(m.start())}>"
            state = targets.setdefault(name, {"draws": [], "rendered": False, "auto": False})
            self.collect(state, walk_chain(code, skip_parens(code, m.end() - 1)), code_str)
        for name, state in targets.items():
            if name.startswith("<"):
                continue
            pattern = r"\s*\.\s*".join(re.escape(part) for part in name.split("."))
            for m in re.finditer(r"(?<![\w$.])" + pattern + r"(?![\w$])", code):
                self.collect(state, walk_chain(code, m.end()), code_str)
                tail = re.match(r"\s*\.\s*renderMode\s*=(?!=)\s*", code[m.end():])
                if tail:
                    value = re.match(r"(['\"`])([^'\"`\n]*)\1", code_str[m.end() + tail.end():])
                    if not value or value.group(2) != "render":
                        state["auto"] = True
        for name, state in targets.items():
            if state["draws"] and not state["rendered"] and not state["auto"]:
                pos, method = state["draws"][0]
                shown = "the texture created here" if name.startswith("<") else f"`{name}`"
                self.add("error", "render-missing", rel, line_of(pos),
                         f"{shown} gets .{method}() but no .render() in this file: Phaser 4 RenderTexture and "
                         "DynamicTexture buffer draw commands until render() runs them",
                         f"call {'render()' if name.startswith('<') else name + '.render()'} after the draw calls, "
                         "or setRenderMode('redraw') / ('all') on a RenderTexture to render every frame")

    @staticmethod
    def collect(state: dict, links: list[tuple[str, int, int | None]], code_str: str) -> None:
        for method, pos, paren in links:
            if paren is None:
                continue
            if method == "render":
                state["rendered"] = True
            elif method in DRAW_METHODS:
                state["draws"].append((pos, method))
            elif method == "setRenderMode" and first_string_arg(code_str, paren) != "render":
                state["auto"] = True


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="check_phaser_v4.py",
        description=(
            "Read-only check of a Phaser 4 project's source for three v3 habits the v4 migration guide breaks:\n"
            "Math.PI2 (removed), type: Phaser.CANVAS (deprecated renderer), and a RenderTexture or\n"
            "DynamicTexture drawn to with no render() call in the same file. A Phaser 3 project is skipped."
        ),
        epilog=(
            "example:\n"
            '  python3 "$CLAUDE_PLUGIN_ROOT/scripts/check_phaser_v4.py" path/to/game\n'
            '  python3 "$CLAUDE_PLUGIN_ROOT/scripts/check_phaser_v4.py" . --json --src game/src\n\n'
            "exit codes: 0 no errors (or not Phaser 4), 1 errors found (or warnings with --strict),\n"
            "            2 usage problem, no package.json or phaser dependency, a range with no single major, or no src folder"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("project_dir", nargs="?", default=".", metavar="PROJECT_DIR",
                        help="folder that holds package.json (default: current folder)")
    parser.add_argument("--src", default="src", metavar="DIR", help="source folder under PROJECT_DIR (default: src)")
    parser.add_argument("--major", type=int, metavar="N",
                        help="Phaser major to assume when the package.json range does not pin one")
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
    try:
        manifest = json.loads(read_text(root / "package.json"))
    except FileNotFoundError:
        print(f"error: no package.json in {args.project_dir}", file=sys.stderr)
        return 2
    except (OSError, ValueError) as exc:
        print(f"error: cannot read package.json as JSON ({exc})", file=sys.stderr)
        return 2
    spec = None
    for key in DEP_KEYS:
        deps = manifest.get(key) if isinstance(manifest, dict) else None
        if isinstance(deps, dict) and isinstance(deps.get("phaser"), str):
            spec = deps["phaser"]
            break
    if spec is None:
        print("error: package.json declares no phaser dependency", file=sys.stderr)
        return 2
    major = args.major if args.major is not None else parse_major(spec)
    if major is None:
        print(f"error: the phaser range {spec!r} does not pin one major; pass --major 4 (or 3)", file=sys.stderr)
        return 2

    scan = Scan(root, root / args.src)
    note = ""
    if major == 4:
        if not scan.src.is_dir():
            print(f"error: no {args.src}/ folder under {args.project_dir}; pass --src DIR", file=sys.stderr)
            return 2
        scan.run()
    else:
        note = f"phaser {spec!r} is major {major}: the checks cover Phaser 4 only, nothing was scanned"

    errors = sorted((i for i in scan.issues if i.severity == "error"), key=lambda i: (i.file, i.line or 0, i.code))
    warnings = sorted((i for i in scan.issues if i.severity == "warning"), key=lambda i: (i.file, i.line or 0, i.code))
    ordered = errors + warnings
    shown = ordered[: args.max_issues] if args.max_issues else ordered
    truncated = len(ordered) > len(shown)

    if args.json:
        payload = {
            "tool": TOOL,
            "schema": SCHEMA,
            "root": root.as_posix(),
            "phaser_range": spec,
            "phaser_major": major,
            "files_checked": scan.files_checked,
            "error_count": len(errors),
            "warning_count": len(warnings),
            "errors": [i.as_dict() for i in shown if i.severity == "error"],
            "warnings": [i.as_dict() for i in shown if i.severity == "warning"],
            "truncated": truncated,
        }
        if note:
            payload["note"] = note
        print(json.dumps(payload, indent=2))
    else:
        for issue in shown:
            where = f"{issue.file}:{issue.line}" if issue.line else issue.file
            print(f"{issue.severity.upper()} {where}: {issue.message}")
            print(f"  fix: {issue.fix}")
        if truncated:
            print(f"... and {len(ordered) - len(shown)} more")
        if note:
            print(note)
        print(f"Summary: {len(errors)} errors, {len(warnings)} warnings in {scan.files_checked} files checked "
              f"(phaser {spec}, major {major})")

    if errors or (args.strict and warnings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
