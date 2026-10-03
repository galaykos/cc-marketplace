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

printf '\n'
[ "$rc" -eq 0 ] && printf 'comment-discipline-hook-tests: all cases passed\n' \
               || printf 'comment-discipline-hook-tests: FAILURES above\n'
exit "$rc"
