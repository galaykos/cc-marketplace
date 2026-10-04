#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# PostToolUse output-discipline guard (warn-only, at most ONE warning per session).
# Measures how much conversational prose this session has emitted per tool call and
# says so once when the session is an outlier. Silence is the overwhelmingly common
# case — see the calibration below.
#
# WHY A MEASUREMENT AND NOT A RULE: "be concise" already exists as prose in many
# places and loses, because it competes against task-local instructions that are more
# specific — ledgers, status tables, "report back" contracts. A rule that says the same
# thing more loudly is rule N+1 and loses the same way. This hook does not add a rule.
# It reports a number about THIS session that nothing else in the marketplace measures.
#
# THE METRIC: total characters of assistant text ÷ number of assistant tool calls,
# cumulative over the session transcript. High = the session is narrating relative to
# how much it is doing.
#
# CALIBRATION (measured 2026-07-28 over 1,933 local session transcripts with >=8 tool
# calls; 135 main-thread, 1,798 subagent):
#     main-thread   p50=155  p90=325  p95=389  p99=821  max=910
#     subagent      p50=152  p90=441  p95=634  p99=1118 max=3120
# The threshold is 600, which fired on 3 of 135 observed main-thread sessions (2.2%)
# and on none below p95. It is set to catch outliers, not to nag the median.
#
# SUBAGENTS ARE EXEMPT. Their p95 is 634 against the main thread's 389 because a
# subagent's final text IS its return value — narration is its contract, not a defect.
# Judging them by this metric would be measuring the wrong thing.
#
# LIMITATION (honest scope — the four laws, see
# .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
#   - WARN-ONLY, and PostToolUse at that: it emits `additionalContext`, which is not a
#     blocking key. It cannot stop a verbose turn, only inform the ones after it.
#     Stop-event delivery was considered and rejected: a Stop hook reaches the model
#     only by BLOCKING (exit 2), and spending a whole extra turn to complain about
#     output volume would emit more prose than it saves.
#   - The metric is CUMULATIVE, so a session that narrated early stays flagged even
#     after it tightens up. One warning per session bounds the cost of that.
#   - Prose the USER asked for (a written report, a long explanation) counts against
#     the ratio. The hook cannot tell requested prose from unrequested narration, and
#     does not pretend to — which is the main reason it warns instead of blocking.
#   - The threshold is calibrated on ONE machine's transcripts. It is a starting number
#     with its sample stated, not a universal constant.
#   - Assumes PostToolUse carries `transcript_path`. If it does not, every path here
#     exits 0 and the hook is simply silent — it degrades to nothing, never to noise.
#   - The ledger below is WRITE-ONLY by design: nothing reads it back automatically.
#     It exists so the threshold and this hook's effect can be evaluated later against
#     real data instead of re-argued. Calling it a feedback loop today would be the
#     over-claim this plugin's own review flagged in `hindsight`.
#
# FAIL-OPEN: missing jq/awk, unreadable transcript, or any error exits 0.
# CC_REMIND unset: the /config option cc_remind decides.
# State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/comment-discipline/ is only the fallback.

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

{
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v awk >/dev/null 2>&1 || exit 0

  input=$(cat)
  # Warn-only hook, so the marketplace-wide advisory switch silences it outright.
  [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0

  tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null) || exit 0
  [ -n "$tp" ] && [ -r "$tp" ] || exit 0

  # Subagent transcripts are exempt (see header). Match the path, not the content.
  case "$tp" in */subagents/*) exit 0 ;; esac

  # `-d`, not just `-n`: a session outlives the directory, and `mkdir -p` below is happy to
  # rebuild three levels of a project tree the user has just deleted — measured on a deleted
  # `work/acme/design-studio`, which came back holding nothing but this hook's state dir.
  #
  # THE PAYLOAD cwd IS THE SHELL'S cwd, and it follows the model's `cd`. This header said it
  # was "whatever the session STARTED in" until 0.23.0, and used that to keep state at
  # `<cwd>/.claude/comment-discipline`. Measured false 2026-09-25
  # (rationale/2026-09-25-session-plugin-usage-review.md, finding 2): one session's cwd was
  # app/Enums, then app/Models, then the repo root; this "shown once per session" warning
  # fired three times, one state dir per directory, and another repo had one COMMITTED.
  # So state lives at cc_state_root (the block above: git toplevel, else CLAUDE_PROJECT_DIR,
  # else cwd). The address `<root>/.claude/comment-discipline` is SHARED with density.sh and
  # scan.sh, and all three moved in one change — a one-shot split across two addresses is no
  # one-shot at all. (conventions.sh keys its one-shot under $TMPDIR and never shared it.)
  # Does NOT catch: a cwd that exists but is not the project (a stale session left in a
  # sibling checkout) — nothing in the payload distinguishes those.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0

  # CHEAP PATH FIRST. This hook runs after every tool call, so the common case must
  # not parse the transcript. `wc -l` is one read of the file's size class, and the
  # state file short-circuits every call after a warning has already been spent.
  #
  # State file: one line, "<lines-at-last-scan> <warned:0|1>". A scan costs one jq
  # pass, so it is rate-limited to once per RESCAN_EVERY new transcript lines rather
  # than once per session — a session that turns verbose late is still caught, while
  # the number of expensive passes stays bounded and small.
  MIN_LINES=60
  RESCAN_EVERY=150
  THRESHOLD=600
  MIN_TOOL_CALLS=8

  lines=$(wc -l < "$tp" 2>/dev/null | tr -d ' ')
  case "$lines" in ''|*[!0-9]*) exit 0 ;; esac
  [ "$lines" -ge "$MIN_LINES" ] || exit 0

  # Resolved here, after the line-count exit, so a short session never pays the git call.
  root=$(cc_state_root "$cwd") || exit 0
  dir=$(cc_plugin_state "$root" comment-discipline)
  state="$dir/verbosity-$sid"

  # BOTH BOUNDS BELOW LIVE IN THAT STATE FILE — "at most one warning per session" and
  # "at most one transcript scan per RESCAN_EVERY lines". If it cannot be written, the
  # hook has no memory: it warns on every tool call and re-scans the whole transcript
  # every time, which is the opposite of both promises. So writability is checked ONCE,
  # here, on the cheap path, before any expensive work — an unwritable state dir means
  # this hook does nothing at all. Same rule as the deny lane in scan.sh: a bound that
  # cannot be recorded is not a bound.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null   # the state dir ignores itself

  last=0
  if [ -r "$state" ]; then
    read -r last warned _ < "$state" 2>/dev/null || exit 0
    [ "${warned:-0}" = "1" ] && exit 0
    case "$last" in ''|*[!0-9]*) last=0 ;; esac
    [ "$((lines - last))" -ge "$RESCAN_EVERY" ] || exit 0
  fi

  # EXPENSIVE PATH: one jq pass emitting "<text-chars> <tool-calls>".
  read -r chars calls <<EOF
$(jq -rs '
    [ .[]
      | select(type == "object" and .type == "assistant")
      | (.message.content // [])[]?
      | select(type == "object")
    ] as $c
    | [ ($c | map(select(.type == "text") | (.text // "" | length)) | add // 0),
        ($c | map(select(.type == "tool_use")) | length) ]
    | @tsv' "$tp" 2>/dev/null)
EOF
  case "${chars:-}${calls:-}" in ''|*[!0-9]*) chars=""; calls="" ;; esac
  [ -n "$chars" ] && [ -n "$calls" ] || exit 0
  [ "$calls" -ge "$MIN_TOOL_CALLS" ] || { printf '%s 0\n' "$lines" > "$state" 2>/dev/null; exit 0; }

  ratio=$((chars / calls))

  # LEDGER. Every scan is recorded, warned or not — this is the only measurement
  # trail any plugin in this marketplace leaves. The threshold above was calibrated
  # once, on one machine, from transcripts that predate this hook; without a record
  # of what it sees in practice, nothing could ever say whether 600 is right, or
  # whether the warning changed the sessions that got it. A number nobody reads back
  # is the failure this plugin's own review named.
  #
  # Machine-local, never inside the project tree — same placement reasoning as
  # hindsight/hooks/collect.sh. One compact row per scan, capped so an old ledger
  # cannot grow without bound. Nothing reads this automatically; it is a dataset for
  # a future evaluation, and saying that is the honest scope.
  ledger="${HOME:-/tmp}/.claude/comment-discipline/verbosity-ledger.jsonl"
  if [ "$(wc -c < "$ledger" 2>/dev/null || echo 0)" -lt 1048576 ]; then
    mkdir -p "${ledger%/*}" 2>/dev/null &&
      jq -cn --arg s "$sid" --argjson c "$chars" --argjson t "$calls" \
             --argjson r "$ratio" --argjson th "$THRESHOLD" --argjson l "$lines" \
        '{session:$s,chars:$c,calls:$t,ratio:$r,threshold:$th,lines:$l,warned:($r>$th)}' \
        >> "$ledger" 2>/dev/null
  fi

  if [ "$ratio" -le "$THRESHOLD" ]; then
    printf '%s 0\n' "$lines" > "$state" 2>/dev/null
    exit 0
  fi

  printf '%s 1\n' "$lines" > "$state" 2>/dev/null

  msg=$(printf 'comment-discipline: this session has emitted ~%s characters of prose per tool call (threshold %s; p95 of measured sessions is ~389). Keep what the user needs to follow the work — what you found, what changed, what you need from them — and drop preamble and closing summaries that restate the diff. Shown once per session.' "$ratio" "$THRESHOLD")

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}' 2>/dev/null \
    || exit 0
  exit 0
} 2>/dev/null
exit 0
