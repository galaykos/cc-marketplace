#!/usr/bin/env bash
# readability.sh [--top N] [--json] — sentences, words per sentence and % over 30 words for README openings, SKILL and command frontmatter, CLAUDE.md prose; worst N passages.
# Sentence splitting is heuristic (a full stop, then a capital, digit or markup); a code span counts as one word. Measures length, never clarity. Exits 0 always.
# Why, limits, history: rationale/derivations/scripts.md § scripts/readability.sh
set -u

top=10
as_json=0
while [ $# -gt 0 ]; do
  case "$1" in
    --top)
      [ $# -ge 2 ] || { echo "readability: --top needs a value" >&2; exit 0; }
      case "$2" in ''|*[!0-9]*) echo "readability: --top needs an integer, got $2" >&2; exit 0 ;; esac
      top="$2"; shift 2 ;;
    --json) as_json=1; shift ;;
    -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
    *) echo "readability: unknown argument $1" >&2; exit 0 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "readability: python3 not found, skipping"; exit 0; }

RD_ROOT="$(cd "$(dirname "$0")/.." && pwd)" RD_TOP="$top" RD_JSON="$as_json" python3 - <<'PY'
import glob, json, os, re

ROOT, TOP, AS_JSON = os.environ["RD_ROOT"], int(os.environ["RD_TOP"]), os.environ["RD_JSON"] == "1"
WORD = re.compile(r"[A-Za-z0-9][\w'/\-.]*")
ABBR = re.compile(r"\b(e\.g|i\.e|vs|etc|cf|approx|incl)\.", re.I)
SPLIT = re.compile(r"(?<=[.!?])\s+(?=[A-Z0-9`\"(\[*_/])")
LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+\.)\s+")
POOLS = ("README openings", "SKILL description+when_to_use", "command descriptions", "CLAUDE.md prose")

def sentences(text):
    t = re.sub(r"<!--.*?-->", " ", text)
    t = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", t)
    t = re.sub(r"`[^`]*`", "CODE", t)
    t = ABBR.sub(lambda m: m.group(0)[:-1], t)
    t = re.sub(r"\s+", " ", t).strip()
    return [len(WORD.findall(s)) for s in SPLIT.split(t) if WORD.search(s)]

def rel(p):
    return os.path.relpath(p, ROOT).replace(os.sep, "/")

def lines_of(p):
    return open(p, encoding="utf-8", errors="replace").read().split("\n")

def readme_opening(p):
    """(line, text) of the first prose paragraph after the title."""
    ls = lines_of(p)
    i = next((n + 1 for n, l in enumerate(ls) if l.startswith("# ")), 0)
    while i < len(ls):
        s = ls[i].strip()
        if s and not s.startswith(("#", "|", "```", "<", "![", "[![", "---")):
            break
        i += 1
    para, j = [], i
    while j < len(ls) and ls[j].strip() and not ls[j].strip().startswith(("#", "|", "```")):
        para.append(ls[j].strip().lstrip("> "))
        j += 1
    return i + 1, " ".join(para)

def frontmatter(p):
    """Line-based on purpose: several skill frontmatters are not strict YAML."""
    ls, out, key = lines_of(p), {}, None
    if not ls or ls[0].strip() != "---":
        return out
    for n, l in enumerate(ls[1:], 2):
        if l.strip() == "---":
            break
        m = re.match(r"^([A-Za-z_][\w-]*):\s?(.*)$", l)
        if m:
            key, v = m.group(1), m.group(2).strip()
            v = "" if v in (">", "|", ">-", "|-", ">+", "|+") else v
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                v = v[1:-1]
            out[key] = [n, v]
        elif key and l[:1] in (" ", "\t"):
            out[key][1] = (out[key][1] + " " + l.strip()).strip()
    return out

def claude_md_passages(p):
    out, cur, start, fence = [], [], 0, False
    for n, l in enumerate(lines_of(p), 1):
        s = l.strip()
        if s.startswith("```"):
            fence = not fence
        skip = fence or s.startswith(("```", "#", "|", "<!--"))
        if skip or not s or LIST_ITEM.match(l):
            if cur:
                out.append((start, " ".join(cur)))
            cur = []
        if skip or not s:
            continue
        if not cur:
            start = n
        cur.append(LIST_ITEM.sub("", l).strip())
    if cur:
        out.append((start, " ".join(cur)))
    return out

passages = []
def add(pool, path, line, counts):
    if counts:
        passages.append({"pool": pool, "path": rel(path), "line": line, "counts": counts})

for p in [os.path.join(ROOT, "README.md")] + sorted(glob.glob(os.path.join(ROOT, "plugins/*/README.md"))):
    if os.path.isfile(p):
        line, text = readme_opening(p)
        add(POOLS[0], p, line, sentences(text))
for p in sorted(glob.glob(os.path.join(ROOT, "plugins/*/skills/*/SKILL.md"))):
    fm = frontmatter(p)
    keys = [k for k in ("description", "when_to_use") if k in fm]
    if keys:
        add(POOLS[1], p, fm[keys[0]][0], [w for k in keys for w in sentences(fm[k][1])])
for p in sorted(glob.glob(os.path.join(ROOT, "plugins/*/commands/*.md"))):
    fm = frontmatter(p)
    if "description" in fm:
        add(POOLS[2], p, fm["description"][0], sentences(fm["description"][1]))
cm = os.path.join(ROOT, "CLAUDE.md")
if os.path.isfile(cm):
    for line, text in claude_md_passages(cm):
        add(POOLS[3], cm, line, sentences(text))

def stats(counts):
    n, w, over = len(counts), sum(counts), sum(1 for c in counts if c > 30)
    return {"sentences": n, "words": w, "words_per_sentence": round(w / n, 1) if n else 0.0,
            "over_30": over, "over_30_pct": round(100.0 * over / n, 1) if n else 0.0}

pools = {}
for name in POOLS:
    ps = [x for x in passages if x["pool"] == name]
    pools[name] = dict(passages=len(ps), **stats([c for x in ps for c in x["counts"]]))
worst = sorted(({"path": x["path"], "line": x["line"], "pool": x["pool"],
                 "sentences": len(x["counts"]),
                 "words_per_sentence": round(sum(x["counts"]) / len(x["counts"]), 1)} for x in passages),
               key=lambda r: (-r["words_per_sentence"], r["path"], r["line"]))[:TOP]

if AS_JSON:
    print(json.dumps({"pools": pools, "worst": worst}, indent=2))
    raise SystemExit(0)

print("readability — sentence length in installer- and contributor-facing prose")
print("MAINTAINER PATH: reports only, exits 0. Long sentences are a signal, not a verdict.\n")
print(f"  {'pool':30} {'passages':>8} {'sentences':>9} {'words/sentence':>14} {'over 30 words':>13}")
for name, v in pools.items():
    print(f"  {name:30} {v['passages']:8} {v['sentences']:9} {v['words_per_sentence']:14.1f} {v['over_30_pct']:12.1f}%")
print(f"\nworst {len(worst)} passages")
for r in worst:
    print(f"  {r['path']}:{r['line']} — {r['words_per_sentence']:.1f} words/sentence")
PY
exit 0
