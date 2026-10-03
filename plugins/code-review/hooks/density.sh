#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# Comment-VOLUME guard, two lanes. PostToolUse (warn-only, at most 3 warnings per
# session) compares the file just written against the comment density of its OWN
# siblings AND against an absolute ceiling, and says so when it is over either.
# PreToolUse (deny, a Write or a truncating Bash cat/tee heredoc, at most TWICE per file per session) refuses a whole new
# file whose comment-to-code ratio is over the ceiling before it lands. Silence is the
# common case.
#
# WHY THIS EXISTS — the gap scan.sh cannot close by design. scan.sh detects KINDS of
# bad comment: restatement, banners, commented-out code, bare TODOs, dead docblock
# tags, change narration. Every one of those is a pattern in a single comment. None of
# them fires on a well-formed why-comment, and a file can be 81% comment with every
# line individually defensible. That is not hypothetical: a 30-card run produced
# `GoogleClient.php` at 180 comment lines out of 223, and scan.sh was silent on it and
# on the three next-fattest files, correctly, because each comment passed every kind
# check. The skill's own anti-pattern list even warns against "deleting comments to hit
# a ratio" — which is right about deletion and was read as licence to never measure.
#
# WHY SIBLINGS. A driver with vendor quirks earns more prose than a controller, and
# "twice the surrounding code" is a signal no constant can give: a run at 0.3:1 in a
# repo that sits at 0.1:1 is an outlier the ceiling below would wave through. This
# hook reaches subagents, which is where writing actually happens and where a prose
# contract had no delivery channel.
#
# WHY A CEILING TOO (2026-09-02, owner decision). Siblings alone had two holes. A
# greenfield subtree with no tracked siblings got no judgment at all, which is the
# fan-out case this hook was written for. And a repo whose committed house style is
# already heavy certified more of the same. The marketplace's stated default is code
# that speaks for itself — minimal comments, a docblock only for what the signature
# cannot state — so the limit is now min(2x the sibling median, CEIL), and a file with
# no siblings is judged against CEIL alone. CEIL is 0.3:1 on prose lines by default, the one
# constant here; a project with a deliberately heavier style overrides it per project
# via `COMMENT_DISCIPLINE_CEILING_TENTHS` in its settings `env` (e.g. 10 for 1:1, 0 to
# switch the ceiling off and keep the sibling test). The deny lane uses the same CEIL.
#
# LIMITATION (honest scope — the four laws, see
# .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
#   - The PostToolUse lane is WARN-ONLY: `additionalContext` is not a blocking key. The
#     file is already on disk. It informs the next write, never the one that tripped it.
#     The PreToolUse lane denies, but only a `Write` or a truncating Bash heredoc (an Edit or an
#     append carries a fragment, whose ratio says nothing about the file), only over CEIL, at most TWICE
#     per file per session with the same marker-on-disk bound as scan.sh — so a false
#     positive costs up to two turns and the third attempt goes through with a warning.
#     The bound was one until 2026-09-15; a sibling hook denying the same call spent it
#     without the write ever landing, which cost this guard its only enforcement.
#   - BASH LANE. Pre-write, a truncating `cat`/`tee` heredoc is judged as a Write of its body to the
#     resolved path (cd_bash_target in hooks/paths.sh), first deny printed; an append (`>>`, `tee -a`)
#     is a fragment and is never denied. After the command, the warn lane measures the first 3 targets
#     that exist on disk, in command order, whatever wrote them, skips one whose first five lines carry
#     a generated marker, and prints the first warning. NOT SEEN on Bash: interpreter writes (python
#     open()), cp/mv, a path held in a variable, a relative target after an in-command cd, targets past
#     the first 3; pre-write also a heredoc fed to anything but cat/tee, a heredoc whose file the
#     command writes again, heredocs past the 40th to a governed file, echo/printf and sed -i / perl -i content, the second
#     operand of `tee a b`, `VAR=x tee f`, cat/tee behind a wrapper, brace or keyword; plus what the two blocks below miss.
#   - A ratio is not a judgment. A file legitimately denser than its siblings (the one
#     driver full of vendor workarounds) trips this, and that is a false positive the
#     author should overrule by keeping the comments and moving on — the message says so.
#   - It cannot see the AGGREGATE across a fan-out. Each subagent gets its own warning
#     in its own context; nothing sums 73 files and reports "this run runs 2x the
#     repo". The ledger below exists so that question can be answered later from data,
#     but nothing reads it back today and calling it a feedback loop would be the
#     over-claim this plugin has been pulled up on before.
#   - The counter is cd_classify in hooks/paths.sh: a per-language line classifier, not a
#     parser. The numerator is PROSE lines: delimiters, typed doc tags, tool directives, a
#     licence first block and `|`-boxed config blocks are comments but not prose. A trailing
#     comment, a mid-line `/*` and a triple-quoted string that is no docstring count as
#     code; a directive it does not know counts as prose. A line it is unsure of is code. Dockerfiles and Makefiles are not judged.
#   - Thresholds are a starting point, not a constant: 2.0x the sibling MEDIAN, with an
#     absolute floor of 0.3 so a repo that comments almost nothing cannot make a single
#     why-comment an outlier, then capped at CEIL. The floor EQUALS the default ceiling,
#     so the sibling test decides only where a project raised CEIL past 0.3 or set it to 0.
#     A file under 50 lines, or under 8 code lines, gets the SHORT rule instead: over the
#     limit with 5+ prose lines, a code line, and more prose than code (or than CEIL allows,
#     once CEIL is past 1:1); CEIL=0 switches it off. The ledger records every measurement
#     so the thresholds can be revisited against real data instead of re-argued.
#
# FAIL-OPEN: missing jq/awk, unreadable file, too few siblings, or any error exits 0.
# CC_REMIND / CC_COMMENT_GUARD unset: the /config options cc_remind / cc_comment_guard decide.
# State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/comment-discipline/ is only the fallback.

# --- state root ----------------------------------------------------------------
# Canonical copy: templates/blocks/state-root.md. Every hook defining cc_state_root must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# The payload's `cwd` is the SHELL's cwd and follows the model's `cd` — measured
# 2026-09-25: app/Enums, then app/Models, then the repo root in one session, each leaving
# its own `.claude/` state dir and each re-firing a "once per session" nudge. State lives
# at the project root instead (pc_state_root refuses a raw `$cwd/.claude` path in a hook):
# the git toplevel reached by walking UP from cwd (`--show-cdup`, so a symlinked /tmp keeps
# the caller's spelling and path-prefix comparisons still hold); outside git,
# CLAUDE_PROJECT_DIR when cwd sits under it; else cwd. A cwd that no longer exists yields
# nothing and status 1 — the caller exits rather than resurrect a deleted project.
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

# --- plugin state --------------------------------------------------------------
# Canonical copy: templates/blocks/plugin-state.md. Every hook defining cc_plugin_state must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# cc_plugin_state <root> <name> prints the directory holding a plugin's own per-project hook
# state, <root> being the hook's cc_state_root result: ${CLAUDE_PLUGIN_DATA}/<key>/<name> when
# the host sets that variable, else <root>/.claude/<name>, the path hooks used before it.
# <key> is the root's basename with every character outside [A-Za-z0-9_-] turned into -, a -,
# and the root's cksum: the host gives one data dir per plugin id, not per project (measured
# 2.1.282), and a raw path inside a filename names parents that never exist. tr runs under
# LC_ALL=C because a UTF-8 tr stops at the first invalid byte. Status 0, no stderr; it
# creates nothing, so the caller keeps its own mkdir -p.
# WHY: state read by no one but the plugin's own hooks does not belong in the user's repo —
# the 2026-09-29 review found .claude/code-review/ and .claude/skill-router/ created by one
# prompt and one edit in a fresh repo.
# WHAT IT DOES NOT CATCH: state another plugin, a skill or the user reads must not use it; the
# fallback path is still in the repo; the data dir is keyed by plugin id, so install scopes of
# one plugin share it (inferred from the docs' id rule), while a --plugin-dir copy gets its
# own `-inline` directory and never sees the installed copy's state. The variable was measured
# only in a SessionStart hook; other events are doc-stated. An event that lacks it falls back
# to the repo path, which splits a writer from a reader running on another event.
cc_plugin_state() {
  local key sum
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    key=$(printf '%s' "$(basename -- "$1")" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-')
    sum=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
    printf '%s/%s-%s/%s\n' "${CLAUDE_PLUGIN_DATA%/}" "$key" "$sum" "$2"
  else
    printf '%s/.claude/%s\n' "$1" "$2"
  fi
  return 0
}

# --- option resolver -----------------------------------------------------------
# Canonical copy: templates/blocks/option-resolver.md. Every hook defining cc_option must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# cc_option <ENV_NAME> <default> [<level-file>] prints one line, the first non-empty of: the
# variable ENV_NAME; the first word of <level-file>, if given and readable; the userConfig
# option CLAUDE_PLUGIN_OPTION_<ENV_NAME>, true/false read as on/off; <default>. The shell wins
# because the environment is the one state independently installed plugins share (CC_REMIND
# or CC_BOOST there mutes every plugin at once); the option gives one plugin a /config row.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# Status 0, no stderr: a malformed name, an expansion error that exits bash 5, yields <default>.
# WHAT IT DOES NOT CATCH: a caller passing a variable instead of a literal name, or a value
# outside the switch's vocabulary — each hook still validates the value it gets.
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

# --- bash write targets --------------------------------------------------------
# Canonical copy: templates/blocks/bash-write-targets.md. Every hook defining
# cc_bash_write_targets must carry this block byte-for-byte (pc_shared_blocks).
# The host steers file writes through Bash (auto mode `bashFirst`); in one measured session
# 233 of 238 main-thread writes were `cat > file <<EOF`, invisible to a hook matching
# Write|Edit.
# Prints one target path per line, as spelled in the command (relative or absolute).
# Heredoc BODIES are dropped and quoted text is masked before matching, so PHP `->`/`=>`,
# HTML `>` and a sed script's `s|a|b|` never read as redirects or pipes; a here-string
# (`<<<`) is not a heredoc. Catches `>`/`>>` onto a path (cat, echo, printf, any command),
# `[sudo] tee [-a] <paths>`, and every file operand of `sed -i`/`-I`/`--in-place` / `perl -i`
# after the script or its `-e`/`-f` arguments, never a redirect word or its target. BSD's
# `-I` always takes the next word as its backup suffix; a `''` or a `.`-led word with no `/`
# right after sed's bare `-i` is read as one too, unless it would be the only file.
# Does NOT catch:
# interpreter writes (python open(), php file_put_contents), cp/mv/install destinations,
# `{ …; } > f` groups, a path held in a variable (`> "$f"` is skipped, never guessed),
# a globbed operand (`sed -i … tests/*.js`: a word with `*`/`?` is dropped), a `\` line
# continuation, sed/perl behind another command word (`gsed`, `/usr/bin/sed`, `env`,
# `xargs`, `command`, `sudo -u x`, `find … -exec sed -i`), a digit- or `&`-led redirect onto
# a file (`2> f`, `&> f`). A lone `&` does not end a command, so words after it can read as
# sed/perl/tee operands.
# The caller filters to existing files under its root.
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
        for (j = scr ? 1 : 2; j <= nf; j++) if (f[j] !~ /^-/) { emit(f[j]); sfx = "" }
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
        if (i > length(m) || c == ";" || c == "|" || c2 == "&&") {
          if (i > st) segment(substr(m, st, i - st), substr(line, st, i - st))
          if (c2 == "&&" || c2 == "||") i++
          st = i + 1
        }
      }
    }' | awk '!seen[$0]++'
}

# --- bash write chunks --------------------------------------------------------
# Canonical copy: templates/blocks/bash-write-chunks.md. Every hook defining
# cc_bash_write_chunks must carry this block byte-for-byte (pc_shared_blocks).
# cc_bash_write_chunks <command> — what a Bash command puts INTO files: the text a content
# guard reads on Bash where its Write path reads tool_input.content. Prints chunks: a line that
# starts with \036 and carries the WRITER — the pipeline (split on ; && ||, never inside
# quotes) whose targets the caller resolves with cc_bash_write_targets — then the
# chunk's text lines. Two sources, and only two:
#   - a heredoc BODY: the lines between `<<TERM` (`<<-`, quoted or `\`-escaped TERM too)
#     and TERM; writer = the pipeline holding the `<<` (`cat > f <<EOF`,
#     `cat <<EOF | tee -a f`);
#   - the ARGUMENTS of an `echo`/`printf` segment, as written: the rest of the segment after
#     the command word, quotes, escapes and any `> file` redirect kept (so match inside the
#     text, never anchored at its start); writer = its pipeline
#     (`echo "K=v" >> .env.example`, `printf '%s\n' v | tee f`).
# A chunk whose writer names no file is dropped by the caller, so `git commit -F - <<EOF`
# and `echo x | grep y` yield nothing. The body of ANY heredoc whose pipeline writes a file
# is read, whatever consumes it — `python3 - <<PY > out.txt` included, where the script is
# not what lands in out.txt. Accepted: the text sits in a file-writing command either
# way.
# NOT read, stated: a `{ echo …; } > f` group (the redirect sits on the closer, not on
# the echo's pipeline); a here-string `<<<`; printf's format substitution (`printf
# 'K=%s' v` is read as written: the format and the argument, never the substituted
# line); a quoted string or a `\` continuation spanning lines; a second heredoc opened
# on one line.
# mask() copies the one inside cc_bash_write_targets: the block is byte-locked and its
# awk functions are not reachable from outside it.
cc_bash_write_chunks() {
  printf '%s\n' "$1" | awk '
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
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function echo_args(p, mp,   i, st, seg, out) {
      out = ""; st = 1
      for (i = 1; i <= length(mp) + 1; i++) {
        if (i > length(mp) || substr(mp, i, 1) == "|") {
          seg = substr(mp, st, i - st)
          if (match(seg, /^[ \t]*(echo|printf)[ \t]/)) out = out substr(p, st + RLENGTH, i - st - RLENGTH) "\n"
          st = i + 1
        }
      }
      return out
    }
    inbody { if (trim($0) == term) inbody = 0; else print; next }
    {
      line = $0; m = mask(line); st = 1; opener = ""
      for (i = 1; i <= length(m) + 1; i++) {
        c = substr(m, i, 1); c2 = substr(m, i, 2)
        if (i > length(m) || c == ";" || c2 == "&&" || c2 == "||") {
          if (i > st) {
            p = substr(line, st, i - st); mp = substr(m, st, i - st)
            a = echo_args(p, mp)
            if (a != "") printf "\036%s\n%s", p, a
            if (opener == "" && match(mp, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
              t = substr(p, RSTART, RLENGTH)
              sub(/^[^<]*<<-?[ \t]*["\047]?/, "", t); sub(/^\\/, "", t); sub(/[^A-Za-z0-9_].*$/, "", t)
              if (t != "") { opener = p; term = t }
            }
          }
          if (c2 == "&&" || c2 == "||") i++
          st = i + 1
        }
      }
      if (opener != "") { printf "\036%s\n", opener; inbody = 1 }
    }'
}

{
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v awk >/dev/null 2>&1 || exit 0

  input=$(cat)
  event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null) || exit 0
  case "$event" in PostToolUse|PreToolUse) ;; *) exit 0 ;; esac
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  # Only a whole file has a ratio: a Write carries one, and so does a truncating Bash heredoc.
  [ "$event" = "PreToolUse" ] && [ "$tool" != "Write" ] && [ "$tool" != "Bash" ] && exit 0
  case "$tool" in
    Edit|Write|MultiEdit)
      fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0 ;;
    Bash)
      cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
      # Same guard as scan.sh: the blocks are quadratic in the length of one line.
      [ "${#cmd}" -gt 32768 ] && printf '%s\n' "$cmd" | awk 'length($0) > 2000 { s += length($0) } length($0) > 8192 || s > 32768 { f = 1; exit } END { exit !f }' && exit 0
      tgts=$(cc_bash_write_targets "$cmd")
      [ -n "$tgts" ] || exit 0 ;;
    *) exit 0 ;;
  esac
  # Sourced only here, below the exit of a Bash call that writes nothing; without the file nothing is governed.
  . "$(dirname "$0")/paths.sh" 2>/dev/null
  if [ "$tool" = Bash ]; then
    gov=0
    while IFS= read -r t; do cd_governed "$t" && gov=1; done <<EOF_G
$tgts
EOF_G
    [ "$gov" = 1 ] || exit 0
  else
    cd_governed "$fp" || exit 0
  fi
  # WARN lane only — see scan.sh's note; the PreToolUse deny ignores this switch.
  [ "$event" = "PostToolUse" ] && [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
  # CC_COMMENT_GUARD=off disables the DENY lane and leaves the advisory lane on.
  # Added 2026-09-22 (UX 1), same reasoning as scan.sh's: the block had no off switch,
  # so its refusal could name none. Read from the hook's environment.
  [ "$event" = "PreToolUse" ] && [ "$(cc_option CC_COMMENT_GUARD on)" = "off" ] && exit 0

  if [ "$tool" = Bash ] && [ "$event" = "PreToolUse" ]; then
    chunks=$(cc_bash_write_chunks "$cmd")
    [ -n "$chunks" ] || exit 0
    nc=0; k=0
    while IFS= read -r l; do
      [ "$nc" -lt 40 ] || break   # 400 one-line heredocs to .sh files took 11 s against a 10 s timeout
      k=$((k + 1)); tgt=$(cc_bash_write_targets "${l#?}" | head -n 1)
      if [ -n "$tgt" ] && cd_governed "$tgt"; then nc=$((nc + 1)); ctgt[$nc]=$tgt; chdr[$nc]=${l#?}; cnum[$nc]=$k; fi
    done <<EOF_C
$(printf '%s\n' "$chunks" | awk 'substr($0, 1, 1) == "\036"')
EOF_C
    [ "$nc" -gt 0 ] || exit 0
  fi

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  # CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
  # subagents at all, and a subagent shares its parent's session_id while getting its
  # own transcript. Keying a one-shot on session_id therefore dedups the worker against
  # nudges only the PARENT ever saw, so the context where most fan-out code is written
  # is the one context this never speaks in. Key on transcript_path first, session_id as fallback.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  # `-d` as well as `-n`: a session outlives its directories, and the `mkdir -p "$dir"`
  # below rebuilt a deleted three-level project tree just to hold this hook's state. Then
  # the state ROOT, not the cwd: the payload cwd is the shell's and follows the model's
  # `cd` (measured 2026-09-25, rationale/2026-09-25-session-plugin-usage-review.md finding
  # 2 — app/Enums, app/Models, then the repo root in one session), so `<cwd>/.claude` scattered
  # one state dir per directory and reset MAX_WARN and the per-file dedup at every `cd`.
  # The address `<root>/.claude/comment-discipline` is SHARED with verbosity.sh and
  # scan.sh; all three moved to cc_state_root in one change (0.23.0), because re-rooting
  # one of them alone splits a bound across two paths. Does NOT catch a cwd that exists
  # but is the wrong checkout — the payload cannot say.
  [ -n "$cwd" ] && [ -d "$cwd" ] && [ -n "$sid" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  # The floor is on SUBSTANTIVE LINES, not on code lines, and the difference is the
  # whole point. A `code >= 40` floor excludes exactly the worst case this hook exists
  # to catch: the observed `GoogleClient.php` was 223 lines of which 180 were comment,
  # so it had ~43 code lines and a code-shaped floor would have waved through the
  # single densest file in the run. A few code lines are still needed for the ratio to
  # mean anything, hence MIN_CODE — set low, as a divide-by-noise guard, not a filter.
  MIN_LINES=50       # comment + code; a file under this, or under MIN_CODE, gets the short rule
  MIN_CODE=8         # enough denominator for a ratio to carry information
  MIN_SIBLINGS=3     # a median of two files is not a house style
  SAMPLE_CAP=25      # bounded cost: this runs after every edit
  MULT=20            # 2.0x, in tenths (integer arithmetic only)
  FLOOR=3            # 0.3, in tenths — absolute lower bound on "outlier"
  CEIL=${COMMENT_DISCIPLINE_CEILING_TENTHS:-3}   # 0.3, in tenths; 0 switches the ceiling off
  case "$CEIL" in ''|*[!0-9]*) CEIL=3 ;; esac
  CEIL=$((10#$CEIL))   # a leading zero would read as octal
  SHORT_LIMIT=$CEIL; [ "$SHORT_LIMIT" -ge 10 ] || SHORT_LIMIT=10   # 1:1, or the ceiling once a project raised it past that
  MAX_WARN=3

  density_regime() { # <prose> <comment> <code>
    d_regime=ratio
    [ "$(( $2 + $3 ))" -ge "$MIN_LINES" ] && [ "$3" -ge "$MIN_CODE" ] && return 0
    d_regime=short
    [ "$1" -ge 5 ] && [ "$3" -ge 1 ] && [ "$CEIL" -gt 0 ]
  }
  # The printed ratio is rounded up, so a file over its limit never prints the limit's own number.
  density_over() { # <prose> <code> <limit, in tenths>
    d_ratio=$(( ($1 * 10 + $2 - 1) / $2 ))
    [ "$3" -gt 0 ] && [ "$(( $1 * 10 ))" -gt "$(( $3 * $2 ))" ]
  }

  density_judge() {
  fp=$1 text=$2 mode=$3 msg=""
  [ -n "$fp" ] || return 1
  cd_governed "$fp" || return 1
  if [ "$event" = "PostToolUse" ]; then [ -f "$fp" ] && [ -r "$fp" ] || return 1; fi
  # Same PATH exclusions as scan.sh, decided by hooks/paths.sh against the same LOGICAL
  # path (worktree prefix stripped): generated, vendored and marketplace tooling trees
  # have deliberate header blocks. A missing paths.sh judges nothing. Config/prose formats
  # use comments for navigation, which this rule does not govern.
  command -v cd_path_exempt >/dev/null 2>&1 || return 1
  cd_path_exempt "$fp" "$root" && return 1
  cd_lang "$fp" || return 1
  lang=$cd_lang_key
  # A comment per instruction is idiomatic in a build file (owner decision 2026-10-02); scan.sh still reads them.
  case "$lang" in dockerfile|make) return 1 ;; esac
  # A generator redirected to a file (`gen > src/api.ts`) leaves its marker on disk, not in the command.
  [ "$event" = "PostToolUse" ] && [ "$tool" = Bash ] && cd_generated < "$fp" && return 1

  dir=$(cc_plugin_state "$root" comment-discipline)
  # Hashed, not raw: `.transcript_path` is an absolute path, so `density-$sid` names a
  # nested file whose parents are never created. Every state write then fails silently,
  # `warned` stays 0, MAX_WARN never engages, the per-file dedup never engages, and the
  # self-output filter below never engages — so a track run raises the sibling median to
  # match its own dense output and certifies the drift it just wrote. Same idiom as
  # the `seen=` line of hooks/conventions.sh.
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || return 1
  state="$dir/density-$ctx"
  # Same rule as scan.sh's deny lane and verbosity.sh: a bound that cannot be recorded
  # is not a bound. Unwritable state means this hook does nothing at all, rather than
  # warning on every single edit for the rest of the session.
  mkdir -p "$dir" 2>/dev/null || return 1
  [ -w "$dir" ] || return 1
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null   # the state dir ignores itself

  # ---- PreToolUse lane: deny a whole new file over CEIL, at most TWICE per file ----
  # Same bound and the same reasoning as scan.sh's deny: the model wrote it, so the
  # model is the audience; `ask` would interrupt the human for a style call; and a
  # deny that cannot record its bounding marker is withheld rather than left unbounded.
  if [ "$event" = "PreToolUse" ]; then
    [ "$mode" = truncate ] || return 1
    [ "$CEIL" -gt 0 ] || return 1
    content=$text
    [ -n "$content" ] || return 1
    printf '%s\n' "$content" | cd_generated && return 1
    read -r pprose pc pcode <<EOF
$(printf '%s\n' "$content" | cd_classify "$lang")
EOF
    case "${pprose:-x} ${pc:-x} ${pcode:-x}" in *[!0-9\ ]*) return 1 ;; esac
    density_regime "$pprose" "$pc" "$pcode" || return 1
    limit=$CEIL; [ "$d_regime" = short ] && limit=$SHORT_LIMIT
    density_over "$pprose" "$pcode" "$limit" || return 1
    key=$(printf '%s' "$fp" | (command -v shasum >/dev/null 2>&1 && shasum || cksum) 2>/dev/null | cut -d' ' -f1)
    [ -n "$key" ] || return 1
    marker="$dir/density-blocked-$ctx-$key"
    # BOUNDED RETRIES, not a one-shot — same defect and same fix as scan.sh: a sibling
    # PreToolUse deny blocks the write too, and the old one-shot was spent on a write
    # that never landed, so the next edit of this file went through unchecked.
    DENY_CAP=2
    # ATOMIC (0.19.1): `mkdir` either creates or fails, so parallel subagents editing one
    # file cannot both read the same count and both write it back. A legacy zero-byte
    # marker counts as one try so an upgrade mid-session does not grant a fresh budget.
    # Residual, same as scan.sh: the bound is spent on a DENY, which does not prove the
    # write landed — two co-firing siblings can still exhaust it.
    tries=0
    [ -e "$marker" ] && tries=1
    i=1
    while [ "$i" -le "$DENY_CAP" ]; do [ -d "$marker.d$i" ] && tries=$i; i=$((i + 1)); done
    [ "$tries" -ge "$DENY_CAP" ] && return 1
    # The name goes through the environment: macOS awk refuses a -v value holding a newline.
    msg=$(file_name="${fp##*/}" LC_ALL=C awk -v c="$pprose" -v cd="$pcode" -v r="$d_ratio" -v l="$limit" \
      'BEGIN { f = ENVIRON["file_name"]; printf "comment-discipline: %s would be %.1f:1 comment-to-code (%d comment lines, %d code); the ceiling is %.1f:1. Write it again with the code carrying the meaning: keep only a why-this-not-the-obvious, an external constraint with a link, a deliberate no-op, or a contract fact the signature cannot state (units, ownership, what throws) — and move the rest to a name, a type, or a test. Blocked at most twice per file; after that a write goes through with a warning instead. CC_COMMENT_GUARD=off disables this block for the session (CC_REMIND=off silences the warning it falls back to).", f, r/10, c, cd, l/10 }')
    [ -n "$msg" ] || return 1
    mkdir "$marker.d$((tries + 1))" 2>/dev/null || return 1
    return 0
  fi

  warned=0
  if [ -r "$state" ]; then
    warned=$(grep -c '^warn ' "$state" 2>/dev/null) || warned=0
    case "$warned" in ''|*[!0-9]*) warned=0 ;; esac
    [ "$warned" -ge "$MAX_WARN" ] && return 1
    grep -qxF "file $fp" "$state" 2>/dev/null && return 1   # already reported this file
  fi

  read -r fprose fc fcode <<EOF
$(cd_classify "$lang" "$fp")
EOF
  case "${fprose:-x} ${fc:-x} ${fcode:-x}" in *[!0-9\ ]*) return 1 ;; esac
  density_regime "$fprose" "$fc" "$fcode" || return 1
  if [ "$d_regime" = short ]; then density_over "$fprose" "$fcode" "$SHORT_LIMIT" || return 1; fi

  # ---- baseline: same-language siblings, nearest directory first ----
  # Cached per directory per session — a fan-out writing 30 files into one package
  # must not re-scan that package 30 times.
  fdir=$(dirname "$fp")
  # Resolved forms, computed once. Needed in two places that must agree: the
  # repo-root bound on the sibling walk, and the "already measured this session"
  # ledger — git reports symlink-free paths and the edited path usually is not one.
  rdir=$(cd "$fdir" 2>/dev/null && pwd -P) || rdir="$fdir"
  rfp="$rdir/$(basename "$fp")"
  key=$(printf '%s' "$fdir/$lang" |(command -v shasum >/dev/null 2>&1 && shasum || cksum) 2>/dev/null | cut -d' ' -f1)
  base=""
  [ -n "$key" ] && base=$(awk -v k="$key" '$1=="base" && $2==k {print $3}' "$state" 2>/dev/null | tail -1)

  if [ -z "$base" ]; then
    # THE BASELINE MUST BE PRE-EXISTING CODE, and this is the subtlety the whole hook
    # turns on. A fan-out that writes 73 uniformly dense files into one new package
    # would otherwise compute its baseline FROM ITS OWN OUTPUT, find no outlier, and
    # certify the drift it just created. That is precisely the run this hook exists
    # for. So siblings are drawn from files git already TRACKS — committed code is
    # house style; a file this run created is not — and any file this session has
    # already written is filtered out on top, which covers a tracked file the run
    # rewrote. Not a git repo, or git absent: fall back to `find`, and say so in the
    # ledger by way of the baseline it produces.
    sibs_from() { # $1 dir, $2 maxdepth
      local d="$1" depth="$2" rel
      # A superset by name, then cd_lang decides: `*.php` also lists Blade files.
      case "$lang" in
        blade) set -- '*.blade.php' ;;
        *) set -- "*.$lang" ;;
      esac
      if command -v git >/dev/null 2>&1 && git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # -z: without it git C-quotes a name holding a quote, a backslash or a non-ASCII byte.
        git -C "$d" ls-files -z -- "$@" 2>/dev/null | while IFS= read -r -d '' rel; do
          case "$rel" in */*/*) [ "$depth" -ge 2 ] || continue ;; esac
          printf '%s/%s\n' "$d" "$rel"
        done
      else
        find "$d" -maxdepth "$depth" -type f -name "$1" 2>/dev/null
      fi | while IFS= read -r rel; do
        cd_lang "$rel" && [ "$cd_lang_key" = "$lang" ] && printf '%s\n' "$rel"
      done
    }
    pick() { # $1 dir, $2 maxdepth — tracked siblings minus this file minus this run's writes
      sibs_from "$1" "$2" | while IFS= read -r s; do
        case "$s" in "$fp"|"$rfp") continue ;; esac
        grep -qxF "file $s" "$state" 2>/dev/null && continue
        printf '%s\n' "$s"
      done | head -n "$SAMPLE_CAP"
    }
    # WALK UP until there is enough tracked code to average, capped at 4 levels. One
    # widening step is not enough: a feature fan-out creates a whole new SUBTREE
    # (`app/Services/Google/Contracts/`), so neither that directory nor its parent has
    # any tracked file, and a two-step search finds nothing and exits silently on
    # exactly the run this hook is for. Depth grows with the walk so a shallow level
    # can still reach the code below it.
    #
    # THE WALK IS BOUNDED BY THE REPOSITORY ROOT, and that bound is load-bearing rather
    # than tidy. Without it a file in a repo with no tracked code walks out of the
    # project entirely and averages whatever `.php` files happen to sit in the parent
    # directory — a sibling checkout, a scratch dir — then reports that as "its
    # siblings". A baseline computed from unrelated code is worse than no baseline,
    # because the warning names a house style that does not exist.
    # Both sides of the bound are resolved with `pwd -P` before comparison. They must
    # be: `git rev-parse --show-toplevel` returns a symlink-free path, while the edited
    # file's path usually is not — on macOS every `/var/...` path is really
    # `/private/var/...` — so a raw string prefix test fails on exactly the temp dirs
    # this is tested in, and silently reduces the walk to zero levels.
    top=""
    if command -v git >/dev/null 2>&1; then
      top=$(cd "$rdir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
    fi
    [ -n "$top" ] || top=$(cd "$root" 2>/dev/null && pwd -P) || top="$root"

    sibs=""; n=0; d="$rdir"; depth=1; up=0
    while [ "$up" -lt 4 ]; do
      case "$d" in "$top"|"$top"/*) ;; *) break ;; esac
      sibs=$(pick "$d" "$depth")
      n=$(printf '%s\n' "$sibs" | grep -c . )
      [ "$n" -ge "$MIN_SIBLINGS" ] && break
      parent=$(dirname "$d")
      [ "$parent" = "$d" ] && break
      d="$parent"; depth=$((depth + 1)); up=$((up + 1))
    done
    # Median of the per-sibling ratios in tenths. Median, not mean: one 90%-comment
    # interface file in the sample must not redefine the house style by itself.
    # No usable siblings leaves base empty, and the ceiling alone judges the file.
    if [ "$n" -ge "$MIN_SIBLINGS" ]; then
      # One awk for every sibling; a tracked file that is gone from disk would make awk exit with nothing read.
      base=$(set --
             while IFS= read -r s; do [ -f "$s" ] && [ -r "$s" ] && set -- "$@" "$s"; done <<EOS
$sibs
EOS
             [ "$#" -gt 0 ] || exit 0
             # One find for the whole set: 25 siblings of 7.7 MB took the classifier 8 s against a 10 s timeout.
             kept=$(find "$@" -size -262145c 2>/dev/null); set --
             while IFS= read -r s; do [ -n "$s" ] && set -- "$@" "$s"; done <<EOS
$kept
EOS
             [ "$#" -gt 0 ] || exit 0
             cd_classify "$lang" "$@" | awk '$3 >= 10 { print int(($1 * 10 + $3 - 1) / $3) }' |
               sort -n | awk '{v[NR]=$1} END{ if (NR==0) exit; print v[int((NR+1)/2)] }')
      case "${base:-}" in ''|*[!0-9]*) base="" ;; esac
      [ -n "$base" ] && [ -n "$key" ] && printf 'base %s %s\n' "$key" "$base" >> "$state" 2>/dev/null
    fi
  fi

  if [ "$d_regime" = short ]; then
    limit="$SHORT_LIMIT"
  elif [ -n "$base" ]; then
    limit=$(( base * MULT / 10 ))
    [ "$limit" -lt "$FLOOR" ] && limit="$FLOOR"
    [ "$CEIL" -gt 0 ] && [ "$limit" -gt "$CEIL" ] && limit="$CEIL"
  else
    [ "$CEIL" -gt 0 ] || return 1
    limit="$CEIL"
  fi
  density_over "$fprose" "$fcode" "$limit"; over=$?

  # LEDGER. Every measurement, warned or not — machine-local, never in the project
  # tree, capped, and read by nothing automatically. Same placement and same honest
  # framing as verbosity.sh's: it exists so the thresholds above can be revisited
  # against real data rather than re-argued.
  ledger="${HOME:-/tmp}/.claude/comment-discipline/density-ledger.jsonl"
  if [ "$(wc -c < "$ledger" 2>/dev/null || echo 0)" -lt 1048576 ]; then
    mkdir -p "${ledger%/*}" 2>/dev/null &&
      jq -cn --arg s "$sid" --arg f "$fp" --arg e "$lang" --argjson c "$fprose" \
             --argjson cd "$fcode" --argjson r "$d_ratio" --argjson b "${base:--1}" --argjson l "$limit" \
        '{session:$s,file:$f,ext:$e,comment:$c,code:$cd,ratio_tenths:$r,baseline_tenths:$b,limit_tenths:$l,warned:($r>$l)}' \
        >> "$ledger" 2>/dev/null
  fi

  printf 'file %s\n' "$fp" >> "$state" 2>/dev/null
  [ "$rfp" = "$fp" ] || printf 'file %s\n' "$rfp" >> "$state" 2>/dev/null
  [ "$over" = 0 ] || return 1

  msg=$(file_name="${fp##*/}" LC_ALL=C awk -v c="$fprose" -v cd="$fcode" -v r="$d_ratio" -v b="${base:--1}" -v l="$limit" -v n="$((warned + 1))" -v m="$MAX_WARN" \
    'BEGIN {
      f = ENVIRON["file_name"]
      if (b >= 0) printf "comment-discipline: %s is %.1f:1 comment-to-code (%d comment lines, %d code); its siblings run %.1f:1 and the limit here is %.1f:1.", f, r/10, c, cd, b/10, l/10
      else        printf "comment-discipline: %s is %.1f:1 comment-to-code (%d comment lines, %d code); no committed siblings to compare against, so the ceiling of %.1f:1 applies.", f, r/10, c, cd, l/10
      printf " The default is code that needs no comment. If this file genuinely needs the prose (vendor quirks, a protocol the code cannot show), keep it and move on; otherwise keep only why-comments, linked constraints, deliberate no-ops and contract facts the signature cannot state, and move the rest to a name, a type, or a test. Warning %d of %d this session. CC_REMIND=off silences these.", n, m }')
  [ -n "$msg" ] || return 1
  printf 'warn %s\n' "$fp" >> "$state" 2>/dev/null
  return 0
  }

  emit() {
    if [ "$event" = "PreToolUse" ]; then
      jq -cn --arg r "$msg$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    else
      jq -cn --arg m "$msg$1" \
        '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}'
    fi
  }

  if [ "$tool" != Bash ]; then
    content=""
    if [ "$event" = "PreToolUse" ]; then
      content=$(printf '%s' "$input" | jq -r '.tool_input.content // empty' 2>/dev/null) || exit 0
    fi
    density_judge "$fp" "$content" truncate && emit ""
  elif [ "$event" = "PreToolUse" ]; then
    hascd=0; cd_has_cd "$cmd" && hascd=1
    # A file the command writes twice is not one chunk alone. The block de-duplicates its targets, so each kept header's own target is pointed at /dev/null, the rest read once, and a path met twice goes to the disk lane.
    c=1; all=""; pairs=$nc   # c and nc, not `i` and `n`: density_judge assigns both of those
    while [ "$c" -le "$nc" ]; do
      cabs[$c]=""
      cd_resolve "${ctgt[$c]}" "$cwd" "$hascd" && { cabs[$c]=$cd_path; all="$all$cd_path
"; }
      pairs="$pairs
${ctgt[$c]}
${chdr[$c]}"
      c=$((c + 1))
    done
    while IFS= read -r o; do
      cd_resolve "$o" "$cwd" "$hascd" && all="$all$cd_path
"
    done <<EOF_O
$(cc_bash_write_targets "$(printf '%s\n%s\n' "$pairs" "$cmd" | awk '
      NR == 1 { n = $0 + 0; next }
      NR <= 1 + 2 * n { if (NR % 2) H[++b] = $0; else T[++a] = $0; next }
      { while (k < n && (i = index($0, H[k + 1])) && (j = index(H[k + 1], T[k + 1]))) {
          k++; $0 = substr($0, 1, i + j - 2) "/dev/null" substr($0, i + j - 1 + length(T[k])) }
        print }')")
EOF_O
    twice="
$(printf '%s' "$all" | awk 'seen[$0]++ == 1')
"
    c=1
    while [ "$c" -le "$nc" ]; do
      fp=${cabs[$c]}
      case "$twice" in *"
$fp
"*) fp="" ;; esac
      if [ -n "$fp" ] && [ "$(cd_chunk_mode "${chdr[$c]}")" = truncate ] && cd_target_whole "${chdr[$c]}" "${ctgt[$c]}" \
         && density_judge "$fp" "$(cd_chunk_text "$chunks" "${cnum[$c]}")" truncate; then
        emit " Written by a Bash command: $(basename "$fp")."
        exit 0
      fi
      c=$((c + 1))
    done
  else
    hascd=0; cd_has_cd "$cmd" && hascd=1
    nt=0
    while IFS= read -r tgt; do
      [ "$nt" -lt "$MAX_WARN" ] || break
      fp=$(cd_bash_target "$tgt" "$cwd" "$hascd") && [ -f "$fp" ] || continue
      nt=$((nt + 1))
      if density_judge "$fp" "" truncate; then
        emit " Written by a Bash command: $(basename "$fp")."
        exit 0
      fi
    done <<EOF_T
$tgts
EOF_T
  fi
} 2>/dev/null
exit 0
