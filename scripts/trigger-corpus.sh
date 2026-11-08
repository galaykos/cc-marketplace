#!/usr/bin/env bash
# trigger-corpus.sh [--root DIR] [--corpus FILE] — ranks every SKILL.md description against labelled prompts (BM25, stdlib Python): a `gate` row whose expected skill falls out of the top 3 prints `FAIL trigger: …` (exit 1); a `known-miss` row prints `WARN` and, once it ranks top 3, a promote hint; skill pairs in different plugins with near-identical descriptions print `WARN collision: …`.
# Misses: how the model actually routes (lexical ranking is a proxy: it catches a description edit that drops a trigger word, not a model choosing differently), commands (only skills are ranked), and prompts nobody added.
# Why, limits, history: rationale/derivations/scripts.md § scripts/trigger-corpus.sh
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd); corpus=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) root=$2; shift 2 ;;
    --corpus) corpus=$2; shift 2 ;;
    *) printf 'trigger-corpus: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$corpus" ] || corpus="$root/scripts/trigger-corpus.tsv"
[ -r "$corpus" ] || { printf 'trigger-corpus: no corpus at %s\n' "$corpus" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'trigger-corpus: python3 is required\n' >&2; exit 2; }
python3 -I - "$root" "$corpus" <<'PY'
import collections, glob, math, re, sys
root, corpus = sys.argv[1], sys.argv[2]
STOP = set("a an the and or of to in on for with when use is are be it its this that as at by from into your you not no any each per than then via vs".split())
def toks(s):
    words = []
    for w in re.findall(r"[a-z0-9][a-z0-9+#.-]*", s.lower()):
        w = w.strip(".-"); words.append(w)
        if "-" in w: words += w.split("-")
    out = []
    for w in words:
        if not w or w in STOP or len(w) < 2: continue
        for suf in ("ing", "ed", "es", "s"):
            if len(w) > 4 and w.endswith(suf): w = w[:-len(suf)]; break
        out.append(w)
    return out
docs = {}
for p in sorted(glob.glob(root + "/plugins/*/skills/*/SKILL.md")):
    txt = open(p, encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---", txt, re.S)
    if not m: continue
    fm = m.group(1)
    get = lambda k: (re.search(r"^%s:\s*(.+)$" % k, fm, re.M) or [None, ""])[1]
    plugin = p.split("/plugins/")[1].split("/")[0]
    key = "%s:%s" % (plugin, (get("name") or p.split("/")[-2]).strip())
    docs[key] = toks(get("description") + " " + get("when_to_use") + " " + key.replace(":", " "))
N = len(docs); avg = sum(len(d) for d in docs.values()) / max(N, 1)
df = collections.Counter(t for d in docs.values() for t in set(d))
tfs = {k: collections.Counter(d) for k, d in docs.items()}
def rank(q):
    qs = toks(q); res = []
    for k, d in docs.items():
        tf, s = tfs[k], 0.0
        for t in qs:
            if t in tf:
                idf = math.log(1 + (N - df[t] + 0.5) / (df[t] + 0.5))
                s += idf * tf[t] * 2.2 / (tf[t] + 1.2 * (0.25 + 0.75 * len(d) / avg))
        res.append((s, k))
    return [k for s, k in sorted(res, reverse=True) if s > 0]
fail = 0; allowed = set()
for n, line in enumerate(open(corpus, encoding="utf-8"), 1):
    line = line.rstrip("\n")
    if line.startswith("# collision-ok:"):
        a, b = line[len("# collision-ok:"):].split()[:2]; allowed.add(frozenset((a, b))); continue
    if not line.strip() or line.startswith("#"): continue
    cols = line.split("\t")
    if len(cols) != 3 or cols[0] not in ("gate", "known-miss"):
        print("FAIL trigger: %s:%d is not `gate|known-miss<TAB>plugin:skill<TAB>prompt`" % (corpus, n)); fail = 1; continue
    status, want, prompt = cols
    if want not in docs:
        print("FAIL trigger: %s:%d names %s, which is not a skill" % (corpus, n, want)); fail = 1; continue
    top = rank(prompt)[:3]
    if status == "gate" and want not in top:
        print("FAIL trigger: \"%s\" should rank %s in the top 3, got %s" % (prompt, want, ", ".join(top) or "nothing")); fail = 1
    elif status == "known-miss":
        if want in top: print("WARN trigger: known-miss \"%s\" now ranks %s in the top 3: change it to gate" % (prompt, want))
        else: print("WARN trigger: known-miss \"%s\" ranks %s, not %s" % (prompt, ", ".join(top) or "nothing", want))
vec = {}
for k, d in docs.items():
    tf = tfs[k]; v = {t: c * math.log(N / df[t]) for t, c in tf.items()}
    norm = math.sqrt(sum(x * x for x in v.values())) or 1.0
    vec[k] = {t: x / norm for t, x in v.items()}
keys = sorted(docs)
for i, a in enumerate(keys):
    for b in keys[i + 1:]:
        if a.split(":")[0] == b.split(":")[0] or frozenset((a, b)) in allowed: continue
        va, vb = vec[a], vec[b]
        cos = sum(x * vb.get(t, 0.0) for t, x in va.items())
        if cos >= 0.3:
            print("WARN collision: %s and %s descriptions are %.2f similar: add a near-miss clause to one, or `# collision-ok: %s %s` in the corpus" % (a, b, cos, a, b))
sys.exit(fail)
PY
