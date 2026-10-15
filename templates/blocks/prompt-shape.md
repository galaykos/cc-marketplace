# Shared block templates/blocks/prompt-shape.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/prompt-shape.md
# Prompt-shape tests for a UserPromptSubmit hook; each reads only its arguments (cc_prompt_unpaste: stdin) and writes nothing.
# cc_prompt_frame <prompt>: status 0 when <prompt> opens as a harness frame or a line opens with the hand-back marker — not a human turn.
# cc_prompt_unpaste: filter; cuts each <pasted_content …>…</pasted_content …> span, keeps text beside a tag, drops lines it emptied;
#   an opening tag with no closing tag after it cuts only itself.
# cc_prompt_ship_only <text> <verb-ERE>: status 0 when every <verb-ERE> match is create, add, open or make governing a PR, pull request
#   or commit, or a branch, push, merge, tag or release once a PR, commit, `git` or a name beside the noun marks the text as git work;
#   a hyphen-, slash-, dot- or underscore-joined name (fix-login, feature/add-auth) is one word, holds no verb, may follow the noun.
# cc_prompt_question <text> <verb-ERE>: status 0 when <text> ends in `?` and holds no <verb-ERE> match and no request (can/could
#   you|someone, please, why, any idea), or holds a hands-off ask (don't work on it, don't change anything yet) and no match beside it.
cc_prompt_frame() {
  case "${1:-}" in
    '<system-reminder>'*|'<task-notification'*|'[SYSTEM NOTIFICATION'*|'Stop hook feedback:'*) return 0 ;;
    'Another Claude session sent a message:'*|'<agent-message'*) return 0 ;;
    *'[Subagent hand-back]'*) printf '%s\n' "$1" | grep -qE '^[*_[:space:]]*\[Subagent hand-back\]' ;;
    *) return 1 ;;
  esac
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
  ! printf '%s' "$t" | tr 'A-Z' 'a-z' | sed -E "s#$h# ; #g" | grep -qiE "$2"
}
