#!/usr/bin/env bash
# program.sh — the overseer's state machine. The ONLY writer of .claude/overseer/program.json
# (serialised by a mkdir lock, so two invocations of this script cannot lose each other's write).
#
# What it gates: a milestone cannot reach `done` without the nine required evidence kinds
# (accept exits 2 and lists them); the browser kinds and `tests` must carry a --file that
# exists at add time AND at accept time (a deleted screenshot un-accepts); every required
# evidence row must be newer than the last worker/follow-up dispatch that passed `dispatch check`
# (a walk recorded before the last fix cycle is a walk of older code); at least one dispatch
# under the milestone passed `dispatch check` unchanged since (recorded in dispatch/.gated —
# a file that never went through the check is not a gated dispatch, whatever it pins); the
# kind's skill groups are pinned by paths that EXIST; a hands-off program must carry at least
# one ASSUMED decision before its first accept; statuses, kinds, sizes and rigour profiles come
# from fixed vocabularies. What it does NOT check: that the evidence is true — a screenshot of
# the wrong page still passes; the acceptance reference says why that residual stays.
#
# Usage:
#   program.sh init --goal "<text>" --slug <slug> [--base <branch>] [--hands-off --reason "<why>"] [--foreign-session "<why>"] [--model opus|auto]
#                                            # refuses when this Claude session was opened in another project (exit 2) unless --foreign-session says why
#                                            # --model (default opus): the tier every dispatch may use — opus: nothing above opus; auto: judgment
#                                            # seats (reader, reviewer) may run at the session model (MODEL: inherit), workers stay at opus
#   program.sh status [--json]
#   program.sh next                          # first milestone not done/parked whose deps are done
#   program.sh milestone add --id <id> --title "<t>" --branch <b> [--depends a,b] [--kind <kind>] [--size S|M|L|XL] [--rigour lean|standard|adversarial]
#                                            # kinds: kinds.tsv (default feature); size (default M): only S may skip taskmaster for a direct worker
#                                            # rigour: how much adversarial scrutiny the milestone buys (dispatch-prompts.md § Rigour) — decided from
#                                            # the brief's signals, so it may be set later; unset draws a WARN on every gated dispatch
#   program.sh milestone set --id <id> --status <queued|briefed|building|accepting|parked> [--reason "<r>"]
#   program.sh milestone set --id <id> --size <S|M|L|XL> | --rigour <profile>  --reason "<why>"   # re-sized / re-rigoured with a reason, kept in history
#   program.sh evidence add --id <id> --kind <kind> --note "<n>" [--file <path>]   # --file required for file kinds
#   program.sh evidence clear --id <id>
#   program.sh accept --id <id>              # exit 0 → status done + "sized X · actual …" line; exit 2 → the first failing gate, listed
#                                            # gates in order: a gated dispatch exists · kind groups pinned by existing paths · nine evidence kinds,
#                                            # files present, each newer than the last gated worker dispatch · hands-off has an ASSUMED row
#   program.sh decision add --text "<what>" --rationale "<why>" [--options "<a | b>"]
#   program.sh decision add --assumed --text "<what>" --alternative "<other reading>" --rationale "<why>"
#   program.sh dispatch check <prompt-file> [--kind worker|reader|reviewer|followup] [--milestone <id>]
#                                            # exit 0 records the file (checksum, kind) in its dispatch/.gated — accept counts only those
#                                            # --milestone (or a file under milestones/<id>/dispatch/): WARN for each of the kind's skill groups no
#                                            # gated dispatch has pinned yet; WARN on a dense card; WARN when the milestone has no rigour profile
#                                            # worker (default): every preamble clause line verbatim (whitespace-folded), TOUCH ONLY, VERIFY, an existing skill path
#                                            # reader/reviewer: preamble verbatim, RETURN shape, an existing skill path, no scope/verify
#                                            # every kind but followup: a MODEL: line the program's tier allows — a worker never inherits, even under
#                                            # --model auto (simulation 3 ran two thirds of its subagent turns on the session model unasked)
#                                            # --milestone + worker: WARN when the milestone is sized M or larger and no taskmaster index newer than
#                                            # the milestone's registration names it — an M+ milestone is briefed to taskmaster, a direct worker needs a decision row
#                                            # --milestone + worker + index: WARN when the index's boost marker disagrees with the rigour profile — Ultra:/Goal:
#                                            # without boost=off on lean/standard (hands-off: brief goal-lean); adversarial with none or with Goal: (boost=off) —
#                                            # or a surface kind (auth api data-model form) is lean
#                                            # every kind: a state file named without an absolute path is a WARN
#   program.sh close [--divergent-ok "<why>"] # every milestone done/parked → archive the program (evidence paths rewritten); init may follow
#                                            # refuses when two done milestones' branches contain neither the other and no done milestone
#                                            # has kind integration — the product was never seen in one tree — unless --divergent-ok says why
#   program.sh log                           # timeline from the record: status changes, dispatches, evidence, decisions — generated, not typed
#   program.sh suggestion add --text "<t>" [--from <id>]   # deferred-suggestion ledger (suggestions.md), printed at close
# Exit codes: 0 ok · 2 gate refused / bad vocabulary · 3 no program or bad usage · 4 jq missing · 5 state write failed
# Env: OVERSEER_ROOT overrides the project root (default: git toplevel, else $PWD).
#      OVERSEER_PREAMBLE overrides where `dispatch check` finds the canonical discipline preamble.
set -u

REQUIRED_KINDS="tests browser-happy browser-error viewport:mobile viewport:tablet viewport:desktop console-clean keyboard motion"
OPTIONAL_KINDS="a11y review perf dark-mode progress"
FILE_KINDS="tests browser-happy browser-error viewport:mobile viewport:tablet viewport:desktop console-clean keyboard motion"
STATUSES="queued briefed building accepting done parked"
SIZES="S M L XL"
RIGOURS="lean standard adversarial"          # dispatch-prompts.md § Rigour: what scrutiny a milestone buys, decided from the brief, not the size
SURFACE_KINDS="auth api data-model form"     # kinds whose defects are irreversible or leak data: never lean
TIERS="opus auto"
MODELS_OPUS="opus sonnet haiku"            # tier opus: nothing above opus, in any seat
MODELS_AUTO="opus sonnet haiku inherit"    # tier auto: a seat may inherit the session model — only when the user asked at start

command -v jq >/dev/null 2>&1 || { echo "program.sh: jq is required" >&2; exit 4; }

root="${OVERSEER_ROOT:-}"
if [ -z "$root" ]; then
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"
fi
dir="$root/.claude/overseer"
state="$dir/program.json"

usage() { sed -n '3,/^set -u$/p' "$0" | sed '$d' >&2; exit 3; }
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
KINDS_FILE="$(cd "$(dirname "$0")/.." && pwd)/kinds.tsv"
kind_required() { grep -v '^#' "$KINDS_FILE" | awk -F'\t' -v k="$1" '$1==k {print $2}'; }
kind_known() { [ -n "$(kind_required "$1")" ]; }
# session_root_check: this Claude session's transcript lives under ~/.claude/projects/<encoded cwd>/;
# when that cwd is not this project, the pipeline commands (taskmaster, task-runner, craft) are
# unreachable and both simulations ran on hand-dispatch without noticing. Fail-open when the
# session id or transcript is unknown (plain terminal, other harness); refuse when it is known and foreign.
session_root_check() {
  local sid="${CLAUDE_CODE_SESSION_ID:-}" t enc want
  [ -n "$sid" ] || return 0
  t=$(ls -d "$HOME"/.claude/projects/*/"$sid".jsonl 2>/dev/null | head -1); [ -n "$t" ] || return 0
  enc=$(basename "$(dirname "$t")"); want=$(printf '%s' "$root" | sed 's#[^A-Za-z0-9]#-#g')
  [ "$enc" = "$want" ] && return 0
  echo "program.sh: this Claude session was opened in another directory (transcript dir $enc), not in $root — the pipeline commands (taskmaster, task-runner, craft) are unreachable from here; start the session in $root, or pass --foreign-session \"<why>\" to init (recorded, every dispatch then WARNs)" >&2
  return 2
}
# pinned_groups_status <kind> <files...>: one line per group: "ok <group>" / "missing <group>" / "uninstalled <group>".
# A pin counts only when the path EXISTS — a review found the text match alone let /nowhere/…/SKILL.md close an
# auth milestone. `stack` is installed only when a project skill or a laravel/web-dev cache skill really is there.
pinned_groups_status() {
  local kind="$1"; shift; local files="$*" g alt plugin skill hit inst pins p
  pins=""
  while IFS= read -r p; do [ -n "$p" ] && [ -f "$p" ] && pins="$pins
$p"; done < <(cat $files 2>/dev/null | grep -oE '/[^ `"'"'"'<>)]*/SKILL\.md' | sort -u)
  for g in $(kind_required "$kind"); do
    hit=0; inst=0
    for alt in $(printf '%s' "$g" | tr '|' ' '); do
      if [ "$alt" = stack ]; then
        printf '%s\n' "$pins" | grep -qE '/\.claude/skills/[A-Za-z0-9_-]+/SKILL\.md$|/(laravel|web-dev)/[^/ ]+/skills/[A-Za-z0-9_-]+/SKILL\.md$' && hit=1
        { ls "$root"/.claude/skills/*/SKILL.md >/dev/null 2>&1 || ls -d "$HOME"/.claude/plugins/cache/*/laravel/*/skills/*/SKILL.md "$HOME"/.claude/plugins/cache/*/web-dev/*/skills/*/SKILL.md >/dev/null 2>&1; } && inst=1
        continue
      fi
      plugin="${alt%%:*}"; skill="${alt#*:}"
      if [ "$plugin" = project ]; then
        printf '%s\n' "$pins" | grep -qE "/\.claude/skills/$skill/SKILL\.md$" && hit=1; [ -f "$root/.claude/skills/$skill/SKILL.md" ] && inst=1
      else
        printf '%s\n' "$pins" | grep -qE "/$plugin/[^/ ]+/skills/$skill/SKILL\.md$" && hit=1
        [ -n "$(ls -d "$HOME"/.claude/plugins/cache/*/"$plugin"/*/skills/"$skill"/SKILL.md 2>/dev/null | head -1)" ] && inst=1
      fi
    done
    if [ "$hit" = 1 ]; then echo "ok $g"; elif [ "$inst" = 1 ]; then echo "missing $g"; else echo "uninstalled $g"; fi
  done
}
# gated_files <id> [kind-filter]: the dispatch files under milestones/<id>/dispatch/ whose current checksum matches the one
# `dispatch check` recorded at its last exit 0 — a file edited after the check, or never checked, is not gated
gated_files() {
  local id="$1" filt="${2:-}" gd sum k b f
  gd="$dir/milestones/$id/dispatch"; [ -f "$gd/.gated" ] || return 0
  while read -r sum k b; do
    [ -n "$b" ] && f="$gd/$b" && [ -f "$f" ] || continue
    [ -z "$filt" ] || in_list "$k" $filt || continue
    [ "$(cksum < "$f" | cut -d' ' -f1)" = "$sum" ] && printf '%s\n' "$f"
  done < <(awk '{last[$3]=$0} END{for (b in last) print last[b]}' "$gd/.gated")
}
abspath() { local d; d=$(cd "$(dirname "$1")" 2>/dev/null && pwd -P) || return 1; printf '%s/%s' "$d" "$(basename "$1")"; }
# in_dispatch_dir <abs-file>: prints the milestone id when the file lives under milestones/<id>/dispatch/ (logical or physical $dir)
in_dispatch_dir() { local f="$1" dp; dp=$(cd "$dir" 2>/dev/null && pwd -P) || dp="$dir"
  case "$f" in "$dir"/milestones/m[0-9]*/dispatch/*.md|"$dp"/milestones/m[0-9]*/dispatch/*.md) basename "$(dirname "$(dirname "$f")")";; esac; }
NEXT_FILTER='. as $p | [.milestones[] | select(.status!="done" and .status!="parked") | select(all((.depends // [])[]; . as $d | any($p.milestones[]; .id==$d and .status=="done")))] | .[0]'

cmd="${1:-}"; shift || true
case "$cmd" in
  init)
    goal=""; slug=""; base=""; hands=false; why=""; foreign=""; model="opus"
    while [ $# -gt 0 ]; do case "$1" in
      --goal) goal=$(arg "$1" "${2:-}") || exit 3; shift 2;; --slug) slug=$(arg "$1" "${2:-}") || exit 3; shift 2;;
      --model) model=$(arg "$1" "${2:-}") || exit 3; shift 2;;
      --base) base=$(arg "$1" "${2:-}") || exit 3; shift 2;; --reason) why=$(arg "$1" "${2:-}") || exit 3; shift 2;;
      --foreign-session) foreign=$(arg "$1" "${2:-}") || exit 3; shift 2;;
      --hands-off) hands=true; shift;; *) usage;; esac; done
    [ -n "$goal" ] && [ -n "$slug" ] || usage
    if [ -z "$foreign" ]; then session_root_check || exit 2; fi
    printf '%s' "$slug" | grep -Eq '^[a-z0-9][a-z0-9-]*$' || { echo "program.sh: slug must be [a-z0-9-]" >&2; exit 2; }
    in_list "$model" $TIERS || { echo "program.sh: --model must be one of: $TIERS (opus: no seat above opus; auto: judgment seats may inherit the session model)" >&2; exit 2; }
    if [ "$hands" = true ] && [ -z "$why" ]; then
      echo "program.sh: --hands-off needs --reason — why nobody can answer a question (headless run, user asked for it, …)" >&2; exit 2
    fi
    if [ -s "$state" ] && jq -e '(.milestones|length)>0' "$state" >/dev/null 2>&1; then
      echo "program.sh: a program with milestones exists here — /overseer:resume to continue it, or 'program.sh close' once every milestone is done or parked" >&2; exit 2
    fi
    [ -n "$base" ] || base=$(git -C "$root" branch --show-current 2>/dev/null)
    [ -n "$base" ] || base=main
    mkdir -p "$dir/milestones" && printf '*\n' > "$dir/.gitignore"
    jq -n --arg goal "$goal" --arg slug "$slug" --arg base "$base" --argjson hands "$hands" --arg why "$why" --arg fs "$foreign" --arg model "$model" --arg at "$(now)" \
      '{version:1,goal:$goal,slug:$slug,base_branch:$base,hands_off:$hands,hands_off_reason:$why,foreign_session_reason:$fs,model:$model,created_at:$at,milestones:[]}' > "$state"
    [ -n "$foreign" ] && echo "program.sh: WARN foreign session recorded (\"$foreign\") — taskmaster, task-runner and craft commands are unreachable; every phase they own runs on the fallback" >&2
    [ -f "$dir/decisions.md" ] || printf '# Decisions taken on the user'"'"'s behalf\n\nRows marked ASSUMED answer a question the user was not asked; the options column holds the reading that was NOT taken.\n\n| when | decision | options | rationale |\n| --- | --- | --- | --- |\n' > "$dir/decisions.md"
    echo "program initialised: $state (base: $base, model tier: $model)";;

  status)
    need_state
    if [ "${1:-}" = "--json" ]; then cat "$state"; exit 0; fi
    assumed=$(grep -c '^| [^|]* | ASSUMED: ' "$dir/decisions.md" 2>/dev/null || true)
    jq -r --arg assumed "${assumed:-0}" '"program: " + .goal + "  [" + .slug + "]  base: " + .base_branch + "  model: " + (.model // "opus") + (if .hands_off then "  hands-off (" + (.hands_off_reason // "no reason recorded") + ")" else "" end),
           "milestones: " + ([.milestones[]|select(.status=="done")]|length|tostring) + "/" + (.milestones|length|tostring) + " done  ·  assumed decisions: " + $assumed,
           "",
           "id\tstatus\tkind\tsize\trigour\tbranch\tdepends\tevidence\twall\ttitle",
           (.milestones[] | [.id, .status, (.kind // "feature"), (.size // "M"), (.rigour // "" | if .=="" then "-" else . end), .branch, ((.depends // [])|join(",")|if .=="" then "-" else . end),
             ((.evidence // [])|map(.kind)|unique|join(",")|if .=="" then "-" else . end),
             (((.history // []) | map(select(.status=="briefed" or .status=="building")) | .[0].at) as $s
              | ((.history // []) | map(select(.status=="done")) | .[0].at) as $e
              | if $s == null then "-" elif $e == null then "open since " + $s[11:16] + "Z"
                else ((($e|fromdate) - ($s|fromdate)) / 60 | floor | tostring) + " min" end),
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
    id=""; title=""; branch=""; depends=""; st=""; reason=""; kind="feature"; size="M"; rigour=""; newsize=""; newrig=""
    case "$sub" in
      add)
        while [ $# -gt 0 ]; do case "$1" in
          --id) id=$(arg "$1" "${2:-}") || exit 3; shift 2;; --title) title=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          --branch) branch=$(arg "$1" "${2:-}") || exit 3; shift 2;; --depends) depends=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          --kind) kind=$(arg "$1" "${2:-}") || exit 3; shift 2;; --size) size=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          --rigour) rigour=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          *) usage;; esac; done;;
      set)
        while [ $# -gt 0 ]; do case "$1" in
          --id) id=$(arg "$1" "${2:-}") || exit 3; shift 2;; --status) st=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          --reason) reason=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          --size) newsize=$(arg "$1" "${2:-}") || exit 3; shift 2;; --rigour) newrig=$(arg "$1" "${2:-}") || exit 3; shift 2;;
          --title|--branch|--depends|--kind) echo "program.sh: $1 is set only by 'milestone add'" >&2; exit 3;;
          *) usage;; esac; done;;
      *) usage;;
    esac
    [ -n "$id" ] || usage
    printf '%s' "$id" | grep -Eq '^m[0-9]+$' || { echo "program.sh: milestone id must be m<N>" >&2; exit 2; }
    case "$sub" in
      add)
        [ -n "$title" ] && [ -n "$branch" ] || usage
        has_ms "$id" && { echo "program.sh: $id already exists" >&2; exit 2; }
        kind_known "$kind" || { echo "program.sh: unknown kind '$kind' — one of: $(grep -v '^#' "$KINDS_FILE" | cut -f1 | tr '\n' ' ')" >&2; exit 2; }
        in_list "$size" $SIZES || { echo "program.sh: --size must be one of: $SIZES" >&2; exit 2; }
        [ -z "$rigour" ] || in_list "$rigour" $RIGOURS || { echo "program.sh: --rigour must be one of: $RIGOURS (dispatch-prompts.md § Rigour)" >&2; exit 2; }
        deps=$(printf '%s' "$depends" | tr ',' '\n' | sed '/^$/d' | jq -R . | jq -s 'unique')
        for d in $(printf '%s' "$depends" | tr ',' ' '); do
          [ "$d" = "$id" ] && { echo "program.sh: $id cannot depend on itself" >&2; exit 2; }
          has_ms "$d" || { echo "program.sh: dependency $d does not exist" >&2; exit 2; }
        done
        write --arg id "$id" --arg t "$title" --arg b "$branch" --arg kind "$kind" --arg size "$size" --arg rig "$rigour" --argjson deps "$deps" --arg at "$(now)" \
          '.milestones += [{id:$id,title:$t,branch:$b,kind:$kind,size:$size,rigour:$rig,depends:$deps,status:"queued",reason:"",evidence:[],history:[{status:"queued",at:$at}]}]'
        mkdir -p "$dir/milestones/$id/evidence" "$dir/milestones/$id/dispatch"
        echo "added $id ($branch, $kind, $size, rigour: ${rigour:-unset — set it from the brief before the first dispatch})";;
      set)
        has_ms "$id" || { echo "program.sh: no milestone $id" >&2; exit 2; }
        if [ -n "$newsize" ] || [ -n "$newrig" ]; then
          [ -z "$st" ] || { echo "program.sh: --size/--rigour and --status are separate calls" >&2; exit 3; }
          [ -n "$reason" ] || { echo "program.sh: re-sizing or re-rigouring needs --reason (what the brief showed that the roadmap guess did not)" >&2; exit 2; }
          [ -z "$newsize" ] || in_list "$newsize" $SIZES || { echo "program.sh: --size must be one of: $SIZES" >&2; exit 2; }
          [ -z "$newrig" ] || in_list "$newrig" $RIGOURS || { echo "program.sh: --rigour must be one of: $RIGOURS" >&2; exit 2; }
          write --arg id "$id" --arg s "$newsize" --arg rg "$newrig" --arg r "$reason" --arg at "$(now)" \
            '(.milestones[]|select(.id==$id)) |= (if $s != "" then .size=$s else . end | if $rg != "" then .rigour=$rg else . end | .history += [{at:$at, size:(if $s != "" then $s else null end), rigour:(if $rg != "" then $rg else null end), reason:$r}])'
          echo "$id → ${newsize:+size $newsize }${newrig:+rigour $newrig }($reason)"; exit 0
        fi
        in_list "$st" $STATUSES || { echo "program.sh: status must be one of: $STATUSES" >&2; exit 2; }
        [ "$st" = "done" ] && { echo "program.sh: 'done' is set only by 'accept'" >&2; exit 2; }
        [ "$st" = "parked" ] && [ -z "$reason" ] && { echo "program.sh: parked needs --reason" >&2; exit 2; }
        write --arg id "$id" --arg st "$st" --arg r "$reason" --arg at "$(now)" '(.milestones[]|select(.id==$id)) |= (.status=$st | .reason=$r | .history += [{status:$st,at:$at}])'
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
    mkind=$(jq -r --arg id "$id" '.milestones[]|select(.id==$id)|.kind // "feature"' "$state")
    # only dispatches that passed `dispatch check` and are unchanged since count: a review closed an auth milestone
    # with zero dispatch files and a hand-written pin to a path that did not exist
    dfiles=$(gated_files "$id" | tr '\n' ' ')
    if [ -z "$dfiles" ]; then
      echo "program.sh: $id NOT accepted — no gated dispatch under milestones/$id/dispatch/ (a file counts once 'dispatch check' passed it and it is unchanged since; .gated is the record)" >&2
      echo "every worker, reviewer and follow-up prompt is a dispatch file passed through: program.sh dispatch check <file> --kind <k> --milestone $id" >&2
      exit 2
    fi
    unpinned=""
    while IFS= read -r line; do case "$line" in missing*) unpinned="$unpinned ${line#missing }";; esac; done < <(pinned_groups_status "$mkind" $dfiles)
    if [ -n "$unpinned" ]; then
      echo "program.sh: $id NOT accepted — kind $mkind requires a skill from each group below, and no gated dispatch under milestones/$id/dispatch/ pins one by a path that exists:" >&2
      for g in $unpinned; do echo "  $g" >&2; done
      echo "pin it in the next dispatch (skill-path.sh <plugin> <skill>) or change the kind: this is the routing table in kinds.tsv" >&2
      exit 2
    fi
    # a walk recorded before the last worker or follow-up dispatch walked older code (simulation 4 ran three fix
    # cycles after its first browser pass); the newest gated worker file's mtime is the line every required row must be after
    lastw=""; for f in $(gated_files "$id" "worker followup"); do
      m=$(date -u -r "$f" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || continue; [ "$m" \> "$lastw" ] && lastw="$m"; done
    stale=""
    if [ -n "$lastw" ]; then
      for k in $REQUIRED_KINDS; do
        last=$(jq -r --arg id "$id" --arg k "$k" '[.milestones[]|select(.id==$id)|.evidence[]|select(.kind==$k)|.at]|max // ""' "$state")
        [ "$last" \< "$lastw" ] && stale="$stale $k"
      done
    fi
    if [ -n "$stale" ]; then
      echo "program.sh: $id NOT accepted — evidence recorded before the last gated worker dispatch ($lastw):$stale" >&2
      echo "the code changed after that walk: re-run acceptance.md for those kinds and record them again (evidence add appends; the newest row counts)" >&2
      exit 2
    fi
    nfiles=$(jq -r --arg id "$id" '[.milestones[]|select(.id==$id)|.evidence[]|select(.file!="")|.file]|unique|length' "$state")
    [ "${nfiles:-0}" -ge 2 ] || echo "program.sh: WARN $id: every evidence row points at the same file — nine kinds behind one artefact is a claim, not a record (acceptance.md: one screenshot per line)" >&2
    [ -n "$(gated_files "$id" reviewer)" ] || echo "program.sh: WARN $id: no gated reviewer dispatch (--kind reviewer) — the review step ran nowhere the record can see; a skipped review is a decisions.md row" >&2
    if jq -e '.hands_off' "$state" >/dev/null 2>&1 && ! grep -q '^| [^|]* | ASSUMED: ' "$dir/decisions.md" 2>/dev/null; then
      echo "program.sh: $id NOT accepted — hands-off program with no ASSUMED decision; record what the Clarify round would have asked:" >&2
      echo "  program.sh decision add --assumed --text \"<reading taken>\" --alternative \"<reading not taken>\" --rationale \"<why>\"" >&2
      exit 2
    fi
    write --arg id "$id" --arg at "$(now)" '(.milestones[]|select(.id==$id)) |= (.status="done" | .reason="" | .accepted_at=$at | .history += [{status:"done",at:$at}])'
    echo "$id accepted → done"
    # the size was a roadmap guess; print what it actually took next to it so the next milestone's guess has an anchor
    # (nothing scores the miss — the bands would be invented; the reader compares)
    msize=$(jq -r --arg id "$id" '.milestones[]|select(.id==$id)|.size // "M"' "$state")
    nw=$(gated_files "$id" "worker followup" | wc -l | tr -d ' '); ng=$(gated_files "$id" | wc -l | tr -d ' ')
    mbranch=$(jq -r --arg id "$id" '.milestones[]|select(.id==$id)|.branch' "$state"); mbase=$(jq -r '.base_branch' "$state")
    lines=$(git -C "$root" diff --shortstat "$mbase...$mbranch" 2>/dev/null | sed -E 's/^ *[0-9]+ files? changed,? *//; s/ insertions?\(\+\)/+/; s/ deletions?\(-\)/-/; s/, */ /g' | tr -d '\n')
    mins=$(jq -r --arg id "$id" '.milestones[]|select(.id==$id)|.history as $h | ([$h[]|select(.status=="briefed" or .status=="building")|.at]|min) as $s | ([$h[]|select(.status=="done")|.at]|max) as $e | if $s==null or $e==null then "-" else ((($e|fromdate)-($s|fromdate))/60|floor|tostring) end' "$state")
    echo "sized $msize · actual: $ng gated dispatches ($nw worker) · ${lines:-diff n/a} lines vs $mbase · $mins min"
    # the moment after accept is where simulation 4 stopped (m1 of 3 done, "resume later", nobody there): say the
    # next step here, at the decision point, not only in the skill text the model read two hours earlier
    nx=$(jq -r "$NEXT_FILTER"' | if . == null then "none" else .id + " (" + .title + ")" end' "$state")
    if [ "$nx" = none ]; then echo "next: none runnable — program.sh close (or park/unblock what remains)"
    elif jq -e '.hands_off' "$state" >/dev/null 2>&1; then echo "next: $nx — hands-off: deliver it in this session; stopping here is a decisions.md row"
    else echo "next: $nx — ask once: continue now, or /overseer:resume in a fresh session"; fi;;

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

  suggestion)
    need_state
    [ "${1:-}" = "add" ] || usage; shift
    text=""; from="-"
    while [ $# -gt 0 ]; do case "$1" in --text) text=$(arg "$1" "${2:-}") || exit 3; shift 2;; --from) from=$(arg "$1" "${2:-}") || exit 3; shift 2;; *) usage;; esac; done
    [ -n "$text" ] || usage
    [ -f "$dir/suggestions.md" ] || printf '# Deferred suggestions\n\nWhat the program saw and did not build; the user picks. One row per item, newest last.\n\n| when | from | suggestion |\n| --- | --- | --- |\n' > "$dir/suggestions.md"
    printf '| %s | %s | %s |\n' "$(now)" "$from" "$text" >> "$dir/suggestions.md"
    echo "suggestion recorded";;

  log)
    need_state
    { jq -r '.milestones[] | .id as $id | ((.history // [])[] | [.at, $id, "status → " + .status] | @tsv), ((.evidence // [])[] | [.at, $id, "evidence " + .kind + (if .file != "" then " (" + (.file|split("/")|last) + ")" else "" end)] | @tsv)' "$state"
      for f in "$dir"/milestones/*/dispatch/*.md; do [ -f "$f" ] || continue
        m=$(basename "$(dirname "$(dirname "$f")")"); printf '%s\t%s\tdispatch %s\n' "$(date -u -r "$f" +%Y-%m-%dT%H:%M:%SZ)" "$m" "$(basename "$f")"; done
      grep -E '^\| [0-9]{4}-' "$dir/decisions.md" 2>/dev/null | sed 's/^| //; s/ |$//' | awk -F' \\| ' '{printf "%s\t-\tdecision %s\n", $1, $2}'
      grep -E '^\| [0-9]{4}-' "$dir/suggestions.md" 2>/dev/null | sed 's/^| //; s/ |$//' | awk -F' \\| ' '{printf "%s\t%s\tsuggestion %s\n", $1, $2, $3}'
    } | sort | awk -F'\t' 'BEGIN{print "at\tmilestone\tevent"} {print}';;

  dispatch)
    [ "${1:-}" = "check" ] && [ -n "${2:-}" ] || usage
    f="$2"; kind="worker"; ms=""; shift 2
    while [ $# -gt 0 ]; do case "$1" in --kind) kind=$(arg "$1" "${2:-}") || exit 3; shift 2;; --milestone) ms=$(arg "$1" "${2:-}") || exit 3; shift 2;; *) usage;; esac; done
    in_list "$kind" worker reader reviewer followup || { echo "program.sh: --kind must be worker, reader, reviewer or followup" >&2; exit 2; }
    [ -f "$f" ] || { echo "program.sh: no such prompt file $f" >&2; exit 3; }
    miss=""; warn=""
    # a file under milestones/<id>/dispatch/ names its milestone; --milestone overrides (and is required elsewhere for the kind WARNs)
    [ -n "$ms" ] || ms=$(in_dispatch_dir "$(abspath "$f")")
    pre="${OVERSEER_PREAMBLE:-}"
    # resolved like a skill pin (skill-path.sh: the CLI's enabled install, else the newest cache dir that has the file) —
    # `find | sort -V | tail -1` across two marketplaces picked the alphabetically later marketplace's older version
    if [ -z "$pre" ]; then sp=$(bash "$(dirname "$0")/skill-path.sh" orchestration delegation-contracts --project "$root" 2>/dev/null) && pre="$(dirname "$sp")/references/discipline-preamble.md"; fi
    if [ "$kind" = followup ]; then
      # a message to a worker that is still alive: the preamble is already in its context, so the
      # follow-up must SAY it still binds, keep the scope lock, verify and return shape, and name the
      # dispatch file it continues — simulation 2 sent two of these with none of that recorded
      grep -qiE 'preamble' "$f" || miss="$miss
  a follow-up must say the discipline preamble still applies (it is in the worker's context, not in this file)"
      grep -qE 'TOUCH ONLY|Touch only|touch only' "$f" || miss="$miss
  no TOUCH ONLY scope lock (say 'same TOUCH ONLY set' or list the additions)"
      grep -qE '(VERIFY|Verify)' "$f" || miss="$miss
  no VERIFY command"
      grep -qE 'RETURN' "$f" || miss="$miss
  no RETURN shape"
      grep -qE '/[A-Za-z0-9_./-]+/dispatch/[A-Za-z0-9_.-]+\.md' "$f" || miss="$miss
  does not name the dispatch file it continues (…/dispatch/<n>.md, absolute)"
      [ -n "$miss" ] && { echo "program.sh: dispatch prompt $f NOT ready:$miss" >&2; exit 2; }
      echo "dispatch prompt ok (followup): $f"; exit 0
    fi
    if [ -n "$pre" ] && [ -f "$pre" ]; then
      # every line of every numbered clause, not only its first: clauses 2-9 of the canonical file span two to ten lines,
      # and "skip diagnosis and guess" on clause 2's second line passed the first-line check. Whitespace is folded so a
      # reflowed paragraph still counts as verbatim; a changed word does not.
      folded=$(tr '\n' ' ' < "$f" | tr -s '[:space:]' ' ')
      clause=""; n=0
      while IFS= read -r line; do
        if printf '%s' "$line" | grep -qE '^[0-9]+\. '; then clause="${line%%.*}"; fi
        [ -n "$clause" ] || continue
        l=$(printf '%s' "$line" | tr -s '[:space:]' ' ' | sed -E 's/^ //; s/ $//'); [ -n "$l" ] || continue
        printf '%s' "$folded" | grep -qF -- "$l" || { n=$((n+1)); [ "$n" -le 3 ] && miss="$miss
  preamble clause $clause missing or reworded: ${l:0:60}…"; }
      done < "$pre"
      [ "$n" -gt 3 ] && miss="$miss
  … and $((n-3)) more preamble lines — cat the canonical file in, never retype it"
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
    # MODEL: the seat's model, bound by the program tier — a dispatch that names none inherits the session
    # model silently, which is how simulation 3 ran its card workers on the most expensive tier without a decision
    tier="opus"; [ -s "$state" ] && tier=$(jq -r '.model // "opus"' "$state" 2>/dev/null || echo opus)
    allowed="$MODELS_OPUS"; [ "$tier" = auto ] && [ "$kind" != worker ] && allowed="$MODELS_AUTO"   # a worker never inherits: judgment seats only
    mval=$(grep -m1 -oE '^MODEL: *[a-z0-9.-]+' "$f" | sed -E 's/^MODEL: *//')
    if [ -z "$mval" ]; then miss="$miss
  no MODEL: line (tier $tier allows: $allowed) — the Agent call must pass the same value"
    elif ! in_list "$mval" $allowed; then miss="$miss
  MODEL: $mval is above the program tier '$tier' for a $kind seat (allows: $allowed) — only a reader/reviewer under --model auto may inherit the session model"
    fi
    skill_ok=0
    while IFS= read -r p; do [ -f "$p" ] && skill_ok=1 && break; done < <(grep -oE '/[^ `"'"'"'<>)]*/SKILL\.md' "$f" | sort -u)
    [ "$skill_ok" -eq 1 ] || miss="$miss
  no skill pinned by an absolute path that exists (…/SKILL.md)"
    grep -qE '(^|[[:space:]`"'"'"'(=:])/[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+' "$f" || miss="$miss
  no absolute path anywhere"
    for sf in decisions.md findings.md brief.md direction.md; do
      if grep -q "$sf" "$f" && ! grep -qE "/[A-Za-z0-9_./-]+/$sf" "$f"; then warn="$warn
  $sf is mentioned without an absolute path — the delegate cannot find it"; fi
    done
    if grep -qiE 'npm run dev|vp dev|artisan serve' "$f" && ! grep -qiE '(^|[^a-z])(stop|kill)([^a-z]|$)|public/hot' "$f"; then warn="$warn
  the prompt may start a dev server and never says to stop it"; fi
    items=$(grep -cE '^[[:space:]]*[0-9]+\. ' "$f" || true); sections=$(grep -cE '^[[:space:]]*[A-H]\. ' "$f" || true)
    # the preamble itself is nine numbered clauses; a card is dense past twelve items of its own
    if [ "$kind" = worker ] && { [ "${items:-0}" -gt 21 ] || [ "${sections:-0}" -gt 3 ]; }; then warn="$warn
  dense card: $((items-9)) numbered items / $sections lettered sections — simulation 2's densest cards are where follow-ups bypassed the gate; split per reviewer section unless the file sets overlap"; fi
    if [ -n "$ms" ] && [ -s "$state" ]; then
      has_ms "$ms" || { echo "program.sh: no milestone $ms" >&2; exit 2; }
      mkind=$(jq -r --arg id "$ms" '.milestones[]|select(.id==$id)|.kind // "feature"' "$state")
      others=$(ls "$dir/milestones/$ms/dispatch/"*.md 2>/dev/null | tr '\n' ' ')
      while IFS= read -r line; do
        case "$line" in
          missing*) warn="$warn
  kind $mkind: no gated dispatch for $ms pins ${line#missing } yet — accept will refuse until one does";;
          uninstalled*) warn="$warn
  kind $mkind: ${line#uninstalled } is not installed — record the fallback (capability-map.md) in decisions.md";;
        esac
      done < <(pinned_groups_status "$mkind" "$f" $others)
      if [ "$(jq -r '.foreign_session_reason // ""' "$state")" != "" ]; then warn="$warn
  foreign session: pipeline commands unreachable — this prompt is the fallback, say so in findings.md"; fi
      # size routes the pipeline: S may go straight to a worker; M+ is briefed to taskmaster, and the proof it was
      # is a card index newer than the brief. "The brief is so complete grill would ask nothing" is not a reason —
      # both earlier simulations said exactly that for every milestone they hand-dispatched
      msize=$(jq -r --arg id "$ms" '.milestones[]|select(.id==$id)|.size // "M"' "$state")
      mrig=$(jq -r --arg id "$ms" '.milestones[]|select(.id==$id)|.rigour // ""' "$state")
      hands=$(jq -r '.hands_off // false' "$state")
      [ -n "$mrig" ] || warn="$warn
  $ms has no rigour profile — score the brief's signals (dispatch-prompts.md § Rigour) and set it: program.sh milestone set --id $ms --rigour lean|standard|adversarial --reason \"<signals>\""
      if [ "$mrig" = lean ] && in_list "$mkind" $SURFACE_KINDS; then warn="$warn
  kind $mkind is never lean — its defects are irreversible or leak data; re-rigour to standard or adversarial"; fi
      if [ "$kind" = worker ]; then
        # the index must name this milestone (its dir or heading: 2026-09-12-m2-landing, "# m2 landing") and be newer than
        # the milestone's registration — not newer than the brief: amending the brief mid-milestone (normal) made the
        # index look stale and swapped the boost WARN for a false "pipeline skipped" one. Newest such index wins.
        idx=""; idre="(^|[^a-z0-9])$ms([^a-z0-9]|$)"
        reg=$(jq -r --arg id "$ms" '.milestones[]|select(.id==$id)|.history[0].at // ""' "$state")
        while IFS= read -r i; do
          [ ! "$(date -u -r "$i" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" \< "$reg" ] || continue
          if printf '%s\n' "$i" | grep -qE "$idre" || head -5 "$i" | grep -qE "$idre"; then
            if [ -z "$idx" ] || [ "$i" -nt "$idx" ]; then idx="$i"; fi; fi
        done < <(find "$root/taskmaster-docs/tasks" -name 00-INDEX.md 2>/dev/null)
        [ "$msize" = S ] || [ -n "$idx" ] || warn="$warn
  size $msize: $ms is briefed to taskmaster (/taskmaster:task <brief>), and no card index under taskmaster-docs/tasks/ registered after $ms names it — a direct worker here needs a decisions.md row saying why the pipeline was skipped"
        # the Ultra:/Goal: marker is taskmaster's Extreme Boost. What it buys on top of a standard run: the spec red-team
        # unconditionally (a standard run already runs it past three criteria or an ASSUMED row), coverage loop-until-dry,
        # a code red-team over the shipped diff, and tier escalation; `goal` adds autonomy. Reviewers per card and the
        # negative control are task-runner's baseline, boosted or not — 0.2.1 charged them to the boost and priced it wrong.
        # The rigour profile says whether the code red-team is worth buying here; the marker says whether it was.
        # `Goal: true (boost=off)` is taskmaster's goal-lean (≥0.42.1, task-runner ≥0.32.0): hands-off without the boost.
        if [ -n "$idx" ]; then
          if head -12 "$idx" | grep -E '^(Goal|Ultra): *true' | grep -qv 'boost=off'; then
            if in_list "$mrig" lean standard; then
              if [ "$hands" = true ]; then warn="$warn
  rigour $mrig, but the card index $idx is boosted — hands-off no longer needs the boost: brief /taskmaster:task goal-lean <brief> (taskmaster ≥0.42.1, task-runner ≥0.32.0); on an older pipeline record in decisions.md that autonomy bought the code red-team"
              else warn="$warn
  rigour $mrig, but the card index $idx carries an Ultra:/Goal: marker — the code red-team was bought where the profile says not to; brief /taskmaster:task <brief> without the token, or re-rigour with the signal that changed"; fi
            fi
          elif [ "$mrig" = adversarial ]; then warn="$warn
  rigour adversarial, but the card index $idx carries no Ultra: marker (or a Goal: boost=off one) — brief /taskmaster:task ultra <brief> (interactive) or goal, never goal-lean (hands-off), or drive the code red-team yourself (dispatch-prompts.md § Rigour) and record it"
          fi
        fi
      fi
    fi
    [ -n "$warn" ] && echo "program.sh: dispatch prompt $f WARN:$warn" >&2
    if [ -n "$miss" ]; then echo "program.sh: dispatch prompt $f NOT ready:$miss" >&2; exit 2; fi
    # the record accept reads: checksum + kind + basename, appended (the last row per file wins); only a file that lives
    # under its milestone's dispatch/ dir can be gated — a prompt checked elsewhere passes but is not a milestone dispatch
    fa=$(abspath "$f"); [ -z "$(in_dispatch_dir "$fa")" ] || printf '%s %s %s\n' "$(cksum < "$f" | cut -d' ' -f1)" "$kind" "$(basename "$f")" >> "$(dirname "$fa")/.gated"
    echo "dispatch prompt ok ($kind): $f";;

  close)
    need_state
    divok=""
    while [ $# -gt 0 ]; do case "$1" in --divergent-ok) divok=$(arg "$1" "${2:-}") || exit 3; shift 2;; *) usage;; esac; done
    if jq -e '[.milestones[]|select(.status!="done" and .status!="parked")]|length>0' "$state" >/dev/null; then
      echo "program.sh: cannot close — milestones still open (not done/parked): $(jq -r '[.milestones[]|select(.status!="done" and .status!="parked")|.id]|join(" ")' "$state")" >&2; exit 2
    fi
    # divergence: two done branches that contain neither the other were never seen in one tree
    # (simulation 2 closed with the homepage from master and the board from m1 never combined)
    if [ -z "$divok" ] && ! jq -e '[.milestones[]|select(.status=="done" and .kind=="integration")]|length>0' "$state" >/dev/null; then
      div=""
      for a in $(jq -r '.milestones[]|select(.status=="done")|.branch' "$state"); do
        for b in $(jq -r '.milestones[]|select(.status=="done")|.branch' "$state"); do
          [ "$a" \< "$b" ] || continue
          git -C "$root" rev-parse --verify -q "$a" >/dev/null && git -C "$root" rev-parse --verify -q "$b" >/dev/null || continue
          git -C "$root" merge-base --is-ancestor "$a" "$b" 2>/dev/null || git -C "$root" merge-base --is-ancestor "$b" "$a" 2>/dev/null || div="$div ${a}<->${b}"
        done
      done
      if [ -n "$div" ]; then
        echo "program.sh: cannot close — done milestones on branches that contain neither the other:$div" >&2
        echo "  the product has never been walked in one tree: add a milestone --kind integration (merge, walk across features, accept), or close --divergent-ok \"<why the user merges later>\" (recorded in decisions.md)" >&2; exit 2
      fi
    fi
    [ -n "$divok" ] && printf '| %s | %s | %s | %s |\n' "$(now)" "closed with divergent done branches" "-" "$divok" >> "$dir/decisions.md"
    # plugins pinned in dispatches vs plugins the scan found installed — what strength was left on the table
    if [ -f "$dir/capabilities.tsv" ]; then
      avail=$(grep -v '^#' "$dir/capabilities.tsv" | awk -F'\t' 'NR>1 && $2!="-" {print $2}' | tr ',' '\n' | sed '/^$/d' | sort -u)
      # a pinned skill path names its plugin; an agent type (AGENT: task-runner:task-executor) names its plugin before the colon
      used=$( { cat "$dir"/milestones/*/dispatch/*.md 2>/dev/null | grep -oE '/plugins/cache/[^/]+/[a-z0-9-]+/' | awk -F/ '{print $5}'
                grep -hoE '^AGENT: *[a-z0-9-]+:' "$dir"/milestones/*/dispatch/*.md 2>/dev/null | sed -E 's/^AGENT: *//; s/:$//'; } | sort -u)
      [ -n "$avail" ] && echo "plugins installed per the scan: $(printf '%s\n' "$avail" | wc -l | tr -d ' ') · pinned in a dispatch: $(printf '%s\n' "$used" | sed '/^$/d' | wc -l | tr -d ' ') · never pinned: $(comm -23 <(printf '%s\n' "$avail") <(printf '%s\n' "$used") | tr '\n' ' ')"
    fi
    [ -f "$dir/suggestions.md" ] && { echo "deferred suggestions ($(grep -cE '^\| [0-9]{4}-' "$dir/suggestions.md")):"; grep -E '^\| [0-9]{4}-' "$dir/suggestions.md" | sed 's/^| //; s/ |$//' | awk -F' \\| ' '{print "  " $2 ": " $3}'; }
    slug=$(jq -r .slug "$state"); at=$(jq -r .created_at "$state" | tr -d ':')
    arch="$dir/archive/$slug-$at"
    mkdir -p "$arch"
    mv "$state" "$arch/program.json"
    # other plugins' hooks (candor, comment-discipline) key their scratch dir on the edited file's directory and
    # leave .claude/ dirs under dispatch/; they are never overseer's and do not belong in the record
    find "$dir/milestones" -type d -name .claude -prune -exec rm -rf {} + 2>/dev/null
    [ -d "$dir/milestones" ] && mv "$dir/milestones" "$arch/milestones"
    # evidence rows hold absolute paths under $dir/milestones; the archive is the record a reader
    # follows, so every path is rewritten to where the file now lives (checked by the harness)
    phys=$(cd "$dir" && pwd -P)   # evidence add stores the physical path; $dir may be the logical one (macOS /var vs /private/var)
    jq --arg a "$dir/milestones/" --arg b "$phys/milestones/" --arg to "$(cd "$arch" && pwd -P)/milestones/" \
      '(.milestones[].evidence[].file) |= (if startswith($a) then $to + .[($a|length):] elif startswith($b) then $to + .[($b|length):] else . end)' \
      "$arch/program.json" > "$arch/program.json.tmp" && mv "$arch/program.json.tmp" "$arch/program.json"
    for f in charter.md discovery.md capabilities.tsv decisions.md suggestions.md; do [ -f "$dir/$f" ] && cp "$dir/$f" "$arch/$f"; done
    mkdir -p "$dir/milestones"
    echo "program closed → $arch (decisions.md kept in place; init may start a new program)";;

  *) usage;;
esac
