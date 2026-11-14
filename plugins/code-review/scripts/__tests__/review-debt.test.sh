#!/usr/bin/env bash
# review-debt.test.sh — drives hooks/review-debt.sh through one ordered scenario in a temp git repo: base, growth, reviews and their
#   content credit, once per range, switches, ship prompts, harness frames, off switches, fail-open; every payload carries transcript_path.
# Misses: whether the host names `.tool_input.subagent_type` / `.tool_input.skill` so on PostToolUse; whether a typed slash command arrives as `/name args`.
# Why, limits, history: rationale/derivations/plugin-code-review.md § plugins/code-review/scripts/__tests__/review-debt.test.sh
set -u
cd "$(dirname "$0")/../../../.." || exit 1
H="$PWD/plugins/code-review/hooks/review-debt.sh"
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }

# This session exports CLAUDE_PROJECT_DIR (the marketplace repo); a user's own git config
# may sign commits or install hooks. Neither belongs in a fixture.
unset CLAUDE_PROJECT_DIR CC_REMIND CC_REVIEW_NUDGE
export HOME="$FX/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"
g() { git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }

R="$FX/repo"
mkdir -p "$R"
g init -q
printf 'readme\n' > "$R/README.md"
g add -A && g commit -qm init

TP1='/Users/x/.claude/projects/-Users-x-proj/11111111-aaaa.jsonl'
TP2='/Users/x/.claude/projects/-Users-x-proj/22222222-bbbb.jsonl'
TP3='/Users/x/.claude/projects/-Users-x-proj/33333333-cccc.jsonl'
TP4='/Users/x/.claude/projects/-Users-x-proj/44444444-dddd.jsonl'
TP5='/Users/x/.claude/projects/-Users-x-proj/55555555-eeee.jsonl'
TP6='/Users/x/.claude/projects/-Users-x-proj/66666666-ffff.jsonl'
TP7='/Users/x/.claude/projects/-Users-x-proj/77777777-aaaa.jsonl'
TP8='/Users/x/.claude/projects/-Users-x-proj/88888888-bbbb.jsonl'
TP9='/Users/x/.claude/projects/-Users-x-proj/99999999-cccc.jsonl'
TP10='/Users/x/.claude/projects/-Users-x-proj/10101010-dddd.jsonl'
TP11='/Users/x/.claude/projects/-Users-x-proj/11011011-eeee.jsonl'
TP12='/Users/x/.claude/projects/-Users-x-proj/12121212-ffff.jsonl'

say() { # cwd prompt transcript -> additionalContext ('' when silent)
  jq -nc --arg c "$1" --arg p "$2" --arg t "$3" \
    '{hook_event_name:"UserPromptSubmit",session_id:"sid-1",transcript_path:$t,cwd:$c,prompt:$p}' \
    | bash "$H" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
prompt() { say "$R" "proceed next recommended" "$TP1"; }
agent() { # subagent_type
  jq -nc --arg c "$R" --arg a "$1" --arg t "$TP1" \
    '{hook_event_name:"PostToolUse",tool_name:"Agent",session_id:"sid-1",transcript_path:$t,cwd:$c,
      tool_input:{subagent_type:$a,description:"x",prompt:"x"},tool_response:{}}' | bash "$H" >/dev/null 2>&1
}
skill() { # skill name
  jq -nc --arg c "$R" --arg s "$1" --arg t "$TP1" \
    '{hook_event_name:"PostToolUse",tool_name:"Skill",session_id:"sid-1",transcript_path:$t,cwd:$c,
      tool_input:{skill:$s},tool_response:{}}' | bash "$H" >/dev/null 2>&1
}
agent_bg() { # subagent_type transcript — an Agent call the host ran in the background, as PostToolUse sees it
  jq -nc --arg c "$R" --arg a "$1" --arg t "$2" \
    '{hook_event_name:"PostToolUse",tool_name:"Agent",session_id:"sid-1",transcript_path:$t,cwd:$c,
      tool_input:{subagent_type:$a,description:"Review the branch",prompt:"x",run_in_background:true},
      tool_response:{isAsync:true,status:"async_launched",agentId:"a41def590cfbd9bc0",description:"Review the branch",
        prompt:"x",outputFile:"/tmp/a41def590cfbd9bc0.output",canReadOutputFile:true,canContinueAgent:true}}' \
    | bash "$H" >/dev/null 2>&1
}
skill_as() { # skill transcript — a Skill call with the tool_response the host records for it
  jq -nc --arg c "$R" --arg s "$1" --arg t "$2" \
    '{hook_event_name:"PostToolUse",tool_name:"Skill",session_id:"sid-1",transcript_path:$t,cwd:$c,
      tool_input:{skill:$s,args:"HEAD"},tool_response:{success:true,commandName:$s}}' | bash "$H" >/dev/null 2>&1
}
commit() { # msg path... — writes fresh content to each path, commits
  local m="$1" f; shift
  for f in "$@"; do mkdir -p "$R/$(dirname "$f")"; printf '%s %s\n' "$f" "$RANDOM$RANDOM" >> "$R/$f"; done
  g add -A && g commit -qm "$m"
}
silent() { # label output
  if [ -z "$2" ]; then echo "PASS: $1 (silent)"; else echo "FAIL: $1 — fired: $2"; rc=1; fi
}
fires() { # label output needle...
  local l="$1" o="$2" n; shift 2
  [ -n "$o" ] || { echo "FAIL: $l — silent"; rc=1; return; }
  for n in "$@"; do
    printf '%s' "$o" | grep -qF -- "$n" || { echo "FAIL: $l — missing '$n' in: $o"; rc=1; return; }
  done
  echo "PASS: $l"
}
base_of() { # transcript -> the base commit (the file's first word; the second is the branch)
  local b=""
  read -r b _ < "$R/.cc-artifacts/code-review/review-base-$(printf '%s' "$1" | cksum | cut -d' ' -f1)" 2>/dev/null
  printf '%s' "$b"
}

# ---- first prompt: record a base, say nothing --------------------------------------
silent "first prompt" "$(prompt)"
[ "$(base_of "$TP1")" = "$(g rev-parse HEAD)" ] \
  && echo "PASS: first prompt recorded HEAD as the base" \
  || { echo "FAIL: first prompt did not record HEAD as the base"; rc=1; }

# ---- 9 committed code files: nudge once, then not again at the same HEAD -----------
commit "nine" src/f1.ts src/f2.ts src/f3.ts src/f4.ts src/f5.ts src/f6.ts src/f7.ts src/f8.ts src/f9.ts
base1=$(base_of "$TP1"); short1=$(g rev-parse --short "$base1")
out=$(prompt)
fires "9 committed code files nudge" "$out" \
  "[code-review] 9 changed files have had no review in this session since $short1. Run /code-review:review $short1..HEAD or say in one line why not (CC_REVIEW_NUDGE=off turns this reminder off)."
printf '%s' "$out" | grep -qi 'per-card' && { echo "FAIL: the reminder speaks of per-card reviews to a user who may never have run task-runner"; rc=1; }
[ "$(printf '%s' "$out" | wc -c)" -le 300 ] && echo "PASS: the reminder is at most 300 bytes" \
  || { echo "FAIL: the reminder is over 300 bytes: $out"; rc=1; }
printf '%s' "$out" | grep -q 'Before this ships' && { echo "FAIL: a plain prompt drew the ship wording"; rc=1; }
printf '%s' "$out" | grep -q 'touches auth' && { echo "FAIL: no auth path, yet an auth clause"; rc=1; }
[ "$(printf '%s' "$out" | wc -l | tr -d ' ')" = "0" ] \
  && echo "PASS: the nudge is one line" || { echo "FAIL: the nudge spans lines: $out"; rc=1; }
printf '%s\n' "$out" > "$FX/nudge-count.txt"
silent "same HEAD, second prompt" "$(prompt)"

# ---- a ship prompt after the plain nudge, same base and count: once per range -----------
silent "ship prompt after the plain nudge, same HEAD and count" "$(say "$R" "commit this and push" "$TP1")"
silent "second ship prompt, same count" "$(say "$R" "open the PR" "$TP1")"

# ---- HEAD moves but the count does not grow: silent ---------------------------------
commit "touch one again" src/f1.ts
silent "new HEAD, same 9 files" "$(prompt)"

# ---- a non-reviewer agent does not move the base; growth past what fired re-fires ---
agent Explore
commit "tenth" src/f10.ts
fires "Explore is not a review; 10 > 9 re-fires" "$(prompt)" "10 changed files have had no review in this session since $short1"

# ---- a reviewer dispatch moves the base ---------------------------------------------
agent code-review:code-reviewer
[ "$(base_of "$TP1")" = "$(g rev-parse HEAD)" ] \
  && echo "PASS: reviewer Agent payload moved the base to HEAD" \
  || { echo "FAIL: reviewer Agent payload did not move the base"; rc=1; }
silent "prompt right after a review" "$(prompt)"
commit "one more" src/g1.ts
silent "one ordinary file after a review" "$(prompt)"

# ---- one auth-surface file is enough (after a `*reviewer` dispatch zeroes the count) --
agent web-dev:frontend-reviewer
commit "policy" app/Policies/PostPolicy.php
out=$(prompt)
fires "one changed file under app/Policies/ nudges" "$out" "1 changed file has had no review" \
  "touches auth: app/Policies/PostPolicy.php"
printf '%s\n' "$out" > "$FX/nudge-auth.txt"

# ---- a Skill review moves the base; `author` is not `auth` ----------------------------
skill code-review:review
commit "author" app/Http/Controllers/AuthorController.php
silent "Skill code-review:review moved the base; AuthorController is not auth" "$(prompt)"

# ---- registration is an auth surface (the shared block's words); a registry is not --
commit "registry" app/Support/ServiceRegistry.php
silent "a service registry is not registration" "$(prompt)"
commit "registration" app/Http/Controllers/RegistrationController.php
fires "a registration controller nudges as an auth surface" "$(prompt)" "touches auth: app/Http/Controllers/RegistrationController.php"

# ---- sign-up counts as a word or a camelCase part, not inside DesignUpdates or AssignUploads --
skill code-review:review
commit "design updates" app/Http/Controllers/DesignUpdatesController.php app/Jobs/AssignUploadsToFolder.php
silent "DesignUpdatesController and AssignUploadsToFolder are not sign-up" "$(prompt)"
commit "sign-up" app/Http/Controllers/UserSignUpController.php
fires "a camelCase SignUp controller nudges as an auth surface" "$(prompt)" "touches auth: app/Http/Controllers/UserSignUpController.php"

# ---- the user typing the review command moves the base too --------------------------
silent "typed /code-review:review" "$(say "$R" "/code-review:review src/" "$TP1")"
[ "$(base_of "$TP1")" = "$(g rev-parse HEAD)" ] \
  && echo "PASS: typed /code-review:review moved the base" \
  || { echo "FAIL: typed /code-review:review did not move the base"; rc=1; }

# ---- docs, lockfiles, taskmaster-docs, .claude, .cc-artifacts, vendor: not code to review -----------
commit "docs" docs/a.md docs/b.md docs/c.md docs/d.md docs/e.md docs/f.md docs/g.md docs/h.md \
  composer.lock package-lock.json taskmaster-docs/spec/token.txt .claude/settings.json vendor/pkg/Auth.php \
  .cc-artifacts/taskmaster/specs/token.txt
silent "docs-only change (8 .md + lockfiles + tooling dirs)" "$(prompt)"

# ---- art, media and Unity assets are not code; `guard` is auth only as a word -----------
# The names are firings quoted in rationale/session-retro-2026-11-05.md, issue 6.
skill code-review:review
commit "art" Assets/Art/SM_Env_GuardPost.fbx Assets/Art/SM_Env_GuardPost.fbx.meta Assets/UI/upg_guardpost.png \
  Assets/UI/upg_guardpost.png.meta Assets/Animations/Hero_Guard.controller Assets/Materials/Fx_Guardian.mat \
  Assets/Audio/hit.wav Assets/Models/hero.blend Assets/Models/hero.glb Assets/Art/concept.psd
silent "art only: 10 binaries and Unity assets, guard in their names" "$(prompt)"
printf 'x\n' > "$R/Assets/UI/upg_guardpost_v2.PNG"; printf 'x\n' > "$R/Assets/Models/hero_lod1.FBX"
silent "ship prompt with only art changed and untracked" "$(say "$R" "commit this" "$TP1")"
rm -f "$R/Assets/UI/upg_guardpost_v2.PNG" "$R/Assets/Models/hero_lod1.FBX"
commit "code beside art" Assets/Scripts/c1.cs Assets/Scripts/c2.cs Assets/Scripts/c3.cs Assets/Scripts/c4.cs \
  Assets/Scripts/c5.cs Assets/Scripts/c6.cs Assets/Scripts/c7.cs Assets/Scripts/c8.cs \
  Assets/Art/b.fbx Assets/UI/b.png Assets/Audio/b.ogg
out=$(prompt)
fires "8 code files beside 13 art files count as 8" "$out" "8 changed files have had no review"
printf '%s' "$out" | grep -q 'touches auth' && { echo "FAIL: art named for a guard post drew an auth clause: $out"; rc=1; }
skill code-review:review
commit "guard post code" Assets/Scripts/SM_Env_GuardPost.cs Assets/Scripts/Fx_Guardian.cs Assets/Scripts/upg_guardpost.ts
silent "GuardPost, Guardian and guardpost in code paths are not auth" "$(prompt)"
skill code-review:review
commit "guards" Guard.php src/guard.ts lib/JwtGuard.php src/guards/admin.ts
fires "guard as a word, a plural or a camelCase part is still auth" "$(prompt)" \
  "4 changed files have had no review" "touches auth: Guard.php, lib/JwtGuard.php, src/guard.ts, +1 more"

# ---- under an active task-runner run: silent, and the run's diff is not charged later
mkdir -p "$R/.cc-artifacts/task-runner" && printf '{}\n' > "$R/.cc-artifacts/task-runner/active-run.json"
commit "run work" run/a.ts run/b.ts run/c.ts run/d.ts run/e.ts run/f.ts run/g.ts run/h.ts app/Http/Middleware/Tenant.php
silent "active-run.json present" "$(prompt)"
rm -f "$R/.cc-artifacts/task-runner/active-run.json"
commit "after the run" src/after.ts
silent "first prompt after the run does not charge the run's 9 files" "$(prompt)"
# A run task-runner registered under .claude/task-runner/ before 2026-11-14 counts until .cc-artifacts/task-runner/ exists.
rm -rf "$R/.cc-artifacts/task-runner"; mkdir -p "$R/.claude/task-runner" && printf '{}\n' > "$R/.claude/task-runner/active-run.json"
commit "old run work" old/a.ts old/b.ts old/c.ts old/d.ts old/e.ts old/f.ts old/g.ts old/h.ts app/Http/Middleware/OldTenant.php
silent "a .claude/task-runner/active-run.json from before 2026-11-14, no new run dir" "$(prompt)"
mkdir -p "$R/.cc-artifacts/task-runner"
commit "next to a stale old run" old/i.ts old/j.ts old/k.ts old/l.ts old/m.ts old/n.ts old/o.ts old/p.ts app/Http/Middleware/NewTenant.php
fires "once .cc-artifacts/task-runner/ exists, a stale .claude/ run file no longer silences" "$(prompt)" "NewTenant.php"
skill code-review:review
rm -rf "$R/.claude/task-runner" "$R/.cc-artifacts/task-runner"

# ---- off switches ---------------------------------------------------------------------
commit "impersonation" app/Http/Middleware/Impersonate.php
o=$(jq -nc --arg c "$R" --arg t "$TP1" \
      '{hook_event_name:"UserPromptSubmit",session_id:"sid-1",transcript_path:$t,cwd:$c,prompt:"go"}' \
    | CC_REVIEW_NUDGE=off bash "$H" 2>/dev/null)
silent "CC_REVIEW_NUDGE=off" "$o"
o=$(jq -nc --arg c "$R" --arg t "$TP1" \
      '{hook_event_name:"UserPromptSubmit",session_id:"sid-1",transcript_path:$t,cwd:$c,prompt:"go"}' \
    | CC_REMIND=off bash "$H" 2>/dev/null)
silent "CC_REMIND=off" "$o"
fires "the same state with the switches unset still nudges" "$(prompt)" "Impersonate.php"

# ---- subdirectory cwd: state at the repo root, one context across `cd` ----------------
commit "dirs" app/Enums/Status.php app/Models/User.php
silent "first prompt of a second context, cwd app/Enums" "$(say "$R/app/Enums" go "$TP2")"
[ -n "$(base_of "$TP2")" ] && echo "PASS: subdirectory cwd — state landed at the repo root" \
  || { echo "FAIL: subdirectory cwd — no state at the repo root"; rc=1; }
[ -e "$R/app/Enums/.cc-artifacts" ] && { echo "FAIL: subdirectory cwd — a .cc-artifacts/ appeared in app/Enums"; rc=1; } \
  || echo "PASS: subdirectory cwd — no .cc-artifacts/ in the subdirectory"
commit "guard" app/Auth/TenantGuard.php
fires "cwd app/Models sees the same context's base" "$(say "$R/app/Models" go "$TP2")" "TenantGuard.php"
silent "cwd at the root, same HEAD: already judged" "$(say "$R" go "$TP2")"
[ -e "$R/app/Models/.cc-artifacts" ] && { echo "FAIL: a .cc-artifacts/ appeared in app/Models"; rc=1; }

# ---- a base that left HEAD's history (amend) resets instead of diffing across ----------
silent "first prompt of a third context" "$(say "$R" go "$TP3")"
printf 'amended\n' >> "$R/app/Auth/TenantGuard.php"
g add -A && g commit -q --amend -m "guard, amended"
silent "base no longer an ancestor of HEAD" "$(say "$R" go "$TP3")"
[ "$(base_of "$TP3")" = "$(g rev-parse HEAD)" ] \
  && echo "PASS: the orphaned base was reset to HEAD" \
  || { echo "FAIL: the orphaned base was not reset"; rc=1; }

# ---- a switch to a branch built on the base does not charge that branch's files -------
silent "first prompt of a fourth context, on master" "$(say "$R" go "$TP4")"
g checkout -q -b upgrade
commit "upgrade work" up/a.ts up/b.ts up/c.ts up/d.ts up/e.ts up/f.ts up/g.ts up/h.ts up/i.ts app/Auth/UpGuard.php
g checkout -q master
silent "fourth context, back on master" "$(say "$R" go "$TP4")"
g switch -q upgrade
silent "switched to a branch built on the base: its 10 files are not this session's" "$(say "$R" go "$TP4")"
[ "$(base_of "$TP4")" = "$(g rev-parse HEAD)" ] \
  && echo "PASS: the base moved to where the switch landed" \
  || { echo "FAIL: the base did not move to the switched-to tip"; rc=1; }
commit "after the switch" app/Auth/AfterSwitch.php
fires "a commit after the switch is counted alone" "$(say "$R" go "$TP4")" \
  "1 changed file has had no review" "touches auth: app/Auth/AfterSwitch.php"

# ---- git switch -c plus commits in one turn stay in the count ------------------------
silent "first prompt of a fifth context" "$(say "$R" go "$TP5")"
start5=$(g rev-parse --short HEAD)
g switch -q -c feature
commit "feature" ft/a.ts ft/b.ts ft/c.ts ft/d.ts ft/e.ts ft/f.ts ft/g.ts ft/h.ts
fires "new branch and 8 commits in one turn: counted from the branch point" "$(say "$R" go "$TP5")" \
  "8 changed files have had no review in this session since $start5"

# ---- uncommitted and untracked work at a ship prompt ---------------------------------
silent "first prompt of a sixth context" "$(say "$R" go "$TP6")"
start6=$(g rev-parse --short HEAD)
printf 'edit\n' >> "$R/ft/a.ts"
mkdir -p "$R/app/Billing" && printf 'new\n' > "$R/app/Billing/PaymentHold.php"
silent "uncommitted work, plain prompt, same HEAD: still once per HEAD" "$(say "$R" "proceed next recommended" "$TP6")"
out=$(say "$R" "open a PR and merge it" "$TP6")
fires "uncommitted + untracked auth file at a ship prompt, same HEAD" "$out" \
  "[code-review] Before this ships: 2 changed files have had no review in this session since $start6, uncommitted and untracked files included (touches auth: app/Billing/PaymentHold.php). Run /code-review:review $start6 now or say in one line why not (CC_REVIEW_NUDGE=off turns this reminder off)."
printf '%s\n' "$out" > "$FX/nudge-ship.txt"
silent "same count, second ship prompt" "$(say "$R" "git push" "$TP6")"
printf 'new\n' > "$R/ft/z.ts"
# Neighbouring words are not ship verbs; each would fire now (3 > 2) if read as one.
silent "pre-commit is not commit" "$(say "$R" "add a pre-commit hook for the linter" "$TP6")"
silent "merge-base is not merge" "$(say "$R" "use git merge-base to find the fork point" "$TP6")"
silent "push_notifications is not push" "$(say "$R" "rename the push_notifications table" "$TP6")"
silent "a path holding merge is not merge" "$(say "$R" "read src/merge/strategy.ts" "$TP6")"
silent "ship verb inside a code fence" "$(say "$R" "$(printf 'why does this fail?\n```\n$ git push origin main\n```')" "$TP6")"
silent "ship verb past 400 characters" "$(say "$R" "$(printf 'x%.0s' $(seq 1 400)) then commit" "$TP6")"
silent "task notification naming a merge" "$(say "$R" "<task-notification>agent finished: merge conflict resolved</task-notification>" "$TP6")"
silent "Stop hook feedback naming a commit" "$(say "$R" "Stop hook feedback: uncommitted changes — commit or stash before stopping" "$TP6")"
for f in "<system-reminder>run git push after the build</system-reminder>" "[SYSTEM NOTIFICATION] merge queue updated" \
         "Another Claude session sent a message: please commit your work" "<agent-message from=\"w1\">ready to merge</agent-message>" \
         "*[Subagent hand-back]* done; open the PR when ready"; do
  silent "harness frame naming a ship verb: ${f%% *}" "$(say "$R" "$f" "$TP6")"
done
fires "the slash form /commit is a ship verb" "$(say "$R" "/commit" "$TP6")" "Before this ships: 3 changed files"
printf 'new\n' > "$R/ft/y.ts"
fires "a hand-back marker quoted mid-sentence is the user's ship prompt" \
  "$(say "$R" "merge it once the relay prints [Subagent hand-back] for card 3" "$TP6")" "Before this ships: 4 changed files"

# ---- a review credits the content it was handed: a merge and a pull do not charge it again --
g add -A && g commit -qm "the sixth context's work"
g switch -q -c trunk
silent "first prompt of a seventh context" "$(say "$R" go "$TP7")"
t7=$(g rev-parse --short HEAD)
g switch -q -c pr7
commit "pr work" pr/a.ts pr/b.ts pr/c.ts pr/d.ts pr/e.ts pr/f.ts pr/g.ts pr/h.ts pr/i.ts
agent_bg code-review:code-reviewer "$TP7"
commit "review fix" pr/a.ts
g switch -q -c gh-merge trunk && g merge -q --no-ff -m "Merge pull request #7" pr7 \
  && g switch -q trunk && g merge -q --ff-only gh-merge
silent "merged and pulled after a background reviewer: only the file changed since counts" "$(say "$R" go "$TP7")"
commit "next" nx/a.ts nx/b.ts nx/c.ts nx/d.ts nx/e.ts nx/f.ts nx/g.ts nx/h.ts
fires "the fixed file and 8 new ones count, the 8 reviewed and unchanged do not" "$(say "$R" go "$TP7")" \
  "9 changed files have had no review in this session since $t7"

# ---- work reviewed uncommitted, then committed, stays credited; an edit after it does not --
silent "first prompt of an eighth context" "$(say "$R" go "$TP8")"
t8=$(g rev-parse --short HEAD)
mkdir -p "$R/wt"
for f in a b c d e f g h i; do printf '%s %s\n' "$f" "$RANDOM" > "$R/wt/$f.ts"; done
skill_as code-review "$TP8"
g add -A && g commit -qm "reviewed work"
silent "9 files reviewed by the host's code-review while untracked, then committed" "$(say "$R" go "$TP8")"
for f in a b c d e f g h; do printf 'edited\n' >> "$R/wt/$f.ts"; done
fires "8 of them edited after the review, at a ship prompt" "$(say "$R" "commit it" "$TP8")" \
  "Before this ships: 8 changed files have had no review in this session since $t8"

# ---- unreviewed work merged and pulled at the same base and count: once per range ---------
g add -A && g commit -qm "the eighth context's edits"
silent "first prompt of a ninth context" "$(say "$R" go "$TP9")"
t9=$(g rev-parse --short HEAD)
g switch -q -c pr9
commit "unreviewed" q/a.ts q/b.ts q/c.ts q/d.ts q/e.ts q/f.ts q/g.ts q/h.ts q/i.ts
fires "9 unreviewed files on a new branch" "$(say "$R" go "$TP9")" "9 changed files have had no review in this session since $t9"
g switch -q -c gh9 trunk && g merge -q --no-ff -m "Merge pull request #9" pr9 \
  && g switch -q trunk && g merge -q --ff-only gh9
silent "merged and pulled: the same 9 files from the same base" "$(say "$R" go "$TP9")"
silent "then a ship prompt at the same count" "$(say "$R" "push it" "$TP9")"

# ---- a review at the base clears what was named and keeps its credit ----------------------
silent "first prompt of a tenth context" "$(say "$R" go "$TP10")"
t10=$(g rev-parse --short HEAD)
mkdir -p "$R/app/Auth" && printf 'v1\n' > "$R/app/Auth/Reset.php" && printf 'v1\n' > "$R/app/Auth/Kept.php"
fires "two untracked auth files at a ship prompt" "$(say "$R" "commit it" "$TP10")" \
  "2 changed files have had no review" "touches auth: app/Auth/Kept.php, app/Auth/Reset.php"
agent_bg code-review:code-reviewer "$TP10"
printf 'v2\n' >> "$R/app/Auth/Reset.php"
g add -A && g commit -qm "reset, edited after the review"
fires "a review at HEAD == base: the file edited since speaks again, the one unchanged stays credited" "$(say "$R" go "$TP10")" \
  "1 changed file has had no review in this session since $t10 (touches auth: app/Auth/Reset.php)"

# ---- one base, a different set of files at the same count is named; the same set is not --
silent "first prompt of an eleventh context" "$(say "$R" go "$TP11")"
t11=$(g rev-parse --short HEAD)
g switch -q -c fa
commit "fa" fa/a.ts fa/b.ts fa/c.ts fa/d.ts fa/e.ts fa/f.ts fa/g.ts fa/h.ts fa/i.ts
fires "9 files on a first branch" "$(say "$R" go "$TP11")" "9 changed files have had no review in this session since $t11"
g switch -q trunk
silent "back on trunk, the base is $t11 again" "$(say "$R" go "$TP11")"
g switch -q -c fb
commit "fb" fb/a.ts fb/b.ts fb/c.ts fb/d.ts fb/e.ts fb/f.ts fb/g.ts fb/h.ts fb/i.ts
fires "9 other files from the same base, the same count" "$(say "$R" go "$TP11")" \
  "9 changed files have had no review in this session since $t11"
silent "a ship prompt over the same 9 files" "$(say "$R" "push it" "$TP11")"

# ---- a C-quoted name or a gitlink a review saw is never credited; a path it saw deleted is --
silent "first prompt of a twelfth context" "$(say "$R" go "$TP12")"
mkdir -p "$R/libs/auth-sdk" && g -C libs/auth-sdk init -q && g -C libs/auth-sdk commit -q --allow-empty -m one
g add libs/auth-sdk 2>/dev/null && g commit -qm "auth-sdk as a gitlink"
printf 'v1\n' > "$R/app/Auth/Q\"uote.php"
g rm -q app/Auth/Kept.php
agent_bg code-review:code-reviewer "$TP12"
g -C libs/auth-sdk commit -q --allow-empty -m two
printf 'v2\n' >> "$R/app/Auth/Q\"uote.php"
g add -A 2>/dev/null && g commit -qm "quoted name edited, gitlink moved, deletion committed"
out=$(say "$R" go "$TP12")
fires "a C-quoted name and a moved gitlink count after a review; the reviewed deletion does not" "$out" \
  "2 changed files have had no review" 'touches auth: "app/Auth/Q\"uote.php", libs/auth-sdk'
printf '%s' "$out" | grep -q 'Kept.php' && { echo "FAIL: a deletion the review saw was charged again: $out"; rc=1; }

# ---- base_f and seen_f are renamed into place, so concurrent refuter launches never truncate them --
sd="$R/.cc-artifacts/code-review"; c12=$(printf '%s' "$TP12" | cksum | cut -d' ' -f1)
ino() { ls -i "$1" 2>/dev/null | awk '{ print $1 }'; }
b0=$(ino "$sd/review-base-$c12"); s0=$(ino "$sd/review-seen-$c12")
agent_bg code-review:code-reviewer "$TP12"
[ -n "$b0" ] && [ "$(ino "$sd/review-base-$c12")" != "$b0" ] && [ "$(ino "$sd/review-seen-$c12")" != "$s0" ] \
  && echo "PASS: a review replaces base_f and seen_f by rename (new inodes)" \
  || { echo "FAIL: a review rewrote base_f or seen_f in place"; rc=1; }
for n in 1 2 3 4 5 6; do agent_bg code-review:code-reviewer "$TP12" & done; wait
bl=$(cat "$sd/review-base-$c12" 2>/dev/null)
[ "$bl" = "$(g rev-parse HEAD) fb" ] && echo "PASS: six concurrent review launches leave base_f whole" \
  || { echo "FAIL: base_f after six concurrent review launches: '$bl'"; rc=1; }
ls "$sd" | grep -qE '^review-(base|seen)-[0-9]+\.[0-9]+$' && { echo "FAIL: a temp state file was left behind"; rc=1; } \
  || echo "PASS: no temp state file left behind"

# ---- outside git: silent, and no state written -----------------------------------------
mkdir -p "$FX/plain"
silent "outside a git repo" "$(say "$FX/plain" go "$TP1")"
[ -e "$FX/plain/.cc-artifacts" ] && { echo "FAIL: outside git — a .cc-artifacts/ was created"; rc=1; } \
  || echo "PASS: outside git — nothing written"

# ---- fail-open ----------------------------------------------------------------------------
if o=$(printf 'not json' | bash "$H" 2>/dev/null) && [ -z "$o" ]; then
  echo "PASS: garbage input exits 0 with no output"
else echo "FAIL: garbage input did not fail open"; rc=1; fi

echo
echo "nudge (count):  $(cat "$FX/nudge-count.txt")"
echo "nudge (auth):   $(cat "$FX/nudge-auth.txt")"
echo "nudge (ship):   $(cat "$FX/nudge-ship.txt")"
[ "$rc" -eq 0 ] && echo "review-debt.test: all cases passed" || echo "review-debt.test: FAILURES above"
exit "$rc"
