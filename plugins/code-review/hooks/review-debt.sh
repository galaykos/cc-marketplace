#!/bin/bash
# UserPromptSubmit, advisory: one line when 8+ files or an auth path changed since this context's last review (a ship prompt: at once, untracked included); a review Agent/Task/Skill call (PostToolUse) moves the base.
# Misses: uncommitted work until a commit or ship verb; reviews by other names; a rebase or branch switch resets the count; silent while .claude/task-runner/active-run.json exists, a crashed run's stale one too. Off: CC_REMIND, CC_REVIEW_NUDGE.
# Why, limits, history: rationale/derivations/plugin-code-review.md § plugins/code-review/hooks/review-debt.sh

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

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
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

# Shared block templates/blocks/prompt-shape.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/prompt-shape.md
# Prompt-shape tests for a UserPromptSubmit hook; each reads only its arguments (cc_prompt_unpaste, cc_prompt_auth_surface: stdin;
#   cc_prompt_scheduled: the file it names) and writes nothing.
# cc_prompt_frame <prompt>: status 0 when <prompt> opens as a harness frame or a host /loop tick, or a line opens with the hand-back marker.
# cc_prompt_scheduled <prompt> <transcript>: status 0 when <transcript> holds a ScheduleWakeup or CronCreate call whose prompt is
#   <prompt> exactly: a timer re-delivering an earlier ask, which the hook payload does not mark. Needs jq.
# cc_prompt_auth_surface: filter for paths; prints each stdin line naming an auth, secret, payment or migration surface (not `author`;
#   sign-up only as a word or a camelCase part, so not DesignUpdates).
# cc_prompt_auth_ask <text>: status 0 when <text> names an auth, account, invite, secret or payment surface as a word, camelCase split;
#   no bare session, token, guard or crypt (design tokens, a session retro, a guard clause).
# cc_prompt_unpaste: filter; cuts each <pasted_content …>…</pasted_content …> span, keeps text beside a tag, drops lines it emptied;
#   an opening tag with no closing tag after it cuts only itself.
# cc_prompt_ship_only <text> <verb-ERE>: status 0 when every <verb-ERE> match is create, add, open or make governing a PR, pull request
#   or commit, or a branch, push, merge, tag or release once a PR, commit, `git` or a name beside the noun marks the text as git work;
#   a hyphen-, slash-, dot- or underscore-joined name (fix-login, feature/add-auth) is one word, holds no verb, may follow the noun.
# cc_prompt_question <text> <verb-ERE>: status 0 when <text> ends in `?` and holds no <verb-ERE> match and no request (can/could
#   you|someone, please, why, any idea), or holds a hands-off ask (don't work on it, don't change anything yet) and, outside it, no match
#   opening a clause or following to, please, a modal or a conjunction (`the deploy` is a noun, `then deploy` an ask).
cc_prompt_frame() {
  case "${1:-}" in
    '<system-reminder>'*|'<task-notification'*|'[SYSTEM NOTIFICATION'*|'Stop hook feedback:'*) return 0 ;;
    'Another Claude session sent a message:'*|'<agent-message'*) return 0 ;;
    '# Autonomous loop check'*|'# Autonomous loop tick'*|'# /loop tick'*) return 0 ;;
    *'[Subagent hand-back]'*) printf '%s\n' "$1" | grep -qE '^[*_[:space:]]*\[Subagent hand-back\]' ;;
    *) return 1 ;;
  esac
}
cc_prompt_scheduled() {
  local n
  [ -n "${1:-}" ] && [ -f "${2:-}" ] || return 1
  n=$(printf '%s' "$1" | jq -Rs . 2>/dev/null) && [ -n "$n" ] || return 1
  grep -F -- "\"prompt\":$n" "$2" 2>/dev/null | grep -qE '"name":"(ScheduleWakeup|CronCreate)"'
}
cc_prompt_auth_surface() {
  LC_ALL=C awk '{ l = " " tolower($0) " " } l ~ /auth[^o]|authori[sz]|login|passw|token|secret|credential|polic|permission|role|guard|middleware|impersonat|session|oauth|webhook|payment|crypt|registration|[^a-z]sign[-_ ]?up|[ \/]migrations\// || /Sign[-_]?[Uu]p/'
}
cc_prompt_auth_ask() {
  printf '%s\n' "${1:-}" | sed -E 's/([a-z])([A-Z])/\1 \2/g' | grep -qiE "(^|[^a-z])((un|re|o)?auth(ori[sz]|[^o]|$)|log[- ]?(in|out)|logged[- ]?(in|out)|sign(ed)?[-_ ]?(in|up|out)s?([^a-z]|$)|pass(w|key)|secrets?([^a-z]|$)|credential|polic|permission|roles?([^a-z]|$)|middleware|impersonat|webhook|payment|(en|de|b)crypt|cryptograph|registration|accounts?([^a-z]|$)|invit(e|ation)|(api|access|refresh|bearer|reset)[-_ ]?(tokens?|keys?)|session[-_ ]?(cookie|token|id|fixation|hijack)|(2fa|mfa|two[- ]factor|sso|saml|jwts?|[cx]srf)([^a-z]|$))|(^|/)migrations/"
}
cc_prompt_unpaste() {
  awk '{ a[NR] = $0; if (index($0, "</pasted_content")) z = NR }
    END { for (n = 1; n <= NR; n++) { out = ""; line = a[n]; cut = p
      while (1) {
        if (p) { j = index(line, "</pasted_content"); if (!j) break
                 line = substr(line, j); k = index(line, ">"); line = k ? substr(line, k + 1) : ""; p = 0 }
        else { i = index(line, "<pasted_content"); if (!i) { out = out line; break }
               out = out substr(line, 1, i - 1) " "; line = substr(line, i); cut = 1
               if (n < z + 0 || index(line, "</pasted_content")) p = 1
               else { k = index(line, ">"); if (!k) { out = out line; break }; line = substr(line, k + 1) } } }
      if (!cut || out ~ /[^[:space:]]/) print out } }'
}
cc_prompt_ship_only() {
  local t v s n
  [ -n "${2:-}" ] || return 1
  t=$(printf '%s' "${1:-}" | tr '\n' ' ' | sed -E 's#[[:alnum:]]+([-/_.][[:alnum:]]+)+#x#g; s/ +([Aa]nd|[Tt]hen|&) +/ ; /g')
  v=$(printf '%s' "$t" | grep -oiE "($2)" | grep -c .)
  n='prs?|pull[ -]requests?|commits?'
  printf '%s' "$t" | grep -qiE "(^|[^a-z])($n|git|(x|feature|hotfix|release) +(branch(es)?|tags?|releases?))([^a-z]|$)|(^|[^a-z])(branch(es)?|tags?|releases?) +x([^a-z]|$)" \
    && n="$n|branch(es)?|push(es)?|merges?|tags?|releases?"
  s=$(printf '%s' "$t" | grep -oiE "($2)( +(a|an|the|new|draft|this|that|my|our|feature|hotfix|release|git|remote|local|separate|fresh))*( +[^ .,;:!?]+)? +($n)( +x)?( *([.,;:!?]|$)| +(for|from|off|against|called|named)([^a-z]|$))" \
    | grep -ciE '^(create|add|open|make)([^a-z]|$)')
  [ "${v:-0}" -gt 0 ] && [ "${s:-0}" -ge "$v" ]
}
cc_prompt_question() {
  local t h
  [ -n "${2:-}" ] || return 1
  t=$(printf '%s' "${1:-}" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
  case "$t" in *'?') printf '%s' "$t" | grep -qiE "($2)|(^|[^a-z])((can|could|would|will) +(you|u|we|someone|anyone)|please|why|any +ideas?)([^a-z]|$)" || return 0 ;; esac
  h="(^|[^a-z])(don't|don’t|dont|do not|never)( +start)? +work(ing)? on +(anything|it|this|that)( *[.,;:!?]| +(yet|for now|until|before)([^a-z]|$)| *$)|(^|[^a-z])(don't|don’t|dont|do not) +(touch|change|edit|modify|build|code|write|fix|make|implement) +anything +(yet|for now|until|before)([^a-z]|$)|^[[:space:]]*(please,? +)?(don't|don’t|dont|do not) +(touch|change|edit|modify|build|code|write|fix|make|implement) +anything[[:space:][:punct:]]*$"
  printf '%s' "$t" | grep -qiE "$h" || return 1
  ! printf '%s' "$t" | tr 'A-Z' 'a-z' | sed -E "s#$h# ; #g" \
    | grep -qiE "(^|[.,;:!?]|(^|[^a-z])(and|but|then|so|also|first|just|now|please|to|should|must|can|could|will|would|let'?s))[^a-z0-9]*($2)"
}

{
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v git >/dev/null 2>&1 || exit 0
  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  case "$(cc_option CC_REVIEW_NUDGE on)" in off) exit 0 ;; esac

  input=$(cat)
  # The event is inferred from the payload's shape when absent, so one missing field cannot disable both halves.
  event=$(printf '%s' "$input" | jq -r '.hook_event_name
    // (if .tool_name then "PostToolUse" elif has("prompt") then "UserPromptSubmit" else empty end)' 2>/dev/null) || exit 0

  # Is this a review? Decided before any git call: almost every Agent and Skill call is not.
  reviewed=0; ship=0
  case "$event" in
    PostToolUse)
      tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
      case "$tool" in
        Agent|Task)
          who=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
          case "$who" in *reviewer|security:*|code-review:*) ;; *) exit 0 ;; esac ;;
        Skill)
          who=$(printf '%s' "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null)
          case "${who#/}" in code-review:review|security:review|code-review|security-review) ;; *) exit 0 ;; esac ;;
        *) exit 0 ;;
      esac
      reviewed=1 ;;
    UserPromptSubmit)
      prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
      case "$prompt" in
        /code-review:review|"/code-review:review "*|/security:review|"/security:review "*) reviewed=1 ;;
        /code-review|"/code-review "*|/security-review|"/security-review "*) reviewed=1 ;;
        # A harness frame quoting "commit" or "merge" is not the user asking to ship: the shared prompt-shape block's list.
        *) cc_prompt_frame "$prompt" \
             || { printf '%s' "$prompt" | awk '/^[[:space:]]*```/{f=!f; next} !f' | tr '\n' ' ' | cut -c1-400 \
             | grep -qiE '(^|[^[:alnum:]_./-])/?(commit|push|merge|pr|pull[ -]request)([^[:alnum:]_/-]|$)' && ship=1; } ;;
      esac ;;
    *) exit 0 ;;
  esac

  tp=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$tp" ] || exit 0
  # A subagent's own dispatches belong to a context no prompt ever reads back.
  case "$tp" in */subagents/*) exit 0 ;; esac
  ctx=$(printf '%s' "$tp" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0
  export GIT_OPTIONAL_LOCKS=0
  # Not a work tree, or no commit yet: nothing to diff, and no state is written.
  head=$(git -C "$root" rev-parse --verify -q HEAD 2>/dev/null) || exit 0
  [ -n "$head" ] || exit 0
  branch=$(git -C "$root" symbolic-ref -q --short HEAD 2>/dev/null) || branch=-   # detached: -

  dir=$(cc_plugin_state "$root" code-review)
  base_f="$dir/review-base-$ctx"
  seen_f="$dir/review-seen-$ctx"
  # base_f: "<base commit> <branch>"; seen_f: "<last HEAD judged> <count that last fired> <count the last ship line named>".
  record() {
    mkdir -p "$dir" 2>/dev/null || exit 0
    [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null   # the state dir ignores itself
    printf '%s %s\n' "$1" "$branch" > "$base_f" 2>/dev/null
    printf '%s 0 0\n' "$1" > "$seen_f" 2>/dev/null
    find "$dir" -maxdepth 1 -name 'review-*' -type f -mtime +14 -exec rm -f {} + 2>/dev/null
  }

  [ "$reviewed" = 1 ] && { record "$head"; exit 0; }
  [ -e "$root/.claude/task-runner/active-run.json" ] && { record "$head"; exit 0; }

  base=""; bbranch=""; seen_head=""; fired=0; shipped=0
  [ -r "$base_f" ] && read -r base bbranch _ < "$base_f"
  [ -n "$base" ] || { record "$head"; exit 0; }               # first prompt: baseline, silent
  if [ -z "$bbranch" ]; then
    printf '%s %s\n' "$base" "$branch" > "$base_f" 2>/dev/null  # recorded before 0.33.0: adopt
  elif [ "$bbranch" != "$branch" ]; then
    # Searched back only to the old base's own entry: an older checkout predates the base and would charge history.
    sw=$(git -C "$root" reflog -n 200 --format='%H %gs' 2>/dev/null \
      | awk -v b="$base" '$2 == "checkout:" { print $1; exit } $1 == b { exit }')
    { [ -n "$sw" ] && git -C "$root" merge-base --is-ancestor "$sw" "$head" 2>/dev/null; } || sw=$head
    record "$sw"; base=$sw
  fi
  [ -r "$seen_f" ] && read -r seen_head fired shipped _ < "$seen_f"
  [ "$ship" = 1 ] || [ "$seen_head" != "$head" ] || exit 0    # this HEAD is already judged
  case "$fired" in ''|*[!0-9]*) fired=0 ;; esac
  case "$shipped" in ''|*[!0-9]*) shipped=0 ;; esac

  # A base off HEAD's history (rebase, amend) would diff across histories.
  git -C "$root" merge-base --is-ancestor "$base" "$head" 2>/dev/null || { record "$head"; exit 0; }

  changed=$( { git -C "$root" -c core.quotepath=off diff --name-only "$base" -- 2>/dev/null
               [ "$ship" = 1 ] && git -C "$root" -c core.quotepath=off ls-files --others --exclude-standard 2>/dev/null; } \
    | grep -vE '\.md$|(^|/)\.claude/|(^|/)taskmaster-docs/|(^|/)(node_modules|vendor|dist|build|\.next|coverage|generated|__generated__)/' \
    | grep -vE '(^|/)(package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|composer\.lock|Gemfile\.lock|Cargo\.lock|poetry\.lock|Pipfile\.lock|uv\.lock|go\.sum|bun\.lockb?|mix\.lock|flake\.lock)$')
  count=$(printf '%s\n' "$changed" | grep -c .)
  # `auth` but not `author`; the words are the prompt-shape block's cc_prompt_auth_surface.
  auth=$(printf '%s\n' "$changed" | cc_prompt_auth_surface)
  nauth=$(printf '%s\n' "$auth" | grep -c .)

  # A ship line answers to the last ship line and raises the plain count, so the next commit stays quiet.
  [ "$ship" = 1 ] && last=$shipped || last=$fired
  if { [ "$count" -ge 8 ] || [ "$nauth" -ge 1 ]; } && [ "$count" -gt "$last" ]; then
    if [ "$ship" = 1 ]; then shipped=$count; [ "$count" -gt "$fired" ] && fired=$count; else fired=$count; fi
    printf '%s %s %s\n' "$head" "$fired" "$shipped" > "$seen_f" 2>/dev/null || exit 0
  else
    printf '%s %s %s\n' "$head" "$fired" "$shipped" > "$seen_f" 2>/dev/null
    exit 0
  fi

  short=$(git -C "$root" rev-parse --short "$base" 2>/dev/null) || short="$base"
  paths=""
  if [ "$nauth" -ge 1 ]; then
    paths=$(printf '%s\n' "$auth" | head -3 | paste -sd, - | sed 's/,/, /g')
    [ "$nauth" -gt 3 ] && paths="$paths, +$((nauth - 3)) more"
    paths=" (touches auth: $paths)"
  fi
  [ "$count" -eq 1 ] && noun="file has" || noun="files have"
  tail="(CC_REVIEW_NUDGE=off turns this reminder off)."
  if [ "$ship" = 1 ]; then
    msg="[code-review] Before this ships: $count changed $noun had no review in this session since $short, uncommitted and untracked files included$paths. Run /code-review:review $short now or say in one line why not $tail"
  else
    msg="[code-review] $count changed $noun had no review in this session since $short$paths. Run /code-review:review $short..HEAD or say in one line why not $tail"
  fi

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$m}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
