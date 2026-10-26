"""End-to-end tests of the read-only Ebitengine checker CLI; no Go/display needed."""
# Derived from gamedev-skills/awesome-gamedev-agent-skills@184b72b tests/test_check_ebitengine.py
# and tests/test_ebitengine_tools.py (Apache-2.0, see NOTICE); modified.

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "check_ebitengine.py"
SOURCE = '''package main
import e "github.com/hajimehoshi/ebiten/v2"
func f() { e.SetMaxTPS(60); e.CurrentFPS() }
'''


class CheckEbitengineTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "game with spaces"
        self.root.mkdir()

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def run_check(self, *args, target=None):
        return subprocess.run([sys.executable, str(SCRIPT), str(target or self.root), *args],
                              capture_output=True, text=True)

    def test_json_and_text_are_warnings_until_strict_is_requested(self):
        path = self.write("main.go", SOURCE)
        original = path.read_bytes()
        result = self.run_check("--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(set(report), {"tool", "schema", "root", "files_checked",
                                      "error_count", "warning_count", "errors", "warnings", "truncated"})
        self.assertEqual((report["tool"], report["schema"]), ("check_ebitengine", 1))
        self.assertEqual(report["root"], self.root.resolve().as_posix())
        self.assertEqual((report["error_count"], report["warning_count"], report["files_checked"]), (0, 2, 1))
        self.assertFalse(report["errors"])
        self.assertFalse(report["truncated"])
        self.assertTrue(all(i["file"] == "main.go" and i["line"] == 3 and i["fix"] for i in report["warnings"]))
        strict = self.run_check("--strict")
        self.assertEqual(strict.returncode, 1, strict.stderr)
        self.assertIn("WARNING main.go:3:", strict.stdout)
        self.assertIn("  fix:", strict.stdout)
        self.assertIn("Summary: 0 errors, 2 warnings in 1 files checked", strict.stdout)
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual([p.name for p in self.root.iterdir()], ["main.go"])

    def test_truncation_preserves_totals_and_exit_status(self):
        self.write("main.go", SOURCE)
        result = self.run_check("--json", "--strict", "--max-issues", "1")
        self.assertEqual(result.returncode, 1, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual((report["warning_count"], len(report["warnings"])), (2, 1))
        self.assertTrue(report["truncated"])
        result = self.run_check("--json", "--max-issues", "0")
        report = json.loads(result.stdout)
        self.assertEqual(len(report["warnings"]), 2)
        self.assertFalse(report["truncated"])

    def test_clean_alias_and_comment_literal_do_not_create_findings(self):
        path = self.write("日本語.go", '''package main
import e "github.com/hajimehoshi/ebiten/v2"
// e.SetMaxTPS(60)
const example = `import "github.com/hajimehoshi/ebiten"; e.CurrentFPS()`
func f() { e.SetTPS(60) }
''')
        result = self.run_check("--json", "--strict", target=path)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual((report["warning_count"], report["error_count"], report["files_checked"]), (0, 0, 1))

    def test_tests_and_generated_dependencies_are_excluded_by_default(self):
        self.write("main.go", SOURCE.replace("e.SetMaxTPS(60); e.CurrentFPS()", "e.SetTPS(60)"))
        self.write("main_test.go", SOURCE)
        self.write("vendor/dependency.go", SOURCE)
        self.write("node_modules/dependency.go", SOURCE)
        self.write(".hidden/dependency.go", SOURCE)
        report = json.loads(self.run_check("--json", "--strict").stdout)
        self.assertEqual((report["warning_count"], report["files_checked"]), (0, 1))
        result = self.run_check("--json", "--strict", "--include-tests")
        self.assertEqual(result.returncode, 1, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual((report["warning_count"], report["files_checked"]), (2, 2))
        self.assertTrue(all(i["file"] == "main_test.go" for i in report["warnings"]))

    def test_missing_wrong_project_and_bad_arguments_exit_two(self):
        self.write("main.go", '''package main
// github.com/hajimehoshi/ebiten/v2 is only a comment.
const example = `import "github.com/hajimehoshi/ebiten/v2"`
func main() {}
''')
        for target, args in ((self.root / "missing", ()), (self.root, ()),
                             (self.write("readme.txt", "text"), ()),
                             (self.root, ("--max-issues", "-1"))):
            with self.subTest(target=target, args=args):
                result = self.run_check(*args, target=target)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertIn("error:", result.stderr)
        result = subprocess.run([sys.executable, str(SCRIPT), "--help"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--max-issues", result.stdout)

    def test_module_signal_allows_checking_a_rules_only_package(self):
        self.write("go.mod", "module example.com/game\n\ngo 1.25\n\nrequire (\n github.com/hajimehoshi/ebiten/v2 v2.10.5\n)\n")
        self.write("rules.go", "package game\nfunc score() int { return 1 }\n")
        result = self.run_check("--json", "--strict")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["files_checked"], 1)

    def test_struct_fields_named_like_packages_are_not_package_calls(self):
        self.write("main.go", '''package main
import (
    e "github.com/hajimehoshi/ebiten/v2"
    "github.com/hajimehoshi/ebiten/v2/audio"
)
func f(s *S, r R) { s.audio.NewPlayer(r); s.e.SetMaxTPS(60); audio.CurrentContext() }
''')
        result = self.run_check("--json", "--strict")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout)["warning_count"], 0)

    def test_deprecated_player_methods_are_checked_only_with_audio_import(self):
        body = "func f(p *P, file *F) { p.Close(); p.Seek(d); p.Current(); file.Seek(0, 0) }\n"
        self.write("main.go", 'package main\nimport "github.com/hajimehoshi/ebiten/v2/audio"\n' + body)
        report = json.loads(self.run_check("--json").stdout)
        self.assertEqual(sorted(i["message"].split(" ")[2] for i in report["warnings"]),
                         ["Player.Close", "Player.Current", "Player.Seek"])
        self.write("main.go", 'package main\nimport "github.com/hajimehoshi/ebiten/v2"\n' + body)
        self.assertEqual(json.loads(self.run_check("--json").stdout)["warning_count"], 0)

    LOOP_SOURCE = '''package main

import (
	"time"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/audio"
	"github.com/hajimehoshi/ebiten/v2/inpututil"
	"github.com/hajimehoshi/ebiten/v2/text/v2"
)

type Game struct{ bgm *audio.Player; started time.Time }

func (g *Game) Update() error {
	_ = time.Since(g.started)
	img := ebiten.NewImage(8, 8)
	_ = img
	return nil
}

func (g *Game) Draw(screen *ebiten.Image) {
	img := ebiten.NewImage(8, 8)
	_, _ = text.NewGoTextFaceSource(nil)
	_ = inpututil.IsKeyJustPressed(ebiten.KeySpace)
	g.bgm.Play()
	_ = audio.NewContext(48000)
	_ = img.At(1, 2)
	_ = g.list.At(3)
}
'''

    def test_draw_and_update_bodies_flag_loop_misuse(self):
        self.write("game.go", self.LOOP_SOURCE)
        result = self.run_check("--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        found = {(i["line"], i["message"].split(":")[0]) for i in report["warnings"]}
        self.assertEqual(found, {(15, "in Update"), (22, "in Draw"), (23, "in Draw"), (24, "in Draw"),
                                 (25, "in Draw"), (26, "in Draw"), (27, "in Draw")})
        self.assertTrue(all(i["code"] == "loop-review" for i in report["warnings"]))
        self.assertEqual(self.run_check("--strict").returncode, 1)

    def test_same_calls_outside_update_and_draw_are_not_loop_findings(self):
        self.write("game.go", self.LOOP_SOURCE.replace(") Update(", ") Load(").replace(") Draw(", ") Prepare("))
        report = json.loads(self.run_check("--json", "--strict").stdout)
        self.assertEqual(report["warning_count"], 0, report["warnings"])

    def test_close_on_an_opened_file_is_not_reported_as_a_player(self):
        self.write("sound.go", '''package main

import (
	"os"

	"github.com/hajimehoshi/ebiten/v2/audio"
)

func load(p *audio.Player) error {
	f, err := os.Open("music.ogg")
	if err != nil {
		return err
	}
	defer f.Close()
	p.Close()
	return nil
}
''')
        report = json.loads(self.run_check("--json").stdout)
        self.assertEqual([(i["line"], i["message"].split(" ")[2]) for i in report["warnings"]],
                         [(15, "Player.Close")])


def load_checker():
    spec = importlib.util.spec_from_file_location("check_ebitengine", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ScanFileTests(unittest.TestCase):
    """The checker cases from upstream tests/test_ebitengine_tools.py."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.checker = load_checker()

    def scan(self, src):
        path = self.root / "scan.go"
        path.write_text(src)
        return self.checker.scan_file(str(path), [])

    def test_checker_handles_aliases_comments_and_unrelated_types(self):
        found = self.scan('''package main
import e "github.com/hajimehoshi/ebiten/v2"
// import "github.com/hajimehoshi/ebiten/v2/text"
const example = `import "github.com/hajimehoshi/ebiten"`
func f() { e.SetMaxTPS(60) }
''')
        self.assertEqual([(f[0], f[1], f[2]) for f in found],
                         [("warn", str(self.root / "scan.go"), 5)])
        found = self.scan('''package main
import audio "example.com/audio"
func f() { audio.NewPlayer(nil); obj.ReplacePixels(nil); obj.ColorM.Reset() }
''')
        self.assertFalse([f for f in found if f[0] == "error"])
        self.assertEqual(len(found), 2)  # ambiguous receiver methods are review warnings

    def test_checker_multiple_context_sites_are_review_warnings(self):
        for suffix in ("linux", "windows"):
            (self.root / ("sound_" + suffix + ".go")).write_text('''package main
import "github.com/hajimehoshi/ebiten/v2/audio"
func newSound() { audio.NewContext(48000) }
''')
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.root)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("multiple audio.NewContext call sites", result.stdout)
        self.assertIn("WARNING sound_linux.go:3:", result.stdout)
        self.assertIn("WARNING sound_windows.go:3:", result.stdout)

    def test_checker_old_import_reports_source_file_and_import_line(self):
        found = self.scan('''package main
import (
    "github.com/hajimehoshi/ebiten"
    "fmt"
)
''')
        self.assertEqual([(f[0], f[1], f[2]) for f in found],
                         [("warn", str(self.root / "scan.go"), 3)])


if __name__ == "__main__":
    unittest.main()
