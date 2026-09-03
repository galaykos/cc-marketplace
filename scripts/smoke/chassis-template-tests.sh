#!/usr/bin/env bash
# Renders the five chassis templates (templates/*.tmpl) with the hand-built sample
# manifests (templates/samples/*.json) through card 01's template engine and asserts
# the Fable payload contract: frontmatter fence at line 1, generated header after it,
# payload markers present (triage / CONFIRMED / Checked: / Apply all), lang/concern
# variants gate correctly, worker-agent carries all six frontmatter fields plus the
# three-strikes kill-trigger, reminder-hook has shebang line 1 + guards + optional
# extraGuard, and no {{token}} survives. Engine path overridable via TEMPLATE_ENGINE
# (default scripts/lib/template-engine.sh) so this runs before card 01 lands in-tree.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE="${TEMPLATE_ENGINE:-$REPO_ROOT/scripts/lib/template-engine.sh}"
TPL="$REPO_ROOT/templates"
SAMPLES="$TPL/samples"

if [[ ! -f "$ENGINE" ]]; then
  printf 'chassis-template-tests: engine not found: %s\n' "$ENGINE" >&2
  printf '  set TEMPLATE_ENGINE=/path/to/scripts/lib/template-engine.sh (card 01 output)\n' >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$ENGINE"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n    %s\n' "$1" "${2:-}"; rc=1; }

render() { # template sample -> file ; hard-fail on render error
  local t="$1" s="$2" out="$3"
  if ! render_template "$t" "$s" > "$out" 2>"$out.err"; then
    fail "render $t with $s" "$(cat "$out.err")"; return 1
  fi
  return 0
}
line1() { IFS= read -r _l < "$1"; printf '%s' "$_l"; }
line_n() { awk -v n="$2" 'NR==n{print; exit}' "$1"; }
grepc() { grep -c -- "$2" "$1" 2>/dev/null || true; }
has()  { grep -q -F -- "$2" "$1"; }

expect_count() { # file marker expected desc
  local n; n="$(grepc "$1" "$2")"
  if [[ "$n" == "$3" ]]; then pass "$4 ($2 == $3)"; else fail "$4" "grep -c '$2' = $n, expected $3"; fi
}
expect_has()    { if has "$1" "$2"; then pass "$3"; else fail "$3" "missing: $2"; fi; }
expect_absent() { if has "$1" "$2"; then fail "$3" "present but should be absent: $2"; else pass "$3"; fi; }

# ---- review command: lang variant ---------------------------------------------
L="$WORK/review-lang.md"
if render "$TPL/review-command.md.tmpl" "$SAMPLES/stack-review-lang.json" "$L"; then
  [[ "$(line1 "$L")" == "---" ]] && pass "lang: line 1 is ---" || fail "lang: line 1 is ---" "got [$(line1 "$L")]"
  expect_has "$L" "<!-- generated from templates/review-command.md.tmpl" "lang: generated header after fence"
  expect_count "$L" "triage" 1 "lang: triage marker"
  expect_count "$L" "CONFIRMED" 2 "lang: CONFIRMED marker (format tag + evidence rule)"
  expect_count "$L" "Checked:" 1 "lang: Checked: marker"
  expect_count "$L" "Apply all" 1 "lang: Apply all marker"
  expect_has "$L" "Apply critical+high only" "lang: apply critical+high option"
  expect_has "$L" "https://laravel.com/docs" "lang: docsUrl rendered (lang block kept)"
  expect_has "$L" "backend-engineer → task-runner:task-executor if installed → inline" "lang: workerChain stamped"
  expect_absent "$L" "design-doc review" "lang: concern affordance dropped"
  expect_has "$L" "skill from this plugin" "lang: local skillHome branch rendered"
fi

# ---- review command: skill owned by ANOTHER plugin -----------------------------
# The generator resolves where the rubric skill actually lives and emits either
# "from this plugin" or the owning plugin's name. Only the first branch had a
# fixture, so the second — the one added because database/review.md claimed a skill
# from plugins/sql was local — was rendered by nothing and asserted by nothing.
F="$WORK/review-foreign.md"
if render "$TPL/review-command.md.tmpl" "$SAMPLES/stack-review-foreign-skill.json" "$F"; then
  expect_has "$F" "from the \`sql\` plugin" "foreign: names the owning plugin"
  expect_absent "$F" "skill from this plugin" "foreign: does NOT claim the skill is local"
  expect_has "$F" "sql-best-practices" "foreign: skill name still rendered"
fi

# ---- review command: concern variant ------------------------------------------
C="$WORK/review-concern.md"
if render "$TPL/review-command.md.tmpl" "$SAMPLES/stack-review-concern.json" "$C"; then
  [[ "$(line1 "$C")" == "---" ]] && pass "concern: line 1 is ---" || fail "concern: line 1 is ---" "got [$(line1 "$C")]"
  expect_count "$C" "triage" 1 "concern: triage marker"
  expect_count "$C" "CONFIRMED" 2 "concern: CONFIRMED marker (format tag + evidence rule)"
  expect_count "$C" "Checked:" 1 "concern: Checked: marker"
  expect_count "$C" "Apply all" 1 "concern: Apply all marker"
  expect_has "$C" "section/heading for a design-doc review" "concern: design-doc locator affordance kept"
  expect_has "$C" "observability-engineer → task-runner:task-executor if installed → inline" "concern: workerChain stamped"
  expect_absent "$C" "https://laravel.com/docs" "concern: lang block dropped"
fi

# ---- worker agent -------------------------------------------------------------
W="$WORK/worker.md"
if render "$TPL/worker-agent.md.tmpl" "$SAMPLES/worker-agent.json" "$W"; then
  [[ "$(line1 "$W")" == "---" ]] && pass "worker: line 1 is ---" || fail "worker: line 1 is ---" "got [$(line1 "$W")]"
  for k in "name:" "description:" "tools:" "model:" "effort:" "bestpractices-skill:"; do
    expect_has "$W" "$k" "worker: frontmatter has $k"
  done
  expect_has "$W" "PROACTIVELY" "worker: description carries PROACTIVELY (validate.sh gate)"
  expect_has "$W" "three strikes" "worker: three-strikes kill-trigger present"
  expect_has "$W" "fails its verify three" "worker: kill-trigger cites 3 failed cycles"
  expect_absent "$W" "Domain checklist" "worker: no restated checklist (skill pointer only)"
fi

# ---- suite uninstall ----------------------------------------------------------
U="$WORK/uninstall.md"
if render "$TPL/suite-uninstall.md.tmpl" "$SAMPLES/suite-uninstall.json" "$U"; then
  [[ "$(line1 "$U")" == "---" ]] && pass "uninstall: line 1 is ---" || fail "uninstall: line 1 is ---" "got [$(line1 "$U")]"
  expect_has "$U" "<!-- generated from templates/suite-uninstall.md.tmpl" "uninstall: generated header after fence"
  expect_has "$U" "claude plugin uninstall quality-suite -s <scope> --prune -y" "uninstall: bundle param rendered with explicit scope"
  # list --json was once a per-plugin divergence to keep OUT; since 2026-08-11 it
  # is the designed discovery step (scope-aware uninstall — bundles are commonly
  # installed at project/local scope while the CLI defaults to user).
  expect_has "$U" "claude plugin list --json" "uninstall: scope discovery present"
  expect_has "$U" '.dependencies[]?' "uninstall: manifest-derived removal set present"
  expect_has "$U" "prune --dry-run -s <scope>" "uninstall: honesty check scoped"
fi

# ---- reminder hook: plain -----------------------------------------------------
H="$WORK/remind.sh"
if render "$TPL/reminder-hook.sh.tmpl" "$SAMPLES/reminder-hook.json" "$H"; then
  [[ "$(line1 "$H")" == "#!/usr/bin/env bash" ]] && pass "hook: line 1 is shebang" || fail "hook: line 1 is shebang" "got [$(line1 "$H")]"
  case "$(line_n "$H" 2)" in "# generated"*) pass "hook: line 2 is # generated header" ;; *) fail "hook: line 2 is # generated header" "got [$(line_n "$H" 2)]" ;; esac
  expect_has "$H" "command -v jq" "hook: jq fail-open guard"
  expect_has "$H" 'case "$prompt" in "" | "/"*) exit 0' "hook: empty + slash guards"
  expect_has "$H" "adspower|local" "hook: regex substituted"
  expect_absent "$H" " && [ " "hook(plain): no extraGuard when null"
  expect_has "$H" 'CC_REMIND:-on' "hook: CC_REMIND off switch present"
  expect_has "$H" 'cut -c1-400' "hook: head-window narrowing present"
  expect_has "$H" 'task-notification|SYSTEM NOTIFICATION' "hook: machinery guard present"
  expect_has "$H" 'grep -qF' "hook: own-command echo guard present"
  expect_has "$H" 'cc-remind-' "hook: per-prompt budget marker present"
fi

# ---- reminder hook: extraGuard ------------------------------------------------
HE="$WORK/remind-eg.sh"
if render "$TPL/reminder-hook.sh.tmpl" "$SAMPLES/reminder-hook-extraguard.json" "$HE"; then
  expect_has "$HE" '&& [ "${#prompt}" -lt 200 ]' "hook(extraGuard): thin-prompt condition rendered"
  expect_has "$HE" "build|create|add" "hook(extraGuard): regex substituted"
fi

# ---- reminder hook: armsClarifyGate (the cross-plugin signal) -------------------
# budgetExempt is RETIRED. It marked a privileged branch that always spoke while
# siblings ran a first-come mkdir lottery; both are replaced by one ranked path where
# a hook yields to any better arcRank sharing its phase. What had to survive the
# retirement is budgetExempt's SIDE EFFECT: the cc-workprompt marker, sole producer
# for taskmaster/hooks/clarify-gate.sh, a PreToolUse DENY gate when the user sets
# CC_CLARIFY_GATE=block. Losing it would have disarmed that gate silently and forever,
# so it now hangs off an explicit armsClarifyGate flag instead of off the branch.
HX="$WORK/remind-exempt.sh"
if render "$TPL/reminder-hook.sh.tmpl" "$SAMPLES/reminder-hook-exempt.json" "$HX"; then
  expect_has "$HX" 'cc-workprompt-' "hook(arms): drops the work-prompt marker"
  expect_has "$HX" 'cc-remind-' "hook(arms): claims a ranked marker"
  expect_has "$HX" '-rank-' "hook(arms): marker is flat, not nested"
  expect_absent "$HX" 'PRIORITY DIRECTIVE' "hook(arms): retired privileged branch is gone"
  expect_absent "$HX" 'PER-PROMPT BUDGET' "hook(arms): retired lottery branch is gone"
fi

# A manifest without the flag must not produce that marker: arming it unconditionally
# would widen a PreToolUse deny gate's trigger to every reminder hook installed.
if [ -f "$H" ]; then
  expect_absent "$H" 'cc-workprompt-$(' "hook(plain): does NOT arm the clarify gate"
fi

# ---- global invariant: no unrendered {{token}} in any output ------------------
for f in "$L" "$C" "$F" "$W" "$U" "$H" "$HE" "$HX"; do
  [[ -f "$f" ]] || continue
  if grep -q '{{' "$f"; then fail "no unrendered token in $(basename "$f")" "$(grep -n '{{' "$f")"; else pass "no unrendered token in $(basename "$f")"; fi
done

# ---- determinism: second render byte-identical --------------------------------
render_template "$TPL/review-command.md.tmpl" "$SAMPLES/stack-review-lang.json" > "$WORK/d2.md" 2>/dev/null
if diff "$L" "$WORK/d2.md" >/dev/null; then pass "determinism (double render byte-identical)"; else fail "determinism" "$(diff -u "$L" "$WORK/d2.md")"; fi

# --- lane block drift (generate.sh, not the engine) ---------------------------------
# A generated lane.tsv row edited by hand must fail --check exactly like a generated
# file — the property the block exists for. Runs on a MIRROR (never the live tree):
# copy the inputs generate.sh reads, corrupt one generated row, expect DRIFT naming
# the lane file. Locks the class, not the pilot plugin: whichever plugin carries the
# first generated block is the one corrupted.
MIR="$WORK/mirror"; mkdir -p "$MIR"
for _d in plugins scripts templates .claude-plugin; do cp -R "$REPO_ROOT/$_d" "$MIR/"; done
cp "$REPO_ROOT/README.md" "$MIR/"
LF="$(grep -l '^# generated:start' "$MIR"/plugins/*/lane.tsv 2>/dev/null | head -1)"
# Control arm first: the pristine mirror must NOT report the lane file, or the
# corruption below would pass for the wrong reason (a tree that was already drifted).
if bash "$MIR/scripts/generate.sh" --check >/dev/null 2>"$WORK/chk0.err" && ! grep -q 'lane.tsv' "$WORK/chk0.err"; then
  pass "lane-block-control (pristine mirror --check clean)"
else
  fail "lane-block-control" "pristine mirror --check already reports drift: $(grep 'DRIFT' "$WORK/chk0.err" | head -3)"
fi
# Sample `lane` keys are inert to the templates (no template names them); assert their
# schema here so a key rename in generate.sh cannot round-trip green past the samples.
lane_ok=1
for s in "$SAMPLES"/*.json; do
  # hooks and agents must also declare phase — generate.sh dies without it for those two kinds
  if jq -e '.chassis != "optout" and ((.lane // null) | type == "object") and (.lane.owns|type=="string") and (.lane.trigger|type=="string") and (.lane.yieldsTo|type=="string") and (((.chassis == "reminder-hook" or .chassis == "worker-agent") | not) or (.lane.phase|type=="string"))' "$s" >/dev/null 2>&1; then :; else
    fail "sample-lane-schema $(basename "$s")" "lane key missing, not {owns,trigger,yieldsTo} strings, or (hook/agent) no phase"; lane_ok=0
  fi
done
[[ $lane_ok == 1 ]] && pass "sample-lane-schema (every sample carries lane.{owns,trigger,yieldsTo}; hooks/agents also phase)"
if [[ -z "$LF" ]]; then
  fail "lane-block-drift" "no lane.tsv carries a generated block — generate.sh lane rows did not land"
else
  awk 'BEGIN{FS=OFS="\t"} /^# generated:start/{g=1} /^# generated:end/{g=0} g && !/^#/ && !d {$4="hand-edited-owns"; d=1} {print}' "$LF" > "$LF.tmp" && mv "$LF.tmp" "$LF"
  if bash "$MIR/scripts/generate.sh" --check >/dev/null 2>"$WORK/chk.err"; then
    fail "lane-block-drift" "--check passed after a generated lane row was hand-edited"
  elif grep -q "DRIFT content: ${LF#$MIR/}" "$WORK/chk.err"; then
    pass "lane-block-drift (hand-edited generated row → DRIFT ${LF#$MIR/})"
  else
    fail "lane-block-drift" "--check failed but did not name the lane file: $(head -3 "$WORK/chk.err")"
  fi
fi

if [[ $rc -eq 0 ]]; then printf '\nAll chassis-template asserts passed.\n'; else printf '\nSome asserts FAILED.\n'; fi
exit $rc
