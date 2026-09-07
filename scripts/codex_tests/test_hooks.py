"""Native payload tests including actual guard decisions, not only matcher strings."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('codex_hooks', ROOT / 'codex/adapters/hooks/hooks.py')
hooks = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(hooks)


class HookTests(unittest.TestCase):
    def test_unknown_source_hook_contract_fails_generation(self):
        with tempfile.TemporaryDirectory() as tmp:
            plugin = Path(tmp) / 'example'
            (plugin / 'hooks').mkdir(parents=True)
            config = {'hooks': {'PreToolUse': [{'hooks': [{'type': 'command', 'command': 'bash ${CLAUDE_PLUGIN_ROOT}/hooks/check.sh --extra'}]}]}}
            (plugin / 'hooks/hooks.json').write_text(json.dumps(config))
            with self.assertRaises(ValueError):
                hooks.build_config(plugin)

    def test_multi_file_patch_preserves_added_content_and_rename(self):
        payload = {'tool_name': 'apply_patch', 'tool_input': {'input': '*** Begin Patch\n*** Add File: safe.md\n+hello\n*** Update File: old.sql\n*** Move to: new.sql\n@@\n-SELECT 1;\n+DROP TABLE users;\n*** End Patch'}}
        items = hooks.translate(payload)
        self.assertEqual([p['tool_input']['file_path'] for p in items], ['safe.md', 'new.sql', 'old.sql'])
        self.assertEqual(items[1]['tool_input']['new_string'], 'DROP TABLE users;\n')

    def run_guard(self, plugin, script, payload):
        with tempfile.TemporaryDirectory() as d:
            package = Path(d)
            shutil.copytree(ROOT / 'plugins' / plugin / 'hooks', package / 'hooks')
            for helper in (package / 'hooks').glob('*.sh'):
                helper.write_text(helper.read_text().replace('.claude', '.codex/cc-marketplace'))
            (package / 'codex-runtime').mkdir()
            shutil.copy2(ROOT / 'codex/adapters/hooks/hooks.py', package / 'codex-runtime/hooks.py')
            result = subprocess.run(['python3', str(package / 'codex-runtime/hooks.py'), 'hooks/' + script, 'PreToolUse', 'Bash|Write|Edit|MultiEdit'], input=json.dumps(payload), text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout) if result.stdout.strip() else {}

    @unittest.skipUnless(shutil.which('jq'), 'original guards require jq')
    def test_secret_on_second_file_denied_but_removed_secret_allowed(self):
        def patch(line):
            return {'tool_name': 'apply_patch', 'tool_input': {'input': '*** Begin Patch\n*** Add File: safe.md\n+hello\n*** Update File: app.env\n@@\n' + line + '\n*** End Patch'}}
        secret = 'AKIA' + 'A' * 16
        denied = self.run_guard('secret-scanning', 'scan.sh', patch('+' + secret))
        self.assertEqual(denied['hookSpecificOutput']['permissionDecision'], 'deny')
        self.assertEqual(self.run_guard('secret-scanning', 'scan.sh', patch('-' + secret + '\n+placeholder')), {})

    @unittest.skipUnless(shutil.which('jq'), 'original guards require jq')
    def test_exec_command_destructive_negative_control(self):
        denied = self.run_guard('command-guard', 'destructive-guard.sh', {'tool_name': 'exec_command', 'tool_input': {'cmd': 'terraform destroy'}})
        self.assertEqual(denied['hookSpecificOutput']['permissionDecision'], 'deny')
        self.assertEqual(self.run_guard('command-guard', 'destructive-guard.sh', {'tool_name': 'exec_command', 'tool_input': {'cmd': 'git status'}}), {})

    @unittest.skipUnless(shutil.which('jq'), 'original guards require jq')
    def test_database_ask_is_not_dropped(self):
        payload = {'tool_name': 'apply_patch', 'tool_input': {'input': '*** Begin Patch\n*** Add File: migration.sql\n+DROP TABLE users;\n*** End Patch'}}
        result = self.run_guard('database', 'guard.sh', payload)
        self.assertEqual(result['hookSpecificOutput']['permissionDecision'], 'ask')

    @unittest.skipUnless(shutil.which('jq'), 'original guards require jq')
    def test_workflow_context_and_added_line_are_combined(self):
        payload = {'tool_name': 'apply_patch', 'tool_input': {'input': '*** Begin Patch\n*** Update File: .github/workflows/ci.yml\n@@\n pull_request_target:\n+  ref: ${{ github.head_ref }}\n*** End Patch'}}
        result = self.run_guard('devops', 'workflow-guard.sh', payload)
        self.assertEqual(result['hookSpecificOutput']['permissionDecision'], 'deny')

    @unittest.skipUnless(shutil.which('jq'), 'original guards require jq')
    def test_guard_exemption_cannot_be_renamed(self):
        payload = {'tool_name': 'apply_patch', 'tool_input': {'input': '*** Begin Patch\n*** Update File: .codex/cc-marketplace/destructive-guard-allow\n*** Move to: harmless.txt\n@@\n-foo\n+bar\n*** End Patch'}}
        result = self.run_guard('command-guard', 'destructive-guard.sh', payload)
        self.assertEqual(result['hookSpecificOutput']['permissionDecision'], 'deny')

    @unittest.skipUnless(shutil.which('jq') and shutil.which('git'), 'completion guard requires jq and git')
    def test_registered_run_requires_current_head_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp) / 'project'
            project.mkdir()
            subprocess.run(['git', 'init', '-q', str(project)], check=True)
            subprocess.run(['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '--allow-empty', '-qm', 'initial'], cwd=project, check=True)
            state = project / '.codex/cc-marketplace/task-runner'
            state.mkdir(parents=True)
            (state / 'active-run.json').write_text(json.dumps({'slug': 'test'}))
            package = Path(tmp) / 'package'
            (package / 'hooks').mkdir(parents=True)
            source = (ROOT / 'plugins/task-runner/hooks/completion-gate.sh').read_text()
            (package / 'hooks/completion-gate.sh').write_text(source.replace('.claude/', '.codex/cc-marketplace/'))
            (package / 'codex-runtime').mkdir()
            shutil.copy2(ROOT / 'codex/adapters/hooks/hooks.py', package / 'codex-runtime/hooks.py')
            cmd = ['python3', str(package / 'codex-runtime/hooks.py'), 'hooks/completion-gate.sh', 'Stop', '*']
            payload = json.dumps({'cwd': str(project), 'session_id': 'test'})
            blocked = subprocess.run(cmd, input=payload, capture_output=True, text=True)
            self.assertEqual(blocked.returncode, 2, blocked.stderr)
            head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip()
            (state / 'gate-pass.json').write_text(json.dumps({'head': head}))
            passed = subprocess.run(cmd, input=payload, capture_output=True, text=True)
            self.assertEqual(passed.returncode, 0, passed.stderr)
            self.assertFalse((project / '.claude').exists())

    def test_exit_two_is_preserved(self):
        with tempfile.TemporaryDirectory() as d:
            package = Path(d)
            (package / 'codex-runtime').mkdir()
            shutil.copy2(ROOT / 'codex/adapters/hooks/hooks.py', package / 'codex-runtime/hooks.py')
            (package / 'block.sh').write_text('echo "validation missing" >&2\nexit 2\n')
            result = subprocess.run(['python3', str(package / 'codex-runtime/hooks.py'), 'block.sh', 'Stop', '*'], input='{}', text=True, capture_output=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('validation missing', result.stderr)

    def test_router_replacement_never_registers_cache_discovery(self):
        config = hooks.build_config(ROOT / 'plugins/skill-router')
        self.assertEqual(set(config['hooks']), {'SessionStart', 'UserPromptSubmit'})
        self.assertNotIn('prime.sh', json.dumps(config))
        result = subprocess.run(['python3', str(ROOT / 'codex/adapters/hooks/hooks.py'), '--router', 'SessionStart'], input='{}', text=True, capture_output=True)
        self.assertIn('actually listed', json.loads(result.stdout)['hookSpecificOutput']['additionalContext'])

    def test_notice_is_native_context(self):
        result = subprocess.run(['python3', str(ROOT / 'codex/adapters/hooks/hooks.py'), '--notice', 'limitation'], text=True, capture_output=True)
        self.assertEqual(json.loads(result.stdout)['hookSpecificOutput'], {'hookEventName': 'SessionStart', 'additionalContext': 'limitation'})

    @unittest.skipUnless(shutil.which('jq'), 'original guards require jq')
    def test_terse_native_prompt_isolates_config(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            package = root / 'terse'
            shutil.copytree(ROOT / 'plugins/terse/hooks', package / 'hooks')
            (package / 'skills/terse-output').mkdir(parents=True)
            (package / 'skills/terse-output/SKILL.md').write_text('<!-- terse-contract:start -->\nKeep replies short.\n<!-- terse-contract:end -->')
            (package / 'codex-runtime').mkdir()
            shutil.copy2(ROOT / 'codex/adapters/hooks/hooks.py', package / 'codex-runtime/hooks.py')
            claude = root / 'claude-config'
            claude.mkdir()
            (claude / 'terse-mode').write_text('lite\n')
            env = dict(os.environ, CODEX_HOME=str(root / 'codex'), CLAUDE_CONFIG_DIR=str(claude), CC_TERSE='')
            result = subprocess.run(['python3', str(package / 'codex-runtime/hooks.py'), 'hooks/mode.sh', 'UserPromptSubmit', '*'], input=json.dumps({'prompt': '$terse:command-level ultra'}), text=True, capture_output=True, env=env)
            self.assertEqual((root / 'codex/cc-marketplace/terse-mode').read_text(), 'ultra\n')
            self.assertEqual((claude / 'terse-mode').read_text(), 'lite\n')
            self.assertIn('ultra', json.loads(result.stdout)['hookSpecificOutput']['additionalContext'])

    def test_native_config_registers_explicit_names(self):
        config = hooks.build_config(ROOT / 'plugins/secret-scanning')
        self.assertIn('apply_patch', config['hooks']['PreToolUse'][0]['matcher'])
        self.assertNotIn('CLAUDE_PLUGIN_ROOT', json.dumps(config))

    def test_no_claude_transcript_sent_to_shell(self):
        translated = hooks.translate({'tool_name': 'exec_command', 'tool_input': {'cmd': 'ls'}, 'session_id': 'abc', 'transcript_path': '/tmp/anything'})
        self.assertEqual(translated[0]['session_id'], 'codex-abc')
        self.assertNotIn('transcript_path', translated[0])

    def test_raw_patch_string_payload(self):
        self.assertEqual(hooks.translate({'tool_name': 'apply_patch', 'tool_input': '*** Begin Patch\n*** Add File: a.txt\n+x\n*** End Patch'})[0]['tool_input']['content'], 'x\n')

if __name__ == '__main__':
    unittest.main()
