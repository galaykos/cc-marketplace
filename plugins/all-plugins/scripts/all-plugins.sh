#!/usr/bin/env bash
# all-plugins.sh — install every LEAF plugin of this marketplace at one scope with
# zero prompts, uninstall them again, or list their state. A mechanism, not prose:
# the exit code is the contract. 0 = done (including nothing to do); 1 = at least
# one per-plugin command failed — the list is still walked to the end and every
# failure is reported; 2 = usage error or a missing prerequisite.
#
# Usage: all-plugins.sh <install|uninstall|list> [--scope local|project|user]
#                       [--dry-run] [--self] [--no-budget] [--marketplace NAME]
#
# The listing budget is part of the job. Claude Code caps the skill+command listing
# it sends the model at contextWindowTokens x bytesPerToken x skillListingBudgetFraction
# (default 0.01 — 6,000 chars at 200k on a 3-byte model) and past it drops entries to
# name-only. Every leaf here costs several times that, so `install` computes the
# listing cost the way scripts/lib/plugin-checks.sh's pc_listing_entry_cost does
# (name + 4 + min(desc,1536) per skill/command), and raises skillListingBudgetFraction
# in the SCOPE's settings file to the smallest 0.01 step that covers it at the 200k
# floor — a cap, not a fill, so a 1M window pays nothing extra. `uninstall` removes
# the key again, but only when it still holds the value this script would set; any
# other value is somebody's and is left alone. --no-budget skips both.
#
# What it does NOT do: never touches another marketplace; never installs a bundle
# (a plugin.json with `dependencies` — the rule scripts/validate.sh applies); never
# prompts — this marketplace declares no install commands, so nothing asks and `-y`
# is never passed; does not reload the session (the hint names /reload-plugins).
#
# Whether an overflowed listing changes what fires was measured once at zero delta,
# n=50 (rationale/2026-09-15-listing-eviction-probe.md); the budget step exists
# because sending every description is the only way to make the question moot.
#
# Discovery is never a hardcoded list: `claude plugin marketplace list --json`
# locates the clone, its marketplace.json names the plugins, and `claude plugin
# list --json` says what is installed WHERE — the same id appears once per project
# at local/project scope, so an entry only counts when its projectPath is this one.
#
# Standing: mechanism — exit code is the contract; nothing in CI runs it against a
# live CLI, the harness (scripts/__tests__/all-plugins.test.sh) drives a shim.
set -u

SELF_NAME="all-plugins"
MARKETPLACE="cc-plugins-marketplace"
SCOPE="local"
DRY=0
SELF=0
BUDGET=1
FLOOR_TOKENS=200000   # the default window; the fraction is a cap, so 1M costs no more
FLOOR_BYTES_PER_TOKEN=3   # the newer tokenizer set; 4-byte models need a smaller fraction
BUDGET_KEY=skillListingBudgetFraction
CMD=""
LEAVES=""
STATES=""
WIDTH=0
REASON=""
ROOT=""

usage() {
  printf 'usage: all-plugins.sh <install|uninstall|list> [--scope local|project|user] [--dry-run] [--self] [--no-budget] [--marketplace NAME]\n'
}

die() { # die <rc> <message> — every error names its fix and goes to stderr
  local rc="$1"; shift
  printf 'all-plugins: %s\n' "$*" >&2
  exit "$rc"
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      install|uninstall|list)
        [ -z "$CMD" ] || { usage >&2; die 2 "one subcommand only — got '$CMD' and '$1'"; }
        CMD="$1" ;;
      --scope)
        [ $# -ge 2 ] || { usage >&2; die 2 "--scope needs a value: local, project or user"; }
        SCOPE="$2"; shift ;;
      --scope=*) SCOPE="${1#--scope=}" ;;
      --marketplace)
        [ $# -ge 2 ] || { usage >&2; die 2 "--marketplace needs a name"; }
        MARKETPLACE="$2"; shift ;;
      --marketplace=*) MARKETPLACE="${1#--marketplace=}" ;;
      --dry-run) DRY=1 ;;
      --self) SELF=1 ;;
      --no-budget) BUDGET=0 ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die 2 "unknown argument '$1'" ;;
    esac
    shift
  done
  [ -n "$CMD" ] || { usage >&2; die 2 "missing subcommand — one of install, uninstall, list"; }
  case "$SCOPE" in
    local|project|user) ;;
    *) die 2 "bad scope '$SCOPE' — use --scope local, project or user" ;;
  esac
}

check_prereqs() {
  command -v claude >/dev/null 2>&1 \
    || die 2 "'claude' is not on PATH — install Claude Code, or open a shell where 'claude --version' works"
  command -v jq >/dev/null 2>&1 \
    || die 2 "'jq' is not on PATH — install it (brew install jq / apt install jq)"
}

# The repo behind the default marketplace is known; any other name gets the shape.
add_hint() {
  case "$MARKETPLACE" in
    cc-plugins-marketplace) printf 'claude plugin marketplace add galaykos/cc-marketplace' ;;
    *) printf 'claude plugin marketplace add <owner/repo of %s>' "$MARKETPLACE" ;;
  esac
}

marketplace_root() { # stdout: the marketplace clone dir
  local json loc
  json=$(claude plugin marketplace list --json 2>/dev/null </dev/null) \
    || die 2 "'claude plugin marketplace list --json' failed — run it by hand to see why"
  printf '%s' "$json" | jq -e 'type == "array"' >/dev/null 2>&1 \
    || die 2 "'claude plugin marketplace list --json' did not return a JSON array — run it by hand to see why"
  loc=$(printf '%s' "$json" | jq -r --arg n "$MARKETPLACE" '.[] | select(.name == $n) | .installLocation // empty' | head -n 1)
  [ -n "$loc" ] || die 2 "marketplace '$MARKETPLACE' is not registered — fix: $(add_hint)"
  [ -d "$loc" ] || die 2 "marketplace '$MARKETPLACE' points at a missing dir $loc — fix: claude plugin marketplace update $MARKETPLACE"
  printf '%s' "$loc"
}

leaves() { # leaves <root> — stdout: one leaf name per line, sorted
  local root="$1" mj name src
  mj="$root/.claude-plugin/marketplace.json"
  [ -r "$mj" ] || die 2 "cannot read $mj — fix: claude plugin marketplace update $MARKETPLACE"
  jq -e '.plugins | type == "array"' "$mj" >/dev/null 2>&1 \
    || die 2 "$mj has no .plugins array — fix: claude plugin marketplace update $MARKETPLACE"
  jq -r '.plugins[] | "\(.name)\t\(.source | if type == "string" then . else "" end)"' "$mj" \
  | while IFS=$'\t' read -r name src; do
      # A non-path source cannot be inspected, so it is in scope; a bundle is not.
      [ -n "$src" ] && jq -e 'has("dependencies")' "$root/$src/.claude-plugin/plugin.json" >/dev/null 2>&1 && continue
      printf '%s\n' "$name"
    done | LC_ALL=C sort
}

installed_states() { # stdout: "<name>\t<installed|disabled>" for every leaf installed at SCOPE here
  local json top phys
  json=$(claude plugin list --json 2>/dev/null </dev/null) \
    || die 2 "'claude plugin list --json' failed — run it by hand to see why"
  [ -n "$json" ] || json='[]'
  printf '%s' "$json" | jq -e 'type == "array"' >/dev/null 2>&1 \
    || die 2 "'claude plugin list --json' did not return a JSON array — run it by hand to see why"
  top=$(git rev-parse --show-toplevel 2>/dev/null || true)
  phys=$(pwd -P)
  printf '%s' "$json" | jq -r --arg mk "$MARKETPLACE" --arg scope "$SCOPE" \
      --arg pwd "$PWD" --arg phys "$phys" --arg top "$top" '
    map(select(.scope == $scope and (.id | endswith("@" + $mk))))
    | map(select($scope == "user"
                 or ((.projectPath // "") as $p
                     | $p == $pwd or $p == $phys or ($top != "" and $p == $top))))
    | group_by(.id)
    | map({name: (.[0].id | split("@")[0]), on: any(.[]; .enabled == true)})
    | .[] | "\(.name)\t\(if .on then "installed" else "disabled" end)"'
}

state_of() { # state_of <name> — installed | disabled | absent
  local s
  s=$(printf '%s\n' "$STATES" | awk -F'\t' -v n="$1" '$1 == n { print $2; exit }')
  printf '%s' "${s:-absent}"
}

name_width() {
  printf '%s\n' "$LEAVES" | awk '{ if (length($0) > w) w = length($0) } END { print w + 0 }'
}

row() { # row <verb> <name> <status>
  printf '%-9s  %-*s  %s\n' "$1" "$WIDTH" "$2" "$3"
}

# run_cli <verb> <name> — `claude plugin <verb> <name>@MARKETPLACE -s SCOPE`, or the
# DRY line under --dry-run. On failure REASON holds the first stderr line. stdin is
# /dev/null so a prompt, should the host ever grow one here, fails instead of hanging.
run_cli() {
  local verb="$1" name="$2" err rc
  if [ "$DRY" -eq 1 ]; then
    printf 'DRY  claude plugin %s %s@%s -s %s\n' "$verb" "$name" "$MARKETPLACE" "$SCOPE"
    return 0
  fi
  err=$( { claude plugin "$verb" "$name@$MARKETPLACE" -s "$SCOPE" </dev/null >/dev/null; } 2>&1 ); rc=$?
  REASON=$(printf '%s\n' "$err" | awk 'NF { print; exit }')
  [ -n "$REASON" ] || REASON="exit $rc"
  return "$rc"
}

report_failures() { # report_failures <count> <lines>
  [ "$1" -gt 0 ] || return 0
  printf 'all-plugins: %s failed —\n%s' "$1" "$2" >&2
  return 1
}

settings_file() { # stdout: the settings file the CLI writes for SCOPE — measured: local and
  local top          # project land at the git toplevel even when installing from a subdir
  case "$SCOPE" in
    user) printf '%s/.claude/settings.json' "$HOME" ;;
    *) top=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
       if [ "$SCOPE" = local ]; then printf '%s/.claude/settings.local.json' "$top"; else printf '%s/.claude/settings.json' "$top"; fi ;;
  esac
}

listing_cost() { # listing_cost <root> — stdout: entry chars of every leaf, pc_listing_entry_cost's rule
  local root="$1" mj name src pdir f desc dl total=0
  mj="$root/.claude-plugin/marketplace.json"
  while read -r name; do
    src=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .source | if type == "string" then . else "" end' "$mj" | head -n 1)
    [ -n "$src" ] || continue
    pdir="$root/$src"
    for f in "$pdir"/skills/*/SKILL.md "$pdir"/commands/*.md; do
      [ -f "$f" ] || continue
      case "$f" in
        */skills/*) name="$(basename "$pdir"):$(basename "$(dirname "$f")")" ;;
        *)          name="$(basename "$pdir"):$(basename "$f" .md)" ;;
      esac
      desc=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f" 2>/dev/null | sed -n 's/^description:[[:space:]]*//p' | head -1)
      dl=$(printf '%s' "$desc" | LC_ALL=C wc -c | tr -d ' ')
      [ "$dl" -gt 1536 ] && dl=1536
      total=$(( total + ${#name} + 4 + dl ))
    done
  done <<<"$LEAVES"
  printf '%s' "$total"
}

needed_fraction() { # needed_fraction <chars> — smallest 0.01 step covering chars x 1.05 at the floor
  awk -v c="$1" -v t="$FLOOR_TOKENS" -v b="$FLOOR_BYTES_PER_TOKEN" 'BEGIN {
    f = (c * 1.05) / (t * b); s = int(f * 100); if (s / 100 < f) s++; if (s < 1) s = 1;
    printf "%.2f", s / 100 }'
}

current_fraction() { # current_fraction <file> — the key's value, or the CLI default when absent
  [ -f "$1" ] || { printf '0.01'; return; }
  jq -r --arg k "$BUDGET_KEY" 'if type == "object" and has($k) then .[$k] else 0.01 end' "$1" 2>/dev/null || printf 'invalid'
}

write_settings() { # write_settings <file> <jq filter> — atomic, creates the file and dir
  local file="$1" filter="$2" tmp
  mkdir -p "$(dirname "$file")" || return 1
  tmp="$file.all-plugins.$$"
  if [ -f "$file" ]; then
    jq --arg k "$BUDGET_KEY" "$filter" "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
  else
    jq -n --arg k "$BUDGET_KEY" "$filter" > "$tmp" || { rm -f "$tmp"; return 1; }
  fi
  mv "$tmp" "$file"
}

budget_raise() { # after install: make the scope's settings cover the whole listing
  local root="$1" file cost need cur tokens
  [ "$BUDGET" -eq 1 ] || return 0
  file=$(settings_file); cost=$(listing_cost "$root"); need=$(needed_fraction "$cost")
  cur=$(current_fraction "$file")
  tokens=$(( cost / FLOOR_BYTES_PER_TOKEN ))
  if [ "$cur" = invalid ]; then
    printf 'all-plugins: %s is not valid JSON — %s left untouched; set it to %s by hand\n' "$file" "$BUDGET_KEY" "$need" >&2; return 0
  fi
  if awk -v a="$cur" -v b="$need" 'BEGIN { exit !(a + 0 >= b + 0) }'; then
    printf '%s %s in %s already covers the %s-char listing\n' "$BUDGET_KEY" "$cur" "$file" "$cost"; return 0
  fi
  if [ "$DRY" -eq 1 ]; then
    printf 'DRY  set %s %s -> %s in %s (listing %s chars; default budget at 200k is %s)\n' "$BUDGET_KEY" "$cur" "$need" "$file" "$cost" $((FLOOR_TOKENS * FLOOR_BYTES_PER_TOKEN / 100)); return 0
  fi
  if write_settings "$file" ". + {(\$k): $need}"; then
    printf '%s %s -> %s in %s: the listing is %s chars against a %s-char default budget at 200k; every description is now sent, about %s system-prompt tokens per turn\n' \
      "$BUDGET_KEY" "$cur" "$need" "$file" "$cost" $((FLOOR_TOKENS * FLOOR_BYTES_PER_TOKEN / 100)) "$tokens"
  else
    printf 'all-plugins: could not write %s — set %s to %s by hand\n' "$file" "$BUDGET_KEY" "$need" >&2
  fi
}

budget_revert() { # after uninstall: drop the key only if it still holds the value install sets
  local root="$1" file cost need cur
  [ "$BUDGET" -eq 1 ] || return 0
  file=$(settings_file)
  [ -f "$file" ] && jq -e --arg k "$BUDGET_KEY" 'type == "object" and has($k)' "$file" >/dev/null 2>&1 || return 0
  cost=$(listing_cost "$root"); need=$(needed_fraction "$cost"); cur=$(current_fraction "$file")
  if ! awk -v a="$cur" -v b="$need" 'BEGIN { exit !(a + 0 == b + 0) }'; then
    printf '%s %s in %s left alone — not the value this script sets (%s)\n' "$BUDGET_KEY" "$cur" "$file" "$need"; return 0
  fi
  if [ "$DRY" -eq 1 ]; then printf 'DRY  remove %s %s from %s\n' "$BUDGET_KEY" "$cur" "$file"; return 0; fi
  if write_settings "$file" "del(.[\$k])"; then
    printf '%s %s removed from %s\n' "$BUDGET_KEY" "$cur" "$file"
  else
    printf 'all-plugins: could not write %s — remove %s by hand\n' "$file" "$BUDGET_KEY" >&2
  fi
}

do_install() {
  local name st n_inst=0 n_en=0 n_skip=0 n_fail=0 total=0 failures="" verb done_as
  while read -r name; do
    total=$((total + 1))
    st=$(state_of "$name")
    case "$st" in
      installed) row install "$name" "skip (installed)"; n_skip=$((n_skip + 1)); continue ;;
      disabled)  verb=enable ;;
      *)         verb=install ;;
    esac
    if run_cli "$verb" "$name"; then
      if [ "$verb" = enable ]; then n_en=$((n_en + 1)); done_as=enabled; else n_inst=$((n_inst + 1)); done_as=ok; fi
      [ "$DRY" -eq 1 ] || row install "$name" "$done_as"
    else
      n_fail=$((n_fail + 1)); row install "$name" "FAIL ($REASON)"
      failures="$failures  $name: $REASON"$'\n'
    fi
  done <<<"$LEAVES"
  if [ "$DRY" -eq 1 ]; then
    printf 'dry-run: would install %s, enable %s, skip %s of %s leaves at scope %s\n' "$n_inst" "$n_en" "$n_skip" "$total" "$SCOPE"
    budget_raise "$ROOT"
    return 0
  fi
  printf 'installed %s, enabled %s, skipped %s, failed %s of %s leaves at scope %s\n' "$n_inst" "$n_en" "$n_skip" "$n_fail" "$total" "$SCOPE"
  # Something from this marketplace is at this scope now (or was already): cover its listing.
  [ $((n_inst + n_en + n_skip)) -eq 0 ] || budget_raise "$ROOT"
  [ $((n_inst + n_en)) -eq 0 ] || printf 'Run /reload-plugins — nothing installed this run is active until you do.\n'
  report_failures "$n_fail" "$failures"
}

do_uninstall() {
  local name st order n_un=0 n_skip=0 n_fail=0 total=0 failures="" self_here=0
  # The plugin holding this script goes LAST, and only on request — see main's tail.
  order=$(printf '%s\n' "$LEAVES" | grep -vx "$SELF_NAME")
  if printf '%s\n' "$LEAVES" | grep -qx "$SELF_NAME"; then
    self_here=1
    [ "$SELF" -eq 0 ] || order="$order"$'\n'"$SELF_NAME"
  fi
  while read -r name; do
    [ -n "$name" ] || continue
    total=$((total + 1))
    st=$(state_of "$name")
    if [ "$st" = absent ]; then
      row uninstall "$name" "skip (not installed)"; n_skip=$((n_skip + 1)); continue
    fi
    if run_cli uninstall "$name"; then
      n_un=$((n_un + 1)); [ "$DRY" -eq 1 ] || row uninstall "$name" ok
    else
      n_fail=$((n_fail + 1)); row uninstall "$name" "FAIL ($REASON)"
      failures="$failures  $name: $REASON"$'\n'
    fi
  done <<<"$order"
  if [ "$DRY" -eq 1 ]; then
    printf 'dry-run: would uninstall %s, skip %s of %s leaves at scope %s\n' "$n_un" "$n_skip" "$total" "$SCOPE"
  else
    printf 'uninstalled %s, skipped %s, failed %s of %s leaves at scope %s\n' "$n_un" "$n_skip" "$n_fail" "$total" "$SCOPE"
  fi
  budget_revert "$ROOT"
  if [ "$SELF" -eq 0 ] && [ "$self_here" -eq 1 ] && [ "$(state_of "$SELF_NAME")" != absent ]; then
    printf '%s itself kept; remove it with: claude plugin uninstall %s@%s -s %s\n' "$SELF_NAME" "$SELF_NAME" "$MARKETPLACE" "$SCOPE"
  fi
  [ "$DRY" -eq 1 ] || report_failures "$n_fail" "$failures"
}

do_list() {
  local name st n_on=0 n_off=0 n_abs=0 total=0
  while read -r name; do
    total=$((total + 1))
    st=$(state_of "$name")
    case "$st" in
      installed) n_on=$((n_on + 1)) ;;
      disabled)  n_off=$((n_off + 1)) ;;
      *)         n_abs=$((n_abs + 1)) ;;
    esac
    printf '%-*s  %-9s  (%s)\n' "$WIDTH" "$name" "$st" "$SCOPE"
  done <<<"$LEAVES"
  printf 'installed %s, disabled %s, absent %s of %s leaves at scope %s\n' "$n_on" "$n_off" "$n_abs" "$total" "$SCOPE"
}

main() {
  local root
  parse_args "$@"
  check_prereqs
  root=$(marketplace_root) || exit $?
  ROOT="$root"
  LEAVES=$(leaves "$root") || exit $?
  [ -n "$LEAVES" ] || { printf 'no leaf plugins in marketplace %s — nothing to do\n' "$MARKETPLACE"; exit 0; }
  STATES=$(installed_states) || exit $?
  WIDTH=$(name_width)
  case "$CMD" in
    install)   do_install ;;
    uninstall) do_uninstall ;;
    list)      do_list ;;
  esac
}

# `main` is the last line on purpose: `uninstall --self` removes the plugin whose
# cache dir holds this very file. bash parses a function body in full before running
# it but reads top-level lines as it reaches them, so everything above is a function
# and nothing past this point is ever read from a file that may already be gone.
main "$@"
