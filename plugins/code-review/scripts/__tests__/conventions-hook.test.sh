#!/usr/bin/env bash
# Fixtures for plugins/code-review/hooks/conventions.sh.
#
# The load-bearing assertion is a NEGATIVE one: the hook must emit PATHS and must
# NOT emit a digest of what those files say. An earlier design summarised "the
# three settings most often violated", which is exactly the shape
# rationale/stack-skill-baselines.md measured as making a review WORSE — the agent
# that read three bullets returned findings that were a strict subset of what the
# blind control found by opening the file. A summary substitutes for a read, so the
# fixture below asserts that no setting VALUE appears in the output.
set -u
H="$(cd "$(dirname "$0")/../.." && pwd)/hooks/conventions.sh"
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

# ISOLATE THE ONCE-PER-SESSION MARKER. The hook records "already fired" as a
# directory under $TMPDIR keyed on the session id. Without a scratch TMPDIR these
# fixtures pass on a clean machine and fail on the second run — or, worse, on a
# machine where a real session happened to use the same id, which makes the
# harness order-dependent in a way nothing would explain. Same failure the
# context-budget dynamic meter hit.
mkdir -p "$FX/tmp"
export TMPDIR="$FX/tmp"
# This session exports CLAUDE_PROJECT_DIR (the marketplace repo); a fixture outside git
# must resolve to its own directory, not to that.
unset CLAUDE_PROJECT_DIR CC_REMIND CC_CONVENTIONS
unset CLAUDE_PLUGIN_DATA   # the effects cases read the marker under <root>/.claude

mkdir -p "$FX/repo/.github/workflows" "$FX/repo/src" "$FX/bare"
printf 'root = true\n[*]\nindent_style = tab\nquote_type = double\nmax_line_length = 120\n' > "$FX/repo/.editorconfig"
printf '{"formatter":{"enabled":true}}\n' > "$FX/repo/biome.json"
printf 'jobs:\n  ci:\n    steps:\n      - run: npx biome check .\n' > "$FX/repo/.github/workflows/ci.yml"
mkdir -p "$FX/repo/docs"
printf '# Contributing\n\nZebrafinch rule: every service class ends in Svc.\n' > "$FX/repo/CONTRIBUTING.md"
printf 'Name modules after the noun they own.\n' > "$FX/repo/docs/CODING_STANDARDS.md"

fire() { # file cwd session -> additionalContext (empty when silent)
  jq -nc --arg f "$1" --arg c "$2" --arg s "$3" \
    '{tool_name:"Edit",session_id:$s,cwd:$c,tool_input:{file_path:$f}}' \
  | bash "$H" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

out=$(fire "$FX/repo/src/a.ts" "$FX/repo" s1)

for want in ".editorconfig" "biome.json" "npx biome check"; do
  if printf '%s' "$out" | grep -qF "$want"; then echo "PASS: names $want"
  else echo "FAIL: did not name $want"; rc=1; fi
done

# THE negative assertion: values from inside the config must not be echoed.
leaked=0
for v in "indent_style" "tab" "double" "120"; do
  printf '%s' "$out" | grep -qF "$v" && { echo "FAIL: leaked config VALUE '$v' — this is the digest shape the doctrine measured as harmful"; leaked=1; rc=1; }
done
[ "$leaked" -eq 0 ] && echo "PASS: emits locations only, no distilled settings"

# CI authority is not derivable from any config file, so it must be stated.
if printf '%s' "$out" | grep -q 'CI actually invokes'; then
  echo "PASS: states that CI is authoritative"
else echo "FAIL: CI-authoritative rule missing"; rc=1; fi

# ---- prose standards docs (0.28.0) --------------------------------------------------
if printf '%s\n' "$out" | awk '/^  configs:/{c=NR} /^  standards: CONTRIBUTING.md docs\/CODING_STANDARDS.md /{s=NR} END{exit !(c && s == c + 1)}'; then
  echo "PASS: names present standards docs on their own standards: line after configs:"
else echo "FAIL: standards docs not on their own line after configs: $out"; rc=1; fi
if printf '%s' "$out" | grep -qF 'standards: CONTRIBUTING.md' && ! printf '%s' "$out" | grep -qF 'Zebrafinch'; then
  echo "PASS: a named standards doc's content never appears in the output"
else echo "FAIL: standards doc unnamed or its content leaked: $out"; rc=1; fi

mkdir -p "$FX/nodoc/src" "$FX/doconly/src"
printf 'root = true\n' > "$FX/nodoc/.editorconfig"
o=$(fire "$FX/nodoc/src/a.ts" "$FX/nodoc" std1)
if [ -n "$o" ] && ! printf '%s' "$o" | grep -qF 'standards:'; then echo "PASS: no standards doc, no standards: line"
else echo "FAIL: no standards doc: ${o:-<silent>}"; rc=1; fi

printf 'Prefer early returns.\n' > "$FX/doconly/CONTRIBUTING.md"
o=$(fire "$FX/doconly/src/a.ts" "$FX/doconly" std2)
printf '%s' "$o" | grep -qF '  standards: CONTRIBUTING.md' && echo "PASS: a repo with only CONTRIBUTING.md fires" \
  || { echo "FAIL: a repo with only CONTRIBUTING.md: ${o:-<silent>}"; rc=1; }
if [ -n "$o" ] && ! printf '%s' "$o" | grep -qF 'CI actually invokes'; then echo "PASS: a doc-only repo gets no CI paragraph"
else echo "FAIL: a doc-only repo: ${o:-<silent>}"; rc=1; fi

# ---- the five non-GitHub CI formats ------------------------------------------------
# The message tells the reader that whatever CI invokes is the standard. On every GitLab,
# CircleCI, Jenkins, Azure and Bitbucket repo it then named nothing, because the sweep read
# `.github/workflows/` and nothing else (panel 2026-09-22, SW 6). Each fixture below is the
# canonical shape of its format, and the assertion is that the COMMAND is extracted, not
# merely that a line appeared.
ci_case() { # label relative-path heredoc-on-stdin expected-command
  local label="$1" rel="$2" want="$3" dir
  dir="$FX/ci-$label"
  mkdir -p "$dir/src" "$dir/$(dirname "$rel")"
  printf 'root = true\n[*]\nindent_style = tab\n' > "$dir/.editorconfig"
  cat > "$dir/$rel"
  local o; o=$(fire "$dir/src/a.ts" "$dir" "ci-$label")
  if printf '%s' "$o" | grep -qF "CI runs: $rel"; then
    if printf '%s' "$o" | grep -qF -- "— $want"; then echo "PASS: $label names its CI lint command"
    else echo "FAIL: $label named the file but not '$want': $o"; rc=1; fi
  else echo "FAIL: $label produced no CI line: ${o:-<silent>}"; rc=1; fi
}

ci_case gitlab .gitlab-ci.yml 'npm run lint' <<'YML'
stages:
  - test
lint:
  stage: test
  script:
    - npm ci
    - npm run lint
YML

ci_case circleci .circleci/config.yml 'npm run lint' <<'YML'
version: 2.1
jobs:
  build:
    steps:
      - checkout
      - run: npm run lint
YML

ci_case jenkins Jenkinsfile 'npm run lint' <<'GROOVY'
pipeline {
  stages {
    stage('Lint') {
      steps {
        sh 'npm run lint'
      }
    }
  }
}
GROOVY

ci_case azure azure-pipelines.yml 'npm run lint' <<'YML'
steps:
  - script: npm run lint
    displayName: Lint
YML

ci_case bitbucket bitbucket-pipelines.yml 'npm run lint' <<'YML'
pipelines:
  default:
    - step:
        script:
          - npm run lint
YML

silent() { # label file cwd session
  local o; o=$(fire "$2" "$3" "$4")
  if [ -z "$o" ]; then echo "PASS: $1 (silent)"; else echo "FAIL: $1 — fired"; rc=1; fi
}

silent "second write in the same session"  "$FX/repo/src/b.ts"    "$FX/repo" s1
silent "markdown is out of scope"          "$FX/repo/README.md"   "$FX/repo" s2
silent "json is out of scope"              "$FX/repo/data.json"   "$FX/repo" s3
silent "repo with no convention configs"   "$FX/bare/x.ts"        "$FX/bare" s4

o=$(jq -nc --arg f "$FX/repo/src/c.ts" --arg c "$FX/repo" \
      '{tool_name:"Edit",session_id:"s5",cwd:$c,tool_input:{file_path:$f}}' \
    | CC_CONVENTIONS=off bash "$H" 2>/dev/null)
[ -z "$o" ] && echo "PASS: CC_CONVENTIONS=off silences it" || { echo "FAIL: off switch ignored"; rc=1; }

o=$(jq -nc --arg f "$FX/repo/src/d.ts" --arg c "$FX/repo" \
      '{tool_name:"Edit",session_id:"s6",cwd:$c,tool_input:{file_path:$f}}' \
    | CC_REMIND=off bash "$H" 2>/dev/null)
[ -z "$o" ] && echo "PASS: CC_REMIND=off silences it" || { echo "FAIL: marketplace-wide off switch ignored"; rc=1; }

if printf 'not json' | bash "$H" >/dev/null 2>&1; then
  echo "PASS: garbage input exits 0 (fail-open)"
else echo "FAIL: garbage input did not exit 0"; rc=1; fi

# ---- the payload the host actually sends -------------------------------------------
# Every case above sends session_id and no transcript_path, so they graded the FALLBACK
# branch of `.transcript_path // .session_id`. conventions.sh hashes that value through
# cksum before it becomes a filename, which is what makes it safe — but that is exactly
# the property nothing here exercised. Three sibling hooks shipped broken behind a green
# suite for want of these two cases. Gated by pc_harness_payload.
TP='/Users/x/.claude/projects/-Users-x-proj/abcdef01-2345-6789.jsonl'
tpfire() { # file cwd -> additionalContext
  jq -nc --arg f "$1" --arg c "$2" --arg t "$TP" \
    '{tool_name:"Edit",session_id:"11111111-2222-3333-4444-555555555555",transcript_path:$t,cwd:$c,tool_input:{file_path:$f}}' \
    | bash "$H" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
first=$(tpfire "$FX/repo/src/tp1.ts" "$FX/repo")
if [ -n "$first" ]; then echo "PASS: transcript_path present — the hook still speaks"
else echo "FAIL: transcript_path present — the hook went silent"; rc=1; fi

second=$(tpfire "$FX/repo/src/tp2.ts" "$FX/repo")
if [ -z "$second" ]; then echo "PASS: transcript_path present — the one-shot still bounds the context"
else echo "FAIL: transcript_path present — fired twice in one context: $second"; rc=1; fi

# ---- Bash writes, and configs read at the project root (0.23.0) ---------------------
# The host steers writes through Bash — 233 of 238 main-thread writes in one measured
# session were `cat > file <<EOF` (rationale/2026-09-25-session-plugin-usage-review.md,
# finding 1) — and the payload cwd follows the model's `cd` (finding 2). A git repo, so the
# project root and the cwd can differ.
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found — Bash/root cases"; exit "$rc"; }
G="$FX/grepo"
mkdir -p "$G/src" "$G/app/Enums" "$FX/outside"
git -C "$G" init -q
printf 'root = true\n' > "$G/.editorconfig"
printf '{}\n' > "$G/biome.json"
# The context is transcript_path; every call shares one session_id, as a session's subagents do.
bfire() { # command cwd context [session] [event] -> additionalContext
  bfire_raw "$@" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
bfire_raw() { # command cwd context [session] [event] -> raw stdout
  jq -nc --arg x "$1" --arg c "$2" --arg s "${4:-sess}" --arg t "/t/$3.jsonl" --arg e "${5:-PostToolUse}" \
    '{hook_event_name:$e,tool_name:"Bash",session_id:$s,transcript_path:$t,cwd:$c,tool_input:{command:$x}}' \
    | bash "$H" 2>/dev/null
}

printf 'export const a = 1\n' > "$G/src/made.ts"
o=$(bfire "cat > src/made.ts <<'EOF'
export const a = 1
EOF" "$G" b1)
printf '%s' "$o" | grep -qF '.editorconfig' && echo "PASS: a Bash heredoc write of a code file fires" \
  || { echo "FAIL: a Bash heredoc write of a code file stayed silent"; rc=1; }
o=$(jq -nc --arg f "$G/src/next.ts" --arg c "$G" \
      '{tool_name:"Edit",session_id:"b1",transcript_path:"/t/b1.jsonl",cwd:$c,tool_input:{file_path:$f}}' \
    | bash "$H" 2>/dev/null)
[ -z "$o" ] && echo "PASS: the one-shot spent on Bash also covers a later Edit (silent)" \
  || { echo "FAIL: fired again after a Bash write spent the one-shot"; rc=1; }

quiet() { # label output
  if [ -z "$2" ]; then echo "PASS: $1 (silent)"; else echo "FAIL: $1 — fired"; rc=1; fi
}
printf 'x\n' > "$G/notes.txt"
quiet "Bash write of a non-code file"         "$(bfire 'echo x > notes.txt' "$G" b2)"
quiet "Bash command with no write"            "$(bfire 'ls -la && git status' "$G" b3)"
quiet "Bash write target that does not exist" "$(bfire 'cat > src/never.ts <<EOF
x
EOF' "$G/app" b4)"
printf 'x\n' > "$FX/outside/o.ts"
quiet "Bash write outside the project root"   "$(bfire "echo x > $FX/outside/o.ts" "$G" b5)"

# From a subdirectory: a relative target resolves against the Bash cwd, and the configs
# are found at the root. Before 0.23.0 this looked for .editorconfig in app/Enums.
printf '<?php\n' > "$G/app/Enums/Status.php"
o=$(bfire "printf '<?php' > Status.php" "$G/app/Enums" b6)
printf '%s' "$o" | grep -qF 'biome.json' && echo "PASS: Bash write from a subdirectory names the root configs" \
  || { echo "FAIL: Bash write from a subdirectory: ${o:-<silent>}"; rc=1; }
o=$(fire "$G/app/Enums/Kind.php" "$G/app/Enums" e7)
printf '%s' "$o" | grep -qF '.editorconfig' && echo "PASS: Edit with a subdirectory cwd names the root configs" \
  || { echo "FAIL: Edit with a subdirectory cwd: ${o:-<silent>}"; rc=1; }

# ---- interpreter writes (bash-write-effects, 0.33.0) -------------------------------------
# One repo per case: a reused one carries an earlier case's marker. A first call in another
# context dates the marker, as any earlier call would.
if command -v python3 >/dev/null 2>&1; then
  prun() { # repo session python-source -> runs it as a heredoc, then the hook on that command
    local c="python3 - <<'PY'
$3
PY"
    (cd "$1" && bash -c "$c") >/dev/null 2>&1
    bfire "$c" "$1" "$2"
  }
  efire() { # file repo context -> an Edit's PostToolUse in the context bfire keys
    jq -nc --arg f "$1" --arg c "$2" --arg t "/t/$3.jsonl" \
      '{hook_event_name:"PostToolUse",tool_name:"Edit",session_id:"sess",transcript_path:$t,cwd:$c,tool_input:{file_path:$f}}' \
      | bash "$H" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
  }
  efx() { # name [nomark] -> a git repo with an .editorconfig
    local d="$FX/eff-$1"; mkdir -p "$d/src"; git -C "$d" init -q; printf 'root = true\n' > "$d/.editorconfig"
    [ "${2:-}" = nomark ] || bfire 'ls' "$d" "$1-mark" >/dev/null
    printf '%s\n' "$d"
  }
  d=$(efx a)
  o=$(prun "$d" ea1 "open('src/made.ts', 'w').write('export const a = 1\n')")
  printf '%s' "$o" | grep -qF '.editorconfig' && echo "PASS: a code file a python heredoc wrote fires" \
    || { echo "FAIL: a code file a python heredoc wrote stayed silent"; rc=1; }
  quiet "a python heredoc that wrote only a non-code file" "$(prun "$d" ea2 "open('notes.txt', 'w').write('x\n')")"

  d=$(efx c nomark)
  o=$(prun "$d" ec1 "open('src/made.ts', 'w').write('export const a = 1\n')")
  [ -z "$o" ] && [ -f "$d/.claude/code-review/bash-effects-conventions.mark" ] && echo "PASS: the first call in a repo is silent and leaves the marker" \
    || { echo "FAIL: the first call in a repo — out [${o:+fired}] marker [$(ls "$d/.claude/code-review" 2>&1)]"; rc=1; }
  quiet "a python run that wrote nothing" "$(prun "$d" ec2 'print(1)')"

  d=$(efx e); printf 'export const e = 1\n' > "$d/src/edited.ts"; efire "$d/src/edited.ts" "$d" ee1 >/dev/null
  quiet "a code file an Edit wrote before the run" "$(prun "$d" ee2 'print(1)')"

  # A context whose one-shot is spent still dates the marker: the marker is per project, and another context reads it.
  d=$(efx s); printf 'export const s = 1\n' > "$d/src/first.ts"; efire "$d/src/first.ts" "$d" es1 >/dev/null
  printf 'export const t = 1\n' > "$d/src/late.ts"; bfire 'ls' "$d" es1 >/dev/null
  quiet "a code file written before a spent context's last call" "$(prun "$d" es2 'print(1)')"

  # A spent context reads no effects: its answer is already given, so the matching run costs no git status.
  shim="$FX/gitlog"; mkdir -p "$shim"; real_git=$(command -v git)
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/calls"\nexec "%s" "$@"\n' "$shim" "$real_git" > "$shim/git"; chmod +x "$shim/git"
  d=$(efx p); printf 'export const p = 1\n' > "$d/src/p.ts"; efire "$d/src/p.ts" "$d" ep1 >/dev/null
  printf 'export const q = 1\n' > "$d/src/q.ts"; : > "$shim/calls"
  PATH="$shim:$PATH" bfire "python3 -c 'print(1)'" "$d" ep1 >/dev/null
  if [ -s "$shim/calls" ] && ! grep -q 'status --porcelain' "$shim/calls"; then echo "PASS: a spent context's matching run reads no effects (no git status)"
  else echo "FAIL: a spent context's matching run ran git status: $(cat "$shim/calls")"; rc=1; fi

  d=$(efx f); (cd "$d" && python3 -c "open('src/f.ts', 'w').write('export const f = 1\n')")
  o=$(bfire_raw "python3 gen.py && false" "$d" ef1 sess PostToolUseFailure)
  printf '%s' "$o" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUseFailure" and (.hookSpecificOutput.additionalContext | contains(".editorconfig"))' >/dev/null 2>&1 \
    && echo "PASS: a failed python run (PostToolUseFailure) fires, its envelope naming that event" \
    || { echo "FAIL: a failed python run (PostToolUseFailure): ${o:-<silent>}"; rc=1; }
  jq -e '[.hooks.PostToolUseFailure[] | select(.matcher == "Bash") | .hooks[].command]
         | (any(test("hooks/conventions.sh")) and any(test("hooks/scan.sh")) and any(test("hooks/density.sh")))' \
    "$(dirname "$H")/hooks.json" >/dev/null 2>&1 && echo "PASS: conventions, scan and density are registered on PostToolUseFailure for Bash" \
    || { echo "FAIL: PostToolUseFailure Bash registration: $(jq -c '.hooks.PostToolUseFailure' "$(dirname "$H")/hooks.json")"; rc=1; }

  d=$(efx g); (cd "$d" && python3 -c "open('src/g.ts', 'w').write('export const g = 1\n')")
  quiet "a python run in a session that did not date the marker" "$(bfire "python3 gen.py" "$d" eg1 other-session)"
else
  echo "SKIP: python3 not found — interpreter-write cases"
fi

[ "$rc" -eq 0 ] && echo "All conventions-hook fixtures passed."
exit "$rc"
