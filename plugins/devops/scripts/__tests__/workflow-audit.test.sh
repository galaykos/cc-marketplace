#!/usr/bin/env bash
# Fixtures for the CI trust-boundary pair: plugins/devops/scripts/workflow-audit.sh
# (report, exit 2 on critical) and plugins/devops/hooks/workflow-guard.sh
# (PreToolUse deny, two classes only). Run by CI via the
# plugins/*/scripts/__tests__/*.test.sh glob.
#
# Both directions matter. A gate that flags every interpolation is worse than no
# gate: it gets switched off, and the two shapes with no legitimate form stop
# being blocked with it. The false-positive fixtures below are therefore not
# padding — one of them (`base.sha`) is a real defect this audit found in its own
# repository's workflow on the first run.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
AUDIT=plugins/devops/scripts/workflow-audit.sh
HOOK=plugins/devops/hooks/workflow-guard.sh
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/wf"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

# --- audit: want = exit code ------------------------------------------------
audit_case() { # label want_rc yaml
  local label="$1" want="$2" yaml="$3" got
  rm -f "$FX/wf"/*.yml
  printf '%s\n' "$yaml" > "$FX/wf/w.yml"
  bash "$AUDIT" --dir "$FX/wf" --quiet; got=$?
  if [ "$got" = "$want" ]; then echo "PASS[audit]: $label (rc=$got)"
  else echo "FAIL[audit]: $label — want rc=$want, got $got"; rc=1; fi
}

audit_case "pull_request_target + untrusted checkout" 2 'on:
  pull_request_target:
permissions:
  contents: read
jobs:
  b:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}'

audit_case "PR title into a run: block" 2 'on:
  pull_request:
permissions:
  contents: read
jobs:
  b:
    runs-on: ubuntu-latest
    steps:
      - run: echo "PR ${{ github.event.pull_request.title }}"'

# The false positive that shipped in the first draft: base.sha is a 40-char SHA
# GitHub generates. No PR author can influence it, so it must NOT be critical.
audit_case "base.sha into a run: block is SAFE" 0 'on:
  pull_request:
permissions:
  contents: read
jobs:
  b:
    runs-on: ubuntu-latest
    steps:
      - run: bash check.sh "${{ github.event.pull_request.base.sha }}"'

audit_case "clean workflow" 0 'on:
  push:
permissions:
  contents: read
jobs:
  b:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make test'

audit_case "missing permissions: is warn, not critical" 0 'on:
  push:
jobs:
  b:
    runs-on: ubuntu-latest
    steps:
      - run: make test'

rm -rf "$FX/wf"; bash "$AUDIT" --dir "$FX/nope" --quiet; [ $? -eq 3 ] \
  && echo "PASS[audit]: absent directory exits 3" \
  || { echo "FAIL[audit]: absent directory did not exit 3"; rc=1; }
mkdir -p "$FX/wf"

# --- hook: want = deny | allow ---------------------------------------------
hook_case() { # label want file yaml
  local label="$1" want="$2" file="$3" yaml="$4" out got
  out=$(jq -nc --arg f "$file" --arg c "$yaml" \
        '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}' | bash "$HOOK" 2>/dev/null)
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then got=deny; else got=allow; fi
  if [ "$got" = "$want" ]; then echo "PASS[hook]: $label ($got)"
  else echo "FAIL[hook]: $label — want $want, got $got"; rc=1; fi
}

hook_case "untrusted checkout under pull_request_target" deny \
  ".github/workflows/ci.yml" 'on:
  pull_request_target:
jobs:
  b:
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.ref }}'

hook_case "PR body into a run: block" deny \
  ".github/workflows/ci.yml" 'jobs:
  b:
    steps:
      - run: echo "${{ github.event.pull_request.body }}"'

hook_case "head_ref into a run: block" deny \
  ".github/workflows/ci.yml" 'jobs:
  b:
    steps:
      - run: git checkout ${{ github.head_ref }}'

hook_case "base.sha is allowed" allow \
  ".github/workflows/ci.yml" 'jobs:
  b:
    steps:
      - run: bash check.sh "${{ github.event.pull_request.base.sha }}"'

hook_case "title in an env: block is the correct fix" allow \
  ".github/workflows/ci.yml" 'jobs:
  b:
    steps:
      - env:
          TITLE: ${{ github.event.pull_request.title }}
        run: echo "$TITLE"'

hook_case "unpinned action is warn-only, never denied" allow \
  ".github/workflows/ci.yml" 'jobs:
  b:
    steps:
      - uses: some-org/some-action@v3'

hook_case "a non-workflow file is out of scope" allow \
  "src/app.ts" 'const x = "${{ github.event.pull_request.title }}"'

if printf 'not json' | bash "$HOOK" >/dev/null 2>&1; then
  echo "PASS[hook]: garbage input exits 0 (fail-open)"
else
  echo "FAIL[hook]: garbage input did not exit 0"; rc=1
fi

[ "$rc" -eq 0 ] && echo "All devops workflow-audit fixtures passed."
exit "$rc"
