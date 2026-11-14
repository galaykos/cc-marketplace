#!/usr/bin/env bash
# dk-usage.sh — did design-kit earn its place? One row per surface, per project.
#
# WHAT IT READS, per project directory given (default: cwd), in $DK =
# .cc-artifacts/design-kit (else the .design-kit/ plugins before 2026-11-14 wrote):
#   $DK/usage.jsonl             one line per dk verb: {ts, verb, outcome, artifact}
#   $DK/decisions.jsonl         one line per board pick: {ts, board, picked, knobs,
#                               text, prompt, consumed}
#   $DK/{decks,boards,artifacts,previews,exports}/  file mtimes
#   $DK/design-system/DECISIONS.md  the decision ledger, if any (else design-system/)
#   git log                     commits touching component paths a decision names,
#                               in the seven days after that decision
#
# WHAT EACH COLUMN MEANS
#   created    pages of that surface that exist
#   revisited  pages whose mtime moved more than a day after their first version
#   picked     decision rows (boards) / consumed decision rows (in-codebase)
#   rendered   scratch verbs with outcome ok (in-codebase only)
#   exported   export verbs with outcome ok, or .pdf/.png beside a deck or board
#   shared     share verbs with outcome ok (LAN, pages branch, zip)
#   followed-by-commit  commits in the 7 days after a decision that touch a path the
#              decision names; `n/a` when no decision names a path — never 0, because
#              0 would claim a measurement this script did not make
#
# WHAT IT CANNOT SEE. Subagent turns; a pick pasted via the clipboard instead of the
# board's decision route (that is prose in a transcript, not a decision row); a deck
# opened in a browser (no request log); anything in a project you did not pass.
# Zero proves nobody used it HERE; non-zero proves it fired, not that it helped.
#
# THE VERDICT LINE. The plugin README commits to a kill trigger: 30 days after 0.2.0,
# at least three projects with a design-kit folder present, followed-by-commit = 0 AND
# shared = 0 across all of them → retire. This script prints that line with the
# numbers it measured; it does not decide.
#
# Standing: scripts/__tests__/dk-usage.test.sh drives a fabricated project (every
# column non-zero) and an empty one (all zeros, n/a). Always exits 0.
set -euo pipefail

projects=(); since=""; json=0
while [ $# -gt 0 ]; do
  case "$1" in
    --projects) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do projects+=("$1"); shift; done; continue ;;
    --since) since="$2"; shift ;;
    --json) json=1 ;;
    -h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    *) echo "dk-usage.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done
[ ${#projects[@]} -gt 0 ] || projects=(".")

DK_SINCE="$since" DK_JSON="$json" python3 - "${projects[@]}" <<'PY'
import datetime as dt, glob, json, os, re, subprocess, sys

SURFACES = ["system", "slides", "design", "in-codebase", "artifact"]
DIRS = {"slides": "decks", "design": "boards", "artifact": "artifacts", "in-codebase": "previews"}
VERB_SURFACE = {"system": "system", "check": "system", "slides": "slides", "board": "design",
                "decision": "design", "scratch": "in-codebase", "bundle": "artifact", "share": "artifact"}
since_days = os.environ.get("DK_SINCE") or ""
cutoff = None
if since_days:
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=int(since_days))


def parse_ts(s):
    try:
        t = dt.datetime.fromisoformat(str(s).replace("Z", "+00:00"))
        return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)
    except (ValueError, TypeError):
        return None


def dk(project):
    """The project's design-kit folder; plugins before 2026-11-14 wrote .design-kit/, read while the new one is absent."""
    new = os.path.join(project, ".cc-artifacts", "design-kit")
    return new if os.path.isdir(new) else os.path.join(project, ".design-kit")


def ds(project, name):
    """A design-system file, new path first, else the design-system/ plugins before 2026-11-14 wrote."""
    new = os.path.join(project, ".cc-artifacts", "design-kit", "design-system", name)
    return new if os.path.isfile(new) else os.path.join(project, "design-system", name)


def jsonl(path):
    rows = []
    if not os.path.isfile(path):
        return rows
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    if cutoff:
        rows = [r for r in rows if (parse_ts(r.get("ts")) or cutoff) >= cutoff]
    return rows


def pages(project, surface):
    if surface == "system":
        return [ds(project, "tokens.json")] if os.path.isfile(ds(project, "tokens.json")) else []
    d = os.path.join(dk(project), DIRS[surface])
    return [p for p in glob.glob(os.path.join(d, "*.html")) if not os.path.basename(p).startswith(".")]


def revisited(project, surface, files):
    n = 0
    for f in files:
        first = None
        if surface == "artifact":
            slug = os.path.basename(f)[:-5]
            v1 = os.path.join(os.path.dirname(f), ".versions", slug, "v1.html")
            first = os.stat(v1).st_mtime if os.path.isfile(v1) else None
        elif surface == "system":
            md = ds(project, "DESIGN-SYSTEM.md")
            first = os.stat(md).st_mtime if os.path.isfile(md) else None
        if first is None:
            try:
                first = os.stat(f).st_ctime
            except OSError:
                continue
        if os.stat(f).st_mtime - first > 86400:
            n += 1
    return n


def named_paths(project, decisions):
    paths = set()
    for r in decisions:
        for k in ("components", "paths"):
            for p in r.get(k) or []:
                paths.add(str(p))
        m = re.findall(r"`([^`]+\.(?:tsx|jsx|vue|blade\.php|svelte|astro))`", str(r.get("prompt", "")))
        paths.update(m)
    ledger = ds(project, "DECISIONS.md")
    if os.path.isfile(ledger):
        txt = open(ledger, encoding="utf-8", errors="replace").read()
        paths.update(re.findall(r"`([^`\s]+\.(?:tsx|jsx|vue|blade\.php|svelte|astro))`", txt))
    return sorted(paths)


def commits_after(project, decisions, paths):
    if not paths or not decisions:
        return "n/a"
    if not os.path.isdir(os.path.join(project, ".git")):
        return "n/a"
    seen = set()  # a commit follows a decision once, however many decisions precede it
    for r in decisions:
        t = parse_ts(r.get("ts"))
        if not t:
            continue
        until = t + dt.timedelta(days=7)
        try:
            out = subprocess.run(
                ["git", "-C", project, "log", "--format=%H", f"--since={t.isoformat()}", f"--until={until.isoformat()}", "--", *paths],
                capture_output=True, text=True, check=False).stdout
        except OSError:
            return "n/a"
        seen.update(l.strip() for l in out.splitlines() if l.strip())
    return len(seen)


report = []
for project in sys.argv[1:]:
    project = os.path.abspath(project)
    usage = jsonl(os.path.join(dk(project), "usage.jsonl"))
    decisions = jsonl(os.path.join(dk(project), "decisions.jsonl"))
    present = os.path.isdir(dk(project))
    rows = {}
    for s in SURFACES:
        files = pages(project, s)
        verbs = [u for u in usage if VERB_SURFACE.get(u.get("verb")) == s and u.get("outcome") == "ok"]
        exported = sum(1 for u in usage if u.get("verb") == "export" and u.get("outcome") == "ok"
                       and VERB_SURFACE.get(os.path.basename(os.path.dirname(str(u.get("artifact", "")))).replace("decks", "slides").replace("boards", "board"), "") == s)
        if s in ("slides", "design"):
            exported += len(glob.glob(os.path.join(dk(project), DIRS[s], "*.pdf"))) + len(glob.glob(os.path.join(dk(project), DIRS[s], "*-board-*.png")))
        rows[s] = {
            "created": len(files),
            "revisited": revisited(project, s, files),
            "picked": (len(decisions) if s == "design" else sum(1 for d in decisions if d.get("consumed")) if s == "in-codebase" else 0),
            "rendered": sum(1 for u in verbs if u.get("verb") == "scratch") if s == "in-codebase" else 0,
            "exported": exported,
            "shared": sum(1 for u in verbs if u.get("verb") == "share") if s == "artifact" else 0,
        }
    paths = named_paths(project, decisions)
    followed = commits_after(project, decisions, paths)
    report.append({"project": project, "present": present, "surfaces": rows, "named_paths": paths, "followed_by_commit": followed,
                   "usage_rows": len(usage), "decision_rows": len(decisions)})

if os.environ.get("DK_JSON") == "1":
    print(json.dumps(report, indent=1))
    sys.exit(0)

cols = ["created", "revisited", "picked", "rendered", "exported", "shared"]
for r in report:
    print(f"project: {r['project']}  (design-kit folder present: {'yes' if r['present'] else 'no'}; usage rows {r['usage_rows']}, decision rows {r['decision_rows']})")
    print("| surface | " + " | ".join(cols) + " | followed-by-commit |")
    print("|---|" + "---|" * (len(cols) + 1))
    for s in SURFACES:
        v = r["surfaces"][s]
        fbc = r["followed_by_commit"] if s in ("design", "in-codebase") else "-"
        print(f"| {s} | " + " | ".join(str(v[c]) for c in cols) + f" | {fbc} |")
    if r["named_paths"]:
        print("named paths: " + ", ".join(r["named_paths"]))
    print()

present_n = sum(1 for r in report if r["present"])
shared_n = sum(r["surfaces"]["artifact"]["shared"] for r in report)
fbc_vals = [r["followed_by_commit"] for r in report if r["followed_by_commit"] != "n/a"]
fbc_total = sum(fbc_vals) if fbc_vals else "n/a"
print(f"verdict inputs: projects with a design-kit folder = {present_n}; shared = {shared_n}; followed-by-commit = {fbc_total}")
print("kill trigger (README, Measured): 30 days after 0.2.0, projects >= 3, followed-by-commit = 0 AND shared = 0 -> retire. This script measures; it does not decide.")
PY
