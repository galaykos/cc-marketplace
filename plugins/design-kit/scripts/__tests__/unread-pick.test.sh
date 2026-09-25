#!/usr/bin/env bash
# Drives hooks/unread-pick.sh: silent without decisions, one line with an unread pick,
# silent once consumed, silent past the decide phase, off-switch honoured, silent with
# no python3, and SPEAKING again once a dead run's sentinel ages past the guard's TTL.
#
# CLAUDE_PLUGIN_ROOT is exported because the shared phase guard resolves the hook's lane
# from ${CLAUDE_PLUGIN_ROOT}/lane.tsv — the host sets it for every plugin hook, and
# without it the guard fails open and every phase case below would pass for the wrong
# reason. What this does NOT prove: that the model acts on the line (agent-graded).
set -euo pipefail
unset CLAUDE_PROJECT_DIR   # a live session exports it; the state root would resolve there
here="$(cd "$(dirname "$0")/../.." && pwd)"; hook="$here/hooks/unread-pick.sh"
export CLAUDE_PLUGIN_ROOT="$here"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
payload() { printf '{"cwd":"%s","prompt":"x"}' "$tmp"; }
[ -z "$(payload | bash "$hook")" ] || { echo "FAIL: spoke with no decisions"; exit 1; }
mkdir -p "$tmp/.design-kit"
printf '{"ts":"t","board":"2026-09-22-deal.html","picked":2,"knobs":{},"text":{},"prompt":"p","consumed":false}\n' > "$tmp/.design-kit/decisions.jsonl"
out="$(payload | bash "$hook")"
case "$out" in "design-kit: 2026-09-22-deal.html has an unread pick — artboard 2."*) ;; *) echo "FAIL: line: $out"; exit 1 ;; esac
[ "$(printf '%s' "$out" | wc -l | tr -d ' ')" = 0 ] || { echo "FAIL: more than one line"; exit 1; }
[ -z "$(payload | CC_REMIND=off bash "$hook")" ] || { echo "FAIL: CC_REMIND=off ignored"; exit 1; }
[ -z "$(payload | CC_DESIGN_KIT_PICK=off bash "$hook")" ] || { echo "FAIL: CC_DESIGN_KIT_PICK=off ignored"; exit 1; }

# no python3 on PATH: silent AND exit 0. rc=127 on every prompt is what `set -e` plus an
# unguarded interpreter used to buy.
mkdir -p "$tmp/nobin"; bash_bin="$(command -v bash)"
rc=0; out="$(payload | PATH="$tmp/nobin" "$bash_bin" "$hook")" || rc=$?
[ "$rc" = 0 ] || { echo "FAIL: exit $rc with no python3"; exit 1; }
[ -z "$out" ] || { echo "FAIL: spoke with no python3: $out"; exit 1; }

mkdir -p "$tmp/.claude"; printf '{"phase":"build"}' > "$tmp/.claude/cc-phase.json"
[ -z "$(payload | bash "$hook")" ] || { echo "FAIL: spoke during build phase"; exit 1; }
printf '{"phase":"plan"}' > "$tmp/.claude/cc-phase.json"
[ -z "$(payload | bash "$hook")" ] || { echo "FAIL: spoke during plan phase"; exit 1; }
printf '{"phase":"decide"}' > "$tmp/.claude/cc-phase.json"
[ -n "$(payload | bash "$hook")" ] || { echo "FAIL: silent during decide phase"; exit 1; }

# a dead run's sentinel, aged past the guard's 120-minute TTL: the hook speaks again and
# the stale file is unlinked. Without the TTL one abandoned run mutes this channel in
# every future session in the project.
printf '{"phase":"build","session_id":"dead-run"}' > "$tmp/.claude/cc-phase.json"
python3 -c "import os,sys,time; p=sys.argv[1]; os.utime(p,(time.time()-3*3600,)*2)" "$tmp/.claude/cc-phase.json"
[ -n "$(payload | bash "$hook")" ] || { echo "FAIL: silent behind a stale sentinel"; exit 1; }
[ ! -e "$tmp/.claude/cc-phase.json" ] || { echo "FAIL: stale sentinel not unlinked"; exit 1; }
printf '{"ts":"t","board":"2026-09-22-deal.html","picked":2,"knobs":{},"text":{},"prompt":"p","consumed":true}\n' > "$tmp/.design-kit/decisions.jsonl"
[ -z "$(payload | bash "$hook")" ] || { echo "FAIL: spoke after consume"; exit 1; }

# SUBDIRECTORY cwd. The payload cwd follows the model's `cd` (finding 2 of
# rationale/2026-09-25-session-plugin-usage-review.md), so a sentinel and a board at the
# repo root must still be found from app/Models. Before 0.5.1 the guard read
# <cwd>/.claude/cc-phase.json, found nothing there and spoke through a root-declared build.
repo="$tmp/repo"; mkdir -p "$repo/app/Models" "$repo/.design-kit" "$repo/.claude"
git -C "$repo" init -q
subp() { printf '{"cwd":"%s","prompt":"x"}' "$repo/app/Models"; }
printf '{"ts":"t","board":"2026-09-25-root.html","picked":1,"knobs":{},"text":{},"prompt":"p","consumed":false}\n' > "$repo/.design-kit/decisions.jsonl"
# speaking first, so the build-phase silence below cannot pass for a board never found
printf '{"phase":"decide"}' > "$repo/.claude/cc-phase.json"
case "$(subp | bash "$hook")" in "design-kit: 2026-09-25-root.html has an unread pick"*) ;;
  *) echo "FAIL: missed the root's board from a subdirectory"; exit 1 ;; esac
printf '{"phase":"build"}' > "$repo/.claude/cc-phase.json"
[ -z "$(subp | bash "$hook")" ] || { echo "FAIL: spoke from a subdirectory during a root-declared build phase"; exit 1; }
[ ! -e "$repo/app/Models/.claude" ] || { echo "FAIL: a .claude/ dir appeared in the subdirectory"; exit 1; }
# dk.sh writes .design-kit/ under the shell cwd it ran in: a board built after a `cd` sits
# in the subdirectory, and the cwd fallback still finds it.
rm -f "$repo/.design-kit/decisions.jsonl" "$repo/.claude/cc-phase.json"; mkdir -p "$repo/app/Models/.design-kit"
printf '{"ts":"t","board":"2026-09-25-sub.html","picked":3,"knobs":{},"text":{},"prompt":"p","consumed":false}\n' > "$repo/app/Models/.design-kit/decisions.jsonl"
case "$(subp | bash "$hook")" in "design-kit: 2026-09-25-sub.html has an unread pick"*) ;;
  *) echo "FAIL: missed a board built in the subdirectory"; exit 1 ;; esac
echo "PASS unread-pick.test.sh"
