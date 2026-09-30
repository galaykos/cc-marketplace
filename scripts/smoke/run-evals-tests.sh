#!/usr/bin/env bash
# Fixtures for scripts/run-evals.sh — the plumbing of a paid eval run, proved without paying.
#
# Every arm but (d) drives a stub `claude` placed first on PATH that records its argv and,
# when asked, writes a canned schemaVersion-1 document to its `--json` path. The canned
# document carries the fields a summary must NOT copy (home paths, a trace id, prompt,
# grader and error text), so an over-eager summariser fails here on the exit code. A stub
# arm that reached the real CLI would spend at a 5 USD cap, so the harness exits before the
# first arm unless a fresh bash resolves `claude` to the stub (a noexec TMPDIR fails this),
# and every stub arm runs with no API key or OAuth token and a throwaway HOME — measured
# 2026-09-30 on macOS, CLI 2.1.285: `claude auth status` reports `loggedIn: false` there.
# Arms needing a suite of known shape run a copy of the script in a scratch repo whose
# plugins/ holds only fixture case.yaml files.
#
# Arm (d) drives the REAL CLI, and only when one is on PATH: `--max-cost-usd 0` under a
# throwaway HOME with no API key or OAuth token, the zero-cost load scripts/eval-cases.sh already runs on every validate
# pass — measured 2026-09-30 on CLI 2.1.285: exit 2, `partialReason: "cost_ceiling"`,
# `costUsd: 0`, no run launched. It loads resilience, not candor: candor's scaffolded cases
# are refused before any call. It spends nothing, so it needs no opt-in; with no `claude`
# it prints a SKIP, never a PASS.
#
# WHAT IT DOES NOT PROVE: any score, that a real paid run's document still has the shape
# the canned one assumes (only the empty-cases shape is checked against the real CLI), that
# the CLI still filters `--case`/`--tag` the way the filter arms assume (measured by hand on
# 2.1.285; the stub filters nothing, so those arms check the script's copy of the rules), that
# the CLI keeps treating a 0 ceiling as "launch nothing" — arm (d) trusts that — or that an
# interrupt between write and rename leaves no truncated summary (no arm can time one).
set -u
cd "$(dirname "$0")/../.." || exit 1
rc=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
real_path=$PATH
real_claude=$(command -v claude 2>/dev/null)

ok()  { printf 'PASS: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n      %s\n' "$1" "$2"; rc=1; }

mkdir -p "$T/bin"
cat > "$T/bin/claude" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STUB_ARGV"
json=
while [ $# -gt 0 ]; do
  if [ "$1" = --json ]; then json=$2; break; fi
  shift
done
if [ -n "${STUB_DOC:-}" ] && [ -n "$json" ]; then cp "$STUB_DOC" "$json"; fi
exit "${STUB_RC:-0}"
STUB
chmod +x "$T/bin/claude"
mkdir -p "$T/home-stub"

stub() { # stub <VAR=value…> <command…> — the stub first on PATH, no credential, no opt-in unless given
  env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u CLAUDE_CODE_OAUTH_TOKEN -u RUN_EVALS \
    -u RUN_EVALS_MAX_COST_USD HOME="$T/home-stub" PATH="$T/bin:$real_path" "$@"
}

seen=$(stub bash -c 'printf "%s|%s|%s" "$(command -v claude)" "$HOME" "${ANTHROPIC_API_KEY+key}${ANTHROPIC_AUTH_TOKEN+auth}${CLAUDE_CODE_OAUTH_TOKEN+oauth}"')
if [ "$seen" != "$T/bin/claude|$T/home-stub|" ]; then
  bad "stub arms run the stub claude, credential-free, under a throwaway HOME" "claude|HOME|credentials = '$seen' — a stub arm could reach the real CLI; stopping"
  exit 1
fi

R="$T/repo"
mkdir -p "$R/scripts"
cp scripts/run-evals.sh "$R/scripts/"
fixture_case() { # fixture_case <plugin> <case> [runs] [extra yaml]
  mkdir -p "$R/plugins/$1/evals/$2"
  {
    echo "name: $2"
    [ -n "${3:-}" ] && echo "runs: $3"
    [ -n "${4:-}" ] && printf '%s\n' "$4"
  } > "$R/plugins/$1/evals/$2/case.yaml"
}
fixture_case duo alpha 2
fixture_case duo beta
fixture_case five alpha 2
fixture_case five beta
fixture_case five gamma 4
fixture_case five delta
fixture_case five epsilon 5
fixture_case scaf plain
fixture_case scaf built 3 $'context:\n  scaffold_script: scaffold.sh'
fixture_case scaf quoted 3 $'context:\n  "scaffold_script": scaffold.sh'
mkdir -p "$R/plugins/scaf/evals/broken"; echo '- not a mapping' > "$R/plugins/scaf/evals/broken/case.yaml"
fixture_case bad plain
mkdir -p "$R/plugins/bad/evals/broken"; echo '- not a mapping' > "$R/plugins/bad/evals/broken/case.yaml"
fixture_case filt alpha '' 'tags: [fast]'
fixture_case filt beta '' 'tags: [slow]'
fixture_case filt delta '' 'tags: [slow, x]'
fixture_case filt gamma

cat > "$T/doc.json" <<'JSON'
{
  "schemaVersion": 1,
  "claudeVersion": "2.1.285",
  "startedAt": "2026-09-30T00:00:00.000Z",
  "durationSeconds": 60,
  "costUsd": 1.25,
  "partial": false,
  "suite": {"root": "/Users/example/cc-marketplace/plugins/candor", "ablation": "with-without",
            "plugins": [{"name": "candor", "version": "0.0.0", "path": "/home/runner/work/plugins/candor"}]},
  "cases": [
    {"name": "alpha", "dir": "/Users/example/cc-marketplace/plugins/candor/evals/alpha",
     "promptMarkdown": "Please fix the login bug.", "runsPerCase": 3,
     "arms": {
       "with": [
         {"score": 1, "passed": true, "error": null,
          "tracePath": "/Users/example/.claude/projects/x/0f8fad5b-d9cb-469f-a165-70867728950e.jsonl",
          "graders": [{"name": "g", "passed": true, "explanation": "The reply names the file."}]},
         {"score": 0.5, "passed": false, "error": null},
         {"score": 1, "passed": true, "error": null}
       ],
       "without": [
         {"score": 0, "passed": false, "error": "timed out after 300s"},
         {"score": 0, "passed": false, "error": null},
         {"score": 1, "passed": true, "error": null}
       ]
     },
     "aggregates": {"score": 0.8333, "scoreWithout": 0.3333, "delta": 0.5}},
    {"name": "beta", "runsPerCase": 3,
     "arms": {
       "with": [{"score": 1}, {"score": 1}, {"score": 1}],
       "without": [{"score": 1}, {"score": 0.5}, {"score": 1}]
     },
     "aggregates": {"score": 1, "scoreWithout": 0.8333, "delta": 0.1667}}
  ],
  "aggregates": {"casesTotal": 2, "casesPassed": 1, "overallScore": 0.9167, "meanDelta": 0.3333}
}
JSON

argv_line() { paste -s -d ' ' "$1"; }
has() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }
only_summary() { # only_summary <dir> <plugin> — prints the one summary path, or nothing
  local f n
  n=$(find "$1" -type f 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = 1 ] || return 0
  f=$(find "$1" -type f)
  case "$(basename "$f")" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]-"$2".json) printf '%s' "$f" ;;
  esac
}
check() { # check <summary> <python assertions over `s` (dict) and `t` (text)> — prints the failure
  python3 - "$1" "$2" <<'PY' 2>&1
import json, re, sys
t = open(sys.argv[1]).read()
s = json.loads(t)
exec(sys.argv[2])
PY
}

# (a) no opt-in: refused before any claude call
err=$(stub RUN_EVALS_OUT_DIR="$T/out-a" STUB_ARGV="$T/argv-a" bash scripts/run-evals.sh candor 2>&1 >/dev/null); st=$?
if [ "$st" -eq 3 ] && [ ! -e "$T/argv-a" ] && case "$err" in *"RUN_EVALS=1"*) true ;; *) false ;; esac; then
  ok "refuses without RUN_EVALS=1"
else
  bad "refuses without RUN_EVALS=1" "exit=$st stub-called=$([ -e "$T/argv-a" ] && echo yes || echo no) stderr=$err"
fi

# missing or unknown plugin: usage refusal, still before any claude call
stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-u" STUB_ARGV="$T/argv-u" bash scripts/run-evals.sh >/dev/null 2>&1; st1=$?
stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-u" STUB_ARGV="$T/argv-u" bash scripts/run-evals.sh no-such-plugin >/dev/null 2>&1; st2=$?
if [ "$st1" -eq 64 ] && [ "$st2" -eq 64 ] && [ ! -e "$T/argv-u" ]; then
  ok "a missing or unknown plugin exits 64 before calling claude"
else
  bad "a missing or unknown plugin exits 64 before calling claude" "exits=$st1,$st2 stub-called=$([ -e "$T/argv-u" ] && echo yes || echo no)"
fi

# --scaffold / --allow-real-servers are never passed, not even as extra arguments
stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-s" STUB_ARGV="$T/argv-s" STUB_DOC="$T/doc.json" \
  bash "$R/scripts/run-evals.sh" duo --scaffold >/dev/null 2>&1; st1=$?
stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-s" STUB_ARGV="$T/argv-s" STUB_DOC="$T/doc.json" \
  bash "$R/scripts/run-evals.sh" duo --allow-real-servers >/dev/null 2>&1; st2=$?
stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-s" STUB_ARGV="$T/argv-s" STUB_DOC="$T/doc.json" \
  bash "$R/scripts/run-evals.sh" duo --mocks off >/dev/null 2>&1; st3=$?
if [ "$st1" -eq 64 ] && [ "$st2" -eq 64 ] && [ "$st3" -eq 64 ] && [ ! -e "$T/argv-s" ]; then
  ok "an extra --scaffold or --allow-real-servers exits 64 before calling claude"
else
  bad "an extra --scaffold or --allow-real-servers exits 64 before calling claude" "exits=$st1,$st2,$st3 stub-called=$([ -e "$T/argv-s" ] && echo yes || echo no)"
fi

# an extra argument that would override a fixed flag, in either form, is refused before any call
over_bad=
for spec in "--max-cost-usd 500" --max-cost-usd=500 "--ablation none" --ablation=none "--json x.json" --json=x.json \
            "--output-dir o" --output-dir=o "--report r.html" --report=r.html "--eval-dir e" --eval-dir=e --publish-report; do
  rm -rf "$T/out-o" "$T/argv-o"
  # shellcheck disable=SC2086 # splitting "--flag v" into two arguments is the point
  stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-o" STUB_ARGV="$T/argv-o" STUB_DOC="$T/doc.json" \
    bash "$R/scripts/run-evals.sh" duo $spec >/dev/null 2>&1; st=$?
  { [ "$st" -eq 64 ] && [ ! -e "$T/argv-o" ]; } \
    || over_bad="$over_bad [$spec: exit=$st stub-called=$([ -e "$T/argv-o" ] && echo yes || echo no)]"
done
if [ -z "$over_bad" ]; then
  ok "an extra argument overriding a fixed flag exits 64 before calling claude"
else
  bad "an extra argument overriding a fixed flag exits 64 before calling claude" "$over_bad"
fi

# a suite with a case declaring scaffold_script is refused before any call, naming the case
err=$(stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-f" STUB_ARGV="$T/argv-f" STUB_DOC="$T/doc.json" \
      bash "$R/scripts/run-evals.sh" scaf 2>&1 >/dev/null); st=$?
if [ "$st" -eq 64 ] && [ ! -e "$T/argv-f" ] && has "$err" "  built" && has "$err" "  quoted" \
   && has "$err" "  broken" && ! has "$err" "plain" && has "$err" "plugins/scaf/README.md"; then
  ok "a suite with a scaffold_script case exits 64 before calling claude"
else
  bad "a suite with a scaffold_script case exits 64 before calling claude" "exit=$st stub-called=$([ -e "$T/argv-f" ] && echo yes || echo no) stderr=$err"
fi
err=$(stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-r" STUB_ARGV="$T/argv-r" STUB_DOC="$T/doc.json" \
      bash "$R/scripts/run-evals.sh" bad 2>&1 >/dev/null); st=$?
if [ "$st" -eq 64 ] && [ ! -e "$T/argv-r" ] && has "$err" "  broken" && ! has "$err" "plain"; then
  ok "a suite with a case.yaml yaml cannot read exits 64 before calling claude"
else
  bad "a suite with a case.yaml yaml cannot read exits 64 before calling claude" "exit=$st stub-called=$([ -e "$T/argv-r" ] && echo yes || echo no) stderr=$err"
fi

# the pass-through is an allow-list: anything else, or a stray or missing value, is refused
allow_bad=
for spec in "-j 2" "--concurrency 2" --verbose --no-scaffold --keep-temp -- "--case" "--runs 4 5" "--tag=x y" \
            "--case --json" "--threshold" "stray"; do
  rm -rf "$T/out-l" "$T/argv-l"
  # shellcheck disable=SC2086 # splitting the spec into arguments is the point
  stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-l" STUB_ARGV="$T/argv-l" STUB_DOC="$T/doc.json" \
    bash "$R/scripts/run-evals.sh" duo $spec >/dev/null 2>&1; st=$?
  { [ "$st" -eq 64 ] && [ ! -e "$T/argv-l" ]; } \
    || allow_bad="$allow_bad [$spec: exit=$st stub-called=$([ -e "$T/argv-l" ] && echo yes || echo no)]"
done
allowed=(--tag a b --allow-tools Bash 'Bash(git:*)' --model m --judge-model j --threshold 0.5 --runs=2
         --case='al*' --tag=c --allow-tools=Write --model=m2 --judge-model=j2 --threshold=1 --runs 3 --case beta)
stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-l" STUB_ARGV="$T/argv-l" STUB_DOC="$T/doc.json" \
  bash "$R/scripts/run-evals.sh" duo "${allowed[@]}" >/dev/null 2>&1; st=$?
[ "$st" -eq 0 ] && [ "$(tail -n "${#allowed[@]}" "$T/argv-l" 2>/dev/null)" = "$(printf '%s\n' "${allowed[@]}")" ] \
  || allow_bad="$allow_bad [every allowed form: exit=$st argv=$(argv_line "$T/argv-l" 2>/dev/null)]"
if [ -z "$allow_bad" ]; then
  ok "extra arguments pass only through the allow-list"
else
  bad "extra arguments pass only through the allow-list" "$allow_bad"
fi

# python3 without yaml: refused before the paid call, not after it
mkdir -p "$T/noyaml"; echo 'raise ImportError("hidden by run-evals-tests")' > "$T/noyaml/yaml.py"
err=$(stub RUN_EVALS=1 PYTHONPATH="$T/noyaml" RUN_EVALS_OUT_DIR="$T/out-y" STUB_ARGV="$T/argv-y" STUB_DOC="$T/doc.json" \
      bash "$R/scripts/run-evals.sh" duo 2>&1 >/dev/null); st=$?
if [ "$st" -eq 64 ] && [ ! -e "$T/argv-y" ] && has "$err" "yaml"; then
  ok "python3 without yaml exits 64 before calling claude"
else
  bad "python3 without yaml exits 64 before calling claude" "exit=$st stub-called=$([ -e "$T/argv-y" ] && echo yes || echo no) stderr=$err"
fi

# (b) opt-in, default cap, stub exits 1 after writing the canned document
out=$(stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-b" STUB_ARGV="$T/argv-b" STUB_DOC="$T/doc.json" STUB_RC=1 \
      bash "$R/scripts/run-evals.sh" duo 2>&1); st=$?
args=" $(argv_line "$T/argv-b" 2>/dev/null) "
if [ "$st" -eq 1 ] && [ "${args#" plugin eval ./plugins/duo "}" != "$args" ] && has "$args" " --ablation with-without " \
   && has "$args" " --max-cost-usd 5 " && ! grep -qx -e --scaffold -e --allow-real-servers "$T/argv-b"; then
  ok "default cap is 5 and ablation is with-without"
else
  bad "default cap is 5 and ablation is with-without" "exit=$st (want 1) argv=$args output=$out"
fi

sb=$(only_summary "$T/out-b" duo)
if [ -z "$sb" ]; then
  bad "summary records vote spread per arm" "want one <date>-<time>-duo.json in RUN_EVALS_OUT_DIR, got: $(ls "$T/out-b" 2>&1) output=$out"
else
  msg=$(check "$sb" '
by = {c["name"]: c for c in s["cases"]}
assert sorted(by) == ["alpha", "beta"], sorted(by)
assert by["alpha"]["spread"] == {"with": "2/3", "without": "1/3"}, by["alpha"]["spread"]
assert by["beta"]["spread"] == {"with": "3/3", "without": "2/3"}, by["beta"]["spread"]
assert by["alpha"]["scores"] == {"with": [1, 0.5, 1], "without": [0, 0, 1]}, by["alpha"]["scores"]
for c in s["cases"]:
    assert c["completed"] == {"with": 3, "without": 3}, c["completed"]
    assert c["planned"] == {"with": 3, "without": 3}, c["planned"]
assert by["alpha"]["delta"] == 0.5 and by["beta"]["delta"] == 0.1667
assert s["plannedRuns"] == 12 and s["completedRuns"] == 12, (s["plannedRuns"], s["completedRuns"])
assert s["exitCode"] == 1 and s["partial"] is False and s["partialReason"] is None
assert s["arms"] == ["with", "without"] and s["maxCostUsd"] == 5 and s["costUsd"] == 1.25
assert s["runsPerCaseOverride"] is None and s["schema"] == 1 and s["plugin"] == "duo"
')
  [ -z "$msg" ] && ok "summary records vote spread per arm" || bad "summary records vote spread per arm" "$msg"

  msg=$(check "$sb" '
top = {"schema", "plugin", "startedAt", "claudeVersion", "maxCostUsd", "costUsd", "exitCode", "partial",
       "partialReason", "arms", "runsPerCaseOverride", "plannedRuns", "completedRuns", "cases"}
assert set(s) == top, set(s) ^ top
for c in s["cases"]:
    assert set(c) == {"name", "planned", "completed", "scores", "spread", "delta"}, set(c)
assert re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", s["startedAt"]), s["startedAt"]
for bad in ("/Users/", "/home/", "timed out", "login bug", "names the file", "0f8fad5b"):
    assert bad not in t, bad
')
  [ -z "$msg" ] && ok "summary copies no path, prompt, grader or error text" || bad "summary copies no path, prompt, grader or error text" "$msg"
fi

# (c) the cap is overridable; extra arguments follow the fixed ones verbatim
stub RUN_EVALS=1 RUN_EVALS_MAX_COST_USD=0.5 RUN_EVALS_OUT_DIR="$T/out-c" STUB_ARGV="$T/argv-c" \
  STUB_DOC="$T/doc.json" STUB_RC=0 bash "$R/scripts/run-evals.sh" duo --runs 4 --case 'al*' >/dev/null 2>&1; st=$?
args=" $(argv_line "$T/argv-c" 2>/dev/null) "
sc=$(only_summary "$T/out-c" duo)
case "$args" in
  *" --max-cost-usd 0.5 "*)
    msg=$([ -n "$sc" ] && check "$sc" 'assert s["maxCostUsd"] == 0.5, s["maxCostUsd"]' || echo "no summary written")
    [ "$st" -eq 0 ] && [ -z "$msg" ] && ok "cap is overridable" || bad "cap is overridable" "exit=$st $msg" ;;
  *) bad "cap is overridable" "argv=$args" ;;
esac
case "$args" in
  *" --json "*"/aggregate.json --runs 4 --case al* ")
    msg=$([ -n "$sc" ] && check "$sc" '
assert s["runsPerCaseOverride"] == 4, s["runsPerCaseOverride"]
assert all(c["planned"] == {"with": 4, "without": 4} for c in s["cases"]), [c["planned"] for c in s["cases"]]
' || echo "no summary written")
    [ -z "$msg" ] && ok "extra arguments pass through verbatim after the fixed ones" \
      || bad "extra arguments pass through verbatim after the fixed ones" "$msg" ;;
  *) bad "extra arguments pass through verbatim after the fixed ones" "argv=$args" ;;
esac

# a document whose case name is session-id shaped: the summary is refused, not written
python3 - "$T/doc.json" "$T/doc-leak.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["cases"][1]["name"] = "0f8fad5b-d9cb-469f-a165-70867728950e"
json.dump(d, open(sys.argv[2], "w"))
PY
err=$(stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-e" STUB_ARGV="$T/argv-e" STUB_DOC="$T/doc-leak.json" STUB_RC=0 \
      bash "$R/scripts/run-evals.sh" duo 2>&1 >/dev/null); st=$?
n=$(find "$T/out-e" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$st" -eq 65 ] && [ "$n" = 0 ]; then
  ok "a summary matching a session-id shape exits 65 and is not written"
else
  bad "a summary matching a session-id shape exits 65 and is not written" "exit=$st files=$n"
fi

# a summariser that fails after the paid run keeps the document and names it
kept_doc() { printf '%s' "$1" | sed -n 's/.* kept at \(.*aggregate\.json\).*/\1/p'; }
printf '{"schemaVersion": 1, "cases": [' > "$T/doc-trunc.json"
err2=$(stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-k" STUB_ARGV="$T/argv-k" STUB_DOC="$T/doc-trunc.json" STUB_RC=0 \
       bash "$R/scripts/run-evals.sh" duo 2>&1 >/dev/null); st=$?
k=$(kept_doc "$err2"); ke=$(kept_doc "$err")
n=$(find "$T/out-k" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$st" -ne 0 ] && [ "$n" = 0 ] && [ -n "$k" ] && cmp -s "$k" "$T/doc-trunc.json" \
   && [ -n "$ke" ] && cmp -s "$ke" "$T/doc-leak.json"; then
  ok "a failed summary keeps the paid run's document and names it"
else
  bad "a failed summary keeps the paid run's document and names it" "exit=$st files=$n kept=${k:-none} kept-on-65=${ke:-none} stderr=$err2"
fi
for f in "$k" "$ke"; do [ -f "$f" ] && rm -rf "${f%/aggregate.json}"; done

# a partial document listing two of five cases: the three it omits are still planned, 0 completed
python3 - "$T/doc.json" "$T/doc-partial.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d.update(partial=True, partialReason="cost_ceiling")
d["cases"][0]["arms"]["without"] = d["cases"][0]["arms"]["without"][:1]
d["cases"][1]["arms"] = {"with": [{"score": 1}], "without": []}
json.dump(d, open(sys.argv[2], "w"))
PY
stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-p" STUB_ARGV="$T/argv-p" STUB_DOC="$T/doc-partial.json" STUB_RC=2 \
  bash "$R/scripts/run-evals.sh" five >/dev/null 2>&1; st=$?
sp=$(only_summary "$T/out-p" five)
msg=$([ -n "$sp" ] && check "$sp" '
by = {c["name"]: c for c in s["cases"]}
assert sorted(by) == ["alpha", "beta", "delta", "epsilon", "gamma"], sorted(by)
planned = {n: by[n]["planned"]["with"] for n in by}
assert planned == {"alpha": 3, "beta": 3, "gamma": 4, "delta": 3, "epsilon": 5}, planned
assert all(c["planned"]["with"] == c["planned"]["without"] for c in s["cases"])
assert by["alpha"]["completed"] == {"with": 3, "without": 1}, by["alpha"]["completed"]
assert by["beta"]["completed"] == {"with": 1, "without": 0}, by["beta"]["completed"]
for n in ("gamma", "delta", "epsilon"):
    c = by[n]
    assert c["completed"] == {"with": 0, "without": 0} and c["spread"] == {"with": "0/0", "without": "0/0"}, c
    assert c["scores"] == {"with": [], "without": []} and c["delta"] is None, c
assert s["plannedRuns"] == 36 and s["completedRuns"] == 5, (s["plannedRuns"], s["completedRuns"])
assert s["partial"] is True and s["partialReason"] == "cost_ceiling" and s["exitCode"] == 2
' || echo "no summary written")
if [ "$st" -eq 2 ] && [ -z "$msg" ]; then
  ok "a partial document still plans every case file"
else
  bad "a partial document still plans every case file" "exit=$st (want 2) $msg"
fi

# a filtered run with a complete document records only the cases the document ran
python3 - "$T/doc.json" "$T/doc-one.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["cases"] = d["cases"][:1]
json.dump(d, open(sys.argv[2], "w"))
PY
stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-1" STUB_ARGV="$T/argv-1" STUB_DOC="$T/doc-one.json" STUB_RC=0 \
  bash "$R/scripts/run-evals.sh" five --case alpha >/dev/null 2>&1; st=$?
s1=$(only_summary "$T/out-1" five)
msg=$([ -n "$s1" ] && check "$s1" '
assert [c["name"] for c in s["cases"]] == ["alpha"], [c["name"] for c in s["cases"]]
assert s["cases"][0]["planned"] == s["cases"][0]["completed"] == {"with": 3, "without": 3}, s["cases"][0]
assert s["plannedRuns"] == 6 and s["completedRuns"] == 6, (s["plannedRuns"], s["completedRuns"])
assert s["partial"] is False and s["exitCode"] == 0
' || echo "no summary written")
if [ "$st" -eq 0 ] && [ -z "$msg" ]; then
  ok "a one-case filtered complete run records one case"
else
  bad "a one-case filtered complete run records one case" "exit=$st $msg"
fi
stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-2" STUB_ARGV="$T/argv-2" STUB_DOC="$T/doc.json" STUB_RC=1 \
  bash "$R/scripts/run-evals.sh" five >/dev/null 2>&1; st=$?
s2=$(only_summary "$T/out-2" five)
msg=$([ -n "$s2" ] && check "$s2" '
assert [c["name"] for c in s["cases"]] == ["alpha", "beta"], [c["name"] for c in s["cases"]]
assert s["plannedRuns"] == 12 and s["completedRuns"] == 12, (s["plannedRuns"], s["completedRuns"])
' || echo "no summary written")
if [ "$st" -eq 1 ] && [ -z "$msg" ]; then
  ok "a complete document gains no case file it omits"
else
  bad "a complete document gains no case file it omits" "exit=$st $msg"
fi

# a partial document adds only the case files --case/--tag select, as the CLI filters them
echo '{"schemaVersion": 1, "claudeVersion": "2.1.285", "costUsd": 0, "partial": true, "partialReason": "cost_ceiling", "cases": []}' \
  > "$T/doc-empty.json"
filt_bad=
filt() { # filt <expected names, space-separated> <extra args…>
  local want=$1 got; shift
  rm -rf "$T/out-t"
  stub RUN_EVALS=1 RUN_EVALS_OUT_DIR="$T/out-t" STUB_ARGV="$T/argv-t" STUB_DOC="$T/doc-empty.json" STUB_RC=2 \
    bash "$R/scripts/run-evals.sh" filt "$@" >/dev/null 2>&1
  got=$(python3 -c 'import json,sys; print(" ".join(c["name"] for c in json.load(open(sys.argv[1]))["cases"]))' \
        "$(only_summary "$T/out-t" filt)" 2>/dev/null) || got="<no summary>"
  [ "$got" = "$want" ] || filt_bad="$filt_bad [$*: want '$want' got '$got']"
}
filt "beta delta" --case zzz --case '?e*'
filt "alpha delta" --tag x fast
filt "delta" --case '*ta' --tag=fast --tag x
filt "" --case '[ab]*'
if [ -z "$filt_bad" ]; then
  ok "a partial document plans only the case files the filters select"
else
  bad "a partial document plans only the case files the filters select" "$filt_bad"
fi

# (d) the real CLI, at a zero ceiling, under a throwaway HOME, with no credential
if [ -n "$real_claude" ]; then
  mkdir -p "$T/home-d"
  env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u CLAUDE_CODE_OAUTH_TOKEN \
    RUN_EVALS=1 RUN_EVALS_MAX_COST_USD=0 RUN_EVALS_OUT_DIR="$T/out-d" HOME="$T/home-d" \
    DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 PATH="$real_path" \
    bash scripts/run-evals.sh resilience </dev/null >"$T/d.out" 2>&1; st=$?
  sd=$(only_summary "$T/out-d" resilience)
  if [ "$st" -ne 2 ] || [ -z "$sd" ]; then
    bad "real CLI free load writes a partial summary" "exit=$st (want 2) summary=${sd:-none} output=$(tail -3 "$T/d.out")"
  else
    msg=$(check "$sd" '
assert s["partial"] is True, s["partial"]
assert s["partialReason"] == "cost_ceiling", s["partialReason"]
assert s["costUsd"] == 0, s["costUsd"]
assert s["completedRuns"] == 0, s["completedRuns"]
assert s["plannedRuns"] > 0, s["plannedRuns"]
assert not re.search(r"/Users/|/home/|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", t)
')
    [ -z "$msg" ] && ok "real CLI free load writes a partial summary" || bad "real CLI free load writes a partial summary" "$msg"
  fi
else
  echo "SKIP: real CLI free load — claude not on PATH"
fi

exit "$rc"
