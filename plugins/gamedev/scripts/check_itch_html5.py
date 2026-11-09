#!/usr/bin/env python3
"""Check an HTML5 game ZIP against itch.io's upload rules before it is uploaded; reads the ZIP's directory, never extracts.
Catches no index.html (missing, wrong case), over 1,000 files, over 500 MB extracted, a file over 200 MB, a path over 240 characters, a non-UTF-8 name; warns on index.html only in a folder and a backslash in a name.
Does not catch absolute or wrong-case paths inside the game's code, non-HTTPS requests, the page's Kind and embed settings, or how itch extracts a backslash name."""
# Why, limits, history: rationale/derivations/plugin-gamedev.md § plugins/gamedev/scripts/check_itch_html5.py

from __future__ import annotations

import argparse
import json
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path

TOOL = "check_itch_html5"
SCHEMA = 1
DOCS = "https://itch.io/docs/creators/html5"

MAX_FILES = 1000
MAX_TOTAL_BYTES = 500_000_000
MAX_FILE_BYTES = 200_000_000
MAX_PATH_CHARS = 240
UTF8_FLAG = 0x800


@dataclass
class Issue:
    level: str
    code: str
    file: str
    message: str
    fix: str

    def as_json(self) -> dict[str, str]:
        return {"code": self.code, "file": self.file, "message": self.message, "fix": self.fix}


def entry_name(info: zipfile.ZipInfo) -> tuple[str, bool]:
    """The entry's name and whether its stored bytes are UTF-8."""
    if info.flag_bits & UTF8_FLAG:
        return info.filename, True
    raw = info.filename.encode("cp437")
    try:
        return raw.decode("utf-8"), True
    except UnicodeDecodeError:
        return info.filename, False


def human_size(size: int) -> str:
    return f"{size / 1_000_000:.1f} MB" if size >= 1_000_000 else f"{size:,} bytes"


NOT_UTF8_FIX = "Re-create the ZIP with a tool that stores names as UTF-8, or rename the file to ASCII."


def check(zip_path: Path) -> tuple[list[Issue], int | None, int | None]:
    zip_shown = zip_path.name
    try:
        with zipfile.ZipFile(zip_path) as archive:
            infos = archive.infolist()
    except UnicodeDecodeError as exc:
        name = bytes(exc.object).decode("utf-8", "replace")
        return [Issue("ERROR", "name-not-utf8", name,
                      "the entry is flagged UTF-8 but its stored name is not valid UTF-8; Python's zipfile stops reading"
                      " the ZIP there, so the other checks did not run", NOT_UTF8_FIX)], None, None
    issues: list[Issue] = []
    files = [(info, *entry_name(info)) for info in infos if not info.is_dir()]
    names = [name for _, name, _ in files]
    total = sum(info.file_size for info, _, _ in files)

    if "index.html" not in names:
        nested = sorted((n for n in names if n.rsplit("/", 1)[-1] == "index.html"), key=lambda n: (n.count("/"), n))
        wrong_case = sorted(n for n in names if n.rsplit("/", 1)[-1].lower() == "index.html" and n not in nested)
        if nested:
            issues.append(Issue("WARNING", "index-html-nested", zip_shown,
                                f"no index.html at the ZIP root; the nearest is {nested[0]}, inside a folder. itch.io's page"
                                " asks for an index.html but states no root rule, so whether itch finds this one is unverified",
                                "Zip the contents of the folder that holds index.html, not the folder itself."))
        elif wrong_case:
            message = f"no index.html at the ZIP root; {wrong_case[0]} differs only in letter case, and itch.io file names are case-sensitive"
            fix = "Rename it to index.html, all lowercase, and keep it at the ZIP root."
        else:
            message = "no index.html anywhere in the ZIP; itch.io loads index.html as the game's entry point"
            fix = "Export the game's HTML5 build with an index.html and zip its contents."
        if not nested:
            issues.append(Issue("ERROR", "index-html-missing", zip_shown, message, fix))

    if len(files) > MAX_FILES:
        issues.append(Issue("ERROR", "too-many-files", zip_shown,
                            f"{len(files):,} files after extraction; itch.io allows at most {MAX_FILES:,}",
                            "Pack assets into fewer files (an atlas, a data pack), or ship the game as a download."))
    if total > MAX_TOTAL_BYTES:
        issues.append(Issue("ERROR", "extracted-too-large", zip_shown,
                            f"{total:,} bytes extracted; itch.io allows at most 500 MB, read here as 500,000,000 bytes",
                            "Cut asset sizes, or ship the game as a download; itch.io support can lift the limit on request."))
    for info, name, utf8 in files:
        if info.file_size > MAX_FILE_BYTES:
            issues.append(Issue("ERROR", "file-too-large", name,
                                f"{info.file_size:,} bytes extracted; itch.io allows at most 200 MB per file, read here as 200,000,000 bytes",
                                "Split the file, or ship the game as a download."))
        if len(name) > MAX_PATH_CHARS:
            issues.append(Issue("ERROR", "path-too-long", name[:60] + "...",
                                f"name including its path is {len(name)} characters; itch.io allows at most {MAX_PATH_CHARS}",
                                "Shorten folder and file names."))
        if not utf8:
            issues.append(Issue("ERROR", "name-not-utf8", name,
                                "the stored name is not UTF-8 (a legacy code page); itch.io requires UTF-8 names", NOT_UTF8_FIX))
        if "\\" in info.orig_filename:
            issues.append(Issue("WARNING", "backslash-in-name", info.orig_filename,
                                "the name holds a backslash, which the ZIP spec forbids (APPNOTE 4.4.17); Python's zipfile reads it"
                                " as a folder on Windows and as part of the file name elsewhere, and how itch.io extracts it is unverified",
                                "Re-create the ZIP with a tool that writes forward slashes between folders."))
    return issues, len(files), total


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="check_itch_html5.py",
        description="Check an HTML5 game ZIP against itch.io's ZIP file requirements before uploading it. Read-only; never extracts.",
        epilog=(
            "example:\n"
            "  python3 check_itch_html5.py build/web.zip\n"
            "  python3 check_itch_html5.py build/web.zip --json   # CI step\n\n"
            "errors:\n"
            "  index-html-missing, too-many-files, extracted-too-large, file-too-large, path-too-long, name-not-utf8\n"
            "warnings:\n"
            "  index-html-nested, backslash-in-name (unverified against itch.io; exit 0)\n\n"
            f"limits ({DOCS}, read 2026-11-09):\n"
            "  a ZIP holds an index.html (the page states no root rule); at most 1,000 files and 500 MB extracted; at most 200 MB per file;\n"
            "  at most 240 characters per name including its path; names case-sensitive and UTF-8.\n"
            "  The page does not say whether MB means 10^6 or 2^20 bytes; this check uses 10^6, the stricter.\n\n"
            "exit codes: 0 no errors (warnings allowed), 1 errors, 2 usage problem, file missing, or not a ZIP"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("zip_file", metavar="ZIP", help="the ZIP you will upload as the HTML5 game")
    parser.add_argument("--json", action="store_true", help="print one JSON object instead of text")
    parser.add_argument("--max-issues", type=int, default=50, metavar="N",
                        help="print at most N issues (default 50, 0 = no limit)")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.max_issues < 0:
        parser.error("--max-issues must be 0 or more")
    target = Path(args.zip_file)
    if not target.is_file():
        print(f"{TOOL}: {target}: file not found", file=sys.stderr)
        return 2
    try:
        issues, file_count, total = check(target)
    except (zipfile.BadZipFile, zipfile.LargeZipFile, OSError, ValueError, EOFError) as exc:
        print(f"{TOOL}: {target}: not a readable ZIP ({exc}). itch.io takes a ZIP, or one self-contained .html file;"
              " .rar, .tar.gz and .7z are not supported", file=sys.stderr)
        return 2
    errors = [i for i in issues if i.level == "ERROR"]
    warnings = [i for i in issues if i.level == "WARNING"]
    ordered = errors + warnings
    shown = ordered if args.max_issues == 0 else ordered[: args.max_issues]
    if args.json:
        print(json.dumps({
            "tool": TOOL, "schema": SCHEMA, "zip": target.as_posix(), "files": file_count, "bytes": total,
            "error_count": len(errors), "warning_count": len(warnings),
            "errors": [i.as_json() for i in shown if i.level == "ERROR"],
            "warnings": [i.as_json() for i in shown if i.level == "WARNING"], "truncated": len(shown) < len(ordered),
        }, indent=2))
    else:
        lines = []
        for issue in shown:
            lines += [f"{issue.level} {issue.file}: {issue.message}", f"  fix: {issue.fix}"]
        if len(shown) < len(ordered):
            lines.append(f"... and {len(ordered) - len(shown)} more")
        contents = "directory not read" if file_count is None else f"{file_count:,} files, {human_size(total)} extracted"
        lines.append(f"Summary: {len(errors)} errors, {len(warnings)} warnings in {target.name}: {contents}")
        print("\n".join(lines))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
