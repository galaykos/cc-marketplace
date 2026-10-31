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
