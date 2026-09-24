#!/bin/bash
# Absolute-path shebang, not `/usr/bin/env bash`: the fail-open guarantee must
# hold under a stripped PATH where `env bash` exits 127.
#
# candor-gate — THE Stop gate of this marketplace: five clauses, each falsifiable
# on disk or in the transcript, none a tone judgement (tone is measured by
# /candor:check and blocked by nothing). Until 2026-09-14 clauses 3 and 4 were two
# sibling scripts, code-architecture/hooks/evidence-gate.sh and
# task-runner/hooks/completion-gate.sh; each had grown a namespaced disarm so the
# others could not spend its enforcement through the SHARED stop_hook_active
# flag. One script needs no such protocol: it records WHICH clause blocked and
# skips only that clause on its own continuation.
#
#   CLAUSE 1 — FABRICATED CITATION. The final assistant message contains a
#   `path/to/file.ext:NNN` reference that does not resolve: no such file under
#   cwd, or the file has fewer lines than the number cited. A file:line citation
#   asserts "I read this"; when it resolves to nothing, that assertion is false
#   and a script can prove it.
#
#   CLAUSE 2 — UNEVIDENCED REVERSAL. The last user message is BARE pushback —
#   challenge-shaped ("are you sure?", "that's wrong", "nope"), carrying no
#   correction of its own — and the final assistant message retracts ("you're
#   right", "my mistake") while NO tool ran after that pushback and the message
#   states no basis for the change. Sycophancy with the evidence step skipped.
#
#   CLAUSE 3 — NAKED COMPLETION CLAIM (was code-architecture's evidence-gate).
#   The assistant tail claims completion (done, fixed, implemented, verified,
#   passes …), files were mutated this session, and NOTHING was executed after
#   the last mutation — no test, no build, no lint, not even running the code.
#   The exact shape of the later apology "you're right, I didn't actually do it".
#   The escape is honesty: prose naming what is unverified passes.
#
#   CLAUSE 4 — REGISTERED RUN NOT COMPLETE (was task-runner's completion-gate).
#   A task-runner run REGISTERED itself ($cwd/.claude/task-runner/active-run.json)
#   and is stopping without a recorded behavioral-gate pass for the current HEAD,
#   with cards neither done nor parked, with per-card negative-control or
#   reviewer records short, with a red-team panel short on a boosted run, or
#   with a recorded reduction its closing report never names. Dormant outside a
#   registered run, on another branch, and without git — exactly as before.
#
# WHAT NO OTHER GATE CARRIES (Admission law — .claude/skills/authoring-skills/SKILL.md
# in the marketplace repository, "The four laws"): this repo's scripts/done-gate.sh
# is marketplace-specific and gate-status based; this hook ships with the plugin
# and works in any project, git or not (clause 4 alone needs git, and stands down
# without it).
#
# LIMITATION (honest scope — the four laws, "Honest limitation"):
#   - CLAUSE 1 checks `file:line` ONLY, never a bare path — a bare path is
#     routinely a file the turn PROPOSES to create. An invented API name,
#     package, flag or function is NOT caught; only an invented location is.
#   - CLAUSE 1 fires on an invented FILENAME, not a wrong directory (see the
#     ladder in resolve() for the measurement that forced that scope).
#   - CLAUSE 1 cannot see intent: a citation into a file the turn itself just
#     shortened, deleted or renamed blocks though the model did read it. An
#     elided path (`plugins/x/.../SKILL.md:74`) is skipped, never resolved.
#   - CLAUSE 2's pushback test is a regex over one message. Pushback phrased
#     outside the list is invisible; a user message carrying its OWN correction
#     deliberately disarms the clause. ANY tool call after the pushback counts.
#   - CLAUSES 1 and 2 judge the FINAL assistant message only; clause 3 matches
#     CLAIM and ACK over the last 30 lines of assistant text, and that window
#     bleeds in BOTH directions (measured; documented in the clause).
#   - CLAUSE 3: saying nothing evades it; ANY post-edit execution satisfies it
#     (a `git status` counts — it proves something ran, not the right thing); an
#     Agent/Task call counts as execution. Edits to PROSE files (.md, .txt, .rst,
#     .adoc) do not arm it — nothing executable proves a README right — so a
#     docs-only turn that says "done" passes on the claim alone.
#   - CLAUSE 4 enforces only a run that REGISTERED itself. A run that never
#     writes active-run.json is not enforced (fail-open) — the same residual the
#     behavioral-gate skill names. It never executes tests: it is a records check.
#   - CLAUSE 4's record counts (nc/, rv/, rt/ lenses and critic, reductions) count
#     only files NEWER than active-run.json, so a record left by a previous run
#     cannot cover this one — card ids repeat across runs and those dirs are never
#     cleared. nc/ was the one count missing that bound until 0.3.7. The residual
#     runs the other way: a legitimate record written BEFORE the run registered
#     itself is invisible, which blocks rather than passes.
#   - Tone — flattery, defensiveness, apology spirals — is NOT gated. No regex
#     separates "you're right" said because it is true from the same words said
#     to please. /candor:check measures it; the straight-talk skill is where the
#     rule lives.
#   - Transcript tail only (last 4000 entries).
#   - One block per distinct final text (clauses 1-3, state marker) or per HEAD
#     (clause 4, nudge marker newer than the sentinel), so no disagreement loops.
#
# FAIL-OPEN on missing jq, an unreadable transcript, or empty text.
#
# A Stop hook reaches the model only via exit 2 with the reason on stderr; this
# uses exit 2. Exit 0 prints into a turn that has already ended.
#
# MODES:
#   CC_CANDOR_GATE=block (default) | warn (print, never block) | off — the whole gate
#   CC_EVIDENCE_GATE=block | warn | off          — clause 3 only (kept from evidence-gate)
#   TASK_RUNNER_STOP_GATE=block | warn | off     — clause 4 only (kept from completion-gate)
#
# SUBAGENT REPORTS (SubagentStop, 0.2.0). The same script is wired to
# SubagentStop; a subagent's final report goes through CLAUSE 1 before the main
# thread quotes it as fact (payload: agent_transcript_path, last_assistant_message,
# measured live on 2.1.267; exit 2 blocks the subagent as it blocks a Stop).
# CLAUSES 2-4 disarm for a subagent: it has no user turn to push back, and its
# transcript is not the session that edited files or registered a run. Markers
# are suffixed per agent so a subagent block never spends the main thread's disarm.
#
# ORDER: 4, 1, 2, 3. Clause 4 first because it is the most specific context (a
# live run) and needs no transcript, so a run that stops with no transcript_path
# in the payload is still held. Only one verdict BLOCKS per stop — but a clause
# that has spoken without blocking does not silence the others. Clause 4 bounded
# at this HEAD (or in warn mode) prints its nudge and clauses 1-3 still run: on
# master these were three independent Stop hooks, each evaluated on every stop,
# and the first merge (0.3.0) let clause 4's verdict occupy the only slot for the
# rest of a HEAD — every card of a live run went uncovered for fabricated
# citations, bare reversals and naked completion claims after its first block.

input=$(cat)

gate_mode="${CC_CANDOR_GATE:-block}"
case "$gate_mode" in off) exit 0 ;; esac

command -v jq >/dev/null 2>&1 || { echo "[candor] gate: jq not found — gate not enforced" >&2; exit 0; }

sha_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
evt=$(printf '%s' "$input" | jq -r '.hook_event_name // "Stop"' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
# `-d`, not just `-n`. The payload cwd is a STRING the host supplies and the mkdir that
# creates the state dir below recreated a project directory the user had just deleted,
# three levels deep (live repro, AR 1 of the 2026-09-22 panel). A cwd that is not a
# directory degrades to the process cwd, which by construction exists. Residual: a cwd
# that IS a directory but not this project's still gets a .claude/candor/ — the check
# proves existence, never identity.
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="."
# Per-agent marker suffix: hashed, so the id never lands raw in a path.
agent_sfx=""
agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
[ -n "$agent_id" ] && agent_sfx="-$(printf '%s' "$agent_id" | cksum | cut -d' ' -f1)"

# PER-CLAUSE DISARM. stop_hook_active is SHARED across every Stop hook: the host
# sets it on the continuation after ANY blocking one. A bare exit on it let a
# sibling gate spend this one's enforcement (the old completion-gate header records
# that exact bug); deleting the exit wedges the session, because clauses 1-3 bound
# on a sha of the final text and a continuation is new prose by construction. So
# the record names the CLAUSE that blocked, and only that clause stands down on
# the continuation — the others still run. Clause 4 never stands down this way:
# its bound is the per-HEAD nudge, which is stable across turns.
# STATE DIR. Both markers live under .claude/candor/, which carries a self-ignoring
# .gitignore the first time it is created. Until 0.3.2 they were bare files at
# .claude/candor-last and .claude/candor-blocked — and showed up as untracked in
# every user's `git status` (observed in a live repo, and named as "other plugins'
# scratch" by overseer's own acceptance protocol), one `git add -A` away from being
# committed. A directory can ignore itself; a bare file cannot.
# Anchored at the repo root when there is one, so a stop taken from a subdirectory does
# not scatter a second .claude/candor/ beside it (pattern: overseer/hooks/track-read.sh).
state_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || state_root="$cwd"
[ -d "$state_root" ] || state_root="$cwd"
state_dir="$state_root/.claude/candor"
claimed="$state_dir/blocked$agent_sfx"
skip=""
if [ "$sha_active" = "true" ] && [ -f "$claimed" ]; then
  skip=$(cat "$claimed" 2>/dev/null)
  rm -f "$claimed" 2>/dev/null
fi

verdict=""   # citation | reversal | evidence | run — set by whichever clause fires first
detail=""
run_msg=""

# ---------------------------------------------------------------------------
# CLAUSE 4 — a registered task-runner run that is not complete
# ---------------------------------------------------------------------------
# Everything here is a RECORDS check: it never executes the produced tests (the
# completion protocol runs behavioral-gate.sh in isolation and records the pass;
# this only verifies that record exists for the final commit). It never mutates
# the tree; the nudge marker under .claude/task-runner/ is the only thing written.
run_clause() {
  local sentinel="$cwd/.claude/task-runner/active-run.json"
  [ "$evt" != "SubagentStop" ] || return 0
  case "${TASK_RUNNER_STOP_GATE:-block}" in off) return 0 ;; esac
  [ -r "$sentinel" ] || return 0                     # no registered run → nothing to enforce
  jq empty "$sentinel" 2>/dev/null || { echo "[candor] completion-gate: active-run.json malformed — not enforced" >&2; return 0; }
  command -v git >/dev/null 2>&1 || { echo "[candor] completion-gate: git not found — not enforced" >&2; return 0; }
  local head run_branch cur_branch slug
  head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null) || { echo "[candor] completion-gate: not a git repo — not enforced" >&2; return 0; }

  # BRANCH GUARD: a sentinel is cleared only on clean completion, so an abandoned run
  # leaves one behind indefinitely. Enforcing it from a different branch would turn a
  # dead run into a repo-wide trap. A run registered with a "branch" is enforced only
  # on that branch; a sentinel without one (pre-0.17 registration) keeps the old
  # unconditional behaviour.
  run_branch=$(jq -r '.branch // empty' "$sentinel" 2>/dev/null)
  cur_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -n "$run_branch" ] && [ -n "$cur_branch" ] && [ "$run_branch" != "$cur_branch" ]; then
    printf '[candor] completion-gate: run registered on branch %s, now on %s — not enforced here.\n' "$run_branch" "$cur_branch" >&2
    printf '  If that run is finished or abandoned, delete .claude/task-runner/active-run.json.\n' >&2
    return 0
  fi
  RUN_HEAD="$head"; RUN_SENTINEL="$sentinel"
  slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)

  local gatepass="$cwd/.claude/task-runner/gate-pass.json" v ct cdone cpark
  if [ -r "$gatepass" ] && [ "$(jq -r '.head // empty' "$gatepass" 2>/dev/null)" = "$head" ]; then
    # Gate pass recorded for THIS commit. For an index run, run.md also records card
    # counts; when those numeric fields are present, refuse a clean stop while any
    # card is neither done nor parked. ALL fields absent → legacy (allow). Partially
    # present, non-numeric or inconsistent counts are MALFORMED — never a silent allow.
    v=$(jq -r '
      if ((.cards_total|type)=="number" and (.cards_done|type)=="number" and (.cards_parked|type)=="number")
      then (if (.cards_done + .cards_parked) < .cards_total then "incomplete"
            elif (.cards_done + .cards_parked) > .cards_total then "malformed"
            else "complete" end)
      elif ((has("cards_total") or has("cards_done") or has("cards_parked")) | not) then "absent"
      else "malformed" end' "$gatepass" 2>/dev/null)
    # A run REGISTERED as an index run must record counts: counts-absent is a
    # bookkeeping failure, not legacy.
    if [ "$v" = "absent" ] && [ "$(jq -r 'has("index_path")' "$sentinel" 2>/dev/null)" = "true" ]; then
      v="malformed"
    fi
    if [ "$v" = "incomplete" ] || [ "$v" = "malformed" ]; then
      ct=$(jq -r '.cards_total' "$gatepass" 2>/dev/null)
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      cpark=$(jq -r '.cards_parked' "$gatepass" 2>/dev/null)
      run_msg=$(printf '[candor] completion-gate: %s recorded a gate pass but its card counts are %s: done=%s parked=%s total=%s.\n  A run may not report complete while any card is neither done nor parked.' "$slug" "$v" "$cdone" "$cpark" "$ct")
      verdict="run"; return 0
    fi
    # PER-CARD NEGATIVE-CONTROL COVERAGE (opt-in by presence of nc/): a complete run
    # must have one nc-pass or nc-skip record per DONE card. No nc/ dir → legacy allow.
    # Bounded the same way as rv/ and rt/ below — only records newer than THIS
    # registration count, and distinct ids (nc-pass-01 + nc-skip-01 is one card).
    # Until 0.3.7 this count was unbounded while its three siblings were not, so a
    # record left in nc/ by a PREVIOUS run (card ids repeat across runs, and the dir
    # is never cleared) satisfied this run's gate for a card that never had a control.
    local ncdir="$cwd/.claude/task-runner/nc" nc_count
    if [ "$v" = "complete" ] && [ -d "$ncdir" ]; then
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      nc_count=$(find "$ncdir" -maxdepth 1 \( -name 'nc-pass-*.json' -o -name 'nc-skip-*.json' \) -newer "$sentinel" 2>/dev/null |
        sed -E 's#.*/nc-(pass|skip)-##; s#\.json$##' | sort -u | wc -l | tr -d ' ')
      if [ "$nc_count" -lt "$cdone" ] 2>/dev/null; then
        run_msg=$(printf '[candor] completion-gate: %s reports %s done cards but only %s per-card negative-control records in .claude/task-runner/nc/.\n  Every done card needs an nc-pass record (negative-control.sh --record-dir --card) or a documented nc-skip. Run the missing controls, then stop.' "$slug" "$cdone" "$nc_count")
        verdict="run"; return 0
      fi
    fi
    # PER-CARD REVIEWER COVERAGE (rv/): records are written by hooks/rv-observe.sh
    # when it OBSERVES a reviewer dispatch carrying the RV-CARD marker, so the count is
    # not model-authored. Only records newer than THIS registration count (card ids
    # repeat across runs), and distinct ids (rv-seen-01 + rv-skip-01 is one card).
    local rvdir="$cwd/.claude/task-runner/rv" rv_count
    if [ "$v" = "complete" ] && [ -d "$rvdir" ]; then
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      rv_count=$(find "$rvdir" -maxdepth 1 \( -name 'rv-seen-*.json' -o -name 'rv-skip-*.json' -o -name 'rv-exempt-*.json' \) -newer "$sentinel" 2>/dev/null |
        sed -E 's#.*/rv-(seen|skip|exempt)-##; s#\.json$##' | sort -u | wc -l | tr -d ' ')
      if [ "$rv_count" -lt "$cdone" ] 2>/dev/null; then
        run_msg=$(printf '[candor] completion-gate: %s reports %s done cards but only %s per-card reviewer records in .claude/task-runner/rv/.\n  Every done card needs an observed reviewer dispatch (the RV-CARD marker in the prompt), a recorded skip (scripts/review-skip.sh --card --reason) or an exemption (--exempt). Run the missing reviews, then stop.' "$slug" "$cdone" "$rv_count")
        verdict="run"; return 0
      fi
    fi
    # BEHAVIORAL-GATE EVIDENCE. gate-pass.json is written by the MODEL; bg-<head>.json
    # is written by behavioral-gate.sh with the verdict it actually reached. With bg/
    # present (created at registration) a complete verdict must be backed by a matching
    # record. `covered` and `no-executable-surface` are BOTH passing verdicts — the
    # second is an honest doc/lint-only change with nothing runnable to prove.
    local bgdir="$cwd/.claude/task-runner/bg" bgv
    if [ "$v" = "complete" ] && [ -d "$bgdir" ]; then
      if [ ! -r "$bgdir/bg-$head.json" ]; then
        run_msg=$(printf '[candor] completion-gate: %s recorded a gate pass for HEAD %s, but behavioral-gate.sh left no verdict record for it.\n  gate-pass.json is written by hand; bg/bg-<head>.json is written by the gate itself. Run scripts/behavioral-gate.sh against this HEAD, then stop.' "$slug" "${head:0:12}")
        verdict="run"; return 0
      fi
      bgv=$(jq -r '.verdict // empty' "$bgdir/bg-$head.json" 2>/dev/null)
      case "$bgv" in covered | no-executable-surface | '') bgv="" ;; esac
      if [ -n "$bgv" ]; then
        run_msg=$(printf '[candor] completion-gate: behavioral-gate.sh reached "%s" for HEAD %s, and the run is reporting complete.\n  A run may not close over a red or unverifiable behavioral gate. Fix the coverage, re-run the gate, then stop.' "$bgv" "${head:0:12}")
        verdict="run"; return 0
      fi
    fi
    # RED-TEAM PANEL WIDTH (boosted runs that shipped code). Refuter dispatches carry
    # RT-LENS markers, the critic RT-CRITIC; rv-observe.sh records them. The degraded
    # inline fallback is legitimate but must be RECORDED (reduction-record.sh --kind
    # redteam). A boosted run that touched no code owes no panel; unknown diff → do
    # not enforce (a missed check costs a check, a false block costs the run).
    local rtdir="$cwd/.claude/task-runner/rt" idx idxp boosted run_base code_touched lenses critic degraded
    if [ "$v" = "complete" ] && [ -d "$rtdir" ]; then
      idx=$(jq -r '.index_path // empty' "$sentinel" 2>/dev/null)
      boosted=0
      case "$idx" in /*) idxp="$idx" ;; *) idxp="$cwd/$idx" ;; esac
      if [ -n "$idx" ] && [ -r "$idxp" ]; then
        # a Goal: line carrying boost=off (taskmaster goal-lean) is hands-off without the boost
        grep -iE '^[[:space:]]*(Ultra|Goal):[[:space:]]*true' "$idxp" 2>/dev/null | grep -qv 'boost=off' && boosted=1
      fi
      if [ "$boosted" = 1 ]; then
        run_base=$(jq -r '.base // empty' "$sentinel" 2>/dev/null)
        code_touched=unknown
        if [ -n "$run_base" ] && git -C "$cwd" rev-parse --verify "$run_base" >/dev/null 2>&1; then
          if git -C "$cwd" diff --name-only "$run_base..HEAD" 2>/dev/null |
               grep -qvE '\.(md|txt|json|ya?ml|lock|csv|svg|png|jpe?g|gif)$|^$'; then
            code_touched=yes
          else
            code_touched=no
          fi
        fi
        [ "$code_touched" = "no" ] && boosted=0
      fi
      if [ "$boosted" = 1 ]; then
        lenses=$(find "$rtdir" -maxdepth 1 -name 'rt-lens-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
        critic=$(find "$rtdir" -maxdepth 1 -name 'rt-critic-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
        degraded=$(find "$cwd/.claude/task-runner/reductions" -maxdepth 1 -name 'redteam-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$degraded" -eq 0 ] 2>/dev/null && { [ "$lenses" -lt 3 ] || [ "$critic" -lt 1 ]; } 2>/dev/null; then
          run_msg=$(printf '[candor] completion-gate: this is a boosted run, and the code red-team panel is short: %s of 3 refuter lenses, %s of 1 completeness critic.\n  Dispatch the missing refuters (each prompt carries RT-LENS: <lens>, the critic RT-CRITIC: <id>), or record the degraded inline pass with scripts/reduction-record.sh --kind redteam --id <ref> --reason "...". Then stop.' "$lenses" "$critic")
          verdict="run"; return 0
        fi
      fi
    fi
    # DISCLOSURE of every recorded reduction: the ID of each one must appear in the
    # closing report. Presence only — this cannot judge whether the disclosure is
    # honest. What it removes is a cut that happened, was recorded, and never reached
    # the person reading the report.
    local ids tp said missing id
    if [ "$v" = "complete" ]; then
      ids=$(find "$rvdir" -maxdepth 1 -name 'rv-skip-*.json' -newer "$sentinel" 2>/dev/null |
              sed -E 's|.*/rv-skip-||; s|\.json$||'
            find "$cwd/.claude/task-runner/reductions" -maxdepth 1 -name '*.json' -newer "$sentinel" 2>/dev/null |
              sed -E 's|.*/[a-z]+-||; s|\.json$||')
      ids=$(printf '%s\n' "$ids" | sed '/^$/d' | sort -u)
      if [ -n "$ids" ]; then
        tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
        if [ -n "$tp" ] && [ -r "$tp" ]; then
          said=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$tp" 2>/dev/null | tail -200)
          missing=""
          for id in $ids; do
            printf '%s' "$said" | grep -qF "$id" || missing="$missing $id"
          done
          if [ -n "$said" ] && [ -n "$missing" ]; then
            run_msg=$(printf '[candor] completion-gate: this run recorded reductions that the closing report never names:%s\n  Name each one and its reason (the records are in .claude/task-runner/rv/ and reductions/) before stopping — a cut the user has to ask about is the gap this gate exists to prevent.' "$missing")
            verdict="run"; return 0
          fi
        fi
      fi
    fi
    return 0                                      # gate pass for THIS commit → allow
  fi

  # No gate pass for HEAD → the run is not complete. Mid-run and end-of-run both land
  # here and the hook cannot tell them apart cheaply, so it names BOTH branches.
  #
  # The gate branch names the exact command and a pace rule. Until 0.4.11 it said
  # "run behavioral-gate.sh (isolated)" under a "continue NOW" that read as applying to
  # both branches. On 2026-09-24 an agent at the end of a 44-card run hand-built the
  # "isolated" checkout in a rush of chained commands. Its worktree call was denied
  # whole, it read that as "only the cp failed", and its next `cd /tmp/… && …; cp
  # .env.example .env && php artisan key:generate` ran in the live repo, overwriting the
  # developer's .env and APP_KEY. Urgency belongs to the cards branch; the gate branch
  # has no deadline, and a setup step that fails must stop the sequence.
  run_msg=$(printf '[candor] completion-gate: %s is a registered run with no behavioral-gate pass for HEAD %s.
  The run is not complete, so this turn must not end here.
  Cards still to execute -> continue with the next card'"'"'s tool call. Do not name the next card
    in prose and yield: that binds nothing, and the user waits on a turn that already ended.
    Need a decision -> ask it with AskUserQuestion (not a stop). Blocked -> park the card with a reason.
  Every card done or parked -> the gate is the only step left, and it has no deadline. From the
    repo root run task-runner'"'"'s scripts/behavioral-gate.sh --isolate --changed "<the run'"'"'s touched
    files>" (the path run.md step 4 names). --isolate creates, checks and removes its own worktree
    and writes the verdict record; do not hand-build a checkout, and do not copy, generate or write
    any .env for it. Then record the pass to .claude/task-runner/gate-pass.json as {"head":"%s"}
    plus the card counts, and clear active-run.json. A green repo suite alone is NOT this gate.
  Any shell setup: one step per call, and read each result before the next. A denied or failed
    call ran NOTHING, not "everything but the part named in the error".
  Not running this task list at all? The sentinel outlived its run — delete
    .claude/task-runner/active-run.json.' "$slug" "${head:0:12}" "$head")
  verdict="run"
}
RUN_HEAD=""; RUN_SENTINEL=""
run_clause

if [ "$verdict" = "run" ]; then
  # Clause-specific mode kept from the script this clause came from.
  run_mode="$gate_mode"
  case "${TASK_RUNNER_STOP_GATE:-block}" in warn) run_mode=warn ;; esac
  # ONE BLOCK PER HEAD. The last HEAD blocked on is recorded, and a second stop at the
  # SAME commit prints without blocking, so a real run is held at every card boundary
  # (every commit re-arms) while a stale sentinel costs one extra turn per commit. The
  # marker counts only while NEWER than the sentinel it was written under: nothing
  # clears it (the run clears active-run.json, not this), so a marker left by run A
  # must not eat run B's first block at the same HEAD. A same-tick tie fails toward
  # blocking, never toward silence. Warn mode never writes it.
  # NAME THE OFF SWITCH IN THE MESSAGE. A Stop gate reaches the reader only through
  # this stderr, so a var documented anywhere else is a var the person being blocked
  # cannot find (UX 1 of the 2026-09-22 panel: every PreToolUse guard here names its
  # own switch, every Stop gate omitted it). One line at the single print site covers
  # all eight completion-gate reasons, which is why it is here and not in each printf.
  printf '%s\n' "$run_msg" >&2
  printf '  TASK_RUNNER_STOP_GATE=off disables this clause for the session; =warn prints without blocking.\n' >&2
  if [ "$run_mode" = "block" ]; then
    nudge="$cwd/.claude/task-runner/gate-nudge"
    if [ -r "$nudge" ] && [ "$nudge" -nt "$RUN_SENTINEL" ] && [ "$(cat "$nudge" 2>/dev/null)" = "$RUN_HEAD" ]; then
      :                                   # bounded at this HEAD — printed, not blocked
    elif printf '%s' "$RUN_HEAD" > "$nudge" 2>/dev/null; then
      exit 2
    elif [ "$sha_active" != "true" ]; then
      # No writable marker → no per-HEAD bound this turn. The shared flag is honoured
      # only here, so an unwritable state dir cannot block the same stop forever.
      exit 2
    fi
  fi
  # Bounded or warn: clause 4 has spoken without blocking. Clauses 1-3 still run —
  # a run held once at this HEAD does not license an invented citation on the next
  # stop (see ORDER in the header).
  verdict=""; run_msg=""
fi

# ---------------------------------------------------------------------------
# Transcript — clauses 1-3 read it; without one they stand down.
# ---------------------------------------------------------------------------
# A subagent's report lives in ITS transcript, not the parent's; fall back to the
# parent path only when the host sent no agent path (a pre-2.1 payload).
tp=$(printf '%s' "$input" | jq -r '.agent_transcript_path // .transcript_path // empty' 2>/dev/null)
tail_jsonl=""
if [ -n "$tp" ] && [ -r "$tp" ]; then
  tail_jsonl=$(tail -n 4000 "$tp" 2>/dev/null)
fi

# The FINAL assistant text message, whole and alone. `-s` slurps the JSONL into
# an array so "last" is expressible; a malformed line collapses the slurp, which
# is a fail-open path and is why the result is tested for emptiness below.
last_msg=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty' 2>/dev/null)
[ -n "$last_msg" ] || [ -z "$tail_jsonl" ] || last_msg=$(printf '%s' "$tail_jsonl" | jq -rs '
  [ .[] | select(.type=="assistant")
        | ((.message.content // []) | map(select(.type=="text") | .text) | join("\n"))
        | select(length > 0) ] | last // empty' 2>/dev/null)

# ---------------------------------------------------------------------------
# CLAUSE 1 — citations that do not resolve
# ---------------------------------------------------------------------------
# URLs are stripped BEFORE extraction: `https://host/a.php:80` is a port, not a
# line. The extension must START with a letter, so `v1.2.3:4` and `10:30` never
# match, and a short deny-list drops bare host:port forms (`example.com:8080`).
if [ -z "$verdict" ] && [ -n "$last_msg" ] && [ "$skip" != "citation" ]; then
  cites=$(printf '%s' "$last_msg" \
    | sed -E 's#[a-zA-Z][a-zA-Z0-9+.-]*://[^[:space:])"]*##g' \
    | grep -oE '[A-Za-z0-9_.~][A-Za-z0-9_./-]*\.[A-Za-z][A-Za-z0-9]{0,9}:[0-9]+' 2>/dev/null \
    | grep -vEi '\.(com|net|org|io|co|ai|app|gg|me):[0-9]+$' \
    | grep -vF '...' \
    | sort -u)

  # _find <predicate…> — one pruned, depth-capped tree walk. Bounded so a Stop hook
  # stays cheap on a large repo.
  _find() { find "$cwd" -maxdepth 8 \
    \( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name .venv \) -prune \
    -o "$@" -type f -print 2>/dev/null; }

  # resolve <relpath> — prints one of:
  #   FILE <path>   the citation identifies exactly one file on disk
  #   MISSING       no file anywhere in the tree carries that BASENAME
  #   AMBIGUOUS     the path does not resolve, but the basename is not unique
  #
  # A FOUR-STEP LADDER, and the last two steps exist because of a measurement, not a
  # theory. Run over 47 real session transcripts (~3.3k assistant messages), the
  # earlier two-step version — cwd-relative, then a full-suffix match — reported 98
  # unresolved citations, and the overwhelming majority were ABBREVIATED paths, not
  # invented ones: `craft-layer/asset-sourcing/SKILL.md:10` for a file that really
  # lives at `plugins/craft-layer/skills/asset-sourcing/SKILL.md`. Blocking those is
  # the false-positive class that gets a gate switched off. So the ladder falls back
  # to the basename, and only a basename that exists NOWHERE is treated as
  # fabrication. A real filename under a wrong directory now passes silently, and
  # that residual is deliberate.
  resolve() {
    local p="$1" m b n
    # `~/.claude/settings.json:12` is a real location in the user's home. Before
    # 0.3.2 the `~` was outside the extraction class, so the citation was read as
    # the absolute path `/.claude/settings.json`, resolved to nothing, and blocked —
    # on the exact file a settings question is answered from.
    case "$p" in "~/"*) p="${HOME:-}/${p#\~/}" ;; esac
    case "$p" in
      /*) [ -f "$p" ] && { printf 'FILE %s' "$p"; return 0; } ;;
    esac
    [ -f "$cwd/$p" ] && { printf 'FILE %s' "$cwd/$p"; return 0; }
    m=$(_find -path "*/$p" | head -1)
    [ -n "$m" ] && { printf 'FILE %s' "$m"; return 0; }
    b=${p##*/}
    m=$(_find -name "$b" | head -2)
    n=$(printf '%s\n' "$m" | grep -c .)
    if [ "$n" -eq 0 ]; then printf 'MISSING'
    elif [ "$n" -eq 1 ]; then printf 'FILE %s' "$m"
    else printf 'AMBIGUOUS'
    fi
    return 0
  }

  misses=""
  checked=0
  for c in $cites; do
    [ "$checked" -ge 25 ] && break
    checked=$((checked + 1))
    path="${c%:*}"; line="${c##*:}"
    r=$(resolve "$path")
    case "$r" in
      MISSING)   misses="$misses
  - $c — no file named ${path##*/} exists anywhere under $cwd"; continue ;;
      AMBIGUOUS) continue ;;   # path unresolved but the name is real — not decidable
    esac
    file="${r#FILE }"
    lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
    case "$lines" in ''|*[!0-9]*) continue ;; esac
    # +1 tolerance: a final line with no trailing newline is not counted by wc -l.
    if [ "$line" -gt $((lines + 1)) ] 2>/dev/null; then
      misses="$misses
  - $c — $file has $lines lines"
    fi
  done

  if [ -n "$misses" ]; then
    verdict="citation"
    detail="$misses"
  fi
fi

# ---------------------------------------------------------------------------
# CLAUSE 2 — a position reversed after bare pushback, with nothing re-checked
# ---------------------------------------------------------------------------
if [ -z "$verdict" ] && [ -n "$last_msg" ] && [ -n "$tail_jsonl" ] && [ "$evt" != "SubagentStop" ] && [ "$skip" != "reversal" ]; then
  # Last real user message. Tool results also arrive as type "user"; they carry
  # tool_result blocks and no text blocks, so selecting text blocks excludes them.
  last_user=$(printf '%s' "$tail_jsonl" | jq -rs '
    [ .[] | select(.type=="user")
          | (if (.message.content | type) == "string" then .message.content
             else ((.message.content // []) | map(select(.type=="text") | .text) | join("\n")) end)
          | select(length > 0) ] | last // empty' 2>/dev/null)

  PUSHBACK='are you sure|you sure|are you certain|is that (right|true|correct|actually)|that.?s (not right|wrong|incorrect|false|not true)|that is (not right|wrong|incorrect|false)|you.?re (wrong|mistaken)|you are (wrong|mistaken)|i don.?t think (so|that|it)|i disagree|doesn.?t (seem|sound|look) right|does not (seem|sound|look) right|check (it )?again|double.?check|really\?|no,? (it|that|this|they|you) |nope|prove it|where did you (get|see|find) that|you (made|just made) (that|it) up|hallucinat|that.?s not (how|what|where)'

  # A pushback that ARRIVES WITH ITS OWN EVIDENCE is not the sycophancy setup —
  # a user who quotes a path, pastes a snippet, or writes a paragraph of reasoning
  # has supplied the new information, and agreeing with it is reading, not
  # flattery. Disarm on any of: a backtick, a path-shaped token, a file:line, or
  # a message long enough to be an argument rather than a challenge.
  user_has_evidence=0
  if [ -n "$last_user" ]; then
    printf '%s' "$last_user" | grep -q '`' && user_has_evidence=1
    printf '%s' "$last_user" | grep -qE '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+' && user_has_evidence=1
    printf '%s' "$last_user" | grep -qE '\.[A-Za-z][A-Za-z0-9]{0,9}:[0-9]+' && user_has_evidence=1
    [ "$(printf '%s' "$last_user" | wc -c | tr -d ' ')" -gt 400 ] && user_has_evidence=1
  fi

  CAVE='you.?re (absolutely |completely |totally |quite |entirely )?right|you are (absolutely |completely |totally |quite |entirely )?right|you.?re correct|you are correct|my (mistake|apologies|bad|error)|i (was|am) wrong|i apologi[sz]e|apologies|good catch|i stand corrected|i (was|got) (confused|mistaken)|that was (wrong|my (mistake|error))|let me correct'

  # HOLD — the message did more than fold. Either it names what it re-checked, or
  # it keeps part of the position. Both are candour; neither is what this blocks.
  HOLD='i still (think|believe|maintain)|i do (think|believe)|i.?m not (changing|reversing)|re-?read|re-?ran|re-?checked|i (checked|verified|confirmed)|after (checking|re-?reading|running|re-?running)|the (file|output|test|error|transcript) (shows|says)|i disagree|on (that|this) (one|point) i|partly|only partly|to be clear, i'

  if [ -n "$last_user" ] && [ "$user_has_evidence" -eq 0 ] \
     && printf '%s' "$last_user" | grep -qiE "$PUSHBACK" \
     && printf '%s' "$last_msg" | grep -qiE "$CAVE" \
     && ! printf '%s' "$last_msg" | grep -qiE "$HOLD"; then
    # Did anything run AFTER that user message? One row per entry keeps order
    # without line numbers: "USER" for a real user turn, the tool names for an
    # assistant turn, empty otherwise.
    ran=$(printf '%s' "$tail_jsonl" | jq -r '
      if .type=="user" then
        (if ((.message.content | type) == "string")
            or (((.message.content // []) | map(select(.type=="text")) | length) > 0)
         then "USER" else "" end)
      elif .type=="assistant" then
        ([.message.content[]? | select(.type=="tool_use") | .name] | join(" "))
      else "" end' 2>/dev/null \
      | awk '{ if ($0 == "USER") { after = 0 } else if (NF > 0) { after = 1 } } END { print (after ? "yes" : "no") }')
    if [ "$ran" = "no" ]; then
      verdict="reversal"
      detail="$last_user"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# CLAUSE 3 — a completion claim with nothing executed after the last edit
# ---------------------------------------------------------------------------
# CLAIM and ACK are matched over the SAME window (the last 30 lines of assistant
# text), and the window bleeds in BOTH directions. Measured:
#   * ACK bleed — "not tested yet" two messages back licenses a fresh naked
#     "Everything is implemented and verified. Done." in this turn.
#   * CLAIM bleed — a previous turn's legitimate "All tests pass, done." still
#     sits in the window, so a later small edit ending in text that claims
#     nothing can be blocked for a claim it never made.
# Narrowing ACK to the final message alone was considered and rejected: it would
# block honest reports that state the caveat before the summary, and it fixes no
# measured escape — those were all same-sentence.
ev_mode="${CC_EVIDENCE_GATE:-block}"
if [ -z "$verdict" ] && [ -n "$tail_jsonl" ] && [ "$evt" != "SubagentStop" ] && [ "$skip" != "evidence" ] && [ "$ev_mode" != "off" ]; then
  # 1. CLAIM (cheap): does the assistant tail claim completion? Whole-word via
  # grep -w (BSD grep has no \b; unanchored 'done' would match 'abandoned').
  said=$(printf '%s' "$tail_jsonl" \
    | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null \
    | tail -30)
  CLAIM='done|complete|completed|finished|implemented|fixed|resolved|verified|passes|passing|works now|working now|should work|all set|good to go'
  # HONESTY ESCAPE: a turn that names what is unverified or failing is a status
  # report, not a false claim. The escape must assert something about THIS turn's
  # verification state. Bare failure nouns (fail/failing/failed) used to be listed
  # and disarmed the gate on the most common bug-fix shape: "Fixed the failing
  # test — should work now". A failure named as the thing that was FIXED is part
  # of the claim. So the failure vocabulary is phrase-scoped — the subject must be
  # the check ("tests still fail", "the build failed", "two tests are failing") or
  # a present-tense failure must carry its cause ("fails with ENOENT").
  # WHAT THIS DOES NOT CLOSE: a completion claim naming a PAST failure with the
  # check as its subject still escapes ("The build failed earlier; after my fix it
  # is all good now. Done.") — the same string is how a genuinely red suite gets
  # reported, and no pattern separates them. This closes the bare-noun class, not
  # the tense problem.
  ACK='not tested|untested|unverified|not verified|did not (run|rerun)|didn.t (run|rerun)|have not (run|rerun)|haven.t (run|rerun)|not (run|rerun) yet|cannot verify|could not verify|not green|still fail(ing|s)?|currently fail(ing|s)?|(tests?|suite|build|lint|checks?|it) (is|are|was|were) (still |currently )?fail(ing|ed|s)?|(tests?|suite|build|lint|checks?|it) (still |currently )?fail(ing|ed|s)?|fail(ing|s) (with|on|because|due)|in progress|still working|wip|not done|incomplete|halt|halting|halted|blocked|parked|known issue|please verify|verify manually|left to do|remains to'
  if [ -n "$said" ] && printf '%s' "$said" | grep -qiwE "$CLAIM" && ! printf '%s' "$said" | grep -qiwE "$ACK"; then
    # 2+3. MUTATION AND EVIDENCE ORDER: one row of tool names per assistant entry
    # (blank when none) preserves order without line numbers; awk finds whether an
    # execution tool ran after the LAST file mutation.
    # Each mutation token carries the edited file's extension (`Edit@md`), and a
    # mutation of a PROSE file — .md/.mdx/.markdown/.txt/.rst/.adoc — does not arm
    # the clause. There is no command whose failure would prove a README typo fix
    # wrong, so "run something" bought a `git diff` and a turn, never a check; the
    # same reasoning clause 4 already applies as its `no-executable-surface` verdict.
    # A mutation with no file_path, no extension, or any other extension (json,
    # yaml, sh, code) still arms it. RESIDUAL: a prose edit that lies about content
    # ("documented and verified") passes — there was nothing to execute either way.
    ev=$(printf '%s' "$tail_jsonl" \
      | jq -r 'select(.type=="assistant")
               | [.message.content[]? | select(.type=="tool_use")
                  | .name + (if (.name | test("^(Edit|Write|MultiEdit|NotebookEdit)$|apply_patch$|create_new_file$"))
                             then "@" + ((.input.file_path // "") | ascii_downcase | (if test("\\.[a-z0-9]+$") then sub(".*\\."; "") else "" end))
                             else "" end)]
               | join(" ")' 2>/dev/null \
      | awk '
          { for (i = 1; i <= NF; i++) { n++
              if ($i ~ /^(Edit|Write|MultiEdit|NotebookEdit)(@|$)/ && $i !~ /@(md|mdx|markdown|txt|rst|adoc|asciidoc)$/) last_edit = n
              if ($i ~ /^(Bash|Agent|Task)$/)                   last_exec = n } }
          END {
            if (!last_edit)               print "no-edits"
            else if (last_exec > last_edit) print "evidence"
            else                          print "naked-claim" }')
    if [ "$ev" = "naked-claim" ]; then
      verdict="evidence"
      detail="$said"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# CLAUSE 5 — LOCKFILE DRIFT. A dependency manifest was edited in this turn and the
# lockfile it governs is not in the working tree's changes. The install step was
# skipped, and the next person to clone gets a tree whose manifest and lockfile
# disagree — a CI failure attributed to them, not to the turn that caused it.
#
# WHY A CLAUSE AND NOT PROSE. `stack-scan:package-hygiene` states the rule already:
# hand-editing a manifest without running the installer is a defect. The model
# agrees and then does it anyway, because adding a dependency line LOOKS complete —
# nothing in the edit's own result says a second step is owed. This clause is the
# only thing in the tree that reads the pair.
#
# WHY IT CANNOT FALSELY FIRE ON A DELIBERATE MANIFEST-ONLY EDIT: it requires a
# dependency-shaped change. Bumping a `version` field, editing `scripts`, or
# rewriting a description never touches a lockfile and never arms this.
#
# Last of the clauses because it is the cheapest to satisfy and the least severe:
# a citation or a naked completion claim is a false report, this is an unfinished
# step.
#
# `$skip` is LOAD-BEARING and was missing in the first version of this clause: without
# it the clause re-fires on its own continuation, and because the loop guard keys on the
# final assistant TEXT, a second turn with different text blocks again — so the escape
# this clause's own message offers ("say plainly that the lockfile is deliberately
# unchanged and why") could never be taken, and the turn was unblockable. Found by a
# branch review before merge; clauses 1-3 each carry the same term at :387, :470, :537.
if [ -z "$verdict" ] && [ "$evt" != "SubagentStop" ] && [ "$skip" != "lockfile" ] && [ "${CC_LOCKFILE_GATE:-on}" != "off" ]; then
  if command -v git >/dev/null 2>&1 && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    changed=$(git -C "$cwd" status --porcelain 2>/dev/null | awk '{print $NF}')
    if [ -n "$changed" ]; then
      lock_detail=""
      # manifest -> the lockfile(s) that satisfy it. First match wins per manifest.
      while IFS='|' read -r man locks; do
        printf '%s\n' "$changed" | grep -qx "$man" || continue
        # A DEPENDENCY-shaped change only. For a JSON manifest this compares the parsed
        # dependency maps at HEAD against the working tree, because a line diff cannot:
        # package.json is frequently one line, so bumping `version` rewrites the same
        # line that holds `dependencies` and every version bump would block. (The
        # harness caught exactly that; a hand test missed it because the loop guard was
        # still holding the previous verdict.) Non-JSON manifests keep the line-diff
        # heuristic — their dependency sections are line-oriented by construction.
        case "$man" in
          package.json|composer.json)
            head_deps=$(git -C "$cwd" show "HEAD:$man" 2>/dev/null \
              | jq -cS '{d:(.dependencies//{}),dd:(.devDependencies//{}),p:(.peerDependencies//{}),o:(.optionalDependencies//{}),r:(.require//{}),rd:(."require-dev"//{})}' 2>/dev/null)
            work_deps=$(jq -cS '{d:(.dependencies//{}),dd:(.devDependencies//{}),p:(.peerDependencies//{}),o:(.optionalDependencies//{}),r:(.require//{}),rd:(."require-dev"//{})}' "$cwd/$man" 2>/dev/null)
            # Unparseable either side → fall through to the line heuristic rather than
            # silently allowing: a manifest mid-edit is exactly when this matters.
            if [ -n "$head_deps" ] && [ -n "$work_deps" ]; then
              [ "$head_deps" = "$work_deps" ] && continue
            else
              git -C "$cwd" diff -U0 -- "$man" 2>/dev/null | grep -qE '^[+-].*"(dependencies|devDependencies|peerDependencies|optionalDependencies|require|require-dev)"' || continue
            fi
            ;;
          *)
            # A DEPENDENCY line, not any line. The first version armed on `^[+-]`, so a
            # version bump in pyproject.toml, a `[tool.ruff]` edit, or a comment added to
            # a Gemfile all blocked a Stop — measured in a branch review before merge,
            # and the exact false fire the header above promises cannot happen. Each
            # manifest's dependency grammar is line-oriented, so a line test is the right
            # shape; it just has to test the right lines. Residual, stated: a dependency
            # written in a form none of these patterns matches arms nothing, which is the
            # safe direction for a Stop-tier block.
            # TOML's `key = "value"` is ambiguous at line level: `requests = "^2.28"` is a
            # poetry dependency and `version = "2.0.0"` is metadata, and a line regex
            # cannot see which table it sits in. So the metadata keys are excluded by
            # name — a short, closed list — rather than guessed at.
            meta_re='^[+-][[:space:]]*(version|name|description|readme|license|authors|maintainers|homepage|repository|documentation|keywords|classifiers|requires-python|edition|rust-version|publish|include|exclude|packages|scripts|urls)[[:space:]]*='
            case "$man" in
              pyproject.toml)
                dep_re='^[+-][[:space:]]*("[^"]+"[[:space:]]*,?[[:space:]]*$|[A-Za-z0-9._-]+[[:space:]]*=[[:space:]]*[{"^~>=<*]|dependencies[[:space:]]*=|\[(tool\.poetry\.(dev-)?dependencies|project\.optional-dependencies|build-system)\])' ;;
              Gemfile)
                dep_re='^[+-][[:space:]]*(gem[[:space:]]|gemspec|source[[:space:]]|git[[:space:]]|path[[:space:]])'
                meta_re='^$' ;;
              Cargo.toml)
                dep_re='^[+-][[:space:]]*([A-Za-z0-9._-]+[[:space:]]*=[[:space:]]*[{"^~>=<*]|\[(dependencies|dev-dependencies|build-dependencies|workspace\.dependencies)\])' ;;
              go.mod)
                dep_re='^[+-][[:space:]]*(require|replace|exclude|retract)?[[:space:]]*[a-z0-9.-]+\.[a-z]{2,}/'
                meta_re='^[+-][[:space:]]*(module|go|toolchain)[[:space:]]' ;;
              *)
                dep_re='^[+-]'
                meta_re='^$' ;;
            esac
            git -C "$cwd" diff -U0 -- "$man" 2>/dev/null \
              | grep -E "$dep_re" 2>/dev/null | grep -qvE "$meta_re" || continue
            ;;
        esac
        satisfied=0
        for l in $locks; do printf '%s\n' "$changed" | grep -qx "$l" && satisfied=1; done
        [ "$satisfied" -eq 1 ] && continue
        [ -n "$lock_detail" ] && lock_detail="$lock_detail, "
        lock_detail="$lock_detail$man (expected one of: $(printf '%s' "$locks" | tr ' ' '/'))"
      done <<'MANIFESTS'
package.json|package-lock.json npm-shrinkwrap.json yarn.lock pnpm-lock.yaml bun.lock bun.lockb
composer.json|composer.lock
Gemfile|Gemfile.lock
pyproject.toml|poetry.lock uv.lock pdm.lock requirements.txt
Cargo.toml|Cargo.lock
go.mod|go.sum
MANIFESTS
      if [ -n "$lock_detail" ]; then
        verdict="lockfile"
        detail="$lock_detail"
      fi
    fi
  fi
fi

[ -n "$verdict" ] || exit 0

# ---------------------------------------------------------------------------
# Bound, record, report.
# ---------------------------------------------------------------------------
# Effective mode for the clause that fired: the whole-gate mode, then the
# clause-specific override kept from the script that clause came from.
mode="$gate_mode"
case "$verdict" in
  evidence) case "$ev_mode" in warn) mode=warn ;; esac ;;
esac

# LOOP GUARD for clauses 1-3: block once per distinct final text. The marker is
# state a mid-work turn cannot fake — a genuinely new turn produces new text.
marker="$state_dir/last$agent_sfx"
state=$(printf '%s|%s' "$verdict" "$detail$last_msg" | (command -v shasum >/dev/null 2>&1 && shasum | cut -d' ' -f1 || cksum | cut -d' ' -f1))
if [ -r "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$state" ]; then
  exit 0
fi
if ! { mkdir -p "$state_dir" 2>/dev/null && { [ -e "$state_dir/.gitignore" ] || printf '*\n' > "$state_dir/.gitignore" 2>/dev/null || :; } && printf '%s' "$state" > "$marker" 2>/dev/null; }; then
  # No marker means no per-text bound this turn. THIS is where the shared flag
  # earns its keep: without both, a gate that blocks on unwritable state blocks
  # the same turn forever. Honouring it only here costs at most one unenforced
  # stop on an already-degraded setup.
  [ "$sha_active" = "true" ] && exit 0
fi

# Record which clause blocked, so only that clause stands down on the continuation.
if [ "$mode" = "block" ]; then
  mkdir -p "$state_dir" 2>/dev/null && printf '%s' "$verdict" > "$claimed" 2>/dev/null
fi

case "$verdict" in
  citation)
    what="this turn"; [ "$evt" = "SubagentStop" ] && what="this report"
    printf '[candor] gate: %s cites a location that does not exist.%s\n' "$what" "$detail" >&2
    printf '  A file:line citation asserts you read that line. Open the file, cite what is actually\n' >&2
    printf '  there, or drop the number and say plainly that you are inferring rather than quoting.\n' >&2
    printf '  Inventing a location is the failure this clause exists to stop.\n' >&2
    printf '  CC_CANDOR_GATE=off disables this gate for the session; =warn prints without blocking.\n' >&2 ;;
  reversal)
    printf '[candor] gate: the user pushed back without giving you new information, and this turn\n' >&2
    printf '  retracts your position anyway — nothing was re-checked between the challenge and the\n' >&2
    printf '  retraction.\n' >&2
    printf '  Do one of two things. Re-check: run the command or read the file that would settle it,\n' >&2
    printf '  then report what it showed. Or hold: say you still believe what you said, and why.\n' >&2
    printf '  "You are right" is a finding. It needs the same evidence as any other finding.\n' >&2
    printf '  CC_CANDOR_GATE=off disables this gate for the session; =warn prints without blocking.\n' >&2 ;;
  lockfile)
    printf '[candor] gate: a dependency manifest changed and its lockfile did not — %s.\n' "$detail" >&2
    printf '  The install step was skipped, so the tree you are leaving has a manifest and a lockfile\n' >&2
    printf '  that disagree. The next clone resolves different versions, and CI blames whoever ran it.\n' >&2
    printf '  Run the installer (npm/pnpm/yarn install, composer update <pkg>, bundle install, cargo\n' >&2
    printf '  build, go mod tidy) and commit the lockfile with the manifest — or say plainly that the\n' >&2
    printf '  lockfile is deliberately unchanged and why. CC_LOCKFILE_GATE=off disables this clause.\n' >&2 ;;
  evidence)
    printf '[candor] evidence-gate: this turn claims completion, files were edited, and no command ran after the last edit — nothing verified the change.\n' >&2
    printf '  Either run the check that would FAIL if the change were broken (test, build, lint, or execute\n' >&2
    printf '  the changed code) and show its output — or restate honestly: what changed, what was NOT\n' >&2
    printf '  verified, and the exact command the user can run to verify it.\n' >&2
    printf '  A claim with no execution behind it is the failure this gate exists to stop.\n' >&2
    printf '  CC_EVIDENCE_GATE=off disables this clause for the session; =warn prints without blocking.\n' >&2 ;;
esac

[ "$mode" = "block" ] || exit 0
exit 2
