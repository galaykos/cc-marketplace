#!/usr/bin/env bash
# skill-vet.sh SOURCE SKILL — run before a picked third-party skill installs. SOURCE is owner/repo or an existing absolute directory, anything else is not scanned; SKILL is the skills.sh skillId. With `skillspector` on PATH: a shallow clone with symlinks checked out as plain files, the skill folder found (`skills/SKILL/`, `SKILL/`, `*/SKILL/` at any depth, then a SKILL.md whose frontmatter name is SKILL), SkillSpector's static scan (--no-llm) of it, its verdict and up to five findings. Without it: one line offering it. Exits 0 on every path past the usage check, so it never holds an install back.
# Misses: SkillSpector's LLM stage (never run here; dependency names still go to OSV.dev); a skill whose folder or SKILL.md is a symlink (reported, not scanned) or whose name is in no folder name and no frontmatter; whatever SkillSpector itself misses. Never installs SkillSpector.
set -u

SOURCE="${1:-}"
SKILL="${2:-}"
if [ "$#" -ne 2 ] || [ -z "$SOURCE" ] || ! [[ "$SKILL" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  echo "usage: skill-vet.sh SOURCE SKILL (SOURCE: owner/repo or an existing absolute directory; SKILL: the skills.sh skillId)" >&2
  exit 1
fi

if ! command -v skillspector >/dev/null 2>&1; then
  echo "SkillSpector is not installed, so $SKILL was not scanned. NVIDIA's scanner checks a skill for prompt injection, data theft and malicious code before install: uv tool install git+https://github.com/NVIDIA/skillspector.git (Apache-2.0). Offered only; nothing runs without your yes."
  exit 0
fi

not_run() {
  echo "SkillSpector did not scan $SKILL: $1. The install still waits on your yes."
  exit 0
}

limited() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@"; else "$@"; fi
}

command -v git >/dev/null 2>&1 || not_run "git is not installed, so the skill could not be fetched"
command -v jq >/dev/null 2>&1 || not_run "jq is not installed, so the report could not be read"

fm_name() {
  awk '{ sub(/\r$/, "") }
       NR == 1 { if ($0 != "---") exit; next }
       $0 == "---" { exit }
       /^name:/ { v = $0; sub(/^name:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v); gsub(/^["\047]|["\047]$/, "", v); print v; exit }' "$1"
}

shortest() {
  awk '{ print length($0) "\t" $0 }' | sort -n | head -1 | cut -f2-
}

if [[ "$SOURCE" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*/[A-Za-z0-9_.-]+$ ]]; then
  url="https://github.com/$SOURCE.git"
elif [[ "$SOURCE" == /* ]] && [ -d "$SOURCE" ]; then
  url="$SOURCE"
else
  not_run "$SOURCE is neither owner/repo nor an existing absolute directory"
fi

tmp=$(mktemp -d) || not_run "no scratch directory"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"

GIT_TERMINAL_PROMPT=0 limited 120 git clone -c core.symlinks=false --depth 1 --quiet -- "$url" "$repo" 2>"$tmp/git.err" \
  || not_run "git clone of $url failed ($(head -1 "$tmp/git.err"))"

link=$(git -C "$repo" ls-files -s | awk -F'\t' -v s="$SKILL" 'substr($1, 1, 6) == "120000" {
  n = split($2, a, "/"); if (a[n] == s || (n > 1 && a[n] == "SKILL.md" && a[n - 1] == s)) { print $2; exit } }')
[ -z "$link" ] || not_run "$link is a symlink, so what would install was not scanned"

dir=""
for cand in "$repo/skills/$SKILL" "$repo/$SKILL"; do
  if [ -f "$cand/SKILL.md" ]; then dir="$cand"; break; fi
done
if [ -z "$dir" ]; then
  hit=$(find "$repo" -name .git -prune -o -type f -path "*/$SKILL/SKILL.md" -print | shortest)
  if [ -z "$hit" ]; then
    hit=$(find "$repo" -name .git -prune -o -type f -name SKILL.md -print | while IFS= read -r f; do
      [ "$(fm_name "$f")" = "$SKILL" ] && printf '%s\n' "$f"
    done | shortest)
  fi
  [ -z "$hit" ] || dir=$(dirname "$hit")
fi
[ -n "$dir" ] || not_run "$SOURCE has no $SKILL/SKILL.md and no SKILL.md named $SKILL"

limited 300 skillspector scan "$dir" --no-llm --format json >"$tmp/report.json" 2>"$tmp/scan.err"
rc=$?
# Exit 1 is a completed scan that scored over 50, so the report is read whatever the status.
jq -e '.risk_assessment.recommendation | strings' "$tmp/report.json" >/dev/null 2>&1 \
  || not_run "skillspector exited $rc without a readable report ($(head -1 "$tmp/scan.err"))"

jq -r --arg skill "$SKILL" --arg rel "${dir#"$repo/"}" '
  def rank: {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}[.severity] // 4;
  (.issues // []) as $issues
  | "SkillSpector verdict for \($skill) (\($rel)/): \(.risk_assessment.recommendation), score \(.risk_assessment.score)/100 (\(.risk_assessment.severity)), \($issues | length) finding(s), static scan (--no-llm).",
    ($issues | sort_by(rank) | .[:5][] | "  \(.severity) \(.id) \(.category // "-") \(.location.file // "?"):\(.location.start_line // "?")"),
    (if ($issues | length) > 5 then "  ... and \(($issues | length) - 5) more" else empty end)
' "$tmp/report.json"
exit 0
