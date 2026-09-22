#!/usr/bin/env bash
# dk.sh — the ONE entry point for every design-kit surface, so a user grants one
# permission rule (`Bash(bash */design-kit/scripts/dk.sh*)`) instead of one per
# script, and so the five commands share one state file instead of re-typing the
# brief, device, theme and pick.
#
#   dk serve [--lan|--stop]                 start / expose / stop the preview server, print its URL
#   dk system [target] [--out DIR]          extract → copy kit into previews → serve → URL
#   dk check                                one line: design-system current, moved, or missing
#   dk drift [PATHS|--staged|--diff REF] [--ci]   literal colours + named Tailwind palette
#                                           utilities in components that reach no token
#   dk slides <outline.md> [--theme FILE]   build a deck, record it, print its URL
#   dk board <spec.json|.md> [--device D]   build a board, record it, print its URL
#   dk scratch --detect|--create SLUG|--cleanup|--verify [--stack S]
#   dk bundle <input> [--name SLUG] [--zip] bundle an artifact, record it, print its URL
#   dk share <page> --lan | --pages [--push] | --zip
#   dk export <file> --pdf|--png|--pptx     deck (pdf/pptx) or board (png/pdf) export
#   dk decision [--latest|--board FILE] [--consume] | --record "LINE"
#   dk status                               the workshop flow as text
#
# STATE. Every verb appends one JSON line to .design-kit/usage.jsonl
# ({ts, verb, outcome, artifact}) and updates only its own keys in
# .design-kit/workshop.json ({brief, device, theme, system, board, scratch,
# artifacts, deck}). `dk decision` reads .design-kit/decisions.jsonl, which the
# board writes through the server's loopback-only /_decision route, and prints
# exactly the prose the board's "Copy edits as prompt" button produces; --consume
# marks that row read; --record appends one human line to design-system/DECISIONS.md.
#
# WHAT IT DOES NOT DO. It asks no questions — every consent (write into the tree,
# share, install pptxgenjs, push) stays in the command that calls it. It never
# assembles a URL from a literal port: the URL is what preview.sh wrote to
# .design-kit/.preview.url. Standing: scripts/__tests__/dk.test.sh drives every
# verb against a temp project; the wrapped scripts keep their own harnesses.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
DK="${DESIGN_KIT_DIR:-.design-kit}"
WS="$DK/workshop.json"; USAGE="$DK/usage.jsonl"; DEC="$DK/decisions.jsonl"
verb="${1:-}"; [ $# -gt 0 ] && shift

# ensure_ignored — the plugin's scratch paths never reach a commit by accident.
# Once per repo: inside a git work tree, when .design-kit/ or __design-kit__/ is not
# already ignored, append one managed block to .gitignore (idempotent — re-runs
# rewrite the block, never duplicate it) and say so in one line. design-system/ is
# NOT added: it is the tracked record. Outside git, nothing. DESIGN_KIT_IGNORE=off
# skips it (a repo that wants the previews committed).
ensure_ignored() {
  [ "${DESIGN_KIT_IGNORE:-on}" = "off" ] && return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local root; root="$(git rev-parse --show-toplevel)"
  if git -C "$root" check-ignore -q "$DK/x" 2>/dev/null && git -C "$root" check-ignore -q "__design-kit__/x" 2>/dev/null; then return 0; fi
  # tracked on purpose (a repo that commits its evidence): say nothing, touch nothing
  [ -n "$(git -C "$root" ls-files -- "$DK" "__design-kit__" 2>/dev/null)" ] && return 0
  python3 - "$root/.gitignore" "$DK/" "__design-kit__/" <<'PY'
import sys, re
p, *pats = sys.argv[1:]
start, end = "# >>> design-kit scratch (managed by design-kit dk.sh) >>>", "# <<< design-kit scratch <<<"
try: s = open(p, encoding="utf-8").read()
except FileNotFoundError: s = ""
block = start + "\n" + "\n".join(pats) + "\n" + end + "\n"
if start in s and end in s:
    s = re.sub(re.escape(start) + r".*?" + re.escape(end) + r"\n?", block, s, count=1, flags=re.S)
else:
    s = s + ("" if s.endswith("\n") or not s else "\n") + block
open(p, "w", encoding="utf-8").write(s)
PY
  echo "design-kit: added $DK/ and __design-kit__/ to .gitignore (managed block; DESIGN_KIT_IGNORE=off to skip)"
}
ensure_ignored
mkdir -p "$DK"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { # log <outcome> [artifact]
  python3 - "$USAGE" "$verb" "$1" "${2:-}" <<'PY'
import json, sys, time
p, verb, outcome, artifact = sys.argv[1:5]
with open(p, "a", encoding="utf-8") as fh:
    fh.write(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "verb": verb, "outcome": outcome, "artifact": artifact}) + "\n")
PY
}
ws_set() { # ws_set <key> <json-value>   (a dotted key sets one nested field; a bare key replaces)
  python3 - "$WS" "$1" "$2" <<'PY'
import json, os, sys
p, key, val = sys.argv[1:4]
try:
    ws = json.load(open(p, encoding="utf-8"))
except (OSError, ValueError):
    ws = {}
val = json.loads(val)
parts = key.split(".")
node = ws
for k in parts[:-1]:
    node = node.setdefault(k, {}) if isinstance(node.get(k), dict) or k not in node else node[k]
if parts[-1] == "artifacts+":
    node.setdefault("artifacts", []).append(val)
else:
    node[parts[-1]] = val
with open(p, "w", encoding="utf-8") as fh:
    json.dump(ws, fh, indent=1)
PY
}
ws_get() { python3 -c 'import json,sys
try: ws=json.load(open(sys.argv[1]))
except Exception: ws={}
v=ws
for k in sys.argv[2].split("."):
    v=v.get(k) if isinstance(v,dict) else None
print("" if v is None else v)' "$WS" "$1"; }
url() { cat "$DK/.preview.url" 2>/dev/null || true; }
ensure_server() { # stdout: the URL only; preview.sh's own lines go to stderr
  local out; out="$(bash "$here/preview.sh" --docroot "$DK" "$@")" || { echo "$out" >&2; return 4; }
  echo "$out" | grep -v '^preview: http' >&2 || true
  local u; u="$(url)"; [ -n "$u" ] || { echo "dk: preview server did not start" >&2; return 4; }
  echo "$u"
}
fail() { log fail "${2:-}"; echo "dk $verb: $1" >&2; exit "${3:-1}"; }
tokens_sha() { python3 -c 'import hashlib,sys
try: print(hashlib.sha256(open("design-system/tokens.json","rb").read()).hexdigest()[:12])
except OSError: print("")'; }

case "$verb" in
  serve)
    if [ "${1:-}" = "--stop" ]; then bash "$here/preview.sh" --docroot "$DK" --stop; log ok; exit 0; fi
    lan=""; [ "${1:-}" = "--lan" ] && lan="--lan"
    base="$(ensure_server $lan)"; echo "url=$base"; log ok ;;

  system)
    target="."; out="design-system"; args=()
    while [ $# -gt 0 ]; do case "$1" in --out) out="$2"; shift ;; --source|--project-name) args+=("$1" "$2"); shift ;; *) target="$1" ;; esac; shift; done
    python3 "$here/system-extract.py" "$target" --out "$out" --dry-run ${args[@]+"${args[@]}"} || fail "dry-run failed" "" 1
    python3 "$here/system-extract.py" "$target" --out "$out" ${args[@]+"${args[@]}"} || fail "extraction failed" "" 1
    mkdir -p "$DK/previews"; cp "$out/kit.html" "$DK/previews/kit.html"
    base="$(ensure_server)"
    ws_set system "{\"stamp\":\"$(tokens_sha)\",\"at\":\"$(now)\",\"out\":\"$out\"}"
    echo "url=${base}previews/kit.html"; log ok "$out/tokens.json" ;;

  check)
    if [ ! -f design-system/tokens.json ]; then echo "design-system: none — run /design-kit:system first"; log skip; exit 0; fi
    set +e; out="$(python3 "$here/system-extract.py" . --dry-run --check 2>&1)"; rc=$?; set -e
    if echo "$out" | grep -q "unrecognized arguments: --check"; then echo "design-system: check unavailable in this build"; log skip; exit 0; fi
    if [ "$rc" = 0 ]; then echo "design-system: current"; log ok; exit 0; fi
    echo "$out" | grep -E '^check:' || echo "$out" | tail -3
    log ok; exit 0 ;;

  drift)
    # WHAT IT CATCHES. Literal hex/rgb/hsl/oklch colours and named Tailwind palette
    # utilities in .tsx/.jsx/.vue/.blade.php/.css/.scss that resolve to no declared
    # token. WHAT IT DOES NOT. Spacing, radius, shadow and font drift; a colour
    # computed at runtime; a token used in the wrong role. handoff-drift.py's header
    # carries the full residual list.
    #
    # --staged and --diff resolve the FILE LIST here, in git, so the python stays
    # git-free and one reader serves both modes. --diff compares against the WORKING
    # TREE, not HEAD: a check run before committing that reads HEAD is blind to the
    # edit it was run for, which is the trap this repo has already paid for once.
    ci=""; paths=(); selector=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --ci) ci="--ci" ;;
        --staged) selector="--staged"
                  while IFS= read -r f; do [ -n "$f" ] && paths+=("$f"); done < <(git diff --cached --name-only --relative --diff-filter=ACMR 2>/dev/null) ;;
        --diff) base="${2:-}"; [ -n "$base" ] || fail "--diff needs a base ref" "" 2; shift; selector="--diff $base"
                while IFS= read -r f; do [ -n "$f" ] && paths+=("$f"); done < <(git diff --name-only --relative --diff-filter=ACMR "$base" 2>/dev/null) ;;
        *) paths+=("$1") ;;
      esac; shift
    done
    # AN EMPTY SELECTOR SCANS NOTHING, never the whole tree. `--staged` with nothing
    # staged, or `--diff <base>` with no changed file, used to fall through to `.`
    # and red a --ci run over code the change never touched.
    if [ -n "$selector" ] && [ ${#paths[@]} -eq 0 ]; then
      echo "drift: $selector selected no file — nothing scanned"; log skip; exit 0
    fi
    [ ${#paths[@]} -gt 0 ] || paths=(".")
    set +e; python3 "$here/handoff-drift.py" --scan ${ci:+"$ci"} "${paths[@]}"; rc=$?; set -e
    case "$rc" in
      0) log ok ;;
      2) log skip ;;
      *) log fail ;;
    esac
    exit "$rc" ;;

  slides)
    outline="${1:-}"; [ -n "$outline" ] || fail "needs an outline path" "" 2; shift
    set +e; out="$(python3 "$here/deck-build.py" "$outline" "$@" 2>&1)"; rc=$?; set -e
    echo "$out" >&2
    [ "$rc" = 0 ] || fail "deck-build exited $rc" "$outline" "$rc"
    deck="$(echo "$out" | sed -n 's/^deck-build: \([^ ]*\.html\).*/\1/p' | tail -1)"
    [ -n "$deck" ] || fail "could not read the deck path from deck-build" "$outline" 1
    base="$(ensure_server)"
    ws_set deck "{\"file\":\"$deck\",\"at\":\"$(now)\",\"outline\":\"$outline\",\"pdf\":null}"
    echo "deck=$deck"; echo "url=${base}${deck#"$DK"/}"; log ok "$deck" ;;

  board)
    spec="${1:-}"; [ -n "$spec" ] || fail "needs a spec path" "" 2; shift
    set +e; out="$(python3 "$here/board-build.py" "$spec" "$@" 2>/tmp/dk-board.$$)"; rc=$?; set -e
    cat /tmp/dk-board.$$ >&2; rm -f /tmp/dk-board.$$
    [ "$rc" = 0 ] || fail "board-build exited $rc" "$spec" "$rc"
    board="$(echo "$out" | tail -1)"
    base="$(ensure_server)"
    ws_set board "{\"file\":\"$board\",\"picked\":null,\"at\":\"$(now)\",\"spec\":\"$spec\"}"
    echo "board=$board"; echo "url=${base}${board#"$DK"/}"; log ok "$board" ;;

  scratch)
    mode="${1:-}"; [ -n "$mode" ] || fail "needs --detect|--create SLUG|--cleanup|--verify" "" 2; shift
    case "$mode" in
      --detect) bash "$here/codebase-scaffold.sh" --detect "$@"; log ok ;;
      --create) slug="${1:-}"; [ -n "$slug" ] || fail "--create needs a slug" "" 2; shift
                # the workshop's brief seeds the variant strip unless the caller passed one
                case " $* " in *" --brief "*) ;; *) wb="$(ws_get brief)"; [ -n "$wb" ] && set -- "$@" --brief "$wb" ;; esac
                bash "$here/codebase-scaffold.sh" --create "$slug" "$@" || fail "scaffold failed" "$slug" 1
                ws_set scratch "{\"slug\":\"$slug\",\"at\":\"$(now)\",\"kept\":true}"; log ok "$slug" ;;
      --cleanup) bash "$here/codebase-cleanup.sh"; ws_set scratch.kept false; log ok ;;
      --verify) if bash "$here/codebase-cleanup.sh" --verify; then log ok; else log fail; exit 1; fi ;;
      *) fail "unknown scratch mode $mode" "" 2 ;;
    esac ;;

  bundle)
    input="${1:-}"; [ -n "$input" ] || fail "needs an input" "" 2; shift
    set +e; out="$(python3 "$here/artifact-bundle.py" "$input" --out-dir "$DK/artifacts" --json "$@" 2>/tmp/dk-bundle.$$)"; rc=$?; set -e
    cat /tmp/dk-bundle.$$ >&2; rm -f /tmp/dk-bundle.$$
    [ "$rc" = 0 ] || fail "artifact-bundle exited $rc" "$input" "$rc"
    read -r art slug ver <<<"$(printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["out"], d["slug"], d["version"])')"
    printf '%s\n' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin)
for n in sorted(set(d.get("network",[]))): print("network:", n)
for u in sorted(set(d.get("unresolved",[]))): print("unresolved-link:", u)
for w in d.get("warnings",[]): print("WARN:", w)
if d.get("zip"): print("zip:", d["zip"])'
    base="$(ensure_server)"
    ws_set "artifacts+" "{\"slug\":\"$slug\",\"version\":$ver,\"at\":\"$(now)\",\"file\":\"$art\"}"
    echo "artifact=$art v$ver"; echo "url=${base}artifacts/$(basename "$art")"; log ok "$art" ;;

  share)
    page="${1:-}"; [ -n "$page" ] || fail "needs a page" "" 2; shift
    mode="${1:-}"; [ -n "$mode" ] || fail "needs --lan | --pages [--push] | --zip" "" 2; shift
    case "$mode" in
      --lan) base="$(ensure_server --lan)"; echo "url=${base}${page#"$DK"/}"; log ok "$page" ;;
      --pages) bash "$here/artifact-publish.sh" "$page" "$@" || fail "publish failed" "$page" 1; log ok "$page" ;;
      --zip) z="${page%.html}.zip"; python3 -c 'import sys,zipfile,os
p,z=sys.argv[1:3]
with zipfile.ZipFile(z,"w",zipfile.ZIP_DEFLATED) as zf: zf.write(p, os.path.basename(p))
print("zip:", z)' "$page" "$z"; log ok "$z" ;;
      *) fail "unknown share mode $mode" "" 2 ;;
    esac ;;

  export)
    file="${1:-}"; [ -n "$file" ] || fail "needs a file" "" 2; shift
    kind="${1:-}"; [ -n "$kind" ] || fail "needs --pdf|--png|--pptx" "" 2; shift
    case "$file" in
      */boards/*) bash "$here/board-export.sh" "$file" "$kind" "$@" || fail "board-export failed" "$file" "$?" ;;
      *) bash "$here/deck-export.sh" "$file" "$kind" "$@" || fail "deck-export failed" "$file" "$?"
         [ "$kind" = "--pdf" ] && ws_set deck.pdf "\"${file%.html}.pdf\"" ;;
    esac
    log ok "$file" ;;

  decision)
    python3 - "$DEC" "$WS" "$@" <<'PY'
import json, os, sys, time
dec, ws_path, *args = sys.argv[1:]
if args[:1] == ["--record"]:
    line = args[1] if len(args) > 1 else ""
    if not line:
        print("dk decision --record needs a line", file=sys.stderr); sys.exit(2)
    os.makedirs("design-system", exist_ok=True)
    p = os.path.join("design-system", "DECISIONS.md")
    new = not os.path.exists(p)
    with open(p, "a", encoding="utf-8") as fh:
        if new:
            fh.write("# Design decisions\n\nOne line per pick a command acted on: date, board, artboard, knobs, components that rendered it, gap rows. Appended by `dk decision --record`.\n\n")
        fh.write("- " + time.strftime("%Y-%m-%d") + " — " + line.strip() + "\n")
    print("recorded: design-system/DECISIONS.md"); sys.exit(0)
rows = []
try:
    for ln in open(dec, encoding="utf-8"):
        try: rows.append(json.loads(ln))
        except ValueError: pass
except OSError:
    pass
board = None; consume = "--consume" in args
if "--board" in args:
    board = os.path.basename(args[args.index("--board") + 1])
cands = [r for r in rows if not r.get("consumed") and (board is None or r.get("board") == board)]
if not cands:
    print("no unread decision" + (f" for {board}" if board else "") + " — pick on the board, or paste its copied prompt"); sys.exit(3)
row = cands[-1]
print(row.get("prompt") or "(empty decision)")
if consume:
    # every unread row of this board is one decision that arrived in pieces (pick, then
    # each debounced knob/text post); reading the latest reads them all
    for r in cands:
        if r.get("board") == row.get("board"):
            r["consumed"] = True
    with open(dec, "w", encoding="utf-8") as fh:
        for r in rows: fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    try: ws = json.load(open(ws_path, encoding="utf-8"))
    except Exception: ws = {}
    b = ws.setdefault("board", {})
    b["picked"] = row.get("picked"); b["file"] = b.get("file") or row.get("board"); b["decided_at"] = row.get("ts")
    json.dump(ws, open(ws_path, "w", encoding="utf-8"), indent=1)
PY
    rc=$?; [ "$rc" = 0 ] && log ok || log skip; exit "$rc" ;;

  status)
    python3 - "$DK" "$here/serve.py" <<'PY'
import importlib.util, sys
dk, serve = sys.argv[1:3]
spec = importlib.util.spec_from_file_location("dkserve", serve); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
import os
steps = m.flow_steps(os.path.abspath(dk))
print(" → ".join(f"{l} [{d}]" for l, d, s in steps))
u = open(os.path.join(dk, ".preview.url")).read().strip() if os.path.exists(os.path.join(dk, ".preview.url")) else ""
print("server: " + (u or "not running"))
PY
    log ok ;;

  -h|--help|"") sed -n '2,32p' "$0"; exit 0 ;;
  *) echo "dk: unknown verb $verb" >&2; sed -n '7,17p' "$0" >&2; exit 2 ;;
esac
