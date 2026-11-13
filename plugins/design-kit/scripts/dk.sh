#!/usr/bin/env bash
# dk.sh — the ONE entry point for every design-kit surface, so a user grants one
# permission rule (`Bash(bash */design-kit/scripts/dk.sh*)`) instead of one per
# script, and so the five commands share one state file instead of re-typing the
# brief, device, theme and pick.
#
#   dk serve [--lan|--stop]                 start / expose / stop the preview server, print its URL
#   dk system [target] [--out DIR]          extract → copy kit into previews → serve → URL
#   dk check                                one line: design-system current, moved, or missing
#   dk check <page> [--widths 375,768,1280] the page in a headless browser: findings, one escaped JSON line each
#   dk drift [PATHS|--staged|--diff REF] [--ci] | --print-hook   literal colours + named
#                                           Tailwind palette utilities reaching no token
#   dk snapshot [--routes R] [--device desktop|mobile|both] [--base-url U] [--out DIR]
#               [--storage-state FILE]      one PNG per route per device off the running app;
#                                           FILE replays a signed-in session (snapshot.sh)
#   dk review --base <dir|git-ref>          before / after / pixel-diff page for the
#                                           last two shot sets, served, with a table
#   dk slides <outline.md> [--theme FILE]   build a deck, record it, print its URL
#   dk board <spec.json|.md> [--device D]   build a board, record it, print its URL
#   dk scratch --detect|--create SLUG|--cleanup|--verify [--stack S]
#   dk bundle <input> [--name SLUG] [--zip] bundle an artifact, record it, print its URL
#   dk share <page> --lan | --pages [--push] | --zip
#   dk export <file> --pdf|--png|--pptx     deck (pdf/pptx) or board (png/pdf) export
#   dk decision [--latest|--board FILE] [--consume] | --record "LINE"
#   dk notes [--all] | --wait [--timeout S] | --reply ID --status addressed|dismissed [--text "LINE"] | --shot ID
#                                           notes left on a preview page, one JSON line each (data)
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
# WHERE .design-kit/ LIVES. At the project root (cc_state_root below: the git toplevel,
# else CLAUDE_PROJECT_DIR when the shell sits under it), not under the shell's cwd. It
# was `./.design-kit` until 0.5.1, so a verb run after the model had cd'd into src/
# built a second .design-kit/ there — its own board, decisions and usage log, invisible
# to the unread-pick hook and to a `dk decision` run from the root (the cwd drift is
# finding 2 of the marketplace's rationale/2026-09-25-session-plugin-usage-review.md).
# At the root $DK stays the relative `.design-kit`, so every path printed there is what
# it always was; from a subdirectory it is absolute. An explicit DESIGN_KIT_DIR is used
# exactly as given. Either way it is EXPORTED, so the scripts dk runs (deck-build,
# board-build, artifact-bundle, deck-export, snapshot) write where dk reads; run on their
# own they fall back to .design-kit at the git toplevel. design-system/ is NOT anchored:
# `dk check`, `--record` and the extractor's default --out still read the shell's cwd.
#
# WHAT IT DOES NOT DO. It asks no questions — every consent (write into the tree,
# share, install pptxgenjs, push) stays in the command that calls it. It never
# assembles a URL from a literal port: the URL is what preview.sh wrote to
# .design-kit/.preview.url. Standing: scripts/__tests__/dk.test.sh drives every
# verb against a temp project; the wrapped scripts keep their own harnesses.
# Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/dk.sh
set -euo pipefail

# Shared block templates/blocks/state-root.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/state-root.md
# cc_state_root <cwd> prints the root that holds hook state: the git toplevel above <cwd>, else
# CLAUDE_PROJECT_DIR when <cwd> is under it, else <cwd>. A <cwd> that no longer exists: no output, status 1.
# --show-cdup, not --show-toplevel: git resolves a symlinked /tmp there, breaking the caller's path-prefix compares.
cc_state_root() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  local up pd="${CLAUDE_PROJECT_DIR:-}"; pd="${pd%/}"
  if up=$(git -C "$1" rev-parse --show-cdup 2>/dev/null); then
    [ -n "$up" ] || { printf '%s\n' "$1"; return 0; }
    (CDPATH= cd -- "$1/$up" 2>/dev/null && pwd) && return 0
  fi
  if [ -n "$pd" ] && [ -d "$pd" ]; then
    case "$1/" in "$pd"/*) printf '%s\n' "$pd"; return 0 ;; esac
  fi
  printf '%s\n' "$1"
}

here="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cc_state_root "$PWD")" || ROOT="$PWD"
if [ -n "${DESIGN_KIT_DIR:-}" ]; then DK="$DESIGN_KIT_DIR"
elif [ "$ROOT" = "$PWD" ]; then DK=".design-kit"
else DK="$ROOT/.design-kit"; fi
export DESIGN_KIT_DIR="$DK"
WS="$DK/workshop.json"; USAGE="$DK/usage.jsonl"; DEC="$DK/decisions.jsonl"
verb="${1:-}"; [ $# -gt 0 ] && shift
# help exits before ensure_ignored, so `dk --help` writes nothing
case "$verb" in -h|--help|"") sed -n '2,54p' "$0"; exit 0 ;; esac

# drift --print-hook writes nothing either: it prints the PostToolUse snippet for the user to paste, and installs nothing.
if [ "$verb" = drift ] && [ "${1:-}" = "--print-hook" ]; then
  python3 - "$here/handoff-drift.py" <<'PY'
import json, shlex, sys
drift = shlex.quote(sys.argv[1])
cmd = ("f=$(python3 -c 'import json,sys; print((json.load(sys.stdin).get(\"tool_input\") or {}).get(\"file_path\") or \"\")' 2>/dev/null); "
       '[ -n "$f" ] || exit 0; '
       f'out=$(python3 {drift} --scan --ci --repo "${{CLAUDE_PROJECT_DIR:-.}}" "$f" 2>/dev/null); '
       '[ $? -eq 1 ] || exit 0; printf \'%s\\n\' "$out" | head -n 40 >&2; exit 2')
hook = {"hooks": {"PostToolUse": [{"matcher": "Edit|Write|MultiEdit",
                                    "hooks": [{"type": "command", "command": cmd, "timeout": 15}]}]}}
print(json.dumps(hook, indent=2))
print("design-kit: nothing was installed. Merge the JSON above into .claude/settings.json (this project) or ~/.claude/settings.json, "
      "under \"hooks\". After an edit it hands Claude the drift table (exit 2) when the edited file has a hit; a clean file, "
      "a file it does not scan and a project with no tokens stay silent. The path names this plugin version: re-run after an update.",
      file=sys.stderr)
PY
  exit 0
fi

# ensure_ignored — once per git repo, a managed .gitignore block for .design-kit/ and __design-kit__/ (never design-system/, the tracked record); DESIGN_KIT_IGNORE=off skips it.
ensure_ignored() {
  [ "${DESIGN_KIT_IGNORE:-on}" = "off" ] && return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local root rel; root="$(git rev-parse --show-toplevel)"
  # root-relative: $DK is absolute from a subdirectory, and .gitignore takes no absolute path
  rel="${DK#"$ROOT"/}"
  if git -C "$root" check-ignore -q "$rel/x" 2>/dev/null && git -C "$root" check-ignore -q "__design-kit__/x" 2>/dev/null; then return 0; fi
  # tracked on purpose (a repo that commits its evidence): say nothing, touch nothing
  [ -n "$(git -C "$root" ls-files -- "$rel" "__design-kit__" 2>/dev/null)" ] && return 0
  python3 - "$root/.gitignore" "$rel/" "__design-kit__/" <<'PY'
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
  echo "design-kit: added $rel/ and __design-kit__/ to .gitignore (managed block; DESIGN_KIT_IGNORE=off to skip)"
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
# keyed <url>: while the server is LAN-bound every printed URL carries the network address, so it needs serve.py's key
keyed() { if [ "$(cat "$DK/.preview.bind" 2>/dev/null)" = 0.0.0.0 ] && [ -s "$DK/.preview.key" ]; then printf '%s?key=%s' "$1" "$(cat "$DK/.preview.key")"; else printf '%s' "$1"; fi; }
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
    base="$(ensure_server $lan)"; echo "url=$(keyed "$base")"; log ok ;;

  system)
    target="."; out="design-system"; args=(); rendered=""
    while [ $# -gt 0 ]; do case "$1" in --out) out="$2"; shift ;; --source|--project-name) [ "$1 ${2:-}" = "--source rendered" ] && rendered=1; args+=("$1" "$2"); shift ;; *) target="$1" ;; esac; shift; done
    # A rendered dry-run would load the page twice; its exit code (3 no Playwright, 4 no page) passes through.
    [ -n "$rendered" ] || python3 "$here/system-extract.py" "$target" --out "$out" --dry-run ${args[@]+"${args[@]}"} || fail "dry-run failed" "" 1
    python3 "$here/system-extract.py" "$target" --out "$out" ${args[@]+"${args[@]}"} || fail "extraction failed" "" "$?"
    mkdir -p "$DK/previews"; cp "$out/kit.html" "$DK/previews/kit.html"
    base="$(ensure_server)"
    ws_set system "{\"stamp\":\"$(tokens_sha)\",\"at\":\"$(now)\",\"out\":\"$out\"}"
    echo "url=$(keyed "${base}previews/kit.html")"; log ok "$out/tokens.json" ;;

  check)
    if [ $# -gt 0 ]; then
      # render-check.py owns its exits: 0 no finding, 1 findings, 2 bad arguments, 4 not checked (no browser, no server, the browser failed).
      set +e; python3 "$here/render-check.py" --docroot "$DK" "$@"; rc=$?; set -e
      case "$rc" in 0|1) log ok "$1" ;; 4) log skip "$1" ;; *) log fail "$1" ;; esac
      exit "$rc"
    fi
    if [ ! -f design-system/tokens.json ]; then echo "design-system: none — run /design-kit:system first"; log skip; exit 0; fi
    set +e; out="$(python3 "$here/system-extract.py" . --dry-run --check 2>&1)"; rc=$?; set -e
    if echo "$out" | grep -q "unrecognized arguments: --check"; then echo "design-system: check unavailable in this build"; log skip; exit 0; fi
    if [ "$rc" = 0 ]; then echo "design-system: current"; log ok; exit 0; fi
    echo "$out" | grep -E '^check:' || echo "$out" | tail -3
    log ok; exit 0 ;;

  drift)
    # --staged and --diff resolve the file list here, in git; --diff compares the WORKING TREE to REF, not HEAD. What it catches and misses: handoff-drift.py's header.
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
    # An empty selector scans nothing, never the whole tree.
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

  snapshot|review)
    # snapshot.sh owns the exit codes (0 rendered, 1 bad arguments, 2 browser or server unreachable); they pass through unchanged.
    set +e; bash "$here/snapshot.sh" "$verb" "$@"; rc=$?; set -e
    case "$rc" in 0) log ok ;; 2) log skip ;; *) log fail ;; esac
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
    echo "deck=$deck"; echo "url=$(keyed "${base}${deck#"$DK"/}")"; log ok "$deck" ;;

  board)
    spec="${1:-}"; [ -n "$spec" ] || fail "needs a spec path" "" 2; shift
    set +e; out="$(python3 "$here/board-build.py" "$spec" "$@" 2>/tmp/dk-board.$$)"; rc=$?; set -e
    cat /tmp/dk-board.$$ >&2; rm -f /tmp/dk-board.$$
    [ "$rc" = 0 ] || fail "board-build exited $rc" "$spec" "$rc"
    board="$(echo "$out" | tail -1)"
    base="$(ensure_server)"
    ws_set board "{\"file\":\"$board\",\"picked\":null,\"at\":\"$(now)\",\"spec\":\"$spec\"}"
    echo "board=$board"; echo "url=$(keyed "${base}${board#"$DK"/}")"; log ok "$board" ;;

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
    echo "artifact=$art v$ver"; echo "url=$(keyed "${base}artifacts/$(basename "$art")")"; log ok "$art" ;;

  share)
    page="${1:-}"; [ -n "$page" ] || fail "needs a page" "" 2; shift
    mode="${1:-}"; [ -n "$mode" ] || fail "needs --lan | --pages [--push] | --zip" "" 2; shift
    case "$mode" in
      --lan) base="$(ensure_server --lan)"; echo "url=$(keyed "${base}${page#"$DK"/}")"; log ok "$page" ;;
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
import json, os, re, sys, time
dec, ws_path, *args = sys.argv[1:]
if args[:1] == ["--record"]:
    line = args[1] if len(args) > 1 else ""
    # A line written in the file's own `date — …` shape came out dated twice in a real
    # session, so a leading `YYYY-MM-DD —` (en dash or hyphen too) is dropped and today's
    # date stands. Residual: a date with no dash after it is kept as text.
    line = re.sub(r"^\s*\d{4}-\d{2}-\d{2}\s+[—–-]\s+", "", line)
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

  notes)
    # Rows are page-originated: printed as escaped JSON, never as prose. Exit 3: nothing to print; 2: bad arguments.
    notes_py() { python3 - "$DK" "$here/serve.py" "$@" <<'PY'
import calendar, contextlib, hashlib, importlib.util, json, os, re, sys, tempfile, time
from urllib.parse import quote
dk, serve, *args = sys.argv[1:]
spec = importlib.util.spec_from_file_location("dkserve", serve); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
path = os.path.join(dk, m.NOTES)
decisions = os.path.join(dk, "decisions.jsonl")
announced = os.path.join(dk, ".notes-pick")  # the last pick a --wait printed, so the next one waits past it
LEASE = 15 * 60  # a handed-out note still open comes back after this many seconds
def die(msg, rc):
    print("dk notes: " + msg, file=sys.stderr); sys.exit(rc)
# One parse: --shot ID stands alone, each option once, one verb at a time.
o, i = {}, 0
while i < len(args):
    a = args[i]
    if a in o: die(a + " given twice", 2)
    if a in ("--all", "--wait"):
        o[a] = True
    elif a in ("--timeout", "--reply", "--status", "--text", "--shot"):
        if i + 1 >= len(args): die(a + " needs a value", 2)
        o[a] = args[i + 1]; i += 1
    else:
        die("unknown argument " + a, 2)
    i += 1
verbs = [v for v in ("--all", "--wait", "--reply", "--shot") if v in o]
if len(verbs) > 1: die(" and ".join(verbs) + " do not go together", 2)
if "--shot" in o and len(args) != 2: die("--shot ID takes no other argument", 2)
if "--timeout" in o and "--wait" not in o: die("--timeout goes with --wait", 2)
if ("--status" in o or "--text" in o) and "--reply" not in o: die("--status and --text go with --reply", 2)
def emit(rows):
    """Print and flush before anything is marked: a reader that cannot write, or is killed here, hands nothing out."""
    try:
        for r in rows: print(m.show(r))
        sys.stdout.flush()
    except OSError as exc:
        print("dk notes: could not print (%s); nothing marked" % exc.strerror, file=sys.stderr); os._exit(1)
def load():
    """[[row or None, raw bytes]] per non-blank line, never through a symlink; a line that is not a JSON object is kept as bytes, so a rewrite never drops it."""
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    except FileNotFoundError:
        return []
    except OSError as exc:
        die("cannot read %s: %s" % (path, exc.strerror), 1)
    with os.fdopen(fd, "rb") as fh:
        data = fh.read()
    entries = []
    for raw in data.split(b"\n"):
        if not raw.strip(): continue
        try: row = json.loads(raw.decode("utf-8", "replace"))
        except (ValueError, RecursionError): row = None
        entries.append([row if isinstance(row, dict) else None, raw])
    return entries
def save(entries):
    fd, tmp = tempfile.mkstemp(dir=dk, prefix=".notes-", suffix=".tmp")
    try:
        with os.fdopen(fd, "wb") as fh:
            for _row, raw in entries: fh.write(raw + b"\n")
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp): os.unlink(tmp)
        raise
def update(entry, **fields):
    entry[0].update(fields); entry[1] = json.dumps(entry[0], ensure_ascii=False).encode("utf-8")
def handed_at(r):
    """Epoch seconds the note was handed out; 0 for never; None for any other value, such as true (handed out, no lease)."""
    v = r.get("handed_out")
    if isinstance(v, str):
        try: return calendar.timegm(time.strptime(v, "%Y-%m-%dT%H:%M:%SZ"))
        except ValueError: return None
    return None if v else 0
def unread(r):
    return r.get("status") == "open" and handed_at(r) is not None and time.time() - handed_at(r) >= LEASE
def fresh(entries): return [e for e in entries if e[0] and unread(e[0])]
def lease_ends(entries):
    return min((handed_at(e[0]) + LEASE for e in entries if e[0] and e[0].get("status") == "open" and handed_at(e[0])), default=float("inf"))
def new_pick():
    """The latest unconsumed pick when no --wait has printed it yet, as (row to print, its fingerprint)."""
    picks = [r for r in m._decisions(dk) if not r.get("consumed")]
    if not picks: return None
    fp = hashlib.sha256(json.dumps(picks[-1], sort_keys=True).encode("utf-8", "replace")).hexdigest()[:16]
    try:
        with open(announced, encoding="ascii") as fh:
            if fh.read().strip() == fp: return None
    except (OSError, ValueError):
        pass
    r = picks[-1]
    return {"kind": "pick", "ts": r.get("ts"), "board": r.get("board"), "picked": r.get("picked"), "prompt": r.get("prompt") or ""}, fp
def hand_out(with_pick):
    """Under the lock: print the unread notes (and a pick not yet printed), then mark the notes and remember the pick."""
    with m.notes_lock(dk):
        entries = load(); new = fresh(entries); pick = new_pick() if with_pick else None
        if not new and not pick: return False
        emit([e[0] for e in new] + ([pick[0]] if pick else []))
        if new:
            stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            for e in new: update(e, handed_out=stamp)
            save(entries)
        if pick:
            fd = os.open(announced, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | getattr(os, "O_NOFOLLOW", 0), 0o600)
            with os.fdopen(fd, "w", encoding="ascii") as fh: fh.write(pick[1] + "\n")
    return True
def signature(p):
    try: st = os.stat(p)
    except OSError: return None
    return (st.st_ino, st.st_size, st.st_mtime_ns)
if "--shot" in o:
    nid = o["--shot"]
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,32}", nid): die("not a note id: " + nid, 2)
    r = next((e[0] for e in load() if e[0] and e[0].get("id") == nid), None) or die("no note " + nid, 3)
    sel = r["anchor"].get("selector") if isinstance(r.get("anchor"), dict) else ""
    if not isinstance(sel, str) or not sel: die("note %s is on the whole page, no element to shoot" % nid, 2)
    vp = (r.get("context") or {}).get("viewport") or {}
    size = [min(max(v if isinstance(v, int) and v > 0 else d, lo), hi) for v, d, lo, hi in ((vp.get("w"), 1280, 320, 3840), (vp.get("h"), 800, 240, 2160))]
    print(nid)
    print("/" + quote(str(r.get("page") or ""), safe="/") + "?_outline=" + quote(sel, safe=""))
    print("%d,%d" % tuple(size)); sys.exit(0)
if "--reply" in o:
    status = o.get("--status")
    if status not in ("addressed", "dismissed"): die("--status must be addressed or dismissed", 2)
    with m.notes_lock(dk):
        entries = load()
        e = next((e for e in entries if e[0] and e[0].get("id") == o["--reply"]), None) or die("no note " + o["--reply"], 3)
        update(e, status=status, reply=" ".join(o.get("--text", "").split())[:300])
        save(entries)
    emit([e[0]]); sys.exit(0)
if "--wait" in o:
    try: end = time.monotonic() + float(o.get("--timeout", "600"))
    except ValueError: die("--timeout needs seconds", 2)
    seen, due = "unread", 0.0
    while True:
        # Parse only when either file's inode, size or mtime moved, or a lease ran out.
        sig = (signature(path), signature(decisions))
        if sig != seen or time.time() >= due:
            seen, entries = sig, load()
            due = lease_ends(entries)
            if (fresh(entries) or new_pick()) and hand_out(True): sys.exit(0)
        if time.monotonic() >= end: sys.exit(3)
        time.sleep(0.5)
if "--all" in o:
    rows = [e[0] for e in load() if e[0]]
    if not rows: die("no note", 3)
    emit(rows); sys.exit(0)
if not fresh(load()) or not hand_out(False): die("no unread note", 3)
PY
    }
    # --shot ID stands alone (notes_py refuses it anywhere else), so only that form is captured here
    if [ "${1:-}" != "--shot" ]; then
      set +e; notes_py "$@"; rc=$?; set -e
      case "$rc" in 0) log ok ;; 3) log skip ;; *) log fail ;; esac
      exit "$rc"
    fi
    set +e; spec="$(notes_py "$@")"; rc=$?; set -e
    [ "$rc" = 0 ] || { log fail; exit "$rc"; }
    # every path below is built from the id notes_py validated, never from the raw argument
    nid="$(printf '%s\n' "$spec" | sed -n 1p)"
    browser="$(bash "$here/board-export.sh" --which 2>/dev/null)" \
      || fail "no Chromium-family browser found (Chrome, Chromium, Edge, Playwright's, or DESIGN_KIT_BROWSER); no screenshot taken" "$nid" 4
    base="$(ensure_server)" || fail "the preview server did not start; no screenshot taken" "$nid" 4
    port="${base%/}"; port="${port##*:}"
    # 127.0.0.1, not the URL file's host: a LAN server's printed address is not loopback, and ?_outline= answers loopback only
    shots="$DK/.notes"; mkdir -p "$shots"; chmod 700 "$shots"; out="$shots/$nid.png"; rm -f "$out"
    profile="$(mktemp -d)"
    # Chrome's sandbox stays on: off only as root, where Chrome refuses to start with it, or on DESIGN_KIT_BROWSER_NO_SANDBOX=1.
    sandbox=""; if [ "$(id -u)" = 0 ] || [ "${DESIGN_KIT_BROWSER_NO_SANDBOX:-}" = 1 ]; then sandbox="--no-sandbox"; fi
    limit=""; if command -v timeout >/dev/null 2>&1; then limit="timeout 30"; fi
    set +e
    $limit "$browser" --headless=new --disable-gpu $sandbox --hide-scrollbars --force-device-scale-factor=1 \
      --run-all-compositor-stages-before-draw --virtual-time-budget=3000 --no-first-run --no-default-browser-check \
      --user-data-dir="$profile" --window-size="$(printf '%s\n' "$spec" | sed -n 3p)" \
      --screenshot="$out" "http://127.0.0.1:$port$(printf '%s\n' "$spec" | sed -n 2p)" >/dev/null 2>&1
    brc=$?; set -e
    rm -rf "$profile"
    if [ "$brc" != 0 ]; then
      rm -f "$out"
      if [ "$brc" = 124 ] && [ -n "$limit" ]; then why="ran past 30 s"; else why="exited $brc"; fi
      fail "the browser $why for note $nid; no screenshot taken" "$nid" 4
    fi
    [ -s "$out" ] || fail "the browser wrote no PNG for note $nid" "$nid" 4
    echo "$out"; log ok "$out" ;;

  status)
    python3 - "$DK" "$here/serve.py" <<'PY'
import importlib.util, sys
dk, serve = sys.argv[1:3]
spec = importlib.util.spec_from_file_location("dkserve", serve); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
import os
steps = m.flow_steps(os.path.abspath(dk))
print(" → ".join(f"{l} [{d}]" for l, d, s in steps))
def alive():
    try:
        pid = int(open(os.path.join(dk, ".preview.pid")).read().strip())
        if pid <= 0:
            return False
        os.kill(pid, 0)
        return True
    except (OSError, ValueError):
        return False
u = open(os.path.join(dk, ".preview.url")).read().strip() if alive() and os.path.exists(os.path.join(dk, ".preview.url")) else ""
print("server: " + (u or "not running"))
PY
    log ok ;;

  *) echo "dk: unknown verb $verb" >&2; sed -n '7,27p' "$0" >&2; exit 2 ;;
esac
