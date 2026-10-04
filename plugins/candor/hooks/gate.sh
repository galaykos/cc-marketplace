#!/bin/bash
# gate.sh (Stop, SubagentStop; payload on stdin) — exit 2 refuses a turn end for one clause per stop, tried 4, 1, 2, 3, 5: an incomplete
#   registered task-runner run, a file:line resolving to nothing, a reversal after bare pushback, a naked completion claim, lockfile drift.
# Off: CC_CANDOR_GATE=off|warn (all), CC_EVIDENCE_GATE=off|warn (3), TASK_RUNNER_STOP_GATE=off|warn (4), CC_LOCKFILE_GATE=off (5);
#   unset, each reads the /config option of its lower-cased name. Fails open: no jq, no enforcement; a clause lacking its input stands down.
# Misses: a wrong API, flag or directory; an elided path; pushback outside its list; entries before the transcript tail; a hand-back
#   hidden by a later user-shaped entry; a resumed agent's text whose boundary is not on disk yet; dependency lines no pattern matches.
#   Blocks anyway: a citation into a file the turn shortened, deleted or renamed; a run record written before the run registered.
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

INFLIGHT_TTL_MIN=180
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

[ "$have_jq" = 1 ] || { echo "[candor] gate: jq not found — gate not enforced" >&2; exit 0; }

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

run_clause() {
  local sentinel="$root/.claude/task-runner/active-run.json"
  [ "$evt" != "SubagentStop" ] || return 0
  case "$(cc_option TASK_RUNNER_STOP_GATE block)" in off) return 0 ;; esac
  [ -r "$sentinel" ] || return 0
  jq empty "$sentinel" 2>/dev/null || { echo "[candor] completion-gate: active-run.json malformed — not enforced" >&2; return 0; }
  command -v git >/dev/null 2>&1 || { echo "[candor] completion-gate: git not found — not enforced" >&2; return 0; }
  local head run_branch cur_branch slug
  head=$(git -C "$root" rev-parse HEAD 2>/dev/null) || { echo "[candor] completion-gate: not a git repo — not enforced" >&2; return 0; }

  # An abandoned run leaves its sentinel behind: a run that names its branch is enforced only on that branch.
  run_branch=$(jq -r '.branch // empty' "$sentinel" 2>/dev/null)
  cur_branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -n "$run_branch" ] && [ -n "$cur_branch" ] && [ "$run_branch" != "$cur_branch" ]; then
    printf '[candor] completion-gate: run registered on branch %s, now on %s — not enforced here.\n' "$run_branch" "$cur_branch" >&2
    printf '  If that run is finished or abandoned, delete .claude/task-runner/active-run.json.\n' >&2
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
      run_msg=$(printf '[candor] completion-gate: %s recorded a gate pass but its card counts are %s: done=%s parked=%s total=%s.\n  A run may not report complete while any card is neither done nor parked.' "$slug" "$v" "$cdone" "$cpark" "$ct")
      verdict="run"; return 0
    fi
    # Only records newer than this registration count: card ids repeat across runs, and these dirs are never cleared.
    local ncdir="$root/.claude/task-runner/nc" nc_count
    if [ "$v" = "complete" ] && [ -d "$ncdir" ]; then
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      nc_count=$(find "$ncdir" -maxdepth 1 \( -name 'nc-pass-*.json' -o -name 'nc-skip-*.json' \) -newer "$sentinel" 2>/dev/null |
        sed -E 's#.*/nc-(pass|skip)-##; s#\.json$##' | sort -u | wc -l | tr -d ' ')
      if [ "$nc_count" -lt "$cdone" ] 2>/dev/null; then
        run_msg=$(printf '[candor] completion-gate: %s reports %s done cards but only %s per-card negative-control records in .claude/task-runner/nc/.\n  Every done card needs an nc-pass record (negative-control.sh --record-dir --card) or a documented nc-skip. Run the missing controls, then stop.' "$slug" "$cdone" "$nc_count")
        verdict="run"; return 0
      fi
    fi
    local rvdir="$root/.claude/task-runner/rv" rv_count
    if [ "$v" = "complete" ] && [ -d "$rvdir" ]; then
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      rv_count=$(find "$rvdir" -maxdepth 1 \( -name 'rv-seen-*.json' -o -name 'rv-skip-*.json' -o -name 'rv-exempt-*.json' \) -newer "$sentinel" 2>/dev/null |
        sed -E 's#.*/rv-(seen|skip|exempt)-##; s#\.json$##' | sort -u | wc -l | tr -d ' ')
      if [ "$rv_count" -lt "$cdone" ] 2>/dev/null; then
        run_msg=$(printf '[candor] completion-gate: %s reports %s done cards but only %s per-card reviewer records in .claude/task-runner/rv/.\n  Every done card needs an observed reviewer dispatch (the RV-CARD marker in the prompt), a recorded skip (scripts/review-skip.sh --card --reason) or an exemption (--exempt). Run the missing reviews, then stop.' "$slug" "$cdone" "$rv_count")
        verdict="run"; return 0
      fi
    fi
    # Of the red verdicts only no-behavioral-coverage may pass, beside this HEAD's coverage reduction, which the report must then name.
    local bgdir="$root/.claude/task-runner/bg" bgv covred
    if [ "$v" = "complete" ] && [ -d "$bgdir" ]; then
      if [ ! -r "$bgdir/bg-$head.json" ]; then
        run_msg=$(printf '[candor] completion-gate: %s recorded a gate pass for HEAD %s, but behavioral-gate.sh left no verdict record for it.\n  gate-pass.json is written by hand; bg/bg-<head>.json is written by the gate itself. Run scripts/behavioral-gate.sh against this HEAD, then stop.' "$slug" "${head:0:12}")
        verdict="run"; return 0
      fi
      bgv=$(jq -r '.verdict // empty' "$bgdir/bg-$head.json" 2>/dev/null)
      case "$bgv" in covered | no-executable-surface | '') bgv="" ;; esac
      covred="$root/.claude/task-runner/reductions/coverage-bg-${head:0:12}.json"
      if [ "$bgv" = "no-behavioral-coverage" ] && [ -f "$covred" ] && [ "$covred" -nt "$sentinel" ]; then
        bgv=""
      fi
      if [ "$bgv" = "no-behavioral-coverage" ]; then
        run_msg=$(printf '[candor] completion-gate: behavioral-gate.sh reached "no-behavioral-coverage" for HEAD %s, and the run is reporting complete.\n  No test in this project exercises the changed files. Add tests a runner here executes, re-run the gate, then stop — or, if that coverage is out of this run'"'"'s scope, record the gap honestly. From the repo root run task-runner'"'"'s scripts/reduction-record.sh --kind coverage --id bg-%s --reason "<which files no runner covers, and why>", name bg-%s and that reason in the closing report, then stop.' "${head:0:12}" "${head:0:12}" "${head:0:12}")
        verdict="run"; return 0
      fi
      if [ -n "$bgv" ]; then
        run_msg=$(printf '[candor] completion-gate: behavioral-gate.sh reached "%s" for HEAD %s, and the run is reporting complete.\n  A run may not close over a red or unverifiable behavioral gate. Fix the coverage, re-run the gate, then stop.' "$bgv" "${head:0:12}")
        verdict="run"; return 0
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
          run_msg=$(printf '[candor] completion-gate: this is a boosted run, and the code red-team panel is short: %s of 3 refuter lenses, %s of 1 completeness critic.\n  Dispatch the missing refuters (each prompt carries RT-LENS: <lens>, the critic RT-CRITIC: <id>), or record the degraded inline pass with scripts/reduction-record.sh --kind redteam --id <ref> --reason "...". Then stop.' "$lenses" "$critic")
          verdict="run"; return 0
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
            run_msg=$(printf '[candor] completion-gate: this run recorded reductions that the closing report never names:%s\n  Name each one and its reason (the records are in .claude/task-runner/rv/ and reductions/) before stopping — a cut the user has to ask about is the gap this gate exists to prevent.' "$missing")
            verdict="run"; return 0
          fi
        fi
      fi
    fi
    return 0
  fi

  # Mid-run and end-of-run both land here and cannot be told apart cheaply, so the message names both branches.
  # Workers in flight: print, block nothing and write no nudge, keeping this HEAD's one block for after the last hand-back.
  local waiting
  waiting=$(inflight_count)
  if [ "${waiting:-0}" -gt 0 ] 2>/dev/null; then
    printf '[candor] completion-gate: %s has no behavioral-gate pass for HEAD %s, and %s background worker(s) of this session are still in flight — not blocking.\n  A worker'"'"'s hand-back wakes this session; the gate holds the stop after the last one returns.\n' "$slug" "${head:0:12}" "$waiting" >&2
    return 0
  fi
  run_msg=$(printf '[candor] completion-gate: %s is a registered run with no behavioral-gate pass for HEAD %s.
  The run is not complete, so this turn must not end here.
  Cards still to execute -> continue with the next card'"'"'s tool call. Do not name the next card
    in prose and yield: that binds nothing, and the user waits on a turn that already ended.
    Need a decision -> ask it with AskUserQuestion (not a stop). Blocked -> park the card with a reason.
  Every card done or parked -> the gate is the only step left, and it has no deadline. From the
    repo root run task-runner'"'"'s scripts/behavioral-gate.sh --isolate --changed "<the run'"'"'s touched
    files>" (the path run.md step 4 names). --isolate creates, checks and removes its own worktree
    and writes the verdict record; do not hand-build a checkout, and do not copy, generate or write
    any .env for it. Then record the pass to .claude/task-runner/gate-pass.json as {"head":"%s"}
    plus the card counts, and clear active-run.json. A green repo suite alone is NOT this gate.
  Any shell setup: one step per call, and read each result before the next. A denied or failed
    call ran NOTHING, not "everything but the part named in the error".
  Not running this task list at all? The sentinel outlived its run — delete
    .claude/task-runner/active-run.json.' "$slug" "${head:0:12}" "$head")
  verdict="run"
}
RUN_HEAD=""; RUN_SENTINEL=""
run_clause

if [ "$verdict" = "run" ]; then
  run_mode="$gate_mode"
  case "$(cc_option TASK_RUNNER_STOP_GATE block)" in warn) run_mode=warn ;; esac
  # The switch is printed here, the one print site of every clause-4 reason: a blocked reader sees only this stderr.
  printf '%s\n' "$run_msg" >&2
  printf '  TASK_RUNNER_STOP_GATE=off disables this clause for the session; =warn prints without blocking.\n' >&2
  if [ "$run_mode" = "block" ]; then
    # One block per HEAD: the nudge counts only while newer than the sentinel, so an earlier run's marker cannot eat this one's block.
    nudge="$root/.claude/task-runner/gate-nudge"
    if [ -r "$nudge" ] && [ "$nudge" -nt "$RUN_SENTINEL" ] && [ "$(cat "$nudge" 2>/dev/null)" = "$RUN_HEAD" ]; then
      :                                   # bounded at this HEAD — printed, not blocked
    elif printf '%s' "$RUN_HEAD" > "$nudge" 2>/dev/null; then
      exit 2
    elif [ "$sha_active" != "true" ]; then
      # No writable marker, so no per-HEAD bound: honour the shared flag here only, or an unwritable state dir blocks forever.
      exit 2
    fi
  fi
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
  # URLs go before extraction (a.php:80 in one is a port); the extension starts with a letter, so v1.2.3:4 and 10:30 never match.
  cites=$(printf '%s' "$last_msg" \
    | sed -E 's#[a-zA-Z][a-zA-Z0-9+.-]*://[^[:space:])"]*##g' \
    | grep -oE '[A-Za-z0-9_.~][A-Za-z0-9_./-]*\.[A-Za-z][A-Za-z0-9]{0,9}:[0-9]+' 2>/dev/null \
    | grep -vEi '\.(com|net|org|io|co|ai|app|gg|me):[0-9]+$' \
    | grep -vF '...' \
    | sort -u)

  # Pruned and depth-capped: a Stop hook must stay cheap on a large repo.
  _find() { find "$root" -maxdepth 8 \
    \( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name .venv \) -prune \
    -o "$@" -type f -print 2>/dev/null; }

  # resolve <relpath> prints FILE <path>, MISSING (the basename exists nowhere) or AMBIGUOUS (unresolved, basename not unique).
  # Abbreviated paths outnumber invented ones (measured), so only a basename found nowhere is fabricated; a wrong directory passes.
  resolve() {
    local p="$1" m b n
    case "$p" in "~/"*) p="${HOME:-}/${p#\~/}" ;; esac
    case "$p" in
      /*) [ -f "$p" ] && { printf 'FILE %s' "$p"; return 0; } ;;
    esac
    # The shell cwd first — a relative path the model just used from there — then the root.
    [ -f "$cwd/$p" ] && { printf 'FILE %s' "$cwd/$p"; return 0; }
    [ -f "$root/$p" ] && { printf 'FILE %s' "$root/$p"; return 0; }
    m=$(_find -path "*/$p" | head -1)
    [ -n "$m" ] && { printf 'FILE %s' "$m"; return 0; }
    b=${p##*/}
    m=$(_find -name "$b" | head -2)
    n=$(printf '%s\n' "$m" | grep -c .)
    if [ "$n" -eq 0 ]; then printf 'MISSING'
    elif [ "$n" -eq 1 ]; then printf 'FILE %s' "$m"
    else printf 'AMBIGUOUS'
    fi
    return 0
  }

  misses=""
  checked=0
  for c in $cites; do
    [ "$checked" -ge "$MAX_CITATIONS_CHECKED" ] && break
    checked=$((checked + 1))
    path="${c%:*}"; line="${c##*:}"
    r=$(resolve "$path")
    case "$r" in
      MISSING)   misses="$misses
  - $c — no file named ${path##*/} exists anywhere under $root"; continue ;;
      AMBIGUOUS) continue ;;   # path unresolved but the name is real — not decidable
    esac
    file="${r#FILE }"
    lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
    case "$lines" in ''|*[!0-9]*) continue ;; esac
    # +1 tolerance: a final line with no trailing newline is not counted by wc -l.
    if [ "$line" -gt $((lines + 1)) ] 2>/dev/null; then
      misses="$misses
  - $c — $file has $lines lines"
    fi
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

# Only a dependency-shaped change arms it: a version, scripts or description edit never touches a lockfile.
# The $skip test is load-bearing, as in clauses 1-3: without it this clause re-fires on its own continuation and its escape never works.
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

[ -n "$verdict" ] || exit 0

report_verdict() {
  mode="$gate_mode"
  case "$verdict" in
    evidence) case "$ev_mode" in warn) mode=warn ;; esac ;;
  esac

  # Loop guard: one block per distinct verdict and final text; a genuinely new turn produces new text.
  marker="$state_dir/last$agent_sfx"
  state=$(printf '%s|%s' "$verdict" "$detail$last_msg" | (command -v shasum >/dev/null 2>&1 && shasum | cut -d' ' -f1 || cksum | cut -d' ' -f1))
  if [ -r "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$state" ]; then
    exit 0
  fi
  if ! { mkdir -p "$state_dir" 2>/dev/null && { [ -e "$state_dir/.gitignore" ] || printf '*\n' > "$state_dir/.gitignore" 2>/dev/null || :; } && printf '%s' "$state" > "$marker" 2>/dev/null; }; then
    # No marker, no per-text bound: honour the shared flag here only, so unwritable state cannot block the same turn forever.
    [ "$sha_active" = "true" ] && exit 0
  fi

  # Record which clause blocked, so only that clause stands down on the continuation.
  if [ "$mode" = "block" ]; then
    mkdir -p "$state_dir" 2>/dev/null && printf '%s' "$verdict" > "$claimed" 2>/dev/null
  fi

  case "$verdict" in
    citation)
      what="this turn"; [ "$evt" = "SubagentStop" ] && what="this report"
      printf '[candor] gate: %s cites a location that does not exist.%s\n' "$what" "$detail" >&2
      printf '  A file:line citation asserts you read that line. Open the file, cite what is actually\n' >&2
      printf '  there, or drop the number and say plainly that you are inferring rather than quoting.\n' >&2
      printf '  Inventing a location is the failure this clause exists to stop.\n' >&2
      printf '  CC_CANDOR_GATE=off disables this gate for the session; =warn prints without blocking.\n' >&2 ;;
    reversal)
      printf '[candor] gate: the user pushed back without giving you new information, and this turn\n' >&2
      printf '  retracts your position anyway — nothing was re-checked between the challenge and the\n' >&2
      printf '  retraction.\n' >&2
      printf '  Do one of two things. Re-check: run the command or read the file that would settle it,\n' >&2
      printf '  then report what it showed. Or hold: say you still believe what you said, and why.\n' >&2
      printf '  "You are right" is a finding. It needs the same evidence as any other finding.\n' >&2
      printf '  CC_CANDOR_GATE=off disables this gate for the session; =warn prints without blocking.\n' >&2 ;;
    lockfile)
      printf '[candor] gate: a dependency manifest changed and its lockfile did not — %s.\n' "$detail" >&2
      printf '  The install step was skipped, so the tree you are leaving has a manifest and a lockfile\n' >&2
      printf '  that disagree. The next clone resolves different versions, and CI blames whoever ran it.\n' >&2
      printf '  Run the installer (npm/pnpm/yarn install, composer update <pkg>, bundle install, cargo\n' >&2
      printf '  build, go mod tidy) and commit the lockfile with the manifest — or say plainly that the\n' >&2
      printf '  lockfile is deliberately unchanged and why. CC_LOCKFILE_GATE=off disables this clause.\n' >&2 ;;
    evidence)
      printf '[candor] evidence-gate: this turn claims completion, files were edited, and no command ran after the last edit — nothing verified the change.\n' >&2
      printf '  Either run the check that would FAIL if the change were broken (test, build, lint, or execute\n' >&2
      printf '  the changed code) and show its output — or restate honestly: what changed, what was NOT\n' >&2
      printf '  verified, and the exact command the user can run to verify it.\n' >&2
      printf '  A claim with no execution behind it is the failure this gate exists to stop.\n' >&2
      printf '  CC_EVIDENCE_GATE=off disables this clause for the session; =warn prints without blocking.\n' >&2 ;;
  esac

  [ "$mode" = "block" ] || exit 0
  # A blocked subagent keeps running: put back the in-flight record removed above.
  if [ -n "$inflight_rec" ]; then
    printf '%s\n' "$agent_id" > "$inflight_rec" 2>/dev/null
  fi
  exit 2
}
report_verdict
