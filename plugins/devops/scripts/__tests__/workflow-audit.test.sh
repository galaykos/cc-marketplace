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

# 0.9.10: the PR's merge commit is PR code too, spelled as refs/pull/N/merge or merge_commit_sha.
PRT='on:
  pull_request_target:
permissions:
  contents: read
jobs:
  b:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:'
audit_case "pull_request_target + refs/pull/N/merge checkout" 2 "$PRT
          ref: refs/pull/\${{ github.event.pull_request.number }}/merge"
audit_case "pull_request_target + merge_commit_sha checkout" 2 "$PRT
          ref: \${{ github.event.pull_request.merge_commit_sha }}"
audit_case "pull_request_target + quoted head.sha checkout" 2 "$PRT
          ref: '\${{ github.event.pull_request.head.sha }}'"
audit_case "workflow_run + pull_requests[0].head.sha checkout" 2 'on:
  workflow_run:
    workflows: [ci]
permissions:
  contents: read
jobs:
  b:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.workflow_run.pull_requests[0].head.sha }}'
audit_case "pull_request_target + base.sha checkout is warn, not critical" 0 "$PRT
          ref: \${{ github.event.pull_request.base.sha }}"
audit_case "refs/pull only in a comment is warn, not critical" 0 "$PRT
          ref: main # not refs/pull/1/merge"

# --- composite actions. Until 0.7.0 the identical injection was denied in
#     workflows/ci.yml and allowed in .github/actions/*/action.yml, which runs with the
#     calling workflow's token. Rules 2 and 3 apply there; 1, 4, 5 and 6 read fields a
#     composite does not have, so a clean composite must stay clean.
comp_case() { # label want_rc workflow_yaml action_yaml
  local label="$1" want="$2" got
  rm -rf "$FX/gh"; mkdir -p "$FX/gh/workflows" "$FX/gh/actions/setup"
  printf '%s\n' "$3" > "$FX/gh/workflows/w.yml"
  printf '%s\n' "$4" > "$FX/gh/actions/setup/action.yml"
  bash "$AUDIT" --dir "$FX/gh/workflows" --quiet; got=$?
  if [ "$got" = "$want" ]; then echo "PASS[audit]: $label (rc=$got)"
  else echo "FAIL[audit]: $label — want rc=$want, got $got"; rc=1; fi
}
CLEANWF='on:
  push:
permissions:
  contents: read
jobs:
  b:
    runs-on: ubuntu-latest
    steps:
      - uses: ./.github/actions/setup'

comp_case "PR title in a composite run: is critical" 2 "$CLEANWF" 'name: setup
runs:
  using: composite
  steps:
    - run: echo "${{ github.event.pull_request.title }}"
      shell: bash'

comp_case "a clean composite stays clean" 0 "$CLEANWF" 'name: setup
runs:
  using: composite
  steps:
    - uses: actions/setup-node@v4'

comp_case "base.sha in a composite is SAFE" 0 "$CLEANWF" 'name: setup
runs:
  using: composite
  steps:
    - run: bash check.sh "${{ github.event.pull_request.base.sha }}"
      shell: bash'
rm -rf "$FX/gh"

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

hook_case "PR title in a composite action is denied" deny \
  ".github/actions/setup/action.yml" 'runs:
  using: composite
  steps:
    - run: echo "${{ github.event.pull_request.title }}"
      shell: bash'

hook_case "a clean composite action is allowed" allow \
  ".github/actions/setup/action.yaml" 'runs:
  using: composite
  steps:
    - run: make test
      shell: bash'

hook_case "a non-workflow file is out of scope" allow \
  "src/app.ts" 'const x = "${{ github.event.pull_request.title }}"'

hook_case "refs/pull/N/merge under pull_request_target" deny ".github/workflows/ci.yml" "$PRT
          ref: refs/pull/\${{ github.event.pull_request.number }}/merge"
hook_case "merge_commit_sha under pull_request_target" deny ".github/workflows/ci.yml" "$PRT
          ref: \${{ github.event.pull_request.merge_commit_sha }}"
hook_case "base.sha under pull_request_target is allowed" allow ".github/workflows/ci.yml" "$PRT
          ref: \${{ github.event.pull_request.base.sha }}"
hook_case "refs/pull/N/merge under pull_request is allowed" allow ".github/workflows/ci.yml" 'on:
  pull_request:
jobs:
  b:
    steps:
      - uses: actions/checkout@v4
        with:
          ref: refs/pull/${{ github.event.number }}/merge'

# --- 0.9.10: an Edit is judged for rule 1 on the file as the edit leaves it. Its new_string
#     alone never holds the trigger line, so until then this Edit was allowed.
hook_edit_case() { # label want disk-yaml old new [old2 new2]
  local label="$1" want="$2" f="$FX/repo/.github/workflows/ci.yml" out got
  mkdir -p "$FX/repo/.github/workflows"; printf '%s\n' "$3" > "$f"
  if [ $# -ge 7 ]; then
    out=$(jq -nc --arg f "$f" --arg a "$4" --arg b "$5" --arg c "$6" --arg d "$7" \
          '{tool_name:"MultiEdit",tool_input:{file_path:$f,edits:[{old_string:$a,new_string:$b},{old_string:$c,new_string:$d}]}}' | bash "$HOOK" 2>/dev/null)
  else
    out=$(jq -nc --arg f "$f" --arg a "$4" --arg b "$5" \
          '{tool_name:"Edit",tool_input:{file_path:$f,old_string:$a,new_string:$b}}' | bash "$HOOK" 2>/dev/null)
  fi
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then got=deny; else got=allow; fi
  if [ "$got" = "$want" ]; then echo "PASS[hook]: edit: $label ($got)"
  else echo "FAIL[hook]: edit: $label — want $want, got $got"; rc=1; fi
}
SAFE="$PRT
          ref: \${{ github.sha }}"
HEADCO="$PRT
          ref: \${{ github.event.pull_request.head.sha }}"
hook_edit_case "an Edit pointing ref: at the PR head is denied" deny "$SAFE" \
  'ref: ${{ github.sha }}' 'ref: ${{ github.event.pull_request.head.sha }}'
hook_edit_case "an Edit pointing ref: at base.sha is allowed" allow "$SAFE" \
  'ref: ${{ github.sha }}' 'ref: ${{ github.event.pull_request.base.sha }}'
hook_edit_case "an Edit adding the privileged trigger to a head checkout is denied" deny \
  "$(printf '%s' "$HEADCO" | sed 's/pull_request_target:/pull_request:/')" '  pull_request:' '  pull_request_target:'
hook_edit_case "a MultiEdit whose second edit adds refs/pull is denied" deny "$SAFE" \
  'runs-on: ubuntu-latest' 'runs-on: ubuntu-24.04' 'ref: ${{ github.sha }}' 'ref: refs/pull/${{ github.event.pull_request.number }}/head'
hook_edit_case "an unrelated Edit to a file already checking out the head is allowed" allow "$HEADCO" \
  'runs-on: ubuntu-latest' 'runs-on: ubuntu-24.04'
hook_edit_case "an Edit removing the head checkout is allowed" allow "$HEADCO" \
  'ref: ${{ github.event.pull_request.head.sha }}' 'ref: ${{ github.sha }}'
rm -rf "$FX/repo"

hook_bash_case() { # label want command
  local label="$1" want="$2" cmd="$3" out got
  out=$(jq -nc --arg c "$cmd" '{tool_name:"Bash",cwd:"/tmp",tool_input:{command:$c}}' \
        | bash "$HOOK" 2>/dev/null)
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then got=deny; else got=allow; fi
  if [ "$got" = "$want" ]; then echo "PASS[hook]: bash: $label ($got)"
  else echo "FAIL[hook]: bash: $label — want $want, got $got"; rc=1; fi
}

BODY='jobs:
  b:
    steps:
      - run: echo "${{ github.event.pull_request.body }}"'

hook_bash_case "heredoc writing a PR body into a run: block is denied" deny \
  "$(printf '%s\n%s\n%s' "cat > .github/workflows/ci.yml <<'EOF'" "$BODY" 'EOF')"

hook_bash_case "non-write command is allowed" allow \
  'git status && gh run list'

hook_bash_case "heredoc into a command that writes no file is allowed" allow \
  "$(printf '%s\n%s\n%s' "yq eval - <<'EOF'" "$BODY" 'EOF')"

hook_bash_case "heredoc to a non-workflow path is allowed" allow \
  "$(printf '%s\n%s\n%s' "cat > notes/ci.yml <<'EOF'" "$BODY" 'EOF')"

out=$(jq -nc --arg c "echo '      - run: echo \"\${{ github.event.pull_request.body }}\"' >> .github/workflows/ci.yml" '{tool_name:"Bash",cwd:"/tmp",tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null)
if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then echo "PASS[hook]: echo: a quoted run: line appended to a workflow is denied (deny)"
else echo "FAIL[hook]: echo: a quoted run: line appended to a workflow is denied — want deny, got allow"; rc=1; fi

MIXED=$(printf '%s\n%s\n%s\n%s\n%s\n%s' "cat > .github/workflows/ci.yml <<'EOF'" 'jobs: {}' 'EOF' "yq eval - <<'EOF'" "$BODY" 'EOF')
out=$(jq -nc --arg c "$MIXED" '{tool_name:"Bash",cwd:"/tmp",tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null)
if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then echo "FAIL[hook]: mixed: a yq heredoc beside a clean workflow write is not judged — want allow, got deny"; rc=1
else echo "PASS[hook]: mixed: a yq heredoc beside a clean workflow write is not judged (allow)"; fi

# 0.7.0: the deny reason used to name plugins/devops/scripts/workflow-audit.sh, a path
# that exists only in this marketplace's own tree. It must resolve the plugin root the
# host hands the hook.
out=$(jq -nc --arg f ".github/workflows/ci.yml" --arg c 'jobs:
  b:
    steps:
      - run: echo "${{ github.event.pull_request.body }}"' \
      '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}' \
      | CLAUDE_PLUGIN_ROOT=/opt/plugins/devops bash "$HOOK" 2>/dev/null)
if printf '%s' "$out" | grep -q '/opt/plugins/devops/scripts/workflow-audit.sh' \
   && ! printf '%s' "$out" | grep -q 'bash plugins/devops/'; then
  echo "PASS[hook]: deny reason names the installed audit path"
else
  echo "FAIL[hook]: deny reason does not resolve CLAUDE_PLUGIN_ROOT: $out"; rc=1
fi
r=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')
want='devops blocked this write: a run: step puts a ${{ github.event.* }} field a pull-request author controls (title, body, branch name, commit message) straight into the shell, where it runs as code. Pass it through env: and reference "$VAR" in the script. (file: .github/workflows/ci.yml) Full report: bash /opt/plugins/devops/scripts/workflow-audit.sh. CC_WORKFLOW_GUARD=off turns this check off.'
if [ "$r" = "$want" ]; then echo "PASS[hook]: injection reason: what was blocked, the fix, the file, the report, one off switch"
else echo "FAIL[hook]: injection reason text — got: $r"; rc=1; fi
out=$(jq -nc --arg f ".github/workflows/ci.yml" --arg c 'on:
  pull_request_target:
jobs:
  b:
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.ref }}' \
      '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}' \
      | CLAUDE_PLUGIN_ROOT=/opt/plugins/devops bash "$HOOK" 2>/dev/null)
r=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')
case "$r" in
  "devops blocked this write: the workflow checks out the pull request's code under pull_request_target or workflow_run, which runs it with the repository's secrets and a write token. Build the PR under pull_request with no secrets, or check out the base ref and treat the PR tree as data. (file: .github/workflows/ci.yml)"*)
    echo "PASS[hook]: privileged-checkout reason: what was blocked and the fix" ;;
  *) echo "FAIL[hook]: privileged-checkout reason text — got: $r"; rc=1 ;;
esac

if printf 'not json' | bash "$HOOK" >/dev/null 2>&1; then
  echo "PASS[hook]: garbage input exits 0 (fail-open)"
else
  echo "FAIL[hook]: garbage input did not exit 0"; rc=1
fi

[ "$rc" -eq 0 ] && echo "All devops workflow-audit fixtures passed."
exit "$rc"
