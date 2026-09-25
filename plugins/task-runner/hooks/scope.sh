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
# Fail-open.
#
# WHAT IT SEES (0.41.0). Edit/Write/MultiEdit through `.tool_input.file_path`, AND Bash:
# the files a command writes by `>`/`>>`, heredoc, `tee` or `sed -i`/`perl -i`, parsed by
# cc_bash_write_targets below, resolved against the Bash call's cwd, kept only when they
# are existing regular files under the project root, at most 8 per call. Measured
# 2026-09-25 (rationale/2026-09-25-session-plugin-usage-review.md, finding 1): with the
# host's `bashFirst` auto mode, 233 of 238 main-thread writes in one session were
# `cat > file`, so an Edit/Write-only tripwire was blind on the default write path.
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
#   - Bash writes the parser cannot name: interpreter writes (python open(), php
#     file_put_contents), cp/mv/install destinations, a path held in a variable, and any
#     target past the eighth. A file that does not exist after the call is skipped.
#   - Any malformed scope file disarms the whole call, not just its own card: a partial
#     union would warn about paths a card it could not parse had actually allowed.
#
# fd 3 = the caller's real stderr, saved before the block so the two fail-open
# warnings below (D7: missing jq / a malformed scope file) reach stderr — the block's
# `2>/dev/null` is there only to silence incidental jq/grep noise and would eat a
# plain `>&2` warning. (Honest limitation law: .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws".)
exec 3>&2

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
# `[sudo] tee [-a] <paths>`, and the last operand of `sed -i` / `perl -i`. Does NOT catch:
# interpreter writes (python open(), php file_put_contents), cp/mv/install destinations,
# `{ …; } > f` groups, a path held in a variable (`> "$f"` is skipped, never guessed).
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
    function segment(ms, os,   rest, off, tok, w, k, j, st, en, word, n, ws, we, last) {
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
      } else if ((word == "sed" || word == "perl") && ms ~ /[ \t]-[a-zA-Z0-9]*i/) {
        last = substr(os, ws[n], we[n] - ws[n] + 1)
        if (n > 2 && last !~ /^-/ && substr(ms, ws[n], 1) !~ /["\047]/) emit(last)
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

{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || { echo "task-runner scope-lock: jq not found — scope not enforced this call" >&3; exit 0; }
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
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
  [ "${#scopes[@]}" -gt 0 ] || exit 0
  for s in "${scopes[@]}"; do
    jq empty "$s" 2>/dev/null || { echo "task-runner scope-lock: $(basename "$s") is malformed — scope not enforced this call" >&3; exit 0; }
  done

  # Written paths, repo-relative. The run's own state dir is never in a card's scope and
  # never checked (header, WHAT IT SEES).
  rels=()
  if [ "$tool" = "Bash" ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$cmd" ] || exit 0
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      # Relative targets resolve against the Bash call's cwd: that is where the shell
      # wrote them, which is the one place the payload cwd is the right anchor.
      case "$t" in /*) p="$t" ;; *) p="$cwd/$t" ;; esac
      [ -f "$p" ] || continue
      case "$p" in */./* | */../*)
        d=$(CDPATH= cd -- "${p%/*}" 2>/dev/null && pwd) || continue
        p="$d/${p##*/}" ;;
      esac
      case "$p" in "$root"/*) rel="${p#"$root"/}" ;; *) continue ;; esac
      case "$rel" in .claude/task-runner/*) continue ;; esac
      rels+=("$rel")
      [ "${#rels[@]}" -ge 8 ] && break
    done <<EOF
$(cc_bash_write_targets "$cmd")
EOF
  else
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
    [ -n "$file" ] || exit 0
    # Normalize the edited path to repo-relative for comparison.
    rel="$file"; case "$file" in "$root"/*) rel="${file#"$root"/}" ;; esac
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
  warn=""
  for rel in "${rels[@]}"; do
    allowed=$(jq -rs --arg f "$rel" \
      'if ((map(.allow // []) | add // []) | any(. as $a | $a == $f or ($f | startswith(if ($a | endswith("/")) then $a else $a + "/" end)))) then "y" else "n" end' \
      "${scopes[@]}" 2>/dev/null)
    [ "$allowed" = "n" ] || continue
    line=$(printf '[task-runner] scope-lock: %s was edited but is NOT among the files %s declared. If intentional, add it to the task definition; otherwise this is scope creep — record it as a follow-up and revert this edit.' "$rel" "$task")
    warn="${warn:+$warn
}$line"
  done
  [ -n "$warn" ] || exit 0
  # jq builds the envelope so the message stays valid JSON whatever $rel contains.
  # jq presence is guaranteed here by the guard at the top of the block.
  jq -cn --arg ctx "$warn" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
} 2>/dev/null
exit 0
