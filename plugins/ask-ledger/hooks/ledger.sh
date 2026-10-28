#!/bin/bash
# ledger.sh — UserPromptSubmit: on a work-shaped prompt, ledgers the names it introduces (quoted 1-3 word terms, mid-clause proper nouns, digit-letter tokens) that the repo's tracked tree lacks, deduped, 12 at most, for gate.sh; says what the gate will ask. Off: CC_ASK_LEDGER=off (unset: /config option cc_ask_ledger). Fails open.
# Misses: lowercase features, names in code spans or pastes, a name the ask adds to one the repo has; ledgers passing mentions; no filter outside a git work tree, for untracked-only names, or past 24 greps.
# Why, limits, history: rationale/derivations/plugin-ask-ledger.md § plugins/ask-ledger/hooks/ledger.sh

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

# Shared block templates/blocks/prompt-shape.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/prompt-shape.md
# Prompt-shape tests for a UserPromptSubmit hook; each reads only its arguments (cc_prompt_unpaste, cc_prompt_auth_surface: stdin;
#   cc_prompt_scheduled: the file it names) and writes nothing.
# cc_prompt_frame <prompt>: status 0 when <prompt> opens as a harness frame or a host /loop tick, or a line opens with the hand-back
#   marker — not a human turn.
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
  command -v jq >/dev/null 2>&1 || exit 0
  [ "$(cc_option CC_ASK_LEDGER on)" = "off" ] && exit 0
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  [ -n "$prompt" ] || exit 0
  case "$prompt" in /*) exit 0 ;; esac
  # Anchored at the start: an ask that merely quotes a frame marker mid-sentence is still an ask.
  cc_prompt_frame "$prompt" && exit 0

  scrub=$(printf '%s' "$prompt" | cc_prompt_unpaste \
    | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-600 | tr 'A-Z' 'a-z')
  verbs='\b(build|create|add|implement|develop|rewrite|refactor|fix|update|change|write|make|ship|redo|replace)\b'
  clauses=$(printf '%s' "$head" | awk '{gsub(/\?/," __Q__\n"); gsub(/\. /,"\n"); print}')
  printf '%s\n' "$clauses" | grep -iE "$verbs" \
    | grep -qvE '(__Q__|^[[:space:]]*(can|could|should|would|shall|is|are|was|were|do|does|did|am|will|what|why|how|when|where|which|who|whether)[^a-z])' \
    || exit 0

  ctx=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$ctx" ] || exit 0
  # A /loop or ScheduleWakeup re-fire returns as plain text the payload does not mark; only the transcript shows it.
  cc_prompt_scheduled "$prompt" "$ctx" && exit 0
  key=$(printf '%s' "$ctx" | cksum | cut -d' ' -f1)
  dir="${TMPDIR:-/tmp}/cc-ask-ledger-$key"
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-ask-ledger-*' -type d -mmin +1440 -exec rm -rf {} + 2>/dev/null
  mkdir -p "$dir" 2>/dev/null || exit 0

  # A quoted span over three words is a phrase; an in-word apostrophe is masked so it opens no quote (rock'n'roll's second still does).
  ap=$(printf '\001')
  found=$(
    printf '%s\n' "$scrub" | sed "s/\([A-Za-z]\)'\([A-Za-z]\)/\1$ap\2/g" \
      | grep -oE '"[^"]{2,40}"|'"'"'[^'"'"']{2,40}'"'" | sed 's/^["'"'"']//; s/["'"'"']$//' | tr "$ap" "'" | awk 'NF <= 3'
    printf '%s\n' "$scrub" | grep -oE '\b[0-9]+[A-Za-z]{1,4}\b( [A-Za-z]{3,})?'
    printf '%s\n' "$scrub" | awk '
      { line=$0; gsub(/[.?!:;]+/, "\n", line); n=split(line, parts, "\n")
        for (i=1;i<=n;i++){ m=split(parts[i], w, /[[:space:]]+/); first=1
          for (j=1;j<=m;j++){ t=w[j]; if (t=="") continue
            if (first){ first=0; continue }
            if (t ~ /^\(?[A-Z][A-Za-z0-9+#.-]{1,}[,)]?$/){ gsub(/[(),]/,"",t); print t } } } }'
  )
  stop='^(I|Claude|OK|Also|Then|Now|Please|Note|The|A|An|And|But|Or|If|It|We|You|They|He|She|This|That|These|Those|My|Our|Your|Its|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|January|February|March|April|May|June|July|August|September|October|November|December|PR|CI|README|TODO|MVP|API|UI|UX)$'
  # A capital I glued to a listed word is the pronoun missing a space; Inertia and an unlisted `Iforked` still ledger.
  glued='^I(i[a-z]+|m|d|ve|ll|am|was|have|had|did|got|saw|see|know|think|guess|mean|want|wanted|need|needed|tried|added|fixed|made|used|changed|updated|created|wrote|just|also|already|like|hope|can|will|would|could|should)$'
  printf '%s\n' "$found" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -vE '^$' | grep -vE "$stop" | grep -vE "$glued" \
    | awk '{ k=tolower($0); if (!(k in s)) { s[k]=1; print } }' \
    | awk '{ a[NR]=$0 } END { for (i=1;i<=NR;i++){ keep=1; for (j=1;j<=NR;j++) if (i!=j && length(a[j])>length(a[i]) && index(tolower(a[j]), tolower(a[i]))) keep=0; if (keep) print a[i] } }' > "$dir/new" 2>/dev/null
  [ -s "$dir/new" ] || exit 0

  # Drop what the repo has. 24 greps at most (twice the 12-name cap), inside a 5-second hook; later candidates pass unfiltered.
  root=""
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] && root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$root" ]; then
    kept=""; scanned=0
    while IFS= read -r cand; do
      [ -n "$cand" ] || continue
      if [ "$scanned" -lt 24 ]; then
        scanned=$((scanned + 1))
        # -i: the repo spells a name as a slug, column or class (`laravel/framework`, `payments`). Status >1 is an error and only that falls to rg.
        git -C "$root" grep -qliF -- "$cand" >/dev/null 2>&1
        case $? in
          0) continue ;;
          1) ;;
          *) command -v rg >/dev/null 2>&1 \
               && rg -qiF --max-count 1 -- "$cand" "$root" >/dev/null 2>&1 && continue ;;
        esac
      fi
      kept="${kept}${cand}
"
    done < "$dir/new"
    printf '%s' "$kept" > "$dir/new" 2>/dev/null
    [ -s "$dir/new" ] || exit 0
  fi

  touch "$dir/entries"
  added=$(awk -v ef="$dir/entries" 'FILENAME==ef { seen[tolower($0)]=1; n++; next } !(tolower($0) in seen) && n+c<12 { c++; print }' "$dir/entries" "$dir/new")
  [ -n "$added" ] || exit 0
  printf '%s\n' "$added" >> "$dir/entries"
  total=$(awk 'NF' "$dir/entries" | head -12 | paste -sd ',' - | sed 's/,/, /g')

  jq -cn --arg m "ask-ledger: the request names $total. Your final reply must say what happened to each, one line per name — \`<name>: as named\` | \`<name>: substituted → what, why\` | \`<name>: omitted → why\` — and a substitution should be asked about before the first edit." \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$m}}' 2>/dev/null
} 2>/dev/null
exit 0
