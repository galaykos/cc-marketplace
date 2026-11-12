#!/usr/bin/env bash
# merge-when-green.sh --pr <n> [--repo owner/name] [--method merge|squash|rebase] [--timeout <s>] [--interval <s>] [--grace <s>] [--dry-run] — waits for a PR's checks, then merges the commit it saw green (`--match-head-commit`). Never `--auto`, never deletes the branch.
# Exit 0 merged (or would, --dry-run), 1 a check failed or was cancelled, 2 usage, 3 gh or jq missing, 4 five lookups failed in a row or the PR is not open, 5 no check reported within --grace, 6 --timeout passed, 7 gh refused the merge.
# Misses: a required status the PR's check rollup does not list, a review requirement (gh refuses, exit 7), a check that starts after every listed one passed.
# Why, limits, history: rationale/derivations/plugin-git-workflow.md § plugins/git-workflow/scripts/merge-when-green.sh
set -uo pipefail
PROG=merge-when-green

die() { printf '%s: %s\n' "$PROG" "$2" >&2; exit "$1"; }
usage() { die 2 "usage error: $1 (usage: merge-when-green.sh --pr <n> [--repo owner/name] [--method merge|squash|rebase] [--timeout <s>] [--interval <s>] [--grace <s>] [--dry-run])"; }
num() { case "$2" in '' | *[!0-9]*) usage "$1 takes whole seconds, got '$2'" ;; esac; }

pr="" repo="" method=merge timeout=2700 interval=20 grace=180 dry=false
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help) sed -n '2,4p' "$0"; exit 0 ;;
    --pr | --repo | --method | --timeout | --interval | --grace)
      [ $# -ge 2 ] || usage "$1 needs a value"
      case "$1" in --pr) pr=$2 ;; --repo) repo=$2 ;; --method) method=$2 ;; --timeout) timeout=$2 ;; --interval) interval=$2 ;; --grace) grace=$2 ;; esac
      shift 2 ;;
    --dry-run) dry=true; shift ;;
    *) usage "unknown argument: $1" ;;
  esac
done
pr=${pr#\#}
case "$pr" in '' | *[!0-9]* | 0*) usage "--pr takes a pull request number, got '$pr'" ;; esac
case "$method" in merge | squash | rebase) ;; *) usage "--method takes merge, squash or rebase, got '$method'" ;; esac
num --timeout "$timeout"; num --interval "$interval"; num --grace "$grace"
if [ -n "$repo" ] && ! printf '%s' "$repo" | grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
  usage "--repo takes owner/name, got '$repo'"
fi
command -v gh >/dev/null 2>&1 || die 3 "gh is not installed"
command -v jq >/dev/null 2>&1 || die 3 "jq is not installed"
R=(); [ -n "$repo" ] && R=(-R "$repo")

start=$SECONDS misses=0 sha=""
while :; do
  elapsed=$((SECONDS - start))
  [ "$elapsed" -le "$timeout" ] || die 6 "PR #$pr still has pending checks after ${timeout}s; nothing was merged"
  # One call for state, head and checks, so the verdict belongs to the head it names. (`gh pr checks --json` needs gh 2.50; this runs on 2.46.)
  view=$(gh pr view "$pr" "${R[@]}" --json state,headRefOid,statusCheckRollup 2>/dev/null) && state=$(jq -r '.state // empty' <<<"$view" 2>/dev/null) && [ -n "$state" ] || {
    misses=$((misses + 1)); [ "$misses" -lt 5 ] || die 4 "could not read PR #$pr five times in a row; nothing was merged"
    sleep "$interval"; continue
  }
  misses=0
  [ "$state" = OPEN ] || die 4 "PR #$pr is $state, not open; nothing was merged"
  sha=$(jq -r '.headRefOid // empty' <<<"$view")
  # A CheckRun carries status + conclusion; a StatusContext carries context + state.
  checks=$(jq -c '[(.statusCheckRollup // [])[] | {name: (.name // .context // "?"), v: (
      if (.__typename // "") == "StatusContext" then
        (if .state == "SUCCESS" then "pass" elif .state == "PENDING" or .state == "EXPECTED" then "pending" else "fail" end)
      elif (.status // "") != "COMPLETED" then "pending"
      elif .conclusion == "SUCCESS" or .conclusion == "SKIPPED" or .conclusion == "NEUTRAL" then "pass"
      else "fail" end)}]' <<<"$view")
  total=$(jq 'length' <<<"$checks")
  if [ "$total" -eq 0 ]; then
    [ "$elapsed" -le "$grace" ] || die 5 "PR #$pr reported no checks within ${grace}s; nothing was merged (a repo with no CI needs a plain gh pr merge)"
    sleep "$interval"; continue
  fi
  red=$(jq -r '[.[] | select(.v == "fail") | .name] | join(", ")' <<<"$checks")
  [ -z "$red" ] || die 1 "PR #$pr is red: $red; nothing was merged"
  [ "$(jq '[.[] | select(.v == "pending")] | length' <<<"$checks")" -eq 0 ] && break
  sleep "$interval"
done

if [ "$dry" = true ]; then
  printf '%s: PR #%s is green at %s (%s checks); --dry-run, not merged\n' "$PROG" "$pr" "${sha:0:12}" "$total"; exit 0
fi
out=$(gh pr merge "$pr" "${R[@]}" "--$method" --match-head-commit "$sha" 2>&1) || die 7 "gh refused to merge PR #$pr at ${sha:0:12}: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-300)"
printf '%s: merged PR #%s at %s (%s, %s checks green)\n' "$PROG" "$pr" "${sha:0:12}" "$method" "$total"
