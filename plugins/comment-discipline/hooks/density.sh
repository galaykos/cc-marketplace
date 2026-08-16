#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# PostToolUse comment-VOLUME guard (warn-only, at most 3 warnings per session).
# Compares the file just written against the comment density of its OWN siblings and
# says so when it is an outlier. Silence is the common case.
#
# WHY THIS EXISTS — the gap scan.sh cannot close by design. scan.sh detects KINDS of
# bad comment: restatement, banners, commented-out code, bare TODOs, dead docblock
# tags, change narration. Every one of those is a pattern in a single comment. None of
# them fires on a well-formed why-comment, and a file can be 81% comment with every
# line individually defensible. That is not hypothetical: a 30-card run produced
# `GoogleClient.php` at 180 comment lines out of 223, and scan.sh was silent on it and
# on the three next-fattest files, correctly, because each comment passed every kind
# check. The skill's own anti-pattern list even warns against "deleting comments to hit
# a ratio" — which is right about deletion and was read as licence to never measure.
#
# WHY SIBLINGS AND NOT A CONSTANT. There is no correct comment ratio. A driver with
# vendor quirks earns more prose than a controller; a repo with a house style of heavy
# docblocks is not wrong. The only defensible baseline is the surrounding code, which
# is also exactly what `task-executor` and the delegation preamble already ask for
# ("match the surrounding file's naming, idiom, and comment density") — this hook
# measures the instruction those already give, and it reaches subagents, which is where
# writing actually happens and where a prose contract had no delivery channel.
#
# LIMITATION (honest scope — the four laws, see
# claude-authoring/skills/authoring-skills/SKILL.md "The four laws"):
#   - WARN-ONLY, PostToolUse: `additionalContext` is not a blocking key. The file is
#     already on disk. It informs the next write, never the one that tripped it.
#   - A ratio is not a judgment. A file legitimately denser than its siblings (the one
#     driver full of vendor workarounds) trips this, and that is a false positive the
#     author should overrule. It is why this warns instead of blocking, and why the
#     message says "against its siblings" rather than "too many comments".
#   - It cannot see the AGGREGATE across a fan-out. Each subagent gets its own warning
#     in its own context; nothing sums 73 files and reports "this run runs 2x the
#     repo". The ledger below exists so that question can be answered later from data,
#     but nothing reads it back today and calling it a feedback loop would be the
#     over-claim this plugin has been pulled up on before.
#   - The comment/code split is line-shaped (a line starting with //, /*, *, #, --),
#     not a parser. A trailing comment on a code line counts as code; a string
#     containing `//` counts as a comment. Both are rare enough not to move a ratio
#     computed over 50+ lines, and the same rule is applied to the file and to its
#     siblings, so a systematic error cancels.
#   - Thresholds are a starting point, not a constant: 2.0x the sibling MEDIAN, with an
#     absolute floor of 0.8 so a repo that comments almost nothing cannot make any
#     comment an outlier. Calibrated against one observed failure (house 0.85-1.26,
#     produced 1.71-1.85) and one repo, and the ledger records every measurement so
#     that can be revisited against real data instead of re-argued.
#
# FAIL-OPEN: missing jq/awk, unreadable file, too few siblings, or any error exits 0.
{
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v awk >/dev/null 2>&1 || exit 0

  input=$(cat)
  event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null) || exit 0
  [ "$event" = "PostToolUse" ] || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [ -n "$fp" ] && [ -f "$fp" ] && [ -r "$fp" ] || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  # CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
  # subagents at all, and a subagent shares its parent's session_id while getting its
  # own transcript. Keying a one-shot on session_id therefore dedups the worker against
  # nudges only the PARENT ever saw, so the context where most fan-out code is written
  # is the one context this never speaks in. Pattern and rationale: lean/hooks/budget.sh:10.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -n "$sid" ] || exit 0

  # Same exclusions and extension set as scan.sh, and against the same LOGICAL path
  # (worktree prefix stripped — see hooks/paths.sh): generated, vendored and tooling
  # trees have deliberate header blocks, and config/prose formats use comments for
  # navigation, which this rule does not govern.
  lp="$fp"
  . "$(dirname "$0")/paths.sh" 2>/dev/null
  command -v cd_logical_path >/dev/null 2>&1 && lp=$(cd_logical_path "$fp")
  case "$lp" in
    */.claude/*|*/node_modules/*|*/vendor/*|*/dist/*|*/build/*|*/.git/*) exit 0 ;;
    */scripts/*.sh|*/templates/*|*/plugins/*/hooks/*|*/migrations/*) exit 0 ;;
  esac
  ext="${fp##*.}"
  case "$fp" in
    *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.vue|*.svelte) ;;
    *.php|*.py|*.rb|*.go|*.rs|*.java|*.kt|*.kts|*.swift|*.scala|*.dart) ;;
    *.c|*.h|*.cpp|*.hpp|*.cc|*.cs|*.m|*.mm) ;;
    *) exit 0 ;;
  esac

  # The floor is on SUBSTANTIVE LINES, not on code lines, and the difference is the
  # whole point. A `code >= 40` floor excludes exactly the worst case this hook exists
  # to catch: the observed `GoogleClient.php` was 223 lines of which 180 were comment,
  # so it had ~43 code lines and a code-shaped floor would have waved through the
  # single densest file in the run. A few code lines are still needed for the ratio to
  # mean anything, hence MIN_CODE — set low, as a divide-by-noise guard, not a filter.
  MIN_LINES=50       # comment + code; below this a ratio is noise, not a signal
  MIN_CODE=8         # enough denominator for a ratio to carry information
  MIN_SIBLINGS=3     # a median of two files is not a house style
  SAMPLE_CAP=25      # bounded cost: this runs after every edit
  MULT=20            # 2.0x, in tenths (integer arithmetic only)
  FLOOR=8            # 0.8, in tenths — absolute lower bound on "outlier"
  MAX_WARN=3

  dir="$cwd/.claude/comment-discipline"
  state="$dir/density-$sid"
  # Same rule as scan.sh's deny lane and verbosity.sh: a bound that cannot be recorded
  # is not a bound. Unwritable state means this hook does nothing at all, rather than
  # warning on every single edit for the rest of the session.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  warned=0
  if [ -r "$state" ]; then
    warned=$(grep -c '^warn ' "$state" 2>/dev/null) || warned=0
    case "$warned" in ''|*[!0-9]*) warned=0 ;; esac
    [ "$warned" -ge "$MAX_WARN" ] && exit 0
    grep -qxF "file $fp" "$state" 2>/dev/null && exit 0   # already reported this file
  fi

  # ---- one shared counter, applied identically to the file and to its siblings ----
  ratio_of() { # $@ files -> "<comment> <code>"
    awk '
      FNR==1 { }
      { s=$0; sub(/^[ \t]+/,"",s)
        if (s == "") next
        if (s ~ /^(\/\/|\/\*|\*|#|--)/) { c++; next }
        code++ }
      END { printf "%d %d\n", c+0, code+0 }' "$@" 2>/dev/null
  }

  read -r fc fcode <<EOF
$(ratio_of "$fp")
EOF
  case "${fc:-}${fcode:-}" in ''|*[!0-9]*) exit 0 ;; esac
  [ "$fcode" -ge "$MIN_CODE" ] || exit 0
  [ "$(( fc + fcode ))" -ge "$MIN_LINES" ] || exit 0

  # ---- baseline: same-extension siblings, nearest directory first ----
  # Cached per directory per session — a fan-out writing 30 files into one package
  # must not re-scan that package 30 times.
  fdir=$(dirname "$fp")
  # Resolved forms, computed once. Needed in two places that must agree: the
  # repo-root bound on the sibling walk, and the "already measured this session"
  # ledger — git reports symlink-free paths and the edited path usually is not one.
  rdir=$(cd "$fdir" 2>/dev/null && pwd -P) || rdir="$fdir"
  rfp="$rdir/$(basename "$fp")"
  key=$(printf '%s' "$fdir/$ext" | (command -v shasum >/dev/null 2>&1 && shasum || cksum) 2>/dev/null | cut -d' ' -f1)
  base=""
  [ -n "$key" ] && base=$(awk -v k="$key" '$1=="base" && $2==k {print $3}' "$state" 2>/dev/null | tail -1)

  if [ -z "$base" ]; then
    # THE BASELINE MUST BE PRE-EXISTING CODE, and this is the subtlety the whole hook
    # turns on. A fan-out that writes 73 uniformly dense files into one new package
    # would otherwise compute its baseline FROM ITS OWN OUTPUT, find no outlier, and
    # certify the drift it just created. That is precisely the run this hook exists
    # for. So siblings are drawn from files git already TRACKS — committed code is
    # house style; a file this run created is not — and any file this session has
    # already written is filtered out on top, which covers a tracked file the run
    # rewrote. Not a git repo, or git absent: fall back to `find`, and say so in the
    # ledger by way of the baseline it produces.
    sibs_from() { # $1 dir, $2 maxdepth
      if command -v git >/dev/null 2>&1 && git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$1" ls-files -- "*.$ext" 2>/dev/null | while IFS= read -r rel; do
          case "$rel" in */*/*) [ "$2" -ge 2 ] || continue ;; esac
          printf '%s/%s\n' "$1" "$rel"
        done
      else
        find "$1" -maxdepth "$2" -type f -name "*.$ext" 2>/dev/null
      fi
    }
    pick() { # $1 dir, $2 maxdepth — tracked siblings minus this file minus this run's writes
      sibs_from "$1" "$2" | while IFS= read -r s; do
        case "$s" in "$fp"|"$rfp") continue ;; esac
        grep -qxF "file $s" "$state" 2>/dev/null && continue
        printf '%s\n' "$s"
      done | head -n "$SAMPLE_CAP"
    }
    # WALK UP until there is enough tracked code to average, capped at 4 levels. One
    # widening step is not enough: a feature fan-out creates a whole new SUBTREE
    # (`app/Services/Google/Contracts/`), so neither that directory nor its parent has
    # any tracked file, and a two-step search finds nothing and exits silently on
    # exactly the run this hook is for. Depth grows with the walk so a shallow level
    # can still reach the code below it.
    #
    # THE WALK IS BOUNDED BY THE REPOSITORY ROOT, and that bound is load-bearing rather
    # than tidy. Without it a file in a repo with no tracked code walks out of the
    # project entirely and averages whatever `.php` files happen to sit in the parent
    # directory — a sibling checkout, a scratch dir — then reports that as "its
    # siblings". A baseline computed from unrelated code is worse than no baseline,
    # because the warning names a house style that does not exist.
    # Both sides of the bound are resolved with `pwd -P` before comparison. They must
    # be: `git rev-parse --show-toplevel` returns a symlink-free path, while the edited
    # file's path usually is not — on macOS every `/var/...` path is really
    # `/private/var/...` — so a raw string prefix test fails on exactly the temp dirs
    # this is tested in, and silently reduces the walk to zero levels.
    top=""
    if command -v git >/dev/null 2>&1; then
      top=$(cd "$rdir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
    fi
    [ -n "$top" ] || top=$(cd "$cwd" 2>/dev/null && pwd -P) || top="$cwd"

    sibs=""; n=0; d="$rdir"; depth=1; up=0
    while [ "$up" -lt 4 ]; do
      case "$d" in "$top"|"$top"/*) ;; *) break ;; esac
      sibs=$(pick "$d" "$depth")
      n=$(printf '%s\n' "$sibs" | grep -c . )
      [ "$n" -ge "$MIN_SIBLINGS" ] && break
      parent=$(dirname "$d")
      [ "$parent" = "$d" ] && break
      d="$parent"; depth=$((depth + 1)); up=$((up + 1))
    done
    [ "$n" -ge "$MIN_SIBLINGS" ] || exit 0

    # Median of the per-sibling ratios in tenths. Median, not mean: one 90%-comment
    # interface file in the sample must not redefine the house style by itself.
    base=$(printf '%s\n' "$sibs" | while IFS= read -r s; do
             [ -f "$s" ] && [ -r "$s" ] || continue
             read -r sc scode <<EOS
$(ratio_of "$s")
EOS
             [ "${scode:-0}" -ge 10 ] 2>/dev/null || continue
             printf '%d\n' $(( sc * 10 / scode ))
           done | sort -n | awk '{v[NR]=$1} END{ if (NR==0) exit; print v[int((NR+1)/2)] }')
    case "${base:-}" in ''|*[!0-9]*) exit 0 ;; esac
    [ -n "$key" ] && printf 'base %s %s\n' "$key" "$base" >> "$state" 2>/dev/null
  fi

  fratio=$(( fc * 10 / fcode ))
  limit=$(( base * MULT / 10 ))
  [ "$limit" -lt "$FLOOR" ] && limit="$FLOOR"

  # LEDGER. Every measurement, warned or not — machine-local, never in the project
  # tree, capped, and read by nothing automatically. Same placement and same honest
  # framing as verbosity.sh's: it exists so the thresholds above can be revisited
  # against real data rather than re-argued.
  ledger="${HOME:-/tmp}/.claude/comment-discipline/density-ledger.jsonl"
  if [ "$(wc -c < "$ledger" 2>/dev/null || echo 0)" -lt 1048576 ]; then
    mkdir -p "${ledger%/*}" 2>/dev/null &&
      jq -cn --arg s "$sid" --arg f "$fp" --arg e "$ext" --argjson c "$fc" \
             --argjson cd "$fcode" --argjson r "$fratio" --argjson b "$base" --argjson l "$limit" \
        '{session:$s,file:$f,ext:$e,comment:$c,code:$cd,ratio_tenths:$r,baseline_tenths:$b,limit_tenths:$l,warned:($r>$l)}' \
        >> "$ledger" 2>/dev/null
  fi

  printf 'file %s\n' "$fp" >> "$state" 2>/dev/null
  [ "$rfp" = "$fp" ] || printf 'file %s\n' "$rfp" >> "$state" 2>/dev/null
  [ "$fratio" -gt "$limit" ] || exit 0
  printf 'warn %s\n' "$fp" >> "$state" 2>/dev/null

  msg=$(awk -v f="$(basename "$fp")" -v c="$fc" -v cd="$fcode" -v r="$fratio" -v b="$base" -v n="$((warned + 1))" -v m="$MAX_WARN" \
    'BEGIN { printf "comment-discipline: %s is %.1f:1 comment-to-code (%d comment lines, %d code); its siblings run %.1f:1. Comment volume is judged against the surrounding code, not a constant — if this file genuinely needs the extra prose (vendor quirks, a protocol the code cannot show), keep it and move on. Otherwise the routing table in the comment-discipline skill says where those facts belong: a name, a type, a test. Warning %d of %d this session.", f, r/10, c, cd, b/10, n, m }')

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}' 2>/dev/null || exit 0
  exit 0
} 2>/dev/null
exit 0
