#!/usr/bin/env python3
"""Read-only Codex catalog check; does not register or install any plugins."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    catalog = json.loads((ROOT / '.agents/plugins/marketplace.json').read_text())
    name = catalog['name']
    result = subprocess.run([
        'codex', '-c', f'marketplaces.{name}.source_type="local"',
        '-c', f'marketplaces.{name}.source={json.dumps(str(ROOT))}',
        'plugin', 'list', '--marketplace', name, '--available', '--json',
    ], capture_output=True, text=True, check=True, timeout=30)
    actual = json.loads(result.stdout)
    items = actual['available'] + actual['installed']
    found = {item['name'] for item in items if item['marketplaceName'] == name}
    expected = {entry['name'] for entry in catalog['plugins']}
    if found != expected:
        raise SystemExit(f'Catalog mismatch: missing={expected - found}, extra={found - expected}')
    print(f'Codex CLI resolves all {len(expected)} packages. No plugins installed or configuration changed.')


if __name__ == '__main__':
    main()
