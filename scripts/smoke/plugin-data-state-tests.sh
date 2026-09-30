#!/usr/bin/env bash
# Drives a prompt, an edit and a stop through every registered hook in two identical scratch
# repos — CLAUDE_PLUGIN_DATA unset (control) and set per plugin (treatment) — and checks that
# moved hook state (the plugin-data rows of git-workflow's marketplace-scratch.tsv) leaves the
# repo only when the variable is set. The control arm must create .claude/code-review/, or the
# treatment's absence check would pass on a run where no hook wrote anything.
# Every hook runs under env -i with HOME, CLAUDE_CONFIG_DIR and TMPDIR inside the temp dir.
# WHAT IT DOES NOT CATCH: only UserPromptSubmit, Pre/PostToolUse on Edit and Stop are fired, so a
# writer on another event — compact-capsule.sh (SessionStart compact), SubagentStop, PostToolUse on
# Agent|Task|Skill or Bash — could still write into the repo unnoticed. The host itself was measured
# exporting CLAUDE_PLUGIN_DATA only to SessionStart; this harness sets it for every event.
set -u
cd "$(dirname "$0")/../.." || exit 2   # repo root
command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit 0; }

ROOT=$(pwd -P)
TSV=plugins/git-workflow/skills/branch-completion/references/marketplace-scratch.tsv
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
rc=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 — $2"; rc=1; }

moved=$(awk -F'\t' '$1 !~ /^#/ && $4 == "plugin-data" {
  n = $1; sub(/^\.claude\//, "", n); sub(/\/$/, "", n); print n }' "$TSV")
[ -n "$moved" ] || { echo "FAIL: no plugin-data rows read from $TSV"; exit 1; }

mkdir -p "$T/home/.claude" "$T/tmp"
iso() { env -i PATH="$PATH" HOME="$T/home" CLAUDE_CONFIG_DIR="$T/home/.claude" TMPDIR="$T/tmp" "$@"; }

# plugin, plugin dir, event, matcher, command, timeout — US-separated: an empty matcher
# between two tabs would collapse, since tab is IFS whitespace.
US=$'\x1f'
HOOKS=$(for hj in plugins/*/hooks/hooks.json; do
  d="$ROOT/${hj%/hooks/hooks.json}"
  jq -r --arg p "${d##*/}" --arg d "$d" '.hooks // {} | to_entries[] | .key as $e | .value[]?
    | (.matcher // "") as $m | .hooks[]? | select(.type=="command")
    | [$p, $d, $e, $m, (.command | gsub("\""; "")), ((.timeout // 60) | tostring)] | join("\u001f")' "$hj"
done)

fits() { # <matcher> <tool>
  local re
  [ -z "$1" ] || [ "$1" = "*" ] && return 0
  re="^($1)\$"
  [[ $2 =~ $re ]]
}

DATA=""
fire() { # <repo> <event> <tool, empty for a tool-less event> <payload>
  local p d e m cmd to extra
  while IFS=$US read -r p d e m cmd to; do
    [ "$e" = "$2" ] || continue
    [ -z "$3" ] || fits "$m" "$3" || continue
    extra=()
    [ -n "$DATA" ] && extra=(CLAUDE_PLUGIN_DATA="$DATA/$p")
    printf '%s' "$4" | (cd "$1" && iso CLAUDE_PLUGIN_ROOT="$d" ${extra[@]+"${extra[@]}"} \
      perl -e 'alarm shift; exec @ARGV' "$to" "${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/$d}") >/dev/null 2>&1 || :
  done <<EOF
$HOOKS
EOF
}

TEST_BEFORE="import { add } from './app.js';

test('add sums two numbers', () => {
  expect(add(1, 2)).toBe(3);
});
"
TEST_AFTER="import { add } from './app.js';

test('add sums two numbers', () => {
  expect(add(1, 2)).toBe(3);
  expect(add(-1, 1)).toBe(0);
});
"
CSS_BEFORE=".button {
  color: #111827;
}
"
CSS_AFTER=".button {
  color: #111827;
  background: #6366f1;
}
"
REPORT='Done: the new case lives in src/validate.js:12 and the suite passes.'

edit() { # <repo> <sid> <transcript> <rel path> <old> <new> <content after>
  local fp="$1/$4" pre post
  pre=$(jq -cn --arg s "$2" --arg t "$3" --arg c "$1" --arg f "$fp" --arg o "$5" --arg n "$6" \
    '{session_id:$s, transcript_path:$t, cwd:$c, hook_event_name:"PreToolUse", tool_name:"Edit",
      tool_input:{file_path:$f, old_string:$o, new_string:$n}}')
  fire "$1" PreToolUse Edit "$pre"
  printf '%s' "$7" > "$fp"
  post=$(printf '%s' "$pre" | jq -c --arg f "$fp" \
    '.hook_event_name = "PostToolUse" | .tool_response = {filePath:$f, success:true}')
  fire "$1" PostToolUse Edit "$post"
}

arm() { # <name> <CLAUDE_PLUGIN_DATA root, empty for the control>
  local repo="$T/$1/proj.app" tp="$T/$1/transcript.jsonl" sid="harness-$1" p
  DATA=$2
  mkdir -p "$repo/src"
  printf 'export function add(a, b) {\n  return a + b;\n}\n' > "$repo/src/app.js"
  printf '%s' "$TEST_BEFORE" > "$repo/src/app.test.js"
  printf '%s' "$CSS_BEFORE" > "$repo/styles.css"
  iso git -C "$repo" init -q
  iso git -C "$repo" add -A
  iso git -C "$repo" -c user.name=harness -c user.email=harness@example.invalid \
    -c commit.gpgsign=false commit -qm init
  jq -cn --arg s "$sid" --arg r "$REPORT" '
    {type:"user", sessionId:$s, message:{role:"user", content:"add a negative-number case to the add test"}},
    {type:"assistant", sessionId:$s, message:{role:"assistant", content:[{type:"text", text:$r}]}}' > "$tp"
  for p in 'add a negative-number case to the add test in src/app.test.js and give the button an accent colour' \
           '/code-review:review'; do
    fire "$repo" UserPromptSubmit "" "$(jq -cn --arg s "$sid" --arg t "$tp" --arg c "$repo" --arg p "$p" \
      '{session_id:$s, transcript_path:$t, cwd:$c, hook_event_name:"UserPromptSubmit", prompt:$p}')"
  done
  edit "$repo" "$sid" "$tp" src/app.test.js '  expect(add(1, 2)).toBe(3);' \
    "$(printf '  expect(add(1, 2)).toBe(3);\n  expect(add(-1, 1)).toBe(0);')" "$TEST_AFTER"
  edit "$repo" "$sid" "$tp" styles.css '  color: #111827;' \
    "$(printf '  color: #111827;\n  background: #6366f1;')" "$CSS_AFTER"
  fire "$repo" Stop "" "$(jq -cn --arg s "$sid" --arg t "$tp" --arg c "$repo" --arg r "$REPORT" \
    '{session_id:$s, transcript_path:$t, cwd:$c, hook_event_name:"Stop", stop_hook_active:false,
      last_assistant_message:$r}')"
}

# The host creates a plugin's data dir on first reference (manifest-reference, doc-stated).
for p in $(printf '%s\n' "$HOOKS" | cut -d "$US" -f1 | sort -u); do mkdir -p "$T/data/$p"; done
arm ctl ""
arm trt "$T/data"

S=""
for n in $moved; do [ -d "$T/ctl/proj.app/.claude/$n" ] && S="$S $n"; done
S=${S# }
echo "S (moved-state dirs the control arm created under .claude/): ${S:-<none>}"
# Names these payloads cannot reach: design-kit's row is legacy, with no current writer.
unreach="design-kit"
missing=""
for n in $moved; do
  case " $unreach " in *" $n "*) continue ;; esac
  case " $S " in *" $n "*) ;; *) missing="$missing $n" ;; esac
done
if [ -z "$missing" ]; then
  pass "control — unset CLAUDE_PLUGIN_DATA writes the legacy dirs"
else
  fail "control — unset CLAUDE_PLUGIN_DATA writes the legacy dirs" \
    "control repo lacks .claude/<name>/ for:$missing (S: ${S:-<empty>}) — the treatment check below would be vacuous for them"
fi

bad=""
for n in $moved; do [ -e "$T/trt/proj.app/.claude/$n" ] && bad="$bad .claude/$n/"; done
if [ -z "$bad" ]; then
  pass "no .claude/<plugin>/ dir for moved state with CLAUDE_PLUGIN_DATA set"
else
  fail "no .claude/<plugin>/ dir for moved state with CLAUDE_PLUGIN_DATA set" "treatment repo has:$bad"
fi

miss=""
[ -n "$S" ] || miss=" <S is empty>"
for n in $S; do
  found=""
  for x in "$T/data"/*/*/"$n"; do [ -d "$x" ] && found=1; done
  [ -n "$found" ] || miss="$miss data/*/*/$n"
done
if [ -z "$miss" ]; then
  pass "moved state landed under CLAUDE_PLUGIN_DATA"
else
  fail "moved state landed under CLAUDE_PLUGIN_DATA" "missing:$miss"
fi

# The key carries the repo's basename on purpose; a leak is its parent/basename fragment.
frag=$(printf '%s' "trt/proj.app" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-')
keys=0; badkey=""
for k in "$T/data"/*/*; do
  [ -e "$k" ] || continue
  keys=$((keys + 1)); name=${k##*/}
  if [ ! -d "$k" ] || ! [[ $name =~ ^[A-Za-z0-9_-]+-[0-9]+$ ]]; then
    badkey="$badkey ${k#"$T"/}"
  else
    case "$name" in *"$frag"*) badkey="$badkey ${k#"$T"/}" ;; esac
  fi
done
if [ "$keys" -gt 0 ] && [ -z "$badkey" ]; then
  pass "project key is hashed, never a raw path"
else
  fail "project key is hashed, never a raw path" "key dirs: $keys; offending:${badkey:- <none>}"
fi

exit "$rc"
