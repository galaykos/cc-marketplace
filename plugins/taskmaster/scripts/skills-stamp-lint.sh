#!/usr/bin/env bash
# skills-stamp-lint.sh — author-time lint for a task card's skill stamp (<skill name="…"/> elements, or the legacy `Skills to apply` bold line): blocks a card touching framework source (.php/.blade.php/.vue/.jsx/.tsx) that names no skill; warns, exit 0, on a stamped skill no sibling plugin ships and on a bare stamp a project skill shadows.
# Misses: generic .ts/.js/.py cards (a "none detected" there is defensible); whether a named skill fits the card.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/skills-stamp-lint.sh (marketplace repository)

# CLI:
#   skills-stamp-lint.sh --card <card.md>                    # lint the card's stamp
#   skills-stamp-lint.sh --line "<value>" --files "<paths>"  # (testing) parts form
# Exit codes:
#   0  OK (non-framework card, or framework card that names a skill)
#   2  block: missing-stamp | framework-card-no-skill
#   3  usage
set -euo pipefail

# Run record (card-lint-record.sh), written on both outcomes: the lint ran and what it said, never that the card is good.
_cardlint_target=""
. "$(dirname "$0")/card-lint-record.sh" 2>/dev/null || true
record_run() { # $1 = verdict. No-op in --line mode: no file to key the record on.
  [ -n "$_cardlint_target" ] || return 0
  command -v cardlint_write >/dev/null 2>&1 || return 0
  cardlint_write skills-stamp "$_cardlint_target" "$1"
}

PROG=skills-stamp
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }
fail()  { record_run block; printf '%s: %s\n' "$PROG" "$1" >&2; exit 2; }

mode=""; card=""; line=""; files=""
while [ $# -gt 0 ]; do
  case "$1" in
    --card)  [ $# -ge 2 ] || usage "--card needs an argument"; card="$2"; mode=card; shift 2 ;;
    --line)  [ $# -ge 2 ] || usage "--line needs an argument"; line="$2"; mode=parts; shift 2 ;;
    --files) [ $# -ge 2 ] || usage "--files needs an argument"; files="$2"; shift 2 ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) usage "unknown argument: $1" ;;
  esac
done

if [ "$mode" = card ]; then
  [ -f "$card" ] || usage "card file not found: $card"
  _cardlint_target="$card"
  # Tagged <skill name="…"/> lines first (`name="none"` is the explicit no-skill stamp), else the legacy **Skills to apply:** label.
  tagged=$(grep -E '^<skill([ />]|$)' "$card" 2>/dev/null || true)
  if [ -n "$tagged" ]; then
    line=$(printf '%s\n' "$tagged" | grep -Eo 'name="[^"]*"' | sed -e 's/^name="//' -e 's/"$//' | paste -sd, -)
    files=$(grep -Ev '^<skill([ />]|$)' "$card" || true)   # the card minus the stamp lines
  else
    raw=$(grep -E -m1 '\*\*Skills to apply:\*\*' "$card" 2>/dev/null || true)
    [ -n "$raw" ] || fail "missing-stamp: card has no <skill> element and no **Skills to apply:** line"
    line=${raw#*\*\*Skills to apply:\*\*}
    files=$(grep -vF -- "$raw" "$card" || true)   # the card minus the stamp line
  fi
elif [ "$mode" != parts ]; then
  usage "need --card <file> (or --line \"<value>\" --files \"<paths>\" for testing)"
fi

# normalize the stamp value: trim, strip one backtick layer, trim
val=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^`//' -e 's/`$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# framework-strong source signal: extensions that unambiguously map to a plugin skill
fw_re='\.blade\.php|\.(php|vue|jsx|tsx)([^a-z0-9]|$)'
if printf '%s' "$files" | grep -Eiq -- "$fw_re"; then
  low=$(printf '%s' "$val" | tr 'A-Z' 'a-z')
  case "$low" in
    ""|none*|"n/a"|"n\a"|"-"|"—")
      fail "framework-card-no-skill: card touches framework source but names no skill (stamp: \"$val\") — name the relevant best-practice skill (e.g. laravel:laravel-best-practices)" ;;
  esac
fi

# sibling_plugin <skill> [plugin] — prints the sibling plugin shipping skills/<skill>/SKILL.md, status 1 when none; reads a source checkout or the installed cache (one level deeper); a cached-but-disabled plugin counts.
sibling_plugin() {
  local r sk p=${2:-*}
  r=$(cd "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}" 2>/dev/null && pwd) || return 1
  if [ "${r##*/}" = taskmaster ]; then
    for sk in "$r"/../$p/skills/"$1"/SKILL.md; do
      [ -f "$sk" ] && { sk=${sk%/skills/*}; printf '%s\n' "${sk##*/}"; return 0; }
    done
  else
    for sk in "$r"/../../$p/*/skills/"$1"/SKILL.md; do
      [ -f "$sk" ] && { sk=${sk%/skills/*}; sk=${sk%/*}; printf '%s\n' "${sk##*/}"; return 0; }
    done
  fi
  return 1
}

# Reachability probe, WARN only (cross-marketplace and project skills are legitimate); the root falls back to this script's plugin because the Bash tool carries no CLAUDE_PLUGIN_ROOT.
probe_root=$(cd "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}" 2>/dev/null && pwd) || probe_root=""
case "$(printf '%s' "$val" | tr 'A-Z' 'a-z')" in ""|none*|"n/a"|"n\a"|"-"|"—") probe_root="" ;; esac
if [ -n "$probe_root" ]; then
  for tok in $(printf '%s' "$val" | tr ',' ' '); do
    case "$tok" in ?*:*) p=${tok%%:*}; s=${tok#*:} ;; *) p=""; s=$tok ;; esac
    case "$p$s" in *[!a-z0-9-]*|"") continue ;; esac
    [ -n "$s" ] || continue
    sibling_plugin "$s" ${p:+"$p"} >/dev/null || printf '%s: warn unreachable-skill: "%s" is stamped but no installed sibling plugin%s ships skills/%s/SKILL.md — the card will run framework-blind unless that plugin is installed\n' "$PROG" "$tok" "${p:+ named $p}" "$s" >&2
  done
fi

# Shadow probe, WARN only: a bare stamp resolves to a same-named project skill (Laravel Boost writes some) before a plugin's; misses ~/.claude/skills and Boost twins missing below.
proj=""
[ -n "$card" ] && proj=$(git -C "$(dirname "$card")" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$proj" ] || proj=${CLAUDE_PROJECT_DIR:-$PWD}
for tok in $(printf '%s' "$val" | tr ',' ' '); do
  case "$tok" in *[!a-z0-9-]*|"") continue ;; esac
  [ -f "$proj/.claude/skills/$tok/SKILL.md" ] || continue
  case "$tok" in
    inertia-react-development) want=laravel:inertia-best-practices ;;
    tailwindcss-development)   want=ui-ux:tailwind-best-practices ;;
    *) p=$(sibling_plugin "$tok") || continue; want="$p:$tok" ;;
  esac
  printf '%s: warn shadowed-skill: "%s" resolves to the project copy .claude/skills/%s/SKILL.md, not the marketplace skill — stamp "%s" to apply that one (keep the bare name only if the project copy is the one you mean)\n' "$PROG" "$tok" "$tok" "$want" >&2
done
record_run pass
exit 0
