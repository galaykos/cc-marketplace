#!/bin/bash
# UserPromptSubmit: on any prompt but a harness frame, prints once each the low-confidence signals route.sh queued for this context; then, on the session's first work-shaped prompt no ScheduleWakeup or CronCreate call scheduled, the rules for judging the host's command listing. It picks no command; fails open.
# Misses a symptom without a state verb; fires on a chat sentence carrying one, or a ?-ended one naming a making verb; waits out a ?-ended symptom with no making verb or request form; repeats a signal whose state file cannot be rewritten. Off: CC_REMIND=off or CC_ROUTE=off; unset, /config.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/hooks/route-prompt.sh
MARKER_TTL_MIN=1440

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
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "") exit 0 ;; esac

  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  case "$(cc_option CC_ROUTE on)" in off) exit 0 ;; esac

  # A harness frame (the shared prompt-shape list) is not a human turn: skipped here, the flush waits for the next human prompt; a frame the list does not name still flushes.
  cc_prompt_frame "$prompt" && exit 0

  # Key and root as route.sh spells them (`.transcript_path // .session_id`, hashed; cc_state_root): any other spelling misses its file.
  sid_f=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  cwd_f=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  ctx_f=$(printf '%s' "$sid_f" | cksum 2>/dev/null | cut -d' ' -f1)
  root_f=""
  [ -n "$cwd_f" ] && root_f=$(cc_state_root "$cwd_f")
  state_f=""
  [ -n "$root_f" ] && [ -n "$ctx_f" ] && state_f="$(cc_plugin_state "$root_f" skill-router)/fired-$ctx_f.json"
  if [ -n "$sid_f" ] && [ -n "$state_f" ] && [ -r "$state_f" ]; then
    digest=$(jq -r '
      [ (.pending_low // [])[] | select(.flushed != true) ]
      | group_by(.skill)
      | map((if .[0].plugin then .[0].plugin + ":" else "" end) + .[0].skill + " (" + ([.[].file | split("/") | last] | unique | join(", ")) + ")")
      | join("; ")
    ' "$state_f" 2>/dev/null)
    if [ -n "$digest" ]; then
      printf '[skill-router] Your recent edits may need these skills: %s. Load each one that applies, or say in one line why it does not.\n' "$digest"
      upd=$(jq '(.pending_low // []) |= map(.flushed = true)' "$state_f" 2>/dev/null) \
        && [ -n "$upd" ] && printf '%s\n' "$upd" > "$state_f" 2>/dev/null
    fi
  fi

  # Slash commands manage their own flow — but only AFTER the flush above ran.
  case "$prompt" in "/"*) exit 0 ;; esac

  # A paste is reference, its verbs not the ask; with nothing typed beside it, the paste is the ask, read whole.
  scrub=$(printf '%s' "$prompt" | cc_prompt_unpaste)
  case "$scrub" in *[![:space:]]*) ;; *) scrub=$prompt ;; esac
  scrub=$(printf '%s' "$scrub" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-400)
  printf '%s' "$head" | grep -qiE 'hook (success|feedback|output)|task-notification|SYSTEM NOTIFICATION|UserPromptSubmit' && exit 0
  printf '%s' "$head" | grep -qiE '(delete|remove|uninstall|disable|install|list|which|audit|fix|update|change|write|rewrite|edit)[a-z -]{0,40}(plugin|hook|reminder|router|route|trigger|catalog)' && exit 0
  printf '%s' "$head" | grep -qF '[skill-router]' && exit 0

  # A question or a hands-off ask is not a work request; one asking for strong-tier work outside the hands-off clause, or a request form (`can you…?`), is.
  strong='build|create|make|add|implement|develop|write|rewrite|refactor|migrate|port|fix|debug|review|audit|design|redesign|restyle|theme|style|test|deploy|ship|optimi[sz]e|speed up|scaffold|set ?up|plan|spec|integrate|automate|investigate|500s?|regress(ed|ion)?|not working'
  cc_prompt_question "$scrub" "\b($strong)\b" && exit 0
  # One grep, three tiers: validate.sh allows four prompt greps here, so a new tier is an alternation in it, never a fifth line.
  # A weak symptom (down, slow, broken…) or error/crash counts only after a state or weak-tier verb, or error opening a sentence: bare, they match `scroll down` and `that error message in the log`.
  printf '%s' "$head" | grep -qiE "\b($strong|why is)\b|\b(is|are|was|were|been|went|going|get(s|ting)?|got|keeps?|kept|still|now|seems?|looks?|am|an|with|see(s|ing)?|saw|throw(s|ing|n)?|threw)\b[[:space:]]+([a-z]+[[:space:]]+)?\b(down|slow(er)?|broken|failing|fails|leak(s|ing)?|stuck|crash(es|ed|ing)?|errors?)\b|(^|[.!?;:][[:space:]]+)errors?\b" || exit 0

  # Raw session_id, not route.sh's context key: UserPromptSubmit never fires in a subagent, so no second context shares this marker.
  sid=$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)
  seen="${TMPDIR:-/tmp}/cc-route-catalog-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
  [ -e "$seen" ] && exit 0
  # A /loop or ScheduleWakeup re-fire is answered like the slash command that set it; the payload does not mark it, so cc_prompt_scheduled reads the transcript, only once the check would otherwise speak.
  cc_prompt_scheduled "$prompt" "$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)" && exit 0
  # mkdir failed: anything at the path (fired, or a squatting file) suppresses; a vacant path means TMPDIR is unwritable, so deliver.
  if ! mkdir "$seen" 2>/dev/null; then
    [ -e "$seen" ] && exit 0
  fi
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-route-catalog-*' -type d -mmin +"$MARKER_TTL_MIN" -exec rmdir {} + 2>/dev/null

  printf '%s\n' '[skill-router] If the user named a tool and a listed command fits the ask better, ask once which to use. If none was named and one clearly fits, name it in one line after any open questions; otherwise say nothing about commands. In a run that decides for you (`goal`, `goal-lean`, `ultra-goal`, or `Goal: true` in the card index), pick the better fit, say so, and add it to the run'\''s decision log.'
} 2>/dev/null
exit 0
