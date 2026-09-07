"""Exercise the installer through its real CLI with a fake Codex process."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

INSTALLER = Path(__file__).resolve().parents[2] / "codex" / "install.py"


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.catalog = self.root / "catalog.json"
        self.state = self.root / "journal.json"
        self.database = self.root / "installed.json"
        self.database.write_text("[]")
        self.catalog.write_text(json.dumps({"marketplace": "cc-plugins-codex", "plugins": {
            "a": {"dependencies": ["shared", "preexisting"]},
            "b": {"dependencies": ["shared"]}, "shared": {}, "preexisting": {}}}))
        self.cli = self.root / "codex"
        self.cli.write_text('''#!''' + sys.executable + '''
import json, pathlib, sys
root = pathlib.Path(__file__).parent
file = root / 'installed.json'
names = json.loads(file.read_text())
action = sys.argv[2]
if action == 'list':
 print(json.dumps({'installed': [{'name': n, 'marketplaceName':'cc-plugins-codex'} for n in names]}))
else:
 name = sys.argv[3].split('@')[0]
 with (root / 'calls').open('a') as out: out.write(action + ' ' + name + '\\n')
 if (root / 'fail-before').exists(): sys.exit(2)
 if action == 'add' and (root / 'fail-add').exists(): sys.exit(2)
 if action == 'add': names = list(dict.fromkeys(names + [name]))
 else: names.remove(name)
 file.write_text(json.dumps(names))
 if (root / 'fail-after').exists(): sys.exit(2)
''')
        self.cli.chmod(0o755)

    def invoke(self, *args, success=True):
        result = subprocess.run([sys.executable, str(INSTALLER), *args,
                                 "--catalog", str(self.catalog), "--state", str(self.state),
                                 "--codex", str(self.cli)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0 if success else 1, result.stderr)
        return result

    def installed(self):
        return set(json.loads(self.database.read_text()))

    def test_dry_run_has_no_writes(self):
        result = self.invoke("install", "a")
        self.assertIn("plugin add shared@cc-plugins-codex", result.stdout)
        self.assertFalse(self.state.exists())
        self.assertFalse((self.root / 'calls').exists())
        self.assertEqual(self.installed(), set())

    def test_shared_preexisting_and_explicit_leaf_are_preserved(self):
        self.database.write_text('["preexisting"]')
        self.invoke("install", "a", "b", "--apply")
        self.invoke("uninstall", "a", "--apply")
        self.assertEqual(self.installed(), {"b", "shared", "preexisting"})
        self.invoke("install", "shared", "--apply")
        self.invoke("uninstall", "b", "--apply")
        self.assertEqual(self.installed(), {"shared", "preexisting"})
        self.invoke("uninstall", "shared", "--apply")
        self.assertEqual(self.installed(), {"preexisting"})
        self.assertEqual((self.root / 'calls').read_text().count("add shared\n"), 1)

    def test_add_failure_before_and_after_effect_recovers(self):
        for marker in ("fail-before", "fail-after"):
            with self.subTest(marker=marker):
                failure = self.root / marker
                failure.touch()
                self.invoke("install", "b", "--apply", success=False)
                self.assertIsNotNone(json.loads(self.state.read_text())["pending"])
                failure.unlink()
                self.invoke("install", "b", "--apply")
                self.assertEqual(self.installed(), {"b", "shared"})
                self.invoke("uninstall", "b", "--apply")
                self.assertEqual(self.installed(), set())

    def test_remove_failure_after_effect_recovers(self):
        self.invoke("install", "b", "--apply")
        failure = self.root / "fail-after"
        failure.touch()
        self.invoke("uninstall", "b", "--apply", success=False)
        failure.unlink()
        self.invoke("uninstall", "b", "--apply")
        self.assertEqual(self.installed(), set())
        self.assertEqual(json.loads(self.state.read_text())["owned"], [])

    def test_removed_catalog_root_can_be_uninstalled_using_snapshot(self):
        self.invoke("install", "a", "b", "--apply")
        catalog = json.loads(self.catalog.read_text())
        del catalog["plugins"]["a"]
        self.catalog.write_text(json.dumps(catalog))
        self.invoke("install", "shared", "--apply")
        self.invoke("uninstall", "a", "--apply")
        self.assertEqual(self.installed(), {"b", "shared"})
        self.invoke("uninstall", "not-a-plugin", "--apply", success=False)

    def test_uninstall_does_not_retry_incomplete_install(self):
        self.invoke("install", "a", "--apply")
        (self.root / "fail-add").touch()
        self.invoke("install", "b", "--apply", success=False)
        self.invoke("uninstall", "a", "--apply")
        self.assertEqual(self.installed(), {"shared"})
        self.assertEqual(json.loads(self.state.read_text())["roots"], ["b"])
        (self.root / "fail-add").unlink()
        self.invoke("install", "b", "--apply")
        self.assertEqual(self.installed(), {"b", "shared"})

    def test_legacy_journal_missing_root_can_be_removed_but_not_guessed(self):
        self.invoke("install", "a", "b", "--apply")
        state = json.loads(self.state.read_text())
        state.pop("graph", None)
        self.state.write_text(json.dumps(state))
        catalog = json.loads(self.catalog.read_text())
        del catalog["plugins"]["a"]
        self.catalog.write_text(json.dumps(catalog))
        self.invoke("uninstall", "b", "--apply", success=False)
        self.assertEqual(self.installed(), {"a", "b", "shared", "preexisting"})
        self.invoke("uninstall", "a", "--apply")
        self.assertEqual(self.installed(), {"b", "shared"})

    def test_new_dependency_definition_overrides_snapshot(self):
        self.invoke("install", "b", "--apply")
        catalog = json.loads(self.catalog.read_text())
        catalog["plugins"]["b"]["dependencies"] = ["preexisting"]
        self.catalog.write_text(json.dumps(catalog))
        self.invoke("install", "b", "--apply")
        self.assertEqual(self.installed(), {"b", "preexisting"})

    def test_cycle_and_missing_dependency_fail_before_cli_mutation(self):
        for plugins in ({"a": {"dependencies": ["a"]}}, {"a": {"dependencies": ["missing"]}}):
            self.catalog.write_text(json.dumps({"marketplace": "cc-plugins-codex", "plugins": plugins}))
            self.invoke("install", "a", "--apply", success=False)
            self.assertFalse((self.root / "calls").exists())


if __name__ == '__main__':
    unittest.main()
