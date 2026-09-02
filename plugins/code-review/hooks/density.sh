#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# Comment-VOLUME guard, two lanes. PostToolUse (warn-only, at most 3 warnings per
# session) compares the file just written against the comment density of its OWN
# siblings AND against an absolute ceiling, and says so when it is over either.
# PreToolUse (deny, Write only, once per file per session) refuses a whole new file
# whose comment-to-code ratio is over the ceiling before it lands. Silence is the
# common case.
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
# WHY SIBLINGS. A driver with vendor quirks earns more prose than a controller, and
# "twice the surrounding code" is a signal no constant can give: a run at 0.3:1 in a
# repo that sits at 0.1:1 is an outlier the ceiling below would wave through. This
# hook reaches subagents, which is where writing actually happens and where a prose
# contract had no delivery channel.
#
# WHY A CEILING TOO (2026-09-02, owner decision). Siblings alone had two holes. A
# greenfield subtree with no tracked siblings got no judgment at all, which is the
# fan-out case this hook was written for. And a repo whose committed house style is
# already heavy certified more of the same. The marketplace's stated default is code
# that speaks for itself — minimal comments, a docblock only for what the signature
# cannot state — so the limit is now min(2x the sibling median, CEIL), and a file with
# no siblings is judged against CEIL alone. CEIL is 0.4:1 by default and is the one
# constant here; a project with a deliberately heavier style overrides it per project
# via `COMMENT_DISCIPLINE_CEILING_TENTHS` in its settings `env` (e.g. 10 for 1:1, 0 to
# switch the ceiling off and keep the sibling test). The deny lane uses the same CEIL.
#
# LIMITATION (honest scope — the four laws, see
# claude-authoring/skills/authoring-skills/SKILL.md "The four laws"):
#   - The PostToolUse lane is WARN-ONLY: `additionalContext` is not a blocking key. The
#     file is already on disk. It informs the next write, never the one that tripped it.
#     The PreToolUse lane denies, but only a `Write` (an Edit carries a fragment, and a
#     fragment's ratio says nothing about the file), only over CEIL, and only ONCE per
#     file per session with the same marker-on-disk bound as scan.sh — so a false
#     positive costs one turn and the second attempt goes through with a warning.
#   - A ratio is not a judgment. A file legitimately denser than its siblings (the one
#     driver full of vendor workarounds) trips this, and that is a false positive the
#     author should overrule by keeping the comments and moving on — the message says so.
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
#     absolute floor of 0.3 so a repo that comments almost nothing cannot make a single
#     why-comment an outlier, then capped at CEIL. The floor was 0.8 while the sibling
#     test was the only test; it dropped with the ceiling, since a floor above the
#     ceiling would have made the sibling test dead code. Calibrated against one
#     observed failure (house 0.85-1.26, produced 1.71-1.85) and one repo, and the
#     ledger records every measurement so that can be revisited against real data
#     instead of re-argued.
#
# FAIL-OPEN: missing jq/awk, unreadable file, too few siblings, or any error exits 0.
{
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v awk >/dev/null 2>&1 || exit 0

  input=$(cat)
  event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null) || exit 0
  case "$event" in PostToolUse|PreToolUse) ;; *) exit 0 ;; esac
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac
  # Only a whole file has a ratio, and only a Write carries a whole file.
  [ "$event" = "PreToolUse" ] && [ "$tool" != "Write" ] && exit 0

  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [ -n "$fp" ] || exit 0
  if [ "$event" = "PostToolUse" ]; then [ -f "$fp" ] && [ -r "$fp" ] || exit 0; fi
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
  FLOOR=3            # 0.3, in tenths — absolute lower bound on "outlier"
  CEIL=${COMMENT_DISCIPLINE_CEILING_TENTHS:-4}   # 0.4, in tenths; 0 switches the ceiling off
  case "$CEIL" in ''|*[!0-9]*) CEIL=4 ;; esac
  MAX_WARN=3

  dir="$cwd/.claude/comment-discipline"
  # Hashed, not raw: `.transcript_path` is an absolute path, so `density-$sid` names a
  # nested file whose parents are never created. Every state write then fails silently,
  # `warned` stays 0, MAX_WARN never engages, the per-file dedup never engages, and the
  # self-output filter below never engages — so a track run raises the sibling median to
  # match its own dense output and certifies the drift it just wrote. Same idiom as
  # code-review/hooks/conventions.sh:59 and lean/hooks/budget.sh:64.
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  state="$dir/density-$ctx"
  # Same rule as scan.sh's deny lane and verbosity.sh: a bound that cannot be recorded
  # is not a bound. Unwritable state means this hook does nothing at all, rather than
  # warning on every single edit for the rest of the session.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  # ---- one shared counter, applied identically to the file and to its siblings ----
  ratio_of() { # $@ files (none = stdin) -> "<comment> <code>"
    awk '
      FNR==1 { }
      { s=$0; sub(/^[ \t]+/,"",s)
        if (s == "") next
        if (s ~ /^(\/\/|\/\*|\*|#|--)/) { c++; next }
        code++ }
      END { printf "%d %d\n", c+0, code+0 }' "$@" 2>/dev/null
  }

  # ---- PreToolUse lane: deny a whole new file over CEIL, ONCE per file ----------
  # Same bound and the same reasoning as scan.sh's deny: the model wrote it, so the
  # model is the audience; `ask` would interrupt the human for a style call; and a
  # deny that cannot record its one-shot marker is withheld rather than left unbounded.
  if [ "$event" = "PreToolUse" ]; then
    [ "$CEIL" -gt 0 ] || exit 0
    content=$(printf '%s' "$input" | jq -r '.tool_input.content // empty' 2>/dev/null) || exit 0
    [ -n "$content" ] || exit 0
    printf '%s\n' "$content" | head -5 | grep -qiE '@generated|generated by|do not edit' && exit 0
    read -r pc pcode <<EOF
$(printf '%s\n' "$content" | ratio_of)
EOF
    case "${pc:-}${pcode:-}" in ''|*[!0-9]*) exit 0 ;; esac
    [ "$pcode" -ge "$MIN_CODE" ] || exit 0
    [ "$(( pc + pcode ))" -ge "$MIN_LINES" ] || exit 0
    pratio=$(( pc * 10 / pcode ))
    [ "$pratio" -gt "$CEIL" ] || exit 0
    key=$(printf '%s' "$fp" | (command -v shasum >/dev/null 2>&1 && shasum || cksum) 2>/dev/null | cut -d' ' -f1)
    [ -n "$key" ] || exit 0
    marker="$dir/density-blocked-$ctx-$key"
    [ -e "$marker" ] && exit 0
    : > "$marker" 2>/dev/null || exit 0
    [ -e "$marker" ] || exit 0
    reason=$(awk -v f="$(basename "$fp")" -v c="$pc" -v cd="$pcode" -v r="$pratio" -v l="$CEIL" \
      'BEGIN { printf "comment-discipline: %s would be %.1f:1 comment-to-code (%d comment lines, %d code); the ceiling is %.1f:1. Write it again with the code carrying the meaning: keep only a why-this-not-the-obvious, an external constraint with a link, a deliberate no-op, or a contract fact the signature cannot state (units, ownership, what throws) — and move the rest to a name, a type, or a test. Blocked once per file; a repeat write goes through with a warning instead.", f, r/10, c, cd, l/10 }')
    jq -cn --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    exit 0
  fi

  warned=0
  if [ -r "$state" ]; then
    warned=$(grep -c '^warn ' "$state" 2>/dev/null) || warned=0
    case "$warned" in ''|*[!0-9]*) warned=0 ;; esac
    [ "$warned" -ge "$MAX_WARN" ] && exit 0
    grep -qxF "file $fp" "$state" 2>/dev/null && exit 0   # already reported this file
  fi

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
    # Median of the per-sibling ratios in tenths. Median, not mean: one 90%-comment
    # interface file in the sample must not redefine the house style by itself.
    # No usable siblings leaves base empty, and the ceiling alone judges the file.
    if [ "$n" -ge "$MIN_SIBLINGS" ]; then
      base=$(printf '%s\n' "$sibs" | while IFS= read -r s; do
               [ -f "$s" ] && [ -r "$s" ] || continue
               read -r sc scode <<EOS
$(ratio_of "$s")
EOS
               [ "${scode:-0}" -ge 10 ] 2>/dev/null || continue
               printf '%d\n' $(( sc * 10 / scode ))
             done | sort -n | awk '{v[NR]=$1} END{ if (NR==0) exit; print v[int((NR+1)/2)] }')
      case "${base:-}" in ''|*[!0-9]*) base="" ;; esac
      [ -n "$base" ] && [ -n "$key" ] && printf 'base %s %s\n' "$key" "$base" >> "$state" 2>/dev/null
    fi
  fi

  fratio=$(( fc * 10 / fcode ))
  if [ -n "$base" ]; then
    limit=$(( base * MULT / 10 ))
    [ "$limit" -lt "$FLOOR" ] && limit="$FLOOR"
    [ "$CEIL" -gt 0 ] && [ "$limit" -gt "$CEIL" ] && limit="$CEIL"
  else
    [ "$CEIL" -gt 0 ] || exit 0
    limit="$CEIL"
  fi

  # LEDGER. Every measurement, warned or not — machine-local, never in the project
  # tree, capped, and read by nothing automatically. Same placement and same honest
  # framing as verbosity.sh's: it exists so the thresholds above can be revisited
  # against real data rather than re-argued.
  ledger="${HOME:-/tmp}/.claude/comment-discipline/density-ledger.jsonl"
  if [ "$(wc -c < "$ledger" 2>/dev/null || echo 0)" -lt 1048576 ]; then
    mkdir -p "${ledger%/*}" 2>/dev/null &&
      jq -cn --arg s "$sid" --arg f "$fp" --arg e "$ext" --argjson c "$fc" \
             --argjson cd "$fcode" --argjson r "$fratio" --argjson b "${base:--1}" --argjson l "$limit" \
        '{session:$s,file:$f,ext:$e,comment:$c,code:$cd,ratio_tenths:$r,baseline_tenths:$b,limit_tenths:$l,warned:($r>$l)}' \
        >> "$ledger" 2>/dev/null
  fi

  printf 'file %s\n' "$fp" >> "$state" 2>/dev/null
  [ "$rfp" = "$fp" ] || printf 'file %s\n' "$rfp" >> "$state" 2>/dev/null
  [ "$fratio" -gt "$limit" ] || exit 0
  printf 'warn %s\n' "$fp" >> "$state" 2>/dev/null

  msg=$(awk -v f="$(basename "$fp")" -v c="$fc" -v cd="$fcode" -v r="$fratio" -v b="${base:--1}" -v l="$limit" -v n="$((warned + 1))" -v m="$MAX_WARN" \
    'BEGIN {
      if (b >= 0) printf "comment-discipline: %s is %.1f:1 comment-to-code (%d comment lines, %d code); its siblings run %.1f:1 and the limit here is %.1f:1.", f, r/10, c, cd, b/10, l/10
      else        printf "comment-discipline: %s is %.1f:1 comment-to-code (%d comment lines, %d code); no committed siblings to compare against, so the ceiling of %.1f:1 applies.", f, r/10, c, cd, l/10
      printf " The default is code that needs no comment. If this file genuinely needs the prose (vendor quirks, a protocol the code cannot show), keep it and move on; otherwise keep only why-comments, linked constraints, deliberate no-ops and contract facts the signature cannot state, and move the rest to a name, a type, or a test. Warning %d of %d this session.", n, m }')

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}' 2>/dev/null || exit 0
  exit 0
} 2>/dev/null
exit 0
