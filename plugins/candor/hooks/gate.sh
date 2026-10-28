#!/bin/bash
# Stop and SubagentStop: refuses a turn end (Stop: JSON block; SubagentStop: exit 2) for one clause per stop, tried 4, 1, 2, 3, 5: an incomplete registered task-runner run, a file:line resolving to nothing, a reversal after bare pushback, a naked completion claim, lockfile drift.
# Misses a wrong API, flag or directory, pushback outside its list, entries before the transcript tail, unmatched dependency lines, a UI card with no review diff; blocks on a citation into a file the turn shortened, renamed or deleted. Fail-open. Off: CC_CANDOR_GATE=off|warn (all), CC_EVIDENCE_GATE=off|warn (3), TASK_RUNNER_STOP_GATE=off|warn (4), CC_LOCKFILE_GATE=off (5); unset, /config.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/gate.sh

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

# Clause 1's lookup, shared with /candor:check. A missing file stands the clause down; it never fails the gate.
. "$(dirname "$0")/cite.sh" 2>/dev/null

INFLIGHT_TTL_MIN=180
# Only for a running.pid with no deadline: seven built-in runners at task-runner's 1800 s suite cap run 210 minutes.
BG_PID_TTL_MIN=240
DISCLOSURE_TAIL_LINES=200
TRANSCRIPT_TAIL_LINES=4000
MAX_CITATIONS_CHECKED=25
BARE_PUSHBACK_MAX_BYTES=400
CLAIM_WINDOW_LINES=30

input=$(cat)

have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1
evt="Stop"; agent_id=""; sid=""
if [ "$have_jq" = 1 ]; then
  evt=$(printf '%s' "$input" | jq -r '.hook_event_name // "Stop"' 2>/dev/null)
  agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
fi
# Not enforcement, so before the off switch: a record kept while the gate was off would hold clause 4's no-gate-pass block silent.
inflight_dir=""; inflight_rec=""
[ -n "$sid" ] && inflight_dir="${TMPDIR:-/tmp}/cc-candor-inflight-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
if [ "$evt" = "SubagentStop" ] && [ -n "$inflight_dir" ] && [ -n "$agent_id" ]; then
  inflight_rec="$inflight_dir/$(printf '%s' "$agent_id" | cksum | cut -d' ' -f1)"
  if [ -f "$inflight_rec" ]; then rm -f "$inflight_rec" 2>/dev/null; else inflight_rec=""; fi
fi

gate_mode=$(cc_option CC_CANDOR_GATE block)
case "$gate_mode" in off) exit 0 ;; esac

[ "$have_jq" = 1 ] || { echo "[candor] jq not found, so the Stop check is not enforced." >&2; exit 0; }

sha_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
# -d, not -n: the payload cwd is a host string, and the state mkdir below must never recreate a project the user deleted.
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"
root=$(cc_state_root "$cwd") || exit 0
# Per-agent marker suffix: hashed, so the id never lands raw in a path.
agent_sfx=""
[ -n "$agent_id" ] && agent_sfx="-$(printf '%s' "$agent_id" | cksum | cut -d' ' -f1)"

# The host's stop_hook_active is shared by every Stop hook: only the clause this gate recorded as blocking stands down on its continuation.
state_dir=$(cc_plugin_state "$root" candor)
claimed="$state_dir/blocked$agent_sfx"
skip=""
if [ "$sha_active" = "true" ] && [ -f "$claimed" ]; then
  skip=$(cat "$claimed" 2>/dev/null)
  rm -f "$claimed" 2>/dev/null
fi

verdict=""
detail=""
run_msg=""
run_note=""
run_owed=""
run_items=""
run_labels=""
run_count=0
notes=""
pass_note=""

# A note printed before a later clause blocks still reaches the model: block_turn puts it in front of the reason.
say() { printf '%s\n' "$1" >&2; notes="$notes$1
"; }

# Stop: the host shows systemMessage to the person and feeds reason to the model; a SubagentStop systemMessage stays in the agent's own transcript, so that event keeps exit 2.
block_turn() { # <reason> <one plain line for the person>
  if [ "$evt" = "SubagentStop" ]; then printf '%s\n' "$1" >&2; exit 2; fi
  jq -cn --arg r "$notes$1" --arg m "$2" '{decision:"block",reason:$r,systemMessage:$m}'
  exit 0
}

# Every passing exit once clause 4 has run: shows the person what the run still owes, with no decision key, so it cannot block.
pass_turn() {
  [ -z "$pass_note" ] || jq -cn --arg m "$pass_note" '{systemMessage:$m}'
  exit 0
}

run_item() { # <short label for the person> <action line for the model>
  run_labels="$run_labels${run_labels:+, }$1"
  run_items="$run_items
  - $2"; run_count=$((run_count + 1)); }

inflight_count() {
  local n
  n=$(printf '%s' "$input" | jq -r 'if (.background_tasks | type) == "array"
        then [.background_tasks[] | select(.type == "subagent" or .type == "teammate")] | length
        else "absent" end' 2>/dev/null)
  case "$n" in '' | absent | *[!0-9]*) ;; *) printf '%s' "$n"; return 0 ;; esac
  # -O: a records dir another user created under a shared /tmp is not evidence.
  if [ -n "$inflight_dir" ] && [ -d "$inflight_dir" ] && [ -O "$inflight_dir" ]; then
    find "$inflight_dir" -type f -mmin +"$INFLIGHT_TTL_MIN" -delete 2>/dev/null
    find "$inflight_dir" -type f ! -mmin +"$INFLIGHT_TTL_MIN" 2>/dev/null | wc -l | tr -d ' '
  else
    printf '0'
  fi
}

# bg/running.pid (PID, HEAD, optional deadline) is one worker while its sha is <head>, its deadline unpassed (none: younger than BG_PID_TTL_MIN) and live: with /proc, the PID's or else any <root> process's command line names behavioral-gate.sh (a sandbox records its own namespace's PID); [e] stops the scan's grep matching itself.
# Misses: without /proc liveness is kill -0, so a recycled PID at the same HEAD holds until the deadline or the file ages out.
bg_running() { # <head> -> 1 or 0
  local f="$root/.claude/task-runner/bg/running.pid" pid="" sha="" dl="" rp p
  if [ -r "$f" ]; then
    { read -r pid || :; read -r sha || :; read -r dl || :; } < "$f"
    case "$dl" in
      '' | *[!0-9]*) [ -z "$(find "$f" -mmin +"$BG_PID_TTL_MIN" 2>/dev/null)" ] || pid="" ;;
      *) [ "$(date +%s)" -lt "$dl" ] 2>/dev/null || pid="" ;;
    esac
    case "$pid" in '' | *[!0-9]*) pid="" ;; esac
    case "$sha" in '' | *[!0-9a-f]*) sha="" ;; esac
    if [ -n "$pid" ] && [ "${#sha}" -ge 7 ]; then
      case "$1" in "$sha"*)
        if [ ! -d /proc/self ]; then kill -0 "$pid" 2>/dev/null && { printf '1'; return 0; }
        else
          grep -qsE 'behavioral-gat[e]\.sh' "/proc/$pid/cmdline" && { printf '1'; return 0; }
          rp=$(cd "$root" 2>/dev/null && pwd -P)
          for p in $(grep -lsE 'behavioral-gat[e]\.sh' /proc/[0-9]*/cmdline 2>/dev/null); do
            case "$(readlink "${p%/cmdline}/cwd" 2>/dev/null)/" in "$root"/* | "${rp:-$root}"/*) printf '1'; return 0 ;; esac
          done
        fi ;;
      esac
    fi
  fi
  printf '0'
}

run_clause() {
  local sentinel="$root/.claude/task-runner/active-run.json"
  [ "$evt" != "SubagentStop" ] || return 0
  case "$(cc_option TASK_RUNNER_STOP_GATE block)" in off) return 0 ;; esac
  # A run closes by renaming its sentinel (run.md step 4), so the stop after the report still reads its records; a clean read retires it.
  [ -r "$sentinel" ] || sentinel="$root/.claude/task-runner/closed-run.json"
  [ -r "$sentinel" ] || return 0
  jq empty "$sentinel" 2>/dev/null || { say "[candor] .claude/task-runner/active-run.json is malformed, so the task-runner run is not checked."; return 0; }
  command -v git >/dev/null 2>&1 || { say "[candor] git not found, so the task-runner run is not checked."; return 0; }
  local head run_branch cur_branch slug
  head=$(git -C "$root" rev-parse HEAD 2>/dev/null) || { say "[candor] Not a git repository, so the task-runner run is not checked."; return 0; }
  # A closed run whose gate pass names an earlier HEAD closed there, and its closing stop never reached this clause.
  local closed_at
  case "$sentinel" in */closed-run.json)
    closed_at=$(jq -r '.head // empty' "$root/.claude/task-runner/gate-pass.json" 2>/dev/null)
    if [ -n "$closed_at" ] && [ "$closed_at" != "$head" ]; then rm -f "$sentinel" 2>/dev/null; return 0; fi ;;
  esac

  # An abandoned run leaves its sentinel behind: a run that names its branch is enforced only on that branch.
  run_branch=$(jq -r '.branch // empty' "$sentinel" 2>/dev/null)
  # symbolic-ref, not rev-parse --abbrev-ref: a tag named like the branch prints heads/<branch>. Exit 1 is a detached head; any other failure leaves the branch unknown, which never stands a run down.
  cur_branch=$(git -C "$root" symbolic-ref -q HEAD 2>/dev/null)
  case $? in 0) cur_branch=${cur_branch#refs/heads/} ;; 1) cur_branch=HEAD ;; *) cur_branch="" ;; esac
  if [ -n "$run_branch" ] && [ -n "$cur_branch" ] && [ "$run_branch" != "$cur_branch" ]; then
    say "$(printf '[candor] The task-runner run was registered on branch %s and you are on %s, so it is not checked here.\n  If that run is finished or abandoned, delete .claude/task-runner/%s.' "$run_branch" "$cur_branch" "${sentinel##*/}")"
    return 0
  fi
  RUN_HEAD="$head"; RUN_SENTINEL="$sentinel"
  slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)

  local gatepass="$root/.claude/task-runner/gate-pass.json" v ct cdone cpark
  if [ -r "$gatepass" ] && [ "$(jq -r '.head // empty' "$gatepass" 2>/dev/null)" = "$head" ]; then
    v=$(jq -r '
      if ((.cards_total|type)=="number" and (.cards_done|type)=="number" and (.cards_parked|type)=="number")
      then (if (.cards_done + .cards_parked) < .cards_total then "incomplete"
            elif (.cards_done + .cards_parked) > .cards_total then "malformed"
            else "complete" end)
      elif ((has("cards_total") or has("cards_done") or has("cards_parked")) | not) then "absent"
      else "malformed" end' "$gatepass" 2>/dev/null)
    if [ "$v" = "absent" ] && [ "$(jq -r 'has("index_path")' "$sentinel" 2>/dev/null)" = "true" ]; then
      v="malformed"
    fi
    if [ "$v" = "incomplete" ] || [ "$v" = "malformed" ]; then
      ct=$(jq -r '.cards_total' "$gatepass" 2>/dev/null)
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      cpark=$(jq -r '.cards_parked' "$gatepass" 2>/dev/null)
      run_item "card counts that add up" "$(printf 'Finish or park every card, then record the three counts in .claude/task-runner/gate-pass.json as numbers that add up (now %s: done=%s parked=%s total=%s).' "$v" "$cdone" "$cpark" "$ct")"
    fi
    # Only records newer than this registration count: card ids repeat across runs, and these dirs are never cleared.
    local ncdir="$root/.claude/task-runner/nc" nc_count
    if [ "$v" = "complete" ] && [ -d "$ncdir" ]; then
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      nc_count=$(find "$ncdir" -maxdepth 1 \( -name 'nc-pass-*.json' -o -name 'nc-skip-*.json' \) -newer "$sentinel" 2>/dev/null |
        sed -E 's#.*/nc-(pass|skip)-##; s#\.json$##' | sort -u | wc -l | tr -d ' ')
      if [ "$nc_count" -lt "$cdone" ] 2>/dev/null; then
        run_item "checks that tests fail without the change" "$(printf 'Run the missing checks that a card'"'"'s test fails without the change (%s cards done, only %s have one in .claude/task-runner/nc/) with task-runner'"'"'s scripts/negative-control.sh --record-dir .claude/task-runner/nc --card <id>, or record a skip with its reason (--skip "<why>").' "$cdone" "$nc_count")"
      fi
    fi
    local rvdir="$root/.claude/task-runner/rv" rv_count
    if [ "$v" = "complete" ] && [ -d "$rvdir" ]; then
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      rv_count=$(find "$rvdir" -maxdepth 1 \( -name 'rv-seen-*.json' -o -name 'rv-skip-*.json' -o -name 'rv-exempt-*.json' \) -newer "$sentinel" 2>/dev/null |
        sed -E 's#.*/rv-(seen|skip|exempt)-##; s#\.json$##' | grep -v '^range-' | sort -u | wc -l | tr -d ' ')
      if [ "$rv_count" -lt "$cdone" ] 2>/dev/null; then
        run_item "card reviews" "$(printf 'Dispatch the missing reviews (%s cards done, only %s have a review recorded in .claude/task-runner/rv/) as task-runner'"'"'s skills/task-execution/references/reviewer-routing.md (Coverage marker) describes, or record why not with scripts/review-skip.sh --card <id> --reason "<why>" (or --exempt no-reviewer-installed).' "$cdone" "$rv_count")"
      fi
    fi
    # A card whose review diff (task-runner's review-diff.sh) names a UI file owes ui-ux-reviewer: the count above let any reviewer stand in.
    local pf card uicards=""
    if [ "$v" = "complete" ] && [ -d "$rvdir" ]; then
      while IFS= read -r pf; do
        # Tests and stories are not UI: reviewer-routing sends a test-only card to code-reviewer alone.
        grep -E '^diff --git a/.* b/.*\.(tsx|jsx|vue|svelte|css|scss|sass|less|blade\.php)$' "$pf" 2>/dev/null |
          grep -qvE '/(__tests__|tests)/|\.(test|spec|stories)\.[^/]*$' || continue
        card=${pf##*/diff-}; card=${card%.patch}
        [ -n "$(find "$rvdir" -maxdepth 1 \( -name "rv-agent-$card@*ui-ux-reviewer.json" -o -name "rv-skip-$card.json" -o -name "rv-exempt-$card.json" \) -newer "$sentinel" 2>/dev/null)" ] ||
          uicards="$uicards $card"
      done < <(find "$rvdir" -maxdepth 1 -name 'diff-*.patch' -newer "$sentinel" 2>/dev/null | sort)
      if [ -n "$uicards" ]; then
        run_item "UI reviews" "$(printf 'Dispatch ui-ux:ui-ux-reviewer (no other reviewer counts) for each card that changed UI files and has no ui-ux-reviewer review recorded:%s, as task-runner'"'"'s skills/task-execution/references/reviewer-routing.md (Coverage marker) describes, or record why not with scripts/review-skip.sh --card <id> --reason "<why>" (or --exempt no-reviewer-installed).' "$uicards")"
      fi
    fi
    # A run with start_sha owes one whole-range review at this HEAD (rv-observe records it from RV-RANGE); after a commit, `from` is the newest reviewed ancestor, so only the commits since it are owed.
    local start_sha rf rid range_ok=0 from
    start_sha=$(jq -r '.start_sha // empty' "$sentinel" 2>/dev/null); from=$start_sha
    if [ -n "$start_sha" ] && [ -d "$rvdir" ]; then
      while IFS= read -r rf; do
        rid=${rf##*range-}; rid=${rid%.json}
        case "$rid" in '' | *[!0-9a-f]*) continue ;; esac
        [ "${#rid}" -ge 7 ] || continue
        case "$head" in "$rid"*) range_ok=1; break ;; esac
        case "$rf" in */range-*) git -C "$root" merge-base --is-ancestor "$rid" HEAD 2>/dev/null &&
          git -C "$root" merge-base --is-ancestor "$from" "$rid" 2>/dev/null && from=$rid ;; esac
      done < <(find "$rvdir" -maxdepth 1 \( -name 'range-*.json' -o -name 'rv-skip-range-*.json' -o -name 'rv-exempt-range-*.json' \) -newer "$sentinel" 2>/dev/null)
      if [ "$range_ok" = 0 ]; then
        run_item "the whole-diff review" "$(printf 'Run /code-review:review %s..HEAD with "RV-RANGE: %s" in its arguments (task-runner'"'"'s run.md step 4), as there is no whole-diff review recorded for HEAD %s, or record why it cannot run with scripts/review-skip.sh --card range-%s --reason "<why>" (or --exempt no-reviewer-installed).' "${from:0:12}" "${head:0:12}" "${head:0:12}" "${head:0:12}")"
      fi
    fi
    # Of the red verdicts only no-behavioral-coverage may pass, beside this HEAD's coverage reduction, which the report must then name.
    local bgdir="$root/.claude/task-runner/bg" bgv covred
    if [ "$v" = "complete" ] && [ -d "$bgdir" ]; then
      if [ ! -r "$bgdir/bg-$head.json" ]; then
        run_item "a behavioral-gate verdict" "$(printf 'Run task-runner'"'"'s scripts/behavioral-gate.sh against HEAD %s: gate-pass.json names it, but behavioral-gate.sh left no verdict record for it (.claude/task-runner/bg/bg-<head>.json).' "${head:0:12}")"
      else
        bgv=$(jq -r '.verdict // empty' "$bgdir/bg-$head.json" 2>/dev/null)
        case "$bgv" in covered | no-executable-surface | '') bgv="" ;; esac
        covred="$root/.claude/task-runner/reductions/coverage-bg-${head:0:12}.json"
        if [ "$bgv" = "no-behavioral-coverage" ] && [ -f "$covred" ] && [ "$covred" -nt "$sentinel" ]; then
          bgv=""
        fi
        if [ "$bgv" = "no-behavioral-coverage" ]; then
          run_item "tests for the changed files" "$(printf 'Add tests a runner here executes and re-run behavioral-gate.sh, which reached "no-behavioral-coverage" for HEAD %s (no test in this project exercises the files the run changed). Or, if that coverage is out of scope: from the repo root run task-runner'"'"'s scripts/reduction-record.sh --kind coverage --id bg-%s --reason "<which files no runner covers, and why>", and name bg-%s and that reason in your closing report.' "${head:0:12}" "${head:0:12}" "${head:0:12}")"
        elif [ -n "$bgv" ]; then
          run_item "a passing behavioral gate" "$(printf 'Fix what behavioral-gate.sh reports and re-run it: it reached "%s" for HEAD %s.' "$bgv" "${head:0:12}")"
        fi
      fi
    fi
    # A boosted run owes the panel unless its diff since the run's base is docs and data only; a missing or unknown base counts as code.
    local rtdir="$root/.claude/task-runner/rt" idx idxp boosted run_base code_touched lenses critic degraded
    if [ "$v" = "complete" ] && [ -d "$rtdir" ]; then
      idx=$(jq -r '.index_path // empty' "$sentinel" 2>/dev/null)
      boosted=0
      case "$idx" in /*) idxp="$idx" ;; *) idxp="$root/$idx" ;; esac
      if [ -n "$idx" ] && [ -r "$idxp" ]; then
        # a Goal: line carrying boost=off (taskmaster goal-lean) is hands-off without the boost
        grep -iE '^[[:space:]]*(Ultra|Goal):[[:space:]]*true' "$idxp" 2>/dev/null | grep -qv 'boost=off' && boosted=1
      fi
      if [ "$boosted" = 1 ]; then
        run_base=$(jq -r '.base // empty' "$sentinel" 2>/dev/null)
        code_touched=unknown
        if [ -n "$run_base" ] && git -C "$root" rev-parse --verify "$run_base" >/dev/null 2>&1; then
          if git -C "$root" diff --name-only "$run_base..HEAD" 2>/dev/null |
               grep -qvE '\.(md|txt|json|ya?ml|lock|csv|svg|png|jpe?g|gif)$|^$'; then
            code_touched=yes
          else
            code_touched=no
          fi
        fi
        [ "$code_touched" = "no" ] && boosted=0
      fi
      if [ "$boosted" = 1 ]; then
        lenses=$(find "$rtdir" -maxdepth 1 -name 'rt-lens-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
        critic=$(find "$rtdir" -maxdepth 1 -name 'rt-critic-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
        degraded=$(find "$root/.claude/task-runner/reductions" -maxdepth 1 -name 'redteam-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$degraded" -eq 0 ] 2>/dev/null && { [ "$lenses" -lt 3 ] || [ "$critic" -lt 1 ]; } 2>/dev/null; then
          run_item "the red-team panel" "$(printf 'Dispatch the missing red-team agents as task-runner'"'"'s code-redteam skill describes, or record a reduced inline pass with scripts/reduction-record.sh --kind redteam --id <ref> --reason "<why>": the run is marked for max effort (Ultra or Goal in its index) and the red-team panel is short (%s of 3 refuters, %s of 1 completeness critic).' "$lenses" "$critic")"
        fi
      fi
    fi
    local ids tp said missing id
    if [ "$v" = "complete" ]; then
      ids=$(find "$rvdir" -maxdepth 1 -name 'rv-skip-*.json' -newer "$sentinel" 2>/dev/null |
              sed -E 's|.*/rv-skip-||; s|\.json$||'
            find "$root/.claude/task-runner/reductions" -maxdepth 1 -name '*.json' -newer "$sentinel" 2>/dev/null |
              sed -E 's|.*/[a-z]+-||; s|\.json$||')
      ids=$(printf '%s\n' "$ids" | sed '/^$/d' | sort -u)
      if [ -n "$ids" ]; then
        tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
        if [ -n "$tp" ] && [ -r "$tp" ]; then
          said=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$tp" 2>/dev/null | tail -"$DISCLOSURE_TAIL_LINES")
          missing=""
          for id in $ids; do
            printf '%s' "$said" | grep -qF "$id" || missing="$missing $id"
          done
          if [ -n "$said" ] && [ -n "$missing" ]; then
            run_item "naming skipped steps in the report" "$(printf 'Name each skipped or reduced step the closing report never names, and why it was cut:%s (details in .claude/task-runner/rv/ and reductions/).' "$missing")"
          fi
        fi
      fi
    fi
    if [ "$run_count" -gt 0 ]; then
      local things=things; [ "$run_count" -eq 1 ] && things=thing
      run_msg=$(printf '[candor] Not finished: %s %s must be done before the task-runner run %s can close:%s' "$run_count" "$things" "$slug" "$run_items")
      run_note="candor sent the turn back: $run_count $things to do before the task-runner run $slug can close."
      run_owed="candor let the turn end, but the task-runner run $slug still owes $run_count $things: $run_labels."
      verdict="run"; return 0
    fi
    case "$sentinel" in */closed-run.json) rm -f "$sentinel" 2>/dev/null ;; esac
    return 0
  fi

  # Mid-run and end-of-run look alike, so the message names both; workers in flight: print, block nothing and write no nudge, keeping this HEAD's one block for after the last hand-back.
  local waiting
  waiting=$(inflight_count)
  case "$waiting" in '' | *[!0-9]*) waiting=0 ;; esac
  waiting=$((waiting + $(bg_running "$head")))
  if [ "${waiting:-0}" -gt 0 ] 2>/dev/null; then
    say "$(printf '[candor] The task-runner run %s is not finished, but %s background worker(s) are still running, so this stop is allowed.\n  The check runs again when the last worker reports back.' "$slug" "$waiting")"
    return 0
  fi
  run_msg=$(printf '[candor] The task-runner run %s is not finished: HEAD %s has no recorded pass of behavioral-gate.sh, so do not end the turn here.
  Cards left: start the next card with a tool call now; naming it in prose and stopping leaves the user waiting.
  Need a decision: ask it with AskUserQuestion. Blocked: park the card with a reason.
  Every card done or parked: run the whole-diff review, then from the
    repo root, in the background, run task-runner'"'"'s scripts/behavioral-gate.sh --isolate --changed "<the run'"'"'s touched
    files>" with a Bash timeout of 7200000 (the default can stop it at 30 minutes). --isolate makes and removes its
    own worktree: do not build a checkout or write any .env for it.
    Then write .claude/task-runner/gate-pass.json as {"head":"%s"} plus the card counts, and rename
    active-run.json to closed-run.json (run.md step 4). The repo'"'"'s own test suite passing does not replace this.
  No rush: run one shell step per call and read its result; a denied or failed call ran nothing.
  Not running this task list? The run file is left over: delete .claude/task-runner/%s.' "$slug" "${head:0:12}" "$head" "${sentinel##*/}")
  run_note="candor sent the turn back: the task-runner run $slug is not finished."
  run_owed="candor let the turn end, but the task-runner run $slug still owes a recorded behavioral-gate pass for this commit."
  verdict="run"
}
RUN_HEAD=""; RUN_SENTINEL=""
run_clause

if [ "$verdict" = "run" ]; then
  run_mode="$gate_mode"
  case "$(cc_option TASK_RUNNER_STOP_GATE block)" in warn) run_mode=warn ;; esac
  # The switch is named here, the one print site of every clause-4 reason: a blocked reader sees only this text.
  run_msg="$run_msg
  TASK_RUNNER_STOP_GATE=off turns this check off (=warn only prints)."
  if [ "$run_mode" = "block" ]; then
    # One block per HEAD: the nudge counts only while newer than the sentinel, so an earlier run's marker cannot eat this one's block.
    nudge="$root/.claude/task-runner/gate-nudge"
    if [ -r "$nudge" ] && [ "$nudge" -nt "$RUN_SENTINEL" ] && [ "$(cat "$nudge" 2>/dev/null)" = "$RUN_HEAD" ]; then
      pass_note="$run_owed"               # bounded at this HEAD — printed, not blocked
    elif printf '%s' "$RUN_HEAD" > "$nudge" 2>/dev/null; then
      block_turn "$run_msg" "$run_note"
    elif [ "$sha_active" != "true" ]; then
      # No writable marker, so no per-HEAD bound: honour the shared flag here only, or an unwritable state dir blocks forever.
      block_turn "$run_msg" "$run_note"
    fi
  fi
  say "$run_msg"
  # Clause 4 spoke without blocking; a run held once at this HEAD still gets clauses 1-3 and 5 on every stop.
  verdict=""; run_msg=""
fi

read_transcript() {
  # A subagent's report lives in its own transcript; the parent's path is the fallback for a payload without one.
  tp=$(printf '%s' "$input" | jq -r '.agent_transcript_path // .transcript_path // empty' 2>/dev/null)
  tail_jsonl=""
  if [ -n "$tp" ] && [ -r "$tp" ]; then
    tail_jsonl=$(tail -n "$TRANSCRIPT_TAIL_LINES" "$tp" 2>/dev/null)
  fi

  handback=""
  if [ "$evt" = "SubagentStop" ]; then
    [ -n "$tail_jsonl" ] && handback=$(printf '%s' "$tail_jsonl" | jq -rs --arg n "SubagentHandback" '
      def usertext: .type=="user" and (.isCompactSummary|not) and ((.message.content // null) as $c
        | if ($c|type)=="string" then $c
          elif ($c|type)=="array" and (any($c[]; .type=="tool_result")|not) then [$c[] | select(.type=="text") | .text][0]
          else null end
        | type=="string" and (test("^\\s*(<system-reminder>|<task-notification>|\\[SYSTEM NOTIFICATION|Stop hook feedback:)")|not));
      . as $e | ([range(0; length) | select($e[.] | usertext)] | last // -1) as $b
      | [ $e[$b+1:][] | select(.type=="assistant") | (.message.content // [])[]
            | select(.type=="tool_use" and .name==$n) | .input.message // empty
            | select(type=="string" and length>0) ] | last // empty' 2>/dev/null)
  fi

  # A malformed JSONL line empties the -s slurp, which fails open: hence each fallback tests for empty.
  last_msg=$handback
  [ -n "$last_msg" ] || last_msg=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty' 2>/dev/null)
  [ -n "$last_msg" ] || [ -z "$tail_jsonl" ] || last_msg=$(printf '%s' "$tail_jsonl" | jq -rs '
    [ .[] | select(.type=="assistant")
          | ((.message.content // []) | map(select(.type=="text") | .text) | join("\n"))
          | select(length > 0) ] | last // empty' 2>/dev/null)
}
read_transcript

clause_fabricated_citation() {
  [ -z "$verdict" ] && [ -n "$last_msg" ] && [ "$skip" != "citation" ] || return 0
  command -v cite_miss >/dev/null 2>&1 || { say "[candor] hooks/cite.sh not loaded, so file:line citations are not checked."; return 0; }
  # hooks/cite.sh: what counts as a citation (a dev host's :port does not) and when one is fabricated (its header has the limits).
  cites=$(printf '%s' "$last_msg" | cite_extract)
  misses=""
  checked=0
  for c in $cites; do
    [ "$checked" -ge "$MAX_CITATIONS_CHECKED" ] && break
    checked=$((checked + 1))
    r=$(cite_miss "$c" "$root" "$cwd")
    [ -n "$r" ] && misses="$misses
  - $c — $r"
  done

  if [ -n "$misses" ]; then
    verdict="citation"
    detail="$misses"
  fi
}
clause_fabricated_citation

clause_unevidenced_reversal() {
  [ -z "$verdict" ] && [ -n "$last_msg" ] && [ -n "$tail_jsonl" ] && [ "$evt" != "SubagentStop" ] && [ "$skip" != "reversal" ] || return 0
  # Tool results arrive as type "user" with no text block, so selecting text excludes them.
  last_user=$(printf '%s' "$tail_jsonl" | jq -rs '
    [ .[] | select(.type=="user")
          | (if (.message.content | type) == "string" then .message.content
             else ((.message.content // []) | map(select(.type=="text") | .text) | join("\n")) end)
          | select(length > 0) ] | last // empty' 2>/dev/null)

  PUSHBACK='are you sure|you sure|are you certain|is that (right|true|correct|actually)|that.?s (not right|wrong|incorrect|false|not true)|that is (not right|wrong|incorrect|false)|you.?re (wrong|mistaken)|you are (wrong|mistaken)|i don.?t think (so|that|it)|i disagree|doesn.?t (seem|sound|look) right|does not (seem|sound|look) right|check (it )?again|double.?check|really\?|no,? (it|that|this|they|you) |nope|prove it|where did you (get|see|find) that|you (made|just made) (that|it) up|hallucinat|that.?s not (how|what|where)'

  # Pushback that brings its own evidence (a backtick, a path, a file:line, an argued paragraph) is new information, not a bare challenge.
  user_has_evidence=0
  if [ -n "$last_user" ]; then
    printf '%s' "$last_user" | grep -q '`' && user_has_evidence=1
    printf '%s' "$last_user" | grep -qE '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+' && user_has_evidence=1
    printf '%s' "$last_user" | grep -qE '\.[A-Za-z][A-Za-z0-9]{0,9}:[0-9]+' && user_has_evidence=1
    [ "$(printf '%s' "$last_user" | wc -c | tr -d ' ')" -gt "$BARE_PUSHBACK_MAX_BYTES" ] && user_has_evidence=1
  fi

  CAVE='you.?re (absolutely |completely |totally |quite |entirely )?right|you are (absolutely |completely |totally |quite |entirely )?right|you.?re correct|you are correct|my (mistake|apologies|bad|error)|i (was|am) wrong|i apologi[sz]e|apologies|good catch|i stand corrected|i (was|got) (confused|mistaken)|that was (wrong|my (mistake|error))|let me correct'

  # HOLD: the message names what it re-checked, or keeps part of its position — candour either way.
  HOLD='i still (think|believe|maintain)|i do (think|believe)|i.?m not (changing|reversing)|re-?read|re-?ran|re-?checked|i (checked|verified|confirmed)|after (checking|re-?reading|running|re-?running)|the (file|output|test|error|transcript) (shows|says)|i disagree|on (that|this) (one|point) i|partly|only partly|to be clear, i'

  if [ -n "$last_user" ] && [ "$user_has_evidence" -eq 0 ] \
     && printf '%s' "$last_user" | grep -qiE "$PUSHBACK" \
     && printf '%s' "$last_msg" | grep -qiE "$CAVE" \
     && ! printf '%s' "$last_msg" | grep -qiE "$HOLD"; then
    ran=$(printf '%s' "$tail_jsonl" | jq -r '
      if .type=="user" then
        (if ((.message.content | type) == "string")
            or (((.message.content // []) | map(select(.type=="text")) | length) > 0)
         then "USER" else "" end)
      elif .type=="assistant" then
        ([.message.content[]? | select(.type=="tool_use") | .name] | join(" "))
      else "" end' 2>/dev/null \
      | awk '{ if ($0 == "USER") { after = 0 } else if (NF > 0) { after = 1 } } END { print (after ? "yes" : "no") }')
    if [ "$ran" = "no" ]; then
      verdict="reversal"
      detail="$last_user"
    fi
  fi
}
clause_unevidenced_reversal

ev_mode=$(cc_option CC_EVIDENCE_GATE block)
clause_naked_completion() {
  [ -z "$verdict" ] && [ -n "$tail_jsonl" ] && [ "$evt" != "SubagentStop" ] && [ "$skip" != "evidence" ] && [ "$ev_mode" != "off" ] || return 0
  # grep -w, not \b: BSD grep has no \b, and an unanchored 'done' would match 'abandoned'.
  said=$(printf '%s' "$tail_jsonl" \
    | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null \
    | tail -"$CLAIM_WINDOW_LINES")
  CLAIM='done|complete|completed|finished|implemented|fixed|resolved|verified|passes|passing|works now|working now|should work|all set|good to go'
  # ACK must state this turn's verification state: a failure named as the thing fixed stays part of the claim.
  ACK='not tested|untested|unverified|not verified|did not (run|rerun)|didn.t (run|rerun)|have not (run|rerun)|haven.t (run|rerun)|not (run|rerun) yet|cannot verify|could not verify|not green|still fail(ing|s)?|currently fail(ing|s)?|(tests?|suite|build|lint|checks?|it) (is|are|was|were) (still |currently )?fail(ing|ed|s)?|(tests?|suite|build|lint|checks?|it) (still |currently )?fail(ing|ed|s)?|fail(ing|s) (with|on|because|due)|in progress|still working|wip|not done|incomplete|halt|halting|halted|blocked|parked|known issue|please verify|verify manually|left to do|remains to'
  if [ -n "$said" ] && printf '%s' "$said" | grep -qiwE "$CLAIM" && ! printf '%s' "$said" | grep -qiwE "$ACK"; then
    # An edit to a prose file (.md, .txt, .rst, .adoc and kin) does not arm the clause: no command's failure proves a README wrong.
    ev=$(printf '%s' "$tail_jsonl" \
      | jq -r 'select(.type=="assistant")
               | [.message.content[]? | select(.type=="tool_use")
                  | .name + (if (.name | test("^(Edit|Write|MultiEdit|NotebookEdit)$|apply_patch$|create_new_file$"))
                             then "@" + ((.input.file_path // "") | ascii_downcase | (if test("\\.[a-z0-9]+$") then sub(".*\\."; "") else "" end))
                             else "" end)]
               | join(" ")' 2>/dev/null \
      | awk '
          { for (i = 1; i <= NF; i++) { n++
              if ($i ~ /^(Edit|Write|MultiEdit|NotebookEdit)(@|$)/ && $i !~ /@(md|mdx|markdown|txt|rst|adoc|asciidoc)$/) last_edit = n
              if ($i ~ /^(Bash|Agent|Task)$/)                   last_exec = n } }
          END {
            if (!last_edit)               print "no-edits"
            else if (last_exec > last_edit) print "evidence"
            else                          print "naked-claim" }')
    if [ "$ev" = "naked-claim" ]; then
      verdict="evidence"
      detail="$said"
    fi
  fi
}
clause_naked_completion

# Armed only by a dependency-shaped change; the $skip test is load-bearing, as in clauses 1-3, or the clause re-fires on its own continuation.
clause_lockfile_drift() {
  [ -z "$verdict" ] && [ "$evt" != "SubagentStop" ] && [ "$skip" != "lockfile" ] && [ "$(cc_option CC_LOCKFILE_GATE on)" != "off" ] || return 0
  if command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    changed=$(git -C "$root" status --porcelain 2>/dev/null | awk '{print $NF}')
    if [ -n "$changed" ]; then
      lock_detail=""
      while IFS='|' read -r man locks; do
        printf '%s\n' "$changed" | grep -qx "$man" || continue
        # JSON manifests compare parsed dependency maps: a one-line package.json puts version and dependencies on one diff line.
        case "$man" in
          package.json|composer.json)
            head_deps=$(git -C "$root" show "HEAD:$man" 2>/dev/null \
              | jq -cS '{d:(.dependencies//{}),dd:(.devDependencies//{}),p:(.peerDependencies//{}),o:(.optionalDependencies//{}),r:(.require//{}),rd:(."require-dev"//{})}' 2>/dev/null)
            work_deps=$(jq -cS '{d:(.dependencies//{}),dd:(.devDependencies//{}),p:(.peerDependencies//{}),o:(.optionalDependencies//{}),r:(.require//{}),rd:(."require-dev"//{})}' "$root/$man" 2>/dev/null)
            # Unparseable on either side: fall through to the line test, never a silent allow.
            if [ -n "$head_deps" ] && [ -n "$work_deps" ]; then
              [ "$head_deps" = "$work_deps" ] && continue
            else
              git -C "$root" diff -U0 -- "$man" 2>/dev/null | grep -qE '^[+-].*"(dependencies|devDependencies|peerDependencies|optionalDependencies|require|require-dev)"' || continue
            fi
            ;;
          *)
            # A dependency line, not any line; TOML metadata keys are excluded by name because a line cannot see its table.
            meta_re='^[+-][[:space:]]*(version|name|description|readme|license|authors|maintainers|homepage|repository|documentation|keywords|classifiers|requires-python|edition|rust-version|publish|include|exclude|packages|scripts|urls)[[:space:]]*='
            case "$man" in
              pyproject.toml)
                dep_re='^[+-][[:space:]]*("[^"]+"[[:space:]]*,?[[:space:]]*$|[A-Za-z0-9._-]+[[:space:]]*=[[:space:]]*[{"^~>=<*]|dependencies[[:space:]]*=|\[(tool\.poetry\.(dev-)?dependencies|project\.optional-dependencies|build-system)\])' ;;
              Gemfile)
                dep_re='^[+-][[:space:]]*(gem[[:space:]]|gemspec|source[[:space:]]|git[[:space:]]|path[[:space:]])'
                meta_re='^$' ;;
              Cargo.toml)
                dep_re='^[+-][[:space:]]*([A-Za-z0-9._-]+[[:space:]]*=[[:space:]]*[{"^~>=<*]|\[(dependencies|dev-dependencies|build-dependencies|workspace\.dependencies)\])' ;;
              go.mod)
                dep_re='^[+-][[:space:]]*(require|replace|exclude|retract)?[[:space:]]*[a-z0-9.-]+\.[a-z]{2,}/'
                meta_re='^[+-][[:space:]]*(module|go|toolchain)[[:space:]]' ;;
              *)
                dep_re='^[+-]'
                meta_re='^$' ;;
            esac
            git -C "$root" diff -U0 -- "$man" 2>/dev/null \
              | grep -E "$dep_re" 2>/dev/null | grep -qvE "$meta_re" || continue
            ;;
        esac
        satisfied=0
        for l in $locks; do printf '%s\n' "$changed" | grep -qx "$l" && satisfied=1; done
        [ "$satisfied" -eq 1 ] && continue
        [ -n "$lock_detail" ] && lock_detail="$lock_detail, "
        lock_detail="$lock_detail$man (expected one of: $(printf '%s' "$locks" | tr ' ' '/'))"
      done <<'MANIFESTS'
package.json|package-lock.json npm-shrinkwrap.json yarn.lock pnpm-lock.yaml bun.lock bun.lockb
composer.json|composer.lock
Gemfile|Gemfile.lock
pyproject.toml|poetry.lock uv.lock pdm.lock requirements.txt
Cargo.toml|Cargo.lock
go.mod|go.sum
MANIFESTS
      if [ -n "$lock_detail" ]; then
        verdict="lockfile"
        detail="$lock_detail"
      fi
    fi
  fi
}
clause_lockfile_drift

[ -n "$verdict" ] || pass_turn

report_verdict() {
  mode="$gate_mode"
  case "$verdict" in
    evidence) case "$ev_mode" in warn) mode=warn ;; esac ;;
  esac

  # Loop guard: one block per distinct verdict and final text; a genuinely new turn produces new text.
  marker="$state_dir/last$agent_sfx"
  state=$(printf '%s|%s' "$verdict" "$detail$last_msg" | (command -v shasum >/dev/null 2>&1 && shasum | cut -d' ' -f1 || cksum | cut -d' ' -f1))
  if [ -r "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$state" ]; then
    pass_turn
  fi
  if ! { mkdir -p "$state_dir" 2>/dev/null && { [ -e "$state_dir/.gitignore" ] || printf '*\n' > "$state_dir/.gitignore" 2>/dev/null || :; } && printf '%s' "$state" > "$marker" 2>/dev/null; }; then
    # No marker, no per-text bound: honour the shared flag here only, so unwritable state cannot block the same turn forever.
    [ "$sha_active" = "true" ] && pass_turn
  fi

  if [ "$mode" = "block" ]; then
    mkdir -p "$state_dir" 2>/dev/null && printf '%s' "$verdict" > "$claimed" 2>/dev/null
  fi

  local msg note
  case "$verdict" in
    citation)
      what="This turn"; [ "$evt" = "SubagentStop" ] && what="This report"
      msg=$(printf '[candor] %s cites a location that does not exist.%s\n' "$what" "$detail"
        printf '  Open the file and cite what is there, or drop the line number and say you are inferring, not quoting.\n'
        # A subagent that re-sent only the correction lost its whole report: the caller receives the last hand-back alone.
        [ "$evt" = "SubagentStop" ] && printf '  Then re-send your COMPLETE report, corrected: only your last message reaches the caller.\n'
        printf '  CC_CANDOR_GATE=off turns this check off (=warn only prints).\n')
      note="candor sent the turn back: the reply cites a file:line that does not exist." ;;
    reversal)
      msg=$(printf '[candor] The user pushed back with no new information, and this turn retracts your position anyway without re-checking anything.\n'
        printf '  Re-check (run the command or read the file that settles it, then report what it showed), or keep your position and say why.\n'
        printf '  CC_CANDOR_GATE=off turns this check off (=warn only prints).\n')
      note="candor sent the turn back: the reply took back its answer after pushback without re-checking anything." ;;
    lockfile)
      msg=$(printf '[candor] A dependency manifest changed and its lockfile did not: %s.\n' "$detail"
        printf '  Run the installer (npm/pnpm/yarn install, composer update <pkg>, bundle install, cargo build, go mod tidy) and keep\n'
        printf '  the lockfile with the manifest, or say why the lockfile stays unchanged. CC_LOCKFILE_GATE=off turns this check off.\n')
      note="candor sent the turn back: a dependency manifest changed and its lockfile did not." ;;
    evidence)
      msg=$(printf '[candor] This turn says the work is done, but no command ran after the last edit.\n'
        printf '  Run the check that would fail if the change were broken (a test, build, lint, or the changed code) and show its\n'
        printf '  output, or say what changed, what was not verified, and the command the user can run to verify it.\n'
        printf '  CC_EVIDENCE_GATE=off turns this check off (=warn only prints).\n')
      note="candor sent the turn back: the reply says the work is done, but nothing ran after the last edit." ;;
  esac

  [ "$mode" = "block" ] || { printf '%s\n' "$msg" >&2; pass_turn; }
  # A blocked subagent keeps running: put back the in-flight record removed above.
  if [ -n "$inflight_rec" ]; then
    printf '%s\n' "$agent_id" > "$inflight_rec" 2>/dev/null
  fi
  block_turn "$msg" "$note"
}
report_verdict
