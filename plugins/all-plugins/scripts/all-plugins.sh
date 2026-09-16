#!/usr/bin/env bash
# all-plugins.sh — install every LEAF plugin of this marketplace at one scope with
# zero prompts, uninstall them again, or list their state. A mechanism, not prose:
# the exit code is the contract. 0 = done (including nothing to do); 1 = at least
# one per-plugin command failed — the list is still walked to the end and every
# failure is reported; 2 = usage error or a missing prerequisite.
#
# Usage: all-plugins.sh <install|uninstall|list> [--scope local|project|user]
#                       [--dry-run] [--self] [--marketplace NAME]
#
# What it does NOT do: never touches another marketplace; never installs a bundle
# (a plugin.json with `dependencies` — the rule scripts/validate.sh applies); never
# prompts — this marketplace declares no install commands, so nothing asks and `-y`
# is never passed; does not reload the session (the hint names /reload-plugins).
#
# Cost caveat: with every leaf installed the host's skill listing overflows its
# budget (rationale/2026-08-31-token-cost-review.md) and the overflow goes name-only.
# Whether that changes what fires was measured once at zero delta, n=50
# (rationale/2026-09-15-listing-eviction-probe.md) — the README states both halves.
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
CMD=""
LEAVES=""
STATES=""
WIDTH=0
REASON=""

usage() {
  printf 'usage: all-plugins.sh <install|uninstall|list> [--scope local|project|user] [--dry-run] [--self] [--marketplace NAME]\n'
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
    return 0
  fi
  printf 'installed %s, enabled %s, skipped %s, failed %s of %s leaves at scope %s\n' "$n_inst" "$n_en" "$n_skip" "$n_fail" "$total" "$SCOPE"
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
