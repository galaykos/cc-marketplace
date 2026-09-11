#!/usr/bin/env bash
# program.sh — the overseer's state machine. The ONLY writer of .claude/overseer/program.json
# (serialised by a mkdir lock, so two invocations of this script cannot lose each other's write).
#
# What it gates: a milestone cannot reach `done` without the nine required evidence kinds
# (accept exits 2 and lists them); the browser kinds and `tests` must carry a --file that
# exists at add time AND at accept time (a deleted screenshot un-accepts); a hands-off program
# must carry at least one ASSUMED decision before its first accept (an autonomous run that
# assumed nothing is not credible); statuses and kinds come from fixed vocabularies. What it
# does NOT check: that the evidence is true — a screenshot of the wrong page still passes; the
# acceptance reference says why that residual stays.
#
# Usage:
#   program.sh init --goal "<text>" --slug <slug> [--base <branch>] [--hands-off --reason "<why>"]
#   program.sh status [--json]
#   program.sh next                          # first milestone not done/parked whose deps are done
#   program.sh milestone add --id <id> --title "<t>" --branch <b> [--depends a,b]
#   program.sh milestone set --id <id> --status <queued|briefed|building|accepting|parked> [--reason "<r>"]
#   program.sh evidence add --id <id> --kind <kind> --note "<n>" [--file <path>]   # --file required for file kinds
#   program.sh evidence clear --id <id>
#   program.sh accept --id <id>              # exit 0 → status done; exit 2 → what is missing, listed
#   program.sh decision add --text "<what>" --rationale "<why>" [--options "<a | b>"]
#   program.sh decision add --assumed --text "<what>" --alternative "<other reading>" --rationale "<why>"
#   program.sh dispatch check <prompt-file> [--kind worker|reader|reviewer]
#                                            # worker (default): preamble verbatim, TOUCH ONLY, VERIFY, an existing skill path
#                                            # reader/reviewer: preamble verbatim, RETURN shape, an existing skill path, no scope/verify
#                                            # every kind: a state file named without an absolute path is a WARN
#   program.sh close                         # every milestone done/parked → archive the program; init may follow
# Exit codes: 0 ok · 2 gate refused / bad vocabulary · 3 no program or bad usage · 4 jq missing · 5 state write failed
# Env: OVERSEER_ROOT overrides the project root (default: git toplevel, else $PWD).
#      OVERSEER_PREAMBLE overrides where `dispatch check` finds the canonical discipline preamble.
set -u

REQUIRED_KINDS="tests browser-happy browser-error viewport:mobile viewport:tablet viewport:desktop console-clean keyboard motion"
OPTIONAL_KINDS="a11y review perf dark-mode progress"
FILE_KINDS="tests browser-happy browser-error viewport:mobile viewport:tablet viewport:desktop console-clean keyboard motion"
STATUSES="queued briefed building accepting done parked"

command -v jq >/dev/null 2>&1 || { echo "program.sh: jq is required" >&2; exit 4; }

root="${OVERSEER_ROOT:-}"
if [ -z "$root" ]; then
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"
fi
dir="$root/.claude/overseer"
state="$dir/program.json"

usage() { sed -n '3,27p' "$0" >&2; exit 3; }
need_state() {
  [ -s "$state" ] || { echo "program.sh: no program under $dir — run /overseer:start" >&2; exit 3; }
  jq -e 'type=="object" and (.milestones|type=="array")' "$state" >/dev/null 2>&1 \
    || { echo "program.sh: $state is not a valid program (malformed JSON or missing milestones[])" >&2; exit 5; }
}
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
in_list() { local x="$1"; shift; for w in "$@"; do [ "$w" = "$x" ] && return 0; done; return 1; }
arg() { [ -n "${2:-}" ] || { echo "program.sh: $1 needs a value" >&2; exit 3; }; printf '%s' "$2"; }
lock() { # mkdir is atomic on every POSIX filesystem; flock is not on macOS
  local n=0
  until mkdir "$state.lock" 2>/dev/null; do
    n=$((n+1)); [ "$n" -lt 200 ] || { echo "program.sh: state locked by another writer for 10s — remove $state.lock if stale" >&2; exit 5; }
    sleep 0.05
  done
  trap 'rmdir "$state.lock" 2>/dev/null' EXIT
}
unlock() { rmdir "$state.lock" 2>/dev/null; trap - EXIT; }
write() { # $1.. = jq args + filter; read-modify-write under the lock, atomic replace, failure is fatal
  lock
  local tmp="$state.tmp.$$"
  if jq "$@" "$state" > "$tmp" 2>"$tmp.err" && jq -e 'type=="object"' "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$state"; rm -f "$tmp.err"; unlock
  else
    echo "program.sh: state write failed — $(head -1 "$tmp.err" 2>/dev/null)" >&2; rm -f "$tmp" "$tmp.err"; unlock; exit 5
  fi
}
has_ms() { jq -e --arg id "$1" '.milestones[] | select(.id==$id)' "$state" >/dev/null 2>&1; }
abspath() { local d; d=$(cd "$(dirname "$1")" 2>/dev/null && pwd -P) || return 1; printf '%s/%s' "$d" "$(basename "$1")"; }
NEXT_FILTER='. as $p | [.milestones[] | select(.status!="done" and .status!="parked") | select(all((.depends // [])[]; . as $d | any($p.milestones[]; .id==$d and .status=="done")))] | .[0]'

cmd="${1:-}"; shift || true
case "$cmd" in
  init)
    goal=""; slug=""; base=""; hands=false; why=""
    while [ $# -gt 0 ]; do case "$1" in
      --goal) goal=$(arg "$1" "${2:-}") || exit 3; shift 2;; --slug) slug=$(arg "$1" "${2:-}") || exit 3; shift 2;;
      --base) base=$(arg "$1" "${2:-}") || exit 3; shift 2;; --reason) why=$(arg "$1" "${2:-}") || exit 3; shift 2;;
      --hands-off) hands=true; shift;; *) usage;; esac; done
    [ -n "$goal" ] && [ -n "$slug" ] || usage
    printf '%s' "$slug" | grep -Eq '^[a-z0-9][a-z0-9-]*$' || { echo "program.sh: slug must be [a-z0-9-]" >&2; exit 2; }
    if [ "$hands" = true ] && [ -z "$why" ]; then
      echo "program.sh: --hands-off needs --reason — why nobody can answer a question (headless run, user asked for it, …)" >&2; exit 2
    fi
    if [ -s "$state" ] && jq -e '(.milestones|length)>0' "$state" >/dev/null 2>&1; then
      echo "program.sh: a program with milestones exists here — /overseer:resume to continue it, or 'program.sh close' once every milestone is done or parked" >&2; exit 2
    fi
    [ -n "$base" ] || base=$(git -C "$root" branch --show-current 2>/dev/null)
    [ -n "$base" ] || base=main
    mkdir -p "$dir/milestones" && printf '*\n' > "$dir/.gitignore"
    jq -n --arg goal "$goal" --arg slug "$slug" --arg base "$base" --argjson hands "$hands" --arg why "$why" --arg at "$(now)" \
      '{version:1,goal:$goal,slug:$slug,base_branch:$base,hands_off:$hands,hands_off_reason:$why,created_at:$at,milestones:[]}' > "$state"
    [ -f "$dir/decisions.md" ] || printf '# Decisions taken on the user'"'"'s behalf\n\nRows marked ASSUMED answer a question the user was not asked; the options column holds the reading that was NOT taken.\n\n| when | decision | options | rationale |\n| --- | --- | --- | --- |\n' > "$dir/decisions.md"
    echo "program initialised: $state (base: $base)";;

  status)
    need_state
    if [ "${1:-}" = "--json" ]; then cat "$state"; exit 0; fi
    assumed=$(grep -c '^| [^|]* | ASSUMED: ' "$dir/decisions.md" 2>/dev/null || true)
    jq -r --arg assumed "${assumed:-0}" '"program: " + .goal + "  [" + .slug + "]  base: " + .base_branch + (if .hands_off then "  hands-off (" + (.hands_off_reason // "no reason recorded") + ")" else "" end),
           "milestones: " + ([.milestones[]|select(.status=="done")]|length|tostring) + "/" + (.milestones|length|tostring) + " done  ·  assumed decisions: " + $assumed,
           "",
           "id\tstatus\tbranch\tdepends\tevidence\ttitle",
           (.milestones[] | [.id, .status, .branch, ((.depends // [])|join(",")|if .=="" then "-" else . end),
             ((.evidence // [])|map(.kind)|unique|join(",")|if .=="" then "-" else . end),
             (.title + (if .reason != "" then "  (" + .reason + ")" else "" end))] | @tsv)' "$state"
    nxt=$(jq -r "$NEXT_FILTER | .id // empty" "$state")
    echo; echo "next: ${nxt:-none}"
    if [ -z "$nxt" ] && jq -e '(.milestones|length)==0' "$state" >/dev/null; then
      echo "no milestones registered — the roadmap step has not run; /overseer:start writes it"
    fi;;

  next)
    need_state
    jq -r "$NEXT_FILTER"' | if . == null then "none" else .id + "\t" + .status + "\t" + .branch + "\t" + .title end' "$state";;

  milestone)
    need_state
    sub="${1:-}"; shift || true
    id=""; title=""; branch=""; depends=""; st=""; reason=""
    case "$sub" in
      add)
        while [ $# -gt 0 ]; do case "$1" in
          --id) id=$(arg "$1" "${2:-}") || exit 3; shift 2;; --title) title=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          --branch) branch=$(arg "$1" "${2:-}") || exit 3; shift 2;; --depends) depends=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          *) usage;; esac; done;;
      set)
        while [ $# -gt 0 ]; do case "$1" in
          --id) id=$(arg "$1" "${2:-}") || exit 3; shift 2;; --status) st=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          --reason) reason=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          --title|--branch|--depends) echo "program.sh: $1 is set only by 'milestone add'" >&2; exit 3;;
          *) usage;; esac; done;;
      *) usage;;
    esac
    [ -n "$id" ] || usage
    printf '%s' "$id" | grep -Eq '^m[0-9]+$' || { echo "program.sh: milestone id must be m<N>" >&2; exit 2; }
    case "$sub" in
      add)
        [ -n "$title" ] && [ -n "$branch" ] || usage
        has_ms "$id" && { echo "program.sh: $id already exists" >&2; exit 2; }
        deps=$(printf '%s' "$depends" | tr ',' '\n' | sed '/^$/d' | jq -R . | jq -s 'unique')
        for d in $(printf '%s' "$depends" | tr ',' ' '); do
          [ "$d" = "$id" ] && { echo "program.sh: $id cannot depend on itself" >&2; exit 2; }
          has_ms "$d" || { echo "program.sh: dependency $d does not exist" >&2; exit 2; }
        done
        write --arg id "$id" --arg t "$title" --arg b "$branch" --argjson deps "$deps" \
          '.milestones += [{id:$id,title:$t,branch:$b,depends:$deps,status:"queued",reason:"",evidence:[]}]'
        mkdir -p "$dir/milestones/$id/evidence" "$dir/milestones/$id/dispatch"
        echo "added $id ($branch)";;
      set)
        has_ms "$id" || { echo "program.sh: no milestone $id" >&2; exit 2; }
        in_list "$st" $STATUSES || { echo "program.sh: status must be one of: $STATUSES" >&2; exit 2; }
        [ "$st" = "done" ] && { echo "program.sh: 'done' is set only by 'accept'" >&2; exit 2; }
        [ "$st" = "parked" ] && [ -z "$reason" ] && { echo "program.sh: parked needs --reason" >&2; exit 2; }
        write --arg id "$id" --arg st "$st" --arg r "$reason" '(.milestones[]|select(.id==$id)) |= (.status=$st | .reason=$r)'
        echo "$id → $st";;
    esac;;

  evidence)
    need_state
    sub="${1:-}"; shift || true
    id=""; kind=""; note=""; file=""
    while [ $# -gt 0 ]; do case "$1" in
      --id) id=$(arg "$1" "${2:-}") || exit 3; shift 2;; --kind) kind=$(arg "$1" "${2:-}") || exit 3; shift 2;;
      --note) note=$(arg "$1" "${2:-}") || exit 3; shift 2;; --file) file=$(arg "$1" "${2:-}") || exit 3; shift 2;;
      *) usage;; esac; done
    [ -n "$id" ] || usage
    has_ms "$id" || { echo "program.sh: no milestone $id" >&2; exit 2; }
    case "$sub" in
      add)
        in_list "$kind" $REQUIRED_KINDS $OPTIONAL_KINDS || { echo "program.sh: kind must be one of: $REQUIRED_KINDS $OPTIONAL_KINDS" >&2; exit 2; }
        [ -n "$note" ] || { echo "program.sh: --note is required (what was done, in one line)" >&2; exit 2; }
        if in_list "$kind" $FILE_KINDS && [ -z "$file" ]; then
          echo "program.sh: kind $kind needs --file (a screenshot, dump or saved output a human can open)" >&2; exit 2
        fi
        if [ -n "$file" ]; then
          [ -f "$file" ] || { echo "program.sh: --file $file is not a regular file" >&2; exit 2; }
          [ -s "$file" ] || { echo "program.sh: --file $file is empty" >&2; exit 2; }
          file=$(abspath "$file")
        fi
        write --arg id "$id" --arg k "$kind" --arg n "$note" --arg f "$file" --arg at "$(now)" \
          '(.milestones[]|select(.id==$id)).evidence += [{kind:$k,note:$n,file:$f,at:$at}]'
        echo "$id evidence: $kind";;
      clear)
        write --arg id "$id" '(.milestones[]|select(.id==$id)).evidence = []'
        echo "$id evidence cleared";;
      *) usage;;
    esac;;

  accept)
    need_state
    id=""
    while [ $# -gt 0 ]; do case "$1" in --id) id=$(arg "$1" "${2:-}") || exit 3; shift 2;; *) usage;; esac; done
    [ -n "$id" ] || usage
    has_ms "$id" || { echo "program.sh: no milestone $id" >&2; exit 2; }
    st=$(jq -r --arg id "$id" '.milestones[]|select(.id==$id)|.status' "$state")
    in_list "$st" building accepting || { echo "program.sh: $id is '$st' — accept runs from building/accepting" >&2; exit 2; }
    missing=""; gone=""
    for k in $REQUIRED_KINDS; do
      jq -e --arg id "$id" --arg k "$k" '.milestones[]|select(.id==$id)|.evidence[]|select(.kind==$k)' "$state" >/dev/null 2>&1 || missing="$missing $k"
    done
    while IFS= read -r f; do
      [ -n "$f" ] && [ ! -s "$f" ] && gone="$gone $f"
    done < <(jq -r --arg id "$id" '.milestones[]|select(.id==$id)|.evidence[]|.file' "$state")
    if [ -n "$missing" ] || [ -n "$gone" ]; then
      [ -n "$missing" ] && echo "program.sh: $id NOT accepted — missing evidence:$missing" >&2
      [ -n "$gone" ] && echo "program.sh: $id NOT accepted — evidence files no longer exist:$gone" >&2
      echo "record each with: program.sh evidence add --id $id --kind <kind> --note \"<what was done>\" --file <path>" >&2
      exit 2
    fi
    if jq -e '.hands_off' "$state" >/dev/null 2>&1 && ! grep -q '^| [^|]* | ASSUMED: ' "$dir/decisions.md" 2>/dev/null; then
      echo "program.sh: $id NOT accepted — hands-off program with no ASSUMED decision; record what the Clarify round would have asked:" >&2
      echo "  program.sh decision add --assumed --text \"<reading taken>\" --alternative \"<reading not taken>\" --rationale \"<why>\"" >&2
      exit 2
    fi
    write --arg id "$id" --arg at "$(now)" '(.milestones[]|select(.id==$id)) |= (.status="done" | .reason="" | .accepted_at=$at)'
    echo "$id accepted → done";;

  decision)
    need_state
    [ "${1:-}" = "add" ] || usage; shift
    text=""; why=""; opts="-"; assumed=false; alt=""
    while [ $# -gt 0 ]; do case "$1" in
      --text) text=$(arg "$1" "${2:-}") || exit 3; shift 2;; --rationale) why=$(arg "$1" "${2:-}") || exit 3; shift 2;;
      --options) opts=$(arg "$1" "${2:-}") || exit 3; shift 2;; --alternative) alt=$(arg "$1" "${2:-}") || exit 3; shift 2;;
      --assumed) assumed=true; shift;; *) usage;; esac; done
    [ -n "$text" ] && [ -n "$why" ] || usage
    if [ "$assumed" = true ]; then
      [ -n "$alt" ] || { echo "program.sh: --assumed needs --alternative (the reading you did NOT take)" >&2; exit 2; }
      text="ASSUMED: $text"; opts="not taken: $alt"
    fi
    printf '| %s | %s | %s | %s |\n' "$(now)" "$text" "$opts" "$why" >> "$dir/decisions.md"
    echo "decision recorded";;

  dispatch)
    [ "${1:-}" = "check" ] && [ -n "${2:-}" ] || usage
    f="$2"; kind="worker"; shift 2
    while [ $# -gt 0 ]; do case "$1" in --kind) kind=$(arg "$1" "${2:-}") || exit 3; shift 2;; *) usage;; esac; done
    in_list "$kind" worker reader reviewer || { echo "program.sh: --kind must be worker, reader or reviewer" >&2; exit 2; }
    [ -f "$f" ] || { echo "program.sh: no such prompt file $f" >&2; exit 3; }
    miss=""; warn=""
    pre="${OVERSEER_PREAMBLE:-}"
    [ -n "$pre" ] || pre=$(find "$HOME/.claude/plugins/cache" -path '*/delegation-contracts/references/discipline-preamble.md' 2>/dev/null | sort -V | tail -1)
    if [ -n "$pre" ] && [ -f "$pre" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        grep -qF -- "$line" "$f" || miss="$miss
  preamble clause missing or reworded: ${line:0:60}…"
      done < <(grep -E '^[0-9]+\. ' "$pre")
    else
      n=$(grep -cE '^[0-9]+\. ' "$f" 2>/dev/null || true)
      [ "${n:-0}" -ge 9 ] || miss="$miss
  discipline preamble: fewer than 9 numbered clauses (canonical file not found; set OVERSEER_PREAMBLE)"
    fi
    if [ "$kind" = worker ]; then
      grep -qE 'TOUCH ONLY|Touch only|touch only' "$f" || miss="$miss
  no TOUCH ONLY scope lock"
      grep -qE '(VERIFY|Verify)' "$f" || miss="$miss
  no VERIFY command"
    else
      grep -qE 'RETURN' "$f" || miss="$miss
  no RETURN shape (a $kind dispatch is judged by what it returns)"
      grep -qE 'write no file|read-only|WRITE NO FILES|writes nothing' "$f" || miss="$miss
  a $kind dispatch must say it writes no file"
    fi
    skill_ok=0
    while IFS= read -r p; do [ -f "$p" ] && skill_ok=1 && break; done < <(grep -oE '/[^ `"'"'"'<>)]*/SKILL\.md' "$f" | sort -u)
    [ "$skill_ok" -eq 1 ] || miss="$miss
  no skill pinned by an absolute path that exists (…/SKILL.md)"
    grep -qE '/[A-Za-z0-9_./-]+' "$f" || miss="$miss
  no absolute path anywhere"
    for sf in decisions.md findings.md brief.md direction.md; do
      if grep -q "$sf" "$f" && ! grep -qE "/[A-Za-z0-9_./-]+/$sf" "$f"; then warn="$warn
  $sf is mentioned without an absolute path — the delegate cannot find it"; fi
    done
    if grep -qiE 'npm run dev|vp dev|artisan serve' "$f" && ! grep -qiE '(^|[^a-z])(stop|kill)([^a-z]|$)|public/hot' "$f"; then warn="$warn
  the prompt may start a dev server and never says to stop it"; fi
    [ -n "$warn" ] && echo "program.sh: dispatch prompt $f WARN:$warn" >&2
    if [ -n "$miss" ]; then echo "program.sh: dispatch prompt $f NOT ready:$miss" >&2; exit 2; fi
    echo "dispatch prompt ok ($kind): $f";;

  close)
    need_state
    if jq -e '[.milestones[]|select(.status!="done" and .status!="parked")]|length>0' "$state" >/dev/null; then
      echo "program.sh: cannot close — milestones still open (not done/parked): $(jq -r '[.milestones[]|select(.status!="done" and .status!="parked")|.id]|join(" ")' "$state")" >&2; exit 2
    fi
    slug=$(jq -r .slug "$state"); at=$(jq -r .created_at "$state" | tr -d ':')
    arch="$dir/archive/$slug-$at"
    mkdir -p "$arch"
    mv "$state" "$arch/program.json"
    [ -d "$dir/milestones" ] && mv "$dir/milestones" "$arch/milestones"
    for f in charter.md discovery.md capabilities.tsv decisions.md; do [ -f "$dir/$f" ] && cp "$dir/$f" "$arch/$f"; done
    mkdir -p "$dir/milestones"
    echo "program closed → $arch (decisions.md kept in place; init may start a new program)";;

  *) usage;;
esac
