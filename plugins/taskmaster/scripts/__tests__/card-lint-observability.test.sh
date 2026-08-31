#!/usr/bin/env bash
# Fixtures for the card-lint observability path: the run record the three linters
# write (scripts/card-lint-record.sh) and the hook that reads it back
# (hooks/card-lint-observe.sh).
#
# WHY THIS EXISTS. The claim being tested is a negative one — "a card set that
# reached the runner unlinted is no longer silent" — and a negative claim needs BOTH
# branches or it proves nothing: a hook that warns unconditionally passes the warn
# case, and a hook that is broken and prints nothing passes the silent case. So the
# two run against the same fixture, differing only in whether the linters were
# actually invoked.
#
# THE PAYLOAD CARRIES transcript_path, ON PURPOSE. A harness that sends only
# session_id grades the FALLBACK branch of every context-keyed hook — the marketplace
# records that as the sole reason three broken hooks shipped behind a green suite.
# Case 4 is the load-bearing one: two transcripts under ONE session id must each get
# the warning, because a subagent shares its parent's session and is exactly where a
# card gets implemented.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
TM=plugins/taskmaster
H=$TM/hooks/card-lint-observe.sh
rc=0
pass() { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; rc=1; }

[ -x "$H" ] || { echo "FAIL: hook not executable at $H"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

FX=$(mktemp -d) || exit 1
trap 'rm -rf "$FX"' EXIT INT TERM HUP
# Isolate the one-shot markers: without a scratch TMPDIR these fixtures pass once
# and fail on every re-run.
mkdir -p "$FX/tmp"
export TMPDIR="$FX/tmp"

# --- fixture: a card set that reached handoff --------------------------------
# active-run.json is shaped exactly as task-runner/commands/run.md step 1 writes it
# for a taskmaster-index run: that file carrying an index_path IS the handoff.
REPO="$FX/repo"
SET="$REPO/taskmaster-docs/tasks/2026-08-31-demo"
mkdir -p "$SET" "$REPO/.claude/task-runner"
printf '# Index\n\n| Card | Status |\n' > "$SET/00-INDEX.md"
cat > "$SET/01-alpha.md" <<'EOF'
# 01 — alpha

- **Verify:** `pytest -k rejects_bad_host asserts 422`
- **Skills to apply:** none
EOF
cat > "$SET/02-beta.md" <<'EOF'
# 02 — beta

- **Verify:** `jest -t "refund path" asserts throw`
- **Skills to apply:** none
EOF
jq -nc --arg i "$SET/00-INDEX.md" \
  '{slug:"2026-08-31-demo",base:"deadbeef",branch:"master",index_path:$i}' \
  > "$REPO/.claude/task-runner/active-run.json"

fire() { # $1 transcript_path, $2 cwd, $3 session_id -> additionalContext (empty = silent)
  jq -nc --arg t "$1" --arg c "$2" --arg s "${3:-sess-shared}" \
    '{hook_event_name:"PostToolUse",tool_name:"Edit",session_id:$s,transcript_path:$t,
      cwd:$c,tool_input:{file_path:"src/x.ts",old_string:"a",new_string:"b"},
      tool_response:{filePath:"src/x.ts",success:true}}' \
  | bash "$H" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

# --- 1. WARN BRANCH: cards reached the run with no record --------------------
out=$(fire "$FX/t/main.jsonl" "$REPO")
if [ -n "$out" ]; then pass "warn branch: unlinted card set is no longer silent"
else bad "warn branch: silent on a card set with zero lint records"; fi
for want in "01-alpha.md" "02-beta.md" "verify-teeth" "skills-stamp" "2 of 2"; do
  if printf '%s' "$out" | grep -qF "$want"; then pass "warning names '$want'"
  else bad "warning missing '$want' (got: $out)"; fi
done

# --- 2. one-shot per transcript ----------------------------------------------
if [ -z "$(fire "$FX/t/main.jsonl" "$REPO")" ]; then pass "one-shot: silent on the second edit of the same transcript"
else bad "one-shot: repeated within one transcript"; fi

# --- 3. the key is DERIVED from transcript_path, never raw in a path ---------
# cksum of "<transcript_path>|<index_path>" — the marker name must be digits only,
# and no path anywhere under TMPDIR may contain a component of the transcript path.
mk=$(ls -d "$TMPDIR"/cc-cardlint-warned-* 2>/dev/null | head -1)
if printf '%s' "$(basename "${mk:-}")" | grep -qE '^cc-cardlint-warned-[0-9]+$'; then
  pass "marker key is a cksum hash, not a pasted path"
else bad "marker key is not a hash: ${mk:-<none>}"; fi
if [ -z "$(find "$TMPDIR" -name '*main.jsonl*' -o -name '*t?main*' 2>/dev/null)" ]; then
  pass "raw transcript_path never appears in a created path"
else bad "raw transcript_path leaked into a path under TMPDIR"; fi

# --- 4. THE DELIVERY CLAIM: a subagent sharing the parent's session still warned
if [ -n "$(fire "$FX/t/subagents/a1.jsonl" "$REPO" sess-shared)" ]; then
  pass "subagent transcript warns under the parent's session id"
else bad "subagent silenced by the parent's marker — session-keyed, and the claim is false"; fi

# --- 5. the linters leave a record -------------------------------------------
# Run them the way skills/task-cards/SKILL.md says to, per card.
for card in "$SET/01-alpha.md" "$SET/02-beta.md"; do
  bash "$TM/scripts/verify-teeth-lint.sh" --card "$card" >/dev/null 2>&1
  bash "$TM/scripts/skills-stamp-lint.sh" --card "$card" >/dev/null 2>&1
done
log="$SET/.lint-records/01-alpha.md.log"
if [ -r "$log" ] \
   && grep -q "$(printf '\tverify-teeth\tpass\t')" "$log" \
   && grep -q "$(printf '\tskills-stamp\tpass\t')" "$log"; then
  pass "each linter leaves a run record beside the card"
else bad "no run record at $log"; fi

# A BLOCKING run records too — the record says the lint ran, not that the card is good.
weak="$FX/weak/03-weak.md"
mkdir -p "$FX/weak"
printf '# 03\n\n- **Verify:** `npm test`\n- **Skills to apply:** none\n' > "$weak"
bash "$TM/scripts/verify-teeth-lint.sh" --card "$weak" >/dev/null 2>&1
wrc=$?
if [ "$wrc" -eq 2 ] && grep -q "$(printf '\tverify-teeth\tblock\t')" "$FX/weak/.lint-records/03-weak.md.log" 2>/dev/null; then
  pass "a blocked lint still records (verdict: block, exit 2 preserved)"
else bad "blocking run left no record or changed the exit code (rc=$wrc)"; fi

# spec-ledger records against its spec (written, deliberately not graded by the hook).
spec="$FX/spec/design.md"
mkdir -p "$FX/spec"
printf '# Spec\n\n## Ambiguity ledger (final)\n\n| # | Item | Current understanding | Status | Source |\n|---|---|---|---|---|\n| 1 | scope | one repo | CLEAR | user |\n' > "$spec"
bash "$TM/scripts/spec-ledger-lint.sh" --spec "$spec" >/dev/null 2>&1
if grep -q "$(printf '\tspec-ledger\tpass\t')" "$FX/spec/.lint-records/design.md.log" 2>/dev/null; then
  pass "spec-ledger-lint records against the spec"
else bad "spec-ledger-lint left no record"; fi

# --- 6. SILENT BRANCH: every card in the set now has a record ----------------
# Fresh transcript, so the one-shot from case 1 cannot be what produces the silence.
if [ -z "$(fire "$FX/t/after-lint.jsonl" "$REPO")" ]; then
  pass "silent branch: fully linted card set produces no warning"
else bad "silent branch: warned about a card set with complete records"; fi

# Half-linted is still a warning, and names only the card that is missing one.
cat > "$SET/03-gamma.md" <<'EOF'
# 03 — gamma

- **Verify:** `pytest -k gamma_rejects asserts 400`
- **Skills to apply:** none
EOF
bash "$TM/scripts/verify-teeth-lint.sh" --card "$SET/03-gamma.md" >/dev/null 2>&1
out=$(fire "$FX/t/partial.jsonl" "$REPO")
if printf '%s' "$out" | grep -qF '03-gamma.md (skills-stamp)' \
   && ! printf '%s' "$out" | grep -qF '01-alpha.md'; then
  pass "partial: names the card missing one linter, and only that card"
else bad "partial branch wrong (got: $out)"; fi

# --- 7. no registered run, no observation (the named fail-open) --------------
mkdir -p "$FX/bare"
if [ -z "$(fire "$FX/t/bare.jsonl" "$FX/bare")" ]; then pass "no active-run.json: silent"
else bad "fired without a registered run"; fi
jq -nc '{slug:"x",branch:"master"}' > "$REPO/.claude/task-runner/active-run.json"
if [ -z "$(fire "$FX/t/noindex.jsonl" "$REPO")" ]; then pass "run without index_path: silent"
else bad "fired on a non-index run"; fi
jq -nc --arg i "$SET/00-INDEX.md" '{slug:"2026-08-31-demo",index_path:$i}' \
  > "$REPO/.claude/task-runner/active-run.json"

# --- 8. off switches ----------------------------------------------------------
rm -f "$SET/.lint-records"/*.log
if [ -z "$(CC_CARDLINT=off fire "$FX/t/off1.jsonl" "$REPO")" ]; then pass "CC_CARDLINT=off silences"
else bad "CC_CARDLINT=off ignored"; fi
if [ -z "$(CC_REMIND=off fire "$FX/t/off2.jsonl" "$REPO")" ]; then pass "CC_REMIND=off silences"
else bad "CC_REMIND=off ignored"; fi

# --- 9. fail-open on malformed input -----------------------------------------
for badin in 'not json' '' '{}' '{"cwd":"/nope"}' '{"tool_name":"Edit"}'; do
  err=$(printf '%s' "$badin" | bash "$H" 2>&1 >/dev/null); st=$?
  if [ "$st" -eq 0 ] && [ -z "$err" ]; then pass "fail-open on [${badin:-<empty>}]"
  else bad "exit=$st stderr=[$err] on [${badin:-<empty>}]"; fi
done

# --- 10. a well-formed PostToolUse envelope, and never a blocking one --------
env_out=$(jq -nc --arg t "$FX/t/shape.jsonl" --arg c "$REPO" \
  '{hook_event_name:"PostToolUse",tool_name:"Edit",transcript_path:$t,cwd:$c}' | bash "$H" 2>/dev/null)
if printf '%s' "$env_out" | jq -e '.hookSpecificOutput.hookEventName=="PostToolUse"' >/dev/null 2>&1; then
  pass "PostToolUse envelope"
else bad "bad envelope: $env_out"; fi
if ! printf '%s' "$env_out" | jq -e '.hookSpecificOutput.permissionDecision // .decision' >/dev/null 2>&1; then
  pass "warns only — no permission decision in the output"
else bad "emitted a blocking decision: $env_out"; fi

exit "$rc"
