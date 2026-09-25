#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
#
# UserPromptSubmit. On a work-shaped prompt (a making verb in an imperative clause — the
# trigger candor's preamble and taskmaster's reminder share), destructure the ask into
# the things it NAMES and keep them in a session ledger the Stop gate reads back:
#   - quoted terms ("digimon", 'checkout total')
#   - proper nouns not at a clause start (Laravel, React, Digimon, Stripe)
#   - digit-letter tokens with their next word (2D sprites, 3D model, i18n)
# The ledger is appended on every later work prompt (an "also add X" names X), deduped,
# capped at 12 entries. The hook also tells the model, once per prompt that added
# entries, what the gate will ask for at the end.
#
# WHY THIS EXISTS (2026-09-19, rationale/fable-distillation-2026-09-18.md §4). Six
# headless runs asked for "Digimon themed … 2D pixel-art sprites" all drew invented
# creatures and said nothing — no hedge, no reason, so candor's avert guard (which fires
# on a reason being written) saw nothing. A script cannot judge whether the sprites are
# Digimon. It can insist the model say, per named thing, whether it delivered it as
# named, substituted it, or omitted it — and the gate can refuse a final message that
# does not. The truth of each line is the model's word; the shape is enforced.
#
# A NAME THE REPO ALREADY HAS IS NOT A THING THE ASK INTRODUCES (2026-09-22). "Fix the
# N+1 in OrderController when Laravel eager-loads Invoice and Payment relations under
# Inertia" ledgered six entries and the Stop gate then blocked the turn until the model
# wrote six lines about code it had been asked to REPAIR, not to deliver. Every
# candidate is now checked against the session project's tracked tree (`git grep -qliF`,
# `rg -qiF` when git grep errors out) and dropped when it is already there; a name the
# repo has never heard of — Digimon, Stripe, a new library — still ledgers.
#
# WHAT IT DOES NOT SEE (honest scope): lowercase features ("login", "register", "a
# library") — the ledger sees names, not nouns; a name mentioned in passing ("like
# Stripe does") is ledgered and must be accounted for, one line, cheap; anything in a
# fenced or inline code span is ignored. The existence filter carries three residuals of
# its own, each real: it needs a git work tree, so a session opened outside one is
# unfiltered exactly as before; `git grep` reads TRACKED files, so a name that exists
# only in an untracked or ignored file still ledgers; and it cannot tell a name the repo
# has from a name the ask ADDS to what the repo has ("also add a Stripe refund flow" in
# a repo that already mentions Stripe drops Stripe). It trades those false negatives for
# the false positives above, which were blocking turns.
# Off switch: CC_ASK_LEDGER=off. Fail-open.
{
  command -v jq >/dev/null 2>&1 || exit 0
  [ "${CC_ASK_LEDGER:-}" = "off" ] && exit 0
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  [ -n "$prompt" ] || exit 0
  case "$prompt" in /*) exit 0 ;; esac
  # Harness-injected turns reach UserPromptSubmit as prompts: a subagent's completion
  # notification, a Stop-hook relay, a system reminder. None is the user's ask, and a
  # subagent report is dense with capitalised tokens (a review's "NULL", "WHERE",
  # "FAIL") that would become ledger entries the Stop gate then demands lines for
  # (measured 2026-09-22: twelve false names from one notification, two blocked turns).
  # Anchored to the start: a real ask that merely QUOTES a marker mid-sentence is an ask.
  #
  # SUBAGENT HAND-BACKS (2026-09-25). A SendMessage report arrives as its own prompt,
  # `Another Claude session sent a message:` then `<agent-message from="<id>">` then a
  # `[Subagent hand-back]` frame, and none of those three was on the list. Measured in two
  # sessions (rationale/2026-09-25-session-plugin-usage-review.md, finding 3): agent ids
  # (`ac61f13cc0e92d08a`), their fragments (`430c`), `SubagentHandback`, `NOT`,
  # `PopoverContent` ledgered; the gate blocked 6 turns and 32+ `<id>: as named` lines
  # reached the user. The opening line and the tag are matched at the start; the frame
  # marker anywhere, because the harness may put a note above it.
  case "$prompt" in
    '<system-reminder>'*|'<task-notification>'*|'[SYSTEM NOTIFICATION'*|'Stop hook feedback:'*) exit 0 ;;
    'Another Claude session sent a message:'*|'<agent-message'*) exit 0 ;;
    *'[Subagent hand-back]'*) exit 0 ;;
  esac

  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-600 | tr 'A-Z' 'a-z')
  verbs='\b(build|create|add|implement|develop|rewrite|refactor|fix|update|change|write|make|ship|redo|replace)\b'
  clauses=$(printf '%s' "$head" | awk '{gsub(/\?/," __Q__\n"); gsub(/\. /,"\n"); print}')
  printf '%s\n' "$clauses" | grep -iE "$verbs" \
    | grep -qvE '(__Q__|^[[:space:]]*(can|could|should|would|shall|is|are|was|were|do|does|did|am|will|what|why|how|when|where|which|who|whether)[^a-z])' \
    || exit 0

  ctx=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$ctx" ] || exit 0
  key=$(printf '%s' "$ctx" | cksum | cut -d' ' -f1)
  dir="${TMPDIR:-/tmp}/cc-ask-ledger-$key"
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-ask-ledger-*' -type d -mmin +1440 -exec rm -rf {} + 2>/dev/null
  mkdir -p "$dir" 2>/dev/null || exit 0

  found=$(
    printf '%s\n' "$scrub" | grep -oE '"[^"]{2,40}"|'"'"'[^'"'"']{2,40}'"'" | sed 's/^["'"'"']//; s/["'"'"']$//'
    printf '%s\n' "$scrub" | grep -oE '\b[0-9]+[A-Za-z]{1,4}\b( [A-Za-z]{3,})?'
    printf '%s\n' "$scrub" | awk '
      { line=$0; gsub(/[.?!:;]+/, "\n", line); n=split(line, parts, "\n")
        for (i=1;i<=n;i++){ m=split(parts[i], w, /[[:space:]]+/); first=1
          for (j=1;j<=m;j++){ t=w[j]; if (t=="") continue
            if (first){ first=0; continue }
            if (t ~ /^\(?[A-Z][A-Za-z0-9+#.-]{1,}[,)]?$/){ gsub(/[(),]/,"",t); print t } } } }'
  )
  stop='^(I|Claude|OK|Also|Then|Now|Please|Note|The|A|An|And|But|Or|If|It|We|You|They|He|She|This|That|These|Those|My|Our|Your|Its|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|January|February|March|April|May|June|July|August|September|October|November|December|PR|CI|README|TODO|MVP|API|UI|UX)$'
  printf '%s\n' "$found" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -vE '^$' | grep -vE "$stop" \
    | awk '{ k=tolower($0); if (!(k in s)) { s[k]=1; print } }' \
    | awk '{ a[NR]=$0 } END { for (i=1;i<=NR;i++){ keep=1; for (j=1;j<=NR;j++) if (i!=j && length(a[j])>length(a[i]) && index(tolower(a[j]), tolower(a[i]))) keep=0; if (keep) print a[i] } }' > "$dir/new" 2>/dev/null
  [ -s "$dir/new" ] || exit 0

  # DROP WHAT THE REPO ALREADY HAS. Scoped to the git work tree of the payload cwd: no
  # work tree, no filter (fail-open — the pre-2026-09-22 behaviour). `git grep` exits 0
  # on a hit, 1 on a clean miss, >1 on an error (bare repo, no index), and only that
  # last case falls through to rg, so an unmatched name is never re-searched twice.
  # BOUNDED AT 24 GREPS, and candidates past that pass UNFILTERED — the honest residual
  # of a bound inside a 5-second hook. 24 is twice the ledger's own 12-name cap so a
  # prompt whose first names are all pre-existing still gets its later ones checked;
  # measured 2026-09-22, 12 tree-wide greps on this marketplace cost 0.32 s.
  root=""
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] && root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$root" ]; then
    kept=""; scanned=0
    while IFS= read -r cand; do
      [ -n "$cand" ] || continue
      if [ "$scanned" -lt 24 ]; then
        scanned=$((scanned + 1))
        # -i: the ask writes a name in prose ("Laravel", "Payment") and the repo writes
        # it as a slug, a column or a class (`laravel/framework`, `payments`). Case is
        # not the signal for "this already exists here", and a case-sensitive miss put
        # `Laravel` back in the ledger of a Laravel project.
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

  jq -cn --arg m "ask-ledger: the ask names these things — $total. The Stop gate refuses a final message without one line per name: \`<name>: as named\` | \`<name>: substituted → what, why\` | \`<name>: omitted → why\`. A substitution is a question before the first edit, not a line at the end; the line is where it is confessed if it was not asked. Off with CC_ASK_LEDGER=off." \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$m}}' 2>/dev/null
} 2>/dev/null
exit 0
