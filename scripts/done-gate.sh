#!/usr/bin/env bash
# done-gate.sh — this repo's Stop hook: blocks (exit 2, once per state) a turn ending on changed plugins/ that acknowledged no failure while generate.sh --check, a FAIL-tier per-file check of a changed plugin, or check-version-bumps.sh fails. CRAFT_DONE_GATE=off disables it.
# Misses: cross-plugin and repo-level checks, WARN tiers, validate.sh and context-budget.sh (93 s against the 60 s timeout), a false acknowledgment; it is a slice of CI, so only CLAUDE.md carries CI's step count (two copies drift). Fails open, except pc_removed_refs on a broken removed-plugins.tsv.
# Why, limits, history: rationale/derivations/scripts.md § scripts/done-gate.sh

set -uo pipefail
[ "${CRAFT_DONE_GATE:-on}" = "off" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

payload=$(cat 2>/dev/null || true)

# Never re-enter within a turn.
if printf '%s' "$payload" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

# 1. STATE (cheap): which plugins changed? Untracked counts — a SKILL.md written
# this turn is untracked. Docs-only, research and read-only sessions stop here.
changed=()
while IFS= read -r p; do
  case "$p" in plugins/.*) continue ;; esac  # validate.sh's plugins/*/ globs skip dot-dirs too
  [ -d "$p" ] && changed+=("$p")
done < <( { git diff --name-only -z -- plugins
            git diff --cached --name-only -z -- plugins
            git ls-files --others --exclude-standard -z -- plugins; } 2>/dev/null \
          | tr '\0' '\n' | cut -d/ -f1-2 | sort -u )
[ "${#changed[@]}" -eq 0 ] && exit 0

# 2. ACKNOWLEDGMENT, checked before the checks so an honest turn pays nothing; grep -w, since BSD grep has no \b and a bare `red` matches required/registered.
ACK='fail|fails|failing|failed|failure|not green|red gate|in progress|still working|wip|not done|incomplete|halt|halting|halted|blocked|parked|known issue|cannot verify'
tp=$(printf '%s' "$payload" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -n "$tp" ] && [ -r "$tp" ] && command -v jq >/dev/null 2>&1; then
  said=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' \
           "$tp" 2>/dev/null | tail -40)
  # Unreadable/empty transcript → fail open (treat as acknowledged).
  [ -z "$said" ] && exit 0
  printf '%s' "$said" | grep -qiwE "$ACK" && exit 0
else
  exit 0
fi

# 3. CHECKS (only reached by a silent turn on changed plugins).
. scripts/lib/plugin-checks.sh 2>/dev/null || exit 0
findings=""
nl=$'\n'
finding() { findings="${findings:+$findings$nl}$1"; }
each() { # $1 label prefix; one finding per stdin line
  local line
  while IFS= read -r line; do [ -n "$line" ] && finding "$1$line"; done
}

# NOTE: generate.sh is invoked with --check ONLY. Running it bare would REWRITE
# every chassis-generated file as a side effect of a Stop hook.
bash scripts/generate.sh --check >/dev/null 2>&1 || finding "generate.sh --check"

# allow_md, the symlink skip, the jargon exemption and the file set below copy validate.sh (the authority); done-gate-tests.sh asserts only allow_md, so the rest can drift.
allow_md='^(README|CHANGELOG|ROADMAP)\.md$|^skills/[^/]+/SKILL\.md$|^skills/[^/]+/references/.+\.md$|^commands/[^/]+\.md$|^agents/[^/]+\.md$|^evals/.+\.md$'
# These three take a plugins ROOT, not one plugin: run each once, filter by name.
rootwide=$( { pc_hook_shebang plugins; pc_hook_timeout plugins; pc_plugin_dependencies plugins; } 2>/dev/null ) || true
for p in "${changed[@]}"; do
  name=${p#plugins/}
  jq empty "$p/.claude-plugin/plugin.json" 2>/dev/null || finding "plugin-json: $p/.claude-plugin/plugin.json"
  for d in "$p"/skills/*/; do
    [ -d "$d" ] || continue
    each "frontmatter: " < <(pc_frontmatter "${d}SKILL.md")
    [ -L "${d%/}" ] || { bud=$(pc_skill_budget "${d}SKILL.md") || finding "skill-budget: $bud"; }
  done
  for f in "$p"/commands/*.md "$p"/agents/*.md; do
    [ -f "$f" ] && each "frontmatter: " < <(pc_frontmatter "$f")
  done
  while IFS= read -r f; do
    pc_doc_location "$f" "$allow_md" >/dev/null || finding "doc-location: $f"
  done < <(find "$p" -name '*.md' 2>/dev/null)
  while IFS= read -r f; do
    case "$f" in
      plugins/taskmaster/*|plugins/task-runner/*) ;;
      *) hit=$(pc_jargon "$f") || finding "jargon: $f [$hit]" ;;
    esac
    hit=$(pc_removed_refs "$f") || finding "removed-refs: $f [$hit]"
  done < <(
    {
      find "$p" -type f \( -path '*/skills/*/SKILL.md' -o -path '*/skills/*/references/*.md' -o -path '*/commands/*.md' -o -path '*/agents/*.md' \) 2>/dev/null
      printf '%s\n' "$p/README.md" "$p/CHANGELOG.md" "$p/ROADMAP.md"
    } | sort -u
  )
  each "hook-exec: " < <(pc_hook_exec "$p")
  while IFS= read -r line; do
    case "$line" in
      "hook-shebang $name:"*) finding "hook-shebang: $line" ;;
      "hook-timeout $name:"*) finding "hook-timeout: ${line#hook-timeout }" ;;
      "plugin-dependencies $name "*) finding "dependencies: ${line#plugin-dependencies }" ;;
    esac
  done <<<"$rootwide"
done

# check-version-bumps.sh judges COMMITTED history: run it only when some exists against the base that script would pick.
base=""
if   git rev-parse --verify -q origin/master >/dev/null 2>&1; then base=origin/master
elif git rev-parse --verify -q master        >/dev/null 2>&1; then base=master
fi
ran_bumps=0
if [ -n "$base" ] && ! git diff --quiet "$base"...HEAD -- plugins 2>/dev/null; then
  ran_bumps=1
  bash scripts/check-version-bumps.sh "$base" >/dev/null 2>&1 \
    || finding "check-version-bumps.sh $base"
fi

[ -z "$findings" ] && exit 0

# 4. LOOP GUARD: block once per distinct state — stop_hook_active is not trusted alone, and repo state cannot be cleared mid-work.
marker=".claude/done-gate-last"
state=$(printf '%s|%s' "$(git status --porcelain -- plugins 2>/dev/null)" "$findings" \
        | (command -v shasum >/dev/null 2>&1 && shasum | cut -d' ' -f1 || echo "$findings"))
if [ -r "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$state" ]; then
  exit 0
fi
mkdir -p .claude 2>/dev/null && printf '%s' "$state" > "$marker" 2>/dev/null

total=$(printf '%s\n' "$findings" | wc -l | tr -d ' ')
shown=$(printf '%s\n' "$findings" | head -10 | awk 'NR > 1 { printf "; " } { printf "%s", $0 }')
[ "$total" -gt 10 ] && shown="$shown (+$((total - 10)) more)"
ran="generate.sh --check and the per-plugin plugin-json, frontmatter, skill-budget, doc-location, jargon, removed-refs, hook-exec, hook-shebang, hook-timeout and dependencies checks"
[ "$ran_bumps" -eq 1 ] && ran="$ran, check-version-bumps.sh $base"

# jq, not a heredoc: findings carry paths and script lines that may hold a quote.
jq -cn --arg r "This turn is ending with plugin changes and failing checks: $shown — and said nothing about it. Either fix them (ran: $ran; full messages: scripts/validate.sh), or state plainly what is failing and why that is acceptable right now. Silence on a red gate is the one thing this hook exists to stop. CRAFT_DONE_GATE=off disables this gate for the session." \
  '{decision: "block", reason: $r}' >&2 || exit 0
exit 2
