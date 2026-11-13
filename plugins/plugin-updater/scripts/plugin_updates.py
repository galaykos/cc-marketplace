#!/usr/bin/env python3
# plugin_updates.py — `update`: run `claude plugin update` for each install behind its marketplace clone, one at a time, every scope and folder; `hook`: at session start, start that run detached when due, report the last one.
# Misses: a remote-source plugin whose version lives only in its own plugin.json, releases the clones have not fetched when the refresh is skipped, and linked git worktree installs (skipped).
# Why, limits, history: rationale/derivations/plugin-plugin-updater.md § plugins/plugin-updater/scripts/plugin_updates.py
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time

PLUGIN = "plugin-updater"
SKILL = "/plugin-updater:update-plugins"
UPDATE_TIMEOUT = 300
LOCK_STALE = 6 * 3600
LOCK_GRACE = 60
GONE = "orphaned entry: folder no longer exists"
WORKTREE = "linked git worktree: run from here, the CLI updates the main checkout's install instead"


def plugins_dir():
    base = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")
    return os.path.join(base, "plugins")


def option(name, default):
    """Env var NAME, else the plugin option the host exports as CLAUDE_PLUGIN_OPTION_NAME, else default."""
    v = os.environ.get(name, "")
    if not v:
        v = os.environ.get("CLAUDE_PLUGIN_OPTION_" + name, "")
        v = {"true": "on", "false": "off"}.get(v.lower(), v)
    return v or default


def interval_hours():
    try:
        h = float(option("CC_PLUGIN_UPDATER_INTERVAL", "24"))
    except ValueError:
        return 24.0
    return h if h >= 0 else 24.0


def default_data_dir():
    """${CLAUDE_PLUGIN_DATA}, else the directory the host would give this install, else plugins/data/plugin-updater."""
    env = os.environ.get("CLAUDE_PLUGIN_DATA")
    if env:
        return env
    parts = os.path.realpath(__file__).split(os.sep)
    mkt = None
    for i in range(1, len(parts) - 2):
        if parts[i - 1] == "plugins" and parts[i] == "cache" and parts[i + 2] == PLUGIN:
            mkt = parts[i + 1]
        elif parts[i - 1] == "plugins" and parts[i] == "marketplaces":
            mkt = parts[i + 1]
    pid = f"{PLUGIN}@{mkt}" if mkt else PLUGIN
    return os.path.join(plugins_dir(), "data", re.sub(r"[^A-Za-z0-9_-]", "-", pid))


def read_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def read_state(data):
    try:
        st = read_json(os.path.join(data, "last-run.json"))
        return st if isinstance(st, dict) else {}
    except (OSError, ValueError):
        return {}


def write_state(data, st):
    os.makedirs(data, exist_ok=True)
    path = os.path.join(data, "last-run.json")
    tmp = f"{path}.{os.getpid()}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(st, f, indent=1)
    os.replace(tmp, path)


def lock_holder(lock):
    """Who holds the run lock, or None when it is absent or stale (dead pid past the grace, or older than LOCK_STALE)."""
    try:
        age = time.time() - os.stat(lock).st_mtime
    except OSError:
        return None
    if age > LOCK_STALE:
        return None
    if age < LOCK_GRACE:
        return f"a run started {int(age)} s ago"
    try:
        with open(os.path.join(lock, "pid"), encoding="utf-8") as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
    except PermissionError:
        pass
    except (OSError, ValueError):
        return None
    return f"pid {pid}, started {int(age // 60)} min ago"


def acquire_lock(data):
    """(lock path, None) when taken, (None, holder) when another run has it."""
    lock = os.path.join(data, "run.lock")
    os.makedirs(data, exist_ok=True)
    for _ in range(2):
        try:
            os.mkdir(lock)
        except FileExistsError:
            holder = lock_holder(lock)
            if holder:
                return None, holder
            shutil.rmtree(lock, ignore_errors=True)
            continue
        claim_lock(lock)
        return lock, None
    return None, "another run"


def claim_lock(lock):
    os.makedirs(lock, exist_ok=True)
    with open(os.path.join(lock, "pid"), "w", encoding="utf-8") as f:
        f.write(str(os.getpid()))


def inside(root, path):
    root, path = os.path.realpath(root), os.path.realpath(path)
    return path == root or path.startswith(root + os.sep)


def plugin_dir_in_clone(loc, manifest, source):
    """The plugin's directory inside the marketplace clone, or None for a remote source."""
    if not isinstance(source, str) or not source:
        return None
    if source.startswith("./"):
        rel = source
    elif "/" not in source:
        root = (manifest.get("metadata") or {}).get("pluginRoot")
        if not isinstance(root, str) or not root:
            return None
        rel = os.path.join(root, source)
    else:
        return None
    d = os.path.normpath(os.path.join(loc, rel))
    return d if inside(loc, d) else None


def marketplace_locations(pdir):
    locs = {}
    try:
        known = read_json(os.path.join(pdir, "known_marketplaces.json"))
    except (OSError, ValueError):
        known = {}
    if isinstance(known, dict):
        for name, info in known.items():
            loc = info.get("installLocation") if isinstance(info, dict) else None
            locs[name] = loc or os.path.join(pdir, "marketplaces", name)
    try:
        for name in os.listdir(os.path.join(pdir, "marketplaces")):
            locs.setdefault(name, os.path.join(pdir, "marketplaces", name))
    except OSError:
        pass
    return locs


def load_catalog(pdir):
    """latest: {id: version or None}; remote: ids whose plugin.json is not in the clone;
    renames: {marketplace: {name: new name or None}}; unreadable: {marketplace}."""
    latest, remote, renames, unreadable = {}, set(), {}, set()
    for mkt, loc in marketplace_locations(pdir).items():
        try:
            manifest = read_json(os.path.join(loc, ".claude-plugin", "marketplace.json"))
            if not isinstance(manifest, dict):
                raise ValueError("not an object")
        except (OSError, ValueError):
            unreadable.add(mkt)
            continue
        ren = manifest.get("renames")
        renames[mkt] = ren if isinstance(ren, dict) else {}
        for entry in manifest.get("plugins") or []:
            if not isinstance(entry, dict) or not isinstance(entry.get("name"), str):
                continue
            version = None
            d = plugin_dir_in_clone(loc, manifest, entry.get("source"))
            if d:  # the plugin's own manifest wins over the entry's version, as the host resolves it
                try:
                    pj = read_json(os.path.join(d, ".claude-plugin", "plugin.json"))
                    version = pj.get("version") if isinstance(pj, dict) else None
                except (OSError, ValueError):
                    version = None
            if not version:
                version = entry.get("version")
            pid = f"{entry['name']}@{mkt}"
            latest[pid] = version if isinstance(version, str) and version else None
            if not d:
                remote.add(pid)
    return {"latest": latest, "remote": remote, "renames": renames, "unreadable": unreadable}


def classify(inst, cat):
    """('current'|'outdated'|'unresolved', detail)."""
    pid = inst.get("id", "")
    name, _, mkt = pid.partition("@")
    have = inst.get("version")
    if pid in cat["latest"]:
        want = cat["latest"][pid]
        if want is None:
            if pid in cat["remote"]:
                return "unresolved", "remote source, its version is not readable locally"
            return "unresolved", "no version declared (the host versions it by commit)"
        return ("current", want) if have == want else ("outdated", want)
    renames = cat["renames"]
    if mkt in renames and name in renames[mkt]:
        to = renames[mkt][name]
        return "unresolved", "removed from the marketplace" if to is None else f"renamed to {to} in the marketplace"
    if mkt in cat["unreadable"]:
        return "unresolved", "marketplace manifest unreadable"
    if mkt in renames:
        return "unresolved", "not in the marketplace manifest"
    return "unresolved", "no local clone of its marketplace"


def folder_of(inst):
    return os.path.expanduser("~") if inst.get("scope") == "user" else inst.get("projectPath")


def where(inst):
    return "~ (user)" if inst.get("scope") == "user" else f"{inst.get('projectPath')} ({inst.get('scope')})"


def is_linked_worktree(folder):
    try:
        with open(os.path.join(folder, ".git"), encoding="utf-8") as f:
            head = f.read(4096)
    except OSError:
        return False
    return head.startswith("gitdir:") and "/worktrees/" in head.replace("\\", "/")


def why_not_updatable(inst):
    scope = inst.get("scope")
    if scope not in ("user", "project", "local"):
        return f"{scope} scope is set by policy, not updated here"
    folder = folder_of(inst)
    if not folder or not os.path.isdir(folder):
        return GONE
    if scope != "user" and is_linked_worktree(folder):
        return WORKTREE
    return None


def outdated_line():
    """The check-only notice, from JSON files and .git entries alone."""
    pdir = plugins_dir()
    installed = read_json(os.path.join(pdir, "installed_plugins.json"))
    plugins = installed.get("plugins") if isinstance(installed, dict) else None
    if not isinstance(plugins, dict):
        return None
    latest = load_catalog(pdir)["latest"]
    n, ids = 0, set()
    for pid, entries in plugins.items():
        want = latest.get(pid)
        if not want or not isinstance(entries, list):
            continue
        for e in entries:
            if not isinstance(e, dict) or e.get("version") == want or why_not_updatable(e):
                continue
            n += 1
            ids.add(pid)
    if not n:
        return None
    s = "" if n == 1 else "s"
    p = "" if len(ids) == 1 else "s"
    return f"{n} plugin install{s} outdated ({len(ids)} plugin{p}): run {SKILL} (--dry-run lists them)."


def report_line(st):
    if not st.get("completed"):
        return f"plugin-updater: the background run did not finish (exit {st.get('rc')}); {SKILL} --last shows its log."
    parts = [f"{label} {st[key]}" for key, label in
             (("updated", "updated"), ("needs_you", "need you"), ("failed", "failed"),
              ("orphaned", "orphaned"), ("worktree", "in worktrees")) if st.get(key)]
    if not parts:
        return None
    restart = " Restart running sessions to load the updates." if st.get("updated") else ""
    return f"plugin-updater, background run: {', '.join(parts)}. {SKILL} --last shows the log.{restart}"


def due(st):
    last = st.get("last_completed")
    return not isinstance(last, (int, float)) or time.time() - last >= interval_hours() * 3600


def spawn(data, lock):
    script = os.path.join(os.path.dirname(os.path.realpath(__file__)), "update-all.sh")
    try:
        with open(os.path.join(data, "last-run.log"), "w", encoding="utf-8") as log:
            subprocess.Popen(["bash", script, "--background", "--owns-lock", "--data-dir", data],
                             cwd=os.path.expanduser("~"), stdin=subprocess.DEVNULL, stdout=log,
                             stderr=subprocess.STDOUT, start_new_session=True, close_fds=True)
    except OSError:
        shutil.rmtree(lock, ignore_errors=True)


def hook():
    """SessionStart: report an unreported background run, then start a detached run when due; returns at once."""
    try:
        data = default_data_dir()
        msgs = []
        st = read_state(data)
        if st.get("reported") is False:
            st["reported"] = True
            write_state(data, st)
            line = report_line(st)
            if line:
                msgs.append(line)
        if option("CC_PLUGIN_UPDATER_AUTO", "on") != "off":
            if due(st):
                lock, _ = acquire_lock(data)
                if lock:
                    spawn(data, lock)
        elif option("CC_PLUGIN_UPDATER_HINT", "on") != "off":
            line = outdated_line()
            if line:
                msgs.append(line)
        if msgs:
            print(json.dumps({"systemMessage": " ".join(msgs)}))
    except Exception:
        return


def claude_bin():
    found = shutil.which("claude")
    if found:
        return found
    exe = os.environ.get("CLAUDE_CODE_EXECPATH", "")
    return exe if exe and os.path.isfile(exe) and os.access(exe, os.X_OK) else None


def claude(args, cwd=None, timeout=UPDATE_TIMEOUT):
    return subprocess.run([claude_bin() or "claude", *args], cwd=cwd, stdin=subprocess.DEVNULL,
                          capture_output=True, text=True, timeout=timeout)


def last_json(text):
    for line in reversed((text or "").strip().splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except ValueError:
                continue
    return None


def tail(text):
    lines = [l for l in (text or "").strip().splitlines() if l.strip()]
    return lines[-1][:300] if lines else ""


def parse_args(argv):
    ap = argparse.ArgumentParser(prog="update-all.sh", description="Update every installed Claude Code plugin, one install at a time.")
    ap.add_argument("--dry-run", action="store_true", help="list what would be updated; run no `claude plugin update`")
    ap.add_argument("--no-refresh", action="store_true", help="skip `claude plugin marketplace update` and compare against the clones as they are")
    ap.add_argument("--scope", action="append", choices=["user", "project", "local"], help="only this scope (repeatable)")
    ap.add_argument("--project", action="append", metavar="PATH", help="only installs whose project folder is PATH (repeatable)")
    ap.add_argument("--plugin", action="append", metavar="NAME", help="only this plugin, as name or name@marketplace (repeatable)")
    ap.add_argument("--last", action="store_true", help="print the last background run's log and exit")
    ap.add_argument("--data-dir", metavar="DIR", help="run state, lock and log (default: ${CLAUDE_PLUGIN_DATA})")
    ap.add_argument("--background", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--owns-lock", action="store_true", help=argparse.SUPPRESS)
    return ap.parse_args(argv)


def wanted(inst, a):
    if a.scope and inst.get("scope") not in a.scope:
        return False
    if a.project:
        pp = inst.get("projectPath")
        if not pp or os.path.realpath(pp) not in a.project:
            return False
    if a.plugin:
        pid = inst.get("id", "")
        if pid not in a.plugin and pid.partition("@")[0] not in a.plugin:
            return False
    return True


def run_one(inst):
    """(bucket, line). bucket: updated | current | failed | needs_you."""
    pid, scope = inst["id"], inst["scope"]
    try:
        p = claude(["plugin", "update", pid, "--scope", scope, "--json"], cwd=folder_of(inst))
    except subprocess.TimeoutExpired:
        return "failed", f"timed out after {UPDATE_TIMEOUT}s"
    except OSError as e:
        return "failed", f"could not run claude: {e}"
    r = last_json(p.stdout)
    if not isinstance(r, dict):
        return "failed", f"exit {p.returncode}, no JSON result: {tail(p.stderr) or tail(p.stdout) or 'no output'}"
    if r.get("outcome") == "ok" and r.get("updateOutcome") == "updated":
        return "updated", f"{r.get('oldVersion')} → {r.get('newVersion')}"
    if r.get("outcome") == "ok" and r.get("updateOutcome") == "up_to_date":
        if r.get("oldVersion") and inst.get("version") and r["oldVersion"] != inst["version"]:
            return "failed", (f"not updated: the CLI checked another install of {pid} (it reports "
                              f"{r['oldVersion']}, this one records {inst['version']})")
        return "current", r.get("newVersion") or ""
    code = str(r.get("failureCode") or "")
    if r.get("shownCommand") or "confirm" in code or "command" in code:
        return "needs_you", r.get("message") or code or "marketplace-declared command changed"
    msg = r.get("message") or json.dumps(r)[:300]
    return "failed", f"{code}: {msg}" if code else msg


def show_last(data):
    log = os.path.join(data, "last-run.log")
    if not os.path.isfile(log):
        print(f"No background run recorded in {data}.")
        return 0
    when = time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(log)))
    print(f"Last background run, log {log} (last written {when}):\n")
    with open(log, encoding="utf-8", errors="replace") as f:
        sys.stdout.write(f.read())
    return 0


def update(argv):
    a = parse_args(argv)
    data = a.data_dir or default_data_dir()
    if a.last:
        return show_last(data)
    if a.project:
        a.project = {os.path.realpath(os.path.expanduser(p)) for p in a.project}
    if a.dry_run:
        return plan_and_run(a)
    if a.owns_lock:
        lock = os.path.join(data, "run.lock")
        claim_lock(lock)
    else:
        lock, holder = acquire_lock(data)
        if not lock:
            print(f"update-all.sh: another update run is in progress ({holder}); its log: {os.path.join(data, 'last-run.log')}", file=sys.stderr)
            return 2
    rc, counts = 2, {}
    try:
        rc, counts = plan_and_run(a)
    finally:
        prev = read_state(data)
        completed = rc in (0, 1) and not counts.get("interrupted")
        st = dict(counts, rc=rc, completed=completed, background=a.background, reported=not a.background,
                  finished_at=time.strftime("%Y-%m-%d %H:%M:%S %Z"),
                  last_completed=time.time() if completed else prev.get("last_completed"))
        try:
            write_state(data, st)
        except OSError:
            pass
        shutil.rmtree(lock, ignore_errors=True)
    return rc


def plan_and_run(a):
    """Dry run: exit code. Real run: (exit code, counts)."""
    pdir = plugins_dir()
    if not claude_bin():
        print("update-all.sh: the claude CLI is not on PATH", file=sys.stderr)
        return 2 if a.dry_run else (2, {})

    if a.no_refresh:
        print("Marketplaces: not refreshed (--no-refresh); comparing against the local clones as they are.")
    else:
        try:
            p = claude(["plugin", "marketplace", "update"], cwd=os.path.expanduser("~"))
            if p.returncode == 0:
                print("Marketplaces: refreshed.")
            else:
                print(f"Marketplaces: refresh failed (exit {p.returncode}: {tail(p.stderr) or tail(p.stdout)}); comparing against the clones as they are.")
        except (subprocess.TimeoutExpired, OSError) as e:
            print(f"Marketplaces: refresh failed ({e}); comparing against the clones as they are.")

    try:
        p = claude(["plugin", "list", "--json"], cwd=os.path.expanduser("~"), timeout=120)
        installs = json.loads(p.stdout)
        if not isinstance(installs, list):
            raise ValueError("not a list")
    except (subprocess.TimeoutExpired, OSError, ValueError) as e:
        print(f"update-all.sh: could not read `claude plugin list --json`: {e}", file=sys.stderr)
        return 2 if a.dry_run else (2, {})

    cat = load_catalog(pdir)
    installs = [i for i in installs if isinstance(i, dict) and i.get("id") and wanted(i, a)]
    installs.sort(key=lambda i: (i["id"], i.get("scope") != "user", i.get("projectPath") or ""))

    current, skipped, jobs = [], [], []
    for inst in installs:
        state, detail = classify(inst, cat)
        if state == "current":
            current.append(inst)
            continue
        blocked = why_not_updatable(inst)
        if blocked:
            skipped.append((inst, blocked))
            continue
        why = f"{inst.get('version')} → {detail}" if state == "outdated" else f"{inst.get('version')}: {detail}"
        jobs.append((inst, state, why))

    print(f"Installs: {len(installs)} matched; {len(current)} current, {len(jobs)} to update or check, {len(skipped)} skipped.")
    if a.dry_run:
        return dry_run_report(jobs, skipped)

    results = {"updated": [], "current": [], "failed": [], "needs_you": []}
    done, interrupted = 0, False
    try:
        for n, (inst, state, why) in enumerate(jobs, 1):
            bucket, line = run_one(inst)
            if bucket == "failed" and state == "unresolved" and "removed" in why:
                line += f" — removed from the marketplace; uninstall it: cd {folder_of(inst)} && claude plugin uninstall {inst['id']} --scope {inst['scope']}"
            results[bucket].append((inst, line))
            done = n
            print(f"[{n}/{len(jobs)}] {bucket:<9} {inst['id']}  {where(inst)}  {line}", flush=True)
    except KeyboardInterrupt:
        interrupted = True
        print(f"\nInterrupted after {done} of {len(jobs)}; the rest were not attempted.")
    rc = final_report(results, len(current), skipped)
    counts = {"updated": len(results["updated"]), "failed": len(results["failed"]),
              "needs_you": len(results["needs_you"]), "interrupted": interrupted,
              "orphaned": sum(1 for _, w in skipped if w == GONE),
              "worktree": sum(1 for _, w in skipped if w == WORKTREE)}
    return rc, counts


def dry_run_report(jobs, skipped):
    print("\nDry run: nothing was updated.")
    if jobs:
        print(f"\nWould run `claude plugin update` for {len(jobs)} install(s):")
        for inst, state, why in jobs:
            tag = "outdated " if state == "outdated" else "check    "
            print(f"  {tag} {inst['id']}  {where(inst)}  {why}")
    else:
        print("\nEvery matched install is current.")
    print_skipped(skipped)
    return 0


def print_skipped(skipped):
    if not skipped:
        return
    by_folder = {}
    other = []
    for inst, why in skipped:
        if why in (GONE, WORKTREE):
            by_folder.setdefault((why, inst.get("projectPath")), []).append(inst["id"])
        else:
            other.append((inst, why))
    print(f"\nSkipped ({len(skipped)}):")
    for (why, folder), ids in sorted(by_folder.items(), key=lambda kv: (kv[0][0], str(kv[0][1]))):
        names = ": " + ", ".join(sorted(ids)) if len(ids) <= 4 else ""
        print(f"  {folder}  {why} ({len(ids)} install(s){names})")
    for inst, why in other:
        print(f"  {inst['id']}  {where(inst)}  {why}")


def final_report(results, already_current, skipped):
    up, cur, failed, needs = results["updated"], results["current"], results["failed"], results["needs_you"]
    print("\nSummary")
    print(f"  updated          {len(up)}")
    print(f"  already current  {already_current + len(cur)}")
    print(f"  skipped          {len(skipped)}")
    print(f"  failed           {len(failed)}")
    print(f"  need you         {len(needs)}")
    if up:
        print(f"\nUpdated ({len(up)}):")
        for inst, line in up:
            print(f"  {inst['id']}  {where(inst)}  {line}")
    print_skipped(skipped)
    if failed:
        print(f"\nFailed ({len(failed)}):")
        for inst, line in failed:
            print(f"  {inst['id']}  {where(inst)}  {line}")
    if needs:
        print(f"\nNeed you ({len(needs)}): the marketplace-declared command changed, and this script never accepts one.")
        for inst, line in needs:
            print(f"  {inst['id']}  {where(inst)}  {line}")
            print(f"    review and accept it yourself: cd {folder_of(inst)} && claude plugin update {inst['id']} --scope {inst['scope']}")
    if up:
        print("\nRestart running Claude Code sessions (or run /reload-plugins in each) to load the updated plugins.")
    else:
        print("\nNothing was updated; no restart needed.")
    return 1 if failed or needs else 0


def main(argv):
    if argv[:1] == ["hook"]:
        hook()
        return 0
    if argv[:1] == ["update"]:
        return update(argv[1:])
    print("usage: plugin_updates.py update [options] | hook", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
