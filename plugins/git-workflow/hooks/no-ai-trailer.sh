#!/bin/bash
# no-ai-trailer.sh — PreToolUse: denies a git commit/merge/tag/notes/rebase/cherry-pick/am or gh pr/release/repo create/merge/edit/comment at a command position whose own words, heredoc or pipeline hold a `Co-Authored-By: Claude …` trailer or a "Generated with Claude Code" line (anywhere in the command once it reads a variable, a substitution or an -F file), and a Write/Edit planting one in a git message file. Off: CLAUDE_AI_TRAILER=allow for that one command — or for good, by a user who wants the trailer. Fails open. `--check '<command>'`: exit 0 allow, 2 deny.
# Misses: a message file written by an unmatched tool or an earlier call, `git config trailer.*` or prepare-commit-msg trailers, filter-repo rewrites, commits outside the session, `git -C <bare word>`. Denies on purpose, judging the whole command as before: one it cannot split (an unclosed quote or heredoc, `$((`), a heredoc fed to a shell, sudo or ssh; prose quoting a full trailer line; a `(` in quoted text before one.
# Why, limits, history: rationale/derivations/plugin-git-workflow.md § plugins/git-workflow/hooks/no-ai-trailer.sh

set -u

# LC_ALL=C matches the emoji as bytes; grep reads line by line, so `.*` never crosses a newline.
export LC_ALL=C
TRAILER_RE='co-authored-by:.*(claude|anthropic)|generated with \[?claude code|🤖 generated with'
# A path prefix must end in `/`; the option run between git and the verb takes dash, path-like and assignment tokens, never a bare word (`git log | grep commit` passes).
GIT_WRITE_RE='(^|[;&|`()]|\$\()[[:space:]]*(([a-z_][a-z0-9_]*=[^[:space:]]*|bash|sh|zsh|dash|ksh|eval|exec|command|sudo|doas|env|nohup|timeout|nice|time|xargs|then|do|else|elif|if|while|until|-[-a-z0-9]*|[0-9]+|"|'"'"')[[:space:]]*)*(([^[:space:]]*/)?git([[:space:]]+(-[^[:space:]]*|[/.~][^[:space:]]*|[^[:space:]]*=[^[:space:]]*))*[[:space:]]+(commit|merge|tag|notes|rebase|cherry-pick|am)|([^[:space:]]*/)?gh[[:space:]]+(pr|release|repo)[[:space:]]+(create|merge|edit|comment))([[:space:]]|$)'

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# A message read from a variable, a substitution or a file can carry text from anywhere in the command.
INDIRECT_RE='\$[a-z_{0-9@*#?!]|(^|[[:space:]])(-[a-z]*f|-t|--(body-|notes-)?file|--template)(=|[[:space:]]+)?([^[:space:]-][^[:space:]]*|-[^[:space:]]+)'

# segments <command>: one \036-ended record per command or pipeline outside quotes, substitutions and heredoc bodies: trailer flag, heredoc flag, the command without its heredoc bodies, lowercased. Exit 3: cannot split it.
segments() {
  printf '%s\n' "$1" | CC_TRAILER_RE="$TRAILER_RE" awk '
    function add(x) { H[ns] = H[ns] x; if (tolower(x) ~ tre) T[ns] = 1 }
    function cut(i, w) { add(substr(s, st, i - st)); st = i + w; ns++; H[ns] = ""; T[ns] = 0; D[ns] = 0 }
    { L[++n] = $0 }
    END {
      tre = ENVIRON["CC_TRAILER_RE"]; ns = 1; H[1] = ""; T[1] = 0; D[1] = 0; top = 0; F[0] = "p"; np = 0
      for (ln = 1; ln <= n; ln++) {
        s = L[ln]; len = length(s); st = 1; cont = 0
        for (i = 1; i <= len; i++) {
          c = substr(s, i, 1); f = F[top]; nx = substr(s, i + 1, 1)
          if (f == "q") { if (c == "\047") top--; continue }
          if (f == "a") { if (c == "\\") i++; else if (c == "\047") top--; continue }
          if (c == "\\") { if (i == len) cont = 1; i++; continue }
          if (f == "d") {
            if (c == "\"") top--; else if (c == "$" && nx == "(") { F[++top] = "p"; i++ } else if (c == "`") F[++top] = "b"
            continue
          }
          if (c == "#" && (i == 1 || substr(s, i - 1, 1) ~ /[ \t;&|()]/)) break
          if (c == "\047") F[++top] = "q"
          else if (c == "\"") F[++top] = "d"
          else if (c == "$" && nx == "\047") { F[++top] = "a"; i++ }
          else if (c == "`") { if (f == "b") top--; else F[++top] = "b" }
          else if (c == "$" && nx == "(") { F[++top] = "p"; i++ }
          else if (c == "(") { if (top > 0 || (i > 1 && substr(s, i - 1, 1) ~ /[<>=]/)) F[++top] = "p"; else cut(i, 1) }
          else if (c == ")") { if (top > 0 && f == "p") top--; else if (top == 0) cut(i, 1) }
          else if (c == "<" && nx == "<") {
            if (substr(s, i + 2, 1) == "<") { i += 2; continue }
            j = i + 2; tabs = 0; w = ""; q = ""
            if (substr(s, j, 1) == "-") { tabs = 1; j++ }
            while (substr(s, j, 1) ~ /[ \t]/) j++
            for (; j <= len; j++) {
              d = substr(s, j, 1)
              if (q != "") { if (d == q) q = ""; else w = w d; continue }
              if (d ~ /[ \t;&|()<>]/) break
              if (d == "\\") { j++; w = w substr(s, j, 1) } else if (d == "\047" || d == "\"") q = d; else w = w d
            }
            if (w == "" || q != "") exit 3
            PD[++np] = w; PT[np] = tabs; PS[np] = ns; D[ns] = 1; i = j - 1
          }
          else if (top > 0) continue
          else if (c == ";") cut(i, 1)
          else if (c == "&" && nx == "&") { cut(i, 2); i++ }
          else if (c == "&" && nx != ">" && (i == 1 || substr(s, i - 1, 1) !~ /[<>]/)) cut(i, 1)
          else if (c == "|" && nx == "|") { cut(i, 2); i++ }
        }
        add(substr(s, st))
        if (ln == n) break
        if (np > 0) {
          if (cont || (F[top] != "p" && F[top] != "b")) exit 3
          for (k = 1; k <= np; k++) {
            for (ok = 0; ++ln <= n;) {
              b = L[ln]; if (PT[k]) sub(/^\t+/, "", b)
              if (b == PD[k]) { ok = 1; break }
              if (tolower(L[ln]) ~ tre) T[PS[k]] = 1
            }
            if (!ok) exit 3
          }
          np = 0
          if (ln >= n) break
        }
        if (top == 0 && !cont) { ns++; H[ns] = ""; T[ns] = 0; D[ns] = 0 } else H[ns] = H[ns] "\n"
      }
      if (top != 0 || np > 0) exit 3
      for (k = 1; k <= ns; k++) {
        h = tolower(H[k])
        if (D[k] && h ~ /(^|[ \t;&|(`\/])(ba|z|da|k|c|tc|a|rba|mk)?sh([ \t]|$)|(^|[ \t;&|(`])(ssh|su|sudo|doas|exec|eval|source|xargs|runuser|chroot|\.)([ \t]|$)/) exit 3
        if (index(h, "git") || index(h, "gh")) printf "%d\037%d\037%s\036", T[k], D[k], h
      }
    }'
}

# 0 = clean, 1 = trailer present in a git-writing command
classify_command() {
  local c segs t d h
  c=$(lc "$1")
  printf '%s' "$c" | grep -qE "$TRAILER_RE" || return 0
  if ! segs=$(segments "$1"); then
    # Keep the quote tokens in GIT_WRITE_RE's prefix: dropping them opens `bash -c "git commit …"` and `eval` as bypasses and leaves the `(` false deny.
    printf '%s' "$c" | tr '\n' ';' | grep -qE "$GIT_WRITE_RE" || return 0
    return 1
  fi
  while IFS=$'\037' read -r -d $'\036' t d h; do
    printf '%s' "$h" | tr '\n' ';' | grep -qE "$GIT_WRITE_RE" || continue
    [ "$t" = 1 ] && return 1
    printf '%s' "$h" | grep -qE "$INDIRECT_RE" && return 1
    if [ "$d" != 1 ] && printf '%s' "$h" | grep -qE '\$\(|`'; then return 1; fi
  done <<<"$segs"
  return 0
}

# 0 = clean, 1 = trailer written into a git message file
classify_file() { # path content
  local p; p=$(lc "$1")
  case "$p" in
    */.git/*|*/commit_editmsg|*/merge_msg|*/squash_msg|*/tag_editmsg|*/pullreq_editmsg|commit_editmsg|merge_msg) ;;
    *) return 0 ;;
  esac
  lc "$2" | grep -qE "$TRAILER_RE" || return 0
  return 1
}

reason() {
  printf '%s' 'git-workflow blocked AI attribution in this commit, merge, tag or PR: remove the "Co-Authored-By: Claude …" trailer and any "Generated with Claude Code" line, then run the same command again (not through a message file). CLAUDE_AI_TRAILER=allow, set by the user, turns this guard off.'
}

emit_deny() {
  jq -cn --arg r "$(reason)" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
}

if [ "${1:-}" = "--check" ]; then
  if classify_command "${2:-}"; then printf 'ALLOW\n'; exit 0; fi
  printf 'DENY  %s\n' "$(reason)"; exit 2
fi

main() {
  command -v jq >/dev/null 2>&1 || exit 0
  [ "$(lc "${CLAUDE_AI_TRAILER:-}")" = "allow" ] && exit 0
  local input tool cmd path content
  input=$(cat 2>/dev/null) || exit 0
  [ -n "$input" ] || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit)
      path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
      [ -n "$path" ] || exit 0
      content=$(printf '%s' "$input" | jq -r '
        [ .tool_input.content // empty,
          .tool_input.new_string // empty,
          ((.tool_input.edits // []) | map(.new_string // empty) | join("\n")) ]
        | map(select(. != "")) | join("\n")' 2>/dev/null) || exit 0
      classify_file "$path" "$content" && exit 0
      emit_deny; exit 0 ;;
    *)
      cmd=$(printf '%s' "$input" | jq -r '
        [ .tool_input.command // empty,
          .tool_input.script // empty,
          .tool_input.cmd // empty ] | map(select(. != "")) | join(" ; ")' 2>/dev/null) || exit 0
      [ -n "$cmd" ] || exit 0
      classify_command "$cmd" && exit 0
      emit_deny; exit 0 ;;
  esac
}

main
exit 0
