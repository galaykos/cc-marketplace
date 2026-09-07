#!/usr/bin/env python3
"""Build the isolated Codex distribution; --check detects missing, extra, or stale files."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MARKETPLACE = 'cc-plugins-codex'
EXCLUDED = {'.claude-plugin', '.claude', '__tests__', '__pycache__', 'evals', '.chassis.json'}
TEXT = {'.md', '.sh', '.py', '.mjs', '.js', '.json', '.tsv', '.txt', '.html', '.tmpl'}


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')


def json_write(path, value):
    write(path, json.dumps(value, indent=2, ensure_ascii=False) + '\n')


def frontmatter(text):
    if text.startswith('---\n') and '\n---\n' in text[4:]:
        head, body = text[4:].split('\n---\n', 1)
        values = {}
        for line in head.splitlines():
            match = re.match(r'^([\w-]+):\s*(.*)$', line)
            if match:
                values[match[1]] = match[2].strip().strip('"\'')
        return values, body.lstrip()
    return {}, text


def convert(text):
    # Remote source URLs describe their own repository, not this generated layout.
    urls = []
    def preserve_url(match):
        urls.append(match.group(0))
        return f'CODEX_URL_PLACEHOLDER_{len(urls) - 1}__'
    text = re.sub(r'https?://[^\s<>`\"\)]+', preserve_url, text)
    # State is isolated; do not convert environment variable names used by adapters.
    text = re.sub(r'(?<![\w-])commands/([a-z][a-z0-9-]*)\.md', r'skills/command-\1/SKILL.md', text)
    text = re.sub(r'(?<![\w-])agents/([a-z][a-z0-9-]*)\.md', r'references/agents/\1.md', text)
    text = text.replace('.claude/skills/', 'references/project-skills/')
    text = text.replace('.claude-plugin/', '.codex-plugin/')
    text = text.replace('.claude.local.md', 'AGENTS.md').replace('.claude.md', 'AGENTS.md')
    text = re.sub(r'\.claude(?=[/}\"\'])', '.codex/cc-marketplace', text)
    text = text.replace('CLAUDE.md', 'AGENTS.md').replace('.claude.md', 'AGENTS.md')
    text = text.replace('claude-registry-source', 'codex-registry-source')
    text = text.replace('claude-in-chrome', 'available browser tools')
    text = re.sub(r'<!-- boost-preamble:start[\s\S]*?<!-- boost-preamble:end -->', 'For an explicit ultra-task or ultra-goal request, load the native ultra skill. Keep session model settings; goal mode continues only already-authorized work.', text)
    text = text.replace('the Skill tool', 'the available skill catalog and its SKILL.md path')
    text = text.replace('AskUserQuestion', 'a user question using the available interaction tool')
    text = text.replace('$ARGUMENTS', 'the user-supplied arguments')
    text = re.sub(r'/([a-z][a-z0-9-]*):([a-z][a-z0-9-]*)', r'\1:command-\2', text)
    for index, url in enumerate(urls):
        text = text.replace(f'CODEX_URL_PLACEHOLDER_{index}__', url)
    return text


def native_skill(name, description, body):
    header = '---\nname: ' + name + '\ndescription: ' + json.dumps(description[:500], ensure_ascii=False) + '\n---\n\n'
    context = ('Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.\n\n')
    return header + context + body


def copy_resources(source, target):
    for path in sorted(source.rglob('*')):
        rel = path.relative_to(source)
        if any(part in EXCLUDED for part in rel.parts) or not path.is_file():
            continue
        if path.is_symlink():
            raise ValueError(f'Package source must not contain symlinks: {path}')
        if rel.parts[0] in {'commands', 'agents'} or rel.name in {'README.md', 'CHANGELOG.md', 'ROADMAP.md', 'hooks.json'}:
            continue
        dest = target / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix in TEXT or path.name == 'SKILL.md':
            write(dest, convert(path.read_text()))
        else:
            shutil.copyfile(path, dest)
        shutil.copymode(path, dest)


def contract(plugin):
    return f'''# Codex execution contract for {plugin}

This package adapts the source workflow to Codex. The following host bindings
supersede Claude-specific mechanics in inherited reference material.

- Resolve this package root from the loaded skill's path (two parents above its
  directory). Before shell examples export `CLAUDE_PLUGIN_ROOT` and `PLUGIN_ROOT`
  to that absolute package path. They are provided automatically to hooks, but
  must not be assumed in an ordinary shell tool. Resolve helper paths there.
- Use Codex's available skill catalog as the authority for installed skills.
  `plugin:command-name` refers to the `command-name` skill of that plugin. Load
  its SKILL.md using the provided path. Never invoke a legacy slash command.
- Role definitions are resources in `references/agents/`, not registered agents.
  Read the relevant role rubric. When delegation is available and appropriate,
  send its instructions and bounded task to a fresh worker; otherwise do the
  work inline. Never request Claude model names or apply a Claude model ranking.
  Inherit the user's configured model unless they selected another available one.
- TaskCreate/TaskUpdate/TaskList, teams, mailboxes, Skill tools, and EnterPlanMode
  are source-host concepts. Use available Codex planning/delegation tools; if
  absent, track tasks and dependencies explicitly in project task documents and
  execute sequentially. Do not issue invented tools or CLI equivalents.
- Use the user-supplied arguments as workflow inputs. For missing required inputs,
  ask a short question. Tool availability never grants authorization for publishing,
  installation, deletion, or communication with others.
- Project workflow state is under `.codex/cc-marketplace/`. Keep existing Claude
  state separate. AGENTS.md is the project instruction file; preserve its existing
  content and scope when proposing or applying changes. When a source state schema
  records session_id, use `codex-` followed by the actual session ID to match the
  hook adapter namespace. Do not invent an ID if the host does not expose one.
- Source transcript scanners expect Claude JSONL and are not Codex evidence.
  Use observed tool outputs, current diffs, and executed checks. Never claim a
  Stop gate passed solely because an inherited scanner returned success.
- Read this package's README for the exact hooks enabled and limitations. Hooks
  require host trust and Python 3 plus any source helper dependencies (usually jq).
  An instruction or reminder is advisory; only a tested blocking hook is a gate.
'''


def hook_module():
    path = ROOT / 'codex/adapters/hooks/hooks.py'
    if not path.exists():
        raise ValueError('Missing Codex hook adapter')
    spec = importlib.util.spec_from_file_location('codex_hooks', path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def generate(dest):
    source_catalog = json.loads((ROOT / '.claude-plugin/marketplace.json').read_text())
    catalog = {'marketplace': MARKETPLACE, 'plugins': {}}
    entries, rows = [], []
    hooks = hook_module()
    for entry in source_catalog['plugins']:
        name = entry['name']
        source = ROOT / 'plugins' / name
        manifest = json.loads((source / '.claude-plugin/plugin.json').read_text())
        catalog['plugins'][name] = {'dependencies': manifest.get('dependencies', [])}
    for entry in source_catalog['plugins']:
        name = entry['name']
        source = ROOT / 'plugins' / name
        target = dest / 'codex/plugins' / name
        manifest = json.loads((source / '.claude-plugin/plugin.json').read_text())
        suite = bool(manifest.get('dependencies'))
        copy_resources(source, target)
        # Commands become namespaced, invocable skills; role definitions stay resources.
        for path in sorted((source / 'commands').glob('*.md')):
            if suite:
                continue
            meta, body = frontmatter(path.read_text())
            skill_name = 'command-' + path.stem
            write(target / 'skills' / skill_name / 'SKILL.md', native_skill(skill_name, convert(meta.get('description', f'Run {name} {path.stem}.')), convert(body)))
        for path in sorted((source / 'agents').glob('*.md')):
            _, body = frontmatter(path.read_text())
            write(target / 'references/agents' / path.name, convert(body))
        overrides = ROOT / 'codex/adapters/overrides' / name
        if overrides.exists():
            for path in sorted(overrides.rglob('*')):
                if path.is_file():
                    write(target / path.relative_to(overrides), path.read_text())
        if suite:
            members = ', '.join(manifest['dependencies'])
            body = f'''This suite groups: {members}.

Installing this package alone does not install its members. Use the bundled
installer to expand membership and track ownership:

```bash
python3 "$PLUGIN_ROOT/scripts/install.py" install {name}
python3 "$PLUGIN_ROOT/scripts/install.py" install {name} --apply
```

The first command previews the plan. Execute the second for an authorized install.
Use `uninstall {name}` with the same preview/apply pattern to remove this suite's
owned installs. Preexisting installs and other suites' dependencies are preserved.
Use this helper for explicit leaf installs too so their ownership is recorded.
Codex's plugin browser cannot expand suite dependencies automatically.
'''
            write(target / 'skills/manage-suite/SKILL.md', native_skill('manage-suite', f'Install or remove the {name} collection with dependency and ownership tracking.', body))
        if suite or name == 'plugin-scout':
            (target / 'scripts').mkdir(exist_ok=True)
            shutil.copyfile(ROOT / 'codex/install.py', target / 'scripts/install.py')
            json_write(target / 'scripts/catalog.json', catalog)
        for skill in sorted((target / 'skills').glob('*/SKILL.md')):
            meta, body = frontmatter(skill.read_text())
            if '../../references/codex.md' not in body:
                write(skill, native_skill(skill.parent.name, meta.get('description', f'Use {skill.parent.name} for {name} workflows.'), body))
        # Preserve repository doctrine that inherited skills explicitly read.
        referenced = set()
        for resource in list(target.rglob('*.md')):
            referenced.update(re.findall(r'references/project-skills/([a-z0-9-]+)/', resource.read_text()))
        for skill_name in referenced:
            project_skill = ROOT / '.claude/skills' / skill_name
            if project_skill.is_dir():
                for resource in sorted(project_skill.rglob('*')):
                    if resource.is_file():
                        write(target / 'references/project-skills' / skill_name / resource.relative_to(project_skill), convert(resource.read_text()))
        write(target / 'references/codex.md', contract(name))
        config = hooks.build_config(source)
        if isinstance(config, tuple):
            config = config[0]
        if config and config.get('hooks'):
            json_write(target / 'hooks/hooks.json', config)
            (target / 'codex-runtime').mkdir(exist_ok=True)
            shutil.copyfile(ROOT / 'codex/adapters/hooks/hooks.py', target / 'codex-runtime/hooks.py')
        mcp = target / '.mcp.json'
        if mcp.exists():
            value = json.loads(mcp.read_text())
            for server in value['mcpServers'].values():
                server.pop('_comment', None)
                if server.get('command') == 'node' and server.get('args') == ['${CLAUDE_PLUGIN_ROOT}/mcp/server.mjs']:
                    server['args'] = ['mcp/server.mjs']
                    server['cwd'] = '.'
            json_write(mcp, value)
        native = {key: manifest[key] for key in ('name', 'version', 'author', 'license', 'homepage', 'repository', 'keywords') if key in manifest}
        native['description'] = f'Codex adaptation of {name}: skills and workflows. See README for hook coverage and host limitations.'
        native['skills'] = './skills/'
        native['interface'] = {'displayName': name.replace('-', ' ').title(), 'shortDescription': f'{name} workflows for Codex', 'category': 'Productivity', 'longDescription': native['description'], 'developerName': manifest.get('author', {}).get('name', 'CC Marketplace'), 'defaultPrompt': [f'Use {name} for this task.'], 'capabilities': ['Read', 'Write']}
        if mcp.exists():
            native['mcpServers'] = './.mcp.json'
        json_write(target / '.codex-plugin/plugin.json', native)
        shutil.copyfile(ROOT / 'LICENSE', target / 'LICENSE')
        disabled = hooks.disabled_hooks(name)
        if name in getattr(hooks, 'PARTIAL', {}):
            disabled['partial'] = hooks.PARTIAL[name]
        limitation = json.dumps(disabled, ensure_ascii=False) if not isinstance(disabled, str) else disabled
        readme = f'# {name} for Codex\n\nGenerated from `plugins/{name}`. Edit source or explicit adapters, then run\n`python3 scripts/build_codex.py --write` in the marketplace checkout.\n\n'
        readme += '## Skills\n\n' + '\n'.join(f'- `{p.parent.name}`' for p in sorted((target / 'skills').glob('*/SKILL.md'))) + '\n\n'
        readme += '## Compatibility\n\n' + ('Suite dependencies require the bundled manage-suite workflow.\n\n' if suite else '')
        readme += 'Commands are skills; worker roles are references with native delegation or inline execution.\nSee [the execution contract](references/codex.md).\n\n'
        readme += f'Hook events configured: {", ".join(config.get("hooks", {})) or "none"}.\n\nSource hook limitations and replacements: {limitation or "none"}.\n\n'
        readme += 'Hooks require host trust. Transcript-dependent source helpers are not Codex verification.\nPython 3 and jq are needed for hook adapters; shell and Node helpers retain their own requirements.\n'
        write(target / 'README.md', readme)
        digest = hashlib.sha256(json.dumps(native, sort_keys=True).encode())
        for resource in sorted(target.rglob('*')):
            if resource.is_file() and resource != target / '.codex-plugin/plugin.json':
                digest.update(str(resource.relative_to(target)).encode() + b'\0')
                digest.update(resource.read_bytes())
                digest.update(str(resource.stat().st_mode & 0o111).encode())
        native['version'] = native['version'].split('+')[0] + '+codex.' + digest.hexdigest()[:12]
        json_write(target / '.codex-plugin/plugin.json', native)
        entries.append({'name': name, 'source': {'source': 'local', 'path': './codex/plugins/' + name}, 'policy': {'installation': 'AVAILABLE', 'authentication': 'ON_INSTALL'}, 'category': 'Productivity'})
        rows.append(f'| {name} | {len(list((target / "skills").glob("*/SKILL.md")))} | {", ".join(config.get("hooks", {})) or "—"} | {limitation.replace("|", "/") or "—"} |')
    json_write(dest / '.agents/plugins/marketplace.json', {'name': MARKETPLACE, 'interface': {'displayName': 'CC Plugins for Codex'}, 'plugins': entries})
    json_write(dest / 'codex/catalog.json', catalog)
    write(dest / 'codex/COMPATIBILITY.md', '# Codex compatibility\n\nGenerated inventory. Skills preserve domain guidance; host-specific workflows use explicit\noverrides. Hooks listed here are configured, not proof of live-host enforcement.\n\n| Plugin | Skills | Hook events | Source limitations / replacement |\n|---|---:|---|---|\n' + '\n'.join(rows) + '\n')


def files(root):
    return {p.relative_to(root): p for p in root.rglob('*') if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--write', action='store_true')
    action.add_argument('--check', action='store_true')
    parser.add_argument('--output-dir', type=Path, default=ROOT)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='codex-build-') as tmp:
        staging = Path(tmp)
        generate(staging)
        expected = files(staging)
        actual = {}
        for managed in ['codex/plugins', '.agents/plugins/marketplace.json', 'codex/catalog.json', 'codex/COMPATIBILITY.md']:
            path = args.output_dir / managed
            if path.is_dir():
                actual.update({p.relative_to(args.output_dir): p for p in path.rglob('*') if p.is_file()})
            elif path.exists():
                actual[Path(managed)] = path
        drift = sorted(str(p) for p in expected.keys() | actual.keys() if p not in expected or p not in actual or expected[p].read_bytes() != actual[p].read_bytes() or actual[p].is_symlink() or (expected[p].stat().st_mode & 0o111) != (actual[p].stat().st_mode & 0o111))
        if args.check:
            if drift:
                print('Codex generated files differ:\n' + '\n'.join(drift[:30]), file=sys.stderr)
                return 1
            print(f'Codex distribution current ({len(expected)} files).')
            return 0
        for rel in actual.keys() - expected.keys():
            actual[rel].unlink()
        for rel, source in expected.items():
            target = args.output_dir / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.is_symlink():
                target.unlink()
            shutil.copyfile(source, target)
            shutil.copymode(source, target)
        print(f'Generated {len(expected)} Codex files in {args.output_dir}.')
        return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError) as exc:
        print(f'Codex build failed: {exc}', file=sys.stderr)
        sys.exit(1)
