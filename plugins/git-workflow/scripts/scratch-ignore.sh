#!/usr/bin/env bash
# scratch-ignore.sh — keep plugin scratch out of a branch.
#
# WHAT IT CATCHES. Every plugin of this marketplace that writes into a user's
# project is listed, with the file that writes it, in
# skills/branch-completion/references/marketplace-scratch.tsv. For the current git
# repo this prints one row per pattern — on disk? ignored? tracked files? kind —
# and, with --check (the default), exits 1 when a `scratch` or `cleaned` path
# exists on disk and is neither ignored nor tracked: the untracked mockup dir,
# preview server state or scratch entry that would otherwise ride into a commit
# as `??` noise, or worse, get `git add -A`'d. /git-workflow:finish runs this
# before its verification gate. --apply writes ONE managed block into .gitignore
# (between the >>> / <<< markers below), rewriting it in place on every run so it
# never duplicates, holding every scratch/cleaned pattern in the inventory — all
# of them, not only those on disk, because a pattern that is not there yet is
# exactly the one the next command creates, and an ignore rule for an absent
# path costs nothing. `state` rows (brain/, design-system/, research/, …) are
# printed as "left to you" and never written: a team may want them tracked.
#
# WHAT IT DOES NOT CATCH. A path already TRACKED is never added to the block —
# ignoring a tracked path is a trap (git keeps tracking it, the rule looks like
# it works) — it is warned about instead. A plugin that starts writing a new
# directory without adding its row is invisible here: the inventory is a
# recorded list, nothing proves it complete. Nothing outside a git repo is
# touched (one line, exit 0).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TSV="${HERE}/../skills/branch-completion/references/marketplace-scratch.tsv"
OPEN='# >>> cc-plugins-marketplace scratch (managed by git-workflow scratch-ignore.sh) >>>'
CLOSE='# <<< cc-plugins-marketplace scratch <<<'

mode=check; root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) mode=check ;;
    --apply) mode=apply ;;
    --root) root="${2:-}"; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "scratch-ignore.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

[ -f "$TSV" ] || { echo "scratch-ignore.sh: inventory missing at $TSV" >&2; exit 2; }
[ -n "$root" ] && cd "$root"
if ! top="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "scratch-ignore: not a git repository — nothing to ignore"; exit 0
fi
cd "$top"

need=(); tracked_warn=(); rows=()
while IFS=$'\t' read -r pattern plugin kind why; do
  case "$pattern" in ''|'#'*) continue ;; esac
  probe="$pattern"; [ "${pattern%/}" != "$pattern" ] && probe="${pattern}.scratch-ignore-probe"
  present=no; [ -e "$pattern" ] && present=yes
  ignored=no; git check-ignore -q "$probe" 2>/dev/null && ignored=yes
  tracked="$(git ls-files -- "$pattern" 2>/dev/null | head -1)"
  has_tracked=no; [ -n "$tracked" ] && has_tracked=yes
  verdict="ok"
  case "$kind" in
    state) verdict="left to you" ;;
    scratch|cleaned)
      if [ "$has_tracked" = yes ]; then verdict="TRACKED — not touched"; tracked_warn+=("$pattern")
      elif [ "$present" = yes ] && [ "$ignored" = no ]; then verdict="NEEDS IGNORE"; need+=("$pattern")
      elif [ "$ignored" = yes ]; then verdict="ignored"
      else verdict="absent"; fi ;;
  esac
  rows+=("$(printf '%-34s %-8s on-disk=%-3s ignored=%-3s tracked=%-3s %s' "$pattern" "$kind" "$present" "$ignored" "$has_tracked" "$verdict")")
done < "$TSV"

printf '%s\n' "${rows[@]}"

if [ "$mode" = check ]; then
  if [ ${#need[@]} -gt 0 ]; then
    printf 'scratch-ignore: %d plugin scratch path(s) on disk and unignored: %s — run with --apply\n' "${#need[@]}" "${need[*]}"
    exit 1
  fi
  echo "scratch-ignore: clean"; exit 0
fi

# --apply: rebuild the managed block from every scratch/cleaned row, skipping tracked ones
block="$OPEN"$'\n'
while IFS=$'\t' read -r pattern plugin kind why; do
  case "$pattern" in ''|'#'*) continue ;; esac
  case "$kind" in scratch|cleaned) ;; *) continue ;; esac
  skip=no; for t in "${tracked_warn[@]:-}"; do [ "$t" = "$pattern" ] && skip=yes; done
  [ "$skip" = yes ] && continue
  block+="${pattern}"$'\n'
done < "$TSV"
block+="$CLOSE"

gi=".gitignore"; tmp="$(mktemp)"; blockfile="$(mktemp)"; printf '%s\n' "$block" > "$blockfile"
if [ -f "$gi" ] && grep -qF "$OPEN" "$gi"; then
  # macOS awk refuses a -v string holding newlines, so the block comes from a file
  awk -v startmark="$OPEN" -v endmark="$CLOSE" -v blockfile="$blockfile" '
    $0 == startmark { while ((getline line < blockfile) > 0) print line; skipping = 1; next }
    $0 == endmark { skipping = 0; next }
    !skipping { print }
  ' "$gi" > "$tmp"
else
  { [ -f "$gi" ] && cat "$gi"; [ -f "$gi" ] && [ -s "$gi" ] && [ "$(tail -c1 "$gi" | wc -l)" -eq 0 ] && echo; printf '%s\n' "$block"; } > "$tmp"
fi
mv "$tmp" "$gi"; rm -f "$blockfile"
for t in "${tracked_warn[@]:-}"; do [ -n "$t" ] && echo "scratch-ignore: WARN $t has tracked files — left out of the block; untrack it first if it is scratch (git rm -r --cached)"; done
echo "scratch-ignore: managed block written to .gitignore"
