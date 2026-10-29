#!/usr/bin/env python3
"""Check raster game assets against the size, alpha and colour-count limits given as flags; exit 1 if any asset breaks one.
Catches a wrong size, no alpha channel, an alpha channel with every pixel opaque (a baked fake checkerboard), too many colours.
Does not judge style, seams, pivots, frame slicing, licence, or any property no flag names; exit 2 means it could not run."""
# Derived from gamedev-skills/awesome-gamedev-agent-skills@184b72b (Apache-2.0, see NOTICE); modified.

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

EPILOG = """exit codes:
  0  every asset passed every flag given
  1  at least one asset broke a flag, is missing, or is unreadable
  2  the check could not run: bad arguments, or Pillow is not installed

requires Pillow 10+ (python3 -m pip install Pillow)."""


def load_pillow():
    try:
        from PIL import Image
    except ImportError as exc:
        sys.stderr.write(
            f"asset_report: Pillow is not importable ({exc}); install Pillow "
            "(python3 -m pip install Pillow) and re-run\n"
        )
        raise SystemExit(2)
    return Image


def parse_size(value: str) -> tuple[int, int]:
    try:
        width_text, height_text = value.lower().split("x", 1)
        width, height = int(width_text), int(height_text)
    except (ValueError, AttributeError) as exc:
        raise argparse.ArgumentTypeError("size must look like WIDTHxHEIGHT") from exc
    if width <= 0 or height <= 0:
        raise argparse.ArgumentTypeError("size dimensions must be positive")
    return width, height


def alpha_stats(image: Any) -> dict[str, Any]:
    has_alpha = "A" in image.getbands() or "transparency" in image.info
    if not has_alpha:
        return {
            "has_alpha": False,
            "alpha_min": 255,
            "alpha_max": 255,
            "transparent_pixels": 0,
            "content_bounds": [0, 0, image.width, image.height],
        }

    alpha = image.convert("RGBA").getchannel("A")
    extrema = alpha.getextrema()
    histogram = alpha.histogram()
    return {
        "has_alpha": True,
        "alpha_min": extrema[0],
        "alpha_max": extrema[1],
        "transparent_pixels": histogram[0],
        "content_bounds": list(alpha.getbbox() or (0, 0, 0, 0)),
    }


def inspect(image_module: Any, path: Path, max_colors: int | None) -> dict[str, Any]:
    with image_module.open(path) as image:
        image.load()
        # getcolors() returns None only when the count EXCEEDS maxcolors, so asking for
        # max_colors + 1 lets an over-limit image come back as a list one entry too long.
        limit = max_colors or 65535
        colors = image.convert("RGBA").getcolors(maxcolors=limit + 1)
        if colors is not None and len(colors) > limit:
            colors = None
        result: dict[str, Any] = {
            "path": path.as_posix(),
            "format": image.format,
            "mode": image.mode,
            "width": image.width,
            "height": image.height,
            "bytes": path.stat().st_size,
            "color_count": len(colors) if colors is not None else f">{limit}",
        }
        result.update(alpha_stats(image))
        return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check raster game assets (PNG, WebP, ...) against size, alpha and colour-count limits.",
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("paths", nargs="+", type=Path, help="raster image files to inspect")
    parser.add_argument("--expect-size", type=parse_size, metavar="WIDTHxHEIGHT",
                        help="fail unless every image is exactly this size")
    parser.add_argument(
        "--require-alpha",
        action="store_true",
        help="fail unless the image has an alpha channel with at least one transparent pixel",
    )
    parser.add_argument("--max-colors", type=int, metavar="N",
                        help="fail when an image has more than N distinct RGBA colours")
    parser.add_argument("--json", action="store_true", dest="as_json",
                        help='print {"ok": bool, "assets": [...]} instead of the table')
    args = parser.parse_args()

    if args.max_colors is not None and args.max_colors <= 0:
        parser.error("--max-colors must be positive")

    image_module = load_pillow()

    reports: list[dict[str, Any]] = []
    failed = False
    for path in args.paths:
        problems: list[str] = []
        if not path.is_file():
            reports.append({"path": path.as_posix(), "problems": ["file does not exist"]})
            failed = True
            continue
        try:
            report = inspect(image_module, path, args.max_colors)
        except (OSError, ValueError) as exc:
            reports.append({"path": path.as_posix(), "problems": [f"cannot read image: {exc}"]})
            failed = True
            continue

        if args.expect_size and (report["width"], report["height"]) != args.expect_size:
            problems.append(
                f"size is {report['width']}x{report['height']}; expected "
                f"{args.expect_size[0]}x{args.expect_size[1]}"
            )
        if args.require_alpha and not report["has_alpha"]:
            problems.append("image has no alpha channel")
        elif args.require_alpha and report["alpha_min"] == 255:
            # An RGBA file with every pixel opaque usually means a baked background
            # (often a fake checkerboard) rather than real transparency.
            problems.append("alpha channel is fully opaque; no pixel is transparent")
        if args.max_colors is not None and isinstance(report["color_count"], str):
            problems.append(f"image has more than {args.max_colors} colors")
        report["problems"] = problems
        reports.append(report)
        failed = failed or bool(problems)

    if args.as_json:
        print(json.dumps({"ok": not failed, "assets": reports}, indent=2))
    else:
        for report in reports:
            if "width" not in report:
                print(f"FAIL {report['path']}: {', '.join(report['problems'])}")
                continue
            state = "PASS" if not report["problems"] else "FAIL"
            print(
                f"{state} {report['path']} {report['width']}x{report['height']} "
                f"{report['mode']} colors={report['color_count']} alpha={report['has_alpha']}"
            )
            for problem in report["problems"]:
                print(f"  - {problem}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
