#!/usr/bin/env bash
# comment-stats.sh [--top N] [--json] — whole-line comment share of .sh .ts .mts .js .mjs .py by area, top N files, house headers.
# Misses trailing comments and docstrings; counts #-lines in heredocs and // in template strings as comments. Exits 0 always.
# Why, limits, history: rationale/derivations/scripts.md § scripts/comment-stats.sh
set -u

top=15
as_json=0
while [ $# -gt 0 ]; do
  case "$1" in
    --top)
      [ $# -ge 2 ] || { echo "comment-stats: --top needs a value" >&2; exit 0; }
      case "$2" in ''|*[!0-9]*) echo "comment-stats: --top needs an integer, got $2" >&2; exit 0 ;; esac
      top="$2"; shift 2 ;;
    --json) as_json=1; shift ;;
    -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
    *) echo "comment-stats: unknown argument $1" >&2; exit 0 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "comment-stats: python3 not found, skipping"; exit 0; }

CS_ROOT="$(cd "$(dirname "$0")/.." && pwd)" CS_TOP="$top" CS_JSON="$as_json" python3 - <<'PY'
import json, os

ROOT, TOP, AS_JSON = os.environ["CS_ROOT"], int(os.environ["CS_TOP"]), os.environ["CS_JSON"] == "1"
EXTS = (".sh", ".ts", ".mts", ".js", ".mjs", ".py")
AREAS = ("plugin hooks", "plugin scripts", "scripts/", "scripts/smoke", "scripts/lib", "tests")
SKIP_DIRS = {"node_modules", ".git", ".claude", ".claude-plugin", "__pycache__"}
POINTER = "Why, limits, history:"

def area(p):
    name = p.rsplit("/", 1)[-1]
    if ".test." in name or ".spec." in name:
        return "tests"
    if p.startswith("plugins/"):
        if "/__tests__/" in p or "/tests/" in p:
            return "tests"
        return "plugin hooks" if p.split("/")[2:3] == ["hooks"] else "plugin scripts"
    for prefix, name in (("scripts/lib/", "scripts/lib"), ("scripts/smoke/", "scripts/smoke"), ("scripts/", "scripts/")):
        if p.startswith(prefix):
            return name
    return None

def classify(path):
    """Per line: 'c' comment, 'k' code, None blank or shebang."""
    hash_style = path.endswith((".sh", ".py"))
    out, in_block = [], False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for i, line in enumerate(fh):
            s = line.strip()
            if not s or (i == 0 and s.startswith("#!")):
                out.append(None)
            elif hash_style:
                out.append("c" if s.startswith("#") else "k")
            elif in_block:
                out.append("c")
                in_block = "*/" not in s
            elif s.startswith("//"):
                out.append("c")
            elif s.startswith("/*"):
                out.append("c")
                in_block = "*/" not in s[2:]
            else:
                out.append("k")
    return out

def header_ok(path, kinds):
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    i = 0
    while i < len(kinds) and kinds[i] is None:
        i += 1
    j = i
    while j < len(kinds) and kinds[j] == "c":
        j += 1
    return 1 <= j - i <= 3 and any(POINTER in l for l in lines[i:j])

rows = []
for top_dir in ("plugins", "scripts"):
    for d, dirs, names in os.walk(os.path.join(ROOT, top_dir)):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
        for n in sorted(names):
            if not n.endswith(EXTS):
                continue
            full = os.path.join(d, n)
            rel = os.path.relpath(full, ROOT).replace(os.sep, "/")
            a = area(rel)
            if not a:
                continue
            kinds = classify(full)
            rows.append({"path": rel, "area": a, "comment": kinds.count("c"),
                         "code": kinds.count("k"), "header": header_ok(full, kinds)})

def share(c, k):
    return round(100.0 * c / (c + k), 1) if c + k else 0.0

def pool(rs):
    c, k = sum(r["comment"] for r in rs), sum(r["code"] for r in rs)
    return {"files": len(rs), "code": k, "comment": c, "share_pct": share(c, k)}
total = pool(rows)
non_test = pool([r for r in rows if r["area"] != "tests"])
areas = {a: pool([r for r in rows if r["area"] == a]) for a in AREAS}
headers = sum(1 for r in rows if r["header"])
top = sorted(rows, key=lambda r: (-r["comment"], r["path"]))[:TOP]
for r in top:
    r["share_pct"] = share(r["comment"], r["code"])

if AS_JSON:
    print(json.dumps({"areas": areas, "all": total, "non_test": non_test,
                      "house_header": {"compliant": headers, "files": len(rows)},
                      "top": top}, indent=2))
    raise SystemExit(0)

print("comment-stats — whole-line comment share (.sh .ts .mts .js .mjs .py; blank lines and shebangs excluded)")
print("MAINTAINER PATH: reports only, exits 0.\n")
print(f"  {'area':16} {'files':>6} {'code':>7} {'comment':>8} {'share':>7}")
for a, v in list(areas.items()) + [("all but tests", non_test), ("all", total)]:
    print(f"  {a:16} {v['files']:6} {v['code']:7} {v['comment']:8} {v['share_pct']:6.1f}%")
print(f"\nhouse header (first comment block, at most 3 lines, naming '{POINTER}'): "
      f"{headers} of {len(rows)} files")
print(f"\ntop {len(top)} files by comment lines")
print(f"  {'comment':>7} {'code':>6} {'share':>7} {'header':>6}  path")
for r in top:
    print(f"  {r['comment']:7} {r['code']:6} {r['share_pct']:6.1f}% {('yes' if r['header'] else 'no'):>6}  {r['path']}")
PY
exit 0
