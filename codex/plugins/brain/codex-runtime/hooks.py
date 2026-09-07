#!/usr/bin/env python3
"""Adapt Codex event payloads to the marketplace's portable shell guards.

The generator copies this file beside each plugin's transformed shell helpers.
No transcript-format compatibility is assumed. Missing jq and helper failures retain
source hooks' fail-open behavior; these heuristics are not a security boundary.
"""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

# Unsupported observation channels get an explicit session instruction instead of
# running a Claude parser against Codex's different transcript representation.
DISABLED = {
    'skill-router': {
        'prime.sh': 'Claude sibling-cache discovery is replaced by guidance to inspect Codex’s available skills catalog.',
        'route-prompt.sh': 'Claude command catalog discovery is replaced by native prompt guidance to select a relevant available Codex skill.',
        'route.sh': 'Automatic file-signal routing requires Claude cache discovery; consult available skill descriptions when changing a new surface.',
        'summary.sh': 'Claude routing-ledger summaries are unavailable because native routing is skill-driven rather than inferred from tool events.',
    },
    'hindsight': {'collect.sh': 'Automatic transcript collection is unavailable. Use the hindsight reflection skill to record outcomes explicitly.',
                  'skill-use.sh': 'Codex does not emit Claude Skill tool events. Record useful skill outcomes explicitly with hindsight.'},
    'code-review': {'verbosity.sh': 'Transcript verbosity measurement is unavailable. Keep progress updates brief and focused on decisions and evidence.'},
    'task-runner': {'drift.sh': 'Transcript drift detection is unavailable. Recheck the user request and active scope before each work batch.',
                    'rv-observe.sh': 'Claude Agent dispatch observation is unavailable. Record reviewer results explicitly using task-runner scripts.'},
    'candor': {'gate.sh': 'Automatic candor transcript gating is unavailable. Before finalizing, use the candor skill to verify claims, unresolved risks, and omissions against actual evidence.'},
    'code-architecture': {'evidence-gate.sh': 'Automatic architecture transcript gating is unavailable. Before finalizing architecture work, explicitly verify the evidence checklist in the code-architecture skill.'},
    'taskmaster': {'preview-guard.sh': 'Codex has no Claude Artifact event. Follow the taskmaster preview protocol before presenting artifacts.'},
    'ui-ux': {'preview-guard.sh': 'Codex has no Claude Artifact event. Run a rendered preview and verify the UI before presenting it.'},
}


PARTIAL = {
    'task-runner': ['Completion state and HEAD checks remain active; transcript-based reduction disclosure checks are unavailable. Explicitly name every reduction and its reason in the closing report.'],
}

def partial_limitations(plugin_name):
    return PARTIAL.get(plugin_name, []).copy()


def disabled_hooks(plugin_name):
    """Return documented per-script limitations, also used by the generator."""
    return DISABLED.get(plugin_name, {}).copy()


def build_config(plugin_dir):
    """Produce a native hooks.json; original shell script paths stay unchanged."""
    plugin_dir = Path(plugin_dir)
    source = plugin_dir / 'hooks/hooks.json'
    if not source.exists():
        return {'hooks': {}}
    result = {}
    disabled = disabled_hooks(plugin_dir.name)
    for event, groups in json.loads(source.read_text())['hooks'].items():
        for group in groups:
            matcher = group.get('matcher', '*')
            native_matcher = matcher
            if any(t in matcher.split('|') for t in ('Write', 'Edit', 'MultiEdit')):
                native_matcher += '|apply_patch'
            if 'Bash' in matcher.split('|'):
                native_matcher += '|exec_command|shell_command|shell'
            commands = []
            for hook in group['hooks']:
                if hook.get('type') != 'command' or not re.fullmatch(r'\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+\.sh', hook.get('command', '')):
                    raise ValueError(f'Unsupported Codex hook conversion: {plugin_dir.name} {event}: {hook}')
                if event not in {'SessionStart', 'SessionEnd', 'UserPromptSubmit', 'PreToolUse', 'PostToolUse', 'Stop'}:
                    raise ValueError(f'Unaudited hook event: {event}')
                relative = hook['command'].replace('${CLAUDE_PLUGIN_ROOT}/', '')
                if Path(relative).name in disabled:
                    continue
                command = 'python3 "${PLUGIN_ROOT}/codex-runtime/hooks.py" ' + ' '.join(shlex.quote(a) for a in (relative, event, matcher))
                commands.append(dict(hook, command=command))
            if commands:
                entry = {'hooks': commands}
                if matcher != '*':
                    entry['matcher'] = native_matcher
                result.setdefault(event, []).append(entry)
    if disabled or plugin_dir.name in PARTIAL:
        message = 'Codex compatibility: ' + ' '.join(list(disabled.values()) + PARTIAL.get(plugin_dir.name, []))
        result.setdefault('SessionStart', []).append({'hooks': [{'type': 'command', 'command': 'python3 "${PLUGIN_ROOT}/codex-runtime/hooks.py" --notice ' + shlex.quote(message), 'timeout': 5}]})
    if plugin_dir.name == 'skill-router':
        result = {event: [{'hooks': [{'type': 'command', 'command': 'python3 \"${PLUGIN_ROOT}/codex-runtime/hooks.py\" --router ' + event, 'timeout': 5}]}] for event in ('SessionStart', 'UserPromptSubmit')}
    return {'hooks': result}


def patch_files(patch):
    """Extract each affected path and added lines without executing the patch.

    For updates, only additions go to scanners (removed secrets must be removable).
    Context is supplied separately for scanners that need a whole workflow view.
    """
    current = None
    for line in patch.splitlines():
        match = re.match(r'^\*\*\* (Add|Update|Delete) File: (.+)$', line)
        if match:
            if current:
                yield current
            current = {'kind': match[1], 'path': match[2], 'added': [], 'context': []}
        elif current and line.startswith('*** Move to: '):
            current['old_path'] = current['path']
            current['path'] = line[len('*** Move to: '):]
        elif current and line.startswith('+'):
            current['added'].append(line[1:])
            current['context'].append(line[1:])
        elif current and line.startswith(' '):
            current['context'].append(line[1:])
    if current:
        yield current


def translate(payload):
    """Normalize native command, freeform patch and file payloads per file."""
    base = dict(payload)
    base.pop('transcript_path', None)
    base['session_id'] = 'codex-' + str(payload.get('session_id') or payload.get('thread_id') or 'unknown')
    name = payload.get('tool_name', '')
    # Accept qualified native tool names without changing arbitrary MCP tools.
    short = name.rsplit('.', 1)[-1]
    data = payload.get('tool_input', {})
    if short == 'apply_patch':
        patch = data if isinstance(data, str) else data.get('input', data.get('patch', ''))
        normalized = []
        for item in patch_files(patch):
            content = '\n'.join(item['added']) + ('\n' if item['added'] else '')
            values = {'file_path': item['path'], 'content' if item['kind'] == 'Add' else 'new_string': content}
            values['_patch_context'] = '\n'.join(item['context'])
            # Delete edits still reach file-path self-protection guards.
            normalized.append(dict(base, tool_name='Write' if item['kind'] == 'Add' else 'Edit', tool_input=values))
            if item.get('old_path'):
                normalized.append(dict(base, tool_name='Edit', tool_input={'file_path': item['old_path'], 'new_string': ''}))
        return normalized
    if short in ('exec_command', 'shell_command', 'shell'):
        data = dict(data) if isinstance(data, dict) else {'command': data}
        command = data.get('command', data.get('cmd', ''))
        if isinstance(command, list):
            command = shlex.join(command)
        data['command'] = command
        return [dict(base, tool_name='Bash', tool_input=data)]
    return [base]


def matches(matcher, name):
    return matcher == '*' or re.fullmatch(matcher, name) is not None


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == '--notice':
        print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': sys.argv[2]}}))
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == '--router':
        if os.environ.get('CC_ROUTE') == 'off' or os.environ.get('CC_REMIND') == 'off':
            return 0
        event = sys.argv[2]
        if event == 'UserPromptSubmit':
            try:
                prompt = json.load(sys.stdin).get('prompt', '')
            except (ValueError, AttributeError):
                return 0
            if not re.search(r'\b(build|create|add|implement|fix|debug|review|audit|design|test|deploy|refactor|error|failing|broken)\b', prompt[:400], re.I):
                return 0
        context = '[skill-router] Consult the available Codex skill names and descriptions in this session before work. Select and read skills relevant to the request and files being changed. Use only skills actually listed; do not infer installation from sibling cache directories. Automatic Claude file-signal routing and command-cache discovery are unavailable; recheck skill fit when the work changes surface.'
        print(json.dumps({'hookSpecificOutput': {'hookEventName': event, 'additionalContext': context}}))
        return 0
    if len(sys.argv) != 4:
        return 1
    relative, event, matcher = sys.argv[1:]
    root = Path(__file__).resolve().parent.parent
    script = (root / relative).resolve()
    if root not in script.parents or not script.is_file():
        print('Codex hook adapter: helper missing or outside plugin root', file=sys.stderr)
        return 1
    try:
        payload = json.load(sys.stdin)
    except (ValueError, TypeError):
        return 0
    if not isinstance(payload, dict):
        return 0
    env = dict(os.environ, CLAUDE_PLUGIN_ROOT=str(root), PLUGIN_ROOT=str(root), CLAUDE_PROJECT_DIR=str(payload.get('cwd') or os.getcwd()))
    # Ignore inherited Claude config paths: portable helper state belongs to Codex.
    env['CLAUDE_CONFIG_DIR'] = str(Path(env.get('CODEX_HOME', str(Path.home() / '.codex'))) / 'cc-marketplace')
    # Preserve existing Codex settings, with a dedicated plugin opt-out variable.
    if 'CODEX_DESTRUCTIVE_GUARD' in env:
        env['CLAUDE_DESTRUCTIVE_GUARD'] = env['CODEX_DESTRUCTIVE_GUARD']
    outputs = []
    verdicts = []
    blocked = []
    for normalized in translate(payload):
        if event in ('PreToolUse', 'PostToolUse') and not matches(matcher, normalized.get('tool_name', '')):
            continue
        normalized['hook_event_name'] = event
        if root.name == 'terse' or (script.name == 'mode.sh' and (root / 'skills/terse-output').exists()):
            prompt = normalized.get('prompt', '')
            token = 'terse:command-level' if 'terse:command-level' in script.read_text() else '/terse:level'
            normalized['prompt'] = re.sub(r'^\$(?:terse:command-level|terse-level|command-level)(?=\s|$)', lambda _: token, prompt)
        # Workflow checks need unchanged trigger lines next to newly added refs.
        if script.name == 'workflow-guard.sh':
            values = normalized.get('tool_input', {})
            if values.get('_patch_context'):
                values['new_string'] = values['_patch_context']
        try:
            proc = subprocess.run(['/bin/bash', str(script)], input=json.dumps(normalized), text=True, capture_output=True, env=env, cwd=payload.get('cwd') or None, timeout=20)
        except (OSError, subprocess.TimeoutExpired) as exc:
            print('Codex hook adapter: ' + str(exc), file=sys.stderr)
            continue
        if proc.stderr:
            print(proc.stderr, file=sys.stderr, end='')
        if proc.returncode == 2:
            blocked.append(proc.stderr or proc.stdout or 'Blocked by ' + script.name)
        if proc.stdout.strip():
            try:
                output = json.loads(proc.stdout)
            except ValueError:
                outputs.append(proc.stdout.strip())
                continue
            details = output.get('hookSpecificOutput', {})
            decision = details.get('permissionDecision')
            if decision in ('deny', 'ask') or output.get('decision') == 'block':
                verdicts.append(output)
            else:
                outputs.append(output)
    if blocked:
        if not any(v.get('hookSpecificOutput', {}).get('permissionDecision') == 'deny' for v in verdicts):
            print('\n'.join(blocked), file=sys.stderr)
            return 2
    if verdicts:
        chosen = next((v for v in verdicts if v.get('hookSpecificOutput', {}).get('permissionDecision') == 'deny' or v.get('decision') == 'block'), verdicts[0])
        print(json.dumps(chosen))
    elif outputs:
        # A single valid JSON object per event. Preserve context from all files.
        if len(outputs) == 1 and isinstance(outputs[0], dict):
            print(json.dumps(outputs[0]))
        else:
            context = '\n'.join(v if isinstance(v, str) else v.get('hookSpecificOutput', {}).get('additionalContext', json.dumps(v)) for v in outputs)
            print(json.dumps({'hookSpecificOutput': {'hookEventName': event, 'additionalContext': context}}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
