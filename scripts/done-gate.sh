#!/usr/bin/env bash
# done-gate — a Stop hook that refuses to let a turn end quietly on a red gate.
#
# WHY: CLAUDE.md is advisory. Across a long session an agent reliably verifies
# the axes it was last burned on and quietly skips the rest. The checks below are
# the fast per-plugin slice of CI's blocking steps — passing them is necessary, not
# sufficient. Only CLAUDE.md ("Every enforcement surface, by tier") carries the
# step COUNT; two files carrying one number is how they drift apart.
#
# TRIGGER — all THREE must hold:
#   1. a plugins/<name> dir has a modified, staged or untracked file, and
#   2. the turn did NOT acknowledge a failing/in-progress state, and
#   3. a check genuinely fails.
#
# The original version asked "did the turn claim completion?" and matched a
# completion-phrasing regex. That penalised clear reporting and was evaded by
# saying nothing: end the turn without the word "done" and a red gate shipped
# silently. The test is inverted — saying "validate.sh is failing", "still in
# progress", "halting with evidence", "blocked on X" passes; ending on a red gate
# having said none of it does not.
#
# The prose comes from the TRANSCRIPT on purpose. The Stop payload does carry
# `last_assistant_message` (ask-ledger and candor read it), but that is the final
# message only; the tail of every assistant text block lets an acknowledgment said
# earlier in the turn count.
#
# WHAT RUNS: `generate.sh --check`, then for each changed plugin validate.sh's
# FAIL-tier per-file checks — frontmatter (pc_frontmatter), skill budget, doc
# location, jargon (not for taskmaster/task-runner), removed refs, hook
# executability (pc_hook_exec), hook shebangs — plus check-version-bumps.sh when
# committed history differs from the base. No WARN-tier check runs. validate.sh and
# context-budget.sh are NOT invoked: measured 2026-09-29, the gate that ran them
# took 93 s against the 60 s Stop timeout, so the host killed it before it blocked.
#
# WHAT IT NO LONGER CATCHES — every cross-plugin and repo-level check, left to CI
# and CLAUDE.md's pre-push loop: lanes (territory, coverage, deference, phase
# guard), skill-router rules (resolution, overlap, reachability, co-fire), README
# counts and the plugin table, marketplace.json parity, CHANGELOG/metadata parity,
# the role-floor registry, the context budget, the host's official validator, the
# smoke harnesses, and validate.sh's per-file checks not named above (plugin.json
# validity and fields, dependencies, hook timeouts, command argument hints, host
# overlap, handoff refs, dispatch binding, the hook-state checks, the command/skill
# shadow check, the renames ledger). A change confined
# to templates/, scripts/ or .claude/skills/ never triggers it.
#
# RESIDUAL: the doc allow-list, the jargon exemption, the jargon/removed-refs file
# set and the symlinked-skill budget skip are COPIES of validate.sh's inline logic;
# frontmatter and hook-exec are not — both scripts call pc_frontmatter and pc_hook_exec.
# validate.sh stays the authority; the allow_md copy is asserted byte-identical by
# scripts/smoke/done-gate-tests.sh.
#
# LIMITATION (honest scope). This converts "stop silently while a gate is red"
# into "stop having said so, or be blocked". Residuals, all accepted:
#   - It does not prove the acknowledgment is truthful; prose mentioning failure
#     for another reason satisfies the escape.
#   - It cannot tell a mid-work pause from a final claim. A Stop hook sees one
#     turn, not intent; the acknowledgment escape is what keeps ordinary work
#     unblocked, and an honest turn always carries it.
#   - The trigger reads the working tree, index and untracked files; only the
#     version-bump gate consults committed history.
#   - It fires on "plugins are dirty", not "this turn dirtied plugins", so the
#     first stop in an already-dirty session is judged even if the turn was
#     read-only. The state marker below means it says so once, not repeatedly.
#
# FAIL-OPEN on every missing tool or unreadable input, matching the sibling hooks
# (candor/hooks/gate.sh, hindsight/hooks/collect.sh) — with one exception:
# pc_removed_refs fails CLOSED on a missing or malformed scripts/removed-plugins.tsv,
# so a broken ledger blocks every changed plugin .md until it is restored.
#
# A Stop hook can reach the model two ways: stdout {"decision":"block",…} with
# exit 0, or exit 2 with the reason on stderr. This uses exit 2. Exit 0 with no
# JSON prints into a turn that has already ended and cannot prevent anything.
#
# DISABLE: remove the Stop entry from .claude/settings.json, or
#          export CRAFT_DONE_GATE=off

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
  [ -d "$p" ] && changed+=("$p")
done < <( { git diff --name-only -z -- plugins
            git diff --cached --name-only -z -- plugins
            git ls-files --others --exclude-standard -z -- plugins; } 2>/dev/null \
          | tr '\0' '\n' | cut -d/ -f1-2 | sort -u )
[ "${#changed[@]}" -eq 0 ] && exit 0

# 2. ACKNOWLEDGMENT (cheap, and evaluated BEFORE the checks so an honest turn
# never pays generate.sh --check plus the per-plugin scans).
# Whole-word matching via grep -w: BSD grep has no \b, and an unanchored `red`
# matches the tail of required/registered/triggered/covered — 1390 occurrences
# under plugins/ in this repo, which would reopen the evasion in new spelling.
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

allow_md='^(README|CHANGELOG|ROADMAP)\.md$|^skills/[^/]+/SKILL\.md$|^skills/[^/]+/references/.+\.md$|^commands/[^/]+\.md$|^agents/[^/]+\.md$|^evals/.+\.md$'
# pc_hook_shebang takes a plugins ROOT, not one plugin: run it once, filter by name.
shebang=$(pc_hook_shebang plugins 2>/dev/null) || true
for p in "${changed[@]}"; do
  name=${p#plugins/}
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
    case "$line" in "hook-shebang $name:"*) finding "hook-shebang: $line" ;; esac
  done <<<"$shebang"
done

# check-version-bumps.sh reads COMMITTED history while this hook fires on an
# UNCOMMITTED tree — different questions. Run it only when there IS committed
# history to judge, against the same base ref that script would pick itself;
# otherwise it reports OK regardless and adds a gate that cannot report.
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

# 4. LOOP GUARD. stop_hook_active is not trusted alone — the sibling Stop hook
# refuses to assume it too. The old trigger was prose the next turn could simply
# not repeat; this one is repo state a mid-work turn cannot clear, so an unset
# flag would mean an unbreakable stop-loop. Block once per distinct state.
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
ran="generate.sh --check and the per-plugin frontmatter, skill-budget, doc-location, jargon, removed-refs, hook-exec and hook-shebang checks"
[ "$ran_bumps" -eq 1 ] && ran="$ran, check-version-bumps.sh $base"

# jq, not a heredoc: findings carry paths and script lines that may hold a quote.
jq -cn --arg r "This turn is ending with plugin changes and failing checks: $shown — and said nothing about it. Either fix them (ran: $ran; full messages: scripts/validate.sh), or state plainly what is failing and why that is acceptable right now. Silence on a red gate is the one thing this hook exists to stop. CRAFT_DONE_GATE=off disables this gate for the session." \
  '{decision: "block", reason: $r}' >&2 || exit 0
exit 2
