#!/usr/bin/env bash
# Shared per-plugin checks, sourced by validate.sh (full sweep) and
# authoring-guard.sh (single edited file). Pure: sourcing runs no code, functions
# close over no caller globals (no err/fail/allow_md), and take all inputs as args.

# pc_skill_budget <skill_md_path>
# On a body-length violation: prints "budget <path> <n>" and returns 1.
# Clean or missing file: prints nothing, returns 0.
#
# CEILING ONLY (2026-07-27). The former 100-line FLOOR was removed: it failed the
# build for a skill that said its piece in 60 lines, so bodies were padded up to
# clear it — 58 of 139 skills sat pinned to a budget edge (35 at 100-109, 5 at
# exactly 100, 23 at exactly 150). The floor manufactured the bloat the ceiling
# exists to stop.
#
# LIMITATION (honest scope), two residuals:
#   1. Nothing replaces the floor as a stub guard. validate.sh's description
#      check reads the frontmatter `description:` line only and constrains body
#      length in no way, so a 3-line body with a trigger sentence now passes
#      every gate in this repo. Accepted, not covered.
#   2. n=0 (missing or unterminated frontmatter — the `c>=2` awk emits nothing)
#      now returns 0 instead of failing. This function is authoring-guard.sh's
#      ONLY SKILL.md check, so a malformed SKILL.md draws no in-session warning;
#      validate.sh's frontmatter-opener/terminator checks still catch it at CI.
pc_skill_budget() {
  local f="$1" n
  [ -f "$f" ] || return 0
  n=$(awk '/^---$/{c++; next} c>=2' "$f" | wc -l | tr -d ' ')
  if [ "$n" -gt 150 ]; then
    printf 'budget %s %s\n' "$f" "$n"
    return 1
  fi
  return 0
}

# pc_jargon <md_path>
# Internal-taskmaster-vocabulary denylist with an ordinary-English rescue list.
# On a hit: prints the comma-joined matches and returns 1. Clean: prints nothing,
# returns 0. Lives here so validate.sh and the smoke fixtures share ONE source —
# a fixture that re-declared the patterns would drift from the gate it tests.
#
# LIMITATION (honest scope): a heuristic denylist over prose with a rescue list,
# not a parser. It converts "leak the internal vocabulary without noticing" into
# "leak it in a form that does not read as ordinary English". Two residuals:
# (1) a real leak sharing a line with a rescued phrase is missed; (2) unrescued
# ordinary English in these shapes still false-positives, and the author's only
# recourse is the <!-- jargon-ok --> marker.
pc_jargon() {
  local f="$1" hit jargon rescue
  [ -f "$f" ] || return 0
  # cards? — plural included (2026-07-28): "cards 03, 05" leaked past the
  # singular-only pattern in a shipped SKILL while reading as internal vocab.
  jargon='(^|[^[:alnum:]])(cards? #?[0-9][0-9]|finding #[0-9]|smoke[ -]test #?[0-9]|the back-?log)'
  # Ordinary English that these shapes WOULD reject. No shipped plugin .md
  # contains them — the gate would have failed CI — so these are probes from the
  # task card, not observed leaks. Stating it that way keeps the claim inside
  # its evidence, which is the same discipline the gate itself is about.
  #   "Use a credit card 16 digits long."            (payments)
  #   "The backlog of user stories is groomed."      (estimation / rollout)
  #   "See finding #2 in the OWASP report."          (security)
  #   "Run smoke test 3 in the regression suite."
  rescue='(credit|debit|gift|payment|loyalty|graphics|SIM|library|report) card|card (number|reader|holder)|(product|sprint|issue|story|user|work) backlog|backlog of|(finding|smoke[ -]test) #?[0-9]+ (in|of|from) '
  hit=$(grep -viF '<!-- jargon-ok -->' "$f" \
        | grep -ivE "$rescue" \
        | grep -iEo "$jargon" \
        | sed 's/^[^[:alnum:]]//' | sort -u | tr '\n' ',' | sed 's/,$//')
  [ -z "$hit" ] && return 0
  printf '%s\n' "$hit"
  return 1
}

# pc_removed_refs <md_path>
# Removed-artifact reference denylist (ground truth: rationale/stack-skill-
# baselines.md, 2026-07-27). The typescript/javascript/vue2 plugins and the
# react/css-family best-practices skills were removed; design-patterns,
# intent-guard, rollout, error-handling and concurrency were merged away as
# plugins. A shipped doc still routing to one of them is a dangling pointer no
# other gate sees — validate.sh's reference check reads only the
# /plugin:command slash form. On a hit: prints the comma-joined matches and
# returns 1. Clean: prints nothing, returns 0. Lives here so validate.sh and
# the smoke fixtures share ONE source, same as pc_jargon.
#
# SHAPE-BOUNDED BY DESIGN: rollout, concurrency, error-handling, typescript
# and javascript are ordinary technical English as bare words ("migrations, or
# concurrency" appears in ~20 review commands), so PLUGIN names match only in
# reference shapes — a bolded member row (**vue2**), "<name> plugin(s)", a
# plugins/<name> path, an install target (<name>@…), a routing arrow
# (→ <name>), or the /<name>: command form. Removed SKILL names
# (react-best-practices, css3/css-grid/flexbox/bootstrap-best-practices) are
# unambiguous hyphenates and match word-bounded anywhere. claude-api is Claude
# Code's BUILT-IN skill, not a marketplace artifact: a line naming it as if it
# were one is a hit UNLESS that line says built-in, external or
# harness-provided (or carries the escape) — the honest wording stays legal.
# harness-provided is in the token list because the shipped llm-app disclosure
# wraps: "Claude Code's built-in" ends one line and "claude-api skill —
# harness-provided, not part of this marketplace" starts the next, and this
# check is line-scoped by design.
#
# LIMITATION (honest scope): a heuristic over prose, lowercase-only for plugin
# names (TitleCase "TypeScript" is the language, not the plugin), so a
# capitalized stale row would slip; capability-breadth staleness ("react
# reviews components") names no removed artifact and is invisible here. The
# rescue list frees lines DISCUSSING a removal; anything else needs the
# <!-- removed-ok --> marker.
pc_removed_refs() {
  local f="$1" b plug skills shapes rescue hit capi
  [ -f "$f" ] || return 0
  b='[^[:alnum:]-]'
  plug='typescript|javascript|vue2|design-patterns|intent-guard|rollout|error-handling|concurrency'
  skills='react-best-practices|css3-best-practices|css-grid-best-practices|flexbox-best-practices|bootstrap-best-practices'
  shapes="\\*\\*($plug)\\*\\*|(^|$b)($plug)\`? plugins?($b|\$)|(^|$b)plugins/($plug)($b|\$)|(^|$b)($plug)@|(→|->) ?\`?($plug)($b|\$)|/($plug):|(^|$b)($skills)($b|\$)"
  # Lines legitimately discussing the removal itself stay legal without a
  # marker. Every phrase below is quoted from a shipped disclosure:
  #   "it was removed after baseline testing"          (plugin-scout flags.md)
  #   "`error-handling` and `concurrency` plugins were / merged into this one"
  #   "**vue2** (Vue 2 is EOL) is no longer bundled"   (frontend-suite README)
  rescue="(was|were|been|are|is) (removed|merged|retired)|merged into|no longer|plugins? (were|was)($b|\$)"
  hit=$(grep -vF '<!-- removed-ok -->' "$f" \
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

# pc_doc_location <plugins_relative_md> <allow_regex>
# $1 is a repo-relative path beginning "plugins/<name>/…". Mirrors validate.sh:
# strips "plugins/*/" and greps the caller-supplied allow regex.
# On violation: prints "doc-location <path>" and returns 1. Clean: returns 0.
pc_doc_location() {
  local mdf="$1" allow="$2" rel
  rel=${mdf#plugins/*/}
  printf '%s\n' "$rel" | grep -qE "$allow" && return 0
  printf 'doc-location %s\n' "$mdf"
  return 1
}

# pc_rules_cofire <rules_tsv_path> <corpus_dir>
# CONTENT-row co-firing gate. Two content rows co-fire when BOTH patterns match at
# least one file in a shared corpus of representative source snippets. Every such
# unordered pair must be blessed by a
#   "# co-fire-ok: content <skillA> <skillB>"
# directive in the same file — the same convention the glob axis already uses.
#
# WHY A CORPUS, not pattern equality: pc_rules_overlap flags glob rows that share an
# IDENTICAL pattern string. Content rows never do — all five are distinct regexes at
# low confidence — so extending that algorithm here would be vacuous, matching nothing
# ever. Content rows collide because two DIFFERENT regexes match the same text: one
# ordinary React component containing `await`, `catch`, `fetch(`, `console.error` and
# `token` fires four of them at once. Only a corpus can express that.
#
# LIMITATION (honest scope): the corpus is a fixed, hand-written sample. This converts
# "add a content row and never learn what it co-fires with" into "add one and the gate
# names every existing row it collides with on realistic code". It does NOT prove the
# absence of collisions on code shapes the corpus does not contain, and it says nothing
# about whether a blessed co-fire is a good idea — only that someone declared it.
#
# On violation: prints "cofire <skillA> <skillB> <file>" per unblessed pair, returns 1.
pc_rules_cofire() {
  local f="$1" corpus="$2" rc=0
  [ -f "$f" ] || return 0
  [ -d "$corpus" ] || return 0
  local blessed pats skills n i j
  blessed=$(grep '^# co-fire-ok:[[:space:]]*content ' "$f" 2>/dev/null \
            | sed 's/^# co-fire-ok:[[:space:]]*content //')
  # collect content rows
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

# pc_rules_overlap <rules_tsv_path>
# Flags unresolved same-pattern collisions among high-confidence glob rows.
# Every unordered pair of rows sharing an identical pattern must be either
# marker-discriminated (both rows carry a stack_marker, and they differ) or
# covered by a pairwise "# co-fire-ok: <pattern> <skillA> <skillB>" directive
# (space-tokenized) in the same file. Content and low-confidence rows are
# never flagged; identical-pattern subsumption (*.php vs *.blade.php) is out
# of scope by design.
# On violation: prints "overlap <pattern> <skillA> <skillB>" per pair and
# returns 1. Clean or missing file: returns 0.
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
