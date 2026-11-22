#!/usr/bin/env bash
# Proves hooks/api-check.sh fires on a written Assets/**/*.cs that uses a name the project's Unity or Cinemachine version deprecated or removed, and stays silent on its neighbours: a clean file, a name outside its version window or under an #if guard, another file's finding, move damage in the same file, a .cs outside Assets/, Bash, PreToolUse, the off switches.
# Does NOT prove the host delivers the context: payloads are built here in the host's PostToolUse shape, with a path-shaped transcript_path.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
HOOK="$(cd "$here/../.." && pwd)/hooks/api-check.sh"
META="$(cd "$here/../.." && pwd)/hooks/meta-check.sh"
for t in jq python3 git; do
  command -v "$t" >/dev/null 2>&1 || { echo "SKIP: $t not available (the hook fails open without it)"; exit 0; }
done
[ -x "$HOOK" ] || { echo "FAIL: hook missing or not executable: $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'chmod -R u+w "$WS" 2>/dev/null; rm -rf "$WS"' EXIT
export CLAUDE_PLUGIN_DATA="$WS/data"
unset CC_UNITY_API_CHECK CLAUDE_PLUGIN_OPTION_CC_UNITY_API_CHECK CC_UNITY_META_CHECK CLAUDE_PLUGIN_OPTION_CC_UNITY_META_CHECK
BASH_BIN="$(command -v bash)"
BASE_PATH="$(dirname "$(command -v jq)"):$(dirname "$(command -v python3)"):$(dirname "$(command -v git)"):/usr/bin:/bin"

# payload <event> <tool> <cwd> <transcript> <file_path>
payload() {
  jq -cn --arg e "$1" --arg t "$2" --arg cwd "$3" --arg tp "$4" --arg f "$5" \
    '{session_id:"0f3c2a9e-1b7d-4e55-9a10-6c2b8d4e7f01", transcript_path:$tp, cwd:$cwd, permission_mode:"default",
      hook_event_name:$e, tool_name:$t, tool_use_id:"toolu_01", tool_input:{file_path:$f, old_string:"a", new_string:"b"},
      tool_response:{filePath:$f, success:true}}'
}

# check <desc> <fire|silent> <grep-pattern-or-empty> <payload> [env assignments...]; HK picks the hook (default api-check)
check() {
  local desc="$1" expect="$2" pat="$3" pl="$4" out rc ok=1 ctx
  shift 4
  out=$(printf '%s' "$pl" | env PATH="$BASE_PATH" "$@" "$BASH_BIN" "${HK:-$HOOK}" 2>/dev/null); rc=$?
  [ "$rc" -eq 0 ] || ok=0
  case "$expect" in
    fire)
      ctx=$(printf '%s' "$out" | jq -r 'select(.hookSpecificOutput.hookEventName == "PostToolUse") | .hookSpecificOutput.additionalContext' 2>/dev/null)
      [ -n "$ctx" ] || ok=0
      [ -z "$pat" ] || printf '%s' "$ctx" | tr '\n' ' ' | grep -qE "$pat" || ok=0
      printf '%s' "$out" | jq -e 'has("decision") or (.hookSpecificOutput | has("permissionDecision"))' >/dev/null 2>&1 && ok=0 ;;
    silent) [ -z "$out" ] || ok=0 ;;
  esac
  if [ "$ok" -eq 1 ]; then pass=$((pass + 1)); printf 'PASS  %s\n' "$desc"
  else fail=$((fail + 1)); printf 'FAIL  %s (rc=%s out=%s)\n' "$desc" "$rc" "$out"; fi
}

assert() { # assert <desc> <command...>
  local desc="$1"; shift
  if "$@"; then pass=$((pass + 1)); printf 'PASS  %s\n' "$desc"
  else fail=$((fail + 1)); printf 'FAIL  %s\n' "$desc"; fi
}

# project <dir> <editor version> [cinemachine version]
project() {
  mkdir -p "$1/Assets/Scripts" "$1/ProjectSettings" "$1/Packages"
  printf 'm_EditorVersion: %s\nm_EditorVersionWithRevision: %s (abc)\n' "$2" "$2" > "$1/ProjectSettings/ProjectVersion.txt"
  if [ -n "${3:-}" ]; then printf '{"dependencies": {"com.unity.cinemachine": "%s"}}\n' "$3"; else printf '{"dependencies": {}}\n'; fi > "$1/Packages/manifest.json"
}
cs() { printf '%s\n' "$2" > "$1"; printf 'fileFormatVersion: 2\nguid: %s\n' "$(printf '%s' "$1" | cksum | cut -d' ' -f1 | awk '{printf "%032d", $1}')" > "$1.meta"; }

R="$WS/repo"; U="$R/Game"; mkdir -p "$R"; (cd "$R" && git init -q)
project "$U" 6000.5.0f1
TP="$R/.claude-home/projects/-repo/0f3c2a9e.jsonl"

cs "$U/Assets/Scripts/Clean.cs" 'public class Clean { int Id(UnityEngine.Object o) { return o.GetEntityId().GetHashCode(); } }'
check "a clean .cs is silent" silent '' "$(payload PostToolUse Write "$R" "$TP" "$U/Assets/Scripts/Clean.cs")"
cs "$U/Assets/Scripts/Ids.cs" 'using UnityEngine;
public class Ids {
  int A(GameObject go) { return go.GetInstanceID(); }
}'
check "a .cs using GetInstanceID() on 6000.5 fires api-removed" fire 'ERROR api-removed Assets/Scripts/Ids\.cs:3: GetInstanceID\(\) was removed in Unity 6000\.5' "$(payload PostToolUse Write "$R" "$TP" "$U/Assets/Scripts/Ids.cs")"
assert "the context marker landed on disk" sh -c "ls '$CLAUDE_PLUGIN_DATA'/*/unity-traps/api-seen-* >/dev/null 2>&1"
check "the same rule is silent the second time in one context" silent '' "$(payload PostToolUse Edit "$R" "$TP" "$U/Assets/Scripts/Ids.cs")"
cs "$U/Assets/Scripts/Ids.cs" 'using UnityEngine;
// a line added above
public class Ids {
  int A(GameObject go) { return go.GetInstanceID(); }
  int B(GameObject go) { return go.GetInstanceID(); }
}'
check "a moved line or a second use does not repeat the rule" silent '' "$(payload PostToolUse Edit "$R" "$TP" "$U/Assets/Scripts/Ids.cs")"
check "a new context hears it again" fire 'api-removed Assets/Scripts/Ids\.cs:4: .*\(2 uses, first shown\)' "$(payload PostToolUse Edit "$R" "$WS/c2.jsonl" "$U/Assets/Scripts/Ids.cs")"
check "another file's finding is not shown on a clean file's edit" silent '' "$(payload PostToolUse Edit "$R" "$WS/c3.jsonl" "$U/Assets/Scripts/Clean.cs")"
cs "$U/Assets/Scripts/Guarded.cs" 'public class Guarded {
#if !UNITY_6000_5_OR_NEWER
  int A(UnityEngine.Object o) { return o.GetInstanceID(); }
#endif
}'
check "a name under an #if UNITY_* guard is silent" silent '' "$(payload PostToolUse Write "$R" "$WS/c4.jsonl" "$U/Assets/Scripts/Guarded.cs")"
cs "$U/Assets/Scripts/Mover.cs" 'using UnityEngine;
public class Walker : MonoBehaviour { }'
check "move damage in the edited file (a class/file name mismatch) is not this hook's to say" silent '' "$(payload PostToolUse Write "$R" "$WS/c5.jsonl" "$U/Assets/Scripts/Mover.cs")"
HK="$META" check "meta-check stays silent on the same .cs Write, so nothing is said twice" silent '' "$(payload PostToolUse Write "$R" "$WS/c6.jsonl" "$U/Assets/Scripts/Ids.cs")"
mkdir -p "$U/Library/Scratch"; printf 'public class X { int A(UnityEngine.Object o) { return o.GetInstanceID(); } }\n' > "$U/Library/Scratch/X.cs"
check "a .cs outside Assets/ is silent" silent '' "$(payload PostToolUse Write "$R" "$WS/c7.jsonl" "$U/Library/Scratch/X.cs")"
mkdir -p "$R/tools"; printf 'public class Y { int A(UnityEngine.Object o) { return o.GetInstanceID(); } }\n' > "$R/tools/Y.cs"
check "a .cs outside any Unity project is silent" silent '' "$(payload PostToolUse Write "$R" "$WS/c8.jsonl" "$R/tools/Y.cs")"

O="$WS/old"; project "$O" 6000.0.30f1
cs "$O/Assets/Scripts/Ids.cs" 'public class Ids { int A(UnityEngine.Object o) { return o.GetInstanceID(); } }'
check "the same name on 6000.0, before its window, is silent" silent '' "$(payload PostToolUse Write "$WS" "$WS/c9.jsonl" "$O/Assets/Scripts/Ids.cs")"

C="$WS/cm"; project "$C" 6000.0.30f1 3.1.2
cs "$C/Assets/Scripts/Cam.cs" 'using Unity.Cinemachine;
public class Cam {
  CinemachineVirtualCamera a; CinemachineFreeLook b; CinemachineTransposer c;
  CinemachineComposer d; CinemachinePOV e; CinemachineCollider f; CinemachineConfiner g;
}'
check "Cinemachine 2 names on Cinemachine 3 fire api-deprecated, capped with a count" fire 'WARNING api-deprecated Assets/Scripts/Cam\.cs:3: CinemachineVirtualCamera is deprecated since com\.unity\.cinemachine 3\.0.*\(\+2 more, not repeated' "$(payload PostToolUse MultiEdit "$WS" "$WS/c10.jsonl" "$C/Assets/Scripts/Cam.cs")"
check "counted findings are not repeated in that context" silent '' "$(payload PostToolUse Edit "$WS" "$WS/c10.jsonl" "$C/Assets/Scripts/Cam.cs")"

check "a Bash call is silent" silent '' "$(jq -cn --arg cwd "$R" --arg tp "$WS/c11.jsonl" '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$cwd,transcript_path:$tp,session_id:"s",tool_input:{command:"cat Game/Assets/Scripts/Ids.cs"}}')"
check "PreToolUse is silent" silent '' "$(payload PreToolUse Write "$R" "$WS/c12.jsonl" "$U/Assets/Scripts/Ids.cs")"
check "CC_UNITY_API_CHECK=off is silent" silent '' "$(payload PostToolUse Write "$R" "$WS/c13.jsonl" "$U/Assets/Scripts/Ids.cs")" CC_UNITY_API_CHECK=off
check "the /config option set false is silent" silent '' "$(payload PostToolUse Write "$R" "$WS/c14.jsonl" "$U/Assets/Scripts/Ids.cs")" CLAUDE_PLUGIN_OPTION_CC_UNITY_API_CHECK=false
check "the variable overrides the option" fire 'api-removed' "$(payload PostToolUse Write "$R" "$WS/c15.jsonl" "$U/Assets/Scripts/Ids.cs")" CLAUDE_PLUGIN_OPTION_CC_UNITY_API_CHECK=false CC_UNITY_API_CHECK=on
check "the meta-check switch does not silence this hook" fire 'api-removed' "$(payload PostToolUse Write "$R" "$WS/c16.jsonl" "$U/Assets/Scripts/Ids.cs")" CC_UNITY_META_CHECK=off

mkdir -p "$WS/ro"; chmod 500 "$WS/ro"
check "unwritable state is silent, exit 0" silent '' "$(payload PostToolUse Write "$R" "$WS/c17.jsonl" "$U/Assets/Scripts/Ids.cs")" CLAUDE_PLUGIN_DATA="$WS/ro/data"
chmod 700 "$WS/ro"
mkdir -p "$WS/nopy"; ln -s "$(command -v jq)" "$WS/nopy/jq"
check "no python3 on PATH is silent, exit 0" silent '' "$(payload PostToolUse Write "$R" "$WS/c18.jsonl" "$U/Assets/Scripts/Ids.cs")" PATH="$WS/nopy:/nonexistent"
check "without CLAUDE_PLUGIN_DATA the repo state dir is used" fire 'api-removed' "$(payload PostToolUse Write "$R" "$WS/c19.jsonl" "$U/Assets/Scripts/Ids.cs")" CLAUDE_PLUGIN_DATA=
assert "the repo-fallback state dir is invisible to git" sh -c "[ -f '$R/.cc-artifacts/unity-traps/.gitignore' ] && [ -z \"\$(git -C '$R' status --porcelain .cc-artifacts)\" ]"

echo "api-check-hook: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
