#!/usr/bin/env bash
# Smoke tests for pc_scout_names (scripts/lib/plugin-checks.sh).
#
# WHY THIS FILE EXISTS. The check's whole point is that it fires on a name nobody
# remembered to remove, which means nobody will ever exercise it by hand — the
# defect it was written for (a dead `i18n` row in plugin-scout's tier-1 signal
# table, feeding `--yes`) had already been fixed in the working tree by the time
# the check first ran green. A gate whose only observed state is "passes on a
# clean repo" is indistinguishable from `return 0`; these fixtures are the record
# that it has been watched fail.
#
# WHAT IS PINNED IS THE ASSERTION LIST BELOW, and nothing else. Read
# pc_scout_names' own header for what the check does and does not catch — this
# header deliberately does not restate it. If the two ever disagree, the
# assertions win, because they run.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib/plugin-checks.sh" 2>/dev/null || { echo "FAIL: cannot source plugin-checks.sh"; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

# A fake root with a two-plugin marketplace. `laravel` is live, `i18n` is not —
# the real removal this check exists for.
mkroot() {
  rm -rf "$WORK/root"
  mkdir -p "$WORK/root/.claude-plugin" "$WORK/root/plugins/plugin-scout/skills/plugin-scout/references"
  cat > "$WORK/root/.claude-plugin/marketplace.json" <<'EOF'
{"name":"t","plugins":[{"name":"laravel"},{"name":"devops"},{"name":"vercel-skills-scout"}]}
EOF
}

# $1 = one of SKILL.md / signals.md / any-core.md, $2… = body lines
mkfile() {
  local which="$1"; shift
  local dir="$WORK/root/plugins/plugin-scout/skills/plugin-scout"
  case "$which" in
    SKILL.md) printf '%s\n' "$@" > "$dir/SKILL.md" ;;
    *)        printf '%s\n' "$@" > "$dir/references/$which" ;;
  esac
}

expect() { # want-rc  desc
  pc_scout_names "$WORK/root" >/dev/null 2>&1; local got=$?
  [ "$got" = "$1" ] && ok "$2" || bad "$2" "want rc=$1, got rc=$got"
}

printf '== the defect: a dead plugin in each of the three lists\n'
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' \
  '| `locales/`, `lang/`, `*.po`, `i18n` dep | `i18n` | |'
expect 1 "signals.md Suggest column names a removed plugin"

mkroot
mkfile SKILL.md '## Stack signals (tier 1)' '' '| Signal (evidence file) | Plugin |' '|---|---|' \
  '| package.json dep vue | vue3 |'
expect 1 "SKILL.md tier-1 Plugin column names a removed plugin"

mkroot
mkfile any-core.md '| Plugin | Why any project |' '|---|---|' \
  '| packages | dependency hygiene |'
expect 1 "any-core.md Plugin column names a removed plugin"

printf '== the fix: the same row retargeted, and a live name\n'
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' \
  '| `.github/workflows/*.yml` | `devops` | mirrors rules.tsv |'
expect 0 "a live plugin passes"

printf '== the `—` no-plugin idiom (signals.md terraform row) passes\n'
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' \
  '| `*.tf`, `*.tofu`, `.terraform/` | — | **no plugin covers this.** Route to `/vercel-skills-scout:suggest terraform` |'
expect 0 "em dash cell passes"
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' '| `*.tf` | - | none |'
expect 0 "ASCII hyphen cell passes"
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' '| `*.tf` |  | none |'
expect 0 "empty cell passes"

printf '== THE COLUMN, NOT THE LINE\n'
# The reason a line-scoped matcher cannot do this job: the signal column of the
# real i18n row holds `i18n` as a DEPENDENCY NAME. Only the Suggest cell names a plugin.
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' \
  '| `locales/`, `lang/`, `*.po`, `i18n` dep | — | no plugin covers this |'
expect 0 "a dead name in the signal column is not a suggestion"
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' \
  '| `laravel` dep | `i18n` | |'
expect 1 "a live name in the signal column does not rescue a dead Suggest cell"

printf '== backticked cells yield backticked tokens only\n'
# `also `vercel-skills-scout`` must resolve to one name, not to "also" as well.
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' \
  '| any of the above **plus** no tier-1 hit | also `vercel-skills-scout` | say so explicitly |'
expect 0 "prose around a backticked name is ignored"
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' \
  '| x | also `i18n` | |'
expect 1 "prose around a DEAD backticked name still fires"

printf '== a bare cell that is not name-shaped is reported, not silently skipped\n'
mkroot
mkfile any-core.md '| Plugin | Why any project |' '|---|---|' '| laravel (when Livewire) | prose |'
expect 1 "unparsed bare cell fires"
pc_scout_names "$WORK/root" 2>/dev/null | grep -q '^scout-name-unparsed ' \
  && ok "unparsed cell reports the distinct scout-name-unparsed kind" \
  || bad "unparsed cell reports the distinct scout-name-unparsed kind" "wrong output prefix"

printf '== the blessing\n'
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' \
  '| `lang/` | `i18n` | <!-- scout-name-ok: illustrating a removal -->'
expect 0 "a blessed line is skipped"
mkroot
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' \
  '| `lang/` | `i18n` | <!-- scout-name-ok: one -->' \
  '| `locales/` | `vue3` | |'
expect 1 "a blessed line does not bless a later unblessed one"

printf '== scope: only tables with a Plugin/Suggest header cell\n'
mkroot
mkfile any-core.md '## Deliberate exclusions' '' '- `i18n` — removed from the marketplace' '' \
  '| Plugin | Why |' '|---|---|' '| laravel | live |'
expect 0 "a dead name in prose outside the table is out of scope (declared residual)"
mkroot
mkfile any-core.md '| Skill | Note |' '|---|---|' '| i18n | not a Plugin column |'
expect 0 "a table without a Plugin/Suggest header is not read"

printf '== each table resolves its own header (SKILL.md holds two)\n'
mkroot
mkfile SKILL.md '| Signal (evidence file) | Plugin |' '|---|---|' '| composer.json | laravel |' '' \
  'Some prose between the tables.' '' \
  '| # | Plugin | Tier | Evidence | Installed |' '|---|---|---|---|---|' \
  '| 1 | laravel | 1 | composer.json: laravel/framework ^11 | — |'
expect 0 "a second table at a different column index parses at ITS index"
mkroot
mkfile SKILL.md '| Signal (evidence file) | Plugin |' '|---|---|' '| composer.json | laravel |' '' \
  'Some prose between the tables.' '' \
  '| # | Plugin | Tier | Evidence | Installed |' '|---|---|---|---|---|' \
  '| 1 | i18n | 1 | composer.json: fake | — |'
expect 1 "the example Report table is covered too (declared residual 3)"

printf '== preconditions: absent inputs are silence, not a failure\n'
mkroot
rm -f "$WORK/root/.claude-plugin/marketplace.json"
mkfile signals.md '| Signal | Suggest | Note |' '|---|---|---|' '| x | `i18n` | |'
expect 0 "no marketplace.json: cannot know the live set, so nothing is claimed"
mkroot
expect 0 "no plugin-scout files: nothing to read"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
