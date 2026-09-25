#!/usr/bin/env bash
# Renders the four chassis templates (templates/*.tmpl) with the hand-built sample
# manifests (templates/samples/*.json) through card 01's template engine and asserts
# each one's contract: frontmatter fence at line 1, generated header after it,
# worker-agent carries all six frontmatter fields plus the three-strikes kill-trigger
# and renders a host `skills:` line only when the manifest sets `preloadSkills`,
# suite-uninstall carries its scope discovery and manifest-derived removal set,
# reminder-hook has shebang line 1 + guards + optional extraGuard, boost-hook gates both
# branches and behaves, and no {{token}} survives. Engine path overridable via
# TEMPLATE_ENGINE (default scripts/lib/template-engine.sh).
#
# review-command.md.tmpl and its three stack-review samples were RETIRED 2026-09-22
# (panel finding #64): one rendered file marketplace-wide. Its three sections here went
# with it, and so did the injected-key-parity assert — that assert read the enrichment
# `. + {…}` jq expression, which existed only in the stack-review renderer, and covered
# only stack-review samples. The failure class it guarded (generate.sh computing a key
# the frozen samples do not carry) has no live instance left: the four surviving
# renderers pass `{defaults} + .`, so a sample missing a key renders with the default
# rather than diverging from the tree.
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
  # preloadSkills (2026-09-25): an optional host `skills:` line, so a plugin agent gets a
  # skill body injected at spawn without a dispatcher. The frozen sample carries the key
  # (the 2026-08-25 lesson: generate.sh and this harness must read the same keys), so the
  # absent arm renders from a copy without it and must differ by that one line only —
  # that is what keeps every other worker agent byte-identical.
  pre=$(jq -r '.preloadSkills' "$SAMPLES/worker-agent.json")
  expect_has "$W" "skills: [$pre]" "worker: preloadSkills renders the host skills: line"
  WN="$WORK/worker-nopreload.md"
  jq 'del(.preloadSkills)' "$SAMPLES/worker-agent.json" > "$WORK/worker-nopreload.json"
  if render "$TPL/worker-agent.md.tmpl" "$WORK/worker-nopreload.json" "$WN"; then
    if grep -q '^skills:' "$WN"; then fail "worker: no skills: line without preloadSkills" "$(grep -n '^skills:' "$WN")"
    else pass "worker: no skills: line without preloadSkills"; fi
    if grep -v '^skills: ' "$W" | diff - "$WN" >/dev/null; then pass "worker: preloadSkills changes that one line only"
    else fail "worker: preloadSkills changes that one line only" "$(grep -v '^skills: ' "$W" | diff - "$WN" | head -5)"; fi
  fi
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
  [[ "$(line1 "$H")" == "#!/bin/bash" ]] && pass "hook: line 1 is shebang" || fail "hook: line 1 is shebang" "got [$(line1 "$H")]"
  case "$(line_n "$H" 2)" in "# generated"*) pass "hook: line 2 is # generated header" ;; *) fail "hook: line 2 is # generated header" "got [$(line_n "$H" 2)]" ;; esac
  expect_has "$H" "command -v jq" "hook: jq fail-open guard"
  expect_has "$H" 'case "$prompt" in "" | "/"*) exit 0' "hook: empty + slash guards"
  expect_has "$H" "adspower|local" "hook: regex substituted"
  # Pinned to the TRIGGER line, not a substring over the whole file: the state-root
  # block (included since 2026-09-25) legitimately carries a two-test conjunction, so a
  # file-wide absence check failed on shared code instead of on a leaked extraGuard.
  re_plain=$(jq -r '.regex' "$SAMPLES/reminder-hook.json")
  expect_has "$H" "\"\$head\" | grep -qiE '$re_plain'; then" "hook(plain): no extraGuard when null"
  expect_has "$H" 'cc_state_root() {' "hook: state-root block included (defines cc_state_root)"
  expect_has "$H" 'sentinel="$root/.claude/cc-phase.json"' "hook: phase sentinel read at the state root, not the payload cwd"
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

# ---- boost hook: two-branch (taskmaster ultra-task / ultra-goal) -----------------
# The three boost injectors were hand-copied twins until 2026-09-10; the template
# owns the shared skeleton and the manifest owns env var, token regex and directive.
B="$WORK/boost.sh"
if render "$TPL/boost-hook.sh.tmpl" "$SAMPLES/boost-hook.json" "$B"; then
  [[ "$(line1 "$B")" == "#!/bin/bash" ]] && pass "boost: line 1 is shebang" || fail "boost: line 1 is shebang" "got [$(line1 "$B")]"
  case "$(line_n "$B" 2)" in "# generated"*) pass "boost: line 2 is # generated header" ;; *) fail "boost: line 2 is # generated header" "got [$(line_n "$B" 2)]" ;; esac
  expect_has "$B" 'case "$prompt" in "/"*) exit 0' "boost: slash-prompt guard"
  expect_has "$B" 'plugin_switch=TASKMASTER_BOOST' "boost: per-plugin off switch envVar substituted"
  expect_has "$B" 'CC_BOOST:-on}${!plugin_switch:-on}' "boost: global + per-plugin off switch"
  expect_has "$B" 'cut -c1-200' "boost: 200-char head narrowing"
  expect_has "$B" "(do not|don't|never|without|avoid|not) +" "boost: negation guard"
  expect_has "$B" 'ultra-?(task|goal|assess(ment)?|craft) +active' "boost: enumerated self-echo guard (shared list)"
  expect_has "$B" "grep -qiE '\\bultra-?goal\\b'" "boost: first-branch regex substituted"
  expect_has "$B" "elif printf '%s' \"\$head\" | grep -qiE '\\bultra-?task\\b'" "boost: second branch rendered when regex2 set"
  expect_has "$B" "<<'CC_BOOST_DIRECTIVE'" "boost: directive via quoted heredoc (no expansion)"
  expect_has "$B" "ULTRA-GOAL ACTIVE" "boost: first directive text present"
  expect_has "$B" "ULTRA-TASK ACTIVE" "boost: second directive text present"
  # Behavioural: the rendered hook must speak on an invocation and stay silent on its own banner.
  out="$(printf '%s' '{"prompt":"ultra-task build the thing"}' | bash "$B" 2>/dev/null)"
  [[ "$out" == "ULTRA-TASK ACTIVE"* ]] && pass "boost: rendered hook speaks on invocation" || fail "boost: rendered hook speaks on invocation" "got [${out:0:40}]"
  out="$(printf '%s' '{"prompt":"ULTRA-TASK ACTIVE (model=auto) — ultra-task"}' | bash "$B" 2>/dev/null)"
  [[ -z "$out" ]] && pass "boost: rendered hook silent on own banner" || fail "boost: rendered hook silent on own banner" "spoke: ${out:0:40}"
fi

# ---- boost hook: single branch (regex2 empty → no elif) -------------------------
BS="$WORK/boost-single.sh"
if render "$TPL/boost-hook.sh.tmpl" "$SAMPLES/boost-hook-single.json" "$BS"; then
  expect_absent "$BS" "elif printf" "boost(single): no elif branch when regex2 is empty"
  expect_has "$BS" 'plugin_switch=ORCHESTRATION_BOOST' "boost(single): envVar substituted"
  expect_has "$BS" "ULTRA-ASSESS ACTIVE" "boost(single): directive text present"
fi

# A manifest without the flag must not produce that marker: arming it unconditionally
# would widen a PreToolUse deny gate's trigger to every reminder hook installed.
if [ -f "$H" ]; then
  expect_absent "$H" 'cc-workprompt-$(' "hook(plain): does NOT arm the clarify gate"
fi

# ---- global invariant: no unrendered {{token}} in any output ------------------
for f in "$W" "$U" "$H" "$HE" "$HX" "$B" "$BS"; do
  [[ -f "$f" ]] || continue
  if grep -q '{{' "$f"; then fail "no unrendered token in $(basename "$f")" "$(grep -n '{{' "$f")"; else pass "no unrendered token in $(basename "$f")"; fi
done

# ---- determinism: second render byte-identical --------------------------------
render_template "$TPL/worker-agent.md.tmpl" "$SAMPLES/worker-agent.json" > "$WORK/d2.md" 2>/dev/null
if diff "$W" "$WORK/d2.md" >/dev/null; then pass "determinism (double render byte-identical)"; else fail "determinism" "$(diff -u "$W" "$WORK/d2.md")"; fi

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
  if jq -e '(.chassis == "optout") or (((.lane // null) | type == "object") and (.lane.owns|type=="string") and (.lane.trigger|type=="string") and (.lane.yieldsTo|type=="string") and (((.chassis == "reminder-hook" or .chassis == "boost-hook" or .chassis == "worker-agent") | not) or (.lane.phase|type=="string")))' "$s" >/dev/null 2>&1; then :; else
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
