#!/bin/bash
# unicode-scan.sh (PostToolUse on file writes and reads, Bash included; payload on stdin) — warns once per file per session, never blocks,
#   naming line and codepoint, when a file the call wrote or read holds a zero-width, bidi, soft-hyphen, mid-file BOM or Unicode tag character.
# Off: CC_UNICODE_SCAN=off or CC_REMIND=off. Fails open on every error path; its one-shot markers live in $TMPDIR, none under the project.
# CC_UNICODE_SCAN / CC_REMIND unset: the /config options cc_unicode_scan / cc_remind decide.
# Misses: homoglyphs; intent (it reports presence only); a file over 2 MB or not valid UTF-8; hits past the sixth in a file; a file the session
#   never touched; a NotebookEdit (notebook_path is not read); an MCP apply_patch (no single path); on Bash, targets past the eighth, outside the
#   project root or not an existing regular file, a relative target after an in-command cd, and writes cc_bash_write_targets does not see.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/hooks/unicode-scan.sh

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

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

# Shared block templates/blocks/bash-write-targets.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-targets.md
# cc_bash_write_targets <command> prints each path the command writes through `>`/`>>`, `[sudo] tee` or `sed -i`/`perl -i`,
# one per line as spelled; heredoc bodies and quoted text never match. A path guard keeps existing files under its root.
# BSD sed's -I always takes the next word as its backup suffix, so that word is never a target; after a bare sed -i,
# a `''` or `.`-led word is read as one too, unless it would be the only file.
# Misses: interpreter writes, cp/mv/install, a path in a variable, a glob, a `\` line continuation, a digit- or &-led
# redirect and `>&`, sed/perl/tee behind another command word (gsed, /usr/bin/sed, env, xargs, sudo -u), a `-`-led
# operand with no `/` or `.`, operands cut short by a `&` inside `$(( ))`/`${ }`, every line after a `<<\EOF` opener.
cc_bash_write_targets() {
  printf '%s\n' "$1" | awk '
    function emit(p) {
      gsub(/^["\047]|["\047]$/, "", p)
      if (p == "" || p ~ /^\/dev\// || p ~ /[$`*?]/ || p ~ /^[&0-9-]/ && p !~ /[\/.]/) return
      print p
    }
    function mask(s,   i, c, q, out, esc) {
      q = ""; out = ""; esc = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (esc) { out = out "_"; esc = 0; continue }
        if (q == "") {
          if (c == "\\") { esc = 1; out = out "_"; continue }
          if (c == "\047" || c == "\"") q = c
          out = out c
        } else if (c == q) { q = ""; out = out c }
        else { if (q == "\"" && c == "\\") esc = 1; out = out "_" }
      }
      return out
    }
    function segment(ms, os,   rest, off, tok, w, k, j, st, en, word, n, ws, we, x, c, a, inp, scr, eo, sfx, nf, f) {
      rest = ms; off = 0
      while (match(rest, /(^|[^0-9&=<>-])>>?[ \t]*("[^"]*"|\047[^\047]*\047|[^ \t&|;<>()"\047]+)/)) {
        tok = substr(os, off + RSTART, RLENGTH)
        off += RSTART + RLENGTH - 1; rest = substr(ms, off + 1)
        sub(/^[^>]*>>?[ \t]*/, "", tok)
        emit(tok)
      }
      n = 0; j = 1
      while (j <= length(ms)) {
        while (j <= length(ms) && substr(ms, j, 1) ~ /[ \t]/) j++
        if (j > length(ms)) break
        st = j; while (j <= length(ms) && substr(ms, j, 1) !~ /[ \t]/) j++
        n++; ws[n] = st; we[n] = j - 1
      }
      if (n == 0) return
      k = 1; word = substr(os, ws[1], we[1] - ws[1] + 1)
      if (word == "sudo" && n > 1) { k = 2; word = substr(os, ws[2], we[2] - ws[2] + 1) }
      if (word == "tee") {
        for (k = k + 1; k <= n; k++) {
          w = substr(os, ws[k], we[k] - ws[k] + 1)
          if (w == "<" || w == "<<<") { k++; continue }
          if (w !~ /^-/ && w !~ /^[<>0-9]/) emit(w)
        }
      } else if (word == "sed" || word == "perl") {
        inp = 0; scr = 0; eo = 0; sfx = ""; nf = 0
        for (k = k + 1; k <= n; k++) {
          w = substr(os, ws[k], we[k] - ws[k] + 1); x = substr(ms, ws[k], we[k] - ws[k] + 1)
          if (x ~ /[<>]/) {
            a = substr(w, 1, match(x, /[<>]/) - 1)
            if (a !~ /^[0-9&]*$/) f[++nf] = a
            if (x ~ /[<>][&|]?$/) k++
            continue
          }
          if (eo || x !~ /^-./) { f[++nf] = w; if (word == "perl") eo = 1; continue }
          if (x == "--") { eo = 1; continue }
          if (x ~ /^--/) {
            if (word == "sed" && x ~ /^--in-place(=|$)/) inp = 1
            if (word == "sed" && x ~ /^--(expression|file)(=|$)/) { scr = 1; if (x !~ /=/) k++ }
            continue
          }
          for (j = 2; j <= length(x); j++) {
            c = substr(x, j, 1)
            if (c == "i" || word == "sed" && c == "I") {
              inp = 1
              if (word == "sed" && j == length(x) && k < n) {
                a = substr(os, ws[k + 1], we[k + 1] - ws[k + 1] + 1); gsub(/^["\047]|["\047]$/, "", a)
                if (c == "I") k++
                else if (a == "" || a ~ /^\.[^\/<>]*$/) { k++; sfx = a }
              }
              break
            }
            if (c == "e" || c == (word == "sed" ? "f" : "E")) { scr = 1; if (j == length(x)) k++; break }
            if (c == (word == "sed" ? "l" : "I")) { if (j == length(x)) k++; break }
            if (word == "perl" && c ~ /[MmFxdDVC]/) break
            if (word == "perl" && c ~ /[l0]/) while (substr(x, j + 1, 1) ~ /[0-7]/) j++
          }
        }
        if (!inp) return
        for (j = scr ? 1 : 2; j <= nf; j++) if (f[j] !~ /^-/ || eo) { emit(f[j]); sfx = "" }
        if (sfx != "") emit(sfx)
      }
    }
    skip { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t); if (t == term) skip = 0; next }
    {
      line = $0; m = mask(line)
      if (match(m, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
        if (substr(m, RSTART, 1) != "<") { RSTART++; RLENGTH-- }
        term = substr(line, RSTART, RLENGTH + 1)
        sub(/^<<-?[ \t]*["\047]?/, "", term); sub(/[^A-Za-z0-9_].*$/, "", term)
        skip = 1
      }
      st = 1
      for (i = 1; i <= length(m) + 1; i++) {
        c = substr(m, i, 1); c2 = substr(m, i, 2)
        if (i > length(m) || c == ";" || c == "|" || c == "&" && c2 != "&>" && substr(m, i - 1, 1) !~ /[<>]/) {
          if (i > st) segment(substr(m, st, i - st), substr(line, st, i - st))
          if (c2 == "&&" || c2 == "||" || c2 == "|&") i++
          st = i + 1
        }
      }
    }' | awk '!seen[$0]++'
}

MARKER_TTL_MIN=1440
MAX_BASH_TARGETS=8
{
  [ "$(cc_option CC_UNICODE_SCAN on)" = "off" ] && exit 0
  [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  command -v python3 >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit|Read|Bash) ;;
    *apply_patch|*create_new_file|*read_file) ;;
    *) exit 0 ;;
  esac

  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)

  # report_file <path> — prints the file's warning, or nothing when it is clean, too big, unreadable or already reported.
  report_file() {
    local file=$1 bytes key mark report kind body base
    [ -f "$file" ] || return 0
    # tr -d: BSD wc pads its count, which the numeric test below would reject, disabling the hook.
    bytes=$(wc -c < "$file" 2>/dev/null | tr -d '[:space:]' || echo 0)
    case "$bytes" in ''|*[!0-9]*) return 0 ;; esac
    [ "$bytes" -gt 2000000 ] && return 0

    mark=""
    if [ -n "$sid" ]; then
      key=$(printf '%s|%s' "$sid" "$file" | cksum 2>/dev/null | cut -d' ' -f1)
      mark="${TMPDIR:-/tmp}/cc-unicode-$key"
      [ -d "$mark" ] && return 0
      find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-unicode-*' -type d -mmin +"$MARKER_TTL_MIN" -exec rmdir {} + 2>/dev/null
    fi

    report=$(python3 - "$file" <<'PY' 2>/dev/null
import sys, unicodedata
NAMED = {
    0x200B: "ZERO WIDTH SPACE", 0x200C: "ZERO WIDTH NON-JOINER",
    0x200D: "ZERO WIDTH JOINER", 0x2060: "WORD JOINER",
    0xFEFF: "ZERO WIDTH NO-BREAK SPACE (BOM)", 0x00AD: "SOFT HYPHEN",
    0x202A: "LEFT-TO-RIGHT EMBEDDING", 0x202B: "RIGHT-TO-LEFT EMBEDDING",
    0x202C: "POP DIRECTIONAL FORMATTING", 0x202D: "LEFT-TO-RIGHT OVERRIDE",
    0x202E: "RIGHT-TO-LEFT OVERRIDE", 0x2066: "LEFT-TO-RIGHT ISOLATE",
    0x2067: "RIGHT-TO-LEFT ISOLATE", 0x2068: "FIRST STRONG ISOLATE",
    0x2069: "POP DIRECTIONAL ISOLATE",
}
BIDI = set(range(0x202A, 0x202F)) | set(range(0x2066, 0x206A))
try:
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        lines = fh.readlines()
except Exception:
    sys.exit(0)

hits = []
for lineno, line in enumerate(lines, 1):
    for col, ch in enumerate(line, 1):
        cp = ord(ch)
        if cp == 0xFEFF and lineno == 1 and col == 1:
            continue                      # a leading BOM is a file encoding, not a hider
        if cp in NAMED or 0xE0000 <= cp <= 0xE007F:
            name = NAMED.get(cp) or unicodedata.name(ch, "UNICODE TAG CHARACTER")
            hits.append((lineno, col, cp, name, cp in BIDI))
        if len(hits) >= 6:
            break
    if len(hits) >= 6:
        break

if not hits:
    sys.exit(0)
bidi = any(h[4] for h in hits)
out = []
for lineno, col, cp, name, _ in hits:
    out.append(f"line {lineno}, col {col}: U+{cp:04X} {name}")
print(("BIDI\n" if bidi else "PLAIN\n") + "\n".join(out))
PY
    )
    [ -n "$report" ] || return 0
    # Claimed only after a hit, so a clean touch keeps the file's one warning; mkdir is atomic, so one of two racing hooks reports.
    if [ -n "$mark" ]; then mkdir "$mark" 2>/dev/null || return 0; fi

    kind=$(printf '%s' "$report" | head -1)
    body=$(printf '%s' "$report" | tail -n +2)
    base=$(basename "$file")

    if [ "$kind" = "BIDI" ]; then
      printf '%s\n' "secret-scanning: \`$base\` contains BIDIRECTIONAL OVERRIDE characters. These reorder how source is DISPLAYED without changing how it executes, so what you and a reviewer read is not what the compiler runs — the Trojan Source class (CVE-2021-42574). Treat this file's visible content as unverified until the characters are removed or explained."
    else
      printf '%s\n' "secret-scanning: \`$base\` contains ZERO-WIDTH or invisible characters. They do not render and survive copy-paste; in text that reaches a model they can carry instructions a human reviewer cannot see. Legitimate in emoji sequences and in Arabic/Persian/Indic text — decide which this is."
    fi
    printf '%s\n' "$body"
  }

  if [ "$tool" = Bash ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    [ -n "$cmd" ] || exit 0
    targets=$(cc_bash_write_targets "$cmd" | head -n "$MAX_BASH_TARGETS")
    [ -n "$targets" ] || exit 0
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
    root=$(cc_state_root "$cwd") || exit 0
    files=""
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      # A relative target resolves against the payload cwd: the shell's cwd when the command starts.
      case "$p" in /*) ;; *) p="$cwd/$p" ;; esac
      # Logical cd && pwd, not pwd -P: the prefix test must compare in cc_state_root's spelling.
      d=$(CDPATH= cd -- "$(dirname -- "$p")" 2>/dev/null && pwd) || continue
      p="$d/$(basename -- "$p")"
      case "$p" in "$root"/*) ;; *) continue ;; esac
      [ -f "$p" ] && files="$files$p
"
    done <<EOF_T
$targets
EOF_T
  else
    files=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null)
  fi
  [ -n "$files" ] || exit 0

  msg=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    r=$(report_file "$f")
    [ -n "$r" ] && msg="$msg$r
"
  done <<EOF_F
$files
EOF_F
  [ -n "$msg" ] || exit 0

  jq -cn --arg c "${msg}Silence with CC_UNICODE_SCAN=off. This warns once per file per session and never blocks." \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
