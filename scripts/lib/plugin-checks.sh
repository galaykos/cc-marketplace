#!/usr/bin/env bash
# Per-plugin checks sourced by validate.sh, context-budget.sh, official-validate.sh, generate.sh, done-gate.sh and authoring-guard.sh; sourcing sets only host constants and removed-plugin lists.
# Every input is an argument and no caller global is read, except by pc_removed_refs, which reads those lists and PC_REMOVED_PLUGINS_TSV.
# Why, limits, history: rationale/derivations/scripts-lib.md § scripts/lib/plugin-checks.sh

. "$(dirname "${BASH_SOURCE[0]}")/../host-constants.sh" \
  || echo "plugin-checks.sh: cannot source scripts/host-constants.sh — the per-entry description cap is unset" >&2

_PC_REMOVED_TSV_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/removed-plugins.tsv"

# _pc_removed_lists — sets _PC_RR_PLUG (prose_match plug|both) and _PC_RR_MOVED (moved|both) from the removed-plugins ledger, cached by the path read.
# Returns 1 on an unreadable file, a malformed row or an empty list: a stray ( or an empty () alternation would pass or match every file.
# Why, limits, history: rationale/derivations/scripts-lib.md § _pc_removed_lists
_pc_removed_lists() {
  local src="${PC_REMOVED_PLUGINS_TSV:-$_PC_REMOVED_TSV_DEFAULT}" lists plug moved
  [ "$src" = "${_PC_RR_SRC:-}" ] && return 0
  _PC_RR_BAD=$src
  [ -r "$src" ] || return 1
  lists=$(awk -F'\t' '
    /^#/ { next }
    { sub(/\r$/, "") }
    /^[ \t]*$/ { next }
    NF < 5 || $1 !~ /^[a-z0-9][a-z0-9-]*$/ || $4 !~ /^(plug|moved|both|no)$/ { if (!bad) at = FNR; bad = 1; next }
    $4 == "plug" || $4 == "both" { p = p (p == "" ? "" : "|") $1 }
    $4 == "moved" || $4 == "both" { m = m (m == "" ? "" : "|") $1 }
    END { print p "\t" m "\t" at; exit bad }' "$src") || { _PC_RR_BAD="$src:${lists##*$'\t'}"; return 1; }
  plug=${lists%%$'\t'*}
  lists=${lists#*$'\t'}
  moved=${lists%%$'\t'*}
  [ -n "$plug" ] && [ -n "$moved" ] || return 1
  _PC_RR_PLUG=$plug _PC_RR_MOVED=$moved _PC_RR_SRC=$src
}
# Primed at source time: callers run pc_removed_refs in a $(…) subshell, where a cache filled inside the call dies with it.
_pc_removed_lists \
  || echo "plugin-checks.sh: removed-plugins ledger unreadable, empty or malformed: ${_PC_RR_BAD:-${PC_REMOVED_PLUGINS_TSV:-$_PC_REMOVED_TSV_DEFAULT}} — pc_removed_refs fails every file until it is restored" >&2

# pc_skill_budget <skill_md> — a body over 200 lines or 14,000 bytes, or a line over 300 chars outside fences and tables: prints "budget <path> lines|bytes|line-length <n>".
# Misses frontmatter (validate.sh's description linter), fences and table rows, value per byte and any floor; drift under the cap is pc_budget_crowding's.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_skill_budget
pc_skill_budget() {
  local f="$1" n bytes maxlen maxline
  [ -f "$f" ] || return 0
  n=$(awk '/^---$/{c++; next} c>=2' "$f" | wc -l | tr -d ' ')
  if [ "$n" -gt 200 ]; then
    printf 'budget %s lines %s\n' "$f" "$n"
    return 1
  fi
  bytes=$(awk '/^---$/{c++; next} c>=2' "$f" | wc -c | tr -d ' ')
  if [ "$bytes" -gt 14000 ]; then
    printf 'budget %s bytes %s\n' "$f" "$bytes"
    return 1
  fi
  maxline=$(awk '
    /^---$/ { c++; next }
    c < 2   { next }
    /^[[:space:]]*```/ { fence = !fence; next }
    fence   { next }
    /^[[:space:]]*\|/ { next }
    { if (length($0) > len) { len = length($0); ln = NR } }
    END { if (len > 0) print len " " ln }
  ' "$f")
  maxlen=${maxline%% *}
  if [ -n "$maxlen" ] && [ "$maxlen" -gt 300 ]; then
    printf 'budget %s line-length %s :%s\n' "$f" "$maxlen" "${maxline##* }"
    return 1
  fi
  return 0
}

# pc_hook_timeout <plugins_root> — a plugins/*/hooks/hooks.json entry with no `timeout`: prints "hook-timeout <plugin>:<event>:<script>" per entry, returns 1.
# Misses whether the number is right and what a killed hook does (agent-graded, per plugin); with no jq it returns 0.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_hook_timeout
pc_hook_timeout() {
  local root="${1:-plugins}" bad=0 d p hj
  command -v jq >/dev/null 2>&1 || return 0
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    p=$(basename "$d")
    hj="$d/hooks/hooks.json"
    [ -f "$hj" ] || continue
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      printf 'hook-timeout %s:%s\n' "$p" "$line"
      bad=1
    done < <(jq -r '.hooks // {} | to_entries[] as $e
                    | $e.value[].hooks[]
                    | select(has("timeout") | not)
                    | "\($e.key):\(.command | gsub("\""; "") | split("/") | last)"' "$hj" 2>/dev/null)
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  return $bad
}

# _pc_hook_script <command> <plugin_dir> — the script a hooks.json command runs: quotes and one leading `bash `/`sh ` dropped, ${CLAUDE_PLUGIN_ROOT} replaced.
# Misses an interpreter flag (`bash -e`), any other interpreter and arguments after the path; each resolves to no file, so callers skip it.
# Why, limits, history: rationale/derivations/scripts-lib.md § _pc_hook_script
_pc_hook_script() {
  local c=${1//\"/}
  c=${c#"${c%%[![:space:]]*}"}
  case "$c" in bash[[:space:]]*|sh[[:space:]]*) c=${c#*[[:space:]]}; c=${c#"${c%%[![:space:]]*}"} ;; esac
  printf '%s' "${c//\$\{CLAUDE_PLUGIN_ROOT\}/"$2"}"
}

# _pc_hook_interp <command> — `bash` or `sh` when the command starts that interpreter, else nothing.
_pc_hook_interp() {
  local c=${1//\"/}
  c=${c#"${c%%[![:space:]]*}"}
  case "$c" in bash[[:space:]]*) printf bash ;; sh[[:space:]]*) printf sh ;; esac
}

# pc_hook_shebang <plugins_root> — a hooks.json-registered script not opening `#!/bin/bash`: prints "hook-shebang <plugin>:<script> <first line>", returns 1.
# Misses PATH calls inside, hosts without /bin/bash, sourced helpers, bash/sh-led commands (on purpose); no jq, no check. Escape: `# env-shebang-ok: <host or interpreter>`.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_hook_shebang
pc_hook_shebang() {
  local root="${1:-plugins}" bad=0 hj d p sh rel first
  command -v jq >/dev/null 2>&1 || return 0
  while IFS= read -r hj; do
    [ -n "$hj" ] || continue
    d=$(dirname "$(dirname "$hj")"); p=$(basename "$d")
    while IFS= read -r sh; do
      [ -n "$sh" ] || continue
      [ -z "$(_pc_hook_interp "$sh")" ] || continue
      sh=$(_pc_hook_script "$sh" "$d")
      [ -f "$sh" ] || continue
      rel=$(basename "$sh")
      IFS= read -r first < "$sh" || true
      case "$first" in '#!/bin/bash'*) continue ;; esac
      grep -qF 'env-shebang-ok:' "$sh" 2>/dev/null && continue
      printf 'hook-shebang %s:%s %s\n' "$p" "$rel" "$first"
      bad=1
    done <<EOF
$(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]?
         | select(.type=="command") | .command | gsub("\""; "")' "$hj" 2>/dev/null | sort -u)
EOF
  done <<EOF
$(find "$root" -mindepth 3 -maxdepth 3 -name hooks.json -print 2>/dev/null | sort)
EOF
  return $bad
}

# pc_cwd_validated <plugins_root> — a hook running `mkdir -p` on a path from payload cwd before `[ -d "$cwd" ]`, a test inside it or `cd "$cwd"`: prints "cwd-unvalidated <plugin>:<script> …".
# Misses a live cwd of another project, taint through a transform, writes other than mkdir -p, sourced scripts; no jq, no check. Escape: `# cwd-mkdir-ok: <why resurrect>`.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_cwd_validated
pc_cwd_validated() {
  local root="${1:-plugins}" bad=0 hj d p sh rel out
  command -v jq >/dev/null 2>&1 || return 0
  while IFS= read -r hj; do
    [ -n "$hj" ] || continue
    d=$(dirname "$(dirname "$hj")"); p=$(basename "$d")
    while IFS= read -r sh; do
      [ -n "$sh" ] || continue
      sh=$(_pc_hook_script "$sh" "$d")
      [ -f "$sh" ] || continue
      grep -qF 'cwd-mkdir-ok:' "$sh" 2>/dev/null && continue
      rel=$(basename "$sh")
      out=$(awk '
        BEGIN { seeded = 0; validated = 0; tainted["cwd"] = 1 }
        {
          line = $0
          t = line; sub(/^[ \t]+/, "", t)
          if (t ~ /^#/) next                       # headers DISCUSS the pattern
          sub(/[ \t]*#.*$/, "", line)              # and so do trailing comments
          if (line ~ /cwd[ \t]*=.*\.cwd/) { seeded = 1; next }
          if (!seeded) next
          if (line ~ /-d[ \t]+"\$\{?cwd\}?"/)         validated = 1
          if (line ~ /-[defrswx][ \t]+"\$\{?cwd\}?\//) validated = 1
          if (line ~ /cd[ \t]+"\$\{?cwd\}?"/)         validated = 1
          if (match(line, /^[ \t]*(local[ \t]+)?[A-Za-z_][A-Za-z0-9_]*=/)) {
            lhs = substr(line, RSTART, RLENGTH)
            sub(/^[ \t]*(local[ \t]+)?/, "", lhs); sub(/=$/, "", lhs)
            rhs = substr(line, RSTART + RLENGTH)
            for (v in tainted) if (rhs ~ ("\\$" v "/") || rhs ~ ("\\$\\{" v "\\}/")) { tainted[lhs] = 1; break }
          }
          if (line ~ /mkdir[ \t]+-p/ && !validated) {
            for (v in tainted)
              if (line ~ ("\\$" v "[/\"]") || line ~ ("\\$\\{" v "\\}")) { printf "%d:%s", FNR, t; exit }
          }
        }' "$sh")
      [ -z "$out" ] && continue
      printf 'cwd-unvalidated %s:%s %s\n' "$p" "$rel" "$out"
      bad=1
    done <<EOF
$(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]?
         | select(.type=="command") | .command | gsub("\""; "")' "$hj" 2>/dev/null | sort -u)
EOF
  done <<EOF
$(find "$root" -mindepth 3 -maxdepth 3 -name hooks.json -print 2>/dev/null | sort)
EOF
  return $bad
}

# pc_state_root <plugins_root> — a registered hook building a path from `$cwd/.claude` instead of cc_state_root: prints "state-root-raw <plugin>:<script> <line>:<stmt>", returns 1.
# Misses the cwd copied to another variable, $PWD in model-run scripts, an ignored cc_state_root result; comment lines skipped. Escape: `# state-root-ok: <why per-directory>`.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_state_root
pc_state_root() {
  local root="${1:-plugins}" bad=0 hj d p sh out
  command -v jq >/dev/null 2>&1 || return 0
  while IFS= read -r hj; do
    [ -n "$hj" ] || continue
    d=$(dirname "$(dirname "$hj")"); p=$(basename "$d")
    while IFS= read -r sh; do
      [ -n "$sh" ] || continue
      sh=$(_pc_hook_script "$sh" "$d")
      [ -f "$sh" ] || continue
      grep -qF 'state-root-ok:' "$sh" 2>/dev/null && continue
      out=$(awk '
        { t = $0; sub(/^[ \t]+/, "", t); if (t ~ /^#/) next
          if ($0 ~ /\$\{?cwd\}?"?\/\.claude/) { printf "%d:%s", FNR, t; exit } }' "$sh")
      [ -z "$out" ] && continue
      printf 'state-root-raw %s:%s %s\n' "$p" "$(basename "$sh")" "$out"
      bad=1
    done <<HOOKS
$(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]?
         | select(.type=="command") | .command | gsub("\""; "")' "$hj" 2>/dev/null | sort -u)
HOOKS
  done <<FILES
$(find "$root" -mindepth 3 -maxdepth 3 -name hooks.json -print 2>/dev/null | sort)
FILES
  return $bad
}

# pc_shared_blocks <plugins_root> <blocks_dir> — a .sh defining a function owned by a templates/blocks/ block (pairs below) without the block byte-for-byte: prints "shared-block-drift <path> <block>".
# Misses a hook reimplementing the helper under another name, or calling it without defining it (its own harness catches that).
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_shared_blocks
pc_shared_blocks() {
  local root="${1:-plugins}" bdir="${2:-templates/blocks}" bad=0 f blk content fn name pair
  for pair in state-root:cc_state_root bash-write-targets:cc_bash_write_targets bash-write-chunks:cc_bash_write_chunks option-resolver:cc_option plugin-state:cc_plugin_state heredoc-bodies:cc_strip_heredoc_bodies 'bash-write-effects:cc_bash_(effects_mark|write_effects)' 'prompt-shape:cc_prompt_[a-z_]+' 'write-scope:cc_scope_[a-z]+'; do
    name=${pair%%:*}; fn=${pair#*:}
    [ -r "$bdir/$name.md" ] || continue
    blk=$(cat "$bdir/$name.md")
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      content=$(cat "$f")
      [[ "$content" == *"$blk"* ]] && continue
      printf 'shared-block-drift %s %s\n' "$f" "$name.md"
      bad=1
    done <<DEFS
$(grep -rlE "^[[:space:]]*$fn\(\)[[:space:]]*\{" "$root" --include='*.sh' 2>/dev/null | sort)
DEFS
  done
  return $bad
}

# pc_switch_reads <hook> — the off-switch names one hook reads, sorted: `${NAME:-`, `plugin_switch=NAME`, `cc_option NAME`; in a module `$.env.get('NAME')`, and registerSuggestion( as CC_SUGGEST.
# One source for pc_offswitch_named and generate.sh's off-switch table. Skips comment lines and host variables; never pass it cc-kit.ts, which reads CC_SUGGEST in every mod.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_switch_reads
pc_switch_reads() {
  local shape='CC_[A-Z0-9_]+|CLAUDE_[A-Z0-9_]+|[A-Z0-9_]+_BOOST|[A-Z0-9_]+_STOP_GATE'
  { grep -ohE "\\\$\\{($shape):-" "$1" | sed -E 's/^\$\{//; s/:-$//'
    grep -ohE '^[[:space:]]*plugin_switch=[A-Z0-9_]+' "$1" | sed -E 's/.*=//'
    grep -v '^[[:space:]]*#' "$1" \
      | grep -oE "cc_option[[:space:]]+[\"']?[A-Za-z0-9_]+" \
      | sed -E "s/^cc_option[[:space:]]+[\"']?//" | grep -xE "$shape"
    case $1 in
      *.ts|*.tsx|*.mts|*.cts|*.js|*.mjs)
        grep -vE '^[[:space:]]*(//|/?\*)' "$1" \
          | grep -oE "\\\$\\.env\\.get\\([\"']($shape)[\"']\\)" | sed -E "s/^.*\\([\"']//; s/[\"']\\)$//"
        # awk reads to EOF: a piped `grep -q` exits early, and under pipefail SIGPIPE drops the switch.
        awk '/^[[:space:]]*(\/\/|\/?\*)/ { next }
             /(^|[^A-Za-z0-9_$])registerSuggestion\(/ { found = 1 }
             END { if (found) print "CC_SUGGEST" }' "$1" ;;
    esac
  } 2>/dev/null \
    | grep -vxE 'CLAUDE_PLUGIN_ROOT|CLAUDE_PROJECT_DIR|CLAUDE_CONFIG_DIR|CLAUDE_CODE_SESSION_ID|CLAUDE_PLUGIN_DATA' \
    | LC_ALL=C sort -u
  return 0
}

# pc_offswitch_named <plugins_root> — a registered hook that can refuse (deny/ask, exit 2, decision block) and reads an off switch it names in no non-comment prose: "offswitch-unnamed …".
# Gates the file, not each refusal message (agent-graded); misses a wrong switch, one read another way or via a variable. Escape: `# offswitch-ok: <why not tell the user>`.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_offswitch_named
pc_offswitch_named() {
  local root="${1:-plugins}" bad=0 hj d p sh rel sw named
  command -v jq >/dev/null 2>&1 || return 0
  while IFS= read -r hj; do
    [ -n "$hj" ] || continue
    d=$(dirname "$(dirname "$hj")"); p=$(basename "$d")
    while IFS= read -r sh; do
      [ -n "$sh" ] || continue
      sh=$(_pc_hook_script "$sh" "$d")
      [ -f "$sh" ] || continue
      grep -qF 'offswitch-ok:' "$sh" 2>/dev/null && continue
      # Refusal-capable by any channel; comment lines are stripped, so a header DISCUSSING exit 2 does not bring a hook into scope.
      grep -v '^[[:space:]]*#' "$sh" \
        | grep -qE 'permissionDecision[^,}]*(deny|ask)|permissionDecision:[[:space:]]*\$|exit 2|decision\\?"?[[:space:]]*:[[:space:]]*\\?"block' || continue
      sw=$(pc_switch_reads "$sh")
      [ -n "$sw" ] || continue
      named=0
      while IFS= read -r v; do
        [ -n "$v" ] || continue
        grep -v '^[[:space:]]*#' "$sh" \
          | sed -E "s/cc_option[[:space:]]+[\"']?[A-Za-z0-9_]+//g" \
          | grep -qE "[^A-Z_$\{]$v" && { named=1; break; }
      done <<EOF
$sw
EOF
      [ "$named" -eq 1 ] && continue
      rel=$(basename "$sh")
      printf 'offswitch-unnamed %s:%s %s\n' "$p" "$rel" "$(printf '%s' "$sw" | tr '\n' ' ' | sed 's/ $//')"
      bad=1
    done <<EOF
$(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]?
         | select(.type=="command") | .command | gsub("\""; "")' "$hj" 2>/dev/null | sort -u)
EOF
  done <<EOF
$(find "$root" -mindepth 3 -maxdepth 3 -name hooks.json -print 2>/dev/null | sort)
EOF
  return $bad
}

# pc_version_stamp_tail <plugins_root> — a SKILL.md whose frontmatter claims pinned, version leverage or installed version, with no npm:/composer:/pypi: tail on its `Last verified` stamp.
# Prints "version-stamp-tail <plugin>:<skill> <why>". Misses a false tail, other phrasings, body-only claims, other registries. Escape: `<!-- version-tail-ok: <the source> -->`.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_version_stamp_tail
pc_version_stamp_tail() {
  local root="${1:-plugins}" bad=0 f p s fm stamp
  for f in "$root"/*/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    grep -qF 'version-tail-ok:' "$f" && continue
    fm=$(awk 'BEGIN{n=0} /^---$/{n++; next} n==1{print} n>=2{exit}' "$f")
    printf '%s\n' "$fm" | grep -qiE 'pinned|version leverage|installed version' || continue
    p=$(basename "$(dirname "$(dirname "$(dirname "$f")")")")
    s=$(basename "$(dirname "$f")")
    stamp=$(grep -m1 'Last verified' "$f")
    if [ -z "$stamp" ]; then
      printf 'version-stamp-tail %s:%s no "Last verified" stamp at all\n' "$p" "$s"
    elif ! printf '%s' "$stamp" | grep -qE '(npm|composer|pypi):'; then
      printf 'version-stamp-tail %s:%s stamp has no npm:/composer:/pypi: tail\n' "$p" "$s"
    else
      continue
    fi
    bad=1
  done
  return $bad
}

# pc_command_arg_hint <plugins_root> — a commands/*.md whose body reads $ARGUMENTS or $<n> with no `argument-hint:` in its frontmatter: prints "command-arg-hint <plugin>:<cmd>", returns 1.
# Misses a hint that misdescribes the input (agent-graded) and input taken without naming $ARGUMENTS; over-reports a `$1` in a shell fence.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_command_arg_hint
pc_command_arg_hint() {
  local root="${1:-plugins}" bad=0 f p body fm
  for f in "$root"/*/commands/*.md; do
    [ -f "$f" ] || continue
    p=$(basename "$(dirname "$(dirname "$f")")")
    body=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$f")
    fm=$(awk 'BEGIN{n=0} /^---$/{n++; next} n==1{print}' "$f")
    # Here-strings, not pipes: an early-exiting grep -q broke the writer's pipe in CI (run 40210716420).
    grep -qE '\$ARGUMENTS|\$[0-9]' <<<"$body" || continue
    grep -q '^argument-hint:' <<<"$fm" && continue
    printf 'command-arg-hint %s:%s\n' "$p" "$(basename "$f" .md)"
    bad=1
  done
  return $bad
}

# pc_budget_crowding <plugins_root> <baseline_file> — more skill bodies at 198+ lines (3 under the 200 cap) than the committed ratchet: prints "crowding <n> > <baseline>" and each file.
# Misses quality, moves that net zero, a body parked just outside the window, and byte crowding. Lower the baseline when skills are cut; never raise it to pass.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_budget_crowding
pc_budget_crowding() {
  local root="${1:-plugins}" base_file="${2:-scripts/skill-crowding-baseline.json}"
  local baseline count f n crowded=""
  [ -f "$base_file" ] || return 0
  baseline=$(sed -n 's/.*"within_3_of_line_cap"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$base_file")
  case "$baseline" in ''|*[!0-9]*) return 0 ;; esac
  count=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$(awk '/^---$/{c++; next} c>=2' "$f" | wc -l | tr -d ' ')
    if [ "$n" -ge 198 ]; then
      count=$((count + 1))
      crowded="$crowded  $f ($n)
"
    fi
  done < <(find "$root" -mindepth 4 -maxdepth 4 -type f -name 'SKILL.md' 2>/dev/null | sort)
  if [ "$count" -gt "$baseline" ]; then
    printf 'crowding %s > %s\n' "$count" "$baseline"
    printf '%s' "$crowded"
    return 1
  fi
  return 0
}

# pc_plugin_corpus <plugins_root> <baseline_file> — more plugins than the ratchet whose skills/ .md (generated excluded) pass 160,000 B: prints "corpus <n> > <baseline>" and each plugin.
# Bytes on disk, not tokens read; misses growth under the cap and chains across plugins, and the cap is a choice. Never raise the baseline to pass.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_plugin_corpus
pc_plugin_corpus() {
  local root="${1:-plugins}" base_file="${2:-scripts/plugin-corpus-baseline.json}"
  local cap=160000
  local baseline count d pl bytes over=""
  [ -f "$base_file" ] || return 0
  baseline=$(sed -n 's/.*"plugins_over_cap"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$base_file")
  case "$baseline" in ''|*[!0-9]*) return 0 ;; esac
  count=0
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    pl=$(basename "$(dirname "$d")")
    bytes=$(find "$d" -type f -name '*.md' 2>/dev/null | while IFS= read -r f; do
      head -c 400 "$f" 2>/dev/null | grep -qi 'generated' && continue
      wc -c < "$f" 2>/dev/null
    done | awk '{s+=$1} END {printf "%d", s+0}')
    if [ "$bytes" -gt "$cap" ]; then
      count=$((count + 1))
      over="$over  $pl ($bytes B, ~$((bytes / 4)) tok)
"
    fi
  done < <(find "$root" -mindepth 2 -maxdepth 2 -type d -name skills 2>/dev/null | sort)
  if [ "$count" -gt "$baseline" ]; then
    printf 'corpus %s > %s (cap %s B/plugin)\n' "$count" "$baseline" "$cap"
    printf '%s' "$over"
    return 1
  fi
  return 0
}

# pc_jargon <md_path> — internal taskmaster vocabulary shapes outside an ordinary-English rescue list: prints the matches comma-joined, returns 1.
# A heuristic, not a parser: misses a leak sharing a line with a rescued phrase, and unrescued English false-positives (escape `<!-- jargon-ok -->`).
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_jargon
pc_jargon() {
  local f="$1" hit jargon rescue
  [ -f "$f" ] || return 0
  jargon='(^|[^[:alnum:]])(cards? #?[0-9][0-9]|finding #[0-9]|smoke[ -]test #?[0-9]|the back-?log)'
  rescue='(credit|debit|gift|payment|loyalty|graphics|SIM|library|report) card|card (number|reader|holder)|(product|sprint|issue|story|user|work) backlog|backlog of|(finding|smoke[ -]test) #?[0-9]+ (in|of|from) '
  hit=$(grep -viF '<!-- jargon-ok -->' "$f" \
        | grep -ivE "$rescue" \
        | grep -iEo "$jargon" \
        | sed 's/^[^[:alnum:]]//' | sort -u | tr '\n' ',' | sed 's/,$//')
  [ -z "$hit" ] && return 0
  printf '%s\n' "$hit"
  return 1
}

# pc_removed_refs <md_path> — a removed plugin (scripts/removed-plugins.tsv), skill or command in a reference shape, or claude-api not called built-in: prints the hits comma-joined, returns 1.
# Misses capitalised names and capability-breadth staleness; an unreadable or malformed ledger fails closed. Lines discussing a removal pass, others need `<!-- removed-ok -->`.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_removed_refs
pc_removed_refs() {
  local f="$1" b plug skills cmds shapes rescue hit capi
  [ -f "$f" ] || return 0
  _pc_removed_lists || {
    printf 'removed-plugins ledger unreadable, empty or malformed: %s — not this file; restore scripts/removed-plugins.tsv or unset PC_REMOVED_PLUGINS_TSV\n' \
      "${_PC_RR_BAD:-${PC_REMOVED_PLUGINS_TSV:-$_PC_REMOVED_TSV_DEFAULT}}"
    return 1
  }
  b='[^[:alnum:]-]'
  # Why each name sits in $plug, $moved or neither: its reason column in scripts/removed-plugins.tsv.
  plug=$_PC_RR_PLUG
  # $moved gets only the plugin-reference shapes: most of those names live on as skill names, npm packages or ordinary words.
  moved=$_PC_RR_MOVED
  bm='[^[:alnum:]/@.-]'   # moved-name boundary: `@inertiajs/vite plugin` is a package, not ours
  # Hyphenates and surveyed bare words only: a bare word must dangle wherever it appears, which is why i18n is absent.
  skills='react-best-practices|css3-best-practices|css-grid-best-practices|flexbox-best-practices|bootstrap-best-practices|simplicity-principles|surgical-coding|strategy-catalog|database-design|opinion-round|task-orchestration|php-best-practices|mysql-best-practices|postgresql-best-practices|vue3-best-practices|nuxt-best-practices|livewire-best-practices|node-backend-best-practices|react-server-state|react-data-grid|terse-crew|terse-commit|terse-compress|real-preview|design-session|estimation'
  # Removed commands, fully qualified: the plugin half is live and the artifact half is ordinary English.
  cmds='approaches:size'
  # Append a shape, never replace one: the ($skills) and ($cmds) clauses are the only guard on removed skill and command names.
  # Write a backtick as \` here, never \\\`: that hands grep \`, GNU grep's start-of-buffer anchor, so the shape fires on macOS and never on Linux CI.
  shapes="/($moved):|\`($moved):[a-z][a-z0-9-]*|(^|$b)plugins/($moved)($b|\$)|(^|$bm)($moved)@|\\*\\*($moved)\\*\\*|(^|$bm)($moved)\`? plugins?($b|\$)|\\*\\*($plug)\\*\\*|(^|$b)($plug)\`? (plugins?|bundles?)($b|\$)|(^|$b)plugins/($plug)($b|\$)|(^|$b)($plug)@|(→|->) ?\`?($plug)($b|\$)|/($plug):|(^|$b)\`($plug)\`($b|\$)|(^|$b)($skills)($b|\$)|(^|$b)($cmds)($b|\$)"
  # Lines discussing a removal stay legal unmarked; each phrase is quoted from a shipped disclosure.
  rescue="(was|were|been|are|is) (removed|merged|retired)|merged into|no longer|plugins? (were|was)($b|\$)"
  # Blank npm:<pkg>@<ver> first: $bm excludes /@.- but not ':', so a package pin read as a plugin reference.
  hit=$(grep -vF '<!-- removed-ok -->' "$f" \
        | sed -E 's/npm:(@[^ ]+\/)?[^ ]+@[0-9]+(\.[0-9]+)?/npm-pin/g' \
        | grep -viE "$rescue" \
        | grep -Eo "$shapes" \
        | sed -e 's/^[^[:alnum:]*]*//' -e 's/[^[:alnum:]*]*$//' | sort -u | tr '\n' ',' | sed 's/,$//')
  capi=$(grep -vF '<!-- removed-ok -->' "$f" \
        | grep -ivE 'built-in|external|harness-provided' \
        | grep -Eo "(^|$b)claude-api($b|\$)" \
        | sed -e 's/^[^[:alnum:]]*//' -e 's/[^[:alnum:]]*$//' | sort -u | tr '\n' ',' | sed 's/,$//')
  if [ -z "$hit" ] && [ -z "$capi" ]; then
    return 0
  fi
  printf '%s\n' "$hit${hit:+${capi:+,}}$capi"
  return 1
}

# pc_doc_location <plugins/<name>/…md> <allow_regex> — a plugin .md whose path below plugins/<name>/ misses the caller's allow regex: prints "doc-location <path>", returns 1.
# Path only: it reads no content, and which files reach it is validate.sh's choice.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_doc_location
pc_doc_location() {
  local mdf="$1" allow="$2" rel
  rel=${mdf#plugins/*/}
  printf '%s\n' "$rel" | grep -qE "$allow" && return 0
  printf 'doc-location %s\n' "$mdf"
  return 1
}

# pc_rules_cofire <rules_tsv> <corpus_dir> — two content rows whose regexes both match one corpus file, unblessed by `# co-fire-ok: content <a> <b>`: prints "cofire <a> <b> <file>", returns 1.
# Proves nothing about code shapes the hand-written corpus lacks, nor whether a blessed co-fire is wise.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_rules_cofire
pc_rules_cofire() {
  local f="$1" corpus="$2" rc=0
  [ -f "$f" ] || return 0
  [ -d "$corpus" ] || return 0
  local blessed pats skills n i j
  blessed=$(grep '^# co-fire-ok:[[:space:]]*content ' "$f" 2>/dev/null \
            | sed 's/^# co-fire-ok:[[:space:]]*content //')
  local -a P S
  while IFS="$(printf '\t')" read -r kind pat skill rest; do
    [ "$kind" = content ] || continue
    P+=("$pat"); S+=("$skill")
  done < <(grep -v '^#' "$f")
  n=${#P[@]}
  for (( i=0; i<n; i++ )); do
    for (( j=i+1; j<n; j++ )); do
      local hit=""
      for c in "$corpus"/*; do
        [ -f "$c" ] || continue
        if grep -qE "${P[$i]}" "$c" 2>/dev/null && grep -qE "${P[$j]}" "$c" 2>/dev/null; then
          hit="$(basename "$c")"; break
        fi
      done
      [ -n "$hit" ] || continue
      printf '%s\n' "$blessed" | grep -qE "(^|[[:space:]])${S[$i]}([[:space:]]|$)" \
        && printf '%s\n' "$blessed" | grep -qE "(^|[[:space:]])${S[$j]}([[:space:]]|$)" \
        && printf '%s\n' "$blessed" | grep -q "${S[$i]} ${S[$j]}\|${S[$j]} ${S[$i]}" && continue
      printf 'cofire %s %s %s\n' "${S[$i]}" "${S[$j]}" "$hit"
      rc=1
    done
  done
  return $rc
}

# pc_rules_overlap <rules_tsv> — two high-confidence glob rows with one pattern, not told apart by differing stack markers or `# co-fire-ok: <pattern> <a> <b>`: prints "overlap <pattern> <a> <b>".
# Content and low-confidence rows are never flagged; subsumption (*.php vs *.blade.php) is out of scope by design.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_rules_overlap
pc_rules_overlap() {
  local f="$1"
  [ -f "$f" ] || return 0
  awk -F'\t' '
    { sub(/\r$/, "") }
    /^# co-fire-ok:/ {
      line = $0
      sub(/^# co-fire-ok:[[:space:]]*/, "", line)
      n = split(line, t, /[[:space:]]+/)
      if (n >= 3) {
        ok[t[1] SUBSEP t[2] SUBSEP t[3]] = 1
        ok[t[1] SUBSEP t[3] SUBSEP t[2]] = 1
      }
      next
    }
    /^#/ { next }
    $1 == "glob" && $5 == "high" {
      m = $6; if (m == "-") m = ""
      # mirror marker_ok fail-open: a marker route.sh would ignore (no "~",
      # empty manifest or regex) must not count as a discriminator here
      if (m != "" && m !~ /^!?[^~]+~.+/) m = ""
      k = $2; cnt[k]++
      skill[k, cnt[k]] = $3; mark[k, cnt[k]] = m
    }
    END {
      bad = 0
      for (k in cnt)
        for (i = 1; i <= cnt[k]; i++)
          for (j = i + 1; j <= cnt[k]; j++) {
            a = skill[k, i]; b = skill[k, j]
            if (a == b) continue
            am = mark[k, i]; bm = mark[k, j]
            if (am != "" && bm != "" && am != bm) continue
            if (ok[k SUBSEP a SUBSEP b]) continue
            printf "overlap %s %s %s\n", k, a, b
            bad = 1
          }
      exit bad
    }' "$f"
}

# pc_rules_reachable <rules_tsv> — a routing row that can never fire: a glob with a / outside `**/dir/**` (route.sh matches basenames), or a content or command ERE that does not compile.
# Prints "unreachable <kind> <pattern> <skill>", returns 1. Structural only: never proves a real file matches.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_rules_reachable
pc_rules_reachable() {
  local tsv="$1" bad=0 kind pattern skill rest
  [ -f "$tsv" ] || return 0
  while IFS=$'\t' read -r kind pattern skill rest; do
    case "$kind" in ''|'#'*) continue ;; esac
    [ -n "$pattern" ] || continue
    case "$kind" in
      glob)
        # The only path-aware form route.sh implements.
        case "$pattern" in '**/'*'/**') continue ;; esac
        # Anything else is basename-matched; a `/` makes it unmatchable.
        case "$pattern" in
          */*) printf 'unreachable glob %s %s\n' "$pattern" "$skill"; bad=1 ;;
        esac ;;
      content|command)
        # A `command` row's ERE runs against the Bash command string; same compile test.
        printf '' | grep -qE "$pattern" 2>/dev/null
        [ $? -gt 1 ] && { printf 'unreachable %s %s %s\n' "$kind" "$pattern" "$skill"; bad=1; } ;;
    esac
  done < "$tsv"
  return $bad
}

# pc_rules_owner <rules_tsv> [plugins_root] — a routing row whose col-4 plugin does not ship its col-3 skill, or has no col 4: prints "rules-owner <skill> <plugin|(missing)>", returns 1.
# Author-time existence only: not whether the plugin is installed (route.sh's runtime filter), the row fires, or it collides.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_rules_owner
pc_rules_owner() {
  local tsv="$1" root="${2:-plugins}" bad=0 kind pattern skill plugin rest
  [ -f "$tsv" ] || return 0
  # `|| [ -n "$kind" ]` mirrors route.sh: an unterminated final row is live at runtime.
  while IFS=$'\t' read -r kind pattern skill plugin rest || [ -n "$kind" ]; do
    case "$kind" in ''|'#'*) continue ;; esac
    if [ -z "$plugin" ]; then
      printf 'rules-owner %s (missing)\n' "$skill"; bad=1; continue
    fi
    [ -f "$root/$plugin/skills/$skill/SKILL.md" ] || { printf 'rules-owner %s %s\n' "$skill" "$plugin"; bad=1; }
  done < "$tsv"
  return $bad
}

# pc_host_overlap <md_path> — a plugin skill or command named like a Claude Code built-in in $hosts: prints "hostoverlap <path> <name>", returns 1. Escape: `<!-- host-ok -->`.
# Name equality only: a differently named skill restating a built-in passes, and the roster goes stale when the host ships a new one.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_host_overlap
pc_host_overlap() {
  local f="$1" bad=0 name host
  [ -f "$f" ] || return 0
  # Built-ins as of CLI 2.1.300 (a session listing plus `strings` on the bundle); older names stay, UI commands and aliases never list.
  local hosts="dataviz artifact-design artifact-capabilities skill-creator claude-api update-config keybindings-help fewer-permission-prompts claude-in-chrome simplify code-review security-review run init loop schedule verify batch deep-research goal skill-doctor artifact-diagramming artifact-components claude-code-docs commit debug design-sync doctor explain-usage insights memory-types plugin-authoring pr run-skill-generator team-onboarding workflow-authoring"
  # Commands too: the host merged commands into skills, so a command competes for a trigger by description like a skill.
  case "$f" in
    */skills/*/SKILL.md) name=$(basename "$(dirname "$f")") ;;
    */commands/*.md)     name=$(basename "$f" .md) ;;
    *) return 0 ;;
  esac
  grep -qF '<!-- host-ok -->' "$f" && return 0
  for host in $hosts; do
    if [ "$name" = "$host" ]; then
      printf 'hostoverlap %s %s\n' "$f" "$name"; bad=1
    fi
  done
  return $bad
}

# pc_cmd_skill_shadow [plugins_root] — one plugin shipping commands/<n>.md and skills/<n>/SKILL.md: prints "shadow <plugin>:<n>", returns 1. Escape: `<!-- shadow-ok: <why> -->`, reason non-empty.
# Misses cross-plugin pairs, paths outside the default dirs, nested commands, project skills, a skill `name:` unlike its dir, and whether a marker's reason is true.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_cmd_skill_shadow
pc_cmd_skill_shadow() {
  local root="${1:-plugins}" bad=0 cmd pdir name
  for cmd in "$root"/*/commands/*.md; do
    [ -f "$cmd" ] || continue
    pdir=${cmd%/commands/*}
    name=$(basename "$cmd" .md)
    ls "$pdir/skills" 2>/dev/null | grep -qxF "$name" || continue
    [ -f "$pdir/skills/$name/SKILL.md" ] || continue
    grep -qE '<!-- shadow-ok:[[:space:]]*[^[:space:]>-][^>]*-->' "$cmd" && continue
    printf 'shadow %s:%s\n' "${pdir##*/}" "$name"
    bad=1
  done
  return $bad
}

# pc_lanes_vocabulary [plugins_root] [vocab_file] — a lane.tsv `owns` noun absent from scripts/lane-vocabulary.txt, or no such file: prints "lane-vocab <file> <noun>", returns 1.
# Bookkeeping only: nothing proves two nouns mean different things or stops a near-duplicate line; the catch is a human reading the list.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_lanes_vocabulary
pc_lanes_vocabulary() {
  local root="${1:-plugins}" vocab="${2:-scripts/lane-vocabulary.txt}" bad=0 f line owns
  # A missing vocabulary fails: returning 0 would let a deleted file disable this gate silently.
  if [ ! -f "$vocab" ]; then printf 'lane-vocab MISSING %s\n' "$vocab"; return 1; fi
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    # `|| [ -n "$line" ]`: the awk-based lane checks see an unterminated last row, so this one must too.
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in ''|'#'*) continue ;; esac
      line=${line%$'\r'}
      # -s: a line with no tab is skipped, not reported whole as an undeclared noun.
      owns=$(printf '%s' "$line" | cut -s -f4)
      [ -n "$owns" ] || continue
      case "$owns" in owns) continue ;; esac
      grep -qxF "$owns" "$vocab" 2>/dev/null && continue
      printf 'lane-vocab %s %s\n' "$f" "$owns"; bad=1
    done < "$f"
  done < <(find "$root" -mindepth 2 -maxdepth 2 -name lane.tsv 2>/dev/null | sort)
  return $bad
}

# pc_twin_files [plugins_root] — a file marked `# TWIN: <path> is an identical copy save this line.` that differs from its partner outside the TWIN lines: prints "twin <a> <b>".
# Gates sameness, not correctness; cannot say which copy is right, and sees only declared pairs.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_twin_files
pc_twin_files() {
  local root="${1:-plugins}" f partner bad=0 a b
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    partner=$(sed -n 's/^# TWIN: \([^ ]*\) is an identical copy save this line.*/\1/p' "$f" | head -1)
    # A reworded marker fails loud: skipping an empty partner would retire the gate while both files still read as a pair.
    if [ -z "$partner" ]; then
      printf 'twin %s (unparseable marker — expected: # TWIN: <path> is an identical copy save this line)\n' "$f"
      bad=1; continue
    fi
    if [ "$partner" = "$f" ]; then printf 'twin %s (declares itself)\n' "$f"; bad=1; continue; fi
    if [ ! -f "$partner" ]; then
      printf 'twin %s %s\n' "$f" "$partner(missing)"; bad=1; continue
    fi
    a=$(grep -vF '# TWIN:' "$f")
    b=$(grep -vF '# TWIN:' "$partner")
    if [ "$a" != "$b" ]; then printf 'twin %s %s\n' "$f" "$partner"; bad=1; fi
  done < <(grep -rlF '# TWIN:' "$root" 2>/dev/null | sort)
  return $bad
}

# pc_handoff_refs <md_path> [plugins_root] — a bare `<plugin>:<name>` (a real plugin dir, not after `<`, fences included) naming no agent, skill or command there: prints "handoff <path> <token>".
# Resolution only: not whether the plugin is installed, nor a stale deferral to a host skill. Escape: `<!-- handoff-ok -->` on the line.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_handoff_refs
pc_handoff_refs() {
  local f="$1" root="${2:-plugins}" bad=0 tok lhs rhs ln skiplines
  [ -f "$f" ] || return 0
  skiplines=" $(grep -nF '<!-- handoff-ok -->' "$f" 2>/dev/null | cut -d: -f1 | tr '\n' ' ')"
  while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    tok="${ln#*:}"; ln="${ln%%:*}"
    case "$skiplines" in *" $ln "*) continue ;; esac
    lhs="${tok%%:*}"; rhs="${tok##*:}"
    [ -d "$root/$lhs" ] || continue
    [ -f "$root/$lhs/agents/$rhs.md" ] && continue
    [ -f "$root/$lhs/skills/$rhs/SKILL.md" ] && continue
    [ -f "$root/$lhs/commands/$rhs.md" ] && continue
    printf 'handoff %s %s\n' "$f" "$tok"
    bad=1
  # sort -u on the whole line: a (line, plugin) key would drop a second handoff sharing a prefix on one line.
  done < <(grep -nEo '(^|[^/`<[:alnum:]_-])[a-z][a-z0-9-]*:[a-z][a-z0-9-]*' "$f" 2>/dev/null \
    | sed -E 's/^([0-9]+):[^a-z]*/\1:/' | sort -u)
  return $bad
}

# pc_version_stamp <plugin_dir> — a plugin.json description claiming version leverage with no `> Last verified:` stamp in any skills/ .md: prints "unstamped <plugin>", returns 1.
# Presence only: whether the stamp is current is check-doc-staleness.sh's job; descriptions asserting no moving fact are not matched.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_version_stamp
pc_version_stamp() {
  local pdir="$1" pj="$1/.claude-plugin/plugin.json" desc name
  [ -f "$pj" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  name=$(jq -r '.name // empty' "$pj" 2>/dev/null)
  desc=$(jq -r '.description // empty' "$pj" 2>/dev/null)
  # Only phrases asserting a moving fact: `lockfile` stays out because lockfile discipline (semver) does not drift.
  printf '%s' "$desc" | grep -qiE 'version-aware|version leverage|version-leverage|as of [0-9]|version[- ]conditional|[0-9]+\.[0-9]+\+' || return 0
  # find, not a glob: an unmatched glob is a hard error under zsh, and a hook sources this file too.
  find "$pdir/skills" -type f -name '*.md' -exec grep -lq '^> Last verified:' {} + 2>/dev/null && return 0
  printf 'unstamped %s\n' "$name"
  return 1
}

# Lane checks read plugins/<name>/lane.tsv (format: CLAUDE.md § Lanes) and gate what a plugin DECLARES, never what its artifacts do (agent-graded).
# Why, limits, history: rationale/derivations/scripts-lib.md § Lane declarations

# _pc_lane_rows <lane_tsv> — "artifact<TAB>kind" per well-formed data row.
_pc_lane_rows() {
  [ -f "$1" ] || return 0
  awk -F'\t' '{ sub(/\r$/, "") } /^#/ { next } NF==6 { print $1 "\t" $2 }' "$1"
}

# _pc_mod_file <plugins_root> <plugin> <name> — prints hooks/<name>.<ts|tsx|mts|cts|js|mjs> when it is the hooks.json `modules` entry or imported by it as './<name>'.
# Misses an entry nested below hooks/, an import with an extension or another path, second-hop imports; a commented-out import counts. No jq: returns 1.
# Why, limits, history: rationale/derivations/scripts-lib.md § _pc_mod_file
_pc_mod_file() {
  local d="$1/$2/hooks" n="$3" e x
  [ -f "$d/hooks.json" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  while IFS= read -r e; do
    e=${e#./}
    case "$e" in ''|*/*) continue ;; esac
    [ -f "$d/$e" ] || continue
    for x in ts tsx mts cts js mjs; do
      [ -f "$d/$n.$x" ] || continue
      if [ "$e" = "$n.$x" ] \
         || grep -qF -e "from './$n'" -e "from \"./$n\"" "$d/$e" 2>/dev/null; then
        printf '%s\n' "$d/$n.$x"; return 0
      fi
    done
  done < <(jq -r '.modules | arrays | .[] | strings' "$d/hooks.json" 2>/dev/null)
  return 1
}

# _pc_lane_resolves <plugins_root> <plugin:name> <kind|any>
# True when the token names a real artifact of the declared kind. Private helper.
# A `mod` resolves through _pc_mod_file, so a feature file the entry never imports does not.
_pc_lane_resolves() {
  local root="$1" tok="$2" kind="${3:-any}" p n
  case "$tok" in *:*) ;; *) return 1 ;; esac
  p="${tok%%:*}"; n="${tok##*:}"
  [ -n "$p" ] && [ -n "$n" ] || return 1
  case "$kind" in
    agent)   [ -f "$root/$p/agents/$n.md" ] ;;
    command) [ -f "$root/$p/commands/$n.md" ] ;;
    skill)   [ -f "$root/$p/skills/$n/SKILL.md" ] ;;
    hook)    [ -f "$root/$p/hooks/$n.sh" ] ;;
    mod)     _pc_mod_file "$root" "$p" "$n" >/dev/null ;;
    *)       [ -f "$root/$p/agents/$n.md" ] || [ -f "$root/$p/commands/$n.md" ] \
             || [ -f "$root/$p/skills/$n/SKILL.md" ] || [ -f "$root/$p/hooks/$n.sh" ] \
             || _pc_mod_file "$root" "$p" "$n" >/dev/null ;;
  esac
}

# pc_lanes_schema <lane_tsv> — a row without 6 tab fields, an unknown kind or phase, an empty owns or definite_trigger, or a repeated artifact+owns: prints "lane-schema <file>:<line> <reason>".
# Shape only: whether the phase, owns or trigger is true is agent-graded.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_lanes_schema
pc_lanes_schema() {
  local f="$1"
  [ -f "$f" ] || return 0
  awk -F'\t' -v file="$f" '
    { sub(/\r$/, "") }
    /^#/ { next }
    /^[[:space:]]*$/ { next }
    {
      if (NF != 6) {
        printf "lane-schema %s:%d %d fields (want 6)\n", file, FNR, NF; bad=1; next
      }
      if ($2 !~ /^(command|hook|agent|skill|mod)$/) {
        printf "lane-schema %s:%d unknown kind %s\n", file, FNR, $2; bad=1
      }
      if ($3 !~ /^(understand|shape|decide|plan|build|verify|review|ship|any)$/) {
        printf "lane-schema %s:%d unknown phase %s\n", file, FNR, $3; bad=1
      }
      if ($4 ~ /^[[:space:]]*$/) {
        printf "lane-schema %s:%d empty owns\n", file, FNR; bad=1
      }
      if ($5 ~ /^[[:space:]]*$/) {
        printf "lane-schema %s:%d empty definite_trigger\n", file, FNR; bad=1
      }
      k = $1 SUBSEP $4
      if (k in seen) {
        printf "lane-schema %s:%d duplicate artifact+owns %s %s\n", file, FNR, $1, $4; bad=1
      }
      seen[k] = 1
    }
    END { exit bad+0 }' "$f"
}

# pc_lanes_authority <lane_tsv> — a row declaring an artifact outside its own plugin, or not plugin:name shaped: prints "lane-authority <file>:<line> <artifact> not owned by <plugin>".
# Blessing comments are not checked: a blessing names two parties and may sit in either file.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_lanes_authority
pc_lanes_authority() {
  local f="$1" plug
  [ -f "$f" ] || return 0
  plug=$(basename "$(dirname "$f")")
  awk -F'\t' -v file="$f" -v plug="$plug" '
    { sub(/\r$/, "") }
    /^#/ { next }
    /^[[:space:]]*$/ { next }
    NF != 6 { next }
    {
      lhs = $1; sub(/:.*$/, "", lhs)
      if ($1 !~ /^[a-z0-9-]+:[a-z0-9._-]+$/ || lhs != plug) {
        printf "lane-authority %s:%d %s not owned by %s\n", file, FNR, $1, plug; bad=1
      }
    }
    END { exit bad+0 }' "$f"
}

# pc_lanes_resolve <lane_tsv> [plugins_root] — an artifact missing as its declared kind, or a yields_to token naming nothing: prints "lane-resolve <file>:<line> …", returns 1.
# Existence only: whether a yields_to edge is honoured at runtime is agent-graded.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_lanes_resolve
pc_lanes_resolve() {
  local f="$1" root="${2:-plugins}" bad=0 lineno=0 art kind ph owns trig yields tok
  [ -f "$f" ] || return 0
  while IFS=$'\t' read -r art kind ph owns trig yields || [ -n "$art" ]; do
    lineno=$((lineno + 1))
    case "$art" in '#'*|'') continue ;; esac
    _pc_lane_resolves "$root" "$art" "$kind" \
      || { printf 'lane-resolve %s:%d %s names no %s in the tree\n' "$f" "$lineno" "$art" "$kind"; bad=1; }
    case "$yields" in ''|'-') continue ;; esac
    for tok in $(printf '%s' "$yields" | tr ',' ' '); do
      _pc_lane_resolves "$root" "$tok" any \
        || { printf 'lane-resolve %s:%d yields_to %s resolves to nothing\n' "$f" "$lineno" "$tok"; bad=1; }
    done
  done < "$f"
  return $bad
}

# pc_lanes_territory <lane_tsv>… — two rows in any files sharing owns + phase, with no yields_to edge and no `# lane-cofire-ok: <a> <b>` anywhere: prints "lane-territory <owns> <phase> <a> <b>".
# A string compare: two nouns for one job, or one noun in two phases, pass (pc_lanes_adjacency; agent-graded).
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_lanes_territory
pc_lanes_territory() {
  local f had=0
  for f in "$@"; do [ -f "$f" ] && had=1; done
  [ "$had" -eq 1 ] || return 0
  awk -F'\t' '
    function yields(list, target,   m, parts, k) {
      if (list == "" || list == "-") return 0
      m = split(list, parts, ",")
      for (k = 1; k <= m; k++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[k])
        if (parts[k] == target) return 1
      }
      return 0
    }
    { sub(/\r$/, "") }
    /^#[[:space:]]*lane-cofire-ok:/ {
      line = $0
      sub(/^#[[:space:]]*lane-cofire-ok:[[:space:]]*/, "", line)
      n = split(line, t, /[[:space:]]+/)
      if (n >= 2) { ok[t[1] SUBSEP t[2]] = 1; ok[t[2] SUBSEP t[1]] = 1 }
      next
    }
    /^#/ { next }
    NF != 6 { next }
    { i = ++cnt; A[i] = $1; PH[i] = $3; OW[i] = $4; Y[i] = $6 }
    END {
      bad = 0
      for (i = 1; i <= cnt; i++)
        for (j = i + 1; j <= cnt; j++) {
          if (OW[i] != OW[j] || PH[i] != PH[j]) continue
          if (A[i] == A[j]) continue
          if (yields(Y[i], A[j]) || yields(Y[j], A[i])) continue
          if (ok[A[i] SUBSEP A[j]]) continue
          printf "lane-territory %s %s %s %s\n", OW[i], PH[i], A[i], A[j]
          bad = 1
        }
      exit bad
    }' "$@"
}

# pc_lanes_adjacency [plugins_root] [rules_tsv] [min=3] — min+ lane artifacts on one file shape in one phase with unresolved pairs: prints "lane-adjacency <shape> <phase> <artifact>…".
# Shapes come from rules.tsv globs and agents' bestpractices-skill; misses commands, content rows, rowless artifacts, agents naming no skill, and whether a crowd is wrong.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_lanes_adjacency
pc_lanes_adjacency() {
  local root="${1:-plugins}" rules="${2:-}" min="${3:-3}" out lanes agents f
  [ -n "$rules" ] || rules="$root/skill-router/rules.tsv"
  [ -f "$rules" ] || return 0
  # find, not a glob: an unmatched glob is a hard error under zsh, and a hook sources this file too.
  lanes=$(find "$root" -maxdepth 2 -name lane.tsv 2>/dev/null | sort)
  [ -n "$lanes" ] || return 0
  agents=$(find "$root" -maxdepth 3 -type f -path '*/agents/*.md' 2>/dev/null | sort)
  # Positional args, not word splitting: zsh does not split unquoted parameters.
  set -- "$rules"
  while IFS= read -r f; do
    [ -n "$f" ] && set -- "$@" "$f"
  done <<EOF_LANE_ADJ_FILES
$lanes
$agents
EOF_LANE_ADJ_FILES
  out=$(awk -F'\t' -v min="$min" -v rules="$rules" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    function yields(list, target,   m, parts, k) {
      if (list == "" || list == "-") return 0
      m = split(list, parts, ",")
      for (k = 1; k <= m; k++) if (trim(parts[k]) == target) return 1
      return 0
    }
    function declares(list, art,   m, parts, k, sn) {
      sn = art; sub(/^[^:]*:/, "", sn)
      m = split(list, parts, ",")
      for (k = 1; k <= m; k++) if (trim(parts[k]) == sn) return 1
      return 0
    }
    function resolved(ck, a, b,   ia, ib) {
      ia = IDX[ck SUBSEP a]; ib = IDX[ck SUBSEP b]
      if (yields(Y[ia], b) || yields(Y[ib], a)) return 1
      if ((a SUBSEP b) in OK) return 1
      if (K[ia] == "agent" && K[ib] == "skill" && declares(BP[a], b)) return 1
      if (K[ib] == "agent" && K[ia] == "skill" && declares(BP[b], a)) return 1
      return 0
    }
    FILENAME == rules {
      sub(/\r$/, "")
      if ($0 ~ /^#/ || NF < 4 || $1 != "glob") next
      art = $4 ":" $3
      if (!((art SUBSEP $2) in aseen)) { aseen[art SUBSEP $2] = 1; ASH[art] = ASH[art] " " $2 }
      if (!(($3 SUBSEP $2) in sseen)) { sseen[$3 SUBSEP $2] = 1; SSH[$3] = SSH[$3] " " $2 }
      next
    }
    FILENAME ~ /lane\.tsv$/ {
      sub(/\r$/, "")
      if ($0 ~ /^#[[:space:]]*lane-cofire-ok:/) {
        line = $0
        sub(/^#[[:space:]]*lane-cofire-ok:[[:space:]]*/, "", line)
        n = split(line, t, /[[:space:]]+/)
        if (n >= 2) { OK[t[1] SUBSEP t[2]] = 1; OK[t[2] SUBSEP t[1]] = 1 }
        next
      }
      if ($0 ~ /^#/ || NF != 6) next
      i = ++rows; A[i] = $1; K[i] = $2; P[i] = $3; Y[i] = $6
      next
    }
    {
      # an agent markdown file: read bestpractices-skill from the FRONTMATTER only
      if (FNR == 1) { fm = ($0 ~ /^---[[:space:]]*$/); next }
      if (!fm) next
      if ($0 ~ /^---[[:space:]]*$/) { fm = 0; next }
      if ($0 !~ /^bestpractices-skill:/) next
      line = $0; sub(/^bestpractices-skill:[[:space:]]*/, "", line)
      n = split(FILENAME, seg, "/")
      key = seg[n-2] ":" seg[n]; sub(/\.md$/, "", key)
      BP[key] = line
    }
    END {
      for (i = 1; i <= rows; i++) {
        shapes = ""
        if (K[i] == "skill") shapes = ASH[A[i]]
        else if (K[i] == "agent") {
          m = split(BP[A[i]], bs, ",")
          for (j = 1; j <= m; j++) { s = trim(bs[j]); if (s != "") shapes = shapes " " SSH[s] }
        }
        if (trim(shapes) == "") continue
        n = split(shapes, sh, /[[:space:]]+/)
        for (j = 1; j <= n; j++) {
          if (sh[j] == "") continue
          ck = P[i] SUBSEP sh[j]
          if ((ck SUBSEP A[i]) in mseen) continue
          mseen[ck SUBSEP A[i]] = 1
          MEM[ck] = MEM[ck] " " A[i]
          IDX[ck SUBSEP A[i]] = i
          SHAPE[ck] = sh[j]; PH[ck] = P[i]
        }
      }
      for (ck in MEM) {
        c = 0; delete M
        n = split(MEM[ck], mm, /[[:space:]]+/)
        for (x = 1; x <= n; x++) if (mm[x] != "") M[++c] = mm[x]
        if (c < min) continue
        delete keep
        for (x = 1; x <= c; x++)
          for (y = x + 1; y <= c; y++) {
            if (resolved(ck, M[x], M[y])) continue
            keep[M[x]] = 1; keep[M[y]] = 1
          }
        nk = 0; delete L
        for (k in keep) L[++nk] = k
        if (nk < min) continue
        for (x = 2; x <= nk; x++) {
          v = L[x]; y = x - 1
          while (y >= 1 && L[y] > v) { L[y+1] = L[y]; y-- }
          L[y+1] = v
        }
        line = "lane-adjacency " SHAPE[ck] " " PH[ck]
        for (x = 1; x <= nk; x++) line = line " " L[x]
        print line
      }
    }' "$@" | sort)
  [ -n "$out" ] || return 0
  printf '%s\n' "$out"
  return 1
}

# pc_lanes_coverage [plugins_root] — an agent, a UserPromptSubmit/Stop hook, a deny-capable Pre/PostToolUse hook or a hook-registering mod file with no own lane row: "lane-missing …".
# Commands and skills draw only "lane-warn …". Misses hooks invoked another way and rows naming the wrong phase or territory; a mod `on(` in a comment over-reports.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_lanes_coverage
pc_lanes_coverage() {
  local root="${1:-plugins}" bad=0 d p lane rows a n hj cmd TAB NL
  TAB=$(printf '\t'); NL='
'
  # find, not a glob: an unmatched glob is a hard error under zsh, and a hook sources this file too.
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    p=$(basename "$d")
    lane="$d/lane.tsv"
    rows=$(_pc_lane_rows "$lane")
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      n=$(basename "$a" .md)
      case "$NL$rows$NL" in
        *"$NL$p:$n${TAB}agent$NL"*) ;;
        *) printf 'lane-missing agent %s:%s\n' "$p" "$n"; bad=1 ;;
      esac
    done < <(find "$d/agents" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
    hj="$d/hooks/hooks.json"
    if [ -f "$hj" ] && command -v jq >/dev/null 2>&1; then
      while IFS= read -r cmd; do
        cmd=$(_pc_hook_script "$cmd" "$d")
        case "$cmd" in "$d/hooks/"*.sh) ;; *) continue ;; esac
        n=$(basename "$cmd" .sh)
        case "$NL$rows$NL" in
          *"$NL$p:$n${TAB}hook$NL"*) ;;
          *) printf 'lane-missing hook %s:%s\n' "$p" "$n"; bad=1 ;;
        esac
      done < <(jq -r '.hooks // {} | to_entries[]
                      | select(.key=="UserPromptSubmit" or .key=="Stop")
                      | (.value[].hooks[].command // empty) | gsub("\""; "")' "$hj" 2>/dev/null | sort -u)
      # Deny-capable Pre/PostToolUse hooks too: permissionDecision or a bare exit 2 in the text (grep, not parse: over-reports, the cheap way).
      while IFS= read -r cmd; do
        cmd=$(_pc_hook_script "$cmd" "$d")
        case "$cmd" in "$d/hooks/"*.sh) ;; *) continue ;; esac
        n=$(basename "$cmd" .sh)
        [ -f "$d/hooks/$n.sh" ] || continue
        grep -qE 'permissionDecision|^[[:space:]]*exit 2([[:space:]]|$)' "$d/hooks/$n.sh" 2>/dev/null || continue
        case "$NL$rows$NL" in
          *"$NL$p:$n${TAB}hook$NL"*) ;;
          *) printf 'lane-missing hook %s:%s (returns a permissionDecision)\n' "$p" "$n"; bad=1 ;;
        esac
      done < <(jq -r '.hooks // {} | to_entries[]
                      | select(.key=="PreToolUse" or .key=="PostToolUse")
                      | (.value[].hooks[].command // empty) | gsub("\""; "")' "$hj" 2>/dev/null | sort -u)
      while IFS= read -r n; do
        [ -n "$n" ] && [ "$n" != cc-kit ] || continue
        a=$(_pc_mod_file "$root" "$p" "$n") || continue
        grep -qE '(^|[^[:alnum:]_$.])on\(|registerSuggestion\(' "$a" 2>/dev/null || continue
        case "$NL$rows$NL" in
          *"$NL$p:$n${TAB}mod$NL"*) ;;
          *) printf 'lane-missing lane-uncovered-mod %s:%s\n' "$p" "$n"; bad=1 ;;
        esac
      done < <(find "$d/hooks" -maxdepth 1 -type f \( -name '*.ts' -o -name '*.tsx' \
                 -o -name '*.mts' -o -name '*.cts' -o -name '*.js' -o -name '*.mjs' \) 2>/dev/null \
               | sed 's#.*/##; s/\.[^.]*$//' | sort -u)
    fi
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      n=$(basename "$a" .md)
      case "$NL$rows$NL" in
        *"$NL$p:$n${TAB}command$NL"*) ;;
        *) printf 'lane-warn command %s:%s\n' "$p" "$n" ;;
      esac
    done < <(find "$d/commands" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      n=$(basename "$(dirname "$a")")
      case "$NL$rows$NL" in
        *"$NL$p:$n${TAB}skill$NL"*) ;;
        *) printf 'lane-warn skill %s:%s\n' "$p" "$n" ;;
      esac
    done < <(find "$d/skills" -maxdepth 2 -type f -name 'SKILL.md' 2>/dev/null | sort)
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  return $bad
}

# pc_dispatch_binding <md_path> [plugins_root] — an `agent(<args>)` sample naming a shipped agent (own plugin bare, else plugin:agent) with no `agentType`: prints "dispatch <path> <agent>".
# Code samples only: not runtime orchestration or Workflow scripts composed on the fly (agent-graded). Escape: `<!-- dispatch-ok -->` for the generic subagent.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_dispatch_binding
pc_dispatch_binding() {
  local f="$1" root="${2:-plugins}" bad=0 plug a n tok lhs rhs
  [ -f "$f" ] || return 0
  grep -qE 'agent\([^)]' "$f" || return 0          # guard 1: a call, not a mention
  grep -qF '<!-- dispatch-ok -->' "$f" && return 0
  grep -qF 'agentType' "$f" && return 0

  plug=${f#"$root"/}; plug=${plug%%/*}
  if [ -d "$root/$plug/agents" ]; then
    for a in "$root/$plug/agents"/*.md; do
      [ -f "$a" ] || continue
      n=$(basename "$a" .md)
      grep -qE "\`$n\`|\`$plug:$n\`|\[$plug:$n\]" "$f" || continue
      printf 'dispatch %s %s\n' "$f" "$plug:$n"; bad=1
    done
  fi
  for tok in $(grep -oE '`[a-z0-9-]+:[a-z0-9-]+`|\[[a-z0-9-]+:[a-z0-9-]+\]' "$f" 2>/dev/null \
                 | tr -d '`[]' | sort -u); do
    lhs=${tok%%:*}; rhs=${tok#*:}
    [ "$lhs" = "$plug" ] && continue              # already covered by the own-plugin pass
    [ -f "$root/$lhs/agents/$rhs.md" ] || continue
    printf 'dispatch %s %s\n' "$f" "$tok"; bad=1
  done
  return $bad
}

# pc_deference_edges [plugins_root] — a plugin.json "defer… to …" clause naming another plugin dir with no yields_to <that>:… in its own lane.tsv: prints "deference <plugin> -> <target>".
# Skips host or class targets; misses other verbs and names inside hyphenated words; plugins named like words over-report loudly; phase is not checked. Needs jq.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_deference_edges
pc_deference_edges() {
  local root="${1:-plugins}" bad=0 pj p desc clause tok lane
  command -v jq >/dev/null 2>&1 || return 0
  for pj in "$root"/*/.claude-plugin/plugin.json; do
    [ -f "$pj" ] || continue
    p=$(basename "$(dirname "$(dirname "$pj")")")
    desc=$(jq -r '.description // ""' "$pj" 2>/dev/null) || continue
    lane="$root/$p/lane.tsv"
    while IFS= read -r clause; do
      [ -n "$clause" ] || continue
      while IFS= read -r tok; do
        [ -n "$tok" ] || continue
        [ "$tok" = "$p" ] && continue
        [ -d "$root/$tok" ] || continue
        if ! awk -F'\t' -v t="$tok:" '
              /^#/ { next } NF==6 { n=split($6, a, ","); for (i=1;i<=n;i++) { gsub(/^[ \t]+/, "", a[i]); if (index(a[i], t)==1) { f=1 } } }
              END { exit f ? 0 : 1 }' "$lane" 2>/dev/null; then
          printf 'deference %s -> %s\n' "$p" "$tok"; bad=1
        fi
      done <<EOF_TOK
$(printf '%s' "$clause" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9-\n' '\n' | sort -u)
EOF_TOK
    done <<EOF_CLAUSE
$(printf '%s' "$desc" | grep -oiE 'defer(s|red|ring|ral)?\b[^.;]*\bto\b[^.;]*' || true)
EOF_CLAUSE
  done
  return $bad
}

# pc_phase_guard <plugins_root> — a Prompt/Stop/Pre/PostToolUse hook or mod file whose lane names a phase other than `any` and never reads .claude/cc-phase.json: "phase-unguarded|phase-guard-mod …".
# Proves the read, not that every branch honours the verdict (agent-graded); rowless artifacts are pc_lanes_coverage's, unresolved mod rows pc_lanes_resolve's.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_phase_guard
pc_phase_guard() {
  local root="${1:-plugins}" bad=0 hj d p sh rel lane_phase art mf
  command -v jq >/dev/null 2>&1 || return 0
  while IFS= read -r hj; do
    [ -n "$hj" ] || continue
    d=$(dirname "$(dirname "$hj")"); p=$(basename "$d")
    while IFS= read -r sh; do
      [ -n "$sh" ] || continue
      sh=$(_pc_hook_script "$sh" "$d")
      [ -f "$sh" ] || continue
      rel=$(basename "$sh")
      grep -qF 'cc-phase.json' "$sh" 2>/dev/null && continue
      # A lane phase of `any` declares a guard that must fire in every phase; a hook with no row is pc_lanes_coverage's.
      lane_phase=$(awk -F'\t' -v a="$p:${rel%.sh}" '$1==a {print $3; exit}' \
                    "$d/lane.tsv" 2>/dev/null)
      [ -z "$lane_phase" ] && continue
      [ "$lane_phase" = any ] && continue
      printf 'phase-unguarded %s:%s\n' "$p" "$rel"
      bad=1
    done <<EOF
$(jq -r '((.hooks.UserPromptSubmit // []) + (.hooks.Stop // [])
          + (.hooks.PreToolUse // []) + (.hooks.PostToolUse // []))
         | .[]? | .hooks[]? | select(.type=="command") | .command | gsub("\""; "")' "$hj" 2>/dev/null | sort -u)
EOF
  done <<EOF
$(find "$root" -mindepth 3 -maxdepth 3 -name hooks.json -print 2>/dev/null | sort)
EOF
  while IFS= read -r art; do
    [ -n "$art" ] || continue
    mf=$(_pc_mod_file "$root" "${art%%:*}" "${art##*:}") || continue
    case "${mf##*/}" in
      cc-kit.*) ;;
      *) grep -qF -e 'liveSentinel(' -e 'registerSuggestion(' -e 'cc-phase.json' "$mf" 2>/dev/null \
           && continue ;;
    esac
    printf 'phase-guard-mod %s\n' "$art"
    bad=1
  done <<EOF
$(find "$root" -mindepth 2 -maxdepth 2 -name lane.tsv -exec awk -F'\t' '
    { sub(/\r$/, "") } /^#/ { next } NF==6 && $2=="mod" && $3!="any" { print $1 }' {} + 2>/dev/null | sort -u)
EOF
  return $bad
}

# pc_context_key <plugins_root> — a PostToolUse hook reading session_id and never transcript_path: prints "context-keyed-on-session <plugin>:<script>", returns 1.
# String presence only (pc_marker_key checks the value is hashed). Escape: `# context-key-ok: <why>` for a hook recording session_id as data.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_context_key
pc_context_key() {
  local root="${1:-plugins}" bad=0 hj d p sh rel
  command -v jq >/dev/null 2>&1 || return 0
  while IFS= read -r hj; do
    [ -n "$hj" ] || continue
    d=$(dirname "$(dirname "$hj")"); p=$(basename "$d")
    while IFS= read -r sh; do
      [ -n "$sh" ] || continue
      sh=$(_pc_hook_script "$sh" "$d")
      [ -f "$sh" ] || continue
      rel=$(basename "$sh")
      grep -q 'session_id' "$sh" 2>/dev/null || continue
      grep -q 'transcript_path' "$sh" 2>/dev/null && continue
      grep -q 'context-key-ok:' "$sh" 2>/dev/null && continue
      printf 'context-keyed-on-session %s:%s\n' "$p" "$rel"
      bad=1
    done <<EOF
$(jq -r '(.hooks.PostToolUse // []) | .[]? | .hooks[]? | select(.type=="command") | .command | gsub("\""; "")' "$hj" 2>/dev/null | sort -u)
EOF
  done <<EOF
$(find "$root" -mindepth 3 -maxdepth 3 -name hooks.json -print 2>/dev/null | sort)
EOF
  return $bad
}

# pc_marker_key [plugins_root] — any registered hook building a path from an unhashed transcript_path key, tainted through assignments: prints "marker-key-unhashed <plugin>:<script>:<line>".
# Passes cksum/shasum/md5, a slash strip, or mkdir -p "$(dirname …)" within 3 lines; misses printf into variables, arrays, eval. Escape: `# marker-key-ok: <why>`.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_marker_key
pc_marker_key() {
  local root="${1:-plugins}" bad=0 hj d p sh rel v line no body seeds tainted round newly

  # Taint, not one syntax: seed from the jq read, propagate through assignments; a hash or a slash strip clears it.
  _mk_tainted() { # $1 file -> tainted var names
    local f=$1 seeds tainted round newly v
    seeds=$(grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[^=]*jq[^;]*transcript_path' "$f" 2>/dev/null \
             | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/' | sort -u)
    tainted="$seeds"
    for round in 1 2; do
      newly=""
      for v in $tainted; do
        # Assigned from a tainted var inherits the taint, unless that line hashes it or strips its slashes.
        newly="$newly $(grep -E "^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=.*\\\$\{?$v\}?" "$f" 2>/dev/null \
          | grep -vE 'cksum|shasum|md5|sha1sum' \
          | grep -vE "\\\$\{$v//" \
          | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/')"
      done
      tainted=$(printf '%s %s' "$tainted" "$newly" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')
    done
    printf '%s' "$tainted"
  }

  command -v jq >/dev/null 2>&1 || return 0
  while IFS= read -r hj; do
    [ -n "$hj" ] || continue
    d=$(dirname "$(dirname "$hj")"); p=$(basename "$d")
    while IFS= read -r sh; do
      [ -n "$sh" ] || continue
      sh=$(_pc_hook_script "$sh" "$d")
      [ -f "$sh" ] || continue
      rel=$(basename "$sh")
      grep -q 'marker-key-ok:' "$sh" 2>/dev/null && continue

      for v in $(_mk_tainted "$sh"); do
        [ -n "$v" ] || continue
        # Path-shaped: the right-hand side must contain a slash.
        while IFS=: read -r no body; do
          [ -n "$no" ] || continue
          printf '%s' "$body" | grep -qE '(cksum|shasum|md5|sha1sum)' && continue
          printf '%s' "$body" | grep -qE "\\\$\{$v//" && continue
          sed -n "$((no + 1)),$((no + 3))p" "$sh" 2>/dev/null \
            | grep -qE 'mkdir[[:space:]]+-p[[:space:]]+"\$\(dirname' && continue
          printf 'marker-key-unhashed %s:%s:%s\n' "$p" "$rel" "$no"
          bad=1
        done <<EOF
$(grep -nE "^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[\"']?[^\"']*/[^\"']*\\\$\{?$v\}?|^[[:space:]]*printf[[:space:]]+-v[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[^|]*/[^|]*\\\$\{?$v\}?" "$sh" 2>/dev/null)
EOF
      done
    done <<EOF
$(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]? | select(.type=="command") | .command | gsub("\""; "")' "$hj" 2>/dev/null | sort -u)
EOF
  done <<EOF
$(find "$root" -mindepth 3 -maxdepth 3 -name hooks.json -print 2>/dev/null | sort)
EOF
  unset -f _mk_tainted
  return $bad
}

# pc_source_of_truth [plugins_root] — a SKILL.md naming references/<f>.md as SOURCE OF TRUTH and carrying a figure (KB|MB|ms|fps, unit adjacent) that file lacks: prints "source-of-truth …".
# Misses prose that contradicts without a number, px, spaced units, bare integers; a figure spaced only on the reference side false-fails.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_source_of_truth
pc_source_of_truth() {
  local root="${1:-plugins}" bad=0 f dir ref refpath body figs missing

  while IFS= read -r f; do
    [ -f "$f" ] || continue
    grep -q 'SOURCE OF TRUTH' "$f" 2>/dev/null || continue
    dir=$(dirname "$f")
    # the reference named on (or just before) the SOURCE OF TRUTH line
    ref=$(grep -B1 -A0 'SOURCE OF TRUTH' "$f" 2>/dev/null           | grep -oE 'references/[A-Za-z0-9._-]+\.md' | head -1)
    [ -n "$ref" ] || continue
    refpath="$dir/$ref"
    [ -f "$refpath" ] || { printf 'source-of-truth %s names %s which does not exist\n' "$f" "$ref"; bad=1; continue; }

    body=$(awk '/^---$/{c++; next} c>=2' "$f" 2>/dev/null)
    # LC_ALL=C on sort AND comm: UTF-8 collations can disagree on "2.6KB" and report a false FAIL.
    figs=$(printf '%s' "$body" | grep -oE '[0-9]+(\.[0-9]+)?(KB|MB|ms|fps)' | LC_ALL=C sort -u)
    [ -n "$figs" ] || continue
    missing=$(LC_ALL=C comm -23 <(printf '%s\n' "$figs") \
                       <(grep -oE '[0-9]+(\.[0-9]+)?(KB|MB|ms|fps)' "$refpath" 2>/dev/null | LC_ALL=C sort -u))
    if [ -n "$missing" ]; then
      printf 'source-of-truth %s carries figures absent from its declared source %s: %s\n' \
        "$f" "$ref" "$(printf '%s' "$missing" | tr '\n' ' ')"
      bad=1
    fi
  done < <(find "$root" -path '*/skills/*/SKILL.md' -type f 2>/dev/null | sort)

  return "$bad"
}

# pc_false_standing [plugins_root] — a SKILL.md engaging pc_source_of_truth (marker + existing reference) that denies being gated in that paragraph: prints "false-standing …", returns 1.
# DENIALS is a fixed phrase list; a list or table is one paragraph, so a neighbour's row trips it (escape `<!-- false-standing-ok: <why> -->`). No other check is paired.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_false_standing
pc_false_standing() {
  local root="${1:-plugins}" bad=0 f dir body ref refpath hit
  local DENIALS='no gate (checks|reads|enforces)|nothing (checks|enforces|gates) (it|this|that|the two|them)|the mirror is manual and no gate|not (gated|enforced|checked) by (any|a) (script|gate)'

  while IFS= read -r f; do
    [ -f "$f" ] || continue
    # pc_source_of_truth's own preconditions, in its order; case-sensitive like its plain grep -q.
    grep -q 'SOURCE OF TRUTH' "$f" 2>/dev/null || continue
    dir=$(dirname "$f")
    ref=$(grep -B1 -A0 'SOURCE OF TRUTH' "$f" 2>/dev/null \
          | grep -oE 'references/[A-Za-z0-9._-]+\.md' | head -1)
    [ -n "$ref" ] || continue
    refpath="$dir/$ref"
    [ -f "$refpath" ] || continue

    body=$(awk '/^---$/{c++; next} c>=2' "$f" 2>/dev/null)
    # tolower(), not gawk-only IGNORECASE; each paragraph is judged alone, so a blessed one cannot hide a later denial.
    hit=$(printf '%s' "$body" | awk -v deny="$DENIALS" '
      BEGIN { RS = "" }
      /SOURCE OF TRUTH/ && tolower($0) ~ tolower(deny) &&
        index($0, "<!-- false-standing-ok:") == 0 { print; exit }
    ')
    [ -n "$hit" ] || continue

    printf 'false-standing %s engages pc_source_of_truth (marker + %s) and denies being gated in the same paragraph\n' "$f" "$ref"
    bad=1
  done < <(find "$root" -path '*/skills/*/SKILL.md' -type f 2>/dev/null | sort)

  return "$bad"
}

# pc_harness_payload [repo_root] — a smoke or plugin harness that builds a payload for a hook reading transcript_path and never sends it: prints "harness-payload-fallback-only <harness>:<hook>".
# String presence only, not a meaningful case; misses hooks reached through paths it cannot resolve. Escape: `# harness-payload-ok: <why>`.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_harness_payload
pc_harness_payload() {
  local root="${1:-.}" bad=0 f plug h hooks b

  _hp_hooks() { # $1 harness -> hook paths it exercises
    local f=$1 plug="" out="" b
    case "$f" in */plugins/*|plugins/*) plug=$(printf '%s' "${f#$root/}" | sed -n 's|^plugins/\([a-z0-9-]*\)/.*|\1|p') ;;
    esac
    out=$(grep -ohE 'plugins/[a-z0-9-]+/hooks/[a-z0-9_-]+\.sh' "$f" 2>/dev/null | sed "s|^|$root/|" | sort -u)
    # hooks/x.sh anywhere, also after a slash, so a hook reached through "$1/hooks/x.sh" is seen.
    for b in $(grep -ohE 'hooks/[a-z0-9_-]+\.sh' "$f" 2>/dev/null | sort -u); do
      if [ -n "$plug" ] && [ -f "$root/plugins/$plug/$b" ]; then out="$out
$root/plugins/$plug/$b"
      else
        # A bare hooks/x.sh resolves across plugins only when one plugin owns that name (remind.sh is in five).
        _cand=$(ls "$root"/plugins/*/"$b" 2>/dev/null)
        [ "$(printf '%s\n' "$_cand" | grep -c .)" -eq 1 ] && out="$out
$_cand"
      fi
    done
    printf '%s\n' "$out" | sort -u | grep -v '^$'
  }

  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    case "$f" in *canary.sh) continue ;; esac
    grep -q 'harness-payload-ok:' "$f" 2>/dev/null && continue
    grep -qE 'hook_event_name|"session_id"|session_id"?[:=]' "$f" 2>/dev/null || continue
    # A comment naming transcript_path exercises nothing: comment lines are stripped first.
    grep -vE '^[[:space:]]*#' "$f" 2>/dev/null | grep -q 'transcript_path' && continue
    while IFS= read -r h; do
      [ -n "$h" ] && [ -f "$h" ] || continue
      grep -q 'transcript_path' "$h" 2>/dev/null || continue
      printf 'harness-payload-fallback-only %s:%s\n' "${f#$root/}" "$(basename "$h")"
      bad=1
    done <<EOF
$(_hp_hooks "$f")
EOF
  done <<EOF
$(ls "$root"/scripts/smoke/*.sh "$root"/plugins/*/scripts/__tests__/*.test.sh 2>/dev/null)
EOF
  unset -f _hp_hooks
  return $bad
}

# pc_prime_coverage [plugins_root] — prime.sh priming a skill skill-map.md does not map (prime-unmapped <skill>), or a non-ASK map row it never primes (map-unprimed <skill>).
# Misses whether prime.sh's matcher agrees with the map's Signal column; only a reader or generation catches that. Escape: `# prime-ok: <skill>` in prime.sh.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_prime_coverage
pc_prime_coverage() {
  local root="${1:-plugins}" bad=0 sk primed
  local prime="$root/skill-router/hooks/prime.sh"
  local map="$root/code-architecture/skills/coding-entry/references/skill-map.md"
  [ -f "$prime" ] || return 0
  [ -f "$map" ] || return 0
  primed=$(grep -oE '(^|[;&[:space:]])add [a-z0-9-]+' "$prime" 2>/dev/null | awk '{print $NF}' | sort -u)
  while IFS= read -r sk; do
    [ -n "$sk" ] || continue
    grep -qF ":$sk\`" "$map" 2>/dev/null && continue
    grep -qF "prime-ok: $sk" "$prime" 2>/dev/null && continue
    printf 'prime-unmapped %s\n' "$sk"
    bad=1
  done <<EOF
$primed
EOF
  while IFS= read -r sk; do
    [ -n "$sk" ] || continue
    printf '%s\n' "$primed" | grep -qxF "$sk" && continue
    grep -qF "prime-ok: $sk" "$prime" 2>/dev/null && continue
    printf 'map-unprimed %s\n' "$sk"
    bad=1
  done <<EOF
$(grep -E '^\|' "$map" 2>/dev/null | grep -v 'the ASK' \
  | sed -nE 's/.*\`[a-z0-9-]+:([a-z0-9-]+)\`.*/\1/p' | sort -u)
EOF
  return $bad
}

# pc_plugin_dependencies [plugins_root] — a plugin.json with a `dependencies` key, any value: prints "plugin-dependencies <name> <deps…>", returns 1.
# Misses wrong or missing companion notices, silent runtime degradation, the key on a marketplace.json entry; re-measure the host before relaxing it.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_plugin_dependencies
pc_plugin_dependencies() {
  local root="${1:-plugins}" bad=0 pj name deps
  for pj in "$root"/*/.claude-plugin/plugin.json; do
    [ -f "$pj" ] || continue
    jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1 || continue
    name=$(jq -r '.name // empty' "$pj" 2>/dev/null)
    [ -n "$name" ] || name=$(basename "$(dirname "$(dirname "$pj")")")
    deps=$(jq -r '[.dependencies | if type == "array" then .[] | tostring elif type == "object" then keys[] else tostring end] | join(" ")' "$pj" 2>/dev/null)
    printf 'plugin-dependencies %s %s\n' "$name" "${deps:-(empty)}"
    bad=1
  done
  return $bad
}

# pc_scout_names [repo_root] — a name in a Plugin/Suggest cell of plugin-scout's SKILL.md, signals.md, any-core.md or stack-relevance.md that is not live in marketplace.json.
# Prints "scout-name …", or "scout-name-unparsed …" for a bare non-name cell. Misses wrong signals, wrong live names, prose. Escape: `<!-- scout-name-ok: <why> -->`.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_scout_names
pc_scout_names() {
  local root="${1:-.}" bad=0 mp live skill f ln kind val
  mp="$root/.claude-plugin/marketplace.json"
  [ -f "$mp" ] || return 0
  live=$(jq -r '.plugins[].name' "$mp" 2>/dev/null) || return 0
  [ -n "$live" ] || return 0
  skill="$root/plugins/stack-scan/skills/plugin-scout"
  for f in "$skill/SKILL.md" "$skill/references/signals.md" "$skill/references/any-core.md" "$skill/references/stack-relevance.md"; do
    [ -f "$f" ] || continue
    while IFS=$'\t' read -r ln kind val; do
      [ -n "$ln" ] || continue
      if [ "$kind" = name ]; then
        printf '%s\n' "$live" | grep -qxF "$val" && continue
        printf 'scout-name %s:%s %s\n' "${f#$root/}" "$ln" "$val"
      else
        printf 'scout-name-unparsed %s:%s %s\n' "${f#$root/}" "$ln" "$val"
      fi
      bad=1
    done <<EOF
$(awk -F'|' '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function emit(tok, cellv) {
  if (tok ~ /^[a-z0-9][a-z0-9-]*$/) print NR "\tname\t" tok
  else print NR "\tunparsed\t" cellv
}
{
  # Leaving the table resets the column: each table resolves its own header.
  if ($0 !~ /^[ \t]*\|/) { col = 0; next }
  if ($0 ~ /scout-name-ok:/) next
  # A row normally ends with `|`, making the last field empty; tolerate one that
  # does not rather than dropping its final cell.
  last = (trim($NF) == "") ? NF - 1 : NF
  if (col == 0) {
    for (i = 2; i <= last; i++) {
      c = tolower(trim($i))
      if (c == "plugin" || c == "suggest") { col = i; break }
    }
    next
  }
  isdelim = 1
  for (i = 2; i <= last; i++) if (trim($i) !~ /^:?-+:?$/) { isdelim = 0; break }
  if (isdelim) next
  if (col > last) next
  cell = trim($col)
  # No alphanumerics at all is the "no plugin covers this" idiom, in whichever
  # dash the author reached for. Byte-matching em/en dashes would miss the next one.
  if (cell !~ /[A-Za-z0-9]/) next
  if (index(cell, "`") > 0) {
    s = cell
    while (match(s, /`[^`]*`/)) {
      tok = trim(substr(s, RSTART + 1, RLENGTH - 2))
      s = substr(s, RSTART + RLENGTH)
      if (tok != "") emit(tok, cell)
    }
  } else emit(cell, cell)
}
' "$f")
EOF
  done
  return $bad
}

# pc_renames_ledger [repo_root] — removed-plugins.tsv and marketplace.json `renames` disagree, a renamed key still listed, or a chain dangles or cycles: renames-<kind> lines, returns 1.
# Misses a wrong successor, retargeted or deleted history, duplicates that agree; the string "null" is refused as unreadable (the host reads it as a name).
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_renames_ledger
pc_renames_ledger() {
  local root="${1:-.}" mp tsv bad=0 rc
  mp="$root/.claude-plugin/marketplace.json"
  tsv="$root/scripts/removed-plugins.tsv"
  [ -f "$tsv" ] && [ -r "$tsv" ] || { printf 'renames-ledger-unreadable %s\n' "${tsv#$root/}"; bad=1; }
  jq -e 'type == "object" and (.plugins | type == "array") and all(.plugins[]; type == "object")
    and (.renames | type == "object") and all(.renames[]; . == null or (type == "string" and . != "null"))' "$mp" >/dev/null 2>&1 \
    || { printf 'renames-ledger-unreadable %s\n' "${mp#$root/}"; bad=1; }
  [ "$bad" -eq 0 ] || return 1
  awk -F'\t' -v src="${tsv#$root/}" '
    FILENAME == ARGV[1] {
      if ($1 == "L") live[$2] = 1
      else { ren[$2] = $3; key[++n] = $2 }
      next
    }
    /^#/ { next }
    { sub(/\r$/, "") }
    /^[ \t]*$/ { next }
    NF < 5 || $1 !~ /^[a-z0-9][a-z0-9-]*$/ || $4 !~ /^(plug|moved|both|no)$/ {
      print "renames-ledger-unreadable " src ":" FNR; bad = 1; next
    }
    { row[$1] = 1 }
    !($1 in ren) { print "renames-missing " $1; bad = 1; next }
    ren[$1] != $2 { print "renames-mismatch " $1 " " $2 " " ren[$1]; bad = 1 }
    END {
      for (i = 1; i <= n; i++) {
        k = key[i]
        if (k in live) { print "renames-live-key " k; bad = 1 }
        if (!(k in row)) { print "renames-orphan " k; bad = 1 }
        split("", seen); seen[k] = 1; t = ren[k]; hops = 0
        while (t != "null" && !(t in live)) {
          if ((t in seen) || ++hops > n) { print "renames-cycle " k; bad = 1; break }
          if (!(t in ren)) { print "renames-dangling " k " " t; bad = 1; break }
          seen[t] = 1; t = ren[t]
        }
      }
      exit bad
    }' <(jq -r '(.plugins[].name | strings | "L\t\(.)"), (.renames | to_entries[] | "R\t\(.key)\t\(.value)")' "$mp") "$tsv"
  rc=$?
  [ "$rc" -le 1 ] && return "$rc"
  printf 'renames-ledger-unreadable %s\n' "${tsv#$root/}"
  return 1
}

# pc_listing_fields <md_path> — "description<TAB>when_to_use<TAB>true|false" (disable-model-invocation) from the frontmatter; single-line values only.
# Split with ${line%%$'\t'*}, not read: a tab-only IFS collapses an empty when_to_use. all-plugins.sh keeps a copy because it ships alone.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_listing_fields
pc_listing_fields() {
  local fm dmi=false
  fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$1" 2>/dev/null)
  printf '%s\n' "$fm" | grep -q '^disable-model-invocation:[[:space:]]*true' && dmi=true
  printf '%s\t%s\t%s\n' \
    "$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)" \
    "$(printf '%s\n' "$fm" | sed -n 's/^when_to_use:[[:space:]]*//p' | head -1)" \
    "$dmi"
}

# pc_listing_entry_cost <plugin_dir> — "<chars> <entries>": per skill and command, name + 4 + min(desc + " - " + when_to_use, 1536) bytes under LC_ALL=C, no separators.
# disable-model-invocation entries cost nothing (unmeasured: if the CLI lists the name, this undercounts name + 4); C bytes overcount UTF-8 by ~1%.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_listing_entry_cost
pc_listing_entry_cost() {
  local pdir="$1" plug total=0 n=0 f name fields desc wtu dl
  plug=$(basename "$pdir")
  for f in "$pdir"/skills/*/SKILL.md "$pdir"/commands/*.md; do
    [ -f "$f" ] || continue
    case "$f" in
      */skills/*) name="$plug:$(basename "$(dirname "$f")")" ;;
      *)          name="$plug:$(basename "$f" .md)" ;;
    esac
    fields=$(pc_listing_fields "$f")
    case "$fields" in *$'\t'true) continue ;; esac
    desc=${fields%%$'\t'*}
    wtu=${fields#*$'\t'}; wtu=${wtu%%$'\t'*}
    dl=$(printf '%s%s' "$desc" "${wtu:+ - $wtu}" | LC_ALL=C wc -c | tr -d ' ')
    [ "$dl" -gt "$HOST_LISTING_MAX_DESC" ] && dl=$HOST_LISTING_MAX_DESC
    total=$(( total + ${#name} + 4 + dl )); n=$((n+1))
  done
  printf '%s %s' "$total" "$n"
}

# pc_frontmatter <md_path> — validate.sh's frontmatter FAILs for one SKILL.md, command or agent (kind by path), unprefixed, returns 1; misses invented keys, wrong model: values.
# validate.sh keys on this wording: reword 'missing frontmatter opener' or 'frontmatter not terminated' and its budget check runs on a broken file; a reworded linter line prints out of order.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_frontmatter
pc_frontmatter() {
  local f="$1" d="" fm sname fields dsc wtu dlen bad=0
  local root='^(/|/.*/)?(plugins/[^/]+|\.claude)'
  local skill_re="$root/skills/[^/]+/SKILL\\.md\$" other_re="$root/(commands|agents)/[^/]+\\.md\$"
  if [[ $f =~ $skill_re ]]; then d="${f%SKILL.md}"
  elif [[ $f =~ $other_re ]]; then :
  else return 0
  fi
  if [ -n "$d" ] && [ ! -d "$d" ]; then
    return 0
  elif [ -n "$d" ] && [ -L "${d%/}" ]; then
    :
  elif [ ! -f "$f" ]; then
    [ -n "$d" ] || return 0
    printf '%s\n' "$d: SKILL.md missing"
    return 1
  elif ! head -1 "$f" | grep -q '^---$'; then
    printf '%s\n' "$f: missing frontmatter opener"; bad=1
  elif ! awk '/^---$/{c++} END{exit !(c>=2)}' "$f"; then
    printf '%s\n' "$f: frontmatter not terminated"; bad=1
  else
    fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f")
    if [ -n "$d" ]; then
      grep -q '^name:' <<<"$fm" || { printf '%s\n' "$f: frontmatter missing name:"; bad=1; }
      sname=$(sed -n 's/^name:[[:space:]]*//p' <<<"$fm" | head -1)
      [ "$sname" = "$(basename "$d")" ] \
        || { printf '%s\n' "$f: name '$sname' does not match directory '$(basename "$d")'"; bad=1; }
      grep -q '^description:' <<<"$fm" || { printf '%s\n' "$f: frontmatter missing description:"; bad=1; }
      if ! grep -q '^disable-model-invocation:[[:space:]]*true' <<<"$fm"; then
        grep -q '^description:.*Use \(when\|before\|after\|during\)' <<<"$fm" \
          || { printf '%s\n' "$f: description lacks trigger phrasing (Use when/before/after/during) — a user-invoked skill sets disable-model-invocation: true instead"; bad=1; }
      fi
    else
      grep -q '^description:' <<<"$fm" || { printf '%s\n' "$f: frontmatter missing description:"; bad=1; }
      case "${f%/*}" in
        */agents)
          grep -q '^name:' <<<"$fm" || { printf '%s\n' "$f: frontmatter missing name:"; bad=1; }
          grep -q '^model:' <<<"$fm" || { printf '%s\n' "$f: frontmatter missing model: (pin a tier or use 'inherit')"; bad=1; }
          grep -q '^effort:' <<<"$fm" || { printf '%s\n' "$f: frontmatter missing effort: (agents default to xhigh)"; bad=1; }
          grep -q '^description:.*\(PROACTIVELY\|Spawned by\)' <<<"$fm" \
            || { printf '%s\n' "$f: agent description needs PROACTIVELY or a sub-dispatch marker (Spawned by)"; bad=1; }
          ;;
      esac
    fi
  fi
  case "$f" in .claude/skills/*|*/.claude/skills/*) return $bad ;; esac
  [ -f "$f" ] || return $bad
  fields=$(pc_listing_fields "$f")
  dsc=${fields%%$'\t'*}
  wtu=${fields#*$'\t'}; wtu=${wtu%%$'\t'*}
  grep -qE '^[>|]' <<<"$dsc"$'\n'"$wtu" \
    && { printf '%s\n' "$f: description or when_to_use uses a YAML block scalar — keep it a single line"; bad=1; }
  [ -n "$dsc" ] || return $bad
  dlen=$(printf '%s%s' "$dsc" "${wtu:+ - $wtu}" | wc -c | tr -d ' ')
  [ "$dlen" -le 500 ] || { printf '%s\n' "$f: description${wtu:+ + when_to_use} $dlen chars (max 500)"; bad=1; }
  grep -qE 'Trigger( words)?:' <<<"$dsc"$'\n'"$wtu" \
    && { printf '%s\n' "$f: description${wtu:+ or when_to_use} carries a 'Trigger words:' list — fold terms into the trigger sentence"; bad=1; }
  return $bad
}

# pc_hook_exec <plugin_dir> — per hooks/hooks.json, "<f>: invalid JSON" or a ${CLAUDE_PLUGIN_ROOT} script missing or not executable (bash/sh-led: missing only); returns 1.
# Misses a path not opening on ${CLAUDE_PLUGIN_ROOT}, a broken executable, a missing timeout (pc_hook_timeout); no dir or no jq returns 0.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_hook_exec
pc_hook_exec() {
  local root="${1%/}" bad=0 f plugroot cmd script
  command -v jq >/dev/null 2>&1 || return 0
  [ -d "$root" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    jq empty "$f" 2>/dev/null || { printf '%s\n' "$f: invalid JSON"; bad=1; continue; }
    plugroot=$(dirname "$(dirname "$f")")
    while IFS= read -r cmd; do
      script=$(_pc_hook_script "$cmd" "$plugroot")
      case "$script" in "$plugroot"/*) ;; *) continue ;; esac
      if [ -n "$(_pc_hook_interp "$cmd")" ]; then [ -f "$script" ] && continue
      else [ -x "$script" ] && continue; fi
      printf '%s\n' "$f: hook script $script missing or not executable"; bad=1
    done < <(jq -r '.. | .command? // empty' "$f")
  done < <(find "$root" -path '*/hooks/hooks.json')
  return $bad
}

# pc_mod_modules <plugins_root> — a hooks.json `modules` entry missing, not .ts/.tsx/.mts/.cts/.js/.mjs, without `export function|const register`, or a second entry: mod-module-* lines.
# Reads text only: a commented-out register passes, `export { register }` fails; `../x.ts` is resolved, not refused; no jq returns 0.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_mod_modules
pc_mod_modules() {
  local root="${1%/}" bad=0 hj d p m n
  local re='export[[:space:]]+((async[[:space:]]+)?function|const)[[:space:]]+register([^[:alnum:]_$]|$)'
  command -v jq >/dev/null 2>&1 || return 0
  for hj in "$root"/*/hooks/hooks.json; do
    [ -f "$hj" ] || continue
    d=$(dirname "$hj"); p=$(basename "$(dirname "$d")")
    n=$(jq '(.modules | arrays | length) // 0' "$hj" 2>/dev/null)
    [ "${n:-0}" -gt 1 ] && { printf 'mod-module-count %s %s\n' "$p" "$n"; bad=1; }
    while IFS= read -r m; do
      if [ ! -f "$d/$m" ]; then
        printf 'mod-module-missing %s %s\n' "$p" "$m"; bad=1; continue
      fi
      case "$m" in
        *.ts|*.tsx|*.mts|*.cts|*.js|*.mjs) ;;
        *) printf 'mod-module-ext %s %s\n' "$p" "$m"; bad=1 ;;
      esac
      grep -qE "$re" "$d/$m" || { printf 'mod-module-no-register %s %s\n' "$p" "$m"; bad=1; }
    done < <(jq -r '.modules | arrays | .[] | tostring' "$hj" 2>/dev/null)
  done
  return $bad
}

# pc_mod_kit <plugins_root> <canonical> — a cc-kit.ts copy not byte-identical to <canonical>, a kit not exporting hostOf, or a hooks file defining its own `function hostOf(`.
# Prints mod-kit-drift|mod-host-unexported|mod-host-paste <file>. Proves copies match, not that the kit is right; an arrow or renamed hostOf is missed.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_mod_kit
pc_mod_kit() {
  local root="${1%/}" canon="$2" kdir d f bad=0
  [ -r "$canon" ] || return 0
  kdir=$(dirname "$canon")
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    cmp -s "$canon" "$f" || { printf 'mod-kit-drift %s\n' "$f"; bad=1; }
  done < <(find "$root" -mindepth 3 -maxdepth 3 -path '*/hooks/cc-kit.ts' 2>/dev/null | sort
           printf '%s\n' "$kdir/kit-harness/hooks/cc-kit.ts")
  grep -qF 'export function hostOf(' "$canon" || { printf 'mod-host-unexported %s\n' "$canon"; bad=1; }
  while IFS= read -r d; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
      [ -n "$f" ] && [ "$f" != "$d/cc-kit.ts" ] || continue
      printf 'mod-host-paste %s\n' "$f"; bad=1
    done < <(grep -rlE '(^|[^A-Za-z0-9_$.])function[[:space:]]+hostOf[[:space:]]*\(' "$d" --include='*.ts' \
               --include='*.tsx' --include='*.mts' --include='*.cts' --include='*.js' --include='*.mjs' 2>/dev/null | sort)
  done < <(find "$root" -mindepth 2 -maxdepth 2 -type d -name hooks 2>/dev/null | sort
           printf '%s\n' "$kdir/kit-harness/hooks")
  return $bad
}

# pc_role_floors <registry_md> <plugins_root> — role-floors.md rows against agent model:/floor:/floor-reason: frontmatter: "fail <validate.sh text>" per violation, "exempt <agent>: <reason>".
# Misses a false floor-reason, floor: values other than none, agents with no model:. Keep `done < <(…)`, grep -qxF (a * key globs under case) and bash 3.2.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_role_floors
pc_role_floors() {
  local rf="$1" root="${2%/}" rows="" keys="" seen="" dup="" bad=0
  local row nf key tier ap fm af fmb m k fl fr rel has
  [ -f "$rf" ] && rows=$(awk '/^```/{f=!f; next} f' "$rf" | grep -v '^[[:space:]]*$' || true)
  if [ -z "$rows" ]; then
    printf 'fail %s\n' "role-floors registry: $rf missing, empty, or has no parseable rows"
    bad=1
  else
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      nf=$(printf '%s\n' "$row" | awk '{print NF}')
      key=$(printf '%s\n' "$row" | awk '{print $1}')
      tier=$(printf '%s\n' "$row" | awk '{print $2}')
      if printf '%s\n' "$seen" | grep -qxF "$key"; then
        printf '%s\n' "$dup" | grep -qxF "$key" \
          || { printf 'fail %s\n' "role-floors registry: $key appears more than once"; bad=1; dup="$dup
$key"; }
      else
        seen="$seen
$key"
      fi
      if [ "$nf" -ne 2 ] || ! printf '%s' "$key" | grep -qE '^[a-z0-9-]+:[a-z0-9-]+$'; then
        printf 'fail %s\n' "role-floors registry: $key tier '$tier' is not one of haiku|sonnet|opus|fable"
        bad=1; continue
      fi
      case "$tier" in
        haiku|sonnet|opus|fable) ;;
        *) printf 'fail %s\n' "role-floors registry: $key tier '$tier' is not one of haiku|sonnet|opus|fable"
           bad=1; continue ;;
      esac
      ap="$root/${key%%:*}/agents/${key##*:}.md"
      if [ ! -f "$ap" ]; then
        printf 'fail %s\n' "role-floors registry: $key resolves to no agent file ($ap)"
        bad=1; continue
      fi
      fm=$(awk '/^---$/{c++; next} c==1' "$ap" \
           | sed -n 's/^model:[[:space:]]*//p' | head -1 \
           | sed -e 's/\r$//' -e 's/[[:space:]]*$//')
      [ "$tier" = "$fm" ] \
        || { printf 'fail %s\n' "role-floors registry: $key tier '$tier' != $ap frontmatter model '$fm'"; bad=1; }
      keys="$keys
$key"
    done < <(printf '%s\n' "$rows")
  fi
  while IFS= read -r af; do
    [ -f "$af" ] || continue
    fmb=$(awk '/^---$/{c++; next} c==1' "$af")
    m=$(printf '%s\n' "$fmb" | sed -n 's/^model:[[:space:]]*//p' | head -1 \
        | sed -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$m" ] || continue
    [ "$m" = "inherit" ] && continue
    rel="${af#"$root"/}"
    k="${rel%%/*}:$(basename "$af" .md)"
    fl=$(printf '%s\n' "$fmb" | sed -n 's/^floor:[[:space:]]*//p' | head -1 \
         | sed -e 's/\r$//' -e 's/[[:space:]]*$//')
    fr=$(printf '%s\n' "$fmb" | sed -n 's/^floor-reason:[[:space:]]*//p' | head -1 \
         | sed -e 's/\r$//' -e 's/[[:space:]]*$//')
    has=0
    printf '%s\n' "$keys" | grep -qxF "$k" && has=1
    if [ "$has" -eq 1 ] && [ "$fl" = "none" ]; then
      printf 'fail %s\n' "$af: has a role-floors row AND 'floor: none' - a row means floored"
      bad=1; continue
    fi
    if [ "$fl" = "none" ]; then
      if [ -z "$(printf '%s' "$fr" | tr -d '[:space:]')" ]; then
        printf 'fail %s\n' "$af: 'floor: none' requires a non-empty floor-reason:"
        bad=1
      else
        printf 'exempt %s: %s\n' "$af" "$fr"
      fi
      continue
    fi
    case "$m" in
      haiku|sonnet|opus|fable) ;;
      *) printf 'fail %s\n' "$af: frontmatter model '$m' is not inherit or one of haiku|sonnet|opus|fable"
         bad=1; continue ;;
    esac
    [ "$has" -eq 1 ] \
      || { printf 'fail %s\n' "$af: pins model '$m' but has neither a role-floors row nor 'floor: none'"; bad=1; }
  done < <(find "$root" -path '*/agents/*.md' -type f | sort)
  return $bad
}

_pc_tool_fit_units() { # <file> <agent|ref> — "<line>\t<sentence>" per prose sentence outside a blessed block
  awk -v mode="$2" '
    function flush(   rest, start, seg, m) {
      if (buf == "") return
      if (index(buf, "<!-- tool-fit-ok:")) blk = 1
      rest = buf
      while (rest != "") {
        if (match(rest, /[.!?][)"'"'"'*_`]*[[:space:]]+/)) { seg = substr(rest, 1, RSTART + RLENGTH - 1); rest = substr(rest, RSTART + RLENGTH) }
        else { seg = rest; rest = "" }
        start = cur
        if (match(seg, /^[[:space:]]*\034[0-9]+\035/)) { m = substr(seg, RSTART, RLENGTH); gsub(/[^0-9]/, "", m); start = m }
        while (match(seg, /\034[0-9]+\035/)) {
          m = substr(seg, RSTART, RLENGTH); gsub(/[^0-9]/, "", m); cur = m
          seg = substr(seg, 1, RSTART - 1) substr(seg, RSTART + RLENGTH)
        }
        if (seg ~ /[^[:space:]]/) pend = pend start "\t" descr(seg) "\n"
      }
      buf = ""
    }
    # ok carries a blessed block to the fence below it.
    function endblock() {
      flush()
      if (pend != "") { if (!blk) printf "%s", pend; ok = blk }
      pend = ""; blk = 0
    }
    # that/which/who or the user as subject describes, not orders: \037 splits the verb. `after that run`: a demonstrative.
    function descr(s,   l, out, j, d) {
      s = " " s; l = tolower(s); out = ""
      while (match(l, /[^a-z0-9_](that|which|who)([[:space:]]+([a-z]+ly|also|then|still|now|would|could|can|may|might|will|should|must|does))*[[:space:]]+(run|execute|invoke|write|save|persist|append|store|create|use|pipe|call|compute|take|seed|verify)|[^a-z0-9_]users?([[:space:]]+([a-z]+ly|also|then|would|could|can|may|might|will|should|must|to|whether))*[[:space:]]+(run|execute|invoke|write|save|persist|append|store|create|use|pipe|call|compute|take|seed|verify)/)) {
        j = RSTART + RLENGTH - 1
        d = substr(l, RSTART + 1, 4) == "that" && substr(l, 1, RSTART) ~ /(^|[^a-z])(after|before|do|did|once|like|with)[[:space:]]*$/
        while (substr(l, j, 1) !~ /[[:space:]]/) j--
        out = out substr(s, 1, j + 1) (d ? "" : "\037")
        s = substr(s, j + 2); l = substr(l, j + 2)
      }
      return substr(out s, 2)
    }
    function add(line) { buf = buf (buf == "" ? "" : " ") "\034" NR "\035" line }
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    fm == 1 { if (/^---[[:space:]]*$/) fm = 2; next }
    /^[[:space:]]*```/ {
      endblock()
      if (!fence && mode == "agent" && !ok && $0 ~ /^[[:space:]]*```[[:space:]]*(bash|sh|shell|zsh|console)[[:space:]]*$/)
        printf "%s\t%s\n", NR, "a ```shell block"
      fence = !fence; next
    }
    fence { next }
    /^[[:space:]]*$/ { endblock(); next }
    /^[[:space:]]*(#|\|)/ { flush(); add($0); flush(); next }
    /^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]/ { flush() }
    { add($0) }
    END { endblock() }
  ' "$1" 2>/dev/null
}

# pc_agent_tool_fit <plugins_root> — an agent body, or a <dir>/references/<f>.md it names, ordering a shell run, a hash or a ```bash fence without Bash, or a file write without Write/Edit.
# Prints "tool-fit <plugin>:<agent> lacks <Bash|Write> — …". Misses dispatch prompts, two hops, SKILL.md, implied acts. Escape: `<!-- tool-fit-ok: <why> -->`.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_agent_tool_fit
pc_agent_tool_fit() {
  local root="${1:-plugins}" bad=0 tab af p n tools nob now ref rf src kind units hits want re ln s
  local SKIP='\b(never|cannot|can.t|do not|don.t|does not|doesn.t|must not|no (bash|shell|write|edit|tools?|files?))\b|main thread|\b(the|your) (caller|dispatcher|orchestrator)\b|\bcaller.s\b'
  local SHELL_RE='\b(run|runs|execute|executes|invoke|invokes)[[:space:]]+`(git|npm|npx|pnpm|yarn|composer|php|node|python3?|bash|sh|jq|curl|make)\b|\brun[[:space:]]+git[[:space:]]+[a-z]|\b(run|runs|use|uses|pipe|pipes|call|calls|compute|computes|take|takes|seed|seeds|verify|execute|executes|invoke|invokes)\b[^;,`]{0,40}(`[^`]*\b(cksum|shasum|sha(1|224|256|384|512)sum|md5sum|b2sum)\b|\b(cksum|shasum|sha(1|224|256|384|512)sum|md5sum|b2sum)\b([[:space:]]*\||[[:space:]]+[^[:space:]`]*[/.][[:alnum:]]))|\b(compute|computes|take|takes|seed|seeded|seeds)[[:space:]]+(it[[:space:]]+)?(from[[:space:]]+)?(a|the)[[:space:]]+hash\b|^[0-9]+[[:space:]]+([-*+]|[0-9]+[.)])?[[:space:]]*(\*\*)?hash[[:space:]]+(the|it|a)\b|```shell'
  local WRITE_RE='\b(write|writes|save|saves|persist|persists|append|appends|store|stores|create|creates)\b[^`]{0,80}\b(to|into|in|at|under)[[:space:]]+`[^`]+\.(md|json|jsonl|tsv|csv|txt|patch|ya?ml|html|log)`|\b(write|create)[[:space:]]+`[^`]+\.(md|json|jsonl|tsv|csv|txt|patch|ya?ml|html|log)`'
  tab=$(printf '\t')
  while IFS= read -r af; do
    tools=$(awk 'NR == 1 && !/^---/ { exit } /^---[[:space:]]*$/ { c++; if (c == 2) exit; next }
                 c == 1 && /^tools:/ { sub(/^tools:[[:space:]]*/, ""); print; exit }' "$af" 2>/dev/null)
    [ -n "$tools" ] || continue
    tools=",$(printf '%s' "$tools" | tr -d " \t\"'[]"),"
    case "$tools" in *,Bash,*|*,Bash\(*) nob=1 ;; *) nob=0 ;; esac
    case "$tools" in *,Write,*|*,Edit,*|*,MultiEdit,*) now=1 ;; *) now=0 ;; esac
    [ "$nob$now" = 11 ] && continue
    p=${af#"$root"/}; p=${p%%/*}; n=$(basename "$af" .md)
    while IFS="$tab" read -r kind src; do
      [ -f "$src" ] || continue
      units=$(_pc_tool_fit_units "$src" "$kind" | grep -viE "$SKIP")
      [ -n "$units" ] || continue
      for want in Bash Write; do
        if [ "$want" = Bash ]; then [ "$nob" = 0 ] || continue; re=$SHELL_RE
        else [ "$now" = 0 ] || continue; re=$WRITE_RE; fi
        hits=$(printf '%s\n' "$units" | grep -iE "$re") || continue
        while IFS="$tab" read -r ln s; do
          printf 'tool-fit %s:%s lacks %s — %s:%s: %.110s\n' "$p" "$n" "$want" "$src" "$ln" \
            "$(printf '%s' "$s" | tr -d '\037' | tr -s ' ' | sed 's/^ //')"
        done <<EOF_TF_HITS
$hits
EOF_TF_HITS
        bad=1
      done
    done <<EOF_TF
$(printf 'agent\t%s\n' "$af"
  grep -oE '[A-Za-z0-9_-]+/references/[A-Za-z0-9._-]+\.md' "$af" 2>/dev/null | sort -u | while IFS= read -r ref; do
    for rf in "$root/$p/skills/$ref" "$root"/*/skills/"$ref"; do
      [ -f "$rf" ] && { printf 'ref\t%s\n' "$rf"; break; }
    done
  done)
EOF_TF
  done < <(find "$root" -path '*/agents/*.md' -type f 2>/dev/null | sort)
  return "$bad"
}

# pc_stray_dirs <plugins_root> — a <root>/*/ dir with no plugin.json, no git-tracked file and no *.md/*.json outside dot-dirs: prints "stray <name>", returns 1.
# An untracked dir holding any .md or .json reads as a half-made plugin, not stray; one tracked file makes any dir non-stray.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_stray_dirs
pc_stray_dirs() {
  local root="${1%/}" bad=0 dir
  for dir in "$root"/*/; do
    [ -d "$dir" ] || continue
    [ -f "${dir}.claude-plugin/plugin.json" ] && continue
    [ "$(git -C "$dir" ls-files -- . 2>/dev/null | wc -l | tr -d ' ')" = 0 ] || continue
    find "$dir" -mindepth 1 -name '.*' -prune -o -type f \( -name '*.md' -o -name '*.json' \) -print 2>/dev/null \
      | grep -q . && continue
    printf 'stray %s\n' "$(basename "$dir")"
    bad=1
  done
  return $bad
}

# pc_route_prompt_literals <hook> — literal /plugin:command tokens on the hook's non-comment lines: prints them space-joined, returns 1.
# Misses tokens built at run time, uppercase or one-letter names, a heredoc line opening with #; over-reports trailing comments and other /ab:cd text.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_route_prompt_literals
pc_route_prompt_literals() {
  local hook="$1" lits
  [ -f "$hook" ] || return 0
  lits=$(grep -v '^[[:space:]]*#' "$hook" 2>/dev/null \
    | grep -oE '/[a-z][a-z0-9-]+:[a-z][a-z0-9-]+' | sort -u | tr '\n' ' ')
  [ -n "$lits" ] || return 0
  printf '%s\n' "${lits% }"
  return 1
}

# pc_route_prompt_greps <hook> — over 4 lines piping printf .%s. "$head" into grep (three refusals plus the work gate): prints the count, returns 1.
# Misses greps spelt another way and a widened alternation in an existing grep; counts lines, so two on one line count once.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_route_prompt_greps
pc_route_prompt_greps() {
  local hook="$1" n
  [ -f "$hook" ] || return 0
  n=$(grep -c 'printf .%s. "\$head" | grep' "$hook" 2>/dev/null)
  [ "${n:-0}" -le 4 ] && return 0
  printf '%s\n' "$n"
  return 1
}

# pc_gating_catch <validate.json> — a `claude plugin validate --json` gatingHooks entry with hasCatch false: prints "<module> <hook>", returns 1; an unreadable report fails too.
# Misses a fail-open .catch, events the host does not count as gating, and every CLI before 2.1.290 (no gatingHooks key); no jq returns 0.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_gating_catch
pc_gating_catch() {
  local f="$1" hits
  command -v jq >/dev/null 2>&1 || return 0
  [ -s "$f" ] || { printf 'unreadable report %s\n' "$f"; return 1; }
  hits=$(jq -r '.. | objects | .gatingHooks? | arrays | .[] | select(.hasCatch == false)
    | "\(.module) \(.hook)"' "$f" 2>/dev/null) || { printf 'unreadable report %s\n' "$f"; return 1; }
  [ -n "$hits" ] || return 0
  printf '%s\n' "$hits"
  return 1
}

# pc_plugin_root_quoting <plugins_root> — a fenced or code-span line in commands/ or skills/ .md running an unquoted ${CLAUDE_PLUGIN_ROOT} path as the command or an interpreter's script.
# Prints "plugin-root-unquoted <plugin> <path>:<line>". Misses plain prose, indented code, unlisted wrappers and launchers, the path as an argument, agents, READMEs.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_plugin_root_quoting
pc_plugin_root_quoting() {
  local root="${1%/}" d
  [ -d "$root" ] || return 0
  for d in "$root"/*/; do
    d=${d%/}
    [ -d "$d/commands" ] && find "$d/commands" -maxdepth 1 -type f -name '*.md'
    [ -d "$d/skills" ] && find "$d/skills" -type f -name '*.md'
  done | sort | tr '\n' '\0' | xargs -0 -r awk -v root="$root" '
    BEGIN {
      R = "[$][{]?CLAUDE_PLUGIN_ROOT"
      OPT = "(--?[A-Za-z-]*[ \t]+)*"
      WRAP = "((sudo|env)[ \t]+" OPT "|[A-Za-z_][A-Za-z0-9_]*=(\"[^\"]*\"|\047[^\047]*\047|[^ \t]*)[ \t]+)*"
      INTERP = "(bash|sh|node|python3?)[ \t]+" OPT
      SPAN = "^[ \t]*" WRAP "(" INTERP R "|" R "[^ \t]*([.](sh|bash|py|mjs|cjs|js|ts)[ \t]*$|[ \t]+[^ \t]))"
      LINE = "(^|[;&|(])[ \t]*" WRAP "(" INTERP ")?" R
      ANY = "(^|[^A-Za-z0-9_./-])" INTERP R
    }
    function hit(ln,  rel) {
      if (FILENAME == lastf && ln == lastl) return
      lastf = FILENAME; lastl = ln
      rel = substr(FILENAME, length(root) + 2)
      printf "plugin-root-unquoted %s %s:%d\n", substr(rel, 1, index(rel, "/") - 1), substr(rel, index(rel, "/") + 1), ln
      found = 1
    }
    function add(t) {
      if (!bufline && t ~ /[^ \t]/) bufline = FNR
      buf = buf t
    }
    FNR == 1 { fch = ""; open = 0 }
    fch != "" {
      if (match($0, /^[ \t]*(```+|~~~+)[ \t]*$/)) {
        f = $0; gsub(/[ \t]/, "", f)
        if (substr(f, 1, 1) == fch && length(f) >= flen) { fch = ""; next }
      }
      if ($0 ~ LINE || $0 ~ ANY) hit(FNR)
      next
    }
    match($0, /^[ \t]*(```+|~~~+)/) {
      f = substr($0, RSTART, RLENGTH); sub(/^[ \t]*/, "", f)
      if (substr(f, 1, 1) == "~" || substr($0, RSTART + RLENGTH) !~ /`/) {
        fch = substr(f, 1, 1); flen = length(f); open = 0; next
      }
    }
    /^[ \t]*$/ { open = 0; next }
    {
      s = $0
      if (open) add(" ")
      while (match(s, /`+/)) {
        pre = substr(s, 1, RSTART - 1); run = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        if (!open) { open = length(run); buf = ""; bufline = 0; continue }
        add(pre)
        if (length(run) == open) { if (buf ~ SPAN) hit(bufline); open = 0 }
        else add(run)
      }
      if (open) add(s)
    }
    END { exit found }' || return 1
}

# pc_undefined_terms [plugins_root] [watchlist] [glossary_md] — a watchlist term in installer text with no "## Words we use" row: prints "undefined-term <file> <term>", returns 1.
# Misses every term not on the watchlist, word forms past a plural s, agent descriptions and skill bodies, and whether a row's definition is right; a term inside a longer hyphenated word is no hit.
# Why, limits, history: rationale/derivations/scripts-lib.md § pc_undefined_terms
pc_undefined_terms() {
  local root="${1:-plugins}" watch="${2:-scripts/glossary-watchlist.txt}" gloss="${3:-README.md}" undef out
  if [ ! -f "$watch" ]; then printf 'undefined-term %s (watchlist missing)\n' "$watch"; return 1; fi
  [ -f "$gloss" ] || gloss=/dev/null
  undef=$(awk -v G="$gloss" '
    FILENAME == G {
      if (/^## Words we use/) on = 1; else if (/^## /) on = 0
      else if (on && /^\|/) { c = $0; sub(/^\|[ \t]*/, "", c); sub(/[ \t]*\|.*$/, "", c); gsub(/[`*]/, "", c); def[tolower(c)] = 1 }
      next
    }
    /^[ \t]*(#|$)/ { next }
    { t = tolower($0); gsub(/^[ \t]+|[ \t]+$/, "", t); if (!(t in def)) print t }' "$gloss" "$watch")
  [ -n "$undef" ] || return 0
  out=$({
    find "$root" -mindepth 2 -maxdepth 2 -name README.md -exec awk '
      FNR == 1 { f = 0 } /^[ \t]*(```|~~~)/ { f = !f; next } !f { print FILENAME "\t" $0 }' {} +
    find "$root" -mindepth 3 -maxdepth 4 \( -path "$root/*/skills/*/SKILL.md" -o -path "$root/*/commands/*.md" \) -exec awk '
      FNR == 1 { c = 0 } /^---[ \t]*$/ { c++; next } c == 1 && /^(description|when_to_use):/ { print FILENAME "\t" $0 }' {} +
    find "$root" -mindepth 3 -maxdepth 3 -path "$root/*/.claude-plugin/plugin.json" -exec jq -r '[input_filename, (.description // "")] | @tsv' {} +
  } 2>/dev/null | TERMS="$undef" awk -F'\t' '
    BEGIN { n = split(ENVIRON["TERMS"], T, "\n"); for (i = 1; i <= n; i++) { r = T[i]; gsub(/[- ]/, "[- ]?", r); R[i] = "(^|[^a-z0-9_-])" r "s?([^a-z0-9_-]|$)" } }
    { s = tolower(substr($0, length($1) + 2))
      for (i = 1; i <= n; i++) if (!(($1, i) in seen) && s ~ R[i]) { seen[$1, i] = 1; print "undefined-term " $1 " " T[i] } }' | sort -u)
  [ -n "$out" ] || return 0
  printf '%s\n' "$out"
  return 1
}
