#!/usr/bin/env python3
"""Install Codex suites after `codex plugin marketplace add <repository>`.

Dry-run is the default. The journal owns only plugins added by this installer;
plugins installed beforehand are never removed. Use this installer for explicit
leaf installs too, so they remain protected when uninstalling a suite.
"""
import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys


def expand(plugins, roots):
    ordered, visiting, visited = [], set(), set()

    def visit(name):
        if name in visiting:
            raise ValueError(f"Dependency cycle involving {name}")
        if name in visited:
            return
        if name not in plugins:
            raise ValueError(f"Unknown plugin: {name}")
        visiting.add(name)
        for dependency in plugins[name].get("dependencies", []):
            visit(dependency)
        visiting.remove(name)
        visited.add(name)
        ordered.append(name)

    for root in roots:
        visit(root)
    return ordered


def save(path, state):
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w") as output:
        json.dump(state, output, indent=2)
        output.write("\n")
        output.flush()
        os.fsync(output.fileno())
    temporary.replace(path)


def run(args):
    catalog = json.loads(args.catalog.read_text())
    marketplace, plugins = catalog["marketplace"], catalog["plugins"]
    state = (json.loads(args.state.read_text()) if args.state.exists() else
             {"version": 1, "marketplace": marketplace, "roots": [], "owned": [], "pending": None})
    if state.get("version") != 1 or state.get("marketplace") != marketplace:
        raise ValueError("Journal version or marketplace does not match")
    # Preserve prior definitions so catalog removals do not strand journal roots.
    # Current definitions take precedence when a suite changes membership.
    graph = dict(state.get("graph", {}))
    graph.update(plugins)
    roots = list(state["roots"])
    if args.action == "install":
        expand(plugins, args.names)
        roots = list(dict.fromkeys(roots + args.names))
    else:
        for name in args.names:
            if name not in graph and name not in state["owned"]:
                raise ValueError(f"Unknown plugin: {name}")
        roots = [name for name in roots if name not in args.names]
    # Missing legacy roots remain an error: guessing their dependency graph could
    # remove another suite's dependencies. Explicitly removing that root is safe.
    desired = expand(graph, roots)
    result = subprocess.run([args.codex, "plugin", "list", "--json"],
                            check=True, text=True, capture_output=True)
    installed_data = json.loads(result.stdout)
    if not isinstance(installed_data, dict) or not isinstance(installed_data.get("installed"), list):
        raise ValueError("Unrecognized Codex plugin list response; refusing to modify installations")
    installed = {item["name"] for item in installed_data["installed"]
                 if item.get("marketplaceName") == marketplace}
    owned = set(state["owned"])
    # Resolve a process interruption or a CLI that changed disk before failing.
    pending = state.get("pending")
    if pending:
        if pending["action"] == "add" and pending["name"] in installed:
            owned.add(pending["name"])
        if pending["action"] == "remove" and pending["name"] not in installed:
            owned.discard(pending["name"])
    owned &= installed
    additions = [name for name in desired if name not in installed] if args.action == "install" else []
    removals = sorted(owned - set(desired))
    for verb, names in (("add", additions), ("remove", removals)):
        for name in names:
            print(f"{'Apply' if args.apply else 'Would run'}: {args.codex} plugin {verb} {name}@{marketplace}", flush=True)
    if not args.apply:
        return
    state.update(roots=roots, owned=sorted(owned), pending=None, graph=graph)
    save(args.state, state)
    for verb, names in (("add", additions), ("remove", removals)):
        for name in names:
            state["pending"] = {"action": verb, "name": name}
            save(args.state, state)
            subprocess.run([args.codex, "plugin", verb, f"{name}@{marketplace}"], check=True)
            if verb == "add":
                owned.add(name)
            else:
                owned.discard(name)
            state.update(owned=sorted(owned), pending=None)
            save(args.state, state)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "uninstall"))
    parser.add_argument("names", nargs="+")
    parser.add_argument("--apply", action="store_true", help="Apply changes; otherwise preview only")
    parser.add_argument("--catalog", type=Path, default=Path(__file__).with_name("catalog.json"))
    parser.add_argument("--state", type=Path,
                        default=Path.home() / ".codex" / "cc-marketplace" / "install-state.json")
    parser.add_argument("--codex", default="codex", help="Codex executable")
    args = parser.parse_args(argv)
    try:
        with contextlib.ExitStack() as stack:
            if args.apply:
                args.state.parent.mkdir(parents=True, exist_ok=True)
                lock = stack.enter_context(args.state.with_suffix(args.state.suffix + ".lock").open("a"))
                fcntl.flock(lock, fcntl.LOCK_EX)
            run(args)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f"Installer failed: {error}. Fix the cause and rerun with the same journal to resume.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
