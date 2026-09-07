import json
import importlib.util
import pathlib
import subprocess
import shutil
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class BuildTests(unittest.TestCase):
    def test_external_urls_and_moved_resource_paths(self):
        spec = importlib.util.spec_from_file_location('build_codex', ROOT / 'scripts/build_codex.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        urls = [f'https://example.org/{n}/.claude-plugin/plugin.json' for n in range(12)]
        self.assertEqual(module.convert(' '.join(urls)), ' '.join(urls))
        self.assertEqual(module.convert('${CLAUDE_PLUGIN_ROOT}/commands/task.md'), '${CLAUDE_PLUGIN_ROOT}/skills/command-task/SKILL.md')
        self.assertEqual(module.convert('agents/indexer.md'), 'references/agents/indexer.md')

    def test_generated_distribution_is_complete_and_detects_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp)
            cmd = [sys.executable, str(ROOT / 'scripts/build_codex.py'), '--output-dir', tmp]
            build = subprocess.run(cmd + ['--write'], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            catalog = json.loads((dest / '.agents/plugins/marketplace.json').read_text())
            source = json.loads((ROOT / '.claude-plugin/marketplace.json').read_text())
            self.assertEqual({p['name'] for p in catalog['plugins']}, {p['name'] for p in source['plugins']})
            for item in catalog['plugins']:
                plugin = dest / item['source']['path']
                self.assertTrue(plugin.is_relative_to(dest / 'codex/plugins'))
                manifest = json.loads((plugin / '.codex-plugin/plugin.json').read_text())
                self.assertEqual(manifest['name'], plugin.name)
                self.assertNotIn('dependencies', manifest)
                self.assertRegex(manifest['version'], r'\+codex\.[0-9a-f]{12}$')
                self.assertTrue(list((plugin / 'skills').glob('*/SKILL.md')), plugin)
                self.assertFalse(any(p.is_symlink() for p in plugin.rglob('*')))
                self.assertFalse((plugin / '.claude-plugin').exists())
            if shutil.which('node'):
                # The cache location differs from the checkout; no outside resource may be needed.
                cached = dest / 'cache/design-lab/local'
                shutil.copytree(dest / 'codex/plugins/design-lab', cached)
                mcp = json.loads((cached / '.mcp.json').read_text())['mcpServers']['registry-source']
                self.assertEqual(mcp['cwd'], '.')
                self.assertNotIn('${', ' '.join(mcp['args']))
                messages = [
                    {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'protocolVersion': '2024-11-05', 'capabilities': {}, 'clientInfo': {'name': 'test', 'version': '1'}}},
                    {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list', 'params': {}},
                ]
                result = subprocess.run([mcp['command']] + mcp['args'], cwd=cached,
                    input='\n'.join(json.dumps(m) for m in messages) + '\n', text=True, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                replies = {m['id']: m for m in map(json.loads, result.stdout.splitlines())}
                self.assertTrue(replies[2]['result']['tools'])
                self.assertEqual(replies[1]['result']['serverInfo']['version'], json.loads((cached / '.codex-plugin/plugin.json').read_text())['version'])
            command = (dest / 'codex/plugins/database/skills/command-review/SKILL.md').read_text()
            self.assertIn('name: command-review', command)
            self.assertNotIn('$ARGUMENTS', command)
            self.assertIn('sql-best-practices', command)
            self.assertTrue((dest / 'codex/plugins/database/references/agents/database-engineer.md').exists())
            self.assertEqual(subprocess.run(cmd + ['--check'], capture_output=True).returncode, 0)
            helper = dest / 'codex/plugins/database/hooks/guard.sh'
            executable = next(p for p in (dest / 'codex/plugins').rglob('*.sh') if p.stat().st_mode & 0o111)
            executable.chmod(executable.stat().st_mode & ~0o111)
            self.assertNotEqual(subprocess.run(cmd + ['--check'], capture_output=True).returncode, 0)
            subprocess.run(cmd + ['--write'], check=True, capture_output=True)
            manifest = dest / 'codex/plugins/database/.codex-plugin/plugin.json'
            manifest.write_text('{}')
            self.assertNotEqual(subprocess.run(cmd + ['--check'], capture_output=True).returncode, 0)
            subprocess.run(cmd + ['--write'], check=True, capture_output=True)
            extra = dest / 'codex/plugins/database/stale.txt'
            extra.write_text('old package artifact')
            self.assertNotEqual(subprocess.run(cmd + ['--check'], capture_output=True).returncode, 0)


if __name__ == '__main__':
    unittest.main()
