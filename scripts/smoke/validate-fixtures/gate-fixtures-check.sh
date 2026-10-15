#!/usr/bin/env bash
# Fixture harness for the checks the 2026-09-22 specialist panel added to
# scripts/lib/plugin-checks.sh — pc_cwd_validated (#2), pc_offswitch_named (#5) and
# pc_version_stamp_tail (#21) — plus pc_state_root and pc_shared_blocks from the
# 2026-09-25 session review, pc_plugin_dependencies from the 2026-09-26 suite
# retirement, and pc_agent_tool_fit from the 2026-10-13 session retro. Each gets BOTH arms: a planted violation that must be
# named, and a clean twin that must not be. A check that only ever runs against the live
# tree proves nothing on the day the tree is clean, which is the day it lands.
#
# Never touches plugins/ — every fixture is built under a temp root and the pc_*
# functions are called against that root directly.
set -u
cd "$(dirname "$0")/../../.." || exit 2   # repo root
. scripts/lib/plugin-checks.sh || { echo "FAIL: cannot source scripts/lib/plugin-checks.sh"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
rc=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 — $2"; rc=1; }

mkhook() { # <plugin> <script-name> <body-file-content on stdin>
  mkdir -p "$T/$1/hooks"
  cat > "$T/$1/hooks/$2"
  jq -n --arg c "\${CLAUDE_PLUGIN_ROOT}/hooks/$2" \
    '{hooks:{PreToolUse:[{matcher:"Write",hooks:[{type:"command",command:$c,timeout:5}]}]}}' \
    > "$T/$1/hooks/hooks.json"
}

# ---- pc_cwd_validated ----------------------------------------------------------
mkhook badcwd resurrect.sh <<'SH'
#!/bin/bash
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || exit 0
dir="$cwd/.claude/fixture"
mkdir -p "$dir" 2>/dev/null || exit 0
exit 0
SH
mkhook okcwd guarded.sh <<'SH'
#!/bin/bash
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
dir="$cwd/.claude/fixture"
mkdir -p "$dir" 2>/dev/null || exit 0
exit 0
SH
# The equivalent test: a read of a path INSIDE cwd proves the directory is there.
mkhook insidecwd inside.sh <<'SH'
#!/bin/bash
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -r "$cwd/.claude/fixture/run.json" ] || exit 0
d="$cwd/.claude/fixture/sub"
mkdir -p "$d" 2>/dev/null || exit 0
exit 0
SH
out=$(pc_cwd_validated "$T") || true
case "$out" in
  *"cwd-unvalidated badcwd:resurrect.sh"*) pass "cwd: unguarded mkdir on payload cwd is named" ;;
  *) fail "cwd: unguarded mkdir on payload cwd is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *okcwd*) fail "cwd: [ -d \"\$cwd\" ] arm stays clean" "flagged: $out" ;;
  *) pass "cwd: [ -d \"\$cwd\" ] arm stays clean" ;;
esac
case "$out" in
  *insidecwd*) fail "cwd: a test on a path inside cwd counts as validation" "flagged: $out" ;;
  *) pass "cwd: a test on a path inside cwd counts as validation" ;;
esac
printf '# cwd-mkdir-ok: fixture\n' >> "$T/badcwd/hooks/resurrect.sh"
out=$(pc_cwd_validated "$T") || true
case "$out" in
  *badcwd*) fail "cwd: '# cwd-mkdir-ok:' silences it" "still flagged: $out" ;;
  *) pass "cwd: '# cwd-mkdir-ok:' silences it" ;;
esac

# ---- pc_state_root (2026-09-25 session review, finding 2) -----------------------
mkhook rawroot raw.sh <<'SH'
#!/bin/bash
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -d "$cwd" ] || exit 0
mkdir -p "$cwd/.claude/fixture" 2>/dev/null
exit 0
SH
mkhook braceroot brace.sh <<'SH'
#!/bin/bash
cwd=$(jq -r '.cwd // empty')
[ -d "$cwd" ] || exit 0
f="${cwd}/.claude/task-runner/active-run.json"
exit 0
SH
mkhook okroot resolved.sh <<'SH'
#!/bin/bash
# the old shape, discussed in a comment: "$cwd/.claude/fixture" is not code
cwd=$(jq -r '.cwd // empty')
root=$(cc_state_root "$cwd") || exit 0
mkdir -p "$root/.claude/fixture" 2>/dev/null
exit 0
SH
out=$(pc_state_root "$T") || true
case "$out" in
  *"state-root-raw rawroot:raw.sh"*) pass "state-root: \$cwd/.claude is named" ;;
  *) fail "state-root: \$cwd/.claude is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"state-root-raw braceroot:brace.sh"*) pass "state-root: \${cwd}/.claude is named" ;;
  *) fail "state-root: \${cwd}/.claude is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *okroot*) fail "state-root: cc_state_root + a comment stays clean" "flagged: $out" ;;
  *) pass "state-root: cc_state_root + a comment stays clean" ;;
esac
printf '# state-root-ok: fixture\n' >> "$T/rawroot/hooks/raw.sh"
out=$(pc_state_root "$T") || true
case "$out" in
  *rawroot*) fail "state-root: '# state-root-ok:' silences it" "still flagged: $out" ;;
  *) pass "state-root: '# state-root-ok:' silences it" ;;
esac

# A QUOTED command ("\"${CLAUDE_PLUGIN_ROOT}/hooks/x.sh\"", the form the host validator
# requires from CLI 2.1.282) must still be resolved: a check that silently skipped every
# quoted hook would read green on a tree it no longer sees.
mkdir -p "$T/quoted/hooks"
printf '#!/bin/bash\ncwd=$(jq -r .cwd)\nmkdir -p "$cwd/.claude/x"\n' > "$T/quoted/hooks/q.sh"
jq -n --arg c "\"\${CLAUDE_PLUGIN_ROOT}/hooks/q.sh\"" \
  '{hooks:{Stop:[{hooks:[{type:"command",command:$c}]}]}}' > "$T/quoted/hooks/hooks.json"
out=$(pc_state_root "$T") || true
case "$out" in
  *"state-root-raw quoted:q.sh"*) pass "quoted command: pc_state_root still resolves it" ;;
  *) fail "quoted command: pc_state_root still resolves it" "got: ${out:-<empty>}" ;;
esac
out=$(pc_cwd_validated "$T") || true
case "$out" in
  *"cwd-unvalidated quoted:q.sh"*) pass "quoted command: pc_cwd_validated still resolves it" ;;
  *) fail "quoted command: pc_cwd_validated still resolves it" "got: ${out:-<empty>}" ;;
esac
rm -rf "$T/quoted"

# ---- quoted vs unquoted hook commands: every hooks.json reader must agree ------------
# 2026-09-25: hook commands moved to the quoted form the host validator requires from CLI
# 2.1.282. Two readers matched the unquoted shape with a `case` pattern and one took the
# last path segment, so pc_lanes_coverage silently stopped seeing every hook — green on a
# tree it no longer read. The invariant: the same fixture, quoted and unquoted, draws the
# SAME findings from every check that reads hooks.json, and the findings are not empty.
QR="$T/_quoting"; mkdir -p "$QR/qfix/hooks"
printf '#!/usr/bin/env bash\ninput=$(cat)\ncwd=$(printf %%s "$input" | jq -r .cwd)\nmkdir -p "$cwd/.claude/x"\nexit 0\n' > "$QR/qfix/hooks/remind.sh"
printf '#!/bin/bash\nexit 0\n' > "$QR/qfix/hooks/gate.sh"
printf '#!/bin/bash\necho %s\nexit 0\n' "'{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\"}}'" > "$QR/qfix/hooks/deny.sh"
chmod +x "$QR"/qfix/hooks/*.sh
printf '# artifact\tkind\tphase\towns\tdefinite_trigger\tyields_to\n' > "$QR/qfix/lane.tsv"
qhooks() { # $1 = command prefix/suffix quote character ('' or '"')
  jq -n --arg q "$1" '{hooks:{
    UserPromptSubmit:[{hooks:[{type:"command",command:($q+"${CLAUDE_PLUGIN_ROOT}/hooks/remind.sh"+$q)}]}],
    Stop:[{hooks:[{type:"command",command:($q+"${CLAUDE_PLUGIN_ROOT}/hooks/gate.sh"+$q),timeout:5}]}],
    PreToolUse:[{matcher:"Edit",hooks:[{type:"command",command:($q+"${CLAUDE_PLUGIN_ROOT}/hooks/deny.sh"+$q),timeout:5}]}]}}' \
    > "$QR/qfix/hooks/hooks.json"
}
qrun() {
  for fn in pc_hook_timeout pc_hook_shebang pc_state_root pc_cwd_validated pc_lanes_coverage \
            pc_phase_guard pc_offswitch_named pc_marker_key pc_context_key; do
    printf '== %s\n' "$fn"; { "$fn" "$QR" 2>>"${QERR:-/dev/null}"; echo "rc=$?"; } | sed 's/"//g'
  done
}
qhooks ''; unq=$(qrun)
qhooks '"'; quo=$(qrun)
if [ "$unq" = "$quo" ]; then pass "quoting: every hooks.json reader agrees on quoted and unquoted commands"
else fail "quoting: every hooks.json reader agrees on quoted and unquoted commands" "$(diff <(printf '%s\n' "$unq") <(printf '%s\n' "$quo") | head -8)"; fi
for want in "hook-timeout qfix:UserPromptSubmit:remind.sh" "hook-shebang qfix:remind.sh" \
            "state-root-raw qfix:remind.sh" "cwd-unvalidated qfix:remind.sh" \
            "lane-missing hook qfix:remind" "lane-missing hook qfix:gate" "lane-missing hook qfix:deny"; do
  case "$quo" in *"$want"*) pass "quoting: quoted form still draws '$want'" ;;
    *) fail "quoting: quoted form still draws '$want'" "got: $(printf '%s' "$quo" | grep -v '^==' | head -6)" ;; esac
done

# ---- modules-only and hooks+modules hooks.json: every reader must agree --------------
QERR="$T/qerr"; : > "$QERR"
# Every pc_* sends jq's stderr to /dev/null, so a reader's jq error is visible only here.
jq() { command jq "$@" 2>>"$QERR"; }
printf 'export function register() {}\n' > "$QR/qfix/hooks/m.ts"
jq '. + {modules:["./m.ts"]}' "$QR/qfix/hooks/hooks.json" > "$QR/m.json" && mv "$QR/m.json" "$QR/qfix/hooks/hooks.json"
both=$(qrun)
rm -rf "$QR/qfix"; mkdir -p "$QR/monly/hooks"
printf 'export function register() {}\n' > "$QR/monly/hooks/m.ts"
printf '{"modules":["./m.ts"]}\n' > "$QR/monly/hooks/hooks.json"
monly=$(qrun)
unset -f jq
detail=$( { cat "$QERR"; printf '%s\n' "$monly" | grep -vxE '==.*|rc=0'; diff <(printf '%s\n' "$quo") <(printf '%s\n' "$both"); } | head -8)
if [ -z "$detail" ]; then pass "modules-only: every hooks.json reader agrees"
else fail "modules-only: every hooks.json reader agrees" "$detail"; fi
rm -rf "$QR"

# ---- pc_shared_blocks ------------------------------------------------------------
B="$T/_blocks"; mkdir -p "$B" "$T/blk/hooks"
cp templates/blocks/state-root.md templates/blocks/bash-write-targets.md templates/blocks/bash-write-chunks.md templates/blocks/plugin-state.md templates/blocks/prompt-shape.md "$B/"
{ echo '#!/bin/bash'; cat "$B/state-root.md" "$B/prompt-shape.md"; echo 'exit 0'; } > "$T/blk/hooks/good.sh"
{ echo '#!/bin/bash'; sed 's/return 1$/return 2/' "$B/prompt-shape.md"; echo 'exit 0'; } > "$T/blk/hooks/prompt-edited.sh"
{ echo '#!/bin/bash'; awk '/^cc_prompt_frame\(\) \{/,/^}/' "$B/prompt-shape.md"; echo 'exit 0'; } > "$T/blk/hooks/prompt-one.sh"
# The auth words, review-debt's path list and taskmaster's prompt list, live in every copy: a lone paste or a dropped word splits them.
{ echo '#!/bin/bash'; awk '/^cc_prompt_auth_surface\(\) \{/,/^}/' "$B/prompt-shape.md"; echo 'exit 0'; } > "$T/blk/hooks/prompt-auth-one.sh"
{ echo '#!/bin/bash'; sed 's/|registration|/|/' "$B/prompt-shape.md"; echo 'exit 0'; } > "$T/blk/hooks/prompt-auth-edited.sh"
{ echo '#!/bin/bash'; sed 's/|invit(e|ation)|/|/' "$B/prompt-shape.md"; echo 'exit 0'; } > "$T/blk/hooks/prompt-ask-edited.sh"
{ echo '#!/bin/bash'; sed 's/return 1$/return 2/' "$B/state-root.md"; echo 'exit 0'; } > "$T/blk/hooks/edited.sh"
{ echo '#!/bin/bash'; echo 'cc_bash_write_targets() { :; }'; } > "$T/blk/hooks/reimpl.sh"
{ echo '#!/bin/bash'; echo 'cc_bash_write_chunks() { :; }'; } > "$T/blk/hooks/reimpl-chunks.sh"
{ echo '#!/bin/bash'; sed 's/local key sum$/local key sun/' "$B/plugin-state.md"; echo 'exit 0'; } > "$T/blk/hooks/pstate-edited.sh"
out=$(pc_shared_blocks "$T" "$B") || true
case "$out" in
  *"blk/hooks/edited.sh state-root.md"*) pass "shared-blocks: an edited copy is named" ;;
  *) fail "shared-blocks: an edited copy is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"blk/hooks/reimpl.sh bash-write-targets.md"*) pass "shared-blocks: a same-name reimplementation is named" ;;
  *) fail "shared-blocks: a same-name reimplementation is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"blk/hooks/reimpl-chunks.sh bash-write-chunks.md"*) pass "shared-blocks: a cc_bash_write_chunks reimplementation is named" ;;
  *) fail "shared-blocks: a cc_bash_write_chunks reimplementation is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"blk/hooks/pstate-edited.sh plugin-state.md"*) pass "shared-blocks: an edited plugin-state copy is named" ;;
  *) fail "shared-blocks: an edited plugin-state copy is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"blk/hooks/prompt-edited.sh prompt-shape.md"*) pass "shared-blocks: an edited prompt-shape copy is named" ;;
  *) fail "shared-blocks: an edited prompt-shape copy is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"blk/hooks/prompt-one.sh prompt-shape.md"*) pass "shared-blocks: a hook pasting one cc_prompt_* function is held to the whole block" ;;
  *) fail "shared-blocks: a hook pasting one cc_prompt_* function is held to the whole block" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"blk/hooks/prompt-auth-one.sh prompt-shape.md"*) pass "shared-blocks: a hook pasting only cc_prompt_auth_surface is held to the whole block" ;;
  *) fail "shared-blocks: a hook pasting only cc_prompt_auth_surface is held to the whole block" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"blk/hooks/prompt-auth-edited.sh prompt-shape.md"*) pass "shared-blocks: a copy dropping an auth-surface word is named" ;;
  *) fail "shared-blocks: a copy dropping an auth-surface word is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"blk/hooks/prompt-ask-edited.sh prompt-shape.md"*) pass "shared-blocks: a copy dropping a prompt-side auth word is named" ;;
  *) fail "shared-blocks: a copy dropping a prompt-side auth word is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *good.sh*) fail "shared-blocks: a verbatim copy stays clean" "flagged: $out" ;;
  *) pass "shared-blocks: a verbatim copy stays clean" ;;
esac
# heredoc-bodies.md, in its own run so the arm stands alone.
cp templates/blocks/heredoc-bodies.md "$B/"
{ echo '#!/bin/bash'; cat "$B/heredoc-bodies.md"; echo 'exit 0'; } > "$T/blk/hooks/heredoc-good.sh"
{ echo '#!/bin/bash'; sed 's/-v how=/-v hw=/' "$B/heredoc-bodies.md"; echo 'exit 0'; } > "$T/blk/hooks/heredoc-edited.sh"
out=$(pc_shared_blocks "$T" "$B") || true
case "$out" in
  *"blk/hooks/heredoc-edited.sh heredoc-bodies.md"*) pass "shared-blocks: an edited heredoc-bodies copy is named" ;;
  *) fail "shared-blocks: an edited heredoc-bodies copy is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *heredoc-good.sh*) fail "shared-blocks: a verbatim heredoc-bodies copy stays clean" "flagged: $out" ;;
  *) pass "shared-blocks: a verbatim heredoc-bodies copy stays clean" ;;
esac
# bash-write-effects.md, in its own run: an edited copy, and one of its two functions pasted alone.
cp templates/blocks/bash-write-effects.md "$B/"
{ echo '#!/bin/bash'; cat "$B/bash-write-effects.md"; echo 'exit 0'; } > "$T/blk/hooks/effects-good.sh"
{ echo '#!/bin/bash'; sed 's/--untracked-files=all/--untracked-files=normal/' "$B/bash-write-effects.md"; echo 'exit 0'; } > "$T/blk/hooks/effects-edited.sh"
{ echo '#!/bin/bash'; awk '/^cc_bash_effects_mark\(\) \{/,/^}/' "$B/bash-write-effects.md"; echo 'exit 0'; } > "$T/blk/hooks/effects-one.sh"
out=$(pc_shared_blocks "$T" "$B") || true
case "$out" in
  *"blk/hooks/effects-edited.sh bash-write-effects.md"*) pass "shared-blocks: an edited bash-write-effects copy is named" ;;
  *) fail "shared-blocks: an edited bash-write-effects copy is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"blk/hooks/effects-one.sh bash-write-effects.md"*) pass "shared-blocks: a hook pasting cc_bash_effects_mark alone is held to the whole block" ;;
  *) fail "shared-blocks: a hook pasting cc_bash_effects_mark alone is held to the whole block" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *effects-good.sh*) fail "shared-blocks: a verbatim bash-write-effects copy stays clean" "flagged: $out" ;;
  *) pass "shared-blocks: a verbatim bash-write-effects copy stays clean" ;;
esac
# write-scope.md, in its own run: an edited copy (the root order swapped), and cc_scope_skip pasted alone.
cp templates/blocks/write-scope.md "$B/"
{ echo '#!/bin/bash'; cat "$B/write-scope.md"; echo 'exit 0'; } > "$T/blk/hooks/scope-good.sh"
{ echo '#!/bin/bash'; sed 's/for r in "$cc_scope_sr" "$cc_scope_pd"/for r in "$cc_scope_pd" "$cc_scope_sr"/' "$B/write-scope.md"; echo 'exit 0'; } > "$T/blk/hooks/scope-edited.sh"
{ echo '#!/bin/bash'; awk '/^cc_scope_skip\(\) \{/,/^}/' "$B/write-scope.md"; echo 'exit 0'; } > "$T/blk/hooks/scope-one.sh"
out=$(pc_shared_blocks "$T" "$B") || true
case "$out" in
  *"blk/hooks/scope-edited.sh write-scope.md"*) pass "shared-blocks: an edited write-scope copy is named" ;;
  *) fail "shared-blocks: an edited write-scope copy is named" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"blk/hooks/scope-one.sh write-scope.md"*) pass "shared-blocks: a hook pasting cc_scope_skip alone is held to the whole block" ;;
  *) fail "shared-blocks: a hook pasting cc_scope_skip alone is held to the whole block" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *scope-good.sh*) fail "shared-blocks: a verbatim write-scope copy stays clean" "flagged: $out" ;;
  *) pass "shared-blocks: a verbatim write-scope copy stays clean" ;;
esac

# ---- pc_offswitch_named --------------------------------------------------------
mkhook badsw quiet-deny.sh <<'SH'
#!/bin/bash
# CC_FIXTURE_GUARD=off turns this off — said here, where a refused user never looks.
input=$(cat)
[ "${CC_FIXTURE_GUARD:-on}" = off ] && exit 0
jq -cn --arg r 'fixture: refused.' \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
SH
mkhook oksw loud-deny.sh <<'SH'
#!/bin/bash
input=$(cat)
[ "${CC_FIXTURE_GUARD:-on}" = off ] && exit 0
jq -cn --arg r 'fixture: refused. CC_FIXTURE_GUARD=off disables this for the session.' \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
SH
# A hook that cannot refuse is out of scope even with a switch and no prose.
mkhook advisorysw advise.sh <<'SH'
#!/bin/bash
input=$(cat)
[ "${CC_FIXTURE_ADVISORY:-on}" = off ] && exit 0
printf 'fixture: a suggestion.\n'
exit 0
SH
out=$(pc_offswitch_named "$T") || true
case "$out" in
  *"offswitch-unnamed badsw:quiet-deny.sh"*) pass "offswitch: a deny that names its switch nowhere is flagged" ;;
  *) fail "offswitch: a deny that names its switch nowhere is flagged" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *oksw*) fail "offswitch: naming it in the reason clears it" "flagged: $out" ;;
  *) pass "offswitch: naming it in the reason clears it" ;;
esac
case "$out" in
  *advisorysw*) fail "offswitch: an advisory hook is out of scope" "flagged: $out" ;;
  *) pass "offswitch: an advisory hook is out of scope" ;;
esac
mkhook resolvedsw quiet-resolved.sh <<'SH'
#!/bin/bash
# CC_FIXTURE_RESOLVED=off turns this off — said here, where a refused user never looks.
# [ "$(cc_option CC_FIXTURE_GHOST on)" = off ]
input=$(cat)
d="${CLAUDE_PLUGIN_DATA:-}"
[ "$(cc_option CC_FIXTURE_RESOLVED on)" = off ] && exit 0
[ "$(cc_option "CC_FIXTURE_QUOTED" on)" = off ] && exit 0
[ "$(cc_option 'CC_FIXTURE_SQ' on)" = off ] && exit 0
[ "$(cc_option FIX_BOOST_MODE on)" = off ] && exit 0
jq -cn --arg r 'fixture: refused.' \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
SH
mkhook resolvedok loud-resolved.sh <<'SH'
#!/bin/bash
# CC_FIXTURE_RESOLVED=off turns this off — said here, where a refused user never looks.
input=$(cat)
[ "$(cc_option CC_FIXTURE_RESOLVED on)" = off ] && exit 0
jq -cn --arg r 'fixture: refused. CC_FIXTURE_RESOLVED=off disables this for the session.' \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
SH
out=$(pc_offswitch_named "$T") || true
case "$out" in
  *"offswitch-unnamed resolvedsw:quiet-resolved.sh "*CC_FIXTURE_RESOLVED*) pass "offswitch: a resolver-read switch named nowhere is flagged" ;;
  *) fail "offswitch: a resolver-read switch named nowhere is flagged" "got: ${out:-<empty>}" ;;
esac
# The whole line: a commented call and CLAUDE_PLUGIN_DATA are not switches, both quote forms
# are read, and FIX_BOOST_MODE is read whole (no switch shape), never cut to FIX_BOOST.
if printf '%s\n' "$out" | grep -qxF 'offswitch-unnamed resolvedsw:quiet-resolved.sh CC_FIXTURE_QUOTED CC_FIXTURE_RESOLVED CC_FIXTURE_SQ'; then
  pass "offswitch: resolver reads are found exactly — quotes, comments, host vars, whole names"
else
  fail "offswitch: resolver reads are found exactly — quotes, comments, host vars, whole names" "got: ${out:-<empty>}"
fi
case "$out" in
  *resolvedok*) fail "offswitch: a resolver-read switch named in the reason is clean" "flagged: $out" ;;
  *) pass "offswitch: a resolver-read switch named in the reason is clean" ;;
esac
printf '# offswitch-ok: fixture\n' >> "$T/badsw/hooks/quiet-deny.sh"
out=$(pc_offswitch_named "$T") || true
case "$out" in
  *badsw*) fail "offswitch: '# offswitch-ok:' silences it" "still flagged: $out" ;;
  *) pass "offswitch: '# offswitch-ok:' silences it" ;;
esac

# ---- pc_switch_reads on hooks modules ------------------------------------------
mkdir -p "$T/modsw/hooks"
cat > "$T/modsw/hooks/reads.ts" <<'TS'
// $.env.get('CC_FX_GHOST')
 * registerSuggestion(
const v = await $.env.get("CC_FX_DQ")
import { registerSuggestion } from './cc-kit'
TS
out=$(pc_switch_reads "$T/modsw/hooks/reads.ts")
if [ "$out" = CC_FX_DQ ]; then
  pass "switch-reads: a module's comments and import are not reads, a double-quoted env.get is"
else
  fail "switch-reads: a module's comments and import are not reads, a double-quoted env.get is" "got: ${out:-<empty>}"
fi
# generate.sh runs under pipefail; a piped early-exit match lost the switch past the pipe buffer.
{ printf 'kit.registerSuggestion(on, {})\n'; yes 'const filler = 1' | head -n 65536; } > "$T/modsw/hooks/big.ts"
out=$(set -o pipefail; pc_switch_reads "$T/modsw/hooks/big.ts")
if [ "$out" = CC_SUGGEST ]; then
  pass "switch-reads: a registerSuggestion( call in a 1 MB module still credits CC_SUGGEST under pipefail"
else
  fail "switch-reads: a registerSuggestion( call in a 1 MB module still credits CC_SUGGEST under pipefail" "got: ${out:-<empty>}"
fi
cat > "$T/modsw/hooks/mirror.sh" <<'SH'
#!/bin/bash
# mirrors the kit: registerSuggestion( and $.env.get('CC_FX_SH')
exit 0
SH
out=$(pc_switch_reads "$T/modsw/hooks/mirror.sh")
if [ -z "$out" ]; then
  pass "switch-reads: a .sh comment naming module reads earns no switch"
else
  fail "switch-reads: a .sh comment naming module reads earns no switch" "got: $out"
fi

# ---- pc_version_stamp_tail -----------------------------------------------------
mkskill() { mkdir -p "$T/$1/skills/$2"; cat > "$T/$1/skills/$2/SKILL.md"; }
mkskill badstamp pinner <<'MD'
---
name: pinner
description: Use when writing framework code — advice pinned to the installed version.
---

> Last verified: 2026-09-22 — https://example.invalid/releases

Body.
MD
mkskill okstamp pinner-tailed <<'MD'
---
name: pinner-tailed
description: Use when writing framework code — advice pinned to the installed version.
---

> Last verified: 2026-09-22 — https://example.invalid/releases — npm:example@9

Body.
MD
mkskill nostampclaim plain <<'MD'
---
name: plain
description: Use when doing a thing that makes no claim about versions at all.
---

Body.
MD
out=$(pc_version_stamp_tail "$T") || true
case "$out" in
  *"version-stamp-tail badstamp:pinner "*) pass "stamp-tail: a pinning claim with a tailless stamp is flagged" ;;
  *) fail "stamp-tail: a pinning claim with a tailless stamp is flagged" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *okstamp*) fail "stamp-tail: an npm: tail clears it" "flagged: $out" ;;
  *) pass "stamp-tail: an npm: tail clears it" ;;
esac
case "$out" in
  *nostampclaim*) fail "stamp-tail: a skill claiming no pinning is out of scope" "flagged: $out" ;;
  *) pass "stamp-tail: a skill claiming no pinning is out of scope" ;;
esac
printf '\n<!-- version-tail-ok: fixture -->\n' >> "$T/badstamp/skills/pinner/SKILL.md"
out=$(pc_version_stamp_tail "$T") || true
case "$out" in
  *badstamp*) fail "stamp-tail: '<!-- version-tail-ok: -->' silences it" "still flagged: $out" ;;
  *) pass "stamp-tail: '<!-- version-tail-ok: -->' silences it" ;;
esac

# ---- pc_rules_reachable: `command` rows (routing review 2026-09-26) --------------
# route.sh matches a `command` row's ERE against the Bash command string; a malformed one
# makes grep exit 2 on every call and the row can never fire, exactly like a content row.
printf 'command\t\\bzzprobe(@[^[:space:]]+\tzz-probe\tzz\thigh\n' > "$T/rules-cmd-bad.tsv"
printf 'command\t\\bzzprobe(@[^[:space:]]+)?[[:space:]]+add\\b\tzz-probe\tzz\thigh\n' > "$T/rules-cmd-ok.tsv"
out=$(pc_rules_reachable "$T/rules-cmd-bad.tsv") && r=0 || r=$?
case "$r:$out" in
  1:*"unreachable command "*zz-probe*) pass "reachable: a command row with a malformed ERE is named" ;;
  *) fail "reachable: a command row with a malformed ERE is named" "rc=$r got: ${out:-<empty>}" ;;
esac
out=$(pc_rules_reachable "$T/rules-cmd-ok.tsv") && r=0 || r=$?
[ "$r" -eq 0 ] && [ -z "$out" ] && pass "reachable: a well-formed command row stays clean" \
  || fail "reachable: a well-formed command row stays clean" "rc=$r got: $out"

# ---- pc_plugin_dependencies (suite retirement 2026-09-26) ------------------------
# No plugin may declare `dependencies`: an update that ADDS one leaves it uninstalled
# and the plugin fails to load (CLI 2.1.283). Its own root, so no other fixture's
# plugin.json can make an arm pass or fail by accident.
D="$T/deps"
mkpj() { mkdir -p "$D/$1/.claude-plugin"; printf '%s\n' "$2" > "$D/$1/.claude-plugin/plugin.json"; }
mkpj withdeps '{"name":"withdeps","version":"0.1.0","description":"d","dependencies":["dep-a","dep-b"]}'
mkpj emptydeps '{"name":"emptydeps","version":"0.1.0","description":"d","dependencies":[]}'
mkpj nodeps '{"name":"nodeps","version":"0.1.0","description":"d"}'
out=$(pc_plugin_dependencies "$D") && r=0 || r=$?
case "$r:$out" in
  1:*"plugin-dependencies withdeps dep-a dep-b"*) pass "deps: a plugin.json declaring dependencies is named, with its deps" ;;
  *) fail "deps: a plugin.json declaring dependencies is named, with its deps" "rc=$r got: ${out:-<empty>}" ;;
esac
case "$out" in
  *"plugin-dependencies emptydeps"*) pass "deps: an empty dependencies array still counts as declaring one" ;;
  *) fail "deps: an empty dependencies array still counts as declaring one" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *nodeps*) fail "deps: a plugin.json with no dependencies key stays clean" "flagged: $out" ;;
  *) pass "deps: a plugin.json with no dependencies key stays clean" ;;
esac
rm -rf "$D/withdeps" "$D/emptydeps"
out=$(pc_plugin_dependencies "$D") && r=0 || r=$?
[ "$r" -eq 0 ] && [ -z "$out" ] && pass "deps: a tree with no dependencies key anywhere returns 0 and prints nothing" \
  || fail "deps: a tree with no dependencies key anywhere returns 0 and prints nothing" "rc=$r got: $out"

# ---- pc_frontmatter: kind is the path's position, not a directory's name ----------
# One body at both paths: description-only frontmatter passes as a command and fails as
# an agent, so the agent-only FAIL line is what shows which kind a path was read as.
F="$T/fm"; deep=plugins/x/skills/y/references/agents/n.md; real=plugins/x/agents/n.md
mkdir -p "$F/${deep%/*}" "$F/${real%/*}"
printf -- '---\ndescription: A note.\n---\n\nBody.\n' | tee "$F/$deep" > "$F/$real"
fm_both() { # <path under $F>: the repo-relative form validate.sh passes, then the absolute one
  local a
  (cd "$F" && pc_frontmatter "$1"); a=$?
  pc_frontmatter "$F/$1"; return $((a + $?))
}
out=$(fm_both "$deep") && r=0 || r=$?
[ "$r" -eq 0 ] && [ -z "$out" ] && pass "frontmatter: a deep references/agents path is not an agent" \
  || fail "frontmatter: a deep references/agents path is not an agent" "rc=$r got: $out"
out=$(fm_both "$real") && r=0 || r=$?
case "$r:$out" in
  2:*"$real: frontmatter missing model:"*"$F/$real: frontmatter missing model:"*) pass "frontmatter: plugins/<p>/agents/<n>.md is still an agent" ;;
  *) fail "frontmatter: plugins/<p>/agents/<n>.md is still an agent" "rc=$r got: ${out:-<empty>}" ;;
esac
# The header's two residuals, pinned: a plugin-shaped tail under a deep path is skipped in
# the relative form (the anchor) and linted in the absolute one (matched from its end).
tail=plugins/x/skills/y/references/plugins/z/agents/n.md
mkdir -p "$F/${tail%/*}"; cp "$F/$real" "$F/$tail"
out=$(cd "$F" && pc_frontmatter "$tail") && r=0 || r=$?
out2=$(pc_frontmatter "$F/$tail") && r2=0 || r2=$?
case "$r:$out:$r2:$out2" in
  "0::1:"*"$F/$tail: frontmatter missing model:"*) pass "frontmatter: a plugin-shaped tail is skipped relative, linted absolute" ;;
  *) fail "frontmatter: a plugin-shaped tail is skipped relative, linted absolute" "rc=$r got: ${out:-<empty>} / rc=$r2 got: ${out2:-<empty>}" ;;
esac

# ---- pc_agent_tool_fit: an instruction the agent's tools cannot carry out ----------
# The true positives are V-44's two shapes (a reference the body names, telling a
# Read/Grep/Glob agent to hash and to write) plus a direct `run git`. Every neighbour below
# is a sentence the live tree carries and must stay silent.
A="$T/toolfit"
mkagent() { # <plugin> <name> <tools>, body on stdin
  mkdir -p "$A/$1/agents"
  { printf -- '---\nname: %s\ndescription: x\ntools: %s\nmodel: opus\n---\n\n' "$2" "$3"; cat; } > "$A/$1/agents/$2.md"
}
mkdir -p "$A/tf/skills/deck/references"
cat > "$A/tf/skills/deck/references/draw.md" <<'MD'
# Draw

1. Read the log.
2. When the log is absent, seed from a hash of the brief text plus
   today's date. A missing log is a first run, never an error.

Write the draw into `craft/record.md` as five lines.

The main thread writes the draw into `craft/record.md` before the
dispatch, and seeds from `printf '%s' "$brief" | cksum`.

```bash
git diff --stat > craft/diff.patch
```
MD
mkagent tf director 'Read, Grep, Glob' <<'MD'
Inputs: read `deck/references/draw.md` for the draw.

Run `git diff main` and read the patch.

You cannot run git; the dispatch gives you `git blame` output for each hunk.
The contrast pre-check is a craft gate — run it here. Run `/tf:research <idea>` first.
Return the record as text; you never write `notes.md`.

Name the lens in the divergence record you return.
MD
sed -n '/^Inputs/,$p' "$A/tf/agents/director.md" | mkagent tf granted 'Read, Grep, Glob, Bash, Write'
mkagent tf blessed 'Read, Grep, Glob' <<'MD'
Run `git log -L` on the touched hunk before you judge it. <!-- tool-fit-ok: fixture -->
MD
mkagent tf runner 'Read, Grep, Glob, Bash' <<'MD'
Run `npm test` and quote the output. Write the report to `out.md` when it is red.
MD
# Reviewer wording describes code or advises the user; a named SKILL.md instructs the main
# thread; a marker blesses its whole block and the fence below it.
printf '# Deck\n\n2. **Run `npx @tailwindcss/upgrade` on a new branch**.\n' > "$A/tf/skills/deck/SKILL.md"
mkagent tf reviewer 'Read, Grep, Glob' <<'MD'
Judge the deck against `deck/SKILL.md`.

Flag any handler that writes to `config.json` without a lock.
Flag a script that executes `bash -c` with user input.
Recommend the user run `npm audit` before the release.
Flag a download not verified with sha256sum.
The brief carries a cksum of the spec; quote it back.

Run `git diff main` and flag every hunk that writes to `config.json`.
Pipe the brief through `cksum` before you compare.

<!-- tool-fit-ok: fixture, the steps that built the input -->
- Run `git log -L` on the hunk.
- Run `npm test` and keep the output.

- Run `npm ci` before the review.

The input was built this way. <!-- tool-fit-ok: fixture -->

```bash
git status --short
```

Compare it with this:

```bash
git diff --stat
```
MD
# A demonstrative `that` leaves its verb an order; a bare hash tool with no code span, pipe or path is a noun.
mkagent tf briefed 'Read, Grep, Glob' <<'MD'
Read the brief. After that run `git diff` on each file.

Read the brief, do that then run `npm test`.

Verify the recorded cksum matches the one in the dispatch.

Use the sha256sum the brief quotes to name the file.

Take sha256sum dist/app.tgz and compare it with the brief.
MD
out=$(pc_agent_tool_fit "$A") && r=0 || r=$?
want_tf() { # <label> <substring>
  case "$out" in *"$2"*) pass "tool-fit: $1" ;; *) fail "tool-fit: $1" "missing '$2' in: ${out:-<empty>}" ;; esac
}
none_tf() { # <label> <substring>
  case "$out" in *"$2"*) fail "tool-fit: $1" "named: $(printf '%s\n' "$out" | grep -F -- "$2")" ;; *) pass "tool-fit: $1" ;; esac
}
want_tf "a direct 'Run \`git diff\`' in a Bash-less body is named at its line" "tool-fit tf:director lacks Bash — $A/tf/agents/director.md:10: Run \`git diff main\`"
want_tf "a hash step in a reference the body names is named at its line (V-44)" "tool-fit tf:director lacks Bash — $A/tf/skills/deck/references/draw.md:4: When the log is absent, seed from a hash"
want_tf "a write step in that reference is named (V-44)" "tool-fit tf:director lacks Write — $A/tf/skills/deck/references/draw.md:7: Write the draw into \`craft/record.md\`"
want_tf "a Bash agent with no Write is named for the write only" "tool-fit tf:runner lacks Write"
RV="tool-fit tf:reviewer lacks"
none_tf "'a handler that writes to \`x.json\`' describes code, not a write order" "Flag any handler that writes"
none_tf "'a script that executes \`bash -c\`' describes code, not a run order" "Flag a script that executes"
none_tf "'recommend the user run \`npm audit\`' advises the user" "Recommend the user run"
none_tf "a bare sha256sum with no verb before it is silent" "not verified with sha256sum"
none_tf "a bare cksum as a noun is silent" "The brief carries a cksum"
none_tf "a SKILL.md the body names is not followed" "deck/SKILL.md"
none_tf "a marker line above a list blesses its first item" "$A/tf/agents/reviewer.md:20:"
none_tf "a marker line above a list blesses its later items" "$A/tf/agents/reviewer.md:21:"
none_tf "a marker in the block above a \`\`\`bash fence blesses the fence" "$A/tf/agents/reviewer.md:27: a \`\`\`shell block"
want_tf "a run order beside a relative clause still fires" "$RV Bash — $A/tf/agents/reviewer.md:16: Run \`git diff main\` and flag every hunk"
want_tf "a hash tool after a verb fires" "$RV Bash — $A/tf/agents/reviewer.md:17: Pipe the brief through \`cksum\`"
want_tf "a list past the blessed block's blank line fires" "$RV Bash — $A/tf/agents/reviewer.md:23: - Run \`npm ci\`"
want_tf "an unblessed \`\`\`bash fence in an agent body fires" "$RV Bash — $A/tf/agents/reviewer.md:33: a \`\`\`shell block"
BR="tool-fit tf:briefed lacks Bash — $A/tf/agents/briefed.md"
want_tf "'After that run \`git diff\`': a demonstrative that leaves the order" "$BR:8: After that run"
want_tf "'do that then run \`npm test\`': a demonstrative that leaves the order" "$BR:10: Read the brief, do that then run"
none_tf "'verify the recorded cksum matches' names a value, not a run" "$BR:12:"
none_tf "'use the sha256sum the brief quotes' names a value, not a run" "$BR:14:"
want_tf "a bare hash tool followed by a path fires" "$BR:16: Take sha256sum dist/app.tgz"
n_tf=$(printf '%s\n' "$out" | grep -c '^tool-fit ')
[ "$r" -eq 1 ] && [ "$n_tf" -eq 11 ] \
  && pass "tool-fit: the neighbours stay silent — negation, the main thread as actor, a fenced sample, 'run it here', a slash command, an implied write, a full grant, the marker, a granted Bash, reviewer wording" \
  || fail "tool-fit: the neighbours stay silent" "rc=$r, $n_tf lines, want 11: $out"
rm -rf "$A/tf/agents/director.md" "$A/tf/agents/runner.md" "$A/tf/agents/reviewer.md" "$A/tf/agents/briefed.md"
out=$(pc_agent_tool_fit "$A") && r=0 || r=$?
[ "$r" -eq 0 ] && [ -z "$out" ] && pass "tool-fit: a tree with nothing to name returns 0 and prints nothing" \
  || fail "tool-fit: a tree with nothing to name returns 0 and prints nothing" "rc=$r got: $out"
grep -v '^[[:space:]]*#' scripts/validate.sh | grep -qF 'toolfit_gap=$(pc_agent_tool_fit plugins)' \
  && grep -v '^[[:space:]]*#' scripts/validate.sh | grep -qF '[ -n "$toolfit_gap" ] && lane_err "$toolfit_gap"' \
  && pass "tool-fit: wiring — validate.sh calls pc_agent_tool_fit and fails on its output" \
  || fail "tool-fit: wiring" "validate.sh lacks the pc_agent_tool_fit call or its lane_err"

[ "$rc" -eq 0 ] && echo "All panel gate-fixture asserts passed."
exit "$rc"
