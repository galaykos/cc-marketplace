#!/usr/bin/env bash
# measure-tools-tests.sh — runs turn-cost.sh (default and --workflow), comment-stats.sh and readability.sh on tiny fixtures; asserts exact counts and exit 0.
# Misses: transcript shapes and command forms no fixture copies; it proves the counting rules, never that a label matches what real sessions mean by it.
# Why, limits, history: rationale/improvement-plan-2026-10-26.md § Before values (m2, 2026-10-26)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT TERM HUP
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
# eq <label> <want> <got>
eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want '$2', got '$3'"; }
# run <outfile> <label> <command...> — captures the output and asserts the maintainer-tool exit-0 contract.
run() { local out="$1" label="$2" rc; shift 2; "$@" > "$out" 2>&1; rc=$?; eq "exit 0: $label" 0 "$rc"; }

# turn-cost --workflow fixture: one session, two kept blocks (the task notification folds into the second), a nested and an unlinked subagent.
T="$WORK/home/.claude/projects/-fixture-proj"
mkdir -p "$T/s1/subagents"
A='"type":"assistant","cwd":"/fixture/proj","timestamp":"2026-10-01T10:00:00Z","message":{"model":"claude-opus-5-5","usage":{"input_tokens":1,"output_tokens":1},"content":'
cat > "$T/s1.jsonl" <<EOF
{"type":"user","cwd":"/fixture/proj","timestamp":"2026-10-01T10:00:00Z","message":{"role":"user","content":"<command-message>taskmaster:task</command-message>\n<command-name>/taskmaster:task</command-name>\n<command-args>build x</command-args>"}}
{$A[{"type":"tool_use","id":"q1","name":"AskUserQuestion","input":{"questions":[{"question":"a"},{"question":"b"}]}}]}}
{$A[{"type":"tool_use","id":"q1","name":"AskUserQuestion","input":{"questions":[{"question":"a"},{"question":"b"}]}}]}}
{"type":"user","toolUseResult":{},"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"q1","content":"ok"}]}}
{$A[{"type":"tool_use","id":"ag1","name":"Agent","input":{"prompt":"x"}}]}}
{$A[{"type":"tool_use","id":"b1","name":"Bash","input":{"command":"bash scripts/validate.sh 2>&1 | tail -3"}},{"type":"tool_use","id":"b2","name":"Bash","input":{"command":"grep -n vitest package.json"}}]}}
{$A[{"type":"tool_use","id":"br1","name":"mcp__plugin_playwright_playwright__browser_navigate","input":{}}]}}
{"type":"user","isMeta":true,"message":{"role":"user","content":"Stop hook feedback:\n[gate.sh]: not yet"}}
{$A[{"type":"text","text":"done"}]}}
{"type":"user","timestamp":"2026-10-01T11:00:00Z","message":{"role":"user","content":"/code-review:review --fix"}}
{$A[{"type":"tool_use","id":"b3","name":"Bash","input":{"command":"npx vitest run"}},{"type":"tool_use","id":"b4","name":"Bash","input":{"command":"cd app && vendor/bin/pest"}}]}}
{"type":"user","timestamp":"2026-10-01T12:00:00Z","message":{"role":"user","content":"<task-notification>agent finished</task-notification>"}}
{$A[{"type":"text","text":"noted"}]}}
{"type":"user","timestamp":"2026-10-01T13:00:00Z","message":{"role":"user","content":"thanks"}}
EOF
S='"isSidechain":true,"type":"assistant","timestamp":"2026-10-01T10:05:00Z","message":{"model":"claude-opus-5-5","usage":{"input_tokens":1,"output_tokens":1},"content":'
cat > "$T/s1/subagents/agent-a1.jsonl" <<EOF
{$S[{"type":"tool_use","id":"s1","name":"Bash","input":{"command":"npm test"}},{"type":"tool_use","id":"s2","name":"mcp__claude-in-chrome__navigate","input":{}}]}}
{$S[{"type":"tool_use","id":"ag2","name":"Agent","input":{"prompt":"y"}}]}}
{"isSidechain":true,"type":"user","isMeta":true,"message":{"role":"user","content":"Stop hook feedback:\nnot yet"}}
EOF
printf '{"toolUseId":"ag1"}\n' > "$T/s1/subagents/agent-a1.meta.json"
printf '{%s[{"type":"tool_use","id":"s3","name":"Bash","input":{"command":"pytest -q"}}]}}\n' "$S" > "$T/s1/subagents/agent-a0.jsonl"
printf '{"toolUseId":"ag2"}\n' > "$T/s1/subagents/agent-a0.meta.json"
printf '{%s[{"type":"tool_use","id":"s4","name":"Bash","input":{"command":"pytest"}}]}}\n' "$S" > "$T/s1/subagents/agent-zz.jsonl"
printf '{"toolUseId":"nope"}\n' > "$T/s1/subagents/agent-zz.meta.json"

TC=(env HOME="$WORK/home" bash "$ROOT/scripts/turn-cost.sh" --workflow --project /fixture/proj)
run "$WORK/tc.json" "turn-cost --workflow --json" "${TC[@]}" --json
j() { jq -r "$1" "$WORK/tc.json" 2>&1; }
eq "turn-cost: kept blocks (a prompt with no request after it is dropped, a task notification opens none)" 2 "$(j .turn_blocks)"
eq "turn-cost: AskUserQuestion calls, a duplicated record counted once" 1 "$(j .totals.questions_calls.total)"
eq "turn-cost: questions inside AskUserQuestion" 2 "$(j .totals.questions_asked.total)"
eq "turn-cost: subagents spawned, nested spawn included" 2 "$(j .totals.subagents.total)"
eq "turn-cost: Stop-check blocks, main and subagent" 2 "$(j .totals.stop_blocks.total)"
eq "turn-cost: suite runs (grep of a runner name is not a run; unlinked subagent not counted)" 5 "$(j .totals.suite_runs.total)"
eq "turn-cost: suite runs median / p90 / max" "2.5 3 3" "$(j '.totals.suite_runs | "\(.median) \(.p90) \(.max)"')"
eq "turn-cost: browser calls (playwright + chrome)" 2 "$(j .totals.browser_calls.total)"
eq "turn-cost: per-block suite runs" "3 2" "$(j '[.blocks[].suite_runs] | map(tostring) | join(" ")')"
eq "turn-cost: events inside subagents (agents stops suites browser)" "1 1 2 1" \
  "$(j '.inside_subagents | "\(.subagents) \(.stop_blocks) \(.suite_runs) \(.browser_calls)"')"
eq "turn-cost: subagent transcripts joined / unlinked" "2 1" "$(j '.subagent_transcripts | "\(.joined) \(.unlinked)"')"
eq "turn-cost: opening slash commands" "/taskmaster:task /code-review:review" "$(j '[.blocks[].command] | map(tostring) | join(" ")')"
eq "turn-cost: harness frames counted" 1 "$(j .harness_frames)"
eq "turn-cost: no drift on a well-formed fixture" 0 "$(j '.drift | length')"
run "$WORK/tc.json" "turn-cost --suite-regex pytest" "${TC[@]}" --json --suite-regex pytest
eq "turn-cost: --suite-regex replaces the default" 1 "$(j .totals.suite_runs.total)"
run "$WORK/tc.txt" "turn-cost --workflow (text)" "${TC[@]}"
grep -q '/taskmaster:task' "$WORK/tc.txt" && ok "turn-cost: text report names the opening command" \
  || bad "turn-cost: text report names the opening command" "$(head -20 "$WORK/tc.txt")"
run "$WORK/tc.err" "turn-cost bad --suite-regex" "${TC[@]}" --suite-regex '('
grep -q 'does not compile' "$WORK/tc.err" && ok "turn-cost: a bad --suite-regex is reported" \
  || bad "turn-cost: a bad --suite-regex is reported" "$(cat "$WORK/tc.err")"
run "$WORK/tc.err" "turn-cost --suite-regex with no value" "${TC[@]}" --suite-regex
grep -q 'needs a value' "$WORK/tc.err" && ok "turn-cost: --suite-regex without a value is reported" \
  || bad "turn-cost: --suite-regex without a value is reported" "$(cat "$WORK/tc.err")"

# turn-cost request and block fixtures, default mode and --workflow: one response split over three records; harness frames mid-block.
mkdir -p "$WORK/home/.claude/projects/-fixture-split" "$WORK/home/.claude/projects/-fixture-frame"
M='"type":"assistant","timestamp":"2026-10-02T10:00:00Z","message":{"model":"claude-opus-5-5","usage":{"input_tokens":1000000,"output_tokens":0},'
cat > "$WORK/home/.claude/projects/-fixture-split/s2.jsonl" <<EOF
{"type":"user","cwd":"/fixture/split","timestamp":"2026-10-02T10:00:00Z","message":{"role":"user","content":"go"}}
{$M"id":"msg_1","content":[{"type":"thinking","thinking":"x"}]}}
{$M"id":"msg_1","content":[{"type":"text","text":"y"}]}}
{$M"id":"msg_1","content":[{"type":"tool_use","id":"t9","name":"Bash","input":{"command":"ls"}}]}}
EOF
# Records 5 and 7 copy a real peer message's and compaction summary's keys (text redacted); 3 and 11 make origin outrank the text, 9 has no origin.
cat > "$WORK/home/.claude/projects/-fixture-frame/s3.jsonl" <<EOF
{"type":"user","cwd":"/fixture/frame","timestamp":"2026-10-02T10:00:00Z","origin":{"kind":"human"},"message":{"role":"user","content":"go"}}
{$M"id":"msg_a","content":[{"type":"text","text":"a"}]}}
{"type":"user","timestamp":"2026-10-02T10:01:00Z","origin":{"kind":"task-notification","producer":"session-task"},"message":{"role":"user","content":"background task finished"}}
{$M"id":"msg_b","content":[{"type":"text","text":"b"}]}}
{"parentUuid":"u4","isSidechain":false,"promptId":"p1","type":"user","message":{"role":"user","content":"Another Claude session sent a message:\n<agent-message from=\"a1\">\n[redacted report]\n</agent-message>"},"isMeta":true,"uuid":"u5","timestamp":"2026-10-02T10:02:00Z","permissionMode":"auto","origin":{"kind":"peer","from":"a1","senderTaskId":"a1","name":"general-purpose","body":"[redacted]"}}
{$M"id":"msg_c","content":[{"type":"text","text":"c"}]}}
{"parentUuid":null,"isSidechain":false,"promptId":"p2","type":"user","message":{"role":"user","content":"This session is being continued from a previous conversation that ran out of context. [redacted summary]"},"isVisibleInTranscriptOnly":true,"isCompactSummary":true,"uuid":"u7","timestamp":"2026-10-02T10:03:00Z","userType":"external","entrypoint":"cli","cwd":"/fixture/frame","sessionId":"s3","version":"2.1.310","gitBranch":"main"}
{$M"id":"msg_d","content":[{"type":"text","text":"d"}]}}
{"type":"user","timestamp":"2026-10-02T10:04:00Z","message":{"role":"user","content":"<task-notification>done</task-notification>"}}
{$M"id":"msg_e","content":[{"type":"text","text":"e"}]}}
{"type":"user","timestamp":"2026-10-02T10:05:00Z","origin":{"kind":"human"},"message":{"role":"user","content":"<task-notification> is what I pasted"}}
{$M"id":"msg_f","content":[{"type":"text","text":"f"}]}}
EOF
DEF=(env HOME="$WORK/home" bash "$ROOT/scripts/turn-cost.sh" --json)
WF=(env HOME="$WORK/home" bash "$ROOT/scripts/turn-cost.sh" --workflow --json)
run "$WORK/tc.json" "turn-cost default --json (split)" "${DEF[@]}" --project /fixture/split
eq "turn-cost default: one message.id over three records is one request, priced once (requests, cents)" "1 400" "$(j '"\(.requests) \(.usd*100|round)"')"
run "$WORK/tc.json" "turn-cost default --json (frames)" "${DEF[@]}" --project /fixture/frame
eq "turn-cost default: frames and a compaction summary open no block (blocks, requests)" "2 6" "$(j '"\(.turn_blocks) \(.requests)"')"
run "$WORK/tc.json" "turn-cost --workflow --json (split)" "${WF[@]}" --project /fixture/split
eq "turn-cost --workflow: split response is one request in its block" 1 "$(j '.blocks[0].requests')"
run "$WORK/tc.json" "turn-cost --workflow --json (frames)" "${WF[@]}" --project /fixture/frame
eq "turn-cost --workflow: origin decides, peer and compaction fold (blocks frames compactions per-block-requests)" "2 3 1 5,1" \
  "$(j '"\(.turn_blocks) \(.harness_frames) \(.compact_summaries) \([.blocks[].requests] | map(tostring) | join(","))"')"

# bashrec <tool-id> <command> / userrec <text> <cwd> — one transcript record each, JSON-escaped by jq.
bashrec() { jq -cn --arg id "$1" --arg c "$2" '{type:"assistant",timestamp:"2026-10-03T10:00:00Z",message:{model:"claude-opus-5-5",usage:{input_tokens:1,output_tokens:1},content:[{type:"tool_use",id:$id,name:"Bash",input:{command:$c}}]}}'; }
userrec() { jq -cn --arg t "$1" --arg cwd "$2" '{type:"user",cwd:$cwd,timestamp:"2026-10-03T10:00:00Z",message:{role:"user",content:$t}}'; }
mkdir -p "$WORK/home/.claude/projects/-fixture-suite"
{
  userrec "mentions" /fixture/suite
  bashrec z1 'grep -n "bash scripts/validate.sh" CLAUDE.md'
  bashrec z2 'ls scripts/smoke/*.sh'
  bashrec z3 'gh pr create --body "runs context-budget.sh"'
  bashrec z4 "cat > /tmp/t.sh <<'EOF'
bash scripts/validate.sh
EOF"
  bashrec z5 'cd x && bash scripts/smoke/foo.sh'
  userrec "runs" /fixture/suite
  bashrec r1 'bash scripts/validate.sh'
  bashrec r2 'timeout 600 bash scripts/validate.sh'
  bashrec r3 'cd x && for t in scripts/smoke/*.sh; do bash "$t" >/dev/null || echo "FAIL $t"; done'
  bashrec r4 'for t in plugins/*/scripts/__tests__/*.test.sh; do bash "$t"; done'
  bashrec r5 'flock "$(git rev-parse --git-common-dir)/verify.lock" bash scripts/context-budget.sh'
  bashrec r6 'OFFICIAL_VALIDATE_ANY_VERSION=1 bash scripts/official-validate.sh'
  bashrec r7 'bash scripts/generate.sh --check'
  bashrec r8 "cat > /tmp/t.sh <<'EOF' && bash scripts/mod-tests.sh
echo hi
EOF"
  userrec "more runners" /fixture/suite
  bashrec n1 'python -m pytest -q'
  bashrec n2 'php artisan test'
  bashrec n3 'pnpm test'
  bashrec n4 'yarn test'
  bashrec n5 'bun test'
} > "$WORK/home/.claude/projects/-fixture-suite/s4.jsonl"
run "$WORK/tc.json" "turn-cost --workflow --json (suite)" "${WF[@]}" --project /fixture/suite
eq "turn-cost: suite runs per block (mentions, runs at a command position, item-2 runners)" "0 8 5" \
  "$(j '[.blocks[].suite_runs] | map(tostring) | join(" ")')"

mkdir -p "$WORK/home/.claude/projects/-fixture-p90"
{
  for n in 1 2 3 4 5 6 7 8 9 10; do
    userrec "block $n" /fixture/p90
    case $n in
      9) bashrec p9 'bash scripts/validate.sh' ;;
      10) for k in 1 2 3 4 5; do bashrec "p10_$k" 'bash scripts/validate.sh'; done ;;
      *) bashrec "p$n" 'ls' ;;
    esac
  done
} > "$WORK/home/.claude/projects/-fixture-p90/s5.jsonl"
run "$WORK/tc.json" "turn-cost --workflow --json (p90)" "${WF[@]}" --project /fixture/p90
eq "turn-cost: nearest-rank p90 sits below max at n=10 (p90 max)" "1 5" "$(j '.totals.suite_runs | "\(.p90) \(.max)"')"

L="$WORK/home/.claude/projects/-fixture-relink"
mkdir -p "$L/s6/subagents"
{
  userrec "first" /fixture/relink
  jq -cn '{type:"assistant",timestamp:"2026-10-03T10:00:00Z",message:{model:"claude-opus-5-5",usage:{input_tokens:1,output_tokens:1},content:[{type:"tool_use",id:"agX",name:"Agent",input:{}}]}}'
  userrec "second" /fixture/relink
  jq -cn '{type:"api-request-blob",message:{role:"assistant",content:[{type:"tool_use",id:"agX",name:"Agent",input:{}}]}}'
  bashrec l1 'ls'
} > "$L/s6.jsonl"
bashrec l2 'bash scripts/validate.sh' > "$L/s6/subagents/agent-r1.jsonl"
printf '{"toolUseId":"agX"}\n' > "$L/s6/subagents/agent-r1.meta.json"
run "$WORK/tc.json" "turn-cost --workflow --json (relink)" "${WF[@]}" --project /fixture/relink
eq "turn-cost: a re-seen tool id keeps its first block (suite runs per block)" "1 0" "$(j '[.blocks[].suite_runs] | map(tostring) | join(" ")')"

# comment-stats fixture: one file per area; only h.sh carries a compliant header.
C="$WORK/cs"
mkdir -p "$C/bin" "$C/plugins/p/hooks" "$C/plugins/p/scripts" "$C/plugins/p/tests" "$C/plugins/p/node_modules" "$C/plugins/p/template" "$C/scripts/lib" "$C/scripts/smoke"
cp "$ROOT/scripts/comment-stats.sh" "$C/bin/"
printf '#!/bin/bash\n# what it catches\n# Why, limits, history: rationale/derivations/x.md\nset -u\n\n# a why\necho hi\n' > "$C/plugins/p/hooks/h.sh"
printf '/**\n * doc line\n */\nconst a = 1; // trailing\n// whole\nlet b = 2;\n' > "$C/plugins/p/scripts/s.ts"
printf '// c1\nx();\n' > "$C/plugins/p/tests/t.test.ts"
printf '// vendored\nx();\n' > "$C/plugins/p/node_modules/v.js"
printf '// a\n// b\nrun();\n' > "$C/plugins/p/template/g.spec.mjs"
printf '# not code\n' > "$C/plugins/p/README.md"
printf '#!/usr/bin/env python3\n# one\n# two\n# three\n# Why, limits, history: y\nprint(1)\n' > "$C/scripts/x.py"
printf '# a\nx=1\n' > "$C/scripts/lib/l.sh"
printf '#!/bin/bash\nx=1\n# b\n' > "$C/scripts/smoke/t.sh"
run "$WORK/cs.json" "comment-stats --json" bash "$C/bin/comment-stats.sh" --json --top 1
k() { jq -r "$1" "$WORK/cs.json" 2>&1; }
eq "comment-stats: comment/code per area (hooks scripts scripts/ smoke lib tests; a .spec. file outside tests/ is a test)" "3/2 4/2 4/1 1/1 1/1 3/2" \
  "$(k '[.areas[] | "\(.comment)/\(.code)"] | join(" ")')"
eq "comment-stats: totals all / non-test (comment code share-in-tenths)" "16 9 640 / 13 7 650" \
  "$(k '"\(.all.comment) \(.all.code) \(.all.share_pct*10|round) / \(.non_test.comment) \(.non_test.code) \(.non_test.share_pct*10|round)"')"
eq "comment-stats: house headers (a 4-line block and a code-first file do not count)" "1 7" \
  "$(k '.house_header | "\(.compliant) \(.files)"')"
eq "comment-stats: --top 1 picks the most-commented file, ties by path" "plugins/p/scripts/s.ts 4" "$(k '.top[] | "\(.path) \(.comment)"')"

# readability fixture: one passage per pool with hand-counted sentence lengths.
R="$WORK/rd"
mkdir -p "$R/bin" "$R/plugins/p/skills/s" "$R/plugins/p/commands"
cp "$ROOT/scripts/readability.sh" "$R/bin/"
printf '# Title\n\nOne two three four five. Six seven eight nine ten eleven.\n\n## Next\nIgnored text here.\n' > "$R/README.md"
printf '# p\n\n<!-- c -->\n%s.\n' "$(seq -s ' ' -f 'w%g' 1 31)" > "$R/plugins/p/README.md"
printf -- '---\nname: s\ndescription: Use when a b c. Then d e\nwhen_to_use: f g h i\n---\nbody text. Not counted here.\n' > "$R/plugins/p/skills/s/SKILL.md"
printf -- '---\ndescription: "Run `x.y` now, e.g. Today is fine"\n---\n' > "$R/plugins/p/commands/c.md"
printf '# H\n\nAlpha beta gamma. Delta epsilon.\n\n| a | b |\n|---|---|\n\n```bash\necho skip me. Not counted.\n```\n\n- List item one two three.\n- Second item has six words here.\n' > "$R/CLAUDE.md"
run "$WORK/rd.json" "readability --json" bash "$R/bin/readability.sh" --json --top 1
r() { jq -r "$1" "$WORK/rd.json" 2>&1; }
eq "readability: README openings (passages, sentences, tenths of words/sentence and of %>30)" "2 3 140 333" \
  "$(r '.pools["README openings"] | "\(.passages) \(.sentences) \(.words_per_sentence*10|round) \(.over_30_pct*10|round)"')"
eq "readability: SKILL description + when_to_use" "1 3 12 40" \
  "$(r '.pools["SKILL description+when_to_use"] | "\(.passages) \(.sentences) \(.words) \(.words_per_sentence*10|round)"')"
eq "readability: command description (code span = one word, e.g. not a full stop)" "1 1 7" \
  "$(r '.pools["command descriptions"] | "\(.passages) \(.sentences) \(.words)"')"
eq "readability: CLAUDE.md prose skips headings, tables and fences" "3 4 16 40" \
  "$(r '.pools["CLAUDE.md prose"] | "\(.passages) \(.sentences) \(.words) \(.words_per_sentence*10|round)"')"
eq "readability: worst passage" "plugins/p/README.md:4 310" "$(r '.worst[] | "\(.path):\(.line) \(.words_per_sentence*10|round)"')"
run "$WORK/rd.txt" "readability (text)" bash "$R/bin/readability.sh" --top 1
grep -qF 'plugins/p/README.md:4 — 31.0 words/sentence' "$WORK/rd.txt" && ok "readability: text report prints path:line — words/sentence" \
  || bad "readability: text report prints path:line — words/sentence" "$(cat "$WORK/rd.txt")"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
