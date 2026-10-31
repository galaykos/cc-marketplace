#!/usr/bin/env bash
# Fixture tests for scripts/skill-vet.sh: a stub `skillspector` on a sandboxed PATH, a local git repo as the skill source.
# Misses: the real SkillSpector (its JSON shape is taken from its README, 2026-10-29) and a clone over the network.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VET="$ROOT/scripts/skill-vet.sh"
[ -f "$VET" ] || { echo "FAIL: skill-vet.sh not found at $VET"; exit 2; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { pass=$((pass + 1)); }
no() { printf 'FAIL  %s\n      %s\n' "$1" "$2"; fail=$((fail + 1)); }
has() { if grep -qF -- "$3" <<<"$2"; then ok; else no "$1" "missing: $3 — got: $2"; fi; }
hasnt() { if grep -qF -- "$3" <<<"$2"; then no "$1" "unexpected: $3"; else ok; fi; }
rc_is() { if [ "$2" -eq "$3" ]; then ok; else no "$1" "exit $2, want $3"; fi; }

BASE="$T/base"; mkdir -p "$BASE"
for c in bash jq mktemp rm head cat timeout dirname awk sort cut find; do
  p="$(command -v "$c")" || { echo "FAIL: $c is not on PATH"; exit 2; }
  ln -s "$p" "$BASE/$c"
done
REALGIT="$(command -v git)" || { echo "FAIL: git is not on PATH"; exit 2; }
cat > "$BASE/git" <<SH
#!$(command -v bash)
printf '%s\n' "\$*" >> "$T/git.log"
exec "$REALGIT" "\$@"
SH
chmod +x "$BASE/git"

SPEC="$T/spec"; mkdir -p "$SPEC"
cat > "$SPEC/skillspector" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$SS_LOG"
[ -f "$2/SKILL.md" ] && printf 'has-skill-md\n' >> "$SS_LOG"
[ -n "${SS_REPORT:-}" ] && cat "$SS_REPORT"
[ -n "${SS_ERR:-}" ] && printf '%s\n' "$SS_ERR" >&2
exit "${SS_RC:-0}"
SH
chmod +x "$SPEC/skillspector"
export SS_LOG="$T/ss.log"

REPO="$T/repo"
mkdir -p "$REPO/skills/demo" "$REPO/demo2" "$REPO/x/demo" "$REPO/plugins/p/skills/nested" \
  "$REPO/.ai/x/skill/hidden" "$REPO/real-folder" "$REPO/decoy" "$REPO/sym"
printf -- '---\nname: demo\n---\nbody\n' > "$REPO/skills/demo/SKILL.md"
printf -- '---\nname: demo2\n---\nbody\n' > "$REPO/demo2/SKILL.md"
printf -- '---\nname: demo\n---\nshorter non-preview path\n' > "$REPO/x/demo/SKILL.md"
printf -- '---\nname: Nested Thing\n---\nbody\n' > "$REPO/plugins/p/skills/nested/SKILL.md"
printf -- '---\nname: hidden-display\n---\nbody\n' > "$REPO/.ai/x/skill/hidden/SKILL.md"
printf -- '---\nname: "renamed"\r\ndescription: x\r\n---\r\nbody\r\n' > "$REPO/real-folder/SKILL.md"
printf -- '---\nname: decoy\n---\nname: body-only\n' > "$REPO/decoy/SKILL.md"
ln -s ../real-folder "$REPO/skills/linked"
ln -s ../real-folder/SKILL.md "$REPO/sym/SKILL.md"
"$REALGIT" -C "$REPO" init -q && "$REALGIT" -C "$REPO" add -A \
  && "$REALGIT" -C "$REPO" -c user.name=t -c user.email=t@t commit -qm fixture \
  || { echo "FAIL: could not build the fixture repo"; exit 2; }

cat > "$T/bad.json" <<'EOF'
{ "risk_assessment": { "score": 78, "severity": "HIGH", "recommendation": "DO_NOT_INSTALL" },
  "issues": [
    { "id": "E1", "category": "data_exfiltration", "severity": "MEDIUM", "location": { "file": "scripts/sync.py", "start_line": 45 } },
    { "id": "AST1", "category": "behavioral_ast", "severity": "CRITICAL", "location": { "file": "scripts/run.py", "start_line": 3 } },
    { "id": "E2", "category": "data_exfiltration", "severity": "HIGH", "location": { "file": "scripts/sync.py", "start_line": 23 } },
    { "id": "SC1", "category": "supply_chain", "severity": "LOW", "location": { "file": "requirements.txt", "start_line": 1 } },
    { "id": "P4", "category": "prompt_injection", "severity": "MEDIUM", "location": { "file": "SKILL.md", "start_line": 9 } },
    { "id": "EA3", "category": "excessive_agency", "severity": "MEDIUM", "location": { "file": "SKILL.md", "start_line": 12 } } ] }
EOF
printf '{ "risk_assessment": { "score": 0, "severity": "LOW", "recommendation": "SAFE" }, "issues": [] }\n' > "$T/safe.json"

run() { # run <PATH> <args...> — sets OUT and RC; clears both logs first
  local path="$1"; shift
  : > "$T/git.log"; : > "$SS_LOG"
  OUT="$(PATH="$path" bash "$VET" "$@" 2>&1)"; RC=$?
}

# Absent: one offer line, exit 0, and nothing is cloned.
run "$BASE" "$REPO" demo
rc_is "absent: exit 0" "$RC" 0
has "absent: offers the install line" "$OUT" "uv tool install git+https://github.com/NVIDIA/skillspector.git"
has "absent: names the licence" "$OUT" "Apache-2.0"
if [ "$(printf '%s\n' "$OUT" | wc -l)" -eq 1 ]; then ok; else no "absent: one line" "got: $OUT"; fi
if [ ! -s "$T/git.log" ]; then ok; else no "absent: no clone" "git ran: $(cat "$T/git.log")"; fi

# Present, a completed scan over 50 (exit 1): the verdict and findings print, worst first, and the run still exits 0.
SS_REPORT="$T/bad.json" SS_RC=1 run "$SPEC:$BASE" "$REPO" demo
rc_is "verdict: exit 0 though the scan exited 1" "$RC" 0
has "verdict: first line" "$OUT" "SkillSpector verdict for demo (skills/demo/): DO_NOT_INSTALL, score 78/100 (HIGH), 6 finding(s), static scan (--no-llm)."
has "verdict: critical first" "$(printf '%s\n' "$OUT" | sed -n 2p)" "CRITICAL AST1 behavioral_ast scripts/run.py:3"
has "verdict: then high" "$(printf '%s\n' "$OUT" | sed -n 3p)" "HIGH E2 data_exfiltration scripts/sync.py:23"
hasnt "verdict: low is past the five shown" "$OUT" "SC1"
has "verdict: the rest are counted" "$OUT" "... and 1 more"
has "verdict: static json scan of the skill folder" "$(head -1 "$SS_LOG")" "/repo/skills/demo --no-llm --format json"
has "verdict: the folder holds the cloned SKILL.md" "$(cat "$SS_LOG")" "has-skill-md"
has "verdict: shallow clone, symlinks as plain files" "$(cat "$T/git.log")" "clone -c core.symlinks=false --depth 1 --quiet -- $REPO"
hasnt "verdict: skills/demo wins over a shorter x/demo" "$(head -1 "$SS_LOG")" "/repo/x/demo"

# Present, the root-level layout and a clean scan.
SS_REPORT="$T/safe.json" SS_RC=0 run "$SPEC:$BASE" "$REPO" demo2
rc_is "safe: exit 0" "$RC" 0
has "safe: verdict" "$OUT" "SkillSpector verdict for demo2 (demo2/): SAFE, score 0/100 (LOW), 0 finding(s)"

# Layouts past the two fixed paths: a folder at any depth, a hidden one, then a frontmatter name.
for c in "nested plugins/p/skills/nested/" "hidden .ai/x/skill/hidden/" "renamed real-folder/"; do
  set -- $c
  SS_REPORT="$T/safe.json" run "$SPEC:$BASE" "$REPO" "$1"
  has "layout $1: found and scanned" "$OUT" "SkillSpector verdict for $1 ($2): SAFE"
done
run "$SPEC:$BASE" "$REPO" body-only
has "layout control: a name in the body is not the frontmatter name" "$OUT" "has no body-only/SKILL.md and no SKILL.md named body-only"

# A symlinked skill folder or SKILL.md is reported, never scanned.
run "$SPEC:$BASE" "$REPO" linked
has "symlink folder: not scanned" "$OUT" "SkillSpector did not scan linked: skills/linked is a symlink"
run "$SPEC:$BASE" "$REPO" sym
has "symlink SKILL.md: not scanned" "$OUT" "SkillSpector did not scan sym: sym/SKILL.md is a symlink"
if [ ! -s "$SS_LOG" ]; then ok; else no "symlink: scanner not called" "$(cat "$SS_LOG")"; fi

# Present, but the scan errors (exit 2, no report): one did-not-scan line, exit 0.
SS_ERR="boom: unreadable source" SS_RC=2 run "$SPEC:$BASE" "$REPO" demo
rc_is "scan error: exit 0" "$RC" 0
has "scan error: says so" "$OUT" "SkillSpector did not scan demo: skillspector exited 2 without a readable report (boom: unreadable source)"
has "scan error: install still the person's call" "$OUT" "The install still waits on your yes."

# Present, the skill is not in the repo: the scanner is never called.
run "$SPEC:$BASE" "$REPO" nope
rc_is "missing skill: exit 0" "$RC" 0
has "missing skill: says so" "$OUT" "has no nope/SKILL.md and no SKILL.md named nope"
if [ ! -s "$SS_LOG" ]; then ok; else no "missing skill: scanner not called" "$(cat "$SS_LOG")"; fi

# Present, the clone fails: an existing directory that is not a repository.
mkdir -p "$T/not-a-repo"
run "$SPEC:$BASE" "$T/not-a-repo" demo
rc_is "clone fails: exit 0" "$RC" 0
has "clone fails: says so" "$OUT" "SkillSpector did not scan demo: git clone of $T/not-a-repo failed"

# SOURCE other than owner/repo or an existing absolute directory: not scanned, nothing cloned.
for s in "https://example.com/x.git" "./relative" "$T/no-such-repo"; do
  run "$SPEC:$BASE" "$s" demo
  rc_is "source $s: exit 0" "$RC" 0
  has "source $s: not scanned" "$OUT" "SkillSpector did not scan demo: $s is neither owner/repo nor an existing absolute directory"
  if [ ! -s "$T/git.log" ]; then ok; else no "source $s: nothing cloned" "$(cat "$T/git.log")"; fi
done

# owner/repo resolves to GitHub; a git that fails stands in for the network.
NONET="$T/nonet"; mkdir -p "$NONET"
printf '#!%s\nprintf "%%s\\n" "$*" >> "%s"\nexit 128\n' "$(command -v bash)" "$T/git.log" > "$NONET/git"
chmod +x "$NONET/git"
run "$NONET:$SPEC:$BASE" acme/skills demo
rc_is "owner/repo: exit 0" "$RC" 0
has "owner/repo: GitHub URL" "$(cat "$T/git.log")" "-- https://github.com/acme/skills.git"

# Usage errors exit 1 and never reach the scanner.
run "$SPEC:$BASE"
rc_is "usage: no arguments" "$RC" 1
run "$SPEC:$BASE" "$REPO" ../demo
rc_is "usage: a skill id with a path in it" "$RC" 1

echo "skill-vet tests: $pass passed, $fail failed"
exit $((fail > 0))
