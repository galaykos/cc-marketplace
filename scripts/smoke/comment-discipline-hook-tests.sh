#!/usr/bin/env bash
# scripts/smoke/comment-discipline-hook-tests.sh
#
# Pins the contract of plugins/code-review/hooks/scan.sh (the comment-discipline skill's
# hook; the standalone plugin was folded into code-review on 2026-09-02) — a warn-only PostToolUse
# guard. Three properties, each of which fails silently in production if it regresses:
#   1. FIRES  on the six high-confidence noise patterns, across all three tool shapes
#   2. SILENT on every keep-case, on exempt paths/extensions, and on unknown tools
#   3. FAIL-OPEN — malformed stdin, empty stdin, and a jq-free PATH exit 0 with no output
# The jq-free case uses a clean bin of coreutils symlinks so it exercises genuine absence.
# Companion to scripts/smoke/hook-guard-tests.sh, which covers the remind.sh guards.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CHASSIS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
HOOK="$ROOT/plugins/code-review/hooks/scan.sh"
BASH_BIN="$(command -v bash)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
unset CLAUDE_PLUGIN_DATA   # the cases read hook state under <root>/.claude
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; rc=1; }

[ -f "$HOOK" ] || { printf 'comment-discipline-hook-tests: %s missing\n' "$HOOK" >&2; exit 2; }
[ -x "$HOOK" ] || fail "hook is executable" "not +x"

NOJQ="$WORK/nojq-bin"; mkdir -p "$NOJQ"
for u in cat grep sed awk tr head cut env sh expr dirname basename printf; do
  p="$(command -v "$u" 2>/dev/null)" && ln -s "$p" "$NOJQ/$u" 2>/dev/null
done
if PATH="$NOJQ" command -v jq >/dev/null 2>&1; then
  printf 'comment-discipline-hook-tests: could not build a jq-free PATH; aborting\n' >&2; exit 2
fi

# Build a PostToolUse envelope without depending on the shape of the caller's quoting.
envelope() { # tool  file_path  added-text  [shape: content|new_string|edits]
  python3 - "$@" <<'PY'
import json, sys
tool, path, added = sys.argv[1], sys.argv[2], sys.argv[3]
shape = sys.argv[4] if len(sys.argv) > 4 else "content"
ti = {"file_path": path}
if shape == "edits":
    ti["edits"] = [{"new_string": part} for part in added.split("\x00")]
else:
    ti[shape] = added
print(json.dumps({"cwd": "/tmp/proj", "tool_name": tool, "tool_input": ti}))
PY
}
envelope_at() { # cwd  file_path  added-text
  envelope Write "$2" "$3" | jq -c --arg c "$1" '.cwd = $c'
}

run() { printf '%s' "$1" | "$BASH_BIN" "$HOOK" 2>/dev/null; }

assert_fires() { # desc  json  expected-category-substring
  local desc="$1" out ctx
  out="$(run "$2")"
  if [ -z "$out" ]; then fail "$desc" "wanted a warning, got silence"; return; fi
  # The warning travels in the PostToolUse envelope — plain stdout never reaches the
  # model. Unwrap it before matching, the same way scope-hook.test.sh does.
  if ! printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1; then
    fail "$desc" "stdout is not a PostToolUse envelope: $out"; return
  fi
  ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')"
  if [ -z "$ctx" ]; then fail "$desc" "envelope carries no additionalContext: $out"; return; fi
  out="$ctx"
  case "$out" in
    comment-discipline:*) ;;
    *) fail "$desc" "warning not prefixed 'comment-discipline:': $out"; return ;;
  esac
  case "$out" in
    *"$3"*) pass "$desc" ;;
    *) fail "$desc" "wanted category '$3', got: $out" ;;
  esac
}

assert_silent() { # desc  json
  local desc="$1" out rc_
  out="$(printf '%s' "$2" | "$BASH_BIN" "$HOOK" 2>/dev/null)"; rc_=$?
  if [ "$rc_" -ne 0 ]; then fail "$desc" "exit $rc_ (want 0)"; return; fi
  if [ -n "$out" ]; then fail "$desc" "wanted silence, spoke: $out"; return; fi
  pass "$desc"
}

# ---- 1. fires on the six patterns, across all three tool shapes ---------------------
assert_fires "fires: comment restating the next line (Write/content)" \
  "$(envelope Write /tmp/proj/a.js '// increment the counter
counter++;')" "restating the next line"

assert_fires "fires: section banner (Edit/new_string)" \
  "$(envelope Edit /tmp/proj/a.php '// ==== HELPERS ====
$x = 1;' new_string)" "section banner"

assert_fires "fires: commented-out code (MultiEdit/edits)" \
  "$(envelope MultiEdit /tmp/proj/a.py 'def f():
    pass
# doThing();' edits)" "commented-out code"

assert_fires "fires: bare TODO with no ticket" \
  "$(envelope Write /tmp/proj/a.ts '// TODO: fix this
const x = 1;')" "bare TODO"

assert_fires "fires: docblock tag repeating the signature" \
  "$(envelope Write /tmp/proj/a.php '/**
 * @param $id The id
 */
function f($id) {}')" "docblock tag repeating the signature"

assert_fires "fires: getter comment restating the name" \
  "$(envelope Write /tmp/proj/a.js '// get the user by id
function getUserById(id) {}')" "restating the next line"

assert_fires "fires: change-narration — now correctly handles" \
  "$(envelope Write /tmp/proj/a.ts '// now correctly handles null input
if (x == null) return [];')" "change-narration"

assert_fires "fires: change-narration — updated to use, per review (Edit/new_string)" \
  "$(envelope Edit /tmp/proj/a.js '// updated to use the shared client per review feedback
const c = sharedClient();' new_string)" "change-narration"

assert_fires "fires: change-narration — this fix ensures" \
  "$(envelope Write /tmp/proj/a.py '# this fix ensures the retry loop terminates
attempts = 0')" "change-narration"

assert_fires "fires: change-narration — added X (diff voice)" \
  "$(envelope Write /tmp/proj/a.js '// added null check
if (x == null) return;')" "change-narration"

# ---- 2. silent on every keep-case ---------------------------------------------------
assert_silent "keep: why / rejected alternative" \
  "$(envelope Write /tmp/proj/a.js '// Sequential, not Promise.all: the vendor rate-limits concurrent calls.
for (const id of ids) await fetchOne(id);')"

assert_silent "keep: external constraint with a ticket" \
  "$(envelope Write /tmp/proj/a.js '// Retry twice: upstream 500s on first call after deploy (VENDOR-412).
retry(2);')"

assert_silent "keep: intentional-silence marker on an empty catch" \
  "$(envelope Write /tmp/proj/a.js 'try { warmCache(); } catch (e) {
  // Best-effort only: a cold cache is correct, just slower.
}')"

assert_silent "keep: TODO carrying a ticket ID" \
  "$(envelope Write /tmp/proj/a.js '// TODO(BILL-412): drop once the v2 rollout completes
const x = 1;')"

assert_silent "keep: contract fact a signature cannot state" \
  "$(envelope Write /tmp/proj/a.ts '// Timeout in milliseconds; caller owns the handle and must close it.
function connect(timeout: number) {}')"

assert_silent "keep: a well-formed shortcut marker is not warned" \
  "$(envelope Write /tmp/proj/a.js '// shortcut: global lock; revisit when throughput matters
const result = withGlobalLock(work);')"

assert_silent "keep: why-comment with a mid-sentence 'now' is not narration" \
  "$(envelope Write /tmp/proj/a.js '// Cache stays warm across retries; a cold start now costs ~3s (measured, VENDOR-88).
warm(cache);')"

assert_silent "keep: 'now that' precondition is not narration" \
  "$(envelope Write /tmp/proj/a.go '// Now that the lock is held, reads are safe without a copy.
readAll(buf)')"

assert_silent "keep: noun phrase 'the change event' is not a change event" \
  "$(envelope Write /tmp/proj/a.js '// The change event fires after blur, not on each keystroke.
el.addEventListener(evName, onEdit);')"

assert_silent "keep: narration-shaped phrase rescued by a ticket reference" \
  "$(envelope Write /tmp/proj/a.ts '// Retry cap of 5 as discussed in ADR-12.
const MAX_RETRIES = 5;')"

assert_silent "keep: standing-state 'was previously' contract fact" \
  "$(envelope Write /tmp/proj/a.py '# Input was previously validated by the caller; no re-check here.
process(data)')"

assert_silent "exempt: licence / SPDX header" \
  "$(envelope Write /tmp/proj/a.js '// Copyright 2026 Acme. SPDX-License-Identifier: MIT
const x = 1;')"

assert_silent "exempt: shebang" \
  "$(envelope Write /tmp/proj/a.sh '#!/usr/bin/env bash
set -e')"

assert_silent "exempt: tool directive" \
  "$(envelope Write /tmp/proj/a.js '// eslint-disable-next-line no-console
console.log(1);')"

assert_silent "scope: non-code extension is not governed" \
  "$(envelope Write /tmp/proj/notes.md '// increment the counter
counter++;')"

# Real roots: the marketplace test is a file on disk, and /tmp/proj resolves no root at all.
INST="$(mktemp -d)"; MKT="$(mktemp -d)"
mkdir -p "$MKT/.claude-plugin"; : > "$MKT/.claude-plugin/marketplace.json"
JS_NOISE='// increment the counter
counter++;'
SH_NOISE='# set the counter
counter=1'

assert_fires "installer root: scripts/deploy.sh is judged" \
  "$(envelope_at "$INST" "$INST/scripts/deploy.sh" "$SH_NOISE")" "restating the next line"
assert_fires "installer root: src/templates/EmailTemplate.tsx is judged" \
  "$(envelope_at "$INST" "$INST/src/templates/EmailTemplate.tsx" "$JS_NOISE")" "restating the next line"
assert_fires "installer root: wp-content/plugins/shop/hooks/cart.php is judged" \
  "$(envelope_at "$INST" "$INST/wp-content/plugins/shop/hooks/cart.php" "$JS_NOISE")" "restating the next line"

assert_silent "marketplace root: scripts/x.sh is exempt" \
  "$(envelope_at "$MKT" "$MKT/scripts/x.sh" "$SH_NOISE")"
assert_silent "marketplace root: templates/x.js is exempt" \
  "$(envelope_at "$MKT" "$MKT/templates/x.js" "$JS_NOISE")"
assert_silent "marketplace root: plugins/x/hooks/h.sh is exempt" \
  "$(envelope_at "$MKT" "$MKT/plugins/x/hooks/h.sh" "$SH_NOISE")"

assert_fires "migrations: judged in an installer root" \
  "$(envelope_at "$INST" "$INST/database/migrations/2026_10_01_create_users.php" "$JS_NOISE")" "restating the next line"
assert_fires "migrations: judged in a marketplace root" \
  "$(envelope_at "$MKT" "$MKT/database/migrations/2026_10_01_create_users.php" "$JS_NOISE")" "restating the next line"

assert_silent "build root: build/app.js at the root is exempt" \
  "$(envelope_at "$INST" "$INST/build/app.js" "$JS_NOISE")"
assert_fires "build root: packages/build/index.ts is judged" \
  "$(envelope_at "$INST" "$INST/packages/build/index.ts" "$JS_NOISE")" "restating the next line"
assert_silent "build root: build/ inside a worktree is exempt" \
  "$(envelope_at "$INST" "$INST/.claude/worktrees/b/build/x.js" "$JS_NOISE")"

# /build/app.js, not <cwd>/build/app.js: an empty root makes this path root-relative `build/app.js`.
assert_fires "missing cwd: build/app.js is still judged" \
  "$(envelope_at "$INST/gone" /build/app.js "$JS_NOISE")" "restating the next line"
rm -rf "$INST" "$MKT"

# cwd != root: every case above posts from the root itself, so a hook handing the classifier
# the payload cwd would pass them all.
if command -v git >/dev/null 2>&1; then
  GITR="$(mktemp -d)"; git -C "$GITR" init -q; mkdir -p "$GITR/packages"
  assert_fires "classifier: from cwd <root>/packages, packages/build/index.ts is judged" \
    "$(envelope_at "$GITR/packages" "$GITR/packages/build/index.ts" "$JS_NOISE")" "restating the next line"
  assert_silent "classifier: from cwd <root>/packages, build/app.js at the git root is exempt" \
    "$(envelope_at "$GITR/packages" "$GITR/build/app.js" "$JS_NOISE")"
  rm -rf "$GITR"
else
  printf 'SKIP  classifier: git not found — cwd-below-root cases\n'
fi

assert_status() { # desc  wanted-status  command...  (stdin passes through)
  local desc="$1" want="$2" got; shift 2
  "$@"; got=$?
  if [ "$got" -eq "$want" ]; then pass "$desc"; else fail "$desc" "status $got (want $want)"; fi
}
. "$ROOT/plugins/code-review/hooks/paths.sh"
assert_status "classifier: a root spelled with a trailing slash exempts build/app.js" 0 \
  cd_path_exempt /tmp/proj/build/app.js /tmp/proj/
assert_status "classifier: a relative build/x.ts is judged" 1 \
  cd_path_exempt build/x.ts /tmp/proj
assert_status "classifier: a BOM before a line-1 marker is still generated" 0 \
  cd_generated <<<$'\357\273\277// Code generated by protoc. DO NOT EDIT.'
utf8=$(locale -a 2>/dev/null | grep -ixE 'en_US\.utf-?8|C\.utf-?8' | head -n 1)
if [ -n "$utf8" ]; then
  LC_ALL=$utf8 assert_status "classifier: a BOM before a line-1 marker is still generated under $utf8" 0 \
    cd_generated <<<$'\357\273\277// Code generated by protoc. DO NOT EDIT.'
else
  printf 'SKIP  classifier: BOM under a UTF-8 locale — locale -a lists none of en_US.UTF-8, en_US.utf8, C.UTF-8, C.utf8\n'
fi
assert_status "classifier: a marker on line 6 is not generated" 1 \
  cd_generated <<<$'a\nb\nc\nd\ne\n// @generated'
assert_status "classifier: <auto-generated mid-line is generated" 0 \
  cd_generated <<<'// tool output <auto-generated/>'
assert_status "classifier: a mid-line @generated (prost-build) is generated" 0 \
  cd_generated <<<'// This file is @generated by prost-build.'
assert_status "classifier: a mid-line @generated (Composer) is generated" 0 \
  cd_generated <<<'// autoload_real.php @generated by Composer'
assert_status "classifier: build/ under a root nested inside a worktree is exempt" 0 \
  cd_path_exempt /m/.claude/worktrees/b/sub/build/x.js /m/.claude/worktrees/b/sub

assert_silent "scope: vendored path is exempt" \
  "$(envelope Write /tmp/proj/node_modules/x/a.js '// increment the counter
counter++;')"

assert_silent "unknown tool name is ignored" \
  "$(envelope Read /tmp/proj/a.js '// increment the counter
counter++;')"

assert_silent "empty added text" \
  "$(envelope Write /tmp/proj/a.js '')"

# ---- 3. fail-open -------------------------------------------------------------------
assert_silent "fail-open: malformed JSON" 'not json at all'
assert_silent "fail-open: empty stdin" ''
assert_silent "fail-open: JSON with no tool_input" '{"tool_name":"Write"}'

nojq_out="$(printf '%s' "$(envelope Write /tmp/proj/a.js '// increment the counter
counter++;')" | PATH="$NOJQ" "$BASH_BIN" "$HOOK" 2>/dev/null)"; nojq_rc=$?
if [ "$nojq_rc" -eq 0 ] && [ -z "$nojq_out" ]; then
  pass "fail-open: no jq on PATH"
else
  fail "fail-open: no jq on PATH" "exit $nojq_rc, output: $nojq_out"
fi

NOLIB="$WORK/nolib"; mkdir -p "$NOLIB"; cp "$HOOK" "$NOLIB/"
HOOK="$NOLIB/scan.sh" assert_silent "missing paths.sh: a noisy Write exits 0 with no output" \
  "$(envelope Write /tmp/proj/a.js '// increment the counter
counter++;')"

# ---- 4. the PostToolUse lane never blocks --------------------------------------------
# `hookSpecificOutput`/`additionalContext` is the non-blocking context channel, not a
# veto. `decision` (Stop) is a blocking key this hook must never emit on any lane.
# `permissionDecision` used to be in this list too; it is now emitted, but ONLY on the
# PreToolUse lane and ONLY for the three blockable categories — asserted behaviorally in
# section 5 rather than by grepping the file, because the file-level assertion can no
# longer tell an emission from an emission on the correct lane.
# Comment lines are stripped first: the header *names* keys to describe them.
if grep -vE '^[[:space:]]*#' "$HOOK" | grep -qE '"decision"'; then
  fail "hook emits no Stop-blocking JSON" "found a Stop decision key in $HOOK"
else
  pass "hook emits no Stop-blocking JSON"
fi

# and it must still exit 0 on the firing path, not just the silent one
fire_rc_out="$(run "$(envelope Write /tmp/proj/a.js '// increment the counter
counter++;')")"; fire_rc=$?
if [ "$fire_rc" -eq 0 ] && [ -n "$fire_rc_out" ]; then
  pass "exits 0 while warning (never vetoes the edit)"
else
  fail "exits 0 while warning (never vetoes the edit)" "exit $fire_rc, output: $fire_rc_out"
fi
# PostToolUse never carries a permissionDecision, whatever the category.
if printf '%s' "$fire_rc_out" | grep -q 'permissionDecision'; then
  fail "PostToolUse lane carries no permissionDecision" "got: $fire_rc_out"
else
  pass "PostToolUse lane carries no permissionDecision"
fi

# ---- 5. the PreToolUse lane denies the blockable categories, once per file -----------
# Blockable = restatement of the next line, commented-out code, and a docblock tag that
# repeats the signature. Banners, bare TODOs and change-narration stay warn-only: they
# are house-style calls.
STATE_DIR="$(mktemp -d)"
pre() { # session-id  file_path  added-text  -> stdout
  envelope Write "$2" "$3" \
    | python3 -c 'import json,sys
d=json.load(sys.stdin); d["hook_event_name"]="PreToolUse"
d["session_id"]=sys.argv[1]; d["cwd"]=sys.argv[2]; print(json.dumps(d))' "$1" "$STATE_DIR" \
    | "$BASH_BIN" "$HOOK" 2>/dev/null
}
assert_denies() { # desc  session  path  text
  local out; out="$(pre "$2" "$3" "$4")"
  if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1
  then pass "$1"; else fail "$1" "wanted deny, got: $out"; fi
}
assert_allows() { # desc  session  path  text
  local out; out="$(pre "$2" "$3" "$4")"
  if [ -z "$out" ]; then pass "$1"; else fail "$1" "wanted silence, got: $out"; fi
}

assert_denies "PreToolUse denies a restatement comment" s1 /tmp/proj/a.js '// increment the counter
counter++;'
assert_denies "bound is TWO denies: same file a second time still denies" s1 /tmp/proj/a.js '// increment the counter
counter++;'
assert_allows "bound is TWO denies: same file a third time is allowed" s1 /tmp/proj/a.js '// increment the counter
counter++;'
assert_denies "the bound is per FILE: a new file in the same session still denies" s1 /tmp/proj/b.js '// increment the counter
counter++;'
assert_denies "PreToolUse denies commented-out code" s2 /tmp/proj/c.js '// doThing(a, b);
doThing(a, c);'
assert_denies "PreToolUse denies a docblock tag repeating the signature" s8 /tmp/proj/j.php '/**
 * @param $id The id
 * @return void
 */
function f($id) {}'
assert_allows "PreToolUse does NOT deny a docblock that says what the signature cannot" s9 /tmp/proj/k.php '/** @param int $ttl Seconds; 0 disables the cache. */
function f($ttl) {}'
assert_allows "PreToolUse does NOT deny a bare TODO (warn-only category)" s3 /tmp/proj/d.js '// TODO: revisit
const x = compute();'
assert_allows "PreToolUse does NOT deny a section banner (warn-only category)" s4 /tmp/proj/e.js '// ===== Helpers =====
const y = 2;'
assert_allows "PreToolUse does NOT deny a change-narration comment (warn-only category)" s7 /tmp/proj/i.js '// now correctly handles null input
if (x == null) return;'
assert_allows "PreToolUse is silent on a keep-case comment" s5 /tmp/proj/f.js '// Sorted before hashing: the vendor compares digests, not sets.
hash(sorted(items));'
assert_allows "PreToolUse does NOT deny a well-formed shortcut marker" s10 /tmp/proj/l.js '// shortcut: global lock; revisit when throughput matters
const result = withGlobalLock(work);'
assert_allows "generated-file header exempts the edit" s6 /tmp/proj/g.js '// @generated by tool — do not edit
// increment the counter
counter++;'
assert_denies "generated marker: a sentence that mentions a generator is judged" g1 /tmp/proj/gm1.js '// This is not generated by a tool
// increment the counter
counter++;'
assert_allows "generated marker: @generated exempts" g2 /tmp/proj/gm2.js '// @generated by tool — do not edit
// increment the counter
counter++;'
assert_allows "generated marker: Code generated by … DO NOT EDIT exempts" g3 /tmp/proj/gm3.go '// Code generated by protoc. DO NOT EDIT.
// increment the counter
counter++;'
assert_allows "generated marker: <auto-generated> exempts" g4 /tmp/proj/gm4.cs '// <auto-generated>
// increment the counter
counter++;'
assert_allows "generated marker: a docblock line This file was auto-generated exempts" g5 /tmp/proj/gm5.ts '/**
 * This file was auto-generated by openapi-typescript.
 */
// increment the counter
counter++;'
assert_allows "generated marker: This file was automatically generated exempts" g6 /tmp/proj/gm6.ts '// This file was automatically generated by json-schema-to-typescript.
// increment the counter
counter++;'
assert_allows "generated marker: GENERATED CODE - DO NOT MODIFY exempts" g7 /tmp/proj/gm7.dart '// GENERATED CODE - DO NOT MODIFY BY HAND
// increment the counter
counter++;'
# The one-shot bound lives in a marker file. If that marker cannot be written, the
# deny is unbounded — it fires on attempt 1, 2, 3, forever, and the model can never
# satisfy or exhaust it. These two cases pin the withhold. Without them the plugin's
# central safety claim ("can never wedge a session") is unasserted prose.
UNWRITABLE="$(mktemp -d)"; mkdir -p "$UNWRITABLE/.claude"; chmod 555 "$UNWRITABLE/.claude"
wedge_out=""
for _ in 1 2 3; do
  wedge_out="$wedge_out$(envelope Write /tmp/proj/w.js '// increment the counter
counter++;' | python3 -c 'import json,sys
d=json.load(sys.stdin); d["hook_event_name"]="PreToolUse"; d["session_id"]="s90"
d["cwd"]=sys.argv[1]; print(json.dumps(d))' "$UNWRITABLE" | "$BASH_BIN" "$HOOK" 2>/dev/null)"
done
if [ -z "$wedge_out" ]; then pass "unwritable marker dir withholds the deny (no wedge)"
else fail "unwritable marker dir withholds the deny (no wedge)" "denied anyway: $wedge_out"; fi
chmod 755 "$UNWRITABLE/.claude"; rm -rf "$UNWRITABLE"

# No cwd at all: the marker path would resolve under / — unwritable on a sealed
# root, and wrong everywhere else. Withhold rather than deny unbounded.
nocwd_out=""
for _ in 1 2; do
  nocwd_out="$nocwd_out$(envelope Write /tmp/proj/x.js '// increment the counter
counter++;' | python3 -c 'import json,sys
d=json.load(sys.stdin); d["hook_event_name"]="PreToolUse"; d["session_id"]="s91"
d.pop("cwd", None)   # envelope() always sets one; this case is about its ABSENCE
print(json.dumps(d))' | "$BASH_BIN" "$HOOK" 2>/dev/null)"
done
if [ -z "$nocwd_out" ]; then pass "missing cwd withholds the deny (no wedge)"
else fail "missing cwd withholds the deny (no wedge)" "denied anyway: $nocwd_out"; fi

# Without a session_id the one-shot cannot be bounded, so the deny is withheld
# entirely rather than risking a loop. Built inline: the helper always sets the field.
nosid_out="$(envelope Write /tmp/proj/h.js '// increment the counter
counter++;' \
  | python3 -c 'import json,sys
d=json.load(sys.stdin); d["hook_event_name"]="PreToolUse"; d["cwd"]=sys.argv[1]; print(json.dumps(d))' "$STATE_DIR" \
  | "$BASH_BIN" "$HOOK" 2>/dev/null)"
if [ -z "$nosid_out" ]; then pass "no session_id: cannot bound the one-shot, so no deny"
else fail "no session_id: cannot bound the one-shot, so no deny" "got: $nosid_out"; fi
rm -rf "$STATE_DIR"

# ---- 6. THE REAL PAYLOAD SHAPE: transcript_path present -------------------------------
# Every case above sends session_id and no transcript_path, so they only ever exercised
# the FALLBACK branch of the context key. The hook reads `.transcript_path // .session_id`,
# and the host normally sends transcript_path — an absolute PATH. Interpolated raw into the
# marker name it built `…/blocked-/Users/x/y.jsonl-<key>`, whose parents are never created;
# the write failed, the withhold above fired, and the deny was silently absent in every
# real session while these tests stayed green. That is why these two cases exist: the
# harness must send what the host sends, or it grades a branch nobody runs.
TP_DIR="$(mktemp -d)"
tp() { # file_path  added-text  -> stdout
  envelope Write "$1" "$2" \
    | python3 -c 'import json,sys
d=json.load(sys.stdin); d["hook_event_name"]="PreToolUse"
d["session_id"]="11111111-2222-3333-4444-555555555555"; d["cwd"]=sys.argv[1]
d["transcript_path"]="/Users/x/.claude/projects/-Users-x-proj/abcdef01-2345-6789.jsonl"
print(json.dumps(d))' "${TP_CWD:-$TP_DIR}" \
    | "$BASH_BIN" "$HOOK" 2>/dev/null
}
tp1="$(tp /tmp/proj/tp.js '// increment the counter
counter++;')"
if printf '%s' "$tp1" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1
then pass "transcript_path present: the deny still fires"
else fail "transcript_path present: the deny still fires" "wanted deny, got: $tp1"; fi

# THE BOUND IS TWO DENIES, NOT ONE (0.18.x → 2026-09-15). A sibling PreToolUse hook
# denying the same call blocks the write too, so spending the whole bound on attempt 1
# left the next edit of that file unchecked — measured with all 31 plugins installed.
# Attempt 2 must still deny; attempt 3 must be silent, which is what bounds the session.
tp2="$(tp /tmp/proj/tp.js '// increment the counter
counter++;')"
if printf '%s' "$tp2" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1
then pass "second edit of the same file still denies (survives one co-firing deny)"
else fail "second edit of the same file still denies (survives one co-firing deny)" "wanted deny, got: $tp2"; fi

tp3="$(tp /tmp/proj/tp.js '// increment the counter
counter++;')"
if [ -z "$tp3" ]; then pass "third edit of the same file is bounded (no wedge)"
else fail "third edit of the same file is bounded (no wedge)" "fired a third time: $tp3"; fi

# The bound must be real state on disk, not an accident of the deny path failing earlier.
# It is a DIRECTORY since 0.19.1: `mkdir` is atomic, a read-modify-write counter file was
# not, and two parallel subagents editing one file could both read 0 and both write 1.
if [ -n "$(find "$TP_DIR/.claude/comment-discipline" -name 'blocked-*.d[0-9]' -type d 2>/dev/null)" ]
then pass "transcript_path present: the marker actually landed on disk"
else fail "transcript_path present: the marker actually landed on disk" "no marker under $TP_DIR"; fi
if [ "$(cat "$TP_DIR/.claude/comment-discipline/.gitignore" 2>/dev/null)" = "*" ]; then pass "the state dir ignores itself"
else fail "the state dir ignores itself" ".claude/comment-discipline/.gitignore missing or not '*'"; fi
# ---- the legacy marker, the <=0.19.0 shape -----------------------------------
# `[ -e "$marker" ] && tries=1` is the only thing stopping a mid-session UPGRADE from
# handing an already-denied file a fresh pair of denies: the old hook wrote a zero-byte
# FILE at the bare marker path, the new one writes `.d1`/`.d2` directories. scan.sh
# claims in a comment that the legacy marker counts as one try. Nothing tested it —
# delete that line and every other assertion in this file stays green.
LEG_DIR="$(mktemp -d)"
TP_CWD="$LEG_DIR"
tp /tmp/proj/leg.js '// increment the counter
counter++;' >/dev/null
leg_d1="$(find "$LEG_DIR/.claude/comment-discipline" -name 'blocked-*.d1' -type d 2>/dev/null | head -1)"
if [ -n "$leg_d1" ]; then
  rmdir "$leg_d1"; : > "${leg_d1%.d1}"      # collapse .d1 back to the pre-0.19.1 shape
  leg1="$(tp /tmp/proj/leg.js '// increment the counter
counter++;')"
  leg2="$(tp /tmp/proj/leg.js '// increment the counter
counter++;')"
  leg1_deny=$(printf '%s' "$leg1" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && echo 1 || echo 0)
  leg2_deny=$(printf '%s' "$leg2" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && echo 1 || echo 0)
  if [ "$leg1_deny" = 1 ] && [ "$leg2_deny" = 0 ]; then
    pass "a legacy marker counts as one try: an upgrade mid-session buys ONE more deny, not two"
  else
    fail "a legacy marker counts as one try" "first=$leg1_deny second=$leg2_deny (want 1 then 0)"
  fi
else
  fail "a legacy marker counts as one try" "no .d1 marker landed under $LEG_DIR to collapse"
fi
unset TP_CWD
rm -rf "$LEG_DIR"

rm -rf "$TP_DIR"

# ---- 7. the Bash lane: a cat/tee heredoc is judged as a Write of its body -------------
# session_id only, as pre() sends it: the shared-budget cases need a Write and a Bash call in one context.
BW="$(mktemp -d)"; BH="$(mktemp -d)"
SUFFIX=' Written by a Bash command:'
bash_payload() { # event  cwd  session-id  command
  jq -cn --arg e "$1" --arg c "$2" --arg s "$3" --arg cmd "$4" \
    '{hook_event_name: $e, cwd: $c, session_id: $s, tool_name: "Bash", tool_input: {command: $cmd}}'
}
write_payload() { # event  session-id  file_path  text
  envelope Write "$3" "$4" | jq -c --arg e "$1" --arg c "$BW" --arg s "$2" \
    '.hook_event_name = $e | .cwd = $c | .session_id = $s'
}
bash_pre()  { run "$(bash_payload PreToolUse "$BW" "$1" "$2")"; }      # session  command
write_pre() { run "$(write_payload PreToolUse "$1" "$2" "$JS_NOISE")"; }   # session  file_path
is_deny()   { printf '%s' "$1" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; }
reason_of() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }
heredoc()   { printf '%s\n%s\nEOF' "$1 <<'EOF'" "$2"; }               # writer  body
assert_bash_denies() { # desc  session  command  reason-substring
  local out; out="$(bash_pre "$2" "$3")"
  if ! is_deny "$out"; then fail "$1" "wanted deny, got: $out"; return; fi
  case "$(reason_of "$out")" in
    *"$4"*) pass "$1" ;;
    *) fail "$1" "wanted '$4' in: $(reason_of "$out")" ;;
  esac
}
assert_bash_silent() { # desc  command — PostToolUse: it warns on everything the deny lane blocks
  assert_silent "$1" "$(bash_payload PostToolUse "$BW" quiet "$2")"
}
assert_writes_spend_bash() { # desc  session  file_path  command — two Write denies, then the heredoc passes
  local w1 w2 b
  w1="$(write_pre "$2" "$3")"; w2="$(write_pre "$2" "$3")"; b="$(bash_pre "$2" "$4")"
  if is_deny "$w1" && is_deny "$w2" && [ -z "$b" ]; then pass "$1"
  else fail "$1" "write1=[$w1] write2=[$w2] bash=[$b] (want deny, deny, silence)"; fi
}
assert_bash_try_lands_on() { # desc  session  command  file_path  [HOME] — one Bash deny, one Write deny, then silence
  local b w1 w2
  b="$(printf '%s' "$(bash_payload PreToolUse "$BW" "$2" "$3")" | HOME="${5:-$HOME}" "$BASH_BIN" "$HOOK" 2>/dev/null)"
  w1="$(write_pre "$2" "$4")"; w2="$(write_pre "$2" "$4")"
  if is_deny "$b" && is_deny "$w1" && [ -z "$w2" ]; then pass "$1"
  else fail "$1" "bash=[$b] write1=[$w1] write2=[$w2] (want deny, deny, silence)"; fi
}

w_reason="$(reason_of "$(write_pre bw "$BW/src/f.js")")"
b_reason="$(reason_of "$(bash_pre bb "$(heredoc 'cat > src/f.js' "$JS_NOISE")")")"
if [ -n "$w_reason" ] && [ "$b_reason" = "$w_reason$SUFFIX f.js." ]; then
  pass "bash: a cat heredoc is denied with the Write reason plus the file suffix"
else
  fail "bash: a cat heredoc is denied with the Write reason plus the file suffix" "write=[$w_reason] bash=[$b_reason]"
fi

assert_bash_denies "bash: a cat >> heredoc is denied" b2 \
  "$(heredoc 'LC_ALL=C cat >> src/app.js' "$JS_NOISE")" "$SUFFIX app.js."
assert_bash_denies "bash: a tee heredoc is denied" b3 \
  "$(heredoc 'mkdir -p src && sudo tee src/t.js' "$JS_NOISE")" "$SUFFIX t.js."
assert_bash_denies "bash: commented-out code in a heredoc is denied" b4 \
  "$(heredoc 'cat > src/c.js' '// doThing(a, b);
doThing(a, c);')" "commented-out code"
assert_bash_denies "bash: a dead docblock tag in a heredoc is denied" b5 \
  "$(heredoc 'cat > src/d.php' '/**
 * @param $id The id
 * @return void
 */
function f($id) {}')" "docblock tag repeating the signature"

assert_bash_silent "bash: silent on a command that writes nothing" 'ls -la && git status'
assert_bash_silent "bash: silent on a governed path named only inside a heredoc body" \
  "$(heredoc 'cat' "cat > src/f.js
$JS_NOISE")"
assert_bash_silent "bash: silent on a heredoc to .md"   "$(heredoc 'cat > notes.md' "$JS_NOISE")"
assert_bash_silent "bash: silent on a heredoc to .json" "$(heredoc 'cat > data.json' "$JS_NOISE")"
assert_bash_silent "bash: silent on a heredoc to .yaml" "$(heredoc 'cat > conf.yaml' "$JS_NOISE")"
# After a kept chunk: a body that leaked into the previous chunk's text would warn.
assert_bash_silent "bash: silent on a heredoc whose writer names no file (psql)" \
  "$(heredoc 'cat > src/clean.js' 'const a = 1;')
psql <<SQL
-- increment the counter
counter++;
SQL"
assert_bash_silent "bash: silent on a heredoc fed to a writer that is not cat or tee" \
  "python3 - <<'PY' > src/x.js
# increment the counter
counter += 1
PY"
# Unquoted: a quote-led echo chunk reaches no detector, so it would be silent even if echo were judged.
assert_bash_silent "bash: silent on echo content" 'echo // TODO: fix this > src/f.js'

assert_bash_silent "chunk: silent on a cat pipeline whose redirect belongs to a later stage" \
  "cat <<'SQL' | psql -d app > out.sql
-- increment the counter
counter++;
SQL"
assert_bash_denies "chunk: cat>src/f.js with no space before the redirect is denied" ck2 \
  "$(heredoc 'cat>src/f.js' "$JS_NOISE")" "$SUFFIX f.js."
HOME= assert_bash_silent "chunk: ~/x.js with HOME empty is skipped" "$(heredoc 'cat > ~/x.js' "$JS_NOISE")"
assert_bash_silent "chunk: a relative target after { cd src; is skipped" \
  "{ $(heredoc 'cd src; cat > f.js' "$JS_NOISE")
}"
HOOK="$NOLIB/scan.sh" assert_bash_silent "lib: a noisy cat heredoc with paths.sh absent exits 0 with no output" \
  "$(heredoc 'cat > src/f.js' "$JS_NOISE")"

BANNER='// ===== HELPERS =====
const y = 2;'
w_warn="$(run "$(write_payload PostToolUse pw "$BW/src/h.js" "$BANNER")" | jq -r '.hookSpecificOutput.additionalContext // empty')"
b_warn="$(run "$(bash_payload PostToolUse "$BW" pb "$(heredoc 'cat > src/h.js' "$BANNER")")" | jq -r '.hookSpecificOutput.additionalContext // empty')"
case "$w_warn" in
  *"section banner"*)
    if [ "$b_warn" = "$w_warn$SUFFIX h.js." ]; then pass "bash: PostToolUse warns on a banner with the Write warning plus the file suffix"
    else fail "bash: PostToolUse warns on a banner with the Write warning plus the file suffix" "write=[$w_warn] bash=[$b_warn]"; fi ;;
  *) fail "bash: PostToolUse warns on a banner with the Write warning plus the file suffix" "the Write itself drew no banner warning: [$w_warn]" ;;
esac

assert_writes_spend_bash "bash: two Write denies spend the budget of a relative heredoc to that file" sb1 \
  "$BW/src/s1.js" "$(heredoc 'cat > src/s1.js' "$JS_NOISE")"
assert_writes_spend_bash "bash: two Write denies spend the budget of a ./relative heredoc to that file" sb2 \
  "$BW/src/s2.js" "$(heredoc 'cat > ./src/s2.js' "$JS_NOISE")"
rev1="$(bash_pre sb3 "$(heredoc 'cat > src/s3.js' "$JS_NOISE")")"
rev2="$(bash_pre sb3 "$(heredoc 'cat > src/s3.js' "$JS_NOISE")")"
rev3="$(write_pre sb3 "$BW/src/s3.js")"
if is_deny "$rev1" && is_deny "$rev2" && [ -z "$rev3" ]; then pass "bash: two heredoc denies spend the budget of a Write to that file"
else fail "bash: two heredoc denies spend the budget of a Write to that file" "bash1=[$rev1] bash2=[$rev2] write=[$rev3] (want deny, deny, silence)"; fi

assert_bash_silent "bash: a relative target after an in-command cd is skipped" \
  "$(heredoc 'cd src && cat > f.js' "$JS_NOISE")"
assert_bash_try_lands_on "bash: a relative target with no cd resolves against the payload cwd" r2 \
  "$(heredoc 'cat > src/r.js' "$JS_NOISE")" "$BW/src/r.js"
assert_bash_try_lands_on "bash: ~/x.js resolves under \$HOME" r3 \
  "$(heredoc 'cat > ~/x.js' "$JS_NOISE")" "$BH/x.js" "$BH"

two_heredocs() { printf '%s\n%s' "$(heredoc "cat > src/$1" "$3")" "$(heredoc "cat > src/$2" "$JS_NOISE")"; } # first  second  first-body
two_out="$(bash_pre th1 "$(two_heredocs one.js two.js "$JS_NOISE")")"
if [ "$(printf '%s\n' "$two_out" | grep -c .)" = 1 ] && is_deny "$two_out"; then
  case "$(reason_of "$two_out")" in
    *"$SUFFIX one.js.") pass "bash: two noisy heredocs draw one deny naming the first file" ;;
    *) fail "bash: two noisy heredocs draw one deny naming the first file" "got: $two_out" ;;
  esac
else
  fail "bash: two noisy heredocs draw one deny naming the first file" "wanted exactly one deny, got: $two_out"
fi
# Runs 1 and 2 spend the first file's budget; the second file must then still hold both of its tries.
for _ in 1 2; do bash_pre th2 "$(two_heredocs three.js four.js "$JS_NOISE")" >/dev/null; done
sec1="$(bash_pre th2 "$(two_heredocs three.js four.js "$JS_NOISE")")"; sec2="$(write_pre th2 "$BW/src/four.js")"
case "$(reason_of "$sec1")" in *"$SUFFIX four.js.") sec1=four ;; esac
if [ "$sec1" = four ] && is_deny "$sec2"; then pass "bash: two noisy heredocs leave the second file's budget untouched"
else fail "bash: two noisy heredocs leave the second file's budget untouched" "run3=[$sec1] write=[$sec2] (want a deny naming four.js, then a Write deny)"; fi

assert_bash_denies "bash: a clean first heredoc does not hide a noisy second" th3 \
  "$(two_heredocs ok.js noisy.js 'const a = 1;')" "$SUFFIX noisy.js."

# ---- 8. red-team: a wrong file, a false deny, a stall ----------------------------------
assert_bash_silent "redteam: a relative heredoc after \`if cd dist; then\` is skipped" \
  "if cd dist; then
$(heredoc 'cat > f.js' "$JS_NOISE")
fi"
assert_bash_silent "redteam: CDPATH= cd dist && cat > g.js is skipped" \
  "CDPATH= cd dist && $(heredoc 'cat > g.js' "$JS_NOISE")"
assert_bash_silent "redteam: a relative heredoc after builtin cd is skipped" \
  "builtin cd dist
$(heredoc 'cat > g.js' "$JS_NOISE")"
assert_bash_silent "redteam: a relative heredoc after a case arm \`x) cd d ;;\` is skipped" \
  "case x in
x) cd d ;;
esac
$(heredoc 'cat > g.js' "$JS_NOISE")"
assert_bash_silent "redteam: a relative heredoc after a quoted << and a cd is skipped" \
  "echo \"usage: prog <<EOF\"
cd dist
$(heredoc 'cat > h.js' "$JS_NOISE")"
assert_bash_silent "redteam: cat src/other.js > src/a.js <<EOF is silent (cat ignores the heredoc)" \
  "$(heredoc 'cat src/other.js > src/a.js' "$JS_NOISE")"
assert_bash_silent "redteam: cat -n > f.js <<EOF is silent" "$(heredoc 'cat -n > f.js' "$JS_NOISE")"
assert_bash_silent "redteam: a heredoc to ~root/x.js is silent" "$(heredoc 'cat > ~root/x.js' "$JS_NOISE")"
assert_bash_silent "redteam: a heredoc to src/f.js'.bak' is silent" "$(heredoc "cat > src/f.js'.bak'" "$JS_NOISE")"
assert_writes_spend_bash "redteam: after two denies on src/f.js a heredoc to src//f.js passes" rt10 \
  "$BW/src/f.js" "$(heredoc 'cat > src//f.js' "$JS_NOISE")"

DENSITY="$ROOT/plugins/code-review/hooks/density.sh"
big_run() { # hook  event  command -> $big_out, status 1 past 5 s. Fed on stdin: Linux caps one argument at 128 kB.
  local t0=$SECONDS
  big_out="$(printf '%s' "$3" | jq -Rsc --arg e "$2" --arg c "$BW" \
    '{hook_event_name: $e, cwd: $c, session_id: "big", tool_name: "Bash", tool_input: {command: .}}' \
    | "$BASH_BIN" "$1" 2>/dev/null)"
  [ $((SECONDS - t0)) -le 5 ]
}
big_all() { # command -> $big_slow, $big_loud: the hook:event pairs past 5 s, and the ones that spoke; $big_pre: scan's PreToolUse output
  local h e
  big_slow=""; big_loud=""; big_pre=""
  for h in "$HOOK" "$DENSITY"; do
    for e in PreToolUse PostToolUse; do
      big_run "$h" "$e" "$1" || big_slow="$big_slow ${h##*/}:$e"
      [ -z "$big_out" ] || big_loud="$big_loud ${h##*/}:$e"
      [ "$h:$e" = "$HOOK:PreToolUse" ] && big_pre=$big_out
    done
  done
}
BIG_BODY="$(awk 'BEGIN { for (i = 0; i < 6000; i++) print "// increment the retry counter for the upstream billing gateway client\nupstreamBillingGatewayClient.retryCounter++;" }')"
big_all "$(heredoc 'cat > notes.md' "$BIG_BODY")"
if [ -z "$big_slow$big_loud" ]; then pass "redteam: a 12,000-line heredoc to notes.md is silent within 5 s, both hooks, both events"
else fail "redteam: a 12,000-line heredoc to notes.md is silent within 5 s, both hooks, both events" "past 5 s:[$big_slow] spoke:[$big_loud]"; fi
big_all "$(heredoc 'cat > src/big.js' "$BIG_BODY")"
if is_deny "$big_pre" && [ -z "$big_slow" ]; then pass "redteam: a 12,000-line noisy heredoc to a governed file is denied within 5 s, and no hook or event takes longer"
else fail "redteam: a 12,000-line noisy heredoc to a governed file is denied within 5 s, and no hook or event takes longer" "past 5 s:[$big_slow] scan PreToolUse=[$big_pre]"; fi
big_all "echo $(awk 'BEGIN { for (i = 0; i < 2326; i++) printf "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVphYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5ejAxMjM0NTY3ODkrLw" }') | base64 -d > out.bin"
if [ -z "$big_slow$big_loud" ]; then pass "redteam: a 200 kB single-line echo | base64 -d > out.bin returns within 5 s, both hooks, both events"
else fail "redteam: a 200 kB single-line echo | base64 -d > out.bin returns within 5 s, both hooks, both events" "past 5 s:[$big_slow] spoke:[$big_loud]"; fi

RT="$(mktemp -d)"; mkdir -p "$RT/mkt/.claude-plugin" "$RT/other" "$RT/real" "$RT/proj/src"
: > "$RT/mkt/.claude-plugin/marketplace.json"; ln -s "$RT/real" "$RT/link"
assert_fires "redteam: in a marketplace root, scripts/deploy.sh OUTSIDE the root is judged" \
  "$(envelope_at "$RT/mkt" "$RT/other/scripts/deploy.sh" "$SH_NOISE")" "restating the next line"
assert_silent "redteam: a root reached through a symlink still exempts build/app.js spelled through the real path" \
  "$(envelope_at "$RT/link" "$RT/real/build/app.js" "$JS_NOISE")"
CLAUDE_PROJECT_DIR="$RT/proj" assert_silent "redteam: cat > ../build/y.js from cwd <root>/src is exempt" \
  "$(bash_payload PostToolUse "$RT/proj/src" quiet "$(heredoc 'cat > ../build/y.js' "$JS_NOISE")")"

# ---- 9. re-test: what the red-team fixes over-skipped --------------------------------
assert_bash_denies "retest: a quoted target with a cd in the heredoc body is denied" rq1 \
  "cat > \"src/run.sh\" <<'EOF'
#!/bin/bash
cd /app
$SH_NOISE
EOF" "$SUFFIX run.sh."
assert_bash_denies "retest: echo \"start\" && cat with a cd in the heredoc body is denied" rq2 \
  "echo \"start\" && $(heredoc 'cat > src/f.js' "// cd is not needed
$JS_NOISE")" "$SUFFIX f.js."
assert_bash_denies "retest: echo \"cd into it\" && cat > src/f.js is denied" rq3 \
  "echo \"cd into it\" && $(heredoc 'cat > src/f.js' "$JS_NOISE")" "$SUFFIX f.js."
assert_bash_silent "retest: chdir dist && cat > f.js is skipped" "chdir dist && $(heredoc 'cat > f.js' "$JS_NOISE")"
mkdir -p "$BW/elsewhere/dist/pkg"; ln -s elsewhere/dist/pkg "$BW/out"
assert_bash_silent "retest: a target whose .. steps out of a symlinked directory is skipped" \
  "$(heredoc 'cat > out/../f.js' "$JS_NOISE")"
ln -s "$RT/mkt" "$RT/mlink"
assert_silent "retest: a marketplace root spelled through a symlink still exempts scripts/x.sh" \
  "$(envelope_at "$RT/mlink" "$RT/mkt/scripts/x.sh" "$SH_NOISE")"
assert_bash_denies "retest: a heredoc header with a trailing comment is denied" rq7 \
  "cat > src/f.js <<'EOF' # write it
$JS_NOISE
EOF" "$SUFFIX f.js."
big_all "$(awk 'BEGIN { for (i = 0; i < 100; i++) { printf "echo "; for (j = 0; j < 799; j++) printf "ABCDEFGHIJ"; print "" } }')
$(heredoc 'cat > src/long.js' "$JS_NOISE")"
if [ -z "$big_slow$big_loud" ]; then pass "retest: 100 command lines of 8,000 characters plus a noisy heredoc return within 5 s, unjudged, both hooks, both events"
else fail "retest: 100 command lines of 8,000 characters plus a noisy heredoc return within 5 s, unjudged, both hooks, both events" "past 5 s:[$big_slow] spoke:[$big_loud]"; fi
rm -rf "$RT" "$BW" "$BH"

# ---- 10. comment recognition: code a language-blind leader read as a comment ----------
# Every allow here was denied before leaders followed the file's language and a *-led line
# needed an open /* block; the denies are the shapes that must stay judged.
STATE_DIR="$(mktemp -d)"
assert_allows "leaders: a shell case arm *) on its own line is code" lr1 /tmp/proj/lr1.sh 'case "$1" in
  start) run ;;
  *)
    usage
    ;;
esac'
assert_allows "leaders: /*) and *.blade.php) case arms are code" lr2 /tmp/proj/lr2.sh 'case "$f" in
  /*) abs=1 ;;
  *.blade.php) key=blade ;;
esac'
assert_allows "leaders: */.claude/worktrees/*/*) above an assignment is code" lr3 /tmp/proj/lr3.sh 'case "$p" in
  */.claude/worktrees/*/*)
    rel="${p#*/.claude/worktrees/*/}" ;;
esac'
assert_allows "leaders: C pointer writes **pp = 0; and *++p = c; are code" lr4 /tmp/proj/lr4.c 'void put(char **pp, char *p, char c) {
  **pp = 0;
  *++p = c;
}'
assert_allows "leaders: a * sizeof(int)); continuation line in C is code" lr5 /tmp/proj/lr5.c 'int *buf = malloc(n
                 * sizeof(int));'
assert_allows "leaders: **pp = nil in Go is code" lr6 /tmp/proj/lr6.go 'func reset(pp **[]int) {
	**pp = nil
}'
assert_allows "leaders: **r = 5; in Rust is code" lr7 /tmp/proj/lr7.rs 'fn set(r: &mut &mut i32) {
    **r = 5;
}'
assert_allows "leaders: a Python **kwargs): continuation is code" lr8 /tmp/proj/lr8.py 'class Child(Base):
    def __init__(self, *args,
                 **kwargs):
        super().__init__(**kwargs)'
assert_allows "leaders: a * foo=bar Markdown list in a shell heredoc is code" lr9 /tmp/proj/lr9.sh 'cat > NOTES.md <<EOF
* foo=bar
EOF'
assert_allows "leaders: a MySQL /*!40101 … */ version comment is code" lr10 /tmp/proj/lr10.sql '/*!40101 SET @A=@@B */;
SELECT 1;'
assert_allows "leaders: a Python // floor-division continuation is code" lr11 /tmp/proj/lr11.py 'def pages(total, size):
    full = (total
            // size)
    return full + (1 if total % size else 0)'
assert_allows "leaders: a # Usage heading in a TS template literal is text" lr12 /tmp/proj/lr12.ts 'const help = `
# Usage
usage: deploy <env>
`;'
assert_allows "leaders: /* flag */ foo(); closes its comment and continues as code" lr13 /tmp/proj/lr13.js '/* flag */ foo();'
assert_silent "leaders: /* flag */ foo(); draws no warning either" "$(envelope Write /tmp/proj/lr13.js '/* flag */ foo();')"
assert_denies "leaders: a typed @param int \$id The ID inside /** */ is still denied" ld1 /tmp/proj/ld1.php '/**
 * @param int $id The ID
 */
function find(int $id) {}'
assert_denies "leaders: commented-out code inside /** */ with no @example is still denied" ld2 /tmp/proj/ld2.ts '/**
 * const old = compute(x);
 */
export function compute(x: number) { return x * 2; }'
assert_denies "leaders: // const old = compute(counter); is still denied" ld3 /tmp/proj/ld3.ts '// const old = compute(counter);
const next = compute(counter + 1);'
assert_allows "leaders: a # Features heading over * fast features in a .sh heredoc is allowed" ld4 /tmp/proj/ld4.sh 'cat > NOTES.md <<EOF
# Features
* fast features
EOF'
# The restatement target is still found with the language-blind leaders, so a line that became code is not a new target.
assert_allows "target: # Usage over * usage: run it in a Python string" rt1 /tmp/proj/rt1.py 'HELP = """
# Usage
* usage: run it
"""'
assert_allows "target: # Options over * options are read from ENV in a Ruby heredoc" rt2 /tmp/proj/rt2.rb 'HELP = <<~TXT
  # Options
  * options are read from ENV
TXT'
assert_allows "target: # show help over a *) show_help ;; case arm" rt3 /tmp/proj/rt3.sh 'case "$1" in
  # show help
  *) show_help ;;
esac'
assert_allows "target: // buffer size over # define BUFFER_SIZE in C" rt4 /tmp/proj/rt4.c '// buffer size
# define BUFFER_SIZE 4096'
assert_allows "target: /* margin */ over a * { margin: 0; } rule" rt5 /tmp/proj/rt5.css '/* margin */
* { margin: 0; }'
assert_allows "target: # divide over a // 2) continuation in Python" rt6 /tmp/proj/rt6.py 'half = (total
        # divide
        // 2)'
assert_allows "target: -- index over a /*+ INDEX(...) */ hint" rt7 /tmp/proj/rt7.sql '-- index
/*+ INDEX(users idx_users_email) */'
assert_denies "target: /* box sizing */ over a *, *::before rule is judged against box-sizing" rt8 /tmp/proj/rt8.css '/* box sizing */
*, *::before, *::after {
  box-sizing: border-box;
}'
assert_denies "examples: //// in Rust is a plain comment, so its code is judged" rt9 /tmp/proj/rt9.rs '//// let old = compute(x);
let next = compute(x + 1);'
assert_allows "exempt: Dockerfile parser directives syntax=, escape= and check=" rt10 /tmp/proj/Dockerfile '# syntax=docker/dockerfile:1
# escape=`
# check=skip=JSONArgsRecommended
FROM alpine:3.20'
assert_allows "target: a blank * line in a docblock still ends the restatement scan" lt1 /tmp/proj/lt1.ts '/**
 * Get the user.
 *
 * @return User
 */
function getUser(): User {}'
assert_denies "target: each comment is judged against its own next line" lt2 /tmp/proj/lt2.ts '// Sorted before hashing: the vendor compares digests, not sets.
hash(sorted(items));
// increment the counter
counter++;'
assert_allows "examples: JSDoc @example code is not commented-out code" le1 /tmp/proj/le1.ts '/**
 * Adds without overflow checks.
 * @example
 * const x = add(1, 2);
 * add(1, 2) // => 3
 */
export function add(a: number, b: number): number { return a + b; }'
assert_allows "examples: code on the @example line itself is example code" le8 /tmp/proj/le8.ts '/**
 * @example const x = add(1, 2);
 */
export const add = (a: number, b: number) => a + b;'
assert_allows "examples: code in a fence inside a doc comment is not commented-out code" le2 /tmp/proj/le2.ts '/**
 * Parses a duration such as 2s or 150ms.
 * ```ts
 * const ms = parse("2s");
 * ```
 */
export function parse(s: string): number { return 0; }'
assert_allows "examples: a Rust /// doc line is not commented-out code" le3 /tmp/proj/le3.rs '/// assert_eq!(add(1, 2), 3);
pub fn add(a: i32, b: i32) -> i32 { a + b }'
assert_allows "examples: code in a fence inside Swift /// doc lines is not commented-out code" le7 /tmp/proj/le7.swift '/// ```
/// let x = add(1, 2)
/// ```
func add(_ a: Int, _ b: Int) -> Int { a + b }'
assert_denies "examples: an @example ends with its docblock, so the next docblock is judged" le6 /tmp/proj/le6.ts '/**
 * @example
 * add(1, 2);
 */
/**
 * const old = compute(x);
 */
export const add = (a: number, b: number) => a + b;'
assert_denies "examples: a plain // const old = compute(x); after an @example block is denied" le4 /tmp/proj/le4.ts '/**
 * @example
 * const x = add(1, 2);
 */
// const old = compute(x);
export const add = (a: number, b: number) => a + b;'
assert_denies "examples: the next tag ends the example, so code after it is judged" le5 /tmp/proj/le5.ts '/**
 * @example
 * const x = add(1, 2);
 * @deprecated
 * const old = compute(x);
 */
export const add = (a: number, b: number) => a + b;'
me_out="$(jq -cn --arg c "$STATE_DIR" --arg a '/* Cache the parsed header so the second lookup is free.' --arg b '**pp = 0;' \
  '{hook_event_name: "PreToolUse", cwd: $c, session_id: "me1", tool_name: "MultiEdit",
    tool_input: {file_path: "/tmp/proj/me1.c", edits: [{old_string: "x", new_string: $a}, {old_string: "y", new_string: $b}]}}' \
  | "$BASH_BIN" "$HOOK" 2>/dev/null)"
if [ -z "$me_out" ]; then pass "multiedit: a /* left open by one edit does not make the next edit's **pp = 0; a comment"
else fail "multiedit: a /* left open by one edit does not make the next edit's **pp = 0; a comment" "wanted silence, got: $me_out"; fi
me_out="$(jq -cn --arg c "$STATE_DIR" --arg a 'a = 1;
b = 2;
c = 3;
d = 4;' --arg b '// @generated by tool
// increment the counter
counter++;' \
  '{hook_event_name: "PreToolUse", cwd: $c, session_id: "me2", tool_name: "MultiEdit",
    tool_input: {file_path: "/tmp/proj/me2.js", edits: [{old_string: "x", new_string: $a}, {old_string: "y", new_string: $b}]}}' \
  | "$BASH_BIN" "$HOOK" 2>/dev/null)"
if [ -z "$me_out" ]; then pass "multiedit: the edit boundary is not a line, so a generated marker on line 5 still exempts"
else fail "multiedit: the edit boundary is not a line, so a generated marker on line 5 still exempts" "wanted silence, got: $me_out"; fi

# Fixture (a) of the m22 timings: 4,000 contiguous comments cost a re-scan each before the single pass.
FIX_A="$(awk 'BEGIN {
  for (i = 0; i < 4000; i++) printf "const v%d = compute(%d);\n", i, i
  for (i = 0; i < 4000; i++) {
    k = i % 8
    if (k == 6) print "// TODO: revisit"
    else if (k == 7) print "// ===== HELPERS ====="
    else if (k % 2) print "// Sequential, not Promise.all: the vendor rate-limits concurrent calls."
    else print "// increment the retry counter for the upstream billing gateway client"
  }
  print "upstreamBillingGatewayClient.retryCounter++;"
  for (i = 1; i < 4000; i++) printf "const w%d = compute(%d);\n", i, i
}')"
t0=$SECONDS
fa_out="$(printf '%s' "$FIX_A" | jq -Rsc --arg c "$STATE_DIR" \
  '{hook_event_name: "PreToolUse", cwd: $c, session_id: "fa", tool_name: "Write", tool_input: {file_path: "/tmp/proj/fa.ts", content: .}}' \
  | "$BASH_BIN" "$HOOK" 2>/dev/null)"
fa_s=$((SECONDS - t0))
case "$(reason_of "$fa_out")" in
  *"1500 restating the next line"*"500 section banner"*"500 bare TODO"*) fa_counts=1 ;;
  *) fa_counts=0 ;;
esac
if [ "$fa_s" -le 5 ] && [ "$fa_counts" = 1 ]; then pass "large: 8,000 code and 4,000 contiguous comment lines are judged within 5 s, counts unchanged"
else fail "large: 8,000 code and 4,000 contiguous comment lines are judged within 5 s, counts unchanged" "${fa_s}s, reason: $(reason_of "$fa_out" | cut -c1-200)"; fi
rm -rf "$STATE_DIR"

# ---- 11. padded tags and restating docstrings: a warning, never a deny ----------------
STATE_DIR="$(mktemp -d)"
PAD='docblock tag padding (restates its name or type)'
DOCSTR='docstring restating the signature'
RUN_PHP='function run($x) {}'
docblock() { printf '/**\n * %s\n */\n%s' "$1" "$2"; }   # tag-line  code-line
pad_fires() { # desc  session  path  text  category
  assert_fires "padding: $1" "$(envelope Write "$3" "$4")" "$5"
  assert_allows "padding: $1 — allowed on PreToolUse" "$2" "$3" "$4"
}
pad_silent() { assert_silent "padding: $1 is silent" "$(envelope Write "$2" "$3")"; }   # desc  path  text

pad_fires "@param id the id" pd1 /tmp/proj/pd1.ts "$(docblock '@param id the id' 'export function load(id: string): void {}')" "$PAD"
pad_fires "@param id - the id" pd2 /tmp/proj/pd2.ts "$(docblock '@param id - the id' 'export function load(id: string): void {}')" "$PAD"
pad_fires "@param int \$userId The ID of the user" pd3 /tmp/proj/pd3.php "$(docblock '@param int $userId The ID of the user' 'function load(int $userId): void {}')" "$PAD"
pad_fires "@return User the user above getUser(): User" pd4 /tmp/proj/pd4.php "$(docblock '@return User the user' 'function getUser(): User
{
    return $this->user;
}')" "$PAD"
pad_fires "@var string The table directly above a string property" pd5 /tmp/proj/pd5.php 'class Account
{
    /** @var string The table */
    protected string $table = "accounts";
}' "$PAD"
pad_fires ":param user_id: user id in a docstring" pd6 /tmp/proj/pd6.py 'def get_user(user_id):
    """Fetch the row for this key.

    :param user_id: user id
    """
    return db.find(user_id)' "$PAD"
pad_fires "a Google Args: entry user_id: User id." pd7 /tmp/proj/pd7.py 'def get_user(user_id):
    """Fetch the row for this key.

    Args:
        user_id: User id.
    """
    return db.find(user_id)' "$PAD"
pad_fires "\"\"\"Get the user.\"\"\" under def get_user(user_id):" pd8 /tmp/proj/pd8.py 'def get_user(user_id):
    """Get the user."""
    return db.find(user_id)' "$DOCSTR"
pad_fires "a docstring under a decorator and a three-line header" pd9 /tmp/proj/pd9.py '@lru_cache
def get_user(
    user_id,
):
    """Get the user."""
    return db.find(user_id)' "$DOCSTR"
pad_fires "a summary line followed by a blank docstring line" pd10 /tmp/proj/pd10.py 'def get_user(user_id):
    """Get the user.

    Reads the replica; writes go through save_user.
    """
    return db.find(user_id)' "$DOCSTR"

pad_silent "list<User> \$users List of users" /tmp/proj/ps1.php "$(docblock '@param list<User> $users List of users' "$RUN_PHP")"
pad_silent "array<string, mixed> \$options The options array" /tmp/proj/ps2.php "$(docblock '@param array<string, mixed> $options The options array' "$RUN_PHP")"
pad_silent "non-empty-string \$userId The ID of the user" /tmp/proj/ps3.php "$(docblock '@param non-empty-string $userId The ID of the user' "$RUN_PHP")"
pad_silent "int|null \$limit Null for no limit" /tmp/proj/ps4.php "$(docblock '@param int|null $limit Null for no limit' "$RUN_PHP")"
pad_silent "int \$n 0 or 1" /tmp/proj/ps5.php "$(docblock '@param int $n 0 or 1' "$RUN_PHP")"
pad_silent "int \$timeout Timeout in milliseconds" /tmp/proj/ps6.php "$(docblock '@param int $timeout Timeout in milliseconds' "$RUN_PHP")"
pad_silent "int \$level The level (1-5)" /tmp/proj/ps7.php "$(docblock '@param int $level The level (1-5)' "$RUN_PHP")"
pad_silent "string \$name The name, if any" /tmp/proj/ps8.php "$(docblock '@param string $name The name, if any' "$RUN_PHP")"
pad_silent "bool \$enabled On or off" /tmp/proj/ps9.php "$(docblock '@param bool $enabled On or off' "$RUN_PHP")"
pad_silent "a description continued on the next line" /tmp/proj/ps10.php '/**
 * @param int $userId The ID of the user,
 *     or 0 for a guest.
 */
function load(int $userId): void {}'
pad_silent "@return BelongsTo<Workspace, \$this>" /tmp/proj/ps11.php "$(docblock '@return BelongsTo<Workspace, $this>' 'public function workspace(): BelongsTo
{
    return $this->belongsTo(Workspace::class);
}')"
pad_silent "@return User|null the user above getUser(): ?User" /tmp/proj/ps12.php "$(docblock '@return User|null the user' 'function getUser(): ?User
{
    return $this->user;
}')"
pad_silent "a .js @param {string} opts.name - the name" /tmp/proj/ps13.js "$(docblock '@param {string} opts.name - the name' 'export function greet(opts) {}')"
pad_silent "a .js @param {number} [opts.limit=10] - the limit" /tmp/proj/ps14.js "$(docblock '@param {number} [opts.limit=10] - the limit' 'export function page(opts) {}')"
pad_silent "a .js untyped @param id the id" /tmp/proj/ps15.js "$(docblock '@param id the id' 'export function load(id) {}')"
pad_silent "a dotted @param opts.userName - the name" /tmp/proj/ps16.ts "$(docblock '@param opts.userName - the name' 'export function greet(opts: Opts): void {}')"
pad_silent "/** @var User \$user */ \$user = \$request->user();" /tmp/proj/ps17.php '/** @var User $user */ $user = $request->user();'
pad_silent "/** @var string */ above an untyped protected \$table" /tmp/proj/ps18.php 'class User extends Model
{
    /** @var string */
    protected $table = "users";
}'
pad_silent "/** @var positive-int */ above an int property" /tmp/proj/ps21.php 'class Job
{
    /** @var positive-int */
    protected int $retries = 3;
}'
pad_silent "a summary that continues on the next line" /tmp/proj/ps22.py 'def get_user(user_id):
    """Get the user
    from the replica, never the primary.
    """
    return db.find(user_id)'
pad_silent "a :param description continued on the next line" /tmp/proj/ps23.py 'def get_user(user_id):
    """Fetch the row for this key.

    :param user_id: user id,
        or None for the caller.
    """
    return db.find(user_id)'
pad_silent "a module docstring" /tmp/proj/ps19.py '"""Get the user."""
def get_user(user_id):
    return db.find(user_id)'
pad_silent "a docstring that is not the first statement" /tmp/proj/ps20.py 'def get_user(user_id):
    user = db.find(user_id)
    """Get the user."""
    return user'
pad_silent "non-empty-string \$name The name" /tmp/proj/pl1.php "$(docblock '@param non-empty-string $name The name' "$RUN_PHP")"
pad_silent "class-string<T> \$class The class" /tmp/proj/pl2.php "$(docblock '@param class-string<T> $class The class' "$RUN_PHP")"
PL3='/**
 * @param  name
 *         the display name of the account
 */
public void rename(String name) {}'
pad_silent "a JDK @param  name with its description on the next line" /tmp/proj/pl3.java "$PL3"
assert_allows "padding: a JDK @param  name with its description on the next line — allowed on PreToolUse" pl3 /tmp/proj/pl3.java "$PL3"
# A non-native type is a fact the signature may not state, so the tag rule leaves it alone.
assert_allows "dead tag: @param list<User> \$users with no description is allowed" dt1 /tmp/proj/dt1.php "$(docblock '@param list<User> $users' 'function notify(array $users): void {}')"
assert_allows "dead tag: @param non-empty-string \$name with no description is allowed" dt2 /tmp/proj/dt2.php "$(docblock '@param non-empty-string $name' 'function rename(string $name): void {}')"
assert_denies "dead tag: @param int \$id with no description is still denied" dt3 /tmp/proj/dt3.php "$(docblock '@param int $id' 'function find(int $id): void {}')"
assert_denies "dead tag: @return void is still denied" dt4 /tmp/proj/dt4.php "$(docblock '@return void' 'function flush(): void {}')"
assert_allows "dead tag: a JDK @param  name whose description wraps onto the next line is allowed" dt5 /tmp/proj/dt5.java '/**
 * @param  name
 *         the display name of the account
 */
public void rename(String name) {}'
assert_denies "dead tag: @param int \$id followed by another tag is still denied" dt6 /tmp/proj/dt6.php '/**
 * @param int $id
 * @throws NotFound when no row matches
 */
function find(int $id): void {}'
rm -rf "$STATE_DIR"

# ---- 12. markup, paragraph, marker, stamp and lowercase-todo cues: a warning, never a deny ----
STATE_DIR="$(mktemp -d)"
MARKUP='commented-out markup'
PARA='comment paragraph (one line is the budget)'
MARKER='section marker'
STAMP='authorship stamp (git blame holds this)'
cue_fires() { # desc  session  path  text  category
  assert_fires "cue: $1" "$(envelope Write "$3" "$4")" "$5"
  assert_allows "cue: $1 — allowed on PreToolUse" "$2" "$3" "$4"
}
cue_silent() { assert_silent "cue: $1 is silent" "$(envelope Write "$2" "$3")"; }   # desc  path  text
WHY='// Sequential, not Promise.all: the vendor rate-limits concurrent calls.'
QUOTA='// One request per id keeps the account under its quota.
for (const id of ids) await fetchOne(id);'

cue_fires "<!-- <Chart :data=\"d\" /> --> in .vue" cu1 /tmp/proj/cu1.vue '<template>
  <!-- <Chart :data="d" /> -->
  <Table :rows="rows" />
</template>' "$MARKUP"
cue_fires "{{-- <x-alert /> --}} in .blade.php" cu2 /tmp/proj/cu2.blade.php '{{-- <x-alert /> --}}
<x-banner :message="$message" />' "$MARKUP"
cue_fires "{/* <Card /> */} in .tsx" cu3 /tmp/proj/cu3.tsx 'export const Panel = () => (
  <div>
    {/* <Card /> */}
    <List items={items} />
  </div>
);' "$MARKUP"
cue_fires "{/* setOpen(true); */} in .tsx" cu4 /tmp/proj/cu4.tsx 'export const Panel = () => (
  <div>
    {/* setOpen(true); */}
    <List items={items} />
  </div>
);' "$MARKUP"
cue_fires "a three-line // why-paragraph in .ts" cu5 /tmp/proj/cu5.ts '// The vendor caps concurrent requests per account, and a burst past the cap
// returns 429s that the client retries with a fixed delay, which stalls the queue
// for every tenant sharing the key, so the calls run one at a time.
for (const id of ids) await fetchOne(id);' "$PARA"
cue_fires "// MARK: - Helpers in .swift" cu6 /tmp/proj/cu6.swift '// MARK: - Helpers
private func clamp(_ v: Int) -> Int { max(0, v) }' "$MARKER"
cue_fires "//region Helpers in .ts" cu7 /tmp/proj/cu7.ts '//region Helpers
function clamp(v: number) { return Math.max(0, v); }' "$MARKER"
cue_fires "// #region Helpers in .ts" cu8 /tmp/proj/cu8.ts '// #region Helpers
function clamp(v: number) { return Math.max(0, v); }' "$MARKER"
cue_fires "// Step 1: validate in .ts" cu9 /tmp/proj/cu9.ts '// Step 1: validate
const parsed = schema.parse(input);' "$MARKER"
cue_fires "// modified by A. 2024-03-11 in .ts" cu10 /tmp/proj/cu10.ts '// modified by A. 2024-03-11
const limit = 10;' "$STAMP"
cue_fires "// ivan 2024-03-11 in .ts" cu11 /tmp/proj/cu11.ts '// ivan 2024-03-11
const limit = 10;' "$STAMP"
cue_fires "// todo handle errors later in .ts" cu12 /tmp/proj/cu12.ts '// todo handle errors later
const res = await fetch(url);' "bare TODO"
cue_fires "// Updated: use the new client in .ts" cu13 /tmp/proj/cu13.ts '// Updated: use the new client
const client = createClient();' "change-narration"

cue_silent "<!-- wp:heading --> block grammar" /tmp/proj/cs1.php '<!-- wp:heading -->
<h2>Pricing</h2>
<!-- /wp:heading -->'
cue_silent "an IE conditional comment holding a script tag" /tmp/proj/cs2.php '<!--[if lt IE 9]><script src="x.js"></script><![endif]-->
<p>Hello</p>'
cue_silent "<!-- prettier-ignore -->" /tmp/proj/cs3.vue '<template>
  <!-- prettier-ignore -->
  <div   class="a"  >x</div>
</template>'
cue_silent "<!-- svelte-ignore a11y-click-events-have-key-events -->" /tmp/proj/cs4.svelte '<!-- svelte-ignore a11y-click-events-have-key-events -->
<div on:click={toggle}>x</div>'
cue_silent "an MIT licence header as the first comment block" /tmp/proj/cs5.ts '// Copyright (c) 2026 Acme Corp
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software.
export const VERSION = "1.0.0";'
cue_silent "a licence header under a shebang" /tmp/proj/cs16.sh '#!/bin/bash
# Copyright 2026 Acme Corp
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at the address in the LICENSE file.
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS.
set -eu'
cue_silent "a four-line Rust //! crate doc" /tmp/proj/cs6.rs '//! Token bucket rate limiting for outbound HTTP calls.
//! Buckets refill continuously rather than once per tick,
//! so a burst after an idle period is bounded by the bucket
//! size and never by the time that has elapsed.
pub mod bucket;'
cue_silent "a four-line Go doc comment above func Run()" /tmp/proj/cs7.go 'package worker

// Run drains the queue until the context is cancelled. It returns the first
// error a job reports and leaves the remaining jobs queued, so a caller that
// retries resumes where this call stopped instead of replaying finished work.
// Run is safe to call from one goroutine at a time only.
func Run(ctx context.Context, q *Queue) error {
	return nil
}'
cue_silent "a four-line JSDoc block" /tmp/proj/cs8.ts '/**
 * Retries the request with exponential backoff, starting at 100 ms.
 * Gives up after five attempts and rethrows the last error to the caller.
 * The caller owns the abort signal and must cancel it on unmount.
 */
export async function withRetry<T>(fn: () => Promise<T>): Promise<T> {
  return fn();
}'
cue_silent "// TODO(ivan): drop after v2" /tmp/proj/cs9.ts '// TODO(ivan): drop after v2
const legacy = true;'
cue_silent "// render each todo item" /tmp/proj/cs10.ts '// render each todo item
items.forEach(renderItem);'
cue_silent "@param Todo \$todo The todo" /tmp/proj/cs11.php '/**
 * @param Todo $todo The todo
 */
public function store(Todo $todo): void {}'
cue_silent "a directive line inside a two-line why" /tmp/proj/cs12.ts "$WHY
// eslint-disable-next-line no-await-in-loop
$QUOTA"
cue_silent "a tag line above a two-line why" /tmp/proj/cs13.ts '// @vitest-environment jsdom
// The widget reads layout from the DOM, so it needs a browser-like environment
// rather than the default node one, which has no window object at all.
import { render } from "@testing-library/react";'
cue_silent "an empty // line inside a two-line why" /tmp/proj/cs14.ts "$WHY
//
$QUOTA"
cue_silent "a shortcut: line inside a two-line why" /tmp/proj/cs15.ts "$WHY
// shortcut: one global queue; revisit when tenants need isolation
$QUOTA"
rm -rf "$STATE_DIR"

# ---- 13. what the adversarial review of 11 and 12 found: false refusals, noise, a stall ----
STATE_DIR="$(mktemp -d)"
JSET='public void set(int value) {}'
assert_denies "dead tag: an untyped @param value Value. is denied" fx1 /tmp/proj/fx1.java "$(docblock '@param value Value.' "$JSET")"
assert_allows "dead tag: an untyped @param value ignored is allowed" fx2 /tmp/proj/fx2.java "$(docblock '@param value ignored' "$JSET")"
# The tag is the only place the type is stated when the signature leaves the parameter untyped.
assert_allows "dead tag: @param  string  \$driver above an untyped callCustomCreator(\$driver) is allowed" fx3 /tmp/proj/fx3.php "$(docblock '@param  string  $driver' 'protected function callCustomCreator($driver) {}')"
assert_allows "dead tag: @param string \$driver with no signature in the added text is allowed" fx4 /tmp/proj/fx4.php '/**
 * @param string $driver
 */'
assert_denies "dead tag: @param string \$driver above f(string \$driver) is still denied" fx5 /tmp/proj/fx5.php "$(docblock '@param string $driver' 'function f(string $driver) {}')"
assert_allows "dead tag: a bare @return whose description wraps onto the next line is allowed" fx6 /tmp/proj/fx6.java '/**
 * @return
 *         the display name of the account
 */
public String displayName() {}'
assert_denies "dead tag: a bare @return followed by */ is still denied" fx7 /tmp/proj/fx7.java "$(docblock '@return' 'public String displayName() {}')"
CLOSE='/* the base value, before the discount applies
 */ const b = compute(a);'
assert_allows "leaders: */ const b = compute(a); closes its block and continues as code" fx8 /tmp/proj/fx8.ts "$CLOSE"
assert_silent "leaders: */ const b = compute(a); draws no warning either" "$(envelope Write /tmp/proj/fx8.ts "$CLOSE")"
assert_denies "leaders: code before the */ that closes a block is still denied" fx9 /tmp/proj/fx9.ts '/*
 * const old = compute(x); */
export const y = 1;'
pad_silent "@return this builder" /tmp/proj/fx10.java "$(docblock '@return this builder' 'public Builder withName(String name) {}')"
pad_silent "@return This matcher" /tmp/proj/fx11.java "$(docblock '@return This matcher' 'public Matcher matcher(CharSequence input) {}')"
pad_silent "@return the new stream" /tmp/proj/fx12.java "$(docblock '@return the new stream' 'public Stream<T> stream() {}')"
pad_silent "@return a new list" /tmp/proj/fx13.java "$(docblock '@return a new list' 'public static List<String> newList() {}')"
assert_silent "docstring: \"\"\"self + other\"\"\" under def __add__ is silent" "$(envelope Write /tmp/proj/fx14.py 'class V:
    def __add__(self, other):
        """self + other"""
        return V()')"
assert_silent "docstring: \"\"\"base ** self\"\"\" under def __rpow__ is silent" "$(envelope Write /tmp/proj/fx15.py 'class V:
    def __rpow__(self, base):
        """base ** self"""
        return V()')"
assert_silent "docstring: \"\"\"~self\"\"\" under def __invert__ is silent" "$(envelope Write /tmp/proj/fx16.py 'class V:
    def __invert__(self):
        """~self"""
        return V()')"
assert_silent "docstring: a grammar rule \"\"\"stmt : stmt ;\"\"\" is silent" "$(envelope Write /tmp/proj/fx17.py 'def p_stmt(p):
    """stmt : stmt ;"""
    p[0] = p[1]')"
pad_silent "a more-indented word: line inside an Args: entry" /tmp/proj/fx18.py 'def read(mode, path):
    """Read a file in one of two modes.

    Args:
        mode: One of the modes below.
            fast: Fast.
        path: Where the bytes come from.
    """
    return open(path)'
pad_fires "a second Args: entry at the first entry's indent" fx19 /tmp/proj/fx19.py 'def read(path, mode):
    """Read a file in one of two modes.

    Args:
        path: Where the bytes come from.
        mode: Mode.
    """
    return open(path)' "$PAD"
pad_silent "/** @var string */ with no description above a string property" /tmp/proj/fx20.php 'class Account
{
    /** @var string */
    protected string $table = "accounts";
}'
pad_silent "@param int \$userId The ID of the user above an untyped load(\$userId)" /tmp/proj/fx21.php "$(docblock '@param int $userId The ID of the user' 'function load($userId): void {}')"
RET_FX="$(awk 'BEGIN { print "/**"; for (i = 0; i < 4000; i++) print " * @returns the value"; print " */"
  printf "export const table = build("; for (i = 0; i < 10000; i++) printf "a, "; print "z);"
  print "// increment the counter"; print "counter++;" }')"
t0=$SECONDS
rt_out="$(printf '%s' "$RET_FX" | jq -Rsc --arg c "$STATE_DIR" \
  '{hook_event_name: "PreToolUse", cwd: $c, session_id: "rt", tool_name: "Write", tool_input: {file_path: "/tmp/proj/ret.ts", content: .}}' \
  | "$BASH_BIN" "$HOOK" 2>/dev/null)"
rt_s=$((SECONDS - t0))
if [ "$rt_s" -le 5 ] && is_deny "$rt_out"; then pass "large: 4,000 @returns lines above one 30 kB line are judged within 5 s"
else fail "large: 4,000 @returns lines above one 30 kB line are judged within 5 s" "${rt_s}s, output: $(printf '%s' "$rt_out" | cut -c1-200)"; fi
rm -rf "$STATE_DIR"

# ---- 14. what the second adversarial review found: a new false refusal, noise, a stall ----
STATE_DIR="$(mktemp -d)"
assert_allows "todo: TODO(api): above the line it names is allowed and silent" fy1 /tmp/proj/fy1.ts 'export function f(api: Api) {
  // TODO(api): sort todos by date
  const todos = api.todos.sort(byDate);
  return todos;
}'
assert_allows "todo: a ticketed TODO #1: above the line it names is allowed" fy1t /tmp/proj/fy1t.ts 'export function f(api: Api) {
  // TODO #1: sort todos by date
  const todos = api.todos.sort(byDate);
  return todos;
}'
assert_allows "todo: a TODO with a URL above the line it names is allowed" fy1u /tmp/proj/fy1u.ts '// TODO https://example.com/i/3 sort todos by date
const todos = api.todos.sort(byDate);'
assert_allows "todo: an owner TODO ending in a parenthetical is not commented-out code" fy1p /tmp/proj/fy1p.ts '// TODO(BILL-412): drop once v2 rollout completes (see ADR-7)
const v2 = rollout();'
assert_allows "todo: an owner TODO whose text ends in ) is allowed" fy1q /tmp/proj/fy1q.ts '// TODO(ana): retry once the gateway recovers (BILL outage)
gateway.connect();'
assert_denies "todo: a bare commented-out call is still denied" fy1r /tmp/proj/fy1r.ts '// gateway.connect(retry);
const g = 1;'
assert_allows "todo: XXX(xxx): set xxx above xxx = 1; is allowed and silent" fy2 /tmp/proj/fy2.ts '// XXX(xxx): set xxx
xxx = 1;'
assert_fires "todo: // TODO handle errors still warns bare" "$(envelope Write /tmp/proj/fy3.ts '// TODO handle errors
const res = await fetch(url);')" "bare TODO"
assert_fires "todo: an owner after the leading marker does not rescue // TODO: remove todo(item)" "$(envelope Write /tmp/proj/fy4.ts '// TODO: remove todo(item)
const items = [];')" "bare TODO"
assert_allows "restating: a bare @return wrapped onto the next line above a one-line getter is allowed" fy5 /tmp/proj/fy5.java 'class T {
    /**
     * @return
     *         the display name
     */
    public String getName() { return name; }
}'
assert_allows "restating: a bare @returns wrapped above a one-line get name() is allowed" fy6 /tmp/proj/fy6.ts 'class T {
  /**
   * @returns
   *   the display name, never empty
   */
  get name(): string { return this._name; }
}'
assert_allows "restating: @return \$this above { return \$this; } is allowed" fy7 /tmp/proj/fy7.php '<?php
class B {
    /**
     * @return $this
     */
    public function withX(): static { return $this; }
}'
assert_denies "restating: // get the name above getName() is still denied" fy8 /tmp/proj/fy8.java '// get the name
public String getName() { return name; }'
cue_silent "a Go doc comment above a var" /tmp/proj/fy9.go 'package store

import "errors"

// ErrNotFound is returned when a key is absent from the store.
// Callers should treat it as a cache miss and fall through to the
// backing database rather than surfacing it to the user.
var ErrNotFound = errors.New("not found")'
cue_silent "a Go doc comment above a struct field" /tmp/proj/fy10.go 'package store

// Options configures a Store.
type Options struct {
	// TTL is how long an entry lives. Zero means entries never
	// expire, which is only safe for bounded key spaces because
	// nothing else evicts.
	TTL time.Duration
}'
assert_fires "cue: a Go paragraph followed by a blank line still warns" "$(envelope Write /tmp/proj/fy11.go 'package store

func f() {
	// The vendor caps concurrent requests per account, and a burst past
	// the cap returns 429s that the client retries with a fixed delay,
	// which stalls the queue for every tenant sharing the key.

	run()
}')" "$PARA"
cue_silent "a licence header after <?php" /tmp/proj/fy12.php '<?php

// Copyright (c) 2026 Acme Corp
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights.

namespace App;'
cue_silent "a licence header after a module docstring" /tmp/proj/fy13.py '"""Token bucket helpers."""

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.
import os'
cue_silent "a licence header after a coding line and a blank" /tmp/proj/fy14.py '# coding: utf-8

# Copyright 2026 Acme Corp
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# notice appears in all copies.
import os'
cue_silent "a licence header framed by #---" /tmp/proj/fy15.py '#---------------------------------------------------------------------
# Licensed to PSF under a Contributor Agreement.
# See the PSF website for licensing details.
# This module carries no warranty of any kind, express or implied,
# and is distributed in the hope that it will be useful.
#---------------------------------------------------------------------
import os'
cue_silent "a CRLF licence header whose blank # lines end in CR" /tmp/proj/fy16.py "$(printf '# Copyright (c) 2020 Example\r\n#\r\n# Redistribution and use in source and binary forms, with or without\r\n# modification, are permitted provided that the following conditions\r\n# are met and the notice below is kept in every distributed copy.\r\nimport os\r\n')"
assert_fires "cue: a why-paragraph after <?php still warns" "$(envelope Write /tmp/proj/fy30.php '<?php

// The vendor caps concurrent requests per account, and a burst past the cap
// returns 429s that the client retries with a fixed delay, which stalls the
// queue for every tenant sharing the key, so the calls run one at a time.
foreach ($ids as $id) { fetchOne($id); }')" "$PARA"
cue_silent "RDoc above a Ruby def" /tmp/proj/fy17.rb 'class User
  # Returns the full name of the user, joined with a single
  # space and stripped of surrounding whitespace. Nil parts
  # are skipped, so a user with no last name gets no trailing space.
  def full_name
    [first, last].compact.join(" ")
  end
end'
cue_silent "YARD above a Ruby attr_reader" /tmp/proj/fy18.rb 'class Job
  # The number of attempts left before the job is parked. It counts
  # down on every failure and resets only when an operator requeues
  # the job by hand, never on a deploy.
  attr_reader :retries
end'
assert_fires "cue: a Ruby paragraph above a statement still warns" "$(envelope Write /tmp/proj/fy19.rb 'def run
  # The vendor caps concurrent requests per account, and a burst past
  # the cap returns 429s that the client retries with a fixed delay,
  # which stalls the queue for every tenant sharing the key.
  ids.each { |id| fetch_one(id) }
end')" "$PARA"
assert_denies "dead tag: @param string \$name above a multi-line __construct(string \$name, …) is denied" fy20 /tmp/proj/fy20.php '<?php
class M {
    /**
     * @param string $name
     */
    public function __construct(
        string $name,
        int $count
    ) {}
}'
assert_allows "dead tag: the same tag above a multi-line __construct(\$name, …) is allowed" fy21 /tmp/proj/fy21.php '<?php
class M {
    /**
     * @param string $name
     */
    public function __construct(
        $name,
        $count
    ) {}
}'
assert_allows "blade: a markdown mail heading # Order Shipped is text, not a comment" fy22 /tmp/proj/fy22.blade.php '<x-mail::message>
# Order Shipped

Your order has been shipped!
</x-mail::message>'
assert_silent "blade: {{-- @include(...) --}} stays silent" "$(envelope Write /tmp/proj/fy23.blade.php "{{-- @include('partials.nav') --}}
<div>{{ \$title }}</div>")"
assert_denies "blade: // const old = compute(\$x); inside @php is still denied" fy24 /tmp/proj/fy24.blade.php '@php
    // const old = compute($x);
    $next = compute($x + 1);
@endphp'
TYPED_FX="$(awk 'BEGIN { print "<?php"; print "/**"; for (i = 0; i < 4000; i++) printf " * @param string $p%d\n", i; print " */"
  printf "function build("; for (i = 0; i < 4000; i++) printf "%sstring $p%d", (i ? ", " : ""), i; print ") {}" }')"
t0=$SECONDS
ty_out="$(printf '%s' "$TYPED_FX" | jq -Rsc --arg c "$STATE_DIR" \
  '{hook_event_name: "PreToolUse", cwd: $c, session_id: "ty", tool_name: "Write", tool_input: {file_path: "/tmp/proj/typed.php", content: .}}' \
  | "$BASH_BIN" "$HOOK" 2>/dev/null)"
ty_s=$((SECONDS - t0))
case "$(reason_of "$ty_out")" in *"4000 docblock tag repeating the signature"*) ty_n=1 ;; *) ty_n=0 ;; esac
if [ "$ty_s" -le 3 ] && [ "$ty_n" = 1 ]; then pass "large: 4,000 typed @param tags over a 4,000-parameter signature are judged within 3 s"
else fail "large: 4,000 typed @param tags over a 4,000-parameter signature are judged within 3 s" "${ty_s}s, reason: $(reason_of "$ty_out" | cut -c1-200)"; fi
# An open signature reads on, so 8,000 of them back to back and one over fifty 12 kB lines bound that read.
OPEN_FX="$(awk 'BEGIN { print "<?php"; for (i = 0; i < 8000; i++) { print "/** @param string $a" i " */"; print "$v" i " = foo(string $a" i "," }
  print "/** @param string $b */"; print "$w = foo(string $b,"; for (k = 0; k < 50; k++) { for (j = 0; j < 2000; j++) printf "c%d, ", j; print "" } }')"
t0=$SECONDS
op_out="$(printf '%s' "$OPEN_FX" | jq -Rsc --arg c "$STATE_DIR" \
  '{hook_event_name: "PreToolUse", cwd: $c, session_id: "op", tool_name: "Write", tool_input: {file_path: "/tmp/proj/open.php", content: .}}' \
  | "$BASH_BIN" "$HOOK" 2>/dev/null)"
op_s=$((SECONDS - t0))
case "$(reason_of "$op_out")" in *"8001 docblock tag repeating the signature"*) op_n=1 ;; *) op_n=0 ;; esac
if [ "$op_s" -le 2 ] && [ "$op_n" = 1 ]; then pass "large: 8,001 open signatures, one over fifty 12 kB lines, are judged within 2 s"
else fail "large: 8,001 open signatures, one over fifty 12 kB lines, are judged within 2 s" "${op_s}s, reason: $(reason_of "$op_out" | cut -c1-200)"; fi
cue_silent "event dates are not authorship stamps" /tmp/proj/fy25.ts '// Deprecated 2024-01-01
export const a = 1;
// Since 2024-01-01
export const b = 2;
// Expires 2025-01-01
export const c = 3;'
cue_silent "// region codes follow ISO 3166 is prose, not a marker" /tmp/proj/fy26.ts '// region codes follow ISO 3166
export const codes = load();'
cue_silent "todo.done and todo-list are not lowercase TODOs" /tmp/proj/fy27.ts '// todo.done is set by the reducer
export const reducer = r;
// todo-list rows render in creation order
export const rows = [];'
cue_silent "a markup comment of prose naming a tag" /tmp/proj/fy28.vue '<template>
  <!-- Uses <code>v-model</code> so the parent owns the value -->
  <input v-model="value" />
</template>'
co_out="$(run "$(envelope Write /tmp/proj/fy29.ts '// const a = load(x);
// const b = parse(a);
// save(b);
export const run = () => 1;')")"
case "$co_out" in
  *"$PARA"*) fail "cue: a three-line commented-out block draws only commented-out code" "got: $co_out" ;;
  *"3 commented-out code"*) pass "cue: a three-line commented-out block draws only commented-out code" ;;
  *) fail "cue: a three-line commented-out block draws only commented-out code" "got: $co_out" ;;
esac
rm -rf "$STATE_DIR"

printf '\n'
[ "$rc" -eq 0 ] && printf 'comment-discipline-hook-tests: all cases passed\n' \
               || printf 'comment-discipline-hook-tests: FAILURES above\n'
exit "$rc"
