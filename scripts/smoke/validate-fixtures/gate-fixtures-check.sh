#!/usr/bin/env bash
# Fixture harness for the checks the 2026-09-22 specialist panel added to
# scripts/lib/plugin-checks.sh — pc_cwd_validated (#2), pc_offswitch_named (#5) and
# pc_version_stamp_tail (#21) — plus pc_state_root and pc_shared_blocks from the
# 2026-09-25 session review, pc_plugin_dependencies from the 2026-09-26 suite
# retirement, pc_agent_tool_fit from the 2026-10-13 session retro, and pc_gating_catch and
# pc_plugin_root_quoting from the 2026-10-15 host review, with official-validate.sh's report
# handling and turn-cost.sh's catalog prices from its re-review. Each gets BOTH arms: a planted violation that must be
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
qhooks() { # $1 = command prefix/suffix quote character ('' or '"'), $2 = interpreter prefix ('', 'bash ', 'sh ')
  jq -n --arg q "$1" --arg i "${2:-}" '{hooks:{
    UserPromptSubmit:[{hooks:[{type:"command",command:($i+$q+"${CLAUDE_PLUGIN_ROOT}/hooks/remind.sh"+$q)}]}],
    Stop:[{hooks:[{type:"command",command:($i+$q+"${CLAUDE_PLUGIN_ROOT}/hooks/gate.sh"+$q),timeout:5}]}],
    PreToolUse:[{matcher:"Edit",hooks:[{type:"command",command:($i+$q+"${CLAUDE_PLUGIN_ROOT}/hooks/deny.sh"+$q),timeout:5}]}]}}' \
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

# ---- interpreter-led hook commands: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/x.sh"` --------------
# 2026-10-15: command-guard 0.9.0 starts destructive-guard through the bash on PATH, so a host
# with no /bin/bash still runs it, and every hooks.json reader but pc_state_root matched only a
# command opening on ${CLAUDE_PLUGIN_ROOT}: they went silent on that hook. The same fixture led
# by `bash` or `sh` must draw the quoted form's findings, except from pc_hook_shebang, which
# skips an interpreter-led command by decision (its header): the host never reads that shebang.
no_shebang() { printf '%s\n' "$1" | awk '/^== /{skip=($2=="pc_hook_shebang")} !skip'; }
qhooks '"' 'bash '; bsh=$(qrun)
qhooks '' 'sh '; ssh_=$(qrun)
qhooks '"'
for form in bash sh; do
  if [ "$form" = bash ]; then got=$bsh; else got=$ssh_; fi
  if [ "$(no_shebang "$quo")" = "$(no_shebang "$got")" ]; then pass "interpreter-led ($form): every other hooks.json reader agrees with the quoted form"
  else fail "interpreter-led ($form): every other hooks.json reader agrees with the quoted form" "$(diff <(no_shebang "$quo") <(no_shebang "$got") | head -8)"; fi
  case "$got" in *"hook-shebang"*) fail "interpreter-led ($form): pc_hook_shebang skips it" "$(printf '%s' "$got" | grep hook-shebang)" ;;
    *) pass "interpreter-led ($form): pc_hook_shebang skips it" ;; esac
done

# Every resolver on one interpreter-led fixture, each with a finding to make: a check that
# draws nothing here proves nothing about the form. ig.sh is not executable and opens on an
# env shebang, which the interpreter-led form makes irrelevant; the path-led twin names both.
IR="$T/_interp"; mkdir -p "$IR/ifix/hooks"
cat > "$IR/ifix/hooks/ig.sh" <<'SH'
#!/usr/bin/env bash
input=$(cat)
[ "${CC_IFIX_GUARD:-on}" = off ] && exit 0
cwd=$(printf %s "$input" | jq -r .cwd)
mkdir -p "$cwd/.claude/x"
tp=$(printf %s "$input" | jq -r .transcript_path)
marker="/tmp/ifix-$tp"
jq -cn '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"fixture: refused."}}'
exit 0
SH
printf '#!/bin/bash\nsid=$(jq -r .session_id)\nexit 0\n' > "$IR/ifix/hooks/pk.sh"
printf '#!/bin/bash\nexit 0\n' > "$IR/ifix/hooks/dg.sh"
chmod 644 "$IR/ifix/hooks/ig.sh"; chmod +x "$IR/ifix/hooks/pk.sh" "$IR/ifix/hooks/dg.sh"
printf 'ifix:ig\thook\tbuild\tfixture-territory\ta fixture\t-\n' > "$IR/ifix/lane.tsv"
ihooks() { # $1 = interpreter prefix ('' for the path-led twin)
  jq -n --arg i "$1" '{hooks:{
    PreToolUse:[{matcher:"Edit",hooks:[{type:"command",command:($i+"\"${CLAUDE_PLUGIN_ROOT}/hooks/ig.sh\""),timeout:5},
                                       {type:"command",command:($i+"\"${CLAUDE_PLUGIN_ROOT}/hooks/missing.sh\""),timeout:5}]}],
    PostToolUse:[{matcher:"Edit",hooks:[{type:"command",command:($i+"\"${CLAUDE_PLUGIN_ROOT}/hooks/pk.sh\""),timeout:5}]}],
    Stop:[{hooks:[{type:"command",command:($i+"${CLAUDE_PLUGIN_ROOT}/hooks/dg.sh"),timeout:5}]}]}}' > "$IR/ifix/hooks/hooks.json"
}
iwant() { # <label> <function> <substring>, against the interpreter-led fixture
  local out; out=$("$2" "$IR" 2>&1) || true
  case "$out" in *"$3"*) pass "interpreter-led: $1" ;; *) fail "interpreter-led: $1" "got: ${out:-<empty>}" ;; esac
}
inone() { # <label> <function> <substring>
  local out; out=$("$2" "$IR" 2>&1) || true
  case "$out" in *"$3"*) fail "interpreter-led: $1" "got: $out" ;; *) pass "interpreter-led: $1" ;; esac
}
ihooks 'bash '
iwant "pc_hook_exec names a missing script" pc_hook_exec "ifix/hooks/missing.sh missing or not executable"
inone "pc_hook_exec needs no exec bit" pc_hook_exec "ifix/hooks/ig.sh"
inone "pc_hook_shebang skips the env shebang" pc_hook_shebang "hook-shebang ifix:ig.sh"
iwant "pc_offswitch_named" pc_offswitch_named "offswitch-unnamed ifix:ig.sh CC_IFIX_GUARD"
iwant "pc_cwd_validated" pc_cwd_validated "cwd-unvalidated ifix:ig.sh"
iwant "pc_state_root" pc_state_root "state-root-raw ifix:ig.sh"
iwant "pc_phase_guard" pc_phase_guard "phase-unguarded ifix:ig.sh"
iwant "pc_marker_key" pc_marker_key "marker-key-unhashed ifix:ig.sh"
iwant "pc_context_key" pc_context_key "context-keyed-on-session ifix:pk.sh"
iwant "pc_lanes_coverage (unquoted path)" pc_lanes_coverage "lane-missing hook ifix:dg"
ihooks 'sh '
iwant "pc_hook_exec names a missing script (sh)" pc_hook_exec "ifix/hooks/missing.sh missing or not executable"
iwant "pc_offswitch_named (sh)" pc_offswitch_named "offswitch-unnamed ifix:ig.sh CC_IFIX_GUARD"
ihooks ''
iwant "path-led twin: pc_hook_exec wants the exec bit" pc_hook_exec "ifix/hooks/ig.sh missing or not executable"
iwant "path-led twin: pc_hook_shebang names the env shebang" pc_hook_shebang "hook-shebang ifix:ig.sh"
rm -rf "$IR"

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
# A Stop block printed as {"decision":"block",…} with exit 0 refuses like exit 2: ask-ledger's gate.sh, as shipped and with its
#   reason's switch sentence reworded away, plus a printf of raw JSON.
mkhook askloud gate.sh < plugins/ask-ledger/hooks/gate.sh
sed 's/CC_ASK_LEDGER=off turns this check off/this check can be turned off/' plugins/ask-ledger/hooks/gate.sh | mkhook askquiet gate.sh
mkhook rawquiet stop-block.sh <<'SH'
#!/bin/bash
input=$(cat)
[ "${CC_FIXTURE_STOP:-on}" = off ] && exit 0
printf '%s\n' '{"decision":"block","reason":"fixture: refused."}'
exit 0
SH
out=$(pc_offswitch_named "$T") || true
case "$out" in
  *"offswitch-unnamed askquiet:gate.sh CC_ASK_LEDGER"*) pass "offswitch: ask-ledger's JSON Stop block with its switch named nowhere is flagged" ;;
  *) fail "offswitch: ask-ledger's JSON Stop block with its switch named nowhere is flagged" "got: ${out:-<empty>}" ;;
esac
case "$out" in
  *askloud*) fail "offswitch: ask-ledger's JSON Stop block naming CC_ASK_LEDGER in its reason is clean" "flagged: $out" ;;
  *) pass "offswitch: ask-ledger's JSON Stop block naming CC_ASK_LEDGER in its reason is clean" ;;
esac
case "$out" in
  *"offswitch-unnamed rawquiet:stop-block.sh CC_FIXTURE_STOP"*) pass "offswitch: a raw \"decision\":\"block\" printf with its switch named nowhere is flagged" ;;
  *) fail "offswitch: a raw \"decision\":\"block\" printf with its switch named nowhere is flagged" "got: ${out:-<empty>}" ;;
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

# ---- pc_gating_catch: a mod gating hook with no .catch (host review 2026-10-15) -------
# The report shape is CLI 2.1.300's `claude plugin validate --strict --json` for a module
# registering `on('tool.call', …)` with and without `.catch` — the host exits 0 on both.
G="$T/gating"; mkdir -p "$G"
cat > "$G/nocatch.json" <<'JSON'
{"success":true,"strict":true,"manifest":{"type":"plugin","errors":[],"warnings":[],"gatingHooks":[]},
 "contents":[{"file":"p/hooks/hooks.json","type":"hooks","errors":[],"warnings":[],"gatingHooks":[
  {"module":"./gate.ts","pattern":"tool.call","hook":"tool.call","hasCatch":false},
  {"module":"./gate.ts","pattern":"prompt.submit","hook":"prompt.submit","hasCatch":true}]}],"advice":[]}
JSON
sed 's/"hasCatch":false/"hasCatch":true/' "$G/nocatch.json" > "$G/caught.json"
printf '%s\n' '{"success":true,"manifest":{"errors":[],"warnings":[]},"contents":[]}' > "$G/old-cli.json"
printf 'Validation passed\n' > "$G/human.txt"
: > "$G/empty.json"
out=$(pc_gating_catch "$G/nocatch.json") && r=0 || r=$?
[ "$r" -eq 1 ] && [ "$out" = "./gate.ts tool.call" ] \
  && pass "gating: a hasCatch:false hook is named, its caught sibling is not" \
  || fail "gating: a hasCatch:false hook is named, its caught sibling is not" "rc=$r got: ${out:-<empty>}"
out=$(pc_gating_catch "$G/caught.json") && r=0 || r=$?
[ "$r" -eq 0 ] && [ -z "$out" ] && pass "gating: every hook caught returns 0 and prints nothing" \
  || fail "gating: every hook caught returns 0 and prints nothing" "rc=$r got: $out"
out=$(pc_gating_catch "$G/old-cli.json") && r=0 || r=$?
[ "$r" -eq 0 ] && pass "gating: a report with no gatingHooks key (CLI < 2.1.290) passes — the residual its header names" \
  || fail "gating: a report with no gatingHooks key passes" "rc=$r got: $out"
for g in human.txt empty.json; do
  out=$(pc_gating_catch "$G/$g") && r=0 || r=$?
  case "$r:$out" in
    1:"unreadable report "*) pass "gating: $g is unreadable and fails rather than passing" ;;
    *) fail "gating: $g is unreadable and fails rather than passing" "rc=$r got: ${out:-<empty>}" ;;
  esac
done
grep -v '^[[:space:]]*#' scripts/official-validate.sh | grep -qF 'nocatch=$(pc_gating_catch "$out")' \
  && grep -v '^[[:space:]]*#' scripts/official-validate.sh | grep -qF 'claude plugin validate --strict --json "$p"' \
  && pass "gating: wiring — official-validate.sh runs pc_gating_catch on each plugin's --json report" \
  || fail "gating: wiring" "official-validate.sh lacks the --json run or the pc_gating_catch call"

# ---- official-validate.sh: one --json run per plugin, its findings printed, its verdict kept ----
# A stub `claude` answers like 2.1.300 does (both modes, the bad plugin failing in each) and logs
# every call; the script runs from a copy whose plugins/ holds one clean and one failing plugin.
OV="$T/ov"
mkdir -p "$OV/scripts/lib" "$OV/bin" "$OV/.claude-plugin" "$OV/plugins/good/.claude-plugin" "$OV/plugins/bad/.claude-plugin"
cp scripts/official-validate.sh scripts/host-constants.sh scripts/removed-plugins.tsv "$OV/scripts/"
cp scripts/lib/plugin-checks.sh "$OV/scripts/lib/"
echo '{}' > "$OV/plugins/good/.claude-plugin/plugin.json"; echo '{}' > "$OV/plugins/bad/.claude-plugin/plugin.json"
cat > "$OV/bin/claude" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$OV_CALLS"
case "$*" in
  --version) echo "2.1.300 (Claude Code)" ;;
  *marketplace.json) exit 0 ;;
  *--json*plugins/bad/) cat <<'J'; exit 1 ;;
{"success":false,"strict":true,"manifest":{"file":"/p/bad/.claude-plugin/plugin.json","errors":[{"path":"name","message":"Plugin name cannot contain spaces"}],"warnings":[],"gatingHooks":[]},
 "contents":[{"file":"/p/bad/hooks/hooks.json","errors":[],"warnings":[{"path":"hooks.Stop","message":"Shell command uses ${CLAUDE_PLUGIN_ROOT} without quotes"}],"gatingHooks":[]}],"advice":[]}
J
  *--json*plugins/garbled/) echo "Segmentation fault"; exit 1 ;;
  *--json*plugins/lying/) echo '{"success":false,"manifest":{"errors":[],"warnings":[]},"contents":[]}' ;;
  *--json*) echo '{"success":true,"manifest":{"errors":[],"warnings":[],"gatingHooks":[]},"contents":[]}' ;;
  *plugins/bad/) echo "  ❯ name: Plugin name cannot contain spaces"; exit 1 ;;
  *) echo "✔ Validation passed" ;;
esac
SH
chmod +x "$OV/bin/claude"
ov_run() { : > "$T/ov-calls"; OV_CALLS="$T/ov-calls" PATH="$OV/bin:$PATH" bash "$OV/scripts/official-validate.sh" 2>&1; }
out=$(ov_run) && r=0 || r=$?
n_good=$(grep -c ' plugins/good/$' "$T/ov-calls"); n_bad=$(grep -c ' plugins/bad/$' "$T/ov-calls")
[ "$n_good" -eq 1 ] && [ "$n_bad" -eq 1 ] \
  && pass "official-validate: one validator run per plugin" \
  || fail "official-validate: one validator run per plugin" "good=$n_good bad=$n_bad: $(cat "$T/ov-calls")"
case "$r:$out" in
  1:*"FAIL: plugins/bad/"*"error: name: Plugin name cannot contain spaces"*"warning: hooks.Stop: Shell command uses"*)
    printf '%s\n' "$out" | grep -q '^FAIL: plugins/good/' \
      && fail "official-validate: a failing plugin fails with its findings printed" "the clean plugin failed too: $out" \
      || pass "official-validate: a failing plugin fails with its findings printed, the clean one passes" ;;
  *) fail "official-validate: a failing plugin fails with its findings printed" "rc=$r got: $out" ;;
esac
mv "$OV/plugins/bad" "$OV/plugins/garbled"
out=$(ov_run) && r=0 || r=$?
case "$r:$out" in
  1:*"FAIL: plugins/garbled/"*"Segmentation fault"*) pass "official-validate: a report jq cannot read fails and prints the raw output" ;;
  *) fail "official-validate: a report jq cannot read fails and prints the raw output" "rc=$r got: $out" ;;
esac
mv "$OV/plugins/garbled" "$OV/plugins/lying"
out=$(ov_run) && r=0 || r=$?
case "$r:$out" in
  1:*"FAIL: plugins/lying/"*) pass "official-validate: success:false fails even on exit 0" ;;
  *) fail "official-validate: success:false fails even on exit 0" "rc=$r got: $out" ;;
esac
rm -rf "$OV/plugins/lying"
out=$(ov_run) && r=0 || r=$?
case "$r:$out" in
  0:*"OK: official validator"*) pass "official-validate: a clean tree passes" ;;
  *) fail "official-validate: a clean tree passes" "rc=$r got: $out" ;;
esac

# ---- turn-cost.sh: older catalog models priced from the CLI 2.1.300 catalog, not the fallback ----
# One request of 1M input + 1M output + 1M cache-read tokens costs input + output + read rates.
for mc in claude-opus-4-1-20250805:91.5 claude-opus-4-20250514:91.5 claude-opus-4-5-20251101:30.5 \
          claude-sonnet-4-5-20250929:18.3 claude-sonnet-4-20250514:18.3 claude-3-7-sonnet-20250219:18.3 \
          claude-3-5-sonnet-20241022:18.3 claude-3-5-haiku-20241022:4.88 claude-made-up-9:30.5; do
  m=${mc%:*} want=${mc##*:}
  TH="$T/tc-$m"; mkdir -p "$TH/.claude/projects/p"
  printf '{"cwd":"/w","message":{"model":"%s","usage":{"input_tokens":1000000,"output_tokens":1000000,"cache_read_input_tokens":1000000}}}\n' "$m" \
    > "$TH/.claude/projects/p/s.jsonl"
  got=$(HOME="$TH" bash scripts/turn-cost.sh --json 2>/dev/null | jq -r '.usd')
  [ "$got" = "$want" ] && pass "turn-cost: $m costs \$$want" || fail "turn-cost: $m costs \$$want" "got: ${got:-<empty>}"
done
TH="$T/tc-claude-made-up-9"
HOME="$TH" bash scripts/turn-cost.sh 2>/dev/null | grep -q 'not in the table.*claude-made-up-9' \
  && pass "turn-cost: a model outside the table is still named" \
  || fail "turn-cost: a model outside the table is still named" "$(HOME="$TH" bash scripts/turn-cost.sh 2>&1 | tail -5)"

# ---- pc_plugin_root_quoting: an unquoted ${CLAUDE_PLUGIN_ROOT} on a runnable line -------
Q="$T/quoting"
mkdir -p "$Q/qbad/commands" "$Q/qbad/skills/s/references" "$Q/qbad/agents" "$Q/qok/commands"
cat > "$Q/qbad/commands/run.md" <<'MD'
# Run

Inline: run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/a.sh --x` now.
Prose span: the doc lives at `${CLAUDE_PLUGIN_ROOT}/skills/s/SKILL.md`.
Prose, no span: run bash ${CLAUDE_PLUGIN_ROOT}/scripts/a.sh by hand.
Quoted: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/a.sh"`.
Second span: see `x` then `python3 -I ${CLAUDE_PLUGIN_ROOT}/s.py`.
Injected: !`node $CLAUDE_PLUGIN_ROOT/s.mjs`
Not an interpreter: `zsh ${CLAUDE_PLUGIN_ROOT}/s.sh`, `npx ${CLAUDE_PLUGIN_ROOT}/s`.

```bash
out=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/b.sh)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/b.sh"
```
~~~
sh ${CLAUDE_PLUGIN_ROOT}/c.sh
~~~
By path: run `${CLAUDE_PLUGIN_ROOT}/scripts/p.sh status`.
Bare script: `${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh` prints a table.
Sudo: `sudo ${CLAUDE_PLUGIN_ROOT}/w.sh`.
Env: `env -i X="a b" ${CLAUDE_PLUGIN_ROOT}/w.sh`.
Option end: `bash -- ${CLAUDE_PLUGIN_ROOT}/o.sh`.
Long option: `python3 --no-site ${CLAUDE_PLUGIN_ROOT}/o.py`.
Spans across lines: the gate —
  `${CLAUDE_PLUGIN_ROOT}/scripts/gate.sh --changed "<the
  files>"`, then a span opened at the end of a line `
  ${CLAUDE_PLUGIN_ROOT}/scripts/next.sh --x`.
Unclosed: a lone `

${CLAUDE_PLUGIN_ROOT}/x.sh --y` would read as a span if the blank line did not end it.

```sh
x=1 && ${CLAUDE_PLUGIN_ROOT}/f.sh
${CLAUDE_PLUGIN_ROOT}/g.sh --y
cat ${CLAUDE_PLUGIN_ROOT}/notes.txt
```

````markdown
```bash
bash ${CLAUDE_PLUGIN_ROOT}/inner.sh
```
````
After the four-backtick fence: bash ${CLAUDE_PLUGIN_ROOT}/prose.sh is prose again.
MD
printf 'Intro.\n\n```\npython ${CLAUDE_PLUGIN_ROOT}/r.py <dir>\n```\n' > "$Q/qbad/skills/s/references/r.md"
printf -- '---\nname: a\n---\nRun `bash ${CLAUDE_PLUGIN_ROOT}/x.sh`.\n' > "$Q/qbad/agents/a.md"
printf 'Run `bash ${CLAUDE_PLUGIN_ROOT}/x.sh`.\n' > "$Q/qbad/README.md"
printf 'Run `bash "${CLAUDE_PLUGIN_ROOT}/x.sh"` and `node "$CLAUDE_PLUGIN_ROOT/y.mjs"`, then `"${CLAUDE_PLUGIN_ROOT}/p.sh" status`.\n' > "$Q/qok/commands/ok.md"
out=$(pc_plugin_root_quoting "$Q") && r=0 || r=$?
# 18-23 run a script by path or through a wrapper or option word, 25 and 27 are spans that
# continue onto the next line (task-runner run.md's behavioral-gate line), 33-34 fenced lines
# in command position, 40 a line inside a ```` fence after an inner ```bash opener.
for want in "commands/run.md:3" "commands/run.md:7" "commands/run.md:8" "commands/run.md:12" \
            "commands/run.md:16" "skills/s/references/r.md:4" \
            "commands/run.md:18" "commands/run.md:19" "commands/run.md:20" "commands/run.md:21" \
            "commands/run.md:22" "commands/run.md:23" "commands/run.md:25" "commands/run.md:27" \
            "commands/run.md:33" "commands/run.md:34" "commands/run.md:40"; do
  printf '%s\n' "$out" | grep -qxF "plugin-root-unquoted qbad $want" \
    && pass "root-quoting: qbad $want is named" || fail "root-quoting: qbad $want is named" "got: ${out:-<empty>}"
done
n_q=$(printf '%s\n' "$out" | grep -c '^plugin-root-unquoted ')
[ "$r" -eq 1 ] && [ "$n_q" -eq 17 ] \
  && pass "root-quoting: the neighbours stay silent — a doc-path span, prose, an argument, quoted paths, zsh/npx, an unclosed backtick, agents, README, a clean plugin" \
  || fail "root-quoting: the neighbours stay silent" "rc=$r, $n_q lines, want 17: $out"
rm -rf "$Q/qbad"
out=$(pc_plugin_root_quoting "$Q") && r=0 || r=$?
[ "$r" -eq 0 ] && [ -z "$out" ] && pass "root-quoting: a tree with nothing to name returns 0 and prints nothing" \
  || fail "root-quoting: a tree with nothing to name returns 0 and prints nothing" "rc=$r got: $out"
grep -v '^[[:space:]]*#' scripts/validate.sh | grep -qF 'quote_gap=$(pc_plugin_root_quoting plugins)' \
  && grep -v '^[[:space:]]*#' scripts/validate.sh | grep -qF 'err "plugin-root-unquoted $qp' \
  && pass "root-quoting: wiring — validate.sh calls pc_plugin_root_quoting at FAIL tier" \
  || fail "root-quoting: wiring" "validate.sh lacks the pc_plugin_root_quoting call or its err"
# Run validate.sh's own block, cut from the live script, against a fixture plugins/ tree.
sed -n '/^quote_gap=\$(pc_plugin_root_quoting plugins)/,/^fi$/p' scripts/validate.sh > "$T/quote-block.sh"
mkdir -p "$Q/run/plugins/qbad/commands" "$Q/clean/plugins/qok/commands"
printf 'Run `bash ${CLAUDE_PLUGIN_ROOT}/x.sh`.\n' > "$Q/run/plugins/qbad/commands/run.md"
printf 'Run `bash "${CLAUDE_PLUGIN_ROOT}/x.sh"`.\n' > "$Q/clean/plugins/qok/commands/ok.md"
quote_block() { # <fixture root>: prints the block's stderr, then fail=<0|1>
  ( cd "$1" || exit 2; fail=0
    err() { echo "FAIL: $1" >&2; fail=1; }; warn() { echo "WARN: $1" >&2; }
    . "$T/quote-block.sh"; echo "fail=$fail" ) 2>&1
}
out=$(quote_block "$Q/run")
case "$out" in
  "FAIL: plugin-root-unquoted qbad: commands/run.md:1 "*"fail=1") pass "root-quoting: validate.sh's block FAILs an unquoted path" ;;
  *) fail "root-quoting: validate.sh's block FAILs an unquoted path" "got: ${out:-<empty>}" ;;
esac
out=$(quote_block "$Q/clean")
[ "$out" = "fail=0" ] && pass "root-quoting: validate.sh's block passes a quoted path silently" \
  || fail "root-quoting: validate.sh's block passes a quoted path silently" "got: ${out:-<empty>}"

[ "$rc" -eq 0 ] && echo "All panel gate-fixture asserts passed."
exit "$rc"
