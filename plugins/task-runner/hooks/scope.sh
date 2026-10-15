#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# PostToolUse scope-lock tripwire. When a REGISTERED run (.claude/task-runner/active-run.json
# at the project root) has declared its allowed files in .claude/task-runner/scope*.json,
# this warns (non-blocking) if a write landed OUTSIDE the union of those sets — the "touch
# only files the task lists" discipline made mechanical. The warning is emitted as the
# PostToolUse stdout JSON envelope
# ({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}},
# exit 0) — the one non-blocking channel the executing model actually receives;
# plain stdout text with exit 0 never reaches it (same channel reasoning as
# candor's gate.sh clause 4, whose Stop event reaches the model only through exit 2).
# No registered run, or no live scope file → no-op (the discipline is opt-in per run).
# A Bash call that exits non-zero fires PostToolUseFailure instead, registered for Bash too;
# the envelope then names that event. Such a command may have stopped before its redirect, so a
# named target the previous call's marker post-dates is skipped, and on a call with no marker
# (the run's first) a named target takes the effects wording below, never "revert". Fail-open.
#
# WHAT IT SEES (0.41.0). Edit/Write/MultiEdit through `.tool_input.file_path`, AND Bash:
# the files a command writes by `>`/`>>`, heredoc, `tee` or `sed -i`/`perl -i`, parsed by
# cc_bash_write_targets below, resolved against the Bash call's cwd, kept only when they
# are existing regular files under the project root, at most 8 per call (MAX_BASH_TARGETS).
# Measured 2026-09-25 (rationale/2026-09-25-session-plugin-usage-review.md, finding 1): with
# the host's `bashFirst` auto mode, 233 of 238 main-thread writes in one session were
# `cat > file`, so an Edit/Write-only tripwire was blind on the default write path.
#
# INTERPRETER WRITES (0.47.0). After a command naming python, node, php, ruby, perl, deno,
# bun, cp, mv, install or patch, also each file git reports changed or untracked since this
# hook's previous call in the run (the bash-write-effects block below), at most 8
# (MAX_BASH_EFFECTS), judged against the scope as an Edit of it is. In four sessions of the
# 2026-10-13 retro, 40-85% of code writes went through interpreter heredocs (python3 - <<'EOF'
# … open(p,'w')), which the parser cannot name. Such a path is worded apart from a named
# target: it changed since the previous tool call and may not be this command's write, so
# the warning sends the agent to `git diff` and never tells it to revert what it did not
# write. The marker is dated on every Edit, Write and Bash call of a registered run, so an
# Edit's file is not read again by the next Bash call; outside a run nothing is written. A
# marker older than active-run.json, or dated by another session, reads nothing.
# Everything under .claude/task-runner/ is the run's own state (active-run.json,
# gate-pass.json, the scope files) and is never checked — a run commonly writes those
# with `cat >`, and no card lists them.
#
# STATE ROOT (0.41.0). Scope files are read from the project root, not the payload cwd,
# which follows the model's `cd` (same review, finding 2): a run whose shell sat in
# app/Models looked for app/Models/.claude/task-runner/, found nothing, and was silently
# disarmed.
#
# COVERAGE: every LIVE scope file in the run's state dir — the inline path's scope.json AND
# the per-card scope-<cardId>.json files routing.md writes for delegated and tracked
# cards — read as ONE UNION. An edit outside the union warns; an edit any live card
# declared does not. Union, not per-file, because this hook cannot tell WHICH card an
# Edit belongs to: the payload carries a path, not a card id, and charging an edit
# against the wrong card's list would warn on correct work.
#
# LIVE means: active-run.json exists, and the scope file is not older than it. Measured
# (same review, finding 8): a finished run's scope-*.json files, left on disk, flagged the
# NEXT task's spec edit as scope creep — the union was read whether or not a run was live.
# A scope file from an earlier registration is now ignored, so re-registering a run
# retires every stale file without deleting it.
#
# WHAT IT STILL DOES NOT CATCH:
#   - A WORKER IN ANOTHER WORKTREE. A subagent's Edit fires in ITS session with ITS
#     cwd; a track worktree is a different tree with no active-run.json of its own, so
#     its edits arm nothing here. That path is enforced by the prose diff-vs-declared
#     check on return.
#   - Scope-file drift INSIDE a live run. A card whose scope file is never written is
#     unbounded here, and a finished card's scope-<cardId>.json written after this
#     registration still WIDENS the union — the union fails toward silence, which is the
#     right failure for an advisory tripwire and the wrong one for a gate. This is not a
#     gate. mtimes compare at whole seconds under macOS's bash 3.2, so a stale file
#     written in the same second as the registration counts as live.
#   - Bash writes neither the parser nor git can name: a path held in a variable, a target
#     past the eighth; after an interpreter run, a writer the effects block does not name
#     (make, git apply, npx prettier --write), a gitignored output, a repo with no git, a
#     file written then reverted, a mv or cp -p destination (it keeps the source's mtime),
#     files past the eighth, and every write of the first Bash call after a registration
#     (no marker newer than active-run.json) or of the first call of a session. A file that
#     does not exist after the call is skipped.
#   - Writes the command did not make: after an interpreter run, any file changed since this
#     hook's previous call in the session (an IDE save, a cache or test output git does not
#     ignore) warns, in the effects wording above. Every agent of a session in the tree
#     shares one marker per root, so a parallel worker's write can be reported to another
#     agent's call, or dated past by that call and missed by the worker that made it.
#   - Any malformed scope file — invalid JSON, or no `allow` array — disarms the whole
#     call, not just its own card: a partial union would warn about paths a card it could
#     not parse had actually allowed.
#   - A Write/Edit to an absolute path outside the project root: skipped on purpose, as a
#     Bash target there always was. The run's own card index under the root is not
#     exempt, so updating its status column still warns unless a card lists it.
#
# fd 3 = the caller's real stderr, saved before the block so the two fail-open
# warnings below (D7: missing jq / a malformed scope file) reach stderr — the block's
# `2>/dev/null` is there only to silence incidental jq/grep noise and would eat a
# plain `>&2` warning. (Honest limitation law: .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws".)
MAX_BASH_TARGETS=8
MAX_BASH_EFFECTS=8
exec 3>&2

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

# Shared block templates/blocks/plugin-state.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/plugin-state.md
# cc_plugin_state <root> <name> prints the plugin's own state dir for <root>, a cc_state_root result:
# CLAUDE_PLUGIN_DATA/<basename>-<cksum>/<name> if non-empty, else <root>/.claude/<name>. Status 0; creates nothing.
# The host keeps one data dir per plugin id, not per project (2.1.282); LC_ALL=C: a UTF-8 tr stops at an invalid byte.
# Misses: state another plugin, a skill or the user reads must not use it; an event lacking the variable uses the repo.
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

# Shared block templates/blocks/bash-write-effects.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-effects.md
# cc_bash_effects_mark <root> <marker> <session> rewrites <marker> to hold <session>'s cksum when <root> holds a .git, and gives its
# directory a `*` .gitignore when it has none. Call it on EVERY call the hook sees (Write, Edit, Bash, a failed Bash too), after
# cc_bash_write_effects read <marker>: the tool has finished when the hook runs, so <marker> then post-dates every write of that call.
# cc_bash_write_effects <root> <marker> <command> <max> <session> prints at most <max> absolute paths, one per line: files `git status`
# under <root> reports changed or untracked and newer than <marker> (a plugin state dir stays out by its `*` .gitignore). It runs git
# only when <command> holds python, node, php, ruby, perl (any version suffix or directory), nodejs, deno, bun, cp, mv, install or
# patch as a word, <marker> holds <session>'s cksum (another session's marker reads as none), <root> is not $HOME and
# status.showUntrackedFiles is not no. Misses: writers it does not name, gitignored files, submodules, no git, each session's first
# call, a file written then reverted, a mv or cp -p destination (it keeps the source's mtime), files past <max>. Reads too much: any
# change since <marker> — an IDE, a parallel agent, a job, a state file another tool keeps in a .claude/ dir git does not ignore.
cc_bash_effects_mark() {
  [ -e "$1/.git" ] || return 0
  local d="${2%/*}" k
  { [ -d "$d" ] || mkdir -p "$d"; } 2>/dev/null || return 0
  { [ -e "$d/.gitignore" ] || printf '*\n' > "$d/.gitignore"; k=$(printf '%s' "$3" | cksum) && printf '%s\n' "${k%% *}" > "$2"; } 2>/dev/null
  return 0
}
cc_bash_write_effects() {
  local LC_ALL=C re='(^|[;&|(`[:space:]])([^[:space:];&|()`<>]*/)?((python|php|ruby|perl|node)[0-9.]*|nodejs|deno|bun|cp|mv|install|patch)([[:space:];&|)`<>]|$)' k m f
  [ -f "$2" ] && [ "$1" != "${HOME%/}" ] && [[ $3 =~ $re ]] && IFS= read -r m < "$2" && k=$(printf '%s' "$5" | cksum) && [ "$m" = "${k%% *}" ] || return 0
  case "$(git -C "$1" config status.showUntrackedFiles 2>/dev/null)" in no|false|off|0) return 0 ;; esac
  # One find over the whole list, each path led by ./ so a name like -delete stays a path; the cap counts only what find kept.
  while IFS= read -r f; do printf '%s\n' "$1/${f#./}"; done < <(exec 2>/dev/null; cd -- "$1" && GIT_OPTIONAL_LOCKS=0 git status --porcelain -z \
    --untracked-files=all --no-renames --ignore-submodules=all | tr '\0' '\n' | sed -e 's|^...|./|' \
    | tr '\n' '\0' | xargs -0 sh -c 'exec find "$@" -prune -newer "$0" -type f -print' "$2" | head -n "$4")
  return 0
}

{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || { echo "task-runner scope-lock: jq not found — scope not enforced this call" >&3; exit 0; }
  # A failed Bash call fires PostToolUseFailure, whose envelope must name that event.
  # context-key-ok: session_id is the effects marker's content, per session by design — a session's subagents share one window.
  { IFS= read -r cwd; IFS= read -r sess; IFS= read -r hev; } < <(printf '%s' "$input" \
    | jq -r '.cwd // "", .session_id // "", if .hook_event_name == "PostToolUseFailure" then .hook_event_name else "PostToolUse" end' 2>/dev/null)
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0
  tr_dir="$root/.claude/task-runner"

  # STATE HYGIENE (0.34.4). .claude/task-runner/ is written by the run itself
  # (active-run.json, rv/, bg/, gate-pass.json) and by this plugin's scripts; none of
  # it belongs in a commit, and it showed up as untracked in every repo a run touched
  # (overseer's acceptance protocol names it as "other plugins' scratch"). A directory
  # can ignore itself, so the first hook to see it drops a `.gitignore` holding `*`.
  if [ -d "$tr_dir" ] && [ ! -e "$tr_dir/.gitignore" ]; then printf '*\n' > "$tr_dir/.gitignore" 2>/dev/null; fi

  # No registered run → every scope file on disk is a leftover (header, LIVE).
  sentinel="$tr_dir/active-run.json"
  [ -f "$sentinel" ] || exit 0
  scopes=()
  for s in "$tr_dir"/scope.json "$tr_dir"/scope-*.json; do
    [ -r "$s" ] || continue
    [ "$sentinel" -nt "$s" ] && continue
    scopes+=("$s")
  done
  # Effects are read against the marker the previous call of this run left, then the marker is
  # dated, on every call from here on. A marker older than active-run.json was dated before
  # this registration, so the window would span calls between runs: it reads nothing.
  effects_mark="$(cc_plugin_state "$root" task-runner)/bash-effects.mark"
  cmd=""; effects=""
  if [ "$tool" = "Bash" ] && [ "${#scopes[@]}" -gt 0 ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    [ -n "$cmd" ] && [ "$effects_mark" -nt "$sentinel" ] \
      && effects=$(cc_bash_write_effects "$root" "$effects_mark" "$cmd" "$MAX_BASH_EFFECTS" "$sess")
  fi
  # Dated on the way out: a failed call's named targets are read against the previous call's marker below.
  trap 'cc_bash_effects_mark "$root" "$effects_mark" "$sess"' EXIT
  [ "${#scopes[@]}" -gt 0 ] || exit 0
  for s in "${scopes[@]}"; do
    jq empty "$s" 2>/dev/null || { echo "task-runner scope-lock: $(basename "$s") is malformed — scope not enforced this call" >&3; exit 0; }
    # Valid JSON of the wrong shape is malformed too. Orchestrators wrote {card, allowed};
    # `.allow // []` read that as an empty list, and every edit of the run was "scope creep".
    jq -e '.allow | type == "array"' "$s" >/dev/null 2>&1 || { echo "task-runner scope-lock: $(basename "$s") has no \"allow\" array (expected {\"allow\":[\"path\",\"dir/\"],\"task\":\"<id>\"}) — scope not enforced this call" >&3; exit 0; }
  done

  # Written paths, repo-relative. The run's own state dir is never in a card's scope and
  # never checked (header, WHAT IT SEES).
  rels=()
  if [ "$tool" = "Bash" ]; then
    [ -n "$cmd" ] || exit 0
    # bash_rel <path> [marker]: keep a written path repo-relative when it is an existing regular file
    # under the root, outside the run's state, not older than [marker] and not kept already; status 1 otherwise.
    bash_rel() {
      local p d rel q
      # Relative targets resolve against the Bash call's cwd: that is where the shell
      # wrote them, which is the one place the payload cwd is the right anchor.
      case "$1" in /*) p="$1" ;; *) p="$cwd/$1" ;; esac
      [ -f "$p" ] || return 1
      [ -n "${2:-}" ] && [ "$2" -nt "$p" ] && return 1
      case "$p" in */./* | */../*)
        d=$(CDPATH= cd -- "${p%/*}" 2>/dev/null && pwd) || return 1
        p="$d/${p##*/}" ;;
      esac
      case "$p" in "$root"/*) rel="${p#"$root"/}" ;; *) return 1 ;; esac
      case "$rel" in .claude/task-runner/*) return 1 ;; esac
      for q in "${rels[@]}"; do [ "$q" = "$rel" ] && return 1; done
      rels+=("$rel")
    }
    # A failed command may have stopped before its redirect: a named target older than the previous
    # call's marker was not written, and with no marker to tell, a target takes the effects wording.
    old=""; [ "$hev" = PostToolUseFailure ] && [ "$effects_mark" -nt "$sentinel" ] && old="$effects_mark"
    n=0
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      bash_rel "$t" "$old" && n=$((n + 1))
      [ "$n" -ge "$MAX_BASH_TARGETS" ] && break
    done <<EOF
$(cc_bash_write_targets "$cmd")
EOF
    named=${#rels[@]}; [ "$hev" = PostToolUseFailure ] && [ -z "$old" ] && named=0
    while IFS= read -r t; do
      [ -n "$t" ] && bash_rel "$t"
    done <<EOF
$effects
EOF
  else
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
    [ -n "$file" ] || exit 0
    # Normalize the edited path to repo-relative for comparison. An absolute path outside
    # the root (/tmp, the user's memory dir) is no card's file and was told to "revert
    # this edit"; it is skipped, as the Bash branch already skips one.
    rel="$file"; case "$file" in "$root"/*) rel="${file#"$root"/}" ;; /*) exit 0 ;; esac
    case "$rel" in .claude/task-runner/*) exit 0 ;; esac
    rels+=("$rel")
  fi
  [ "${#rels[@]}" -gt 0 ] || exit 0

  task=$(jq -rs '[.[] | .task // empty] | unique | join(", ")' "${scopes[@]}" 2>/dev/null)
  [ -n "$task" ] || task="the current task"

  # Allowed if the edited path equals an allow entry, or sits under it as a
  # DIRECTORY. The boundary matters: a raw startswith made every entry a prefix of
  # unrelated siblings — "src/util.ts" admitted "src/util.tsx", "app/Models"
  # admitted "app/ModelsBackup/X.php" — so the lock leaked silently on the exact
  # near-miss paths a drifting edit produces.
  # -s slurps every scope file into one array, so `allow` is the UNION of all of them.
  warn=""; named=${named:-${#rels[@]}}; i=0
  for rel in "${rels[@]}"; do
    i=$((i + 1))
    allowed=$(jq -rs --arg f "$rel" \
      'if ((map(.allow // []) | add // []) | any(. as $a | $a == $f or ($f | startswith(if ($a | endswith("/")) then $a else $a + "/" end)))) then "y" else "n" end' \
      "${scopes[@]}" 2>/dev/null)
    [ "$allowed" = "n" ] || continue
    # Past the command's named targets, a path is only what changed since the previous call: who wrote it is unknown.
    if [ "$i" -gt "$named" ]; then
      line=$(printf '[task-runner] scope-lock: %s changed since the previous tool call and is NOT among the files %s declared. This command may not have written it — a parallel agent, an IDE or a job may have. Check `git diff -- %s`: if your command changed it, add it to the task definition or record it as a follow-up and undo your change; never revert a change you did not make.' "$rel" "$task" "$rel")
    else
      line=$(printf '[task-runner] scope-lock: %s was edited but is NOT among the files %s declared. If intentional, add it to the task definition; otherwise this is scope creep — record it as a follow-up and revert this edit.' "$rel" "$task")
    fi
    warn="${warn:+$warn
}$line"
  done
  [ -n "$warn" ] || exit 0
  # jq builds the envelope so the message stays valid JSON whatever $rel contains.
  # jq presence is guaranteed here by the guard at the top of the block.
  jq -cn --arg ctx "$warn" --arg ev "$hev" \
    '{hookSpecificOutput:{hookEventName:$ev,additionalContext:$ctx}}'
} 2>/dev/null
exit 0
