"""End-to-end tests for check_phaser_v4.py: each case builds a throwaway Phaser project in a temp dir."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "check_phaser_v4.py"

V4_BAD = """\
import Phaser from 'phaser';
const config: Phaser.Types.Core.GameConfig = { type: Phaser.CANVAS, width: 800, height: 600 };
export class Play extends Phaser.Scene {
  private trail!: Phaser.GameObjects.RenderTexture;
  create() {
    const rt: Phaser.GameObjects.RenderTexture = this.add.renderTexture(0, 0, 64, 64);
    rt.draw(this.player, 10, 10);
    this.trail = this.add.renderTexture(0, 0, 800, 600);
    const dt = this.textures.addDynamicTexture('splat', 32, 32);
    dt.fill(0xff0000);
    this.add.renderTexture(0, 0, 8, 8).stamp('dot');
    const spin = Phaser.Math.PI2 * this.turns;
  }
  update() {
    this.trail.stamp('dot', undefined, 4, 4);
  }
}
"""

V4_SILENT = """\
// Math.PI2 and type: Phaser.CANVAS in a line comment; rt.draw(x) too
/* const rt = this.add.renderTexture(0, 0, 4, 4); rt.draw(x);
   type: Phaser.CANVAS */
const label = "Math.PI2 is gone; type: Phaser.CANVAS is deprecated";
const help = `rt.draw(${name}) needs Math.PI2? no: ${'type: Phaser.CANVAS'}`;
const re = /Math\\.PI2|type: Phaser\\.CANVAS/g;
const config = { type: Phaser.AUTO, width: 800 };
if (game.config.renderType === Phaser.CANVAS) { console.log('canvas fallback'); }
const full = Phaser.Math.TAU;
export function build(scene) {
  const rt = scene.add.renderTexture(0, 0, 64, 64);
  rt.draw(scene.player).render();
  const trail = new Phaser.GameObjects.RenderTexture(scene, 0, 0, 32, 32);
  trail.stamp('dot');
  trail.render();
  scene.minimap = scene.add.renderTexture(700, 50, 150, 100);
  scene.minimap.setRenderMode('all');
  scene.minimap.capture(scene.player);
  const live = scene.add.renderTexture(0, 0, 16, 16);
  live.renderMode = 'redraw';
  live.fill(0x000000);
  const dt = scene.textures.addDynamicTexture('dt', 8, 8);
  dt.clear();
  const g = scene.add.graphics();
  g.fill(0xffffff);
  return [rt, trail, live, dt, g];
}
"""


class CheckerCase(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "game"
        self.root.mkdir()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def write(self, rel: str, text: str) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def manifest(self, spec: str, key: str = "dependencies") -> None:
        self.write("package.json", json.dumps({"name": "game", key: {"phaser": spec}}))

    def run_checker(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, "-I", str(CHECKER), str(self.root), *args],
                              capture_output=True, text=True, timeout=60)

    def run_json(self, *args: str) -> tuple[int, dict]:
        proc = self.run_checker("--json", "--max-issues", "0", *args)
        self.assertIn(proc.returncode, (0, 1), proc.stderr)
        return proc.returncode, json.loads(proc.stdout)

    @staticmethod
    def found(payload: dict) -> list[tuple[str, int]]:
        return sorted((i["code"], i["line"]) for i in payload["errors"] + payload["warnings"])


class Findings(CheckerCase):
    def test_v4_patterns_fire(self) -> None:
        self.manifest("^4.2.1")
        self.write("src/scenes/Play.ts", V4_BAD)
        rc, data = self.run_json()
        self.assertEqual(rc, 1)
        self.assertEqual(self.found(data), [
            ("canvas-renderer", 2), ("pi2-removed", 12), ("render-missing", 7), ("render-missing", 10),
            ("render-missing", 11), ("render-missing", 15),
        ])
        self.assertEqual({i["code"] for i in data["warnings"]}, {"canvas-renderer"})
        self.assertTrue(all(i["source"].endswith("MIGRATION-GUIDE.md") for i in data["errors"]))
        self.assertIn("`this.trail`", [i for i in data["errors"] if i["line"] == 15][0]["message"])

    def test_comments_strings_and_rendered_textures_stay_silent(self) -> None:
        self.manifest("~4.0.0")
        self.write("src/main.js", V4_SILENT)
        rc, data = self.run_json("--strict")
        self.assertEqual(rc, 0, data)
        self.assertEqual(data["files_checked"], 1)
        self.assertEqual(self.found(data), [])

    def test_dotted_receiver_and_render_mode(self) -> None:
        self.manifest("^4.2.1")
        hud = ("export function hud(scene) {\n  scene.minimap = scene.add.renderTexture(0, 0, 150, 100);\n"
               "  scene.minimap.capture(scene.player);\n{MODE}}\n")
        self.write("src/hud.js", hud.replace("{MODE}", ""))
        self.assertEqual(self.found(self.run_json()[1]), [("render-missing", 3)])
        self.write("src/hud.js", hud.replace("{MODE}", "  scene.minimap.setRenderMode('render');\n"))
        self.assertEqual(self.found(self.run_json()[1]), [("render-missing", 3)])
        self.write("src/hud.js", hud.replace("{MODE}", "  scene.minimap.setRenderMode('all');\n"))
        self.assertEqual(self.found(self.run_json()[1]), [])

    def test_regex_literals_are_not_strings_or_code(self) -> None:
        self.manifest("^4.2.1")
        self.write("src/util.js", 'const q = /"/; const bad = Phaser.Math.PI2;\nconst re = /Math.PI2|type: Phaser.CANVAS/g;\n'
                                  "const half = total / 2; const quarter = Phaser.Math.PI2 / 4;\n")
        self.assertEqual(self.found(self.run_json()[1]), [("pi2-removed", 1), ("pi2-removed", 3)])

    def test_v3_project_stays_silent(self) -> None:
        self.manifest("^3.80.1")
        self.write("src/main.js", V4_BAD)
        proc = self.run_checker("--strict")
        self.assertEqual(proc.returncode, 0, proc.stdout)
        self.assertIn("Phaser 4 only", proc.stdout)
        rc, data = self.run_json()
        self.assertEqual((data["phaser_major"], data["files_checked"], self.found(data)), (3, 0, []))

    def test_only_src_scripts_are_scanned(self) -> None:
        self.manifest("4.0.0-rc.7", key="devDependencies")
        self.write("src/types.d.ts", "declare const a: typeof Phaser.Math.PI2;\n")
        self.write("src/notes.md", "Phaser.Math.PI2\n")
        self.write("src/node_modules/x/index.js", "Phaser.Math.PI2\n")
        self.write("public/legacy.js", "Phaser.Math.PI2\n")
        self.write("src/ok.mjs", "export const t = Phaser.Math.TAU;\n")
        rc, data = self.run_json()
        self.assertEqual((rc, data["files_checked"], self.found(data)), (0, 1, []))
        rc, data = self.run_json("--src", "public")
        self.assertEqual(self.found(data), [("pi2-removed", 1)])

    def test_text_output_and_strict(self) -> None:
        self.manifest("4.x")
        self.write("src/boot.ts", "new Phaser.Game({ type: Phaser.CANVAS });\n")
        proc = self.run_checker()
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(proc.stdout.startswith("WARNING src/boot.ts:1:"), proc.stdout)
        self.assertIn("(phaser 4.x, major 4)", proc.stdout.splitlines()[-1])
        self.assertEqual(self.run_checker("--strict").returncode, 1)

    def test_nothing_is_written(self) -> None:
        self.manifest("^4.2.1")
        self.write("src/scenes/Play.ts", V4_BAD)
        before = sorted((p.as_posix(), p.stat().st_mtime_ns) for p in self.root.rglob("*"))
        self.run_checker("--json")
        after = sorted((p.as_posix(), p.stat().st_mtime_ns) for p in self.root.rglob("*"))
        self.assertEqual(before, after)


class Usage(CheckerCase):
    def test_missing_or_bad_manifest(self) -> None:
        self.assertEqual(self.run_checker().returncode, 2)
        self.write("package.json", "{not json")
        self.assertEqual(self.run_checker().returncode, 2)
        self.write("package.json", json.dumps({"dependencies": {"pixi.js": "^8.0.0"}}))
        proc = self.run_checker()
        self.assertEqual(proc.returncode, 2)
        self.assertIn("no phaser dependency", proc.stderr)

    def test_unpinned_range_needs_major(self) -> None:
        self.write("src/main.js", "const a = Phaser.Math.PI2;\n")
        for spec in ("latest", "*", ">=3.60.0", "^3.80.0 || ^4.0.0", "github:phaserjs/phaser#v4.0.0"):
            self.manifest(spec)
            proc = self.run_checker()
            self.assertEqual(proc.returncode, 2, spec)
            self.assertIn("--major", proc.stderr)
        rc, data = self.run_json("--major", "4")
        self.assertEqual((rc, self.found(data)), (1, [("pi2-removed", 1)]))

    def test_missing_src_folder(self) -> None:
        self.manifest("^4.2.1")
        proc = self.run_checker()
        self.assertEqual(proc.returncode, 2)
        self.assertIn("--src", proc.stderr)


if __name__ == "__main__":
    unittest.main()
