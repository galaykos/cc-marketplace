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
PC_JARGON='(^|[^[:alnum:]])(card #?[0-9][0-9]|finding #[0-9]|smoke[ -]test #?[0-9]|the back-?log)'
# These shapes also match prose a plugin has every right to write, and did:
# "Use a credit card 16 digits long" (payments), "The backlog of user stories is
# groomed weekly" (estimation/rollout) and "finding #2 in the OWASP report"
# (security) were all REJECTED before this rescue list existed.
PC_JARGON_EN='(credit|debit|gift|payment|loyalty|graphics|SIM|library|report) card|card (number|reader|holder)|(product|sprint|issue|story|user|work) backlog|backlog of|(finding|smoke[ -]test) #?[0-9]+ (in|of|from) '
pc_jargon() {
  local f="$1" hit
  [ -f "$f" ] || return 0
  hit=$(grep -v '<!-- jargon-ok -->' "$f" \
        | grep -ivE "$PC_JARGON_EN" \
        | grep -iEo "$PC_JARGON" \
        | sed 's/^[^[:alnum:]]//' | sort -u | tr '\n' ',' | sed 's/,$//')
  [ -z "$hit" ] && return 0
  printf '%s\n' "$hit"
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
