"""End-to-end tests for asset_report.py: constraint passes and failures need Pillow; the missing-Pillow exit 2 runs everywhere."""
# Derived from gamedev-skills/awesome-gamedev-agent-skills@184b72b (Apache-2.0, see NOTICE); modified.

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

try:  # Pillow is only needed by the cases that build fixture images.
    from PIL import Image, ImageDraw

    PILLOW_AVAILABLE = True
except ImportError:  # pragma: no cover - exercised on machines without Pillow
    Image = ImageDraw = None
    PILLOW_AVAILABLE = False


REPORT = Path(__file__).resolve().parents[1] / "asset_report.py"


def run_tool(script: Path, *args: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(script), *args],
        check=False,
        capture_output=True,
        text=True,
        env=env,
    )


class MissingPillowTests(unittest.TestCase):
    """A PIL that raises on import is what a machine without Pillow looks like to the script."""

    def test_missing_pillow_exits_2_and_names_the_fix(self) -> None:
        with tempfile.TemporaryDirectory() as stub:
            Path(stub, "PIL.py").write_text('raise ImportError("stubbed by test_asset_report.py")\n')
            env = dict(os.environ, PYTHONPATH=stub, PYTHONDONTWRITEBYTECODE="1")
            result = run_tool(REPORT, str(Path(stub, "sprite.png")), "--require-alpha", env=env)

        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("install Pillow", result.stderr)
        self.assertEqual(result.stdout, "")


@unittest.skipUnless(
    PILLOW_AVAILABLE,
    "Pillow is not installed; install it (python3 -m pip install Pillow) to run these cases",
)
class AssetReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.asset = self.root / "sprite.png"
        image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        ImageDraw.Draw(image).rectangle((4, 3, 11, 14), fill=(220, 70, 90, 255))
        image.save(self.asset)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_asset_report_passes_and_emits_json(self) -> None:
        result = run_tool(
            REPORT,
            str(self.asset),
            "--expect-size",
            "16x16",
            "--require-alpha",
            "--max-colors",
            "4",
            "--json",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["assets"][0]["content_bounds"], [4, 3, 12, 15])

    def test_asset_report_fails_a_constraint(self) -> None:
        result = run_tool(REPORT, str(self.asset), "--expect-size", "32x32")

        self.assertEqual(result.returncode, 1)
        self.assertIn("expected 32x32", result.stdout)

    def test_asset_report_max_colors_is_an_exact_limit(self) -> None:
        # The fixture has exactly 2 colors: transparent and the fill.
        at_limit = run_tool(REPORT, str(self.asset), "--max-colors", "2")
        over_limit = run_tool(REPORT, str(self.asset), "--max-colors", "1")

        self.assertEqual(at_limit.returncode, 0, at_limit.stdout)
        self.assertEqual(over_limit.returncode, 1)
        self.assertIn("more than 1 colors", over_limit.stdout)

    def test_asset_report_require_alpha_rejects_fully_opaque_rgba(self) -> None:
        opaque = self.root / "opaque.png"
        Image.new("RGBA", (8, 8), (40, 40, 40, 255)).save(opaque)

        result = run_tool(REPORT, str(opaque), "--require-alpha")

        self.assertEqual(result.returncode, 1)
        self.assertIn("fully opaque", result.stdout)


if __name__ == "__main__":
    unittest.main()
